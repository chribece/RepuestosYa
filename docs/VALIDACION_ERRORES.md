# Validación y Manejo de Errores

Este documento detalla las reglas de validación aplicadas en los formularios y el sistema centralizado de manejo de errores HTTP en RepuestosYa.

## 1. Reglas de Validación (POST /api/requests)

Las validaciones en el frontend se derivan directamente del contrato del backend y reglas de negocio de RepuestosYa.

| Campo | Regla del Contrato | Regla de Negocio / UI | Mensaje de Error |
| :--- | :--- | :--- | :--- |
| `categoria_id` | Obligatorio (UUID) | Selección obligatoria | "Debes seleccionar una categoría para filtrar los repuestos." |
| `repuesto_id` | Obligatorio (UUID) | Selección obligatoria | "Debes seleccionar un repuesto de la lista." |
| `vehiculo_id` | Obligatorio (UUID) | Selección obligatoria | "Debes seleccionar un vehículo de tu garaje para filtrar repuestos compatibles." |
| `direccion_entrega_id` | Obligatorio (UUID) | Selección obligatoria | "Indica dónde deseas recibir el repuesto." |
| `descripcion` | Opcional (String) | Mínimo 10 caracteres | "La descripción es muy corta. Ingresa al menos 10 caracteres (ej: marca, lado, color)." |
| `foto_url` | Opcional (URL) | Subida previa a storage | "No se pudo subir la imagen. Verifica tu conexión." |

## 2. Manejo de Errores de Validación (HTTP 422)

Cuando el backend devuelve un error 422 (Unprocessable Entity), el `ApiErrorHandler` mapea automáticamente los errores a los campos correspondientes.

### Payload Real de Flutter (POST /requests):
La aplicación envía un objeto híbrido que contiene tanto campos del contrato legacy como del nuevo catálogo normalizado.

```json
{
  "pieza_nombre": "...",
  "es_urgente": false,
  "vehiculo_id": "...",
  "descripcion": "...",
  "foto_url": "...",
  "direccion_entrega_id": "...",
  "categoria_id": "...",
  "repuesto_id": "...",
  "repuesto_nombre_snapshot": "...",
  "descripcion_problema": "..."
}
```

### Formato del Backend normalizado (422):
```json
{
  "message": "Errores de validación",
  "errors": [
    { "field": "vehiculo_id", "message": "El vehículo seleccionado no es válido. Selecciona un vehículo de tu garaje." },
    { "field": "descripcion_problema", "message": "La descripción del problema debe tener al menos 10 caracteres." }
  ]
}
```

### Ejemplos de errores por campo:
- **vehiculo_id:** "El vehículo seleccionado no es válido o no pertenece a tu cuenta."
- **direccion_entrega_id:** "La dirección seleccionada no es válida. Selecciona una dirección registrada."
- **categoria_id:** "La categoría seleccionada no es válida. Selecciona una categoría del catálogo."
- **repuesto_id:** "El repuesto seleccionado no es válido. Selecciona un repuesto del catálogo."

## 3. Códigos de Estado y Comportamiento Centralizado

| Código | Significado | Comportamiento en la App |
| :--- | :--- | :--- |
| **400** | Bad Request | Error genérico o fallo inesperado de negocio. |
| **401** | Unauthorized | Sesión expirada. Se limpia el token localmente y se redirige a `/welcome`. |
| **403** | Forbidden | Sin permisos. Se muestra un SnackBar persistente pero **no se cierra la sesión**. |
| **422** | Unprocessable Entity | Error de validación. Los errores se mapean a los campos del formulario. |
| **500** | Server Error | Error crítico del servidor. Se muestra un mensaje de reintento. |

## 4. Persistencia del Formulario

Se ha implementado un `CreateRequestProvider` (ChangeNotifier) para gestionar el estado del formulario de creación de solicitudes.

### Justificación:
Se eligió **Provider/ChangeNotifier** sobre `PageStorageKey` porque:
1.  **Mantenibilidad:** Separa la lógica de datos de la UI.
2.  **Persistencia Robusta:** El estado sobrevive si el widget es destruido (ej. al navegar a una página de ayuda y volver, o al cambiar de app temporalmente).
3.  **Limpia Fácil:** Permite llamar a `provider.clear()` tras un envío exitoso de forma centralizada.
