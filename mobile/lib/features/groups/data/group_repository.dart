import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/group_models.dart';

/// Timeout por defecto para operaciones de red
const _defaultTimeout = Duration(seconds: 10);

class GroupRepository {
  GroupRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ─────────────────────────────────────────────────────────────────────────────
  // GROUP OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Obtener todos los grupos del usuario (propios + donde es co-tutor)
  Future<List<ChildGroupModel>> fetchGroups({required String token}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener los grupos.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChildGroupModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Obtener detalle de un grupo con membresías, tutores y zonas
  Future<ChildGroupModel> fetchGroupDetail({
    required String token,
    required int groupId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo obtener el detalle del grupo.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChildGroupModel.fromJson(data);
  }

  /// Crear un nuevo grupo
  Future<ChildGroupModel> createGroup({
    required String token,
    required CreateGroupPayload payload,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(payload.toJson()),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo crear el grupo.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChildGroupModel.fromJson(data);
  }

  /// Actualizar un grupo
  Future<ChildGroupModel> updateGroup({
    required String token,
    required int groupId,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo actualizar el grupo.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ChildGroupModel.fromJson(json);
  }

  /// Eliminar un grupo
  Future<void> deleteGroup({
    required String token,
    required int groupId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/');
    final response = await _client.delete(uri, headers: _headers(token)).timeout(_defaultTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      _ensureSuccess(response, 'No se pudo eliminar el grupo.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MEMBERSHIP OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Obtener los miembros de un grupo
  Future<List<GroupMembershipModel>> fetchGroupMembers({
    required String token,
    required int groupId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/members/');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener los miembros del grupo.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => GroupMembershipModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Agregar un niño al grupo
  Future<GroupMembershipModel> addChildToGroup({
    required String token,
    required int groupId,
    required int childId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/add-child/');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'child_id': childId}),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo agregar el niño al grupo.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupMembershipModel.fromJson(data);
  }

  /// Remover un niño del grupo
  Future<void> removeChildFromGroup({
    required String token,
    required int groupId,
    required int childId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/remove-child/');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'child_id': childId}),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo remover el niño del grupo.');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TUTOR OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Invitar a un co-tutor por email
  Future<GroupTutorModel> inviteTutor({
    required String token,
    required int groupId,
    required InviteTutorPayload payload,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/invite-tutor/');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(payload.toJson()),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo invitar al tutor.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupTutorModel.fromJson(data);
  }

  /// Remover a un co-tutor
  Future<void> removeTutor({
    required String token,
    required int groupId,
    required int tutorId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/remove-tutor/');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'tutor_id': tutorId}),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo remover al tutor.');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LOCATIONS (MAP VIEW)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Obtener ubicaciones de todos los niños del grupo para el mapa
  Future<GroupLocationsResponse> fetchGroupLocations({
    required String token,
    required int groupId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groups}$groupId/locations/');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener las ubicaciones del grupo.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupLocationsResponse.fromJson(data);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GROUP SAFE ZONES
  // ─────────────────────────────────────────────────────────────────────────────

  /// Obtener todas las zonas seguras de grupos
  Future<List<GroupSafeZoneModel>> fetchGroupSafeZones({required String token}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groupSafeZones}');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener las zonas seguras de grupos.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => GroupSafeZoneModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Crear una zona segura para un grupo
  Future<GroupSafeZoneModel> createGroupSafeZone({
    required String token,
    required GroupSafeZoneModel zone,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groupSafeZones}');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(zone.toJson()),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo crear la zona segura del grupo.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupSafeZoneModel.fromJson(data);
  }

  /// Actualizar una zona segura de grupo
  Future<GroupSafeZoneModel> updateGroupSafeZone({
    required String token,
    required int zoneId,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groupSafeZones}$zoneId/');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo actualizar la zona segura.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupSafeZoneModel.fromJson(json);
  }

  /// Eliminar una zona segura de grupo
  Future<void> deleteGroupSafeZone({
    required String token,
    required int zoneId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.groupSafeZones}$zoneId/');
    final response = await _client.delete(uri, headers: _headers(token)).timeout(_defaultTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      _ensureSuccess(response, 'No se pudo eliminar la zona segura.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  void _ensureSuccess(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GroupRepositoryException(_extractError(response, fallback: fallback));
  }

  String _extractError(http.Response response, {required String fallback}) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['detail'] != null) return json['detail'].toString();
      if (json['error'] != null) return json['error'].toString();
      final errors = <String>[];
      json.forEach((key, value) {
        if (value is List) {
          errors.addAll(value.map((e) => e.toString()));
        } else {
          errors.add(value.toString());
        }
      });
      if (errors.isNotEmpty) return errors.join(', ');
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

class GroupRepositoryException implements Exception {
  GroupRepositoryException(this.message);
  final String message;
  @override
  String toString() => 'GroupRepositoryException: $message';
}
