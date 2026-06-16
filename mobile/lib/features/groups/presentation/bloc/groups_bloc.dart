import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/api_cache_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/group_repository.dart';
import '../../domain/group_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class GroupsEvent extends Equatable {
  const GroupsEvent();
  @override
  List<Object?> get props => [];
}

/// Solicitar lista de grupos
class GroupsFetchRequested extends GroupsEvent {
  final bool forceRefresh;
  const GroupsFetchRequested({this.forceRefresh = false});
  @override
  List<Object?> get props => [forceRefresh];
}

/// Crear un nuevo grupo
class GroupsCreateRequested extends GroupsEvent {
  final CreateGroupPayload payload;
  const GroupsCreateRequested(this.payload);
  @override
  List<Object?> get props => [payload];
}

/// Eliminar un grupo
class GroupsDeleteRequested extends GroupsEvent {
  final int groupId;
  const GroupsDeleteRequested(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

// ─────────────────────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────────────────────

abstract class GroupsState extends Equatable {
  const GroupsState();
  @override
  List<Object?> get props => [];
}

class GroupsInitial extends GroupsState {}

class GroupsLoading extends GroupsState {
  final List<ChildGroupModel>? previousData;
  const GroupsLoading({this.previousData});
  @override
  List<Object?> get props => [previousData];
}

class GroupsLoaded extends GroupsState {
  final List<ChildGroupModel> groups;
  final bool fromCache;
  final DateTime lastUpdated;

  GroupsLoaded(
    this.groups, {
    this.fromCache = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  @override
  List<Object?> get props => [groups, fromCache, lastUpdated];
}

class GroupsError extends GroupsState {
  final String message;
  final List<ChildGroupModel>? previousData;
  
  const GroupsError(this.message, {this.previousData});
  @override
  List<Object?> get props => [message, previousData];
}

class GroupsCreating extends GroupsState {}

class GroupsCreated extends GroupsState {
  final ChildGroupModel group;
  const GroupsCreated(this.group);
  @override
  List<Object?> get props => [group];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  final GroupRepository _repo;
  final AuthBloc _authBloc;
  final ApiCacheService _cache = ApiCacheService();
  
  static const String _cacheKey = 'groups_list';

  GroupsBloc({
    required GroupRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(GroupsInitial()) {
    on<GroupsFetchRequested>(_onFetchRequested);
    on<GroupsCreateRequested>(_onCreateRequested);
    on<GroupsDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onFetchRequested(
    GroupsFetchRequested event,
    Emitter<GroupsState> emit,
  ) async {
    final token = _authBloc.state.token;
    
    if (token == null || token.isEmpty) {
      emit(const GroupsError('No autenticado'));
      return;
    }

    List<ChildGroupModel>? previousData;
    if (state is GroupsLoaded) {
      previousData = (state as GroupsLoaded).groups;
    }

    // Intentar mostrar caché primero si no es force refresh
    if (!event.forceRefresh) {
      final cached = await _cache.get<List<dynamic>>(_cacheKey, category: 'groups');
      if (cached != null) {
        try {
          final groups = cached
              .map((item) => ChildGroupModel.fromJson(item as Map<String, dynamic>))
              .toList();
          emit(GroupsLoaded(groups, fromCache: true));
        } catch (e) {
          debugPrint('Error parsing cached groups: $e');
          // Limpiar caché corrupto
          await _cache.invalidate(_cacheKey);
        }
      }
    }

    if (previousData == null && state is! GroupsLoaded) {
      emit(GroupsLoading(previousData: previousData));
    }

    try {
      final groups = await _repo.fetchGroups(token: token);
      
      // Guardar en caché
      await _cache.set(
        _cacheKey,
        groups.map((g) => g.toJson()).toList(),
      );
      
      emit(GroupsLoaded(groups));
    } catch (e) {
      if (state is GroupsLoaded) {
        debugPrint('Groups refresh failed, keeping cached data: $e');
      } else if (previousData != null) {
        emit(GroupsError(e.toString(), previousData: previousData));
      } else {
        emit(GroupsError(e.toString()));
      }
    }
  }

  Future<void> _onCreateRequested(
    GroupsCreateRequested event,
    Emitter<GroupsState> emit,
  ) async {
    final token = _authBloc.state.token;
    
    if (token == null || token.isEmpty) {
      emit(const GroupsError('No autenticado'));
      return;
    }

    emit(GroupsCreating());

    try {
      final group = await _repo.createGroup(token: token, payload: event.payload);
      emit(GroupsCreated(group));
      
      // Refrescar la lista
      add(const GroupsFetchRequested(forceRefresh: true));
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onDeleteRequested(
    GroupsDeleteRequested event,
    Emitter<GroupsState> emit,
  ) async {
    final token = _authBloc.state.token;
    
    if (token == null || token.isEmpty) {
      emit(const GroupsError('No autenticado'));
      return;
    }

    try {
      await _repo.deleteGroup(token: token, groupId: event.groupId);
      
      // Refrescar la lista
      add(const GroupsFetchRequested(forceRefresh: true));
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }
}
