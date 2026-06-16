import 'package:equatable/equatable.dart';

class DeviceModel extends Equatable {
  const DeviceModel({
    required this.id,
    required this.deviceId,
    this.deviceType,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSeen,
    this.batteryLevel,
    required this.isActive,
    this.isOnline = false,
  });

  final int id;
  final String deviceId;
  final String? deviceType;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastSeen;
  final int? batteryLevel;
  final bool isActive;
  /// Indica si el dispositivo está realmente en línea (last_seen < 5 minutos)
  final bool isOnline;

  @override
  List<Object?> get props => [id, deviceId, deviceType, lastLatitude, lastLongitude, lastSeen, batteryLevel, isActive, isOnline];

  /// Crea una copia del modelo con valores actualizados
  DeviceModel copyWith({
    int? id,
    String? deviceId,
    String? deviceType,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastSeen,
    int? batteryLevel,
    bool? isActive,
    bool? isOnline,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastSeen: lastSeen ?? this.lastSeen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  factory DeviceModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DeviceModel(
        id: 0,
        deviceId: '',
        isActive: false,
        isOnline: false,
      );
    }
    return DeviceModel(
      id: json['id'] as int? ?? 0,
      deviceId: json['device_id']?.toString() ?? '',
      deviceType: json['device_type']?.toString(),
      lastLatitude: _toDouble(json['last_latitude']),
      lastLongitude: _toDouble(json['last_longitude']),
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen'].toString()) : null,
      batteryLevel: json['battery_level'] as int?,
      isActive: json['is_active'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  /// Serializa el modelo a JSON para caché
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      if (deviceType != null) 'device_type': deviceType,
      if (lastLatitude != null) 'last_latitude': lastLatitude,
      if (lastLongitude != null) 'last_longitude': lastLongitude,
      if (lastSeen != null) 'last_seen': lastSeen!.toIso8601String(),
      if (batteryLevel != null) 'battery_level': batteryLevel,
      'is_active': isActive,
      'is_online': isOnline,
    };
  }
}

class ChildModel extends Equatable {
  const ChildModel({
    required this.id,
    required this.fullName,
    required this.dateOfBirth,
    this.photoUrl,
    this.notes,
    required this.isActive,
    this.device,
    this.createdAt,
    this.updatedAt,
    this.isOwnChild = true,
    this.tutorName,
  });

  final int id;
  final String fullName;
  final DateTime dateOfBirth;
  final String? photoUrl;
  final String? notes;
  final bool isActive;
  final DeviceModel? device;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Indica si el niño pertenece directamente al usuario actual (true) o viene de un grupo compartido (false)
  final bool isOwnChild;
  /// Nombre del tutor propietario del niño (útil cuando no es hijo propio)
  final String? tutorName;

  @override
  List<Object?> get props => [id, fullName, dateOfBirth, photoUrl, notes, isActive, device, createdAt, updatedAt, isOwnChild, tutorName];

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'] as int,
      fullName: json['full_name']?.toString() ?? '',
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      photoUrl: json['photo_url']?.toString() ?? json['photo']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      device: json['device'] != null ? DeviceModel.fromJson(json['device'] as Map<String, dynamic>) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      isOwnChild: json['is_own_child'] as bool? ?? true,
      tutorName: json['tutor_name']?.toString(),
    );
  }

  /// Serializa el modelo a JSON para caché
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (notes != null) 'notes': notes,
      'is_active': isActive,
      if (device != null) 'device': device!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_own_child': isOwnChild,
      if (tutorName != null) 'tutor_name': tutorName,
    };
  }
}

