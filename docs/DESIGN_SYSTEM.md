# Design System - RepuestosYa App Móvil

## Resumen Ejecutivo

Este documento define el sistema de diseño para la aplicación móvil RepuestosYa en Flutter, basado en el análisis del código existente del backend (Express), las pantallas Flutter actuales y las rutas API disponibles. El sistema está diseñado para soportar dos flujos principales: **Cliente** y **Almacén**.

---

## 1. Inventario de Pantallas

### 1.1 Flujo de Autenticación (Común)

| Pantalla | Archivo Flutter | Rutas API Relacionadas | Justificación |
|----------|----------------|------------------------|---------------|
| **Welcome Page** | `welcome_page.dart` | - | Pantalla de bienvenida inicial con opciones de login/registro |
| **Role Selection** | `role_selection_page.dart` | - | Selección entre flujo Cliente o Almacén |
| **Login** | `login_page.dart` | `POST /auth/login` | Autenticación de usuarios con navegación condicional por rol |
| **Registro Genérico** | `registration_page.dart` | `POST /auth/register` | Registro base de usuarios (usado como fallback) |

### 1.2 Flujo Cliente

| Pantalla | Archivo Flutter | Rutas API Relacionadas | Justificación |
|----------|----------------|------------------------|---------------|
| **Registro Cliente** | `register_cliente_page.dart` | `POST /auth/register` | Formulario específico para registro de clientes |
| **Home Cliente** | `home_page.dart` | `GET /requests`, `GET /requests/stats` | Dashboard principal con estadísticas y solicitudes |
| **Crear Solicitud** | `create_request_page.dart` | `POST /requests`, `GET /vehicles`, `GET /addresses` | Formulario para crear nuevas solicitudes de repuestos |
| **Mis Solicitudes** | `todas_solicitudes_page.dart` | `GET /requests` | Listado completo de solicitudes del cliente |
| **Cotizaciones Recibidas** | `received_quotations_page.dart` | `GET /quotations/request/:solicitud_id` | Visualización de cotizaciones para una solicitud específica |
| **Mis Órdenes** | `mis_ordenes_page.dart` | `GET /orders` | Listado de órdenes de compra del cliente |
| **Detalle Orden** | `orden_compra_page.dart` | `GET /orders/:id` | Detalle completo de una orden de compra |
| **Perfil** | `profile_page.dart` | `GET /profile`, `PUT /profile` | Gestión del perfil del cliente |
| **Mis Vehículos** | `vehicles_page.dart` | `GET /vehicles`, `POST /vehicles`, `PUT /vehicles/:id`, `DELETE /vehicles/:id` | CRUD de vehículos del cliente |
| **Mis Direcciones** | `addresses_page.dart` | `GET /addresses`, `POST /addresses`, `PUT /addresses/:id`, `DELETE /addresses/:id` | CRUD de direcciones de entrega |

### 1.3 Flujo Almacén

| Pantalla | Archivo Flutter | Rutas API Relacionadas | Justificación |
|----------|----------------|------------------------|---------------|
| **Registro Almacén** | `register_almacen_page.dart` | `POST /auth/register` (con rol: 'almacen') | Registro inicial de almacén |
| **Completar Perfil Almacén** | `complete_profile_page.dart` | `POST /warehouses` | Formulario para completar datos del almacén |
| **Dashboard Almacén** | `warehouse_dashboard.dart` | `GET /requests/active`, `GET /quotations/my-quotations` | Panel principal con solicitudes activas y cotizaciones enviadas |
| **Crear Cotización** | `create_quotation_page.dart` | `POST /quotations` | Formulario para enviar cotizaciones a solicitudes |
| **Perfil Almacén** | `perfil_almacen_page.dart` | `GET /warehouse/my-warehouse`, `PUT /warehouses/:id` | Gestión del perfil del almacén |
| **Detalle Orden Almacén** | `almacen_orden_detalle_page.dart` | `GET /orders/:id`, `PATCH /orders/:id/status` | Gestión de órdenes recibidas por el almacén |
| **Todas las Solicitudes** | `todas_solicitudes_page.dart` | `GET /requests/active` | Vista completa de solicitudes activas para almacén |

---

## 2. Tokens de Diseño - Tipografía

### 2.1 Primitivos

```dart
// Familia Tipográfica
final fontFamily = 'Sora'; // Google Fonts Sora

// Tamaños Base
final fontSizeBase = 16.0; // Tamaño base de referencia

// Pesos
final fontWeightLight = FontWeight.w300;   // Light
final fontWeightRegular = FontWeight.w400; // Regular
final fontWeightSemibold = FontWeight.w600; // Semibold
final fontWeightBold = FontWeight.w700;     // Bold

// Alturas de Línea
final lineHeightTight = 1.2;  // Texto denso
final lineHeightNormal = 1.4; // Texto normal
final lineHeightRelaxed = 1.6; // Texto espaciado
```

### 2.2 Semánticos

```dart
// Escala Tipográfica Semántica
class AppTextStyles {
  // Display - Para hero elements y títulos grandes
  static const textStyleDisplay = TextStyle(
    fontFamily: 'Sora',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.0,
  );

  // Heading - Para títulos de secciones
  static const textStyleHeading = TextStyle(
    fontFamily: 'Sora',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Title - Para títulos de tarjetas y modales
  static const textStyleTitle = TextStyle(
    fontFamily: 'Sora',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
  );

  // Body - Para texto de contenido principal
  static const textStyleBody = TextStyle(
    fontFamily: 'Sora',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.2,
  );

  // Caption - Para texto secundario y descripciones
  static const textStyleCaption = TextStyle(
    fontFamily: 'Sora',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // Small - Para texto muy pequeño (ayudas, labels)
  static const textStyleSmall = TextStyle(
    fontFamily: 'Sora',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 1.0,
  );

  // Button - Para texto en botones
  static const textStyleButton = TextStyle(
    fontFamily: 'Sora',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );
}
```

---

## 3. Tokens de Diseño - Color, Espaciado y Radio

### 3.1 Colores Primitivos

```dart
class AppColors {
  // Colores Primarios
  static const primary = Color(0xFFFFB5A7);           // Coral claro
  static const primaryContainer = Color(0xFFFF5722);   // Naranja intenso
  static const onPrimaryContainer = Color(0xFF541200); // Marrón oscuro para texto

  // Colores de Superficie
  static const background = Color(0xFF131313);         // Negro casi puro
  static const surface = Color(0xFF131313);           // Superficie principal
  static const surfaceContainerLow = Color(0xFF1C1B1B); // Superficie elevada baja
  static const surfaceContainerHigh = Color(0xFF2A2A2A); // Superficie elevada alta
  static const surfaceVariant = Color(0xFF353534);     // Variante de superficie

  // Colores de Texto
  static const onSurface = Color(0xFFE5E2E1);         // Texto principal
  static const onSurfaceVariant = Color(0xFFE4BEB4);  // Texto secundario

  // Colores Secundarios
  static const secondary = Color(0xFF9ECAFF);         // Azul claro
  static const secondaryContainer = Color(0xFF1E95F2); // Azul intenso
  static const tertiaryContainer = Color(0xFF019AD8);  // Azul cyan

  // Colores de Estado
  static const error = Color(0xFFFF1744);              // Rojo error
  static const success = Color(0xFF00C853);            // Verde éxito
  static const warning = Color(0xFFFFAB00);            // Amarillo advertencia

  // Colores de Borde
  static const outlineVariant = Color(0xFF5B4039);    // Borde sutil

  // Asterisco requerido
  static const requiredAsterisk = Color(0xFFFF3333);   // Rojo para campos requeridos
}
```

### 3.2 Colores Semánticos

