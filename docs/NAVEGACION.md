# RepuestosYa - Sistema de Navegación

Este documento detalla la arquitectura y el mapa de rutas del sistema de navegación de la aplicación RepuestosYa.

## Justificación Técnica

Se ha seleccionado **GoRouter** como el motor de enrutamiento principal por las siguientes razones:

1.  **Enrutamiento Declarativo:** Permite definir todas las rutas de la aplicación en un único lugar centralizado (`lib/router/app_router.dart`), mejorando la mantenibilidad.
2.  **Soporte de Deep Linking:** GoRouter está diseñado nativamente para manejar URLs y deep links, lo cual es fundamental para reconstruir el estado de la aplicación desde una dirección específica (ej: `/orden/123`).
3.  **Gestión de Redirecciones:** Facilita la implementación de lógica de protección de rutas (Auth Guard) de forma global, permitiendo redirigir al usuario al login si intenta acceder a una ruta privada sin sesión, y conservar su destino original.
4.  **Parámetros de Ruta:** Obliga a pasar parámetros simples (IDs) a través de la URL en lugar de objetos complejos, asegurando que cada pantalla sea independiente y reconstruible.
5.  **Integración con Provider:** Se sincroniza perfectamente con el estado de autenticación proporcionado por `AuthService` y `UserRoleProvider`.

## Mapa de Rutas

| Dirección | Pantalla | Endpoint Principal | Pública/Privada |
| :--- | :--- | :--- | :--- |
| `/welcome` | `WelcomePage` | - | Pública |
| `/login` | `LoginPage` | `POST /auth/login` | Pública |
| `/registration` | `RegistrationPage` | - | Pública |
| `/registration/cliente` | `RegisterClientePage` | `POST /auth/register` | Pública |
| `/registration/almacen` | `RegisterAlmacenPage` | `POST /auth/register` | Pública |
| `/role-selection` | `RoleSelectionPage` | - | Pública |
| `/home` | `HomePage` | `GET /requests/stats` | Privada (Cliente) |
| `/dashboard` | `WarehouseDashboard` | `GET /requests/active` | Privada (Almacén) |
| `/complete-profile` | `CompleteProfilePage` | `POST /warehouse` | Privada (Almacén) |
| `/profile` | `ProfilePage` | `GET /profiles/:id` | Privada |
| `/profile/addresses` | `AddressesPage` | `GET /direcciones` | Privada (Cliente) |
| `/profile/vehicles` | `VehiclesPage` | `GET /vehiculos` | Privada (Cliente) |
| `/profile/almacen` | `PerfilAlmacenPage` | `GET /warehouse/my-warehouse` | Privada (Almacén) |
| `/request/create` | `CreateRequestPage` | `POST /requests` | Privada (Cliente) |
| `/solicitudes` | `TodasSolicitudesPage` | `GET /requests` | Privada (Cliente) |
| `/solicitudes/:id` | `ReceivedQuotationsPage`| `GET /quotations/request/:id` | Privada (Cliente) |
| `/cotizar/:solicitudId`| `CreateQuotationPage` | `POST /quotations` | Privada (Almacén) |
| `/mis-ordenes` | `MisOrdenesPage` | `GET /orders` | Privada (Cliente) |
| `/orden/:id` | `OrdenCompraPage` | `GET /orders/:id` | Privada (Cliente) |
| `/dashboard/orden/:id` | `AlmacenOrdenDetallePage`| `GET /orders/:id` | Privada (Almacén) |

## Lógica de Redirección (Auth Guard)

El `AppRouter` implementa un `redirect` global que evalúa el estado de autenticación en cada cambio de ruta:

```dart
redirect: (context, state) {
  final bool isAuthenticated = authService.isAuthenticated;
  final bool isLoggingIn = ...; // welcome, login, registration, etc.

  if (!isAuthenticated) {
    if (isLoggingIn) return null;
    // Conservar destino pretendido
    final from = state.matchedLocation;
    return '/welcome?from=$from';
  }

  if (isLoggingIn) {
    return _getHomeRoute(roleProvider.currentRole);
  }

  // Protección por rol
  if (role == UserRole.cliente && location.startsWith('/dashboard')) return '/home';
  if (role == UserRole.almacen && location.startsWith('/home')) return '/dashboard';

  return null;
}
```

## Navegación Anidada y Parámetros

- **Rutas Anidadas:** Se utiliza la jerarquía de `GoRoute` para agrupar rutas relacionadas (ej: `/registration/cliente`).
- **Parámetros de Ruta:** Todas las pantallas de detalle reciben su ID por `pathParameters` (ej: `/orden/:id`).
- **Estado de Navegación:** Para reconstruir pantallas de detalle que requieren datos adicionales (como nombres o imágenes) en deep links, la pantalla implementa una carga perezosa (lazy load) si los datos no se pasan por el parámetro `extra`.
