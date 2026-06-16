import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/monitoring_models.dart';
import '../all_children_map_view.dart' show SafeZonesCacheManager;

// ═══════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════

abstract class SafeZoneEvent extends Equatable {
  const SafeZoneEvent();
  @override
  List<Object?> get props => [];
}

/// Cargar zonas seguras de un niño
class SafeZonesFetchRequested extends SafeZoneEvent {
  final int childId;
  const SafeZonesFetchRequested(this.childId);
  @override
  List<Object?> get props => [childId];
}

/// Crear una nueva zona segura
class SafeZoneCreateRequested extends SafeZoneEvent {
  final CreateSafeZonePayload payload;
  const SafeZoneCreateRequested(this.payload);
  @override
  List<Object?> get props => [payload];
}

/// Actualizar una zona segura existente
class SafeZoneUpdateRequested extends SafeZoneEvent {
  final int zoneId;
  final Map<String, dynamic> data;
  const SafeZoneUpdateRequested({required this.zoneId, required this.data});
  @override
  List<Object?> get props => [zoneId, data];
}

/// Eliminar una zona segura
class SafeZoneDeleteRequested extends SafeZoneEvent {
  final int zoneId;
  final int childId;
  const SafeZoneDeleteRequested({required this.zoneId, required this.childId});
  @override
  List<Object?> get props => [zoneId, childId];
}

/// Toggle activar/desactivar zona segura
class SafeZoneToggleRequested extends SafeZoneEvent {
  final int zoneId;
  final int childId;
  final bool isActive;
  const SafeZoneToggleRequested({
    required this.zoneId,
    required this.childId,
    required this.isActive,
  });
  @override
  List<Object?> get props => [zoneId, childId, isActive];
}

/// Limpiar estado de operación
class SafeZoneOperationReset extends SafeZoneEvent {}

// ═══════════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════════

abstract class SafeZoneState extends Equatable {
  const SafeZoneState();
  @override
  List<Object?> get props => [];
}

class SafeZoneInitial extends SafeZoneState {}

class SafeZoneLoading extends SafeZoneState {}

class SafeZoneLoaded extends SafeZoneState {
  final List<SafeZoneModel> zones;
  final int childId;

  const SafeZoneLoaded({required this.zones, required this.childId});

  @override
  List<Object?> get props => [zones, childId];
}

class SafeZoneError extends SafeZoneState {
  final String message;
  const SafeZoneError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Estado para operaciones de crear/actualizar/eliminar
class SafeZoneOperationInProgress extends SafeZoneState {}

class SafeZoneOperationSuccess extends SafeZoneState {
  final String message;
  final SafeZoneModel? zone;
  
  const SafeZoneOperationSuccess({required this.message, this.zone});
  
  @override
  List<Object?> get props => [message, zone];
}

class SafeZoneOperationFailure extends SafeZoneState {
  final String message;
  const SafeZoneOperationFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════

class SafeZoneBloc extends Bloc<SafeZoneEvent, SafeZoneState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;

  SafeZoneBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(SafeZoneInitial()) {
    on<SafeZonesFetchRequested>(_onFetchRequested);
    on<SafeZoneCreateRequested>(_onCreateRequested);
    on<SafeZoneUpdateRequested>(_onUpdateRequested);
    on<SafeZoneDeleteRequested>(_onDeleteRequested);
    on<SafeZoneToggleRequested>(_onToggleRequested);
    on<SafeZoneOperationReset>(_onOperationReset);
  }

  String? get _token => _authBloc.state.token;

  Future<void> _onFetchRequested(
    SafeZonesFetchRequested event,
    Emitter<SafeZoneState> emit,
  ) async {
    emit(SafeZoneLoading());

    if (_token == null || _token!.isEmpty) {
      emit(const SafeZoneError('No autenticado'));
      return;
    }

    try {
      final zones = await _repo.fetchSafeZones(
        token: _token!,
        childId: event.childId,
      );
      emit(SafeZoneLoaded(zones: zones, childId: event.childId));
    } catch (e) {
      emit(SafeZoneError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(
    SafeZoneCreateRequested event,
    Emitter<SafeZoneState> emit,
  ) async {
    emit(SafeZoneOperationInProgress());

    if (_token == null || _token!.isEmpty) {
      emit(const SafeZoneOperationFailure('No autenticado'));
      return;
    }

    try {
      final zone = await _repo.createSafeZone(
        token: _token!,
        payload: event.payload,
      );
      
      // Invalidar caché del mapa para que recargue las zonas
      SafeZonesCacheManager.invalidate();
      
      emit(SafeZoneOperationSuccess(
        message: 'Zona segura creada correctamente',
        zone: zone,
      ));
    } catch (e) {
      emit(SafeZoneOperationFailure(e.toString()));
    }
  }

  Future<void> _onUpdateRequested(
    SafeZoneUpdateRequested event,
    Emitter<SafeZoneState> emit,
  ) async {
    emit(SafeZoneOperationInProgress());

    if (_token == null || _token!.isEmpty) {
      emit(const SafeZoneOperationFailure('No autenticado'));
      return;
    }

    try {
      final zone = await _repo.updateSafeZone(
        token: _token!,
        zoneId: event.zoneId,
        data: event.data,
      );
      
      // Invalidar caché del mapa para que recargue las zonas
      SafeZonesCacheManager.invalidate();
      
      emit(SafeZoneOperationSuccess(
        message: 'Zona segura actualizada correctamente',
        zone: zone,
      ));
    } catch (e) {
      emit(SafeZoneOperationFailure(e.toString()));
    }
  }

  Future<void> _onDeleteRequested(
    SafeZoneDeleteRequested event,
    Emitter<SafeZoneState> emit,
  ) async {
    emit(SafeZoneOperationInProgress());

    if (_token == null || _token!.isEmpty) {
      emit(const SafeZoneOperationFailure('No autenticado'));
      return;
    }

    try {
      await _repo.deleteSafeZone(token: _token!, zoneId: event.zoneId);
      
      // Invalidar caché del mapa para que recargue las zonas
      SafeZonesCacheManager.invalidate();
      
      emit(const SafeZoneOperationSuccess(
        message: 'Zona segura eliminada correctamente',
      ));
    } catch (e) {
      emit(SafeZoneOperationFailure(e.toString()));
    }
  }

  Future<void> _onToggleRequested(
    SafeZoneToggleRequested event,
    Emitter<SafeZoneState> emit,
  ) async {
    emit(SafeZoneOperationInProgress());

    if (_token == null || _token!.isEmpty) {
      emit(const SafeZoneOperationFailure('No autenticado'));
      return;
    }

    try {
      await _repo.updateSafeZone(
        token: _token!,
        zoneId: event.zoneId,
        data: {'is_active': event.isActive},
      );
      
      // Invalidar caché del mapa para que recargue las zonas
      SafeZonesCacheManager.invalidate();
      
      final message = event.isActive 
          ? 'Zona segura activada' 
          : 'Zona segura desactivada';
      emit(SafeZoneOperationSuccess(message: message));
    } catch (e) {
      emit(SafeZoneOperationFailure(e.toString()));
    }
  }

  void _onOperationReset(
    SafeZoneOperationReset event,
    Emitter<SafeZoneState> emit,
  ) {
    emit(SafeZoneInitial());
  }
}