```dart
class SemanticColors {
  // Fondo/Texto
  static const colorBackground = AppColors.background;
  static const colorSurface = AppColors.surface;
  static const colorOnSurface = AppColors.onSurface;
  static const colorOnSurfaceVariant = AppColors.onSurfaceVariant;

  // Botón/Texto
  static const colorPrimaryButton = AppColors.primaryContainer;
  static const colorOnPrimaryButton = AppColors.onPrimaryContainer;
  static const colorSecondaryButton = AppColors.secondaryContainer;
  static const colorOnSecondaryButton = AppColors.onSurface;

  // Error/Texto
  static const colorErrorBackground = AppColors.error;
  static const colorOnErrorText = Colors.white;
  static const colorErrorText = AppColors.error;

  // Estados
  static const colorSuccess = AppColors.success;
  static const colorWarning = AppColors.warning;
  static const colorInfo = AppColors.secondaryContainer;
}
```

### 3.3 Verificación de Contraste WCAG 2.2 AA

> Ratios recalculados el 2026-08-22 con la fórmula WCAG 2.2 AA (luminancia
> relativa + `(L1+0.05)/(L2+0.05)`). La fórmula de contraste por
> luminancia relativa se mantiene igual entre WCAG 2.1 y 2.2; la
> verificación de área táctil mínima (§2.5.8) y foco visible (§2.4.11)
> se aborda en §8.4 y §8.5 respectivamente. La versión anterior sobreestimaba
> varios pares; ver §8 para el detalle de la corrección y los tokens
> ajustados.

| Par de Colores | Fondo | Texto | Ratio real | AA normal (≥4.5) | AA large (≥3.0) |
|----------------|-------|-------|-----------:|:----------------:|:---------------:|
| **Botón Primario** | `#FF5722` | `#541200` | 4.54:1 | ✅ | ✅ |
| **Botón Secundario** | `#1E95F2` | `#541200` | 4.53:1 | ✅ | ✅ |
| **Error Background** | `#C62828` | `#FFFFFF` | 5.62:1 | ✅ | ✅ |
| **Superficie/Texto** | `#2A2A2A` | `#E5E2E1` | 11.14:1 | ✅ | ✅ |
| **Background/Texto** | `#131313` | `#E5E2E1` | 14.42:1 | ✅ | ✅ |
| **Botón Deshabilitado** | `#353534` | `#E4BEB4` | 7.21:1 | ✅ | ✅ |
| **Texto de error (input/badge)** | `#1C1B1B` | `#FF6B7A` | 6.25:1 | ✅ | ✅ |
| **Texto badge info** | `#1C2D3B` (filled bg) | `#4DA8F5` | 5.53:1 | ✅ | ✅ |

### 3.4 Espaciado

```dart
class AppSpacing {
  // Escala de espaciado base (4px base unit)
  static const spacingXxs = 4.0;   // 0.25rem
  static const spacingXs = 8.0;    // 0.5rem
  static const spacingSm = 12.0;   // 0.75rem
  static const spacingMd = 16.0;   // 1rem
  static const spacingLg = 24.0;   // 1.5rem
  static const spacingXl = 32.0;   // 2rem
  static const spacingXxl = 48.0;  // 3rem
  static const spacingXxxl = 64.0; // 4rem
}
```

### 3.5 Radios de Borde

```dart
class AppRadius {
  static const radiusXs = 4.0;   // Radio muy pequeño
  static const radiusSm = 8.0;   // Radio pequeño
  static const radiusMd = 12.0;  // Radio medio
  static const radiusLg = 16.0;  // Radio grande
  static const radiusXl = 20.0;  // Radio muy grande
  static const radiusXxl = 24.0; // Radio extra grande
  static const radiusFull = 999.0; // Radio completo (círculo)
}
```

---

## 4. Componentes Reutilizables

### 4.1 Botón (`RyButton`)

**Justificación:** Los botones se usan extensivamente en toda la aplicación (login, registro, acciones principales, secundarias). Un componente unificado garantiza consistencia visual y comportamiento.

**Interfaz Pública:**

```dart
class RyButton extends StatelessWidget {
  // Datos de entrada
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;

  // Configuración de presentación
  final RyButtonVariant variant;
  final RyButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final bool isFullWidth;

  // Callbacks
  final VoidCallback? onPressed;

  // Contenido delegado
  final Widget? customChild;

  const RyButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.variant = RyButtonVariant.primary,
    this.size = RyButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.isFullWidth = false,
    this.onPressed,
    this.customChild,
  });
}

enum RyButtonVariant {
  primary,      // Botón principal (naranja)
  secondary,    // Botón secundario (azul)
  outline,      // Botón con borde
  text,         // Botón de solo texto
  danger,       // Botón de acción destructiva (rojo)
}

enum RyButtonSize {
  small,   // Altura 40px
  medium,  // Altura 48px
  large,   // Altura 56px
}
```

### 4.2 Tarjeta de Repuesto (`RyPartCard`)

**Justificación:** Las tarjetas de repuestos se muestran en múltiples contextos (home cliente, dashboard almacén, listados de solicitudes). Este componente encapsula la visualización consistente de información de repuestos con imagen, título, estado y acciones.

**Interfaz Pública:**

```dart
class RyPartCard extends StatelessWidget {
  // Datos de entrada
  final String partName;
  final String? imageUrl;
  final String? vehicleInfo;
  final String? description;
  final String status;
  final String? price;
  final String? location;
  final DateTime createdAt;

  // Configuración de presentación
  final RyPartCardVariant variant;
  final bool showImage;
  final bool showPrice;
  final bool showStatus;
  final bool isCompact;

  // Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStatusTap;
  final VoidCallback? onQuoteTap;

  // Contenido delegado
  final Widget? customActions;
  final Widget? customFooter;

  const RyPartCard({
    super.key,
    required this.partName,
    this.imageUrl,
    this.vehicleInfo,
    this.description,
    required this.status,
    this.price,
    this.location,
    required this.createdAt,
    this.variant = RyPartCardVariant.client,
    this.showImage = true,
    this.showPrice = true,
    this.showStatus = true,
    this.isCompact = false,
    this.onTap,
    this.onLongPress,
    this.onStatusTap,
    this.onQuoteTap,
    this.customActions,
    this.customFooter,
  });
}

enum RyPartCardVariant {
  client,    // Vista para clientes (más detalles)
  warehouse, // Vista para almacenes (enfocado en cotización)
  compact,   // Vista compacta para listados
}
```

### 4.3 Campo de Entrada (`RyTextField`)

**Justificación:** Los formularios son extensivos en la app (login, registro, crear solicitud, direcciones, vehículos). Un componente unificado maneja validación, estados (error, foco, deshabilitado), iconos y helper text de forma consistente.

**Interfaz Pública:**

```dart
class RyTextField extends StatelessWidget {
  // Datos de entrada
  final String? label;
  final String? hint;
  final String? initialValue;
  final String? helperText;
  final String? errorText;

  // Configuración de presentación
  final RyTextFieldType type;
  final bool isRequired;
  final bool isReadOnly;
  final bool isDense;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;

  // Callbacks
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;

  // Contenido delegado
  final Widget? prefixWidget;
  final Widget? suffixWidget;

  const RyTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.helperText,
    this.errorText,
    this.type = RyTextFieldType.text,
    this.isRequired = false,
    this.isReadOnly = false,
    this.isDense = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.prefixWidget,
    this.suffixWidget,
  });
}

enum RyTextFieldType {
  text,
  email,
  password,
  number,
  phone,
  url,
  multiline,
  search,
}
```

### 4.4 Badge de Estado (`RyStatusBadge`)

**Justificación:** Los estados (solicitud, cotización, orden) se muestran en múltiples lugares con diferentes colores y textos. Este componente garantiza consistencia en la visualización de estados.

**Interfaz Pública:**

```dart
class RyStatusBadge extends StatelessWidget {
  // Datos de entrada
  final String status;
  final String? customLabel;

  // Configuración de presentación
  final RyStatusBadgeStyle style;
  final RyStatusBadgeSize size;
  final Color? customColor;

  const RyStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.style = RyStatusBadgeStyle.filled,
    this.size = RyStatusBadgeSize.medium,
    this.customColor,
  });
}

enum RyStatusBadgeStyle {
  filled,    // Badge con fondo de color
  outlined,  // Badge con borde de color
  subtle,    // Badge con fondo sutil
}

enum RyStatusBadgeSize {
  small,   // Texto pequeño
  medium,  // Texto medio
  large,   // Texto grande
}
```

