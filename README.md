# Mi Hogar 360 v2 — Base funcional

Esta es una base inicial funcional para validar la estructura del producto. No es una implementación final ni incluye sincronización en la nube.

## Ejecutar localmente
Puede abrir `index.html` directamente en Chrome/Edge para probar la interfaz y el almacenamiento local. Para probar PWA/service worker, sírvalo desde un servidor local o GitHub Pages.

## Funciones disponibles en esta base
- Registrar ingresos, gastos y movimientos de ahorro.
- Dashboard con métricas y gráficos generados a partir de los movimientos.
- Filtrado por mes y búsqueda de movimientos.
- Presupuesto por categoría.
- Asignación mensual por hijo (perfiles de ejemplo Hijo 1–3).
- Objetivos de ahorro y aportaciones.
- Tareas locales.
- Exportación de respaldo JSON, restauración validada y exportación CSV.

## Limitaciones conocidas / siguiente trabajo
- Almacenamiento inicial en `localStorage` para mantener la primera entrega sencilla; migrar a IndexedDB antes de guardar grandes volúmenes.
- Los nombres de hijos son perfiles de demostración editables en una fase posterior.
- El registro de gasto asociado a hijo y el control de asignaciones necesita una regla contable configurable para evitar doble conteo; en esta base se muestran advertencias y se mantienen los movimientos únicos.
- No hay cuentas, roles seguros ni sincronización remota implementada.
- Recordatorios recurrentes y permisos multiusuario son futuros.
- Los datos locales se guardan en el perfil del navegador y pueden perderse si se borra el almacenamiento del sitio. Exporta respaldos periódicamente.

## Pruebas manuales mínimas
1. Registrar ingreso de $2,000.
2. Registrar gasto pagado de $150.
3. Confirmar balance de $1,850.
4. Crear presupuesto para Alimentación y comprobar progreso.
5. Asignar presupuesto a un hijo.
6. Crear objetivo y registrar aportación.
7. Exportar JSON, probar importación en un perfil de prueba.
8. Revisar layout móvil a 375px.
