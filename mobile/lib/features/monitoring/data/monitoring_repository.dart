import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/monitoring_models.dart';

/// Timeout por defecto para operaciones de red - optimizado para GCE
const _defaultTimeout = Duration(seconds: 10);
/// Timeout más corto para operaciones frecuentes
const _fastTimeout = Duration(seconds: 5);

class MonitoringRepository {
  MonitoringRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  
  // Cache en memoria para requests recientes (evita llamadas duplicadas)
  final Map<String, _CachedResponse> _memoryCache = {};
  static const _memoryCacheDuration = Duration(seconds: 2);

  Future<List<ChildModel>> fetchChildren({required String token}) async {
    // Verificar cache en memoria para evitar requests duplicados
    final cacheKey = 'children_$token';
    final cached = _getMemoryCache<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached.map((item) => ChildModel.fromJson(item as Map<String, dynamic>)).toList();
    }

    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.children);
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener los niños.');
    final data = jsonDecode(response.body) as List<dynamic>;
    
    // Guardar en cache de memoria
    _setMemoryCache(cacheKey, data);
    
    return data.map((item) => ChildModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChildModel> createChild({
    required String token,
    required CreateChildPayload payload,
  }) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.children);
    
    if (payload.hasPhoto) {
      // Use multipart request for photo upload
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $token';
      
      // Add text fields
      request.fields['full_name'] = payload.fullName;
      request.fields['date_of_birth'] = payload.dateOfBirth.toIso8601String().split('T').first;
      if (payload.notes != null && payload.notes!.isNotEmpty) {
        request.fields['notes'] = payload.notes!;
      }
      
      // Add photo file
      final photoFile = File(payload.photoPath!);
      request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));
      
      final streamedResponse = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      _ensureSuccess(response, 'No se pudo registrar al niño.');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ChildModel.fromJson(json);
    } else {
      // Regular JSON request without photo
      final response = await _client.post(
        uri,
        headers: _headers(token),
        body: jsonEncode(payload.toJson()),
      ).timeout(_defaultTimeout);
      _ensureSuccess(response, 'No se pudo registrar al niño.');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ChildModel.fromJson(json);
    }
  }

  Future<List<AlertModel>> fetchAlerts({required String token}) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.alerts);
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron cargar las alertas.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => AlertModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChildModel> fetchChildDetail({
    required String token,
    required int childId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.children}$childId/');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_fastTimeout);
    _ensureSuccess(response, 'No se pudo obtener la ubicación del niño.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChildModel.fromJson(data);
  }

  Future<ChildModel> updateChild({
    required String token,
    required int childId,
    required CreateChildPayload payload,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.children}$childId/');
    
    if (payload.hasPhoto) {
      // Use multipart request for photo upload
      final request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Token $token';
      
      // Add text fields
      request.fields['full_name'] = payload.fullName;
      request.fields['date_of_birth'] = payload.dateOfBirth.toIso8601String().split('T').first;
      if (payload.notes != null && payload.notes!.isNotEmpty) {
        request.fields['notes'] = payload.notes!;
      }
      
      // Add photo file
      final photoFile = File(payload.photoPath!);
      request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));
      
      final streamedResponse = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      _ensureSuccess(response, 'No se pudo actualizar al niño.');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ChildModel.fromJson(json);
    } else {
      // Regular JSON request without photo
      final response = await _client.patch(
        uri,
        headers: _headers(token),
        body: jsonEncode(payload.toJson()),
      ).timeout(_defaultTimeout);
      _ensureSuccess(response, 'No se pudo actualizar al niño.');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ChildModel.fromJson(json);
    }
  }

  Future<void> deleteChild({
    required String token,
    required int childId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.children}$childId/');
    final response = await _client.delete(uri, headers: _headers(token)).timeout(_defaultTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      _ensureSuccess(response, 'No se pudo eliminar al niño.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DEVICE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<DeviceModel> createDevice({
    required String token,
    required int childId,
    required String deviceId,
    String? deviceType,
  }) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.devices);
    final body = {
      'child_id': childId,
      'device_id': deviceId,
      if (deviceType != null) 'device_type': deviceType,
    };
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo registrar el dispositivo.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DeviceModel.fromJson(json);
  }

  // NOTA: updateDeviceLocation ELIMINADO - ahora se usa WebSocket 100%
  // Ver TrackerWebSocketService para envío de ubicaciones en tiempo real

  Future<List<DeviceModel>> fetchDevices({required String token}) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.devices);
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener los dispositivos.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => DeviceModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAFE ZONE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<SafeZoneModel>> fetchSafeZones({
    required String token,
    int? childId,
  }) async {
    var url = '${ApiConstants.baseUrl}${ApiConstants.safeZones}';
    if (childId != null) {
      url += '?child=$childId';
    }
    final uri = Uri.parse(url);
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudieron obtener las zonas seguras.');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => SafeZoneModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SafeZoneModel> fetchSafeZoneDetail({
    required String token,
    required int zoneId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.safeZones}$zoneId/');
    final response = await _client.get(uri, headers: _headers(token)).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo obtener la zona segura.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SafeZoneModel.fromJson(data);
  }

  Future<SafeZoneModel> createSafeZone({
    required String token,
    required CreateSafeZonePayload payload,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.safeZones}');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(payload.toJson()),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo crear la zona segura.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SafeZoneModel.fromJson(json);
  }

  Future<SafeZoneModel> updateSafeZone({
    required String token,
    required int zoneId,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.safeZones}$zoneId/');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo actualizar la zona segura.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SafeZoneModel.fromJson(json);
  }

  Future<void> deleteSafeZone({
    required String token,
    required int zoneId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.safeZones}$zoneId/');
    final response = await _client.delete(uri, headers: _headers(token)).timeout(_defaultTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      _ensureSuccess(response, 'No se pudo eliminar la zona segura.');
    }
  }

  Future<bool> checkPointInZone({
    required String token,
    required int zoneId,
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.safeZones}$zoneId/check-point/');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    ).timeout(_defaultTimeout);
    _ensureSuccess(response, 'No se pudo verificar el punto.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['is_inside'] as bool? ?? false;
  }

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
    throw MonitoringRepositoryException(_extractError(response, fallback: fallback));
  }

  String _extractError(http.Response response, {required String fallback}) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['detail'] != null) return json['detail'].toString();
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

  // ─────────────────────────────────────────────────────────────────────────────
  // MEMORY CACHE HELPERS - evita requests duplicados en corto tiempo
  // ─────────────────────────────────────────────────────────────────────────────

  T? _getMemoryCache<T>(String key) {
    final cached = _memoryCache[key];
    if (cached == null) return null;
    
    if (DateTime.now().difference(cached.timestamp) > _memoryCacheDuration) {
      _memoryCache.remove(key);
      return null;
    }
    
    return cached.data as T?;
  }

  void _setMemoryCache(String key, dynamic data) {
    // Limpiar cache viejo si hay muchas entradas
    if (_memoryCache.length > 20) {
      final now = DateTime.now();
      _memoryCache.removeWhere(
        (_, v) => now.difference(v.timestamp) > _memoryCacheDuration,
      );
    }
    
    _memoryCache[key] = _CachedResponse(data: data, timestamp: DateTime.now());
  }

  void invalidateMemoryCache([String? key]) {
    if (key != null) {
      _memoryCache.remove(key);
    } else {
      _memoryCache.clear();
    }
  }
}

class _CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  
  _CachedResponse({required this.data, required this.timestamp});
}

class MonitoringRepositoryException implements Exception {
  MonitoringRepositoryException(this.message);
  final String message;
  @override
  String toString() => 'MonitoringRepositoryException: $message';
}