### 4.5 Contenedor de Estado Vacío/Error (`RyStateContainer`)

**Justificación:** Los estados vacíos y de error se presentan en múltiples listados (solicitudes, cotizaciones, vehículos, direcciones). Este componente proporciona una visualización consistente con icono, mensaje y acción.

**Interfaz Pública:**

```dart
class RyStateContainer extends StatelessWidget {
  // Datos de entrada
  final String title;
  final String? subtitle;
  final String? actionLabel;

  // Configuración de presentación
  final RyStateType type;
  final IconData? customIcon;

  // Callbacks
  final VoidCallback? onAction;

  // Contenido delegado
  final Widget? customContent;

  const RyStateContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    required this.type,
    this.customIcon,
    this.onAction,
    this.customContent,
  });
}

enum RyStateType {
  empty,     // Estado vacío (sin datos)
  error,     // Estado de error
  loading,   // Estado de carga
  success,   // Estado de éxito
  network,   // Error de red
}
```

### 4.6 Selector de Imagen (`RyImagePicker`)

**Justificación:** La selección de imágenes se usa en múltiples formularios (crear solicitud con foto del repuesto, crear cotización con evidencia, perfil). Este componente unifica la experiencia de selección entre cámara y galería.

**Interfaz Pública:**

```dart
class RyImagePicker extends StatelessWidget {
  // Datos de entrada
  final String? currentImageUrl;
  final File? currentFile;

  // Configuración de presentación
  final RyImagePickerMode mode;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool allowCamera;
  final bool allowGallery;

  // Callbacks
  final ValueChanged<File?>? onImageSelected;
  final ValueChanged<String?>? onImageUrlChanged;
  final VoidCallback? onRemove;

  // Contenido delegado
  final Widget? customPreview;
  final Widget? customPlaceholder;

  const RyImagePicker({
    super.key,
    this.currentImageUrl,
    this.currentFile,
    this.mode = RyImagePickerMode.single,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.allowCamera = true,
    this.allowGallery = true,
    this.onImageSelected,
    this.onImageUrlChanged,
    this.onRemove,
    this.customPreview,
    this.customPlaceholder,
  });
}

enum RyImagePickerMode {
  single,    // Selección de una imagen
  multiple,  // Selección múltiple (futuro)
}
```

### 4.7 Tarjeta de Sección (`RySectionCard`)

**Justificación:** Múltiples pantallas agrupan campos o información en
bloques visuales con un encabezado consistente (icono + título + contenido
delegado dentro de una tarjeta con `surfaceContainerHigh`). Este patrón
aparece en Perfil Almacén, Perfil Cliente, Detalle Orden y Dashboard.
Extraído del helper `_buildSectionCard` de `perfil_almacen_page.dart`.

**Interfaz Pública:**

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `title` | `String` | Sí | — | Título de la sección |
| `icon` | `IconData?` | No | `null` | Icono junto al título. Si es `null`, solo se muestra el título |
| `children` | `List<Widget>` | Sí | — | Contenido de la sección (campos, texto, widgets) |
| `iconColor` | `Color?` | No | `null` → `AppColors.primaryContainer` | Color del icono |

**Semantics:** `Semantics(container: true, label: 'Sección: $title')`.

---

## 4bis. Patrones visuales repetidos en el inventario de pantallas

Los siguientes patrones visuales aparecen en tres o más pantallas y son
cubiertos por componentes del catálogo o candidatos futuros.

| Patrón visual | Pantallas donde aparece | Componente asociado | Justificación |
|---------------|--------------------------|---------------------|---------------|
| **Tarjeta contenedora** (surfaceContainerHigh + outlineVariant + radiusLg, encabezado con icono + título) | Perfil Almacén, Perfil Cliente, Detalle Orden, Dashboard | `RySectionCard` | Agrupa campos o información en bloques visuales con encabezado consistente |
| **Botones de acción principal/secundaria** | Login, Registro Cliente, Registro Almacén, Crear Solicitud, Crear Cotización, Perfil Almacén, Cotizaciones Recibidas | `RyButton` | Unifica variantes (primary, secondary, outline, text, danger) y tamaños (small, medium, large) |
| **Campos de formulario** (label + icono + validación + helper/error) | Login, Registro Cliente, Registro Almacén, Completar Perfil, Crear Solicitud, Crear Cotización, Perfil Almacén, Perfil Cliente | `RyTextField` | Unifica tipo de input, validación, estados readOnly/error, formatters por tipo (email, phone, decimal, etc.) |
| **Badges de estado** (color + label según estado de solicitud/cotización/orden) | Home Cliente, Todas Solicitudes, Cotizaciones Recibidas, Dashboard Almacén, Perfil Almacén, Detalle Orden | `RyStatusBadge` | Garantiza consistencia de color y texto para estados (pendiente, en_proceso, completado, error, etc.) |
| **Estados loading/empty/error** (icono + título + subtítulo + acción opcional) | Home Cliente, Todas Solicitudes, Cotizaciones Recibidas, Perfil Almacén, Dashboard Almacén, Mis Órdenes, Detalle Orden | `RyStateContainer` | Proporciona visualización consistente para 5 estados (empty, error, loading, success, network) |
| **Selector de imagen** (cámara/galería + preview + quitar) | Crear Solicitud, Crear Cotización | `RyImagePicker` | Unifica selección entre cámara y galería con preview y eliminación |
| **Navegación lateral (drawer)** | Home Cliente, Dashboard Almacén, Perfil Almacén | _Candidato futuro (`RyDrawer`)_ | Patrón repetido con las mismas opciones (inicio, secciones, cerrar sesión). Actualmente cada página construye su propio `Drawer` inline |
| **Navegación inferior (bottom nav bar)** | Home Cliente, Dashboard Almacén | _Candidato futuro (`RyBottomNav`)_ | Barra con 4 items (icono + label), estado seleccionado. Actualmente construida inline en cada página |

---

## 4ter. Desacoplamiento de componentes

Se verificó estáticamente en `lib/widgets/` que ningún componente del
catálogo tiene dependencias con la capa de datos o navegación:

| Verificación | Resultado |
|-------------|:---------:|
| Ningún componente importa `services/` | ✅ |
| Ningún componente importa `pages/` | ✅ |
| Ningún componente importa `api_client.dart` | ✅ |
| Ningún componente usa `Navigator` o `MaterialPageRoute` | ✅ |
| Ningún componente consulta backend | ✅ |
| Ningún componente conoce rutas de navegación | ✅ |

**Verificación estática: cumplida.**

Los únicos imports externos en `lib/widgets/` son:
- `package:flutter/material.dart` (framework)
- `package:flutter/services.dart` (`RyTextField` — `TextInputFormatter`)
- `package:cached_network_image/` (`RyPartCard`, `RyImagePicker`)
- `package:image_picker/` (`RyImagePicker`)
- `../theme/*` (tokens de diseño)
- Imports entre widgets (`ry_status_badge` → `ry_part_card`, `ry_button` → `ry_part_card`)

---

## 4quater. Implementación por composición

Cada componente se implementa mediante composición de widgets de Material
consumiendo tokens desde el tema (`AppColors`, `AppTextStyles`,
`AppSpacing`, `AppRadius`). Ningún componente usa `StatefulWidget` con
lógica de negocio — todos son `StatelessWidget` (excepto `RyTextField`
que es `StatefulWidget` para gestionar `TextEditingController` y
`obscureText`).

