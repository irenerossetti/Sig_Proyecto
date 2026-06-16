import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/api_cache_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/monitoring_models.dart';

// Events
abstract class AlertsEvent extends Equatable {
  const AlertsEvent();
  @override
  List<Object?> get props => [];
}

class AlertsFetchRequested extends AlertsEvent {
  final bool forceRefresh;
  const AlertsFetchRequested({this.forceRefresh = false});
  @override
  List<Object?> get props => [forceRefresh];
}

/// Agregar una nueva alerta en tiempo real
class AlertsAddNew extends AlertsEvent {
  final AlertModel alert;
  const AlertsAddNew(this.alert);
  @override
  List<Object?> get props => [alert];
}

// States
abstract class AlertsState extends Equatable {
  const AlertsState();
  @override
  List<Object?> get props => [];
}

class AlertsInitial extends AlertsState {}

class AlertsLoading extends AlertsState {
  final List<AlertModel>? previousData;
  const AlertsLoading({this.previousData});
  @override
  List<Object?> get props => [previousData];
}

class AlertsLoaded extends AlertsState {
  final List<AlertModel> alerts;
  final bool fromCache;
  final DateTime lastUpdated;

  AlertsLoaded(
    this.alerts, {
    this.fromCache = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  @override
  List<Object?> get props => [alerts, fromCache, lastUpdated];
}

class AlertsError extends AlertsState {
  final String message;
  final List<AlertModel>? previousData;
  
  const AlertsError(this.message, {this.previousData});
  @override
  List<Object?> get props => [message, previousData];
}

// Bloc optimizado con caché
class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;
  final ApiCacheService _cache = ApiCacheService();
  
  static const String _cacheKey = 'alerts_list';

  AlertsBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(AlertsInitial()) {
    on<AlertsFetchRequested>(_onFetchRequested);
    on<AlertsAddNew>(_onAddNew);
  }

  Future<void> _onFetchRequested(
    AlertsFetchRequested event,
    Emitter<AlertsState> emit,
  ) async {
    final token = _authBloc.state.token;

    if (token == null || token.isEmpty) {
      emit(const AlertsError('No autenticado'));
      return;
    }

    List<AlertModel>? previousData;
    if (state is AlertsLoaded) {
      previousData = (state as AlertsLoaded).alerts;
    }

    // Mostrar datos del caché primero si no es force refresh
    if (!event.forceRefresh) {
      final cached = await _cache.get<List<dynamic>>(_cacheKey, category: 'alerts');
      if (cached != null) {
        try {
          final alerts = cached
              .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
              .toList();
          emit(AlertsLoaded(alerts, fromCache: true));
        } catch (e) {
          debugPrint('Error parsing cached alerts: $e');
        }
      }
    }

    if (previousData == null && state is! AlertsLoaded) {
      emit(AlertsLoading(previousData: previousData));
    }

    try {
      final alerts = await _repo.fetchAlerts(token: token);
      
      await _cache.set(
        _cacheKey,
        alerts.map((a) => a.toJson()).toList(),
      );
      
      emit(AlertsLoaded(alerts));
    } catch (e) {
      if (state is AlertsLoaded) {
        debugPrint('Alerts refresh failed, keeping cached data: $e');
      } else if (previousData != null) {
        emit(AlertsError(e.toString(), previousData: previousData));
      } else {
        emit(AlertsError(e.toString()));
      }
    }
  }

  /// Agregar nueva alerta desde WebSocket sin refetch
  void _onAddNew(AlertsAddNew event, Emitter<AlertsState> emit) {
    if (state is AlertsLoaded) {
      final currentAlerts = (state as AlertsLoaded).alerts;
      
      // Evitar duplicados
      if (currentAlerts.any((a) => a.id == event.alert.id)) {
        return;
      }
      
      // Insertar al inicio (más reciente primero)
      final updatedAlerts = [event.alert, ...currentAlerts];
      emit(AlertsLoaded(updatedAlerts));
      
      // Actualizar caché
      _cache.set(
        _cacheKey,
        updatedAlerts.map((a) => a.toJson()).toList(),
      );
    }
  }
}
