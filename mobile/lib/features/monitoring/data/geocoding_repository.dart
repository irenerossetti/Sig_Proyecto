import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

/// Repository para servicios de Google Cloud (Geocoding, Places)
class GeocodingRepository {
  GeocodingRepository({http.Client? client, String? token}) 
      : _client = client ?? http.Client(),
        _token = token;

  final http.Client _client;
  String? _token;
  
  // Cache local para evitar llamadas repetidas
  final Map<String, String> _addressCache = {};
  
  static const _timeout = Duration(seconds: 5);

  /// Actualizar el token
  void updateToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Token $_token',
    };
  }

  /// Convierte coordenadas a dirección legible
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    // Revisar cache primero (redondeado a 4 decimales ~11m precisión)
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_addressCache.containsKey(cacheKey)) {
      debugPrint('🗺️ Cache HIT for address: $cacheKey');
      return _addressCache[cacheKey];
    }

    if (_token == null) return null;

    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/monitoring/geocoding/reverse/'),
        headers: _headers(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🗺️ Response body: $data');
        final address = data['address'] as String?;
        
        // Guardar en cache
        if (address != null) {
          _addressCache[cacheKey] = address;
          debugPrint('🗺️ Geocoded: $address');
          
          // Limpiar cache si es muy grande
          if (_addressCache.length > 100) {
            final keysToRemove = _addressCache.keys.take(50).toList();
            for (final key in keysToRemove) {
              _addressCache.remove(key);
            }
          }
        }
        
        return address;
      }
      debugPrint('🗺️ Geocoding failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('🗺️ Geocoding error: $e');
      return null;
    }
  }

  /// Obtiene direcciones para múltiples puntos
  Future<List<AddressPoint>> batchGeocode(List<GeoPoint> points) async {
    if (points.isEmpty) return [];
    if (_token == null) return [];
    
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/monitoring/geocoding/batch/'),
        headers: _headers(),
        body: jsonEncode({
          'points': points.map((p) => {
            'latitude': p.latitude,
            'longitude': p.longitude,
          }).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;
        
        return results.map((r) => AddressPoint(
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
          address: r['address'] as String?,
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🗺️ Batch geocoding error: $e');
      return [];
    }
  }

  /// Busca lugares cercanos (escuelas, parques, etc.)
  Future<NearbyPlace?> findNearbyLandmark(
    double latitude, 
    double longitude, {
    int radius = 200,
  }) async {
    if (_token == null) return null;
    
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/monitoring/places/nearby/'),
        headers: _headers(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['name'] != null) {
          return NearbyPlace(
            name: data['name'] as String,
            type: data['type'] as String?,
            vicinity: data['vicinity'] as String?,
            distance: (data['distance'] as num?)?.toDouble(),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('🗺️ Nearby places error: $e');
      return null;
    }
  }

  /// Limpia el cache de direcciones
  void clearCache() {
    _addressCache.clear();
  }
}

/// Modelo simple para coordenadas (usado internamente para batch geocoding)
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude);
}

/// Punto con dirección
class AddressPoint {
  final double latitude;
  final double longitude;
  final String? address;

  AddressPoint({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Lugar cercano
class NearbyPlace {
  final String name;
  final String? type;
  final String? vicinity;
  final double? distance;

  NearbyPlace({
    required this.name,
    this.type,
    this.vicinity,
    this.distance,
  });

  String get formattedType {
    switch (type) {
      case 'school':
        return 'Colegio';
      case 'park':
        return 'Parque';
      case 'hospital':
        return 'Hospital';
      case 'police':
        return 'Policía';
      case 'church':
        return 'Iglesia';
      case 'shopping_mall':
        return 'Centro Comercial';
      case 'bus_station':
        return 'Terminal';
      default:
        return type ?? 'Lugar';
    }
  }

  String get formattedDistance {
    if (distance == null) return '';
    if (distance! < 1000) {
      return '${distance!.round()}m';
    }
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }
}