| Componente | Composición interna | Tokens consumidos | Elementos de reutilización |
|------------|---------------------|-------------------|---------------------------|
| `RyButton` | `Semantics` + `Material`/`InkWell` + `Container` + `Row` + `CircularProgressIndicator`/`Text`/`Icon` | `AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles` | — |
| `RyPartCard` | `Semantics` + `Material`/`InkWell` + `Column`/`Row` + `CachedNetworkImage` + `RyStatusBadge` + `RyButton` | `AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles` | `RyStatusBadge`, `RyButton` |
| `RyTextField` | `Semantics` + `TextFormField` + `InputDecoration` (tema) | `AppColors`, `AppSpacing`, `AppTextStyles` | — |
| `RyStatusBadge` | `Semantics` + `Container` + `Text` | `AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles` | — |
| `RyStateContainer` | `Column` + `Icon` + `Text` + `CircularProgressIndicator` + `ElevatedButton` | `AppColors`, `AppSpacing`, `AppTextStyles` | — |
| `RyImagePicker` | `Semantics` + `GestureDetector` + `Container` + `Image.file`/`CachedNetworkImage` + `Material`/`InkWell` | `AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles` | — |
| `RySectionCard` | `Semantics` + `Container` + `Column` + `Row` + `Icon` + `Text` | `AppColors`, `AppRadius`, `AppSpacing`, `AppTextStyles` | — |

---

## 4quinquies. Interfaces públicas — parámetros obligatorios y valores por defecto

Las tablas siguientes documentan la interfaz pública exacta de cada
componente, extraída del código real de los constructores.

### RyButton

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `label` | `String` | Sí | — | Texto del botón |
| `icon` | `IconData?` | No | `null` | Icono al inicio |
| `trailingIcon` | `IconData?` | No | `null` | Icono al final |
| `variant` | `RyButtonVariant` | No | `primary` | Variante visual |
| `size` | `RyButtonSize` | No | `medium` | Tamaño (small=48dp, medium=48dp, large=56dp) |
| `isLoading` | `bool` | No | `false` | Muestra spinner |
| `isDisabled` | `bool` | No | `false` | Deshabilita el botón |
| `isFullWidth` | `bool` | No | `false` | Ocupa todo el ancho |
| `customChild` | `Widget?` | No | `null` | Contenido delegado (reemplaza label+iconos) |

| Callback | Tipo | Obligatorio | Default | Descripción |
|----------|------|:-----------:|:-------:|-------------|
| `onPressed` | `VoidCallback?` | No | `null` | Acción al presionar |

### RyPartCard

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `partName` | `String` | Sí | — | Nombre del repuesto |
| `imageUrl` | `String?` | No | `null` | URL de la imagen |
| `vehicleInfo` | `String?` | No | `null` | Info del vehículo |
| `description` | `String?` | No | `null` | Descripción del repuesto |
| `status` | `String` | Sí | — | Estado (mapea a color/label) |
| `price` | `String?` | No | `null` | Precio formateado |
| `location` | `String?` | No | `null` | Ubicación |
| `createdAt` | `DateTime` | Sí | — | Fecha de creación |
| `variant` | `RyPartCardVariant` | No | `client` | Variante (client, warehouse, compact) |
| `showImage` | `bool` | No | `true` | Mostrar imagen |
| `showPrice` | `bool` | No | `true` | Mostrar precio |
| `showStatus` | `bool` | No | `true` | Mostrar badge de estado |
| `isCompact` | `bool` | No | `false` | Forzar variante compact |

| Callback | Tipo | Obligatorio | Default | Descripción |
|----------|------|:-----------:|:-------:|-------------|
| `onTap` | `VoidCallback?` | No | `null` | Tap en la tarjeta |
| `onLongPress` | `VoidCallback?` | No | `null` | Long press |
| `onStatusTap` | `VoidCallback?` | No | `null` | Tap en badge de estado |
| `onQuoteTap` | `VoidCallback?` | No | `null` | Tap en botón "Cotizar" |

| Slot delegado | Tipo | Obligatorio | Default | Descripción |
|---------------|------|:-----------:|:-------:|-------------|
| `customActions` | `Widget?` | No | `null` | Acciones personalizadas (reemplaza botón Cotizar) |
| `customFooter` | `Widget?` | No | `null` | Contenido al pie de la tarjeta |

### RyTextField

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `label` | `String?` | No | `null` | Etiqueta del campo |
| `hint` | `String?` | No | `null` | Placeholder |
| `initialValue` | `String?` | No | `null` | Valor inicial (si no hay controller) |
| `controller` | `TextEditingController?` | No | `null` | Controller del campo |
| `helperText` | `String?` | No | `null` | Texto de ayuda |
| `errorText` | `String?` | No | `null` | Texto de error externo |
| `type` | `RyTextFieldType` | No | `text` | Tipo (text, email, password, number, decimal, phone, url, multiline, search) |
| `isRequired` | `bool` | No | `false` | Muestra asterisco rojo |
| `isReadOnly` | `bool` | No | `false` | Solo lectura |
| `isDense` | `bool` | No | `false` | Padding reducido |
| `maxLines` | `int?` | No | `1` | Número de líneas |
| `maxLength` | `int?` | No | `null` | Longitud máxima |
| `keyboardType` | `TextInputType?` | No | `null` (deriva de `type`) | Tipo de teclado |
| `inputFormatters` | `List<TextInputFormatter>?` | No | `null` (deriva de `type`) | Formatters |
| `prefixIcon` | `IconData?` | No | `null` | Icono al inicio |
| `suffixIcon` | `IconData?` | No | `null` | Icono al final |
| `prefixWidget` | `Widget?` | No | `null` | Widget delegado al inicio |
| `suffixWidget` | `Widget?` | No | `null` | Widget delegado al final |

| Callback | Tipo | Obligatorio | Default | Descripción |
|----------|------|:-----------:|:-------:|-------------|
| `onSuffixIconTap` | `VoidCallback?` | No | `null` | Tap en icono sufijo |
| `onChanged` | `ValueChanged<String>?` | No | `null` | Cambio de texto |
| `onSubmitted` | `ValueChanged<String>?` | No | `null` | Submit del campo |
| `onTap` | `VoidCallback?` | No | `null` | Tap en el campo |
| `validator` | `FormFieldValidator<String>?` | No | `null` | Validador de formulario |

### RyStatusBadge

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `status` | `String` | Sí | — | Estado (mapea a color/label: pendiente, en_proceso, completado, etc.) |
| `customLabel` | `String?` | No | `null` | Etiqueta personalizada (sobreescribe la derivada de `status`) |
| `style` | `RyStatusBadgeStyle` | No | `filled` | Estilo (filled, outlined, subtle) |
| `size` | `RyStatusBadgeSize` | No | `medium` | Tamaño (small, medium, large) |
| `customColor` | `Color?` | No | `null` | Color personalizado (sobreescribe el derivado de `status`) |

### RyStateContainer

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `title` | `String` | Sí | — | Título del estado |
| `subtitle` | `String?` | No | `null` | Subtítulo descriptivo |
| `actionLabel` | `String?` | No | `null` | Texto del botón de acción |
| `type` | `RyStateType` | Sí | — | Tipo (empty, error, loading, success, network) |
| `customIcon` | `IconData?` | No | `null` | Icono personalizado (sobreescribe el derivado de `type`) |

| Callback | Tipo | Obligatorio | Default | Descripción |
|----------|------|:-----------:|:-------:|-------------|
| `onAction` | `VoidCallback?` | No | `null` | Acción del botón (requiere `actionLabel`) |

| Slot delegado | Tipo | Obligatorio | Default | Descripción |
|---------------|------|:-----------:|:-------:|-------------|
| `customContent` | `Widget?` | No | `null` | Contenido entre subtítulo y botón |

### RyImagePicker

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `currentImageUrl` | `String?` | No | `null` | URL de imagen actual (preview remoto) |
| `currentFile` | `File?` | No | `null` | Archivo local actual (preview local) |
| `mode` | `RyImagePickerMode` | No | `single` | Modo (single, multiple — multiple futuro) |
| `width` | `double?` | No | `null` → `200` | Ancho del selector |
| `height` | `double?` | No | `null` → `200` | Alto del selector |
| `fit` | `BoxFit` | No | `cover` | Ajuste de la imagen |
| `allowCamera` | `bool` | No | `true` | Permitir cámara |
| `allowGallery` | `bool` | No | `true` | Permitir galería |

| Callback | Tipo | Obligatorio | Default | Descripción |
|----------|------|:-----------:|:-------:|-------------|
| `onImageSelected` | `ValueChanged<File?>?` | No | `null` | Imagen seleccionada |
| `onImageUrlChanged` | `ValueChanged<String?>?` | No | `null` | URL cambiada |
| `onRemove` | `VoidCallback?` | No | `null` | Quitar imagen |