class AlertModel extends Equatable {
  const AlertModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.message,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final int id;
  final int childId;
  final String childName;
  final String message;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, childId, childName, message, status, latitude, longitude, createdAt];

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as int,
      childId: json['child'] as int,
      childName: json['child_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Serializa el modelo a JSON para caché
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child': childId,
      'child_name': childName,
      'message': message,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CreateChildPayload {
  const CreateChildPayload({
    required this.fullName,
    required this.dateOfBirth,
    this.notes,
    this.photoPath,
  });

  final String fullName;
  final DateTime dateOfBirth;
  final String? notes;
  final String? photoPath; // Local file path for photo upload

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
  
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalChildren,
    required this.activeDevices,
    required this.pendingAlerts,
  });

  final int totalChildren;
  final int activeDevices;
  final int pendingAlerts;

  @override
  List<Object?> get props => [totalChildren, activeDevices, pendingAlerts];
}

/// Representa un punto de coordenadas
class LatLngPoint extends Equatable {
  const LatLngPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory LatLngPoint.fromJson(Map<String, dynamic> json) {
    return LatLngPoint(
      lat: _toDouble(json['lat']) ?? 0,
      lng: _toDouble(json['lng']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  List<Object?> get props => [lat, lng];
}

/// Modelo de zona segura (geocerca)
class SafeZoneModel extends Equatable {
  const SafeZoneModel({
    required this.id,
    required this.childId,
    this.childName,
    required this.name,
    required this.zoneType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    required this.polygonPoints,
    required this.color,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int childId;
  final String? childName;
  final String name;
  final String zoneType; // 'polygon' o 'circle'
  final double? centerLatitude;
  final double? centerLongitude;
  final int? radiusMeters;
  final List<LatLngPoint> polygonPoints;
  final String color;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, childId, childName, name, zoneType, centerLatitude, centerLongitude, radiusMeters, polygonPoints, color, isActive, createdAt, updatedAt];

  factory SafeZoneModel.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['polygon_points'] as List<dynamic>? ?? [];
    final points = pointsJson
        .map((p) => LatLngPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    return SafeZoneModel(
      id: json['id'] as int,
      childId: json['child'] as int,
      childName: json['child_name']?.toString(),
      name: json['name']?.toString() ?? '',
      zoneType: json['zone_type']?.toString() ?? 'polygon',
      centerLatitude: _toDouble(json['center_latitude']),
      centerLongitude: _toDouble(json['center_longitude']),
      radiusMeters: json['radius_meters'] as int?,
      polygonPoints: points,
      color: json['color']?.toString() ?? '#1E8E3E',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'child': childId,
      'name': name,
      'zone_type': zoneType,
      if (centerLatitude != null) 'center_latitude': centerLatitude,
      if (centerLongitude != null) 'center_longitude': centerLongitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      'polygon_points': polygonPoints.map((p) => p.toJson()).toList(),
      'color': color,
      'is_active': isActive,
    };
  }

  SafeZoneModel copyWith({
    int? id,
    int? childId,
    String? childName,
    String? name,
    String? zoneType,
    double? centerLatitude,
    double? centerLongitude,
    int? radiusMeters,
    List<LatLngPoint>? polygonPoints,
    String? color,
    bool? isActive,
  }) {
    return SafeZoneModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      name: name ?? this.name,
      zoneType: zoneType ?? this.zoneType,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Payload para crear una zona segura
class CreateSafeZonePayload {
  const CreateSafeZonePayload({
    required this.childId,
    required this.name,
    required this.zoneType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    required this.polygonPoints,
    this.color = '#1E8E3E',
  });

  final int childId;
  final String name;
  final String zoneType;
  final double? centerLatitude;
  final double? centerLongitude;
  final int? radiusMeters;
  final List<LatLngPoint> polygonPoints;
  final String color;

  Map<String, dynamic> toJson() {
    return {
      'child': childId,
      'name': name,
      'zone_type': zoneType,
      if (centerLatitude != null) 'center_latitude': centerLatitude,
      if (centerLongitude != null) 'center_longitude': centerLongitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      'polygon_points': polygonPoints.map((p) => p.toJson()).toList(),
      'color': color,
      'is_active': true,
    };
  }
}
