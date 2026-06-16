import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/group_repository.dart';
import '../../domain/group_models.dart';
import '../../../monitoring/presentation/all_children_map_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class GroupDetailEvent extends Equatable {
  const GroupDetailEvent();
  @override
  List<Object?> get props => [];
}

/// Cargar detalle del grupo
class GroupDetailLoadRequested extends GroupDetailEvent {
  final int groupId;
  const GroupDetailLoadRequested(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

/// Agregar niño al grupo
class GroupDetailAddChild extends GroupDetailEvent {
  final int childId;
  const GroupDetailAddChild(this.childId);
  @override
  List<Object?> get props => [childId];
}

/// Remover niño del grupo
class GroupDetailRemoveChild extends GroupDetailEvent {
  final int childId;
  const GroupDetailRemoveChild(this.childId);
  @override
  List<Object?> get props => [childId];
}

/// Invitar co-tutor
class GroupDetailInviteTutor extends GroupDetailEvent {
  final String email;
  final String role;
  const GroupDetailInviteTutor({required this.email, this.role = 'monitor'});
  @override
  List<Object?> get props => [email, role];
}

/// Remover co-tutor
class GroupDetailRemoveTutor extends GroupDetailEvent {
  final int tutorId;
  const GroupDetailRemoveTutor(this.tutorId);
  @override
  List<Object?> get props => [tutorId];
}

/// Cargar ubicaciones para el mapa
class GroupDetailLoadLocations extends GroupDetailEvent {
  final int groupId;
  const GroupDetailLoadLocations(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

/// Crear zona segura del grupo
class GroupDetailCreateSafeZone extends GroupDetailEvent {
  final String name;
  final int radiusMeters;
  const GroupDetailCreateSafeZone({
    required this.name,
    required this.radiusMeters,
  });
  @override
  List<Object?> get props => [name, radiusMeters];
}

/// Crear zona segura de grupo con polígono (mapa)
class GroupDetailCreatePolygonSafeZone extends GroupDetailEvent {
  final String name;
  final List<LatLngPoint> polygonPoints;
  final String color;
  const GroupDetailCreatePolygonSafeZone({
    required this.name,
    required this.polygonPoints,
    this.color = '#4CAF50',
  });
  @override
  List<Object?> get props => [name, polygonPoints, color];
}

/// Actualizar zona segura de grupo
class GroupDetailUpdateSafeZone extends GroupDetailEvent {
  final int zoneId;
  final String name;
  final List<LatLngPoint> polygonPoints;
  final String color;
  const GroupDetailUpdateSafeZone({
    required this.zoneId,
    required this.name,
    required this.polygonPoints,
    required this.color,
  });
  @override
  List<Object?> get props => [zoneId, name, polygonPoints, color];
}

/// Eliminar zona segura del grupo
class GroupDetailDeleteSafeZone extends GroupDetailEvent {
  final int zoneId;
  const GroupDetailDeleteSafeZone(this.zoneId);
  @override
  List<Object?> get props => [zoneId];
}

/// Toggle activar/desactivar zona segura del grupo
class GroupDetailToggleSafeZone extends GroupDetailEvent {
  final int zoneId;
  final bool isActive;
  const GroupDetailToggleSafeZone({required this.zoneId, required this.isActive});
  @override
  List<Object?> get props => [zoneId, isActive];
}

/// Eliminar el grupo completo
class GroupDetailDeleteGroup extends GroupDetailEvent {
  const GroupDetailDeleteGroup();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────────────────────

abstract class GroupDetailState extends Equatable {
  const GroupDetailState();
  @override
  List<Object?> get props => [];
}

class GroupDetailInitial extends GroupDetailState {}

class GroupDetailLoading extends GroupDetailState {}

class GroupDetailLoaded extends GroupDetailState {
  final ChildGroupModel group;
  final GroupLocationsResponse? locations;

  const GroupDetailLoaded({required this.group, this.locations});
  @override
  List<Object?> get props => [group, locations];
}

class GroupDetailError extends GroupDetailState {
  final String message;
  const GroupDetailError(this.message);
  @override
  List<Object?> get props => [message];
}

class GroupDetailActionLoading extends GroupDetailState {
  final ChildGroupModel group;
  final String action;

  const GroupDetailActionLoading({required this.group, required this.action});
  @override
  List<Object?> get props => [group, action];
}

class GroupDetailActionSuccess extends GroupDetailState {
  final ChildGroupModel group;
  final String message;

  const GroupDetailActionSuccess({required this.group, required this.message});
  @override
  List<Object?> get props => [group, message];
}

/// Estado cuando el grupo fue eliminado exitosamente
class GroupDetailDeleted extends GroupDetailState {
  final String message;
  const GroupDetailDeleted(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class GroupDetailBloc extends Bloc<GroupDetailEvent, GroupDetailState> {
  final GroupRepository _repo;
  final AuthBloc _authBloc;

  int? _currentGroupId;

  GroupDetailBloc({required GroupRepository repo, required AuthBloc authBloc})
    : _repo = repo,
      _authBloc = authBloc,
      super(GroupDetailInitial()) {
    on<GroupDetailLoadRequested>(_onLoadRequested);
    on<GroupDetailAddChild>(_onAddChild);
    on<GroupDetailRemoveChild>(_onRemoveChild);
    on<GroupDetailInviteTutor>(_onInviteTutor);
    on<GroupDetailRemoveTutor>(_onRemoveTutor);
    on<GroupDetailLoadLocations>(_onLoadLocations);
    on<GroupDetailCreateSafeZone>(_onCreateSafeZone);
    on<GroupDetailCreatePolygonSafeZone>(_onCreatePolygonSafeZone);
    on<GroupDetailUpdateSafeZone>(_onUpdateSafeZone);
    on<GroupDetailDeleteSafeZone>(_onDeleteSafeZone);
    on<GroupDetailToggleSafeZone>(_onToggleSafeZone);
    on<GroupDetailDeleteGroup>(_onDeleteGroup);
  }

  String? get _token => _authBloc.state.token;

  Future<void> _onLoadRequested(
    GroupDetailLoadRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null) {
      emit(const GroupDetailError('No autenticado'));
      return;
    }

    _currentGroupId = event.groupId;
    emit(GroupDetailLoading());

    try {
      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: event.groupId,
      );
      emit(GroupDetailLoaded(group: group));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onAddChild(
    GroupDetailAddChild event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Agregando niño...',
      ),
    );

    try {
      await _repo.addChildToGroup(
        token: _token!,
        groupId: _currentGroupId!,
        childId: event.childId,
      );

      // Invalidar caché de grupos en el mapa para que se actualice
      GroupsCacheManager.invalidate();

      // Recargar grupo
      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Niño agregado al grupo',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onRemoveChild(
    GroupDetailRemoveChild event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Removiendo niño...',
      ),
    );

    try {
      await _repo.removeChildFromGroup(
        token: _token!,
        groupId: _currentGroupId!,
        childId: event.childId,
      );

      // Invalidar caché de grupos en el mapa para que se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Niño removido del grupo',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onInviteTutor(
    GroupDetailInviteTutor event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Invitando tutor...',
      ),
    );

    try {
      await _repo.inviteTutor(
        token: _token!,
        groupId: _currentGroupId!,
        payload: InviteTutorPayload(email: event.email, role: event.role),
      );

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Tutor invitado exitosamente',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onRemoveTutor(
    GroupDetailRemoveTutor event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Removiendo tutor...',
      ),
    );

    try {
      await _repo.removeTutor(
        token: _token!,
        groupId: _currentGroupId!,
        tutorId: event.tutorId,
      );

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Tutor removido del grupo',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onLoadLocations(
    GroupDetailLoadLocations event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) {
      emit(GroupDetailLoading());
    }

    try {
      final locations = await _repo.fetchGroupLocations(
        token: _token!,
        groupId: event.groupId,
      );

      if (currentGroup != null) {
        emit(GroupDetailLoaded(group: currentGroup, locations: locations));
      } else {
        final group = await _repo.fetchGroupDetail(
          token: _token!,
          groupId: event.groupId,
        );
        emit(GroupDetailLoaded(group: group, locations: locations));
      }
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  ChildGroupModel? _getCurrentGroup() {
    if (state is GroupDetailLoaded) {
      return (state as GroupDetailLoaded).group;
    }
    if (state is GroupDetailActionLoading) {
      return (state as GroupDetailActionLoading).group;
    }
    if (state is GroupDetailActionSuccess) {
      return (state as GroupDetailActionSuccess).group;
    }
    return null;
  }

  Future<void> _onCreateSafeZone(
    GroupDetailCreateSafeZone event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Creando zona segura...',
      ),
    );

    try {
      // Crear zona circular centrada en Santa Cruz de la Sierra
      final zone = GroupSafeZoneModel(
        id: 0, // El servidor asignará el ID real
        groupId: _currentGroupId!,
        name: event.name,
        zoneType: 'circle',
        centerLatitude: -17.7833, // Santa Cruz de la Sierra
        centerLongitude: -63.1821,
        radiusMeters: event.radiusMeters,
        polygonPoints: [],
        color: '#4CAF50', // Verde por defecto
        isActive: true,
      );

      await _repo.createGroupSafeZone(token: _token!, zone: zone);

      // Invalidar caché para que el mapa se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Zona segura creada exitosamente',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onCreatePolygonSafeZone(
    GroupDetailCreatePolygonSafeZone event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Creando zona segura...',
      ),
    );

    try {
      final zone = GroupSafeZoneModel(
        id: 0,
        groupId: _currentGroupId!,
        name: event.name,
        zoneType: 'polygon',
        polygonPoints: event.polygonPoints,
        color: event.color,
        isActive: true,
      );

      await _repo.createGroupSafeZone(token: _token!, zone: zone);

      // Invalidar caché para que el mapa se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Zona segura creada exitosamente',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onUpdateSafeZone(
    GroupDetailUpdateSafeZone event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Actualizando zona...',
      ),
    );

    try {
      await _repo.updateGroupSafeZone(
        token: _token!,
        zoneId: event.zoneId,
        data: {
          'name': event.name,
          'polygon_points': event.polygonPoints.map((p) => p.toJson()).toList(),
          'color': event.color,
        },
      );

      // Invalidar caché para que el mapa se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Zona actualizada exitosamente',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onDeleteSafeZone(
    GroupDetailDeleteSafeZone event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Eliminando zona...',
      ),
    );