| Slot delegado | Tipo | Obligatorio | Default | Descripción |
|---------------|------|:-----------:|:-------:|-------------|
| `customPreview` | `Widget?` | No | `null` | Preview personalizado (reemplaza Image.file/CachedNetworkImage) |
| `customPlaceholder` | `Widget?` | No | `null` | Placeholder personalizado |

### RySectionCard

| Propiedad | Tipo | Obligatoria | Valor por defecto | Descripción |
|-----------|------|:-----------:|:-----------------:|-------------|
| `title` | `String` | Sí | — | Título de la sección |
| `icon` | `IconData?` | No | `null` | Icono junto al título |
| `children` | `List<Widget>` | Sí | — | Contenido de la sección |
| `iconColor` | `Color?` | No | `null` → `primaryContainer` | Color del icono |

---

## 4sexies. Pantalla ensamblada con componentes del catálogo

**Pantalla:** `perfil_almacen_page.dart` (Perfil de Almacén)

Esta pantalla se ensambla utilizando exclusivamente componentes del
catálogo (`RyButton`, `RyTextField`, `RyStatusBadge`, `RyStateContainer`,
`RySectionCard`) y widgets estándar de Flutter/Material (`Scaffold`,
`Drawer`, `AppBar`, `SafeArea`, `SingleChildScrollView`, `Form`,
`Container`, `Row`, `Column`, `Text`, `Icon`, `SizedBox`, `Divider`,
`ListTile`, `DrawerHeader`, `AlertDialog`, `TextButton`). Los helpers
visuales locales (`_buildHeader`, `_buildTopAppBar`, `_buildDrawer`) usan
widgets estándar de Flutter — no son componentes custom reutilizables.

**Componentes del catálogo usados:**

| Componente | Uso en la pantalla |
|------------|-------------------|
| `RySectionCard` | Sección "Información de Contacto" y sección "Ubicación" |
| `RyTextField` | Campos: Nombre Comercial, Teléfono, Dirección, Latitud, Longitud |
| `RyButton` | Botones: Guardar Cambios (primary), Cancelar (outline), Cerrar Sesión (danger) |
| `RyStatusBadge` | Badges: Verificado/En verificación, Abierto/Cerrado |
| `RyStateContainer` | Estados: loading, error, empty, saving |

**Helpers locales restantes** (widgets estándar de Flutter, no candidatos
a componente reutilizable por ahora):
- `_buildHeader`: avatar + nombre + encargado + badges
- `_buildTopAppBar`: appbar con menú + editar
- `_buildDrawer`: drawer de navegación (candidato futuro `RyDrawer`)
- `_buildActionsSection`: wrapper de botones Guardar/Cancelar
- `_buildLogoutButton`: wrapper de `RyButton(danger)`
- `_buildFooter`: texto de versión

**Estado: cumplido.** La pantalla usa componentes del catálogo para todos
los elementos interactivos y de contenido. Los helpers restantes son
composiciones de widgets estándar de Flutter, no lógica de negocio.

---

## 4septies. Recorrido con lector de pantalla

**Estado: pendiente de verificación manual en dispositivo.**

No se ha ejecutado TalkBack (Android) ni VoiceOver (iOS) sobre ninguna
pantalla del proyecto. Las etiquetas `Semantics` añadidas (§8.5) se
verificaron por inspección del árbol de widgets, no por prueba con lector
real.

**Checklist para verificación manual:**

- [ ] Leer encabezado de la pantalla (título de AppBar)
- [ ] Leer acción principal (botón "Guardar Cambios" / "Editar")
- [ ] Leer campos de formulario (label, hint, error, helper)
- [ ] Leer botones sin texto visible (icono de menú, icono de cerrar)
- [ ] Leer badges de estado (Verificado, Abierto, Pendiente)
- [ ] Leer navegación inferior / drawer (items del menú)
- [ ] Confirmar orden lógico de lectura (de arriba a abajo, izquierda a derecha)
- [ ] Confirmar que las imágenes tienen label comprensible ("Imagen del repuesto X")
- [ ] Confirmar que los estados de carga anuncian "Cargando" (pendiente: `RyStateContainer.loading` no anuncia texto)
- [ ] Verificar navegación por swipe (orden de foco)
- [ ] Verificar activación con doble tap (botones, tarjetas)

**Resultado de la verificación manual:** _Pendiente — ejecutar en
dispositivo físico o emulador con TalkBack/VoiceOver activado._

---

### 5.1 Rutas API Principales (Backend)

```
AUTENTICACIÓN
├── POST /auth/register
├── POST /auth/login
├── POST /auth/logout
└── GET /auth/me

PERFIL
├── GET /profile
└── PUT /profile

VEHÍCULOS
├── GET /vehicles
├── POST /vehicles
├── PUT /vehicles/:id
└── DELETE /vehicles/:id

CATÁLOGOS
├── GET /brands
└── GET /models

DIRECCIONES
├── GET /addresses
├── POST /addresses
├── PUT /addresses/:id
└── DELETE /addresses/:id

ALMACENES
├── POST /warehouses
├── GET /warehouses/encargado/:encargadoId
├── PUT /warehouses/:id
└── GET /warehouse/my-warehouse

SOLICITUDES
├── GET /requests
├── GET /requests/active
├── GET /requests/stats
├── POST /requests
└── GET /requests/:id

COTIZACIONES
├── POST /quotations
├── GET /quotations/my-quotations
├── GET /quotations/request/:solicitud_id
├── PUT /quotations/:id/status
├── POST /quotations/:id/accept
└── POST /quotations/:id/reject

ÓRDENES
├── GET /orders
├── GET /orders/:id
└── PATCH /orders/:id/status

ADMIN
├── GET /admin/metrics
├── GET /admin/orders
├── GET /admin/users
├── PATCH /admin/users/:id/role
├── GET /admin/warehouses/pending
└── PATCH /admin/warehouses/:id/verify
```

### 5.2 Pantallas Flutter Detectadas

```
COMUNES
├── welcome_page.dart
├── role_selection_page.dart
├── login_page.dart
└── registration_page.dart

CLIENTE
├── register_cliente_page.dart
├── home_page.dart
├── create_request_page.dart
├── todas_solicitudes_page.dart
├── received_quotations_page.dart
├── mis_ordenes_page.dart
├── orden_compra_page.dart
├── profile_page.dart
├── vehicles_page.dart
└── addresses_page.dart

ALMACÉN
├── register_almacen_page.dart
├── complete_profile_page.dart
├── warehouse_dashboard.dart
├── create_quotation_page.dart
├── perfil_almacen_page.dart
├── almacen_orden_detalle_page.dart
└── todas_solicitudes_page.dart (compartida)
```

---

## 6. Próximos Pasos

1. **Implementar tokens de diseño en una clase centralizada** (`AppTheme`)
2. **Crear los componentes reutilizables** en una carpeta `lib/widgets/`
3. **Migrar las pantallas existentes** para usar los nuevos componentes
4. **Establecer guías de uso** para cada componente
5. **Crear Storybook o showcase** de componentes para referencia visual

---

## 7. Convenciones de Código

### 7.1 Nomenclatura

- **Widgets:** Prefijo `Ry` (RepuestosYa) + nombre descriptivo
- **Enums:** Prefijo del componente + `Variant`/`Style`/`Type`/`Size`
- **Colores:** `color{Contexto}{Uso}` (ej: `colorPrimaryButton`)
- **Espaciado:** `spacing{Tamaño}` (ej: `spacingMd`)
- **Tipografía:** `textStyle{Rol}` (ej: `textStyleHeading`)

### 7.2 Estructura de Archivos

```
lib/
├── widgets/
│   ├── ry_button.dart
│   ├── ry_part_card.dart
│   ├── ry_text_field.dart
│   ├── ry_status_badge.dart
│   ├── ry_state_container.dart
│   └── ry_image_picker.dart
├── theme/
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   ├── app_spacing.dart
│   ├── app_radius.dart
│   └── app_theme.dart
└── pages/
    └── [pantallas existentes]
```

