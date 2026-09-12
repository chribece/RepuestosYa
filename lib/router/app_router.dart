import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/welcome_page.dart';
import '../pages/role_selection_page.dart';
import '../pages/login_page.dart';
import '../pages/registration_page.dart';
import '../pages/register_cliente_page.dart';
import '../pages/register_almacen_page.dart';
import '../pages/complete_profile_page.dart';
import '../pages/home_page.dart';
import '../pages/onboarding_page.dart';
import '../pages/warehouse_dashboard.dart';
import '../pages/create_request_page.dart';
import '../pages/todas_solicitudes_page.dart';
import '../pages/received_quotations_page.dart';
import '../pages/create_quotation_page.dart';
import '../pages/mis_ordenes_page.dart';
import '../pages/orden_compra_page.dart';
import '../pages/profile_page.dart';
import '../pages/perfil_almacen_page.dart';
import '../pages/addresses_page.dart';
import '../pages/vehicles_page.dart';
import '../pages/almacen_orden_detalle_page.dart';

import '../providers/onboarding_provider.dart';
import '../providers/user_role_provider.dart';
import '../services/auth_service.dart';
import 'route_names.dart';
import '../utils/keys.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      RyKeys.rootNavigatorKey;
  static GoRouter? _router;

  static GoRouter getRouter(
    UserRoleProvider roleProvider,
    OnboardingProvider onboardingProvider,
  ) {
    _router ??= GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/welcome',
      debugLogDiagnostics: true,

      refreshListenable: Listenable.merge([
        roleProvider,
        onboardingProvider,
        _AuthStreamListenable(AuthService().authStateChanges),
      ]),

      redirect: (context, state) {
        final authService = AuthService();
        final bool isAuthenticated = authService.isAuthenticated;

        final location = state.matchedLocation;
        final bool isPublicRoute =
            location == '/login' ||
            location == '/welcome' ||
            location == '/registration' ||
            location == '/registration/cliente' ||
            location == '/registration/almacen' ||
            location == '/role-selection' ||
            location == '/';

        // 1. Si no está autenticado y trata de ir a una ruta privada
        if (!isAuthenticated) {
          if (isPublicRoute) return null;

          // Conservar destino pretendido si es una ruta privada
          final from = state.matchedLocation;
          if (from != '/welcome' && from != '/') {
            return '/welcome?from=$from';
          }
          return '/welcome';
        }

        // 2. Si está autenticado pero el rol es aún desconocido, esperamos.
        // (Esto evita redirigir al Home equivocado mientras carga el rol)
        if (roleProvider.isUnknown) {
          // Si ya está en una ruta pública (como login), se queda ahí.
          // Si trata de entrar a una privada, dejamos que pase o lo mandamos a login?
          // Mejor quedarse donde está hasta que sepamos el rol.
          if (isPublicRoute) return null;
          return null;
        }

        // 3. Si está autenticado y el rol es conocido:
        final role = roleProvider.currentRole;

        // Si está en una ruta pública (login/welcome/etc), mandarlo a su Home
        if (isPublicRoute) {
          return _getHomeRoute(role);
        }

        // Protección de rutas por rol (Cross-role protection)
        if (role == UserRole.cliente) {
          if (location.startsWith('/dashboard') ||
              location.startsWith('/profile/almacen') ||
              location.startsWith('/cotizar')) {
            return '/home';
          }
        } else if (role == UserRole.almacen) {
          if (location.startsWith('/home') ||
              location.startsWith('/onboarding') ||
              location.startsWith('/solicitudes') ||
              location.startsWith('/request/create')) {
            return '/dashboard';
          }
        }

        final isOnboardingFlowRoute =
            location.startsWith('/onboarding') ||
            location.startsWith('/profile/vehicles') ||
            location.startsWith('/request/create');
        if (role == UserRole.cliente &&
            !onboardingProvider.isLoading &&
            !onboardingProvider.isComplete &&
            !onboardingProvider.isSkipped &&
            !isOnboardingFlowRoute) {
          return '/onboarding';
        }

        return null;
      },

      routes: [
        // Públicas
        GoRoute(
          path: '/welcome',
          name: RouteNames.welcome,
          builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
          path: '/role-selection',
          name: RouteNames.roleSelection,
          builder: (context, state) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: '/login',
          name: RouteNames.login,
          builder: (context, state) {
            // Si viene de un redirect, podemos pasar el parámetro 'from'
            // aunque LoginPage no lo use hoy, el AuthService/Router lo maneja.
            return const LoginPage();
          },
        ),
        GoRoute(
          path: '/registration',
          name: RouteNames.registration,
          builder: (context, state) => const RegistrationPage(),
          routes: [
            GoRoute(
              path: 'cliente',
              name: RouteNames.registerCliente,
              builder: (context, state) => const RegisterClientePage(),
            ),
            GoRoute(
              path: 'almacen',
              name: RouteNames.registerAlmacen,
              builder: (context, state) => const RegisterAlmacenPage(),
            ),
          ],
        ),

        // Privadas comunes
        GoRoute(
          path: '/complete-profile',
          name: RouteNames.completeProfile,
          builder: (context, state) => const CompleteProfilePage(),
        ),
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/profile/addresses',
          name: RouteNames.addresses,
          builder: (context, state) => const AddressesPage(),
        ),
        GoRoute(
          path: '/profile/vehicles',
          name: RouteNames.vehicles,
          builder: (context, state) => const VehiclesPage(),
        ),

        // Flujo Cliente: ruta privada y destino del redirect de onboarding.
        GoRoute(
          path: '/onboarding',
          name: RouteNames.onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/request/create',
          name: RouteNames.createRequest,
          builder: (context, state) => const CreateRequestPage(),
        ),
        GoRoute(
          path: '/solicitudes',
          name: RouteNames.solicitudes,
          builder: (context, state) => const TodasSolicitudesPage(),
        ),
        GoRoute(
          path: '/solicitudes/:id',
          name: RouteNames.receivedQuotations,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            // Para reconstruir desde la dirección, el resto de campos pueden ser opcionales o cargarse.
            // Si no vienen en extra/query, la página debe manejarlos.
            final extra = state.extra as Map<String, dynamic>?;
            return ReceivedQuotationsPage(
              solicitudId: id,
              piezaNombre: extra?['piezaNombre'] ?? 'Solicitud',
              fotoUrl: extra?['fotoUrl'],
              ofertasPendientes: extra?['ofertasPendientes'] ?? 0,
            );
          },
        ),
        GoRoute(
          path: '/mis-ordenes',
          name: RouteNames.misOrdenes,
          builder: (context, state) => const MisOrdenesPage(),
        ),
        GoRoute(
          path: '/orden/:id',
          name: RouteNames.ordenDetalle,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            // Actualizamos la página para que use este ID.
            return OrdenCompraPage(ordenId: id);
          },
        ),

        // Flujo Almacén
        GoRoute(
          path: '/dashboard',
          name: RouteNames.dashboard,
          builder: (context, state) => const WarehouseDashboard(),
        ),
        GoRoute(
          path: '/cotizar/:solicitudId',
          name: RouteNames.createQuotation,
          builder: (context, state) {
            final solicitudId = state.pathParameters['solicitudId']!;
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null && extra.containsKey('solicitud')) {
              return CreateQuotationPage(solicitud: extra['solicitud']);
            }
            // Si no hay extra, cargamos la solicitud (la página debería manejarlo si es null o pasar el ID)
            // Por simplicidad en este paso, pasamos un map mínimo con el ID si no hay extra.
            return CreateQuotationPage(solicitud: {'id': solicitudId});
          },
        ),
        GoRoute(
          path: '/profile/almacen',
          name: RouteNames.profileAlmacen,
          builder: (context, state) => const PerfilAlmacenPage(),
        ),
        GoRoute(
          path: '/dashboard/orden/:id',
          name: RouteNames.ordenDetalleAlmacen,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AlmacenOrdenDetallePage(ordenId: id);
          },
        ),
      ],
    );

    return _router!;
  }

  static String _getHomeRoute(UserRole role) {
    switch (role) {
      case UserRole.cliente:
        return '/home';
      case UserRole.almacen:
      case UserRole.admin:
        return '/dashboard';
      default:
        return '/welcome';
    }
  }
}

/// Helper para convertir un Stream en un Listenable
class _AuthStreamListenable extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _AuthStreamListenable(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
