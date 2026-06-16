import 'dart:math';
import 'package:flutter/foundation.dart';
import 'local_database.dart';

/// Result of a geofence check
class GeofenceResult {
  final bool isInAnyZone;
  final List<CachedSafeZone> containingZones;
  final CachedSafeZone? nearestZone;
  final double? distanceToNearest; // meters

  GeofenceResult({
    required this.isInAnyZone,
    required this.containingZones,
    this.nearestZone,
    this.distanceToNearest,
  });
}

/// Local geofencing service for offline zone checking
class GeofenceService {
  List<CachedSafeZone> _cachedZones = [];
  bool _isInitialized = false;

  /// Initialize the service and load cached zones
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cachedZones = await LocalDatabaseService.getCachedSafeZones();
      _isInitialized = true;
      debugPrint('🗺️ Geofence: Loaded ${_cachedZones.length} zones from cache');
    } catch (e) {
      debugPrint('❌ Geofence: Error loading zones: $e');
    }
  }

  /// Update cached zones from API response
  Future<void> updateZones(List<Map<String, dynamic>> zonesData) async {
    try {
      final zones = zonesData
          .map((z) => CachedSafeZone.fromApiResponse(z))
          .toList();
      
      await LocalDatabaseService.cacheSafeZones(zones);
      _cachedZones = zones;
      
      debugPrint('🗺️ Geofence: Updated ${zones.length} zones');
    } catch (e) {
      debugPrint('❌ Geofence: Error updating zones: $e');
    }
  }

  /// Check if a point is inside any safe zone
  GeofenceResult checkPoint(double latitude, double longitude) {
    if (_cachedZones.isEmpty) {
      return GeofenceResult(
        isInAnyZone: true, // Assume safe if no zones configured
        containingZones: [],
      );
    }

    final containingZones = <CachedSafeZone>[];
    CachedSafeZone? nearestZone;
    double? minDistance;

    for (final zone in _cachedZones) {
      if (!zone.isActive) continue;

      final isInside = _isPointInZone(latitude, longitude, zone);
      
      if (isInside) {
        containingZones.add(zone);
      } else {
        // Calculate distance to zone
        final distance = _distanceToZone(latitude, longitude, zone);
        if (distance != null && (minDistance == null || distance < minDistance)) {
          minDistance = distance;
          nearestZone = zone;
        }
      }
    }

    return GeofenceResult(
      isInAnyZone: containingZones.isNotEmpty,
      containingZones: containingZones,
      nearestZone: nearestZone,
      distanceToNearest: minDistance,
    );
  }

  /// Check if point is inside a specific zone
  bool _isPointInZone(double lat, double lng, CachedSafeZone zone) {
    if (zone.zoneType == 'circle') {
      return _isPointInCircle(lat, lng, zone);
    } else if (zone.zoneType == 'polygon' && zone.polygonPoints != null) {
      return _isPointInPolygon(lat, lng, zone.polygonPoints!);
    }
    return false;
  }

  /// Check if point is inside a circle zone using Haversine formula
  bool _isPointInCircle(double lat, double lng, CachedSafeZone zone) {
    if (zone.centerLatitude == null || zone.centerLongitude == null) {
      return false;
    }

    final distance = _haversineDistance(
      lat, lng,
      zone.centerLatitude!, zone.centerLongitude!,
    );

    final radius = zone.radiusMeters ?? 100;
    return distance <= radius;
  }

  /// Check if point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(double lat, double lng, List<Map<String, double>> points) {
    if (points.length < 3) return false;

    bool inside = false;
    int j = points.length - 1;

    for (int i = 0; i < points.length; i++) {
      final xi = points[i]['lat']!;
      final yi = points[i]['lng']!;
      final xj = points[j]['lat']!;
      final yj = points[j]['lng']!;

      if (((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Calculate distance to the nearest point of a zone
  double? _distanceToZone(double lat, double lng, CachedSafeZone zone) {
    if (zone.zoneType == 'circle') {
      if (zone.centerLatitude == null || zone.centerLongitude == null) {
        return null;
      }
      final distanceToCenter = _haversineDistance(
        lat, lng,
        zone.centerLatitude!, zone.centerLongitude!,
      );
      final radius = zone.radiusMeters ?? 100;
      return max(0, distanceToCenter - radius);
    } else if (zone.zoneType == 'polygon' && zone.polygonPoints != null) {
      // Find minimum distance to any edge/vertex
      double minDist = double.infinity;
      for (final point in zone.polygonPoints!) {
        final dist = _haversineDistance(lat, lng, point['lat']!, point['lng']!);
        if (dist < minDist) minDist = dist;
      }
      return minDist;
    }
    return null;
  }

  /// Calculate distance between two points using Haversine formula
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * asin(sqrt(a));
    
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Get the number of cached zones
  int get zoneCount => _cachedZones.length;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Clear all cached zones
  Future<void> clearCache() async {
    await LocalDatabaseService.clearSafeZones();
    _cachedZones = [];
  }
}

/// Singleton instance
final geofenceService = GeofenceService();