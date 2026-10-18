-- Mi Hogar 360 v1.2 — Supabase setup
-- Run this entire file in Supabase SQL Editor before connecting the PWA.
create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  can_add_expenses boolean not null default false,
  member_profile_id text,
  created_at timestamptz not null default now(),
  primary key (household_id,user_id)
);
create table if not exists public.household_invites (
  code text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  member_profile_id text,
  can_add_expenses boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;

drop policy if exists household_select_member on public.households;
create policy household_select_member on public.households for select to authenticated
using (owner_id=auth.uid() or exists(select 1 from public.household_members hm where hm.household_id=id and hm.user_id=auth.uid()));
drop policy if exists household_insert_owner on public.households;
create policy household_insert_owner on public.households for insert to authenticated with check (owner_id=auth.uid());
drop policy if exists household_update_admin on public.households;
create policy household_update_admin on public.households for update to authenticated
using (exists(select 1 from public.household_members hm where hm.household_id=id and hm.user_id=auth.uid() and hm.role='admin'))
with check (exists(select 1 from public.household_members hm where hm.household_id=id and hm.user_id=auth.uid() and hm.role='admin'));
drop policy if exists hm_select_self_or_admin on public.household_members;
create policy hm_select_self_or_admin on public.household_members for select to authenticated
using (user_id=auth.uid() or exists(select 1 from public.household_members x where x.household_id=household_id and x.user_id=auth.uid() and x.role='admin'));
drop policy if exists hm_insert_self on public.household_members;
create policy hm_insert_self on public.household_members for insert to authenticated with check (user_id=auth.uid());

grant select,insert,update on public.households to authenticated;
grant select,insert on public.household_members to authenticated;

create or replace function public.create_household_invite(p_household_id uuid,p_member_profile_id text,p_can_add_expenses boolean default false)
returns text language plpgsql security definer set search_path=public as $$
declare v_code text;
begin
 if not exists(select 1 from public.household_members where household_id=p_household_id and user_id=auth.uid() and role='admin') then raise exception 'Solo el administrador puede invitar integrantes'; end if;
 v_code := upper(substr(encode(gen_random_bytes(8),'hex'),1,10));
 insert into public.household_invites(code,household_id,member_profile_id,can_add_expenses,created_by) values(v_code,p_household_id,p_member_profile_id,coalesce(p_can_add_expenses,false),auth.uid());
 return v_code;
end; $$;

create or replace function public.join_household(p_code text)
returns uuid language plpgsql security definer set search_path=public as $$
declare inv public.household_invites%rowtype;
begin
 select * into inv from public.household_invites where code=upper(trim(p_code)) and used_by is null and expires_at>now() for update;
 if not found then raise exception 'Código inválido, vencido o ya utilizado'; end if;
 insert into public.household_members(household_id,user_id,role,can_add_expenses,member_profile_id)
 values(inv.household_id,auth.uid(),'member',inv.can_add_expenses,inv.member_profile_id)
 on conflict(household_id,user_id) do update set role='member',can_add_expenses=excluded.can_add_expenses,member_profile_id=excluded.member_profile_id;
 update public.household_invites set used_by=auth.uid() where code=inv.code;
 return inv.household_id;
end; $$;

-- Admins may sync the full household. Members may only add authorized expenses and
-- toggle task completion; they cannot alter payments, budgets, savings, members or old transactions.
create or replace function public.save_household_data(p_household_id uuid,p_data jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
declare old_data jsonb; hm public.household_members%rowtype; item jsonb; old_item jsonb; allowed boolean;
begin
 select * into hm from public.household_members where household_id=p_household_id and user_id=auth.uid();
 if not found then raise exception 'No perteneces a este hogar'; end if;
 select data into old_data from public.households where id=p_household_id;
 if hm.role='admin' then update public.households set data=p_data where id=p_household_id; return true; end if;
 if (p_data->'settings') is distinct from (old_data->'settings') or
    (p_data->'members') is distinct from (old_data->'members') or
    (p_data->'payments') is distinct from (old_data->'payments') or
    (p_data->'budgets') is distinct from (old_data->'budgets') or
    (p_data->'goals') is distinct from (old_data->'goals') or
    (p_data->'contributions') is distinct from (old_data->'contributions') or
    (p_data->'events') is distinct from (old_data->'events') then raise exception 'Permisos insuficientes para modificar esa sección'; end if;
 -- Every old transaction must remain unchanged; new transactions must be authorized expenses.
 for old_item in select value from jsonb_array_elements(coalesce(old_data->'transactions','[]'::jsonb)) loop
   if not exists(select 1 from jsonb_array_elements(coalesce(p_data->'transactions','[]'::jsonb)) n(value) where n.value->>'id'=old_item->>'id' and n.value=old_item) then raise exception 'No puedes editar ni borrar movimientos anteriores'; end if;
 end loop;
 for item in select value from jsonb_array_elements(coalesce(p_data->'transactions','[]'::jsonb)) loop
   if not exists(select 1 from jsonb_array_elements(coalesce(old_data->'transactions','[]'::jsonb)) o(value) where o.value->>'id'=item->>'id') then
     if not hm.can_add_expenses or item->>'type'<>'expense' or coalesce(item->>'memberId','')<>coalesce(hm.member_profile_id,'') then raise exception 'No tienes permiso para registrar este movimiento o asignarlo a otro integrante'; end if;
   end if;
 end loop;
 -- Task list cannot be changed except the done flag.
 if jsonb_array_length(coalesce(p_data->'tasks','[]'::jsonb)) <> jsonb_array_length(coalesce(old_data->'tasks','[]'::jsonb)) then raise exception 'No puedes crear o borrar tareas'; end if;
 for item in select value from jsonb_array_elements(coalesce(p_data->'tasks','[]'::jsonb)) loop
   select value into old_item from jsonb_array_elements(coalesce(old_data->'tasks','[]'::jsonb)) where value->>'id'=item->>'id' limit 1;
   if old_item is null or (old_item-'done') is distinct from (item-'done') then raise exception 'Solo puedes marcar tareas como completadas'; end if;
 end loop;
 update public.households set data=p_data where id=p_household_id; return true;
end; $$;
revoke all on function public.create_household_invite(uuid,text,boolean) from public;
revoke all on function public.join_household(text) from public;
revoke all on function public.save_household_data(uuid,jsonb) from public;
grant execute on function public.create_household_invite(uuid,text,boolean) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant execute on function public.save_household_data(uuid,jsonb) to authenticated;
