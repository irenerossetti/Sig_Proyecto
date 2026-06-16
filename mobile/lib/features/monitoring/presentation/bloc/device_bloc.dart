import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/monitoring_models.dart';

// Events
abstract class DeviceEvent extends Equatable {
  const DeviceEvent();
  @override
  List<Object?> get props => [];
}

class DeviceCreateRequested extends DeviceEvent {
  final int childId;
  final String deviceId;
  final String? deviceType;

  const DeviceCreateRequested({
    required this.childId,
    required this.deviceId,
    this.deviceType,
  });

  @override
  List<Object?> get props => [childId, deviceId, deviceType];
}

// States
abstract class DeviceState extends Equatable {
  const DeviceState();
  @override
  List<Object?> get props => [];
}

class DeviceInitial extends DeviceState {}

class DeviceLoading extends DeviceState {}

class DeviceCreated extends DeviceState {
  final DeviceModel device;
  const DeviceCreated(this.device);
  @override
  List<Object?> get props => [device];
}

class DeviceError extends DeviceState {
  final String message;
  const DeviceError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Bloc para crear dispositivos.
/// El envío de ubicaciones se hace desde la app Tracker via WebSocket.
class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;

  DeviceBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(DeviceInitial()) {
    on<DeviceCreateRequested>(_onCreateDevice);
  }

  Future<void> _onCreateDevice(
    DeviceCreateRequested event,
    Emitter<DeviceState> emit,
  ) async {
    emit(DeviceLoading());
    final token = _authBloc.state.token;
    if (token == null || token.isEmpty) {
      emit(const DeviceError('No autenticado.'));
      return;
    }

    try {
      final device = await _repo.createDevice(
        token: token,
        childId: event.childId,
        deviceId: event.deviceId,
        deviceType: event.deviceType,
      );
      emit(DeviceCreated(device));
    } on MonitoringRepositoryException catch (e) {
      emit(DeviceError(e.message));
    } catch (e) {
      emit(const DeviceError('Error al crear el dispositivo.'));
    }
  }
}
