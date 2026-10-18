import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/notificacion.dart';
import '../services/auth_service.dart';
import '../services/notificaciones_api_service.dart';
import '../utils/app_logger.dart';

class NotificacionesProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  final NotificacionesApiService _service;
  final AuthService _authService;
  final bool escucharRealtime;

  NotificacionesProvider({
    NotificacionesApiService? service,
    AuthService? authService,
    this.escucharRealtime = true,
  }) : _service = service ?? NotificacionesApiService(),
       _authService = authService ?? AuthService();

  int _unreadCount = 0;
  List<Notificacion> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  bool _hasMore = false;
  bool _listaInicializada = false;
  int _page = 1;
  String? _errorMessage;
  String? _loadMoreError;
  String? _userId;
  supabase.RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  bool _inicializado = false;
  bool _disposed = false;
  int _sessionEpoch = 0;

  int get unreadCount => _unreadCount;
  List<Notificacion> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get loadMoreError => _loadMoreError;

  void initialize() {
    if (_inicializado) return;
    _inicializado = true;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _authService.authStateChanges.listen(
      (state) => _cambiarUsuario(state.user?.id),
    );
    _cambiarUsuario(_authService.currentUser?.id);
  }

  void _cambiarUsuario(String? userId) {
    if (_userId == userId) return;
    _sessionEpoch++;
    _desuscribirRealtime();
    _userId = userId;
    _unreadCount = 0;
    _items = [];
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = false;
    _listaInicializada = false;
    _page = 1;
    _errorMessage = null;
    _loadMoreError = null;
    notifyListeners();

    if (userId != null) {
      if (_isRefreshing) {
        _refreshQueued = true;
      } else {
        unawaited(refrescar());
      }
      if (escucharRealtime) _suscribirRealtime(userId);
    }
  }

  void _suscribirRealtime(String userId) {
    try {
      final channel = supabase.Supabase.instance.client
          .channel('notificaciones_in_app_$userId')
          .onPostgresChanges(
            event: supabase.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notificaciones',
            filter: supabase.PostgresChangeFilter(
              column: 'user_id',
              type: supabase.PostgresChangeFilterType.eq,
              value: userId,
            ),
            callback: (_) => unawaited(refrescar()),
          )
          .onPostgresChanges(
            event: supabase.PostgresChangeEvent.update,
            schema: 'public',
            table: 'notificaciones',
            filter: supabase.PostgresChangeFilter(
              column: 'user_id',
              type: supabase.PostgresChangeFilterType.eq,
              value: userId,
            ),
            callback: (_) => unawaited(refrescar()),
          )
          .subscribe((status, error) {
            if (error != null) {
              AppLogger.warning(
                'No se pudo suscribir a notificaciones realtime: $error',
                name: 'NotificacionesProvider',
              );
            }
          });
      _realtimeChannel = channel;
    } catch (error) {
      // La campana sigue actualizándose al volver a la app y al navegar.
      AppLogger.warning(
        'Realtime de notificaciones no disponible: $error',
        name: 'NotificacionesProvider',
      );
    }
  }

  void _desuscribirRealtime() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) unawaited(channel.unsubscribe());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refrescar());
  }

  /// Actualiza el contador y, si la pantalla está abierta, vuelve a cargar su
  /// primera página para conservarla sincronizada con la campana.
  Future<void> refrescar() async {
    if (_userId == null || _disposed) return;
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;
    final epoch = _sessionEpoch;
    try {
      do {
        _refreshQueued = false;
        try {
          final unreadCount = await _service.contarNoLeidas();
          if (_disposed || epoch != _sessionEpoch) return;
          _unreadCount = unreadCount;
        } catch (error) {
          AppLogger.warning(
            'No se pudo actualizar el contador de notificaciones: $error',
            name: 'NotificacionesProvider',
          );
        }

        if (_listaInicializada) {
          try {
            final page = await _service.listar(page: 1);
            if (_disposed || epoch != _sessionEpoch) return;
            _items = page.items;
            _page = page.page;
            _hasMore = page.hasMore;
            _loadMoreError = null;
            _errorMessage = null;
          } catch (error) {
            _errorMessage ??= 'No se pudieron actualizar las notificaciones.';
            AppLogger.warning(
              'No se pudo actualizar la lista de notificaciones: $error',
              name: 'NotificacionesProvider',
            );
          }
        }
        if (!_disposed) notifyListeners();
      } while (_refreshQueued && _userId != null && !_disposed);
    } finally {
      _isRefreshing = false;
      if (_refreshQueued && _userId != null && !_disposed) {
        _refreshQueued = false;
        unawaited(refrescar());
      }
    }
  }

  Future<void> cargarInicial() async {
    if (_userId == null || _isLoading || _disposed) return;
    final epoch = _sessionEpoch;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.listar(page: 1);
      if (_disposed || epoch != _sessionEpoch) return;
      _items = page.items;
      _page = page.page;
      _hasMore = page.hasMore;
      _listaInicializada = true;
      _loadMoreError = null;
    } catch (error) {
      _errorMessage = 'No se pudieron cargar las notificaciones.';
      AppLogger.error(
        'Error al cargar notificaciones',
        name: 'NotificacionesProvider',
        error: error,
      );
    } finally {
      if (epoch == _sessionEpoch) _isLoading = false;
      if (!_disposed) notifyListeners();
    }
    if (epoch == _sessionEpoch) await _refrescarConteo();
  }

  Future<void> _refrescarConteo() async {
    final userId = _userId;
    if (userId == null || _disposed) return;
    final epoch = _sessionEpoch;
    try {
      final count = await _service.contarNoLeidas();
      if (_disposed || epoch != _sessionEpoch) return;
      _unreadCount = count;
      notifyListeners();
    } catch (error) {
      AppLogger.warning(
        'No se pudo actualizar el contador de notificaciones: $error',
        name: 'NotificacionesProvider',
      );
    }
  }

  Future<void> cargarMas() async {
    if (_userId == null ||
        !_listaInicializada ||
        !_hasMore ||
        _isLoadingMore ||
        _disposed) {
      return;
    }
    final epoch = _sessionEpoch;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final page = await _service.listar(page: nextPage);
      if (_disposed || epoch != _sessionEpoch) return;
      final idsExistentes = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...page.items.where((item) => !idsExistentes.contains(item.id)),
      ];
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (error) {
      _loadMoreError = 'No se pudo cargar más. Intenta nuevamente.';
      AppLogger.warning(
        'Error al paginar notificaciones: $error',
        name: 'NotificacionesProvider',
      );
    } finally {
      if (epoch == _sessionEpoch) _isLoadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> marcarLeida(String id) async {
    if (_userId == null) return;
    final epoch = _sessionEpoch;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].estaLeida) return;

    final original = _items[index];
    final conteoOriginal = _unreadCount;
    _items = [..._items];
    _items[index] = original.marcadaLeida(DateTime.now());
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    notifyListeners();

    try {
      final leidoEn = await _service.marcarLeida(id);
      if (_disposed || epoch != _sessionEpoch) return;
      final currentIndex = _items.indexWhere((item) => item.id == id);
      if (currentIndex >= 0 && leidoEn != null) {
        _items = [..._items];
        _items[currentIndex] = original.marcadaLeida(leidoEn);
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed && epoch == _sessionEpoch) {
        final currentIndex = _items.indexWhere((item) => item.id == id);
        if (currentIndex >= 0) {
          _items = [..._items];
          _items[currentIndex] = original;
        }
        _unreadCount = conteoOriginal;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<int> marcarTodasLeidas() async {
    if (_userId == null) return 0;
    final epoch = _sessionEpoch;
    final itemsOriginales = _items;
    final conteoOriginal = _unreadCount;
    final ahora = DateTime.now();
    _items = _items
        .map((item) => item.estaLeida ? item : item.marcadaLeida(ahora))
        .toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      final actualizadas = await _service.marcarTodasLeidas();
      if (!_disposed && epoch == _sessionEpoch) unawaited(refrescar());
      return actualizadas;
    } catch (_) {
      if (!_disposed && epoch == _sessionEpoch) {
        _items = itemsOriginales;
        _unreadCount = conteoOriginal;
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _desuscribirRealtime();
    super.dispose();
  }
}
