# Catálogo Normalizado de Repuestos - RepuestosYa

Este documento detalla la implementación del sistema de categorización y normalización de repuestos para evitar errores de tipeo y mejorar la calidad de los datos en las solicitudes.

## Modelo de Datos

### Tabla: `categorias_repuestos`
Almacena las categorías principales del catálogo.
- `id`: UUID (PK)
- `nombre`: Nombre de la categoría (ej: Frenos)
- `slug`: Identificador amigable (ej: frenos)
- `descripcion`: Descripción opcional
- `activo`: Estado de la categoría

### Tabla: `repuestos_catalogo`
Almacena las piezas o repuestos normalizados asociados a una categoría.
- `id`: UUID (PK)
- `categoria_id`: Referencia a `categorias_repuestos`
- `nombre`: Nombre oficial de la pieza (ej: Pastillas de freno)
- `slug`: Identificador amigable
- `sinonimos`: Array de textos para mejorar la búsqueda (ej: ["balatas", "pastillas"])
- `activo`: Estado del repuesto

### Tabla: `solicitudes_repuesto` (Actualización)
Se han añadido campos para soportar la normalización manteniendo compatibilidad legacy:
- `categoria_id`: UUID (FK) opcional.
- `repuesto_id`: UUID (FK) opcional.
- `repuesto_nombre_snapshot`: Texto que guarda el nombre del repuesto al momento de la creación (redundancia para integridad histórica).
- `descripcion_problema`: Texto libre para detalles adicionales del cliente.

## Endpoints del Catálogo

### 1. Obtener Categorías
`GET /api/catalog/part-categories`
- **Descripción**: Devuelve todas las categorías activas ordenadas alfabéticamente.
- **Acceso**: Usuarios autenticados.

### 2. Obtener Repuestos
`GET /api/catalog/parts`
- **Parámetros Query**:
  - `category_id`: (Opcional) Filtrar por categoría.
  - `q`: (Opcional) Buscar por nombre o sinónimos.
- **Descripción**: Devuelve repuestos activos filtrados y ordenados.
- **Acceso**: Usuarios autenticados.

## Creación de Solicitudes (Contrato Actualizado)

`POST /api/requests`

### Cuerpo de la petición (Nuevo flujo):
```json
{
  "vehiculo_id": "UUID",
  "categoria_id": "UUID",
  "repuesto_id": "UUID",
  "repuesto_nombre_snapshot": "Pastillas de freno",
  "descripcion_problema": "Ruido al frenar en las ruedas delanteras",
  "foto_url": "URL",
  "direccion_entrega_id": "UUID",
  "es_urgente": false
}
```

### Compatibilidad Legacy:
El backend sigue aceptando `pieza_nombre` y `descripcion`. Si se envía `repuesto_id`, el sistema:
1. Valida que el repuesto exista y esté activo.
2. Si no se envía `repuesto_nombre_snapshot`, usa el nombre del catálogo.
3. Si no se envía `pieza_nombre`, usa el nombre del catálogo para mantener compatibilidad con sistemas que solo leen `pieza_nombre`.

## Seed Inicial
El sistema incluye categorías y repuestos base para:
- Frenos
- Motor
- Suspensión
- Transmisión
- Eléctrico
- Carrocería
- Lubricantes y fluidos
- Filtros

---
*Implementado por Devin para RepuestosYa (Agosto 2026)*

## Implementación en Flutter

Se ha refactorizado el flujo de creación de solicitudes para utilizar el catálogo normalizado.

### Componentes y Servicios
- **`CatalogService`**: Gestiona las llamadas a los nuevos endpoints del catálogo.
- **`RyDropdownField`**: Nuevo componente de UI genérico para selección de categorías y repuestos.
- **Modelos**: `PartCategory` y `CatalogPart` mapean las respuestas del backend.

### Flujo de Usuario (Crear Solicitud)
1. El usuario selecciona una **Categoría** de una lista precargada.
2. Se cargan los **Repuestos** asociados a esa categoría.
3. El usuario selecciona el repuesto específico.
4. El campo `pieza_nombre` (legacy) se llena automáticamente con el nombre oficial.
5. El usuario puede añadir **Detalles adicionales** en un campo de texto libre (mapeado a `descripcion_problema`).

### Visualización y Fallback Legacy
Para asegurar que las solicitudes antiguas sigan siendo legibles, se ha implementado una lógica de fallback en el modelo `Solicitud` y en las pantallas de visualización (`Home`, `Mis Solicitudes`, `Dashboard Almacén`):

- **Nombre del Repuesto**:
  - Prioridad 1: `repuesto_nombre_snapshot`
  - Prioridad 2: `pieza_nombre` (legacy)
- **Descripción**:
  - Prioridad 1: `descripcion_problema`
  - Prioridad 2: `descripcion` (legacy)

Esto garantiza una transición fluida mientras se normalizan los datos históricos.
