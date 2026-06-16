import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/api_cache_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/monitoring_models.dart';

// Events
abstract class ChildrenEvent extends Equatable {
  const ChildrenEvent();
  @override
  List<Object?> get props => [];
}

class ChildrenFetchRequested extends ChildrenEvent {
  /// Si es true, fuerza refresh desde servidor ignorando caché
  final bool forceRefresh;
  const ChildrenFetchRequested({this.forceRefresh = false});
  @override
  List<Object?> get props => [forceRefresh];
}

/// Evento para actualizar un niño específico en la lista (sin refetch completo)
class ChildrenUpdateSingle extends ChildrenEvent {
  final ChildModel child;
  const ChildrenUpdateSingle(this.child);
  @override
  List<Object?> get props => [child];
}

// States
abstract class ChildrenState extends Equatable {
  const ChildrenState();
  @override
  List<Object?> get props => [];
}

class ChildrenInitial extends ChildrenState {}

class ChildrenLoading extends ChildrenState {
  /// Si hay datos previos, los mantenemos para mostrar mientras carga
  final List<ChildModel>? previousData;
  const ChildrenLoading({this.previousData});
  @override
  List<Object?> get props => [previousData];
}

class ChildrenLoaded extends ChildrenState {
  final List<ChildModel> children;
  /// Indica si los datos vienen del caché
  final bool fromCache;
  /// Timestamp de la última actualización
  final DateTime lastUpdated;

  ChildrenLoaded(
    this.children, {
    this.fromCache = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  @override
  List<Object?> get props => [children, fromCache, lastUpdated];
}

class ChildrenError extends ChildrenState {
  final String message;
  /// Mantener datos previos en caso de error
  final List<ChildModel>? previousData;
  
  const ChildrenError(this.message, {this.previousData});
  @override
  List<Object?> get props => [message, previousData];
}

// Bloc optimizado con caché
class ChildrenBloc extends Bloc<ChildrenEvent, ChildrenState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;
  final ApiCacheService _cache = ApiCacheService();
  
  static const String _cacheKey = 'children_list';

  ChildrenBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(ChildrenInitial()) {
    on<ChildrenFetchRequested>(_onFetchRequested);
    on<ChildrenUpdateSingle>(_onUpdateSingle);
  }

  Future<void> _onFetchRequested(
    ChildrenFetchRequested event,
    Emitter<ChildrenState> emit,
  ) async {
    final token = _authBloc.state.token;
    
    if (token == null || token.isEmpty) {
      emit(const ChildrenError('No autenticado'));
      return;
    }

    // Obtener datos previos si existen
    List<ChildModel>? previousData;
    if (state is ChildrenLoaded) {
      previousData = (state as ChildrenLoaded).children;
    }

    // Si no es force refresh, intentar mostrar caché primero
    if (!event.forceRefresh) {
      final cached = await _cache.get<List<dynamic>>(_cacheKey, category: 'children');
      if (cached != null) {
        try {
          final children = cached
              .map((item) => ChildModel.fromJson(item as Map<String, dynamic>))
              .toList();
          emit(ChildrenLoaded(children, fromCache: true));
          // Continuar para refrescar en background
        } catch (e) {
          debugPrint('Error parsing cached children: $e');
        }
      }
    }

    // Mostrar loading solo si no hay datos previos
    if (previousData == null && state is! ChildrenLoaded) {
      emit(ChildrenLoading(previousData: previousData));
    }

    try {
      final children = await _repo.fetchChildren(token: token);
      
      // Guardar en caché
      await _cache.set(
        _cacheKey,
        children.map((c) => c.toJson()).toList(),
      );
      
      emit(ChildrenLoaded(children));
    } catch (e) {
      // Si hay datos previos (del caché o estado anterior), usarlos
      if (state is ChildrenLoaded) {
        // Mantener el estado actual, solo loggear el error
        debugPrint('Children refresh failed, keeping cached data: $e');
      } else if (previousData != null) {
        emit(ChildrenError(e.toString(), previousData: previousData));
      } else {
        emit(ChildrenError(e.toString()));
      }
    }
  }

  /// Actualizar un niño específico sin refetch completo
  void _onUpdateSingle(
    ChildrenUpdateSingle event,
    Emitter<ChildrenState> emit,
  ) {
    if (state is ChildrenLoaded) {
      final currentChildren = (state as ChildrenLoaded).children;
      final updatedChildren = currentChildren.map((child) {
        return child.id == event.child.id ? event.child : child;
      }).toList();
      
      emit(ChildrenLoaded(updatedChildren));
      
      // Actualizar caché
      _cache.set(
        _cacheKey,
        updatedChildren.map((c) => c.toJson()).toList(),
      );
    }
  }
}
