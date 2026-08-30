# Guía de Evidencias del Recorrido Completo

Este documento sirve como guía estructurada para capturar las evidencias del funcionamiento del sistema RepuestosYa, cubriendo los flujos principales de cliente, navegación y manejo de errores.

## Recorrido del Cliente y Navegación

| Paso | Acción | Ruta | Endpoint esperado | Evidencia a capturar | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Inicio de sesión | `/login` | `POST /auth/login` | Screenshot del formulario lleno y log de consola con éxito. | Token guardado y transición fluida. |
| 2 | Redirección por Rol | - | - | Screenshot de la pantalla de inicio tras login. | El cliente es enviado a `/home` (no `/dashboard`). |
| 3 | Carga de Estadísticas | `/home` | `GET /requests/stats` | Screenshot de los Bento Cards con números reales. | Estadísticas coinciden con los datos del backend. |
| 4 | Listado de Solicitudes | `/home` | `GET /requests` | Screenshot de la sección "Mis Solicitudes" con `RyPartCard`. | Lista cargada correctamente con scroll infinito. |
| 5 | Detalle de Solicitud | `/solicitudes/:id` | `GET /quotations/request/:id` | Screenshot de la pantalla de cotizaciones recibidas. | Se muestran las ofertas disponibles para esa solicitud. |
| 6 | Detalle de Orden | `/orden/:id` | `GET /orders/:id` | Screenshot de la pantalla de Orden de Compra. | Información detallada del repuesto, precio y almacén. |
| 7 | Inicio de Creación | `/request/create` | `GET /categories` | Screenshot del formulario inicial de búsqueda. | Categorías cargadas en el dropdown. |
| 8 | Validación Local | `/request/create` | - | Screenshot del error en el campo "Descripción" (< 10 chars). | El botón de envío permanece bloqueado o muestra errores. |
| 9 | Persistencia | `/request/create` | - | Video/GIF: llenar campos -> ir a Perfil -> volver. | Los datos ingresados se conservan (Provider activo). |
| 10 | Error de Servidor (422) | `/request/create` | `POST /requests` | Screenshot del error retornado por el backend sobre un campo. | El error del backend se muestra bajo el campo específico. |

## Pruebas de Seguridad y Sesión

| Paso | Acción | Ruta | Endpoint esperado | Evidencia a capturar | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 11 | Prueba de Auth (401) | `/home` | Cualquier GET | Log de consola mostrando 401 y redirección. | Sesión limpiada y usuario enviado a `/welcome`. |
| 12 | Prueba de Permisos (403)| `/dashboard` | `GET /requests/active` | Screenshot del SnackBar de error (Forbidden). | Mensaje "Sin permisos" sin cerrar la sesión. |
| 13 | Cierre de Sesión | Drawer | `POST /auth/logout` | Screenshot del diálogo de confirmación y pantalla final. | Token eliminado y regreso a `/welcome`. |

## Instrucciones para Captura

1.  **Modo Debug:** Asegúrese de tener activa la consola de Flutter para capturar los logs de los endpoints.
2.  **Logs de Payload:** Se pueden verificar los envíos con el prefijo `[POST /requests PAYLOAD]` en la consola.
3.  **Insomnia/Postman:** Para las pruebas de 422 manuales, use el body documentado en `docs/VALIDACION_ERRORES.md`.
4.  **Limpieza:** Antes de iniciar el recorrido, realice un logout para asegurar una sesión limpia.