    try {
      await _repo.deleteGroupSafeZone(token: _token!, zoneId: event.zoneId);

      // Invalidar caché para que el mapa se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      emit(
        GroupDetailActionSuccess(
          group: group,
          message: 'Zona eliminada exitosamente',
        ),
      );
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onToggleSafeZone(
    GroupDetailToggleSafeZone event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    final actionText = event.isActive ? 'Activando zona...' : 'Desactivando zona...';
    emit(GroupDetailActionLoading(group: currentGroup, action: actionText));

    try {
      await _repo.updateGroupSafeZone(
        token: _token!,
        zoneId: event.zoneId,
        data: {'is_active': event.isActive},
      );

      // Invalidar caché para que el mapa se actualice
      GroupsCacheManager.invalidate();

      final group = await _repo.fetchGroupDetail(
        token: _token!,
        groupId: _currentGroupId!,
      );

      final message = event.isActive ? 'Zona activada' : 'Zona desactivada';
      emit(GroupDetailActionSuccess(group: group, message: message));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> _onDeleteGroup(
    GroupDetailDeleteGroup event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_token == null || _currentGroupId == null) return;

    final currentGroup = _getCurrentGroup();
    if (currentGroup == null) return;

    emit(
      GroupDetailActionLoading(
        group: currentGroup,
        action: 'Eliminando grupo...',
      ),
    );

    try {
      await _repo.deleteGroup(token: _token!, groupId: _currentGroupId!);

      // Invalidar caché de grupos
      GroupsCacheManager.invalidate();

      emit(const GroupDetailDeleted('Grupo eliminado exitosamente'));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }
}