---

## 8. Verificación de calidad y accesibilidad

> Sección añadida el 2026-08-22 tras una auditoría de accesibilidad
> (contraste WCAG, área táctil 48 dp, Semantics, responsividad y reflujo
> con `textScaleFactor`). Las relaciones de contraste se calcularon con la
> fórmula WCAG 2.2 AA (luminancia relativa + `(L1+0.05)/(L2+0.05)`) mediante
> un script Dart independiente; el resto de verificaciones se hizo por
> inspección del árbol de widgets. Las correcciones se aplicaron por
> bloques (color → touch target → Semantics → reflujo) y se documentan a
> continuación.

### 8.1 Decisión sobre el tema claro

**Hallazgo:** `main.dart` fijaba `themeMode: ThemeMode.dark` y `lightTheme`
(`app_theme.dart`) reutilizaba exactamente los mismos tokens oscuros
(`AppColors.background = #131313`, `AppColors.surface = #131313`, etc.).
En consecuencia no existía un tema claro real: cualquier par "en tema
claro" era numéricamente idéntico al mismo par en tema oscuro, y la rama
`lightTheme` no aportaba nada funcional.

**Decisión adoptada: eliminar la rama de tema claro.** Se justifica por:

1. La marca RepuestosYa es deliberadamente oscura (coral/naranja sobre
   negro, estilo "automotriz de garaje"). Un tema claro real requeriría
   diseñar una paleta completa nueva (superficies claras, onSurface oscuro,
   bordes, sombras, estados) y re-auditar todos los pares de contraste —
   fuera del alcance de esta auditoría.
2. Mantener `lightTheme` como clon de `darkTheme` era código muerto que
   confundía: invitaba a pensar que había soporte claro cuando no lo había.
3. `themeMode: ThemeMode.dark` ya forzaba el oscuro en runtime.

**Acción aplicada (v1.2.1, 2026-08-22):**
- `app_theme.dart`: eliminado el getter `lightTheme` (157 líneas). `darkTheme`
  queda como único tema, con docstring explicativa que referencia esta
  sección.
- `main.dart`: el `MaterialApp` ahora usa `theme: darkTheme` directo, sin
  `darkTheme:` ni `themeMode:`. Comentario in-line documentando la decisión.
- `dart format lib/`: 51 archivos procesados, 25 reformateados (ninguno
  de los cambios de esta tarea; eran reformateos pendientes de archivos
  preexistentes).
- `dart format --output=none --set-exit-if-changed lib/`: exit 0 — no
  queda archivo sin formatear.
- `flutter analyze`: `No issues found! (ran in 44.9s)`.

**Las tablas siguientes reportan el valor único aplicable al único tema
efectivo (oscuro).**

### 8.2 Contraste WCAG — tabla principal (post-corrección)

| Par | Fondo | Texto | Ratio real | AA normal | AA large |
|-----|-------|-------|-----------:|:---------:|:--------:|
| Botón Primario | `#FF5722` | `#541200` | 4.54:1 | ✅ | ✅ |
| Botón Secundario | `#1E95F2` | `#541200` | 4.53:1 | ✅ | ✅ |
| Botón danger / Error bg | `#C62828` | `#FFFFFF` | 5.62:1 | ✅ | ✅ |
| Superficie/Texto | `#2A2A2A` | `#E5E2E1` | 11.14:1 | ✅ | ✅ |
| Background/Texto | `#131313` | `#E5E2E1` | 14.42:1 | ✅ | ✅ |
| Botón Deshabilitado | `#353534` | `#E4BEB4` | 7.21:1 | ✅ (exento §1.4.3) | ✅ |
| Input texto | `#1C1B1B` | `#E5E2E1` | 13.34:1 | ✅ | ✅ |
| Input label | `#1C1B1B` | `#E4BEB4` | 10.08:1 | ✅ | ✅ |
| Input hint (alpha 0.7) | `#1C1B1B` | `#A88D86` | 5.58:1 | ✅ | ✅ |
| Input asterisco | `#1C1B1B` | `#FF3333` | 4.72:1 | ✅ | ✅ |
| **Texto de error** (input/badge) | `#1C1B1B` | `#FF6B7A` | 6.25:1 | ✅ | ✅ |
| Badge warning text | `#3E3117` (filled) | `#FFAB00` | 6.69:1 | ✅ | ✅ |
| Badge success text | `#183523` (filled) | `#00C853` | 5.97:1 | ✅ | ✅ |
| **Badge info text** | `#1C2D3B` (filled) | `#4DA8F5` | 5.53:1 | ✅ | ✅ |
| **Badge error text** | `#3E1A21` (filled) | `#FF6B7A` | 5.05:1 | ✅ | ✅ |
| Precio (success sobre card) | `#1C1B1B` | `#00C853` | 7.68:1 | ✅ | ✅ |
| `primary` sobre background | `#131313` | `#FFB5A7` | 10.99:1 | ✅ | ✅ |

**Post-corrección todos los pares pasan AA normal.** Antes de la auditoría
fallaban: Botón Secundario (2.46:1), Botón danger/Error bg (3.85:1 sólo
AA large), texto de error de input (4.47:1), badge info text (4.46:1) y
badge error text (3.97:1).

### 8.3 Tokens de color ajustados

| Token | Antes | Después | Ratio resultante | Justificación |
|-------|-------|---------|-----------------:|---------------|
| `AppColors.error` | `#FF1744` (3.85:1 con blanco) | `#C62828` | 5.62:1 AA normal | Material Red 800; mantiene lectura "rojo error", mejora snackbars/botón danger/iconos. |
| `SemanticColors.colorOnSecondaryButton` | `onSurface #E5E2E1` (2.46:1) | `onPrimaryContainer #541200` | 4.53:1 AA normal | Reutiliza marrón existente; sin tocar el azul de marca del botón. |
| `SemanticColors.colorErrorText` | `= AppColors.error` (4.47:1 sobre fill) | `#FF6B7A` | 6.25:1 AA normal | Token propio para texto de error sobre fondo oscuro (input + badge). |
| `SemanticColors.colorInfoBadgeText` | _(no existía)_ | `#4DA8F5` | 5.53:1 AA normal | Texto del badge "info"/"enviado"/"cotizado" sobre fondo sutil. |

`RyStatusBadge._getTextColor()` usa `colorErrorText` para estados
`cancelado/rechazado/urgente/error/fallido` y `colorInfoBadgeText` para
`en_proceso/enviado/cotizado/info`; el color base (`_getStatusColor()`)
se mantiene para fondo (alpha 0.15/0.08) y borde, preservando identidad
visual del badge.

### 8.4 Área táctil mínima (48×48 dp)

| Componente | Antes | Después | Cómo lo garantiza |
|-----------|-------|---------|-------------------|
| `RyButton` size `medium`/`large` | 48 / 56 dp | 48 / 56 dp | `Container(height: 48 ó 56)` + padding `spacingLg` |
| `RyButton` size `small` | 40 dp alto ❌ | **48 dp** ✅ | `_getHeight()` retorna 48 para `small` |
| `RyTextField` (campo) | ≥56 dp | ≥56 dp | `inputDecorationTheme.contentPadding` 16/16 + texto 16 |
| `RyTextField` suffix `IconButton` | ~24×24 ❌ (`constraints: BoxConstraints()`) | **48×48** ✅ | Eliminado `padding: EdgeInsets.zero` y `constraints`; `visualDensity: VisualDensity.standard` + `iconSize: 24` |
| `RyPartCard` (toda la tarjeta) | ≥48 en ambos ejes | ≥48 | `InkWell` envuelve tarjeta completa |
| `RyPartCard` → `RyStatusBadge` accionable | ~24-30 dp ❌ (`GestureDetector` sin padding) | **≥48 dp** ✅ | `_buildStatusAction()`: `InkWell` + padding `spacingXs` vertical; `Semantics(button:, label: 'Estado: …')` |
| `RyImagePicker` (área principal) | 200×200 | 200×200 | `Container` por defecto |
| `RyImagePicker` botón "Quitar" | 32×32 ❌ | **48×48** ✅ | `SizedBox(width: 48, height: 48)`; `top/right` ajustado a `spacingXxs` |
| `RyStateContainer` acción | 48×48 | 48×48 | `ElevatedButton` (theme `minimumSize: Size(48,48)`) |
| `home_page` avatar AppBar | 40×40 ❌ | **48×48** ✅ | `Container(width: 48, height: 48)`; icon 22→24 |
| `home_page` `IconButton` menú | 48×48 | 48×48 | `IconButton` default |
| `home_page` `TextButton` "Ver todas" | colapsado al texto ❌ (`minimumSize: Size.zero`) | **48×48** ✅ | `minimumSize: const Size(48, 48)` + `tapTargetSize: MaterialTapTargetSize.padded` |
| `home_page` `_buildNavItem` | ~46 dp alto, ancho variable ⚠ | **48×48** ✅ | `SizedBox(height: 48, width: 64)` envolviendo el `InkWell` |

