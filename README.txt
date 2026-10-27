MI HOGAR 360 — DESDE CERO

Contenido:
- index.html: aplicación web adaptable a escritorio y móvil.

Cómo probar:
1. Extrae el ZIP en una carpeta nueva.
2. Abre index.html con Chrome o Edge.
3. Pulsa + Movimiento para registrar ingresos y gastos.
4. Prueba Nueva tarea, Crear objetivo y Añadir evento.
5. Copia de seguridad descarga un archivo JSON con los datos.

Datos y límites:
- Esta primera versión guarda los datos en localStorage del navegador y dispositivo.
- No hay sincronización entre dispositivos ni inicio de sesión todavía.
- El panel muestra miembros de familia de ejemplo; no contiene datos personales reales.
- Para publicar como sitio se puede subir el contenido a GitHub Pages. Para instalar como PWA y habilitar service worker será necesario añadir manifest, iconos y service worker en una siguiente fase.
- No subas respaldos JSON con datos familiares a repositorios públicos.
