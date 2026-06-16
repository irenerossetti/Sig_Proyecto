import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/websocket_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/monitoring_models.dart';

// Events
abstract class MapEvent extends Equatable {
  const MapEvent();
  @override
  List<Object?> get props => [];
}

class MapChildSelected extends MapEvent {
  final int childId;
  const MapChildSelected(this.childId);
  @override
  List<Object?> get props => [childId];
}

class MapRefreshChild extends MapEvent {
  const MapRefreshChild();
}

class MapStartListening extends MapEvent {}
class MapStopListening extends MapEvent {}

class _MapLocationUpdated extends MapEvent {
  final ChildModel child;
  const _MapLocationUpdated(this.child);
  @override
  List<Object?> get props => [child];
}

class _MapRealtimeLocationReceived extends MapEvent {
  final LocationUpdate update;
  const _MapRealtimeLocationReceived(this.update);
  @override
  List<Object?> get props => [update];
}

class _MapWebSocketStateChanged extends MapEvent {
  final bool isConnected;
  const _MapWebSocketStateChanged(this.isConnected);
  @override
  List<Object?> get props => [isConnected];
}

// States
class MapState extends Equatable {
  final int? selectedChildId;
  final ChildModel? childLocation;
  final bool isLoading;
  final bool isWebSocketConnected;

  const MapState({
    this.selectedChildId,
    this.childLocation,
    this.isLoading = false,
    this.isWebSocketConnected = false,
  });

  MapState copyWith({
    int? selectedChildId,
    ChildModel? childLocation,
    bool? isLoading,
    bool? isWebSocketConnected,
  }) {
    return MapState(
      selectedChildId: selectedChildId ?? this.selectedChildId,
      childLocation: childLocation ?? this.childLocation,
      isLoading: isLoading ?? this.isLoading,
      isWebSocketConnected: isWebSocketConnected ?? this.isWebSocketConnected,
    );
  }

  @override
  List<Object?> get props => [selectedChildId, childLocation, isLoading, isWebSocketConnected];
}

/// Bloc que usa WebSocket exclusivamente para actualizaciones en tiempo real
class MapBloc extends Bloc<MapEvent, MapState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;
  final WebSocketService _webSocketService = WebSocketService();
  
  StreamSubscription? _locationSubscription;
  StreamSubscription? _connectionSubscription;

  MapBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(const MapState()) {
    
    on<MapChildSelected>(_onChildSelected);
    on<MapRefreshChild>(_onRefreshChild);
    on<MapStartListening>(_onStartListening);
    on<MapStopListening>(_onStopListening);
    on<_MapLocationUpdated>(_onLocationUpdated);
    on<_MapRealtimeLocationReceived>(_onRealtimeLocationReceived);
    on<_MapWebSocketStateChanged>(_onWebSocketStateChanged);
    
    // Escuchar actualizaciones de ubicación en tiempo real via WebSocket
    _locationSubscription = _webSocketService.locationUpdates.listen((update) {
      add(_MapRealtimeLocationReceived(update));
    });
    
    // Escuchar estado de conexión WebSocket
    _connectionSubscription = _webSocketService.connectionState.listen((connected) {
      add(_MapWebSocketStateChanged(connected));
    });
  }

  void _onChildSelected(MapChildSelected event, Emitter<MapState> emit) {
    emit(state.copyWith(selectedChildId: event.childId, isLoading: true));
    
    // Suscribirse a actualizaciones de este niño via WebSocket
    _webSocketService.subscribeToChild(event.childId);
    
    // Fetch inicial para tener datos inmediatos
    _fetchInitialLocation(event.childId);
  }

  void _onRefreshChild(MapRefreshChild event, Emitter<MapState> emit) {
    // Refrescar los datos del niño actualmente seleccionado
    if (state.selectedChildId != null) {
      _fetchInitialLocation(state.selectedChildId!);
    }
  }

  void _onStartListening(MapStartListening event, Emitter<MapState> emit) {
    // WebSocket ya está conectado via AuthBloc, solo actualizar estado
    emit(state.copyWith(isWebSocketConnected: _webSocketService.isConnected));
  }

  void _onStopListening(MapStopListening event, Emitter<MapState> emit) {
    // Desuscribirse del niño actual si hay uno seleccionado
    if (state.selectedChildId != null) {
      _webSocketService.unsubscribeFromChild(state.selectedChildId!);
    }
  }

  void _onLocationUpdated(_MapLocationUpdated event, Emitter<MapState> emit) {
    emit(state.copyWith(
      childLocation: event.child,
      isLoading: false,
    ));
  }

  void _onRealtimeLocationReceived(_MapRealtimeLocationReceived event, Emitter<MapState> emit) {
    final update = event.update;
    
    debugPrint('📍 MapBloc received: child=${update.childId}, selected=${state.selectedChildId}');
    
    // Solo actualizar si es el niño seleccionado actualmente
    if (state.selectedChildId == update.childId) {
      final currentChild = state.childLocation;
      
      // Crear nuevo device con la ubicación actualizada
      final updatedDevice = currentChild?.device?.copyWith(
        lastLatitude: update.latitude,
        lastLongitude: update.longitude,
        batteryLevel: update.batteryLevel,
        lastSeen: update.timestamp,
      ) ?? DeviceModel(
        id: 0,
        deviceId: 'realtime',
        lastLatitude: update.latitude,
        lastLongitude: update.longitude,
        batteryLevel: update.batteryLevel,
        lastSeen: update.timestamp,
        isActive: true,
      );
      
      final updatedChild = currentChild != null 
        ? ChildModel(
            id: currentChild.id,
            fullName: currentChild.fullName,
            dateOfBirth: currentChild.dateOfBirth,
            photoUrl: currentChild.photoUrl,
            notes: currentChild.notes,
            isActive: currentChild.isActive,
            createdAt: currentChild.createdAt,
            updatedAt: currentChild.updatedAt,
            device: updatedDevice,
          )
        : ChildModel(
            id: update.childId,
            fullName: update.childName,
            dateOfBirth: DateTime.now(), // Placeholder
            isActive: true,
            device: updatedDevice,
          );
      
      emit(state.copyWith(
        childLocation: updatedChild,
        isWebSocketConnected: true,
        isLoading: false,
      ));
      
      debugPrint('📍 MapBloc UPDATED: lat=${update.latitude}, lng=${update.longitude}');
    }
  }

  void _onWebSocketStateChanged(_MapWebSocketStateChanged event, Emitter<MapState> emit) {
    emit(state.copyWith(isWebSocketConnected: event.isConnected));
    debugPrint('🔌 WebSocket connected: ${event.isConnected}');
  }

  /// Fetch inicial solo para tener datos mientras llega el primer WebSocket update
  Future<void> _fetchInitialLocation(int childId) async {
    final token = _authBloc.state.token;
    if (token == null || token.isEmpty) return;

    try {
      final child = await _repo.fetchChildDetail(token: token, childId: childId);
      add(_MapLocationUpdated(child));
    } catch (_) {
      // Silencioso - WebSocket proveerá los datos
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