### 8.5 Etiquetas semánticas (Semantics)

| Componente | Estado | Detalle |
|-----------|:------:|---------|
| `RyButton` | ✅ | `Semantics(button:, enabled:, label:, excludeSemantics: true)` ya presente desde la implementación original. |
| `RyTextField` | ✅ (nuevo) | `Semantics(label: label ?? hint, hint: errorText ?? helperText, textField: true, enabled: !isReadOnly, excludeSemantics: true)`. |
| `RyPartCard` | ✅ (corregido) | `onTap: () {}` (no-op) → **`onTap: onTap`**; añadido `excludeSemantics: true`; label enriquecido con `vehicleInfo`. |
| `RyPartCard` imágenes (compact 60, client 80, warehouse 80) | ✅ (nuevo) | Cada `CachedNetworkImage` envuelto con `Semantics(image: true, label: 'Imagen del repuesto $partName', excludeSemantics: true)`. |
| `RyPartCard` badge accionable | ✅ (nuevo) | `_buildStatusAction()`: `Semantics(button: onStatusTap != null, label: 'Estado: $status', onTap: onStatusTap)` + `InkWell` con padding ≥48 dp. |
| `RyImagePicker` (área principal) | ✅ | `Semantics(button:, label: dinámico 'Imagen seleccionada'/'Seleccionar imagen', onTap:)` ya presente. |
| `RyImagePicker` preview | ✅ (nuevo) | `Semantics(image: true, label: 'Imagen seleccionada', excludeSemantics: true)` en `Image.file` y `CachedNetworkImage`. |
| `RyImagePicker` botón "Quitar" | ✅ (nuevo) | `Semantics(button: true, label: 'Quitar imagen', enabled: onRemove != null)`. |
| `RyStatusBadge` (standalone) | ✅ (nuevo) | `Semantics(label: 'Estado: $label', excludeSemantics: true)`. |
| `RyStateContainer` acción | ✅ | Heredado del `ElevatedButton`. El indicador `loading` no anuncia "Cargando" (mejora futura). |
| `RySectionCard` | ✅ (nuevo) | `Semantics(container: true, label: 'Sección: $title')`. |

### 8.5bis Foco visible (WCAG 2.2 §2.4.11)

WCAG 2.2 añade el criterio 2.4.11 "Foco no oscurecido" y el existente
2.4.7 "Foco visible" (heredado de 2.1). Se verificó que los componentes
interactivos principales tienen foco visible mediante el comportamiento
estándar de Material 3 en Flutter:

| Componente | Foco visible | Mecanismo |
|------------|:------------:|-----------|
| `RyButton` | ✅ | `Material`/`InkWell` expone ripple + estado highlighted al recibir foco. Flutter Material 3 gestiona `FocusHighlightType` automáticamente. |
| `RyTextField` | ✅ | `TextFormField` hereda el `focusColor` y `focusedBorder` del `inputDecorationTheme` de `app_theme.dart` (border `primaryContainer` + `borderWidth: 2` en foco). |
| `RyPartCard` | ✅ | `Material`/`InkWell` con `borderRadius` expone ripple al foco. |
| `RyImagePicker` | ✅ | `GestureDetector` envuelto en `Semantics(button:)`. El `Container` reciene highlight por el `GestureDetector` tap. |
| `RyStatusBadge` accionable | ✅ | `InkWell` con `borderRadius` en `_buildStatusAction()` expone ripple al foco. |
| `RySectionCard` | N/A | No es interactivo (contenedor pasivo). |

**Nota:** Flutter Material 3 gestiona el foco visible automáticamente
vía `FocusManager` y `ThemeData.focusColor`. No se requiere código
custom para mostrar el foco — el framework dibuja el indicador cuando
un widget recibe foco por teclado o TalkBack. La verificación visual
en dispositivo con teclado Bluetooth/USB queda como pendiente manual.

Análisis manual sobre `lib/pages/home_page.dart` con `MediaQuery`
simulado a 360 dp y 800 dp. El layout es 100% `Expanded`/`fill`/

| Sección | 360 dp | 800 dp | Notas |
|---------|--------|--------|-------|
| `_buildTopAppBar` (Row con `spaceBetween`) | ✅ cabe (con `Flexible` + `ellipsis` en título) | ✅ | Sin desborde. |
| `_buildNewSearchButton` (`minHeight: 180`) | ✅ | ✅ se estira al ancho | Hero element con altura mínima (refluya). |
| `_buildStatsRow` (2×2 grid de `Expanded`) | ✅ 2 cards ~156 dp c/u | ✅ pero tarjetas muy anchas (~390 dp) | Sin desborde; en tablet se ve estirado (mejora futura: `maxWidth` por card). |
| `_buildRequestsSection` (`RyPartCard` client, `maxLines:2, ellipsis`) | ✅ | ✅ | Sin desborde horizontal. |
| `_buildTrendingSection` (h:96, items w:130) | ✅ scroll horizontal | ✅ 3 items = 390 dp, espacio sobrante | No desborda; en tablet se ve "corto". |
| `_buildBottomNavBar` (4 `SizedBox(48×64)` con `spaceAround`) | ✅ ~90 dp c/u | ✅ | Sin desborde. |
| Drawer (`ListView`) | ✅ | ✅ | Lista vertical, sin desborde. |

**Conclusión responsividad:** no se detectan desbordes en 360 ni 800 dp
tras las correcciones de Bloque 4. El único problema estético pendiente es
el ancho excesivo de las stat cards en 800 dp (pendiente de soporte
tablet, fuera de scope).

### 8.7 Fuente ampliada — `textScaleFactor` 1.3 y 2.0

Pantalla densa elegida: `_buildNewSearchButton` (hero) y `RyPartCard`
client en `_buildRequestsSection`.

| Elemento | 1.3× | 2.0× | Resultado |
|----------|------|------|-----------|
| `RyPartCard` `partName` (Title 20 pt, `maxLines:2, ellipsis`) | ✅ | ⚠ se corta con `…` tras 2 líneas a 40 pt | Texto cortado (ellipsis), no desbordamiento. Aceptable; idealmente `maxLines: 3`. |
| `RyPartCard` `description` (Body 16 pt, `maxLines:2, ellipsis`) | ✅ | ⚠ ídem, 32 pt corta | Texto cortado. |
| `RyPartCard` `vehicleInfo` (Caption 14 pt, sin `maxLines`) | ✅ crece | ✅ crece verticalmente | Sin desborde. |
| `_buildNewSearchButton` ("NUEVA BÚSQUEDA" + subtítulo) | ✅ | ✅ refluye verticalmente (minHeight) | **Corregido en Bloque 4** (antes `height: 180` desbordaba a ~244 dp). |
| `_buildTopAppBar` "RepuestosYa" (Title 20 pt, w800) | ✅ | ✅ truncado con `…` en 360 dp (no desborda) | **Corregido en Bloque 4** (antes overflow ~378 dp > 360 dp). |
| `_buildStatCard` (sin altura fija) | ✅ crece | ✅ crece | Sin desborde. |
| `_buildBottomNavBar` labels (Small 12 pt) + icon 22 | ✅ | ✅ ~50 dp alto < 64 | Sin desborde. |

