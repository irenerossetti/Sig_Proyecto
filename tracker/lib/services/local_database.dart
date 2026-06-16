import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

/// Model for a pending location that couldn't be sent
class PendingLocation {
  final int? id;
  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final DateTime timestamp;
  final int retryCount;

  PendingLocation({
    this.id,
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'battery_level': batteryLevel,
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory PendingLocation.fromMap(Map<String, dynamic> map) {
    return PendingLocation(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      batteryLevel: map['battery_level'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode({
    'type': 'location',
    'latitude': latitude,
    'longitude': longitude,
    'battery_level': batteryLevel,
    'timestamp': timestamp.toIso8601String(),
  });
}

/// Model for cached safe zones (for local geofencing)
class CachedSafeZone {
  final int id;
  final String name;
  final String zoneType; // 'polygon' or 'circle'
  final double? centerLatitude;
  final double? centerLongitude;
  final int? radiusMeters;
  final List<Map<String, double>>? polygonPoints;
  final bool isActive;

  CachedSafeZone({
    required this.id,
    required this.name,
    required this.zoneType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    this.polygonPoints,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'zone_type': zoneType,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_meters': radiusMeters,
      'polygon_points': polygonPoints != null ? jsonEncode(polygonPoints) : null,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory CachedSafeZone.fromMap(Map<String, dynamic> map) {
    List<Map<String, double>>? points;
    if (map['polygon_points'] != null) {
      final decoded = jsonDecode(map['polygon_points'] as String) as List;
      points = decoded.map((p) => {
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
      }).toList();
    }

    return CachedSafeZone(
      id: map['id'] as int,
      name: map['name'] as String,
      zoneType: map['zone_type'] as String,
      centerLatitude: map['center_latitude'] as double?,
      centerLongitude: map['center_longitude'] as double?,
      radiusMeters: map['radius_meters'] as int?,
      polygonPoints: points,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  factory CachedSafeZone.fromApiResponse(Map<String, dynamic> json) {
    List<Map<String, double>>? points;
    if (json['polygon_points'] != null && json['polygon_points'] is List) {
      points = (json['polygon_points'] as List).map((p) => {
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
      }).toList();
    }

    return CachedSafeZone(
      id: json['id'] as int,
      name: json['name'] as String,
      zoneType: json['zone_type'] as String? ?? 'circle',
      centerLatitude: json['center_latitude'] != null 
          ? (json['center_latitude'] as num).toDouble() 
          : null,
      centerLongitude: json['center_longitude'] != null 
          ? (json['center_longitude'] as num).toDouble() 
          : null,
      radiusMeters: json['radius_meters'] as int?,
      polygonPoints: points,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Local database service for offline queue and geofence caching
class LocalDatabaseService {
  static Database? _database;
  static const String _dbName = 'geoguard_tracker.db';
  static const int _dbVersion = 1;

  /// Get the database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// Create tables
  static Future<void> _onCreate(Database db, int version) async {
    // Pending locations queue
    await db.execute('''
      CREATE TABLE pending_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        battery_level INTEGER,
        timestamp TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Cached safe zones for local geofencing
    await db.execute('''
      CREATE TABLE safe_zones (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        zone_type TEXT NOT NULL,
        center_latitude REAL,
        center_longitude REAL,
        radius_meters INTEGER,
        polygon_points TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Device configuration cache
    await db.execute('''
      CREATE TABLE device_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // ============ Pending Locations Queue ============

  /// Add a location to the pending queue
  static Future<int> addPendingLocation(PendingLocation location) async {
    final db = await database;
    return await db.insert('pending_locations', location.toMap());
  }

  /// Get all pending locations
  static Future<List<PendingLocation>> getPendingLocations({int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'pending_locations',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return results.map((map) => PendingLocation.fromMap(map)).toList();
  }

  /// Get count of pending locations
  static Future<int> getPendingLocationCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_locations');
    return result.first['count'] as int;
  }

  /// Remove a pending location after successful send
  static Future<void> removePendingLocation(int id) async {
    final db = await database;
    await db.delete('pending_locations', where: 'id = ?', whereArgs: [id]);
  }

  /// Increment retry count for a location
  static Future<void> incrementRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_locations SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Remove locations with too many retries
  static Future<int> removeFailedLocations({int maxRetries = 10}) async {
    final db = await database;
    return await db.delete(
      'pending_locations',
      where: 'retry_count >= ?',
      whereArgs: [maxRetries],
    );
  }

  /// Clear all pending locations
  static Future<void> clearPendingLocations() async {
    final db = await database;
    await db.delete('pending_locations');
  }

  // ============ Safe Zones Cache ============

  /// Save safe zones from API
  static Future<void> cacheSafeZones(List<CachedSafeZone> zones) async {
    final db = await database;
    
    // Clear existing
    await db.delete('safe_zones');
    
    // Insert new zones
    final batch = db.batch();
    for (final zone in zones) {
      batch.insert('safe_zones', zone.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Get cached safe zones
  static Future<List<CachedSafeZone>> getCachedSafeZones() async {
    final db = await database;
    final results = await db.query('safe_zones', where: 'is_active = 1');
    return results.map((map) => CachedSafeZone.fromMap(map)).toList();
  }

  /// Clear safe zones cache
  static Future<void> clearSafeZones() async {
    final db = await database;
    await db.delete('safe_zones');
  }

  // ============ Device Config ============

  /// Save a config value
  static Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'device_config',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a config value
  static Future<String?> getConfig(String key) async {
    final db = await database;
    final results = await db.query(
      'device_config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  /// Close the database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