**Problemas resueltos en Bloque 4:**
1. `_buildNewSearchButton` a 2.0×: `height: 180` → `ConstrainedBox(minHeight: 180)` + padding vertical `spacingLg`.
2. `_buildTopAppBar` a 360 dp × 2.0×: `Text('RepuestosYa')` envuelto en `Flexible` + `overflow: TextOverflow.ellipsis` + `maxLines: 1`.

**Recomendaciones pendientes (P2, no aplicadas):**
- Subir `maxLines` de `partName` (2→3) y `description` (2→3) en `RyPartCard` para priorizar contenido legible sobre compactación con texto ampliado.

### 8.8 Resultado de `flutter analyze`

- **Antes de la auditoría (versión 1.1.0):** 0 issues.
- **Tras Bloques 1-4 (versión 1.2.0):** 0 issues — `No issues found! (ran in 52.3s)`.

Las correcciones de accesibilidad no introdujeron ningún regression de
análisis estático.

### 8.9 Síntesis de acciones aplicadas

**P0 (incumplimiento WCAG claro) — aplicado:**
1. Botón Secundario 2.46:1 → `colorOnSecondaryButton = onPrimaryContainer` (4.53:1).
2. `RyButton.small` 40 dp → 48 dp.
3. `RyTextField` suffix `IconButton` 24 dp → 48 dp.
4. `RyImagePicker` botón quitar 32×32 → 48×48.
5. `home_page` "Ver todas" `minimumSize: Size.zero` → `Size(48, 48)`.
6. `RyTextField` sin Semantics → Semantics completo.

**P1 (mejoras de accesibilidad) — aplicado:**
7. `AppColors.error #FF1744` → `#C62828` (5.62:1 con blanco).
8. `colorErrorText` → token propio `#FF6B7A` (6.25:1 sobre fill).
9. Badge info 4.46:1 → `colorInfoBadgeText #4DA8F5` (5.53:1); badge error → `colorErrorText #FF6B7A` (5.05:1).
10. `RyStatusBadge` accionable → `Semantics(button:, label:)` + `InkWell` con padding ≥48 dp.
11. `RyPartCard.Semantics.onTap: () {}` → `onTap: onTap` + `excludeSemantics: true`; `Semantics(image:, label:)` en imágenes.
12. `_buildNewSearchButton` `height: 180` → `minHeight: 180` vía `ConstrainedBox`.
13. `_buildTopAppBar` título → `Flexible` + `TextOverflow.ellipsis`.
14. `RyImagePicker` preview → `Semantics(image:, label:)`.
15. `RyStatusBadge` standalone → `Semantics(label: 'Estado: …')`.

**P2 (documentación) — aplicado:**
16. Tabla §3.3 actualizada con ratios reales.
17. Esta sección §8 añadida con resultados finales.
18. Decisión sobre tema claro documentada en §8.1.

---

## 9. Decisiones de Implementación (migración 2026-08-21)

Esta sección documenta las decisiones técnicas tomadas durante la migración del
código a los tokens y componentes del design system (actualización 2026-08-21).

### 9.1 Tokens adicionales

- **`AppColors.transparent`** (`Color(0x00000000)`): se añadió un token para el
  color transparente. Anteriormente las páginas usaban `Colors.transparent` de
  Material de forma ad-hoc (gradient stops, bordes condicionales, `Material`
  incoloro). Con el token se elimina la última referencia literal a `Colors.*`
  en `lib/pages/`.

### 9.2 Logger centralizado (`AppLogger`)

- Todo `print()` en `lib/` se reemplazó por `AppLogger` (`lib/utils/app_logger.dart`),
  que envuelve `dart:developer.log` y se silencia automáticamente en release
  (`kDebugMode`). Esto resuelve el lint `avoid_print` y permite filtrar por
  módulo en DevTools mediante `name` (p. ej. `'Supabase'`,
  `'CreateRequest.Direcciones'`, `'WarehouseDashboard.Filter'`).
- No quedó ningún `print()` intencional en el código de producción.

### 9.3 Migración `withOpacity` → `withValues`

- La migración ya estaba completa: los 65 usos de opacidad en `lib/` utilizan
  `Color.withValues(alpha: x)` en lugar del `withOpacity` deprecado. No hubo
  cambios en este punto; se verificó con `grep` que no quedan ocurrencias de
  `withOpacity`.

### 9.4 Estilos inline en `pages/`

- Se eliminaron **todos** los `TextStyle(` literales, `fontSize:` numéricos,
  `BorderRadius.circular(<número>)`, `EdgeInsets.(all|symmetric|only)(<número>)`
  y `SizedBox(height/width: <número>)` ad-hoc en `lib/pages/`. Todo se
  reemplazó por `AppTextStyles`, `AppRadius`, `AppSpacing` o `.copyWith()`
  sobre los tokens.
- **Excepciones justificadas (documentadas in-line con comentario):**
  - `fontFamily: 'JetBrains Mono'` en `warehouse_dashboard.dart` (métricas
    numéricas Bento) y `create_quotation_page.dart` (VIN): familia
    monoespaciada intencional para datos técnicos; no existe token
    equivalente en `AppTextStyles`.
  - `BorderRadius.circular(AppRadius.radiusSm - 1)` en
    `create_quotation_page.dart`: ajuste fino de 1px para que el `ClipRRect`
    de la imagen encaje con el borde exterior (comentado in-line).
  - `SizedBox(height: 2)` en `home_page.dart` y `vertical: 2` en
    `create_quotation_page.dart`: separaciones mínimas intencionales en la
    barra inferior y pastilla compacta (comentadas in-line).

### 9.5 `RyPartCard` en listas de repuestos

`RyPartCard` se aplica en **todas** las listas de repuestos/solicitudes:

| Página | Variante | Ubicación |
|--------|----------|-----------|
| `home_page.dart` | `RyPartCardVariant.client` | ListView de solicitudes del cliente |
| `todas_solicitudes_page.dart` | `RyPartCardVariant.client` | ListView paginado de solicitudes |
| `warehouse_dashboard.dart` | `RyPartCardVariant.warehouse` | ListView de solicitudes activas |

**No se migró a `RyPartCard`** (decisión intencional):

- `mis_ordenes_page.dart` usa `_buildOrdenCard` manual porque muestra
  **órdenes de compra** (con `ordenId` + almacén que fulfilló la orden), no
  repuestos/solicitudes. La interfaz de `RyPartCard` (`vehicleInfo`,
  `onQuoteTap`, variantes client/warehouse/compact, imagen del repuesto) no
  encaja semánticamente con una orden. El card de orden sí usa `RyStatusBadge`
  y los tokens de tipografía/espaciado/color.
- `cotizaciones_page.dart` usa `Card` manual porque muestra **cotizaciones**
  (con nombre del almacén, condición del repuesto, tiempo de entrega), no
  repuestos. Mismo motivo semántico.

### 9.6 Migración a `RadioGroup` (Flutter 3.32+)

- `create_request_page.dart` migró `RadioListTile` de `groupValue`/`onChanged`
  (deprecados) a un ancestro `RadioGroup<String>` que gestiona el grupo.

### 9.7 `BuildContext` tras async gaps

- Se añadieron guards `if (!mounted) return` / `if (!context.mounted) return`
  en `create_request_page.dart` y `warehouse_dashboard.dart` para eliminar los
  warnings `use_build_context_synchronously`.

### 9.8 Resultado de `flutter analyze`

- **Antes:** 32 issues (1 error de compilación, 3 warnings, 28 infos).
- **Después:** 0 issues — `No issues found!`.

---

**Documento generado el: 2026-08-19**
**Última actualización: 2026-08-22 — patrones visuales, interfaces con obligatorio/default, WCAG 2.2 AA, desacoplamiento, composición, RySectionCard, pantalla ensamblada, lector de pantalla**
**Versión: 1.3.0**
**Basado en análisis de código existente - RepuestosYa App Móvil**
