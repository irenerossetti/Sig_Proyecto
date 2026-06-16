import 'package:equatable/equatable.dart';
import '../../monitoring/domain/monitoring_models.dart';
export '../../monitoring/domain/monitoring_models.dart' show LatLngPoint;

/// Modelo de un grupo de niños
class ChildGroupModel extends Equatable {
  const ChildGroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.ownerName,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.membersCount,
    required this.tutorsCount,
    this.memberships,
    this.tutors,
    this.safeZones,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final int ownerId;
  final String? ownerName;
  final String color;
  final String icon;
  final bool isActive;
  final int membersCount;
  final int tutorsCount;
  final List<GroupMembershipModel>? memberships;
  final List<GroupTutorModel>? tutors;
  final List<GroupSafeZoneModel>? safeZones;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        ownerId,
        ownerName,
        color,
        icon,
        isActive,
        membersCount,
        tutorsCount,
        memberships,
        tutors,
        safeZones,
        createdAt,
        updatedAt,
      ];

  factory ChildGroupModel.fromJson(Map<String, dynamic> json) {
    return ChildGroupModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      ownerId: json['owner'] as int? ?? 0,
      ownerName: json['owner_name']?.toString(),
      color: json['color']?.toString() ?? '#1E88E5',
      icon: json['icon']?.toString() ?? 'users',
      isActive: json['is_active'] as bool? ?? true,
      membersCount: json['members_count'] as int? ?? 0,
      tutorsCount: json['tutors_count'] as int? ?? 0,
      memberships: (json['memberships'] as List<dynamic>?)
          ?.map((m) => GroupMembershipModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      tutors: (json['tutors'] as List<dynamic>?)
          ?.map((t) => GroupTutorModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      safeZones: (json['safe_zones'] as List<dynamic>?)
          ?.map((z) => GroupSafeZoneModel.fromJson(z as Map<String, dynamic>))
          .toList(),
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
      'id': id,
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'owner': ownerId,
      if (ownerName != null) 'owner_name': ownerName,
      'color': color,
      'icon': icon,
      'is_active': isActive,
      'members_count': membersCount,
      'tutors_count': tutorsCount,
      if (memberships != null)
        'memberships': memberships!.map((m) => m.toJson()).toList(),
      if (tutors != null) 'tutors': tutors!.map((t) => t.toJson()).toList(),
      if (safeZones != null)
        'safe_zones': safeZones!.map((z) => z.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Verifica si el usuario es el dueño del grupo
  bool isOwner(int userId) => ownerId == userId;

  /// Obtiene el rol del usuario en el grupo (owner, admin, monitor, o null si no pertenece)
  String? getUserRole(int userId) {
    if (isOwner(userId)) return 'owner';
    final tutor = tutors?.firstWhere(
      (t) => t.tutorId == userId && t.isActive,
      orElse: () => const GroupTutorModel(
        id: -1,
        groupId: 0,
        tutorId: 0,
        role: '',
        isActive: false,
      ),
    );
    if (tutor?.id == -1) return null;
    return tutor?.role;
  }

  /// Verifica si el usuario puede editar el grupo (owner o admin)
  bool canEdit(int userId) {
    final role = getUserRole(userId);
    return role == 'owner' || role == 'admin';
  }

  /// Verifica si el usuario solo puede ver (monitor)
  bool isReadOnly(int userId) {
    final role = getUserRole(userId);
    return role == 'monitor';
  }

  ChildGroupModel copyWith({
    int? id,
    String? name,
    String? description,
    int? ownerId,
    String? ownerName,
    String? color,
    String? icon,
    bool? isActive,
    int? membersCount,
    int? tutorsCount,
    List<GroupMembershipModel>? memberships,
    List<GroupTutorModel>? tutors,
    List<GroupSafeZoneModel>? safeZones,
  }) {
    return ChildGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      membersCount: membersCount ?? this.membersCount,
      tutorsCount: tutorsCount ?? this.tutorsCount,
      memberships: memberships ?? this.memberships,
      tutors: tutors ?? this.tutors,
      safeZones: safeZones ?? this.safeZones,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Modelo de membresía de un niño en un grupo
class GroupMembershipModel extends Equatable {
  const GroupMembershipModel({
    required this.id,
    required this.groupId,
    required this.childId,
    this.childName,
    this.childPhoto,
    this.addedById,
    this.addedByName,
    required this.isActive,
    this.joinedAt,
  });

  final int id;
  final int groupId;
  final int childId;
  final String? childName;
  final String? childPhoto;
  final int? addedById;
  final String? addedByName;
  final bool isActive;
  final DateTime? joinedAt;

  @override
  List<Object?> get props => [
        id,
        groupId,
        childId,
        childName,
        childPhoto,
        addedById,
        addedByName,
        isActive,
        joinedAt,
      ];

  factory GroupMembershipModel.fromJson(Map<String, dynamic> json) {
    return GroupMembershipModel(
      id: json['id'] as int,
      groupId: json['group'] as int? ?? 0,
      childId: json['child'] as int? ?? 0,
      childName: json['child_name']?.toString(),
      childPhoto: json['child_photo']?.toString(),
      addedById: json['added_by'] as int?,
      addedByName: json['added_by_name']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group': groupId,
      'child': childId,
      if (childName != null) 'child_name': childName,
      if (childPhoto != null) 'child_photo': childPhoto,
      if (addedById != null) 'added_by': addedById,
      if (addedByName != null) 'added_by_name': addedByName,
      'is_active': isActive,
      if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
    };
  }
}

/// Modelo de un co-tutor del grupo
class GroupTutorModel extends Equatable {
  const GroupTutorModel({
    required this.id,
    required this.groupId,
    required this.tutorId,
    this.tutorName,
    this.tutorEmail,
    required this.role,
    this.invitedById,
    this.invitedByName,
    required this.isActive,
    this.joinedAt,
  });

  final int id;
  final int groupId;
  final int tutorId;
  final String? tutorName;
  final String? tutorEmail;
  final String role; // 'admin' or 'monitor'
  final int? invitedById;
  final String? invitedByName;
  final bool isActive;
  final DateTime? joinedAt;

  @override
  List<Object?> get props => [
        id,
        groupId,
        tutorId,
        tutorName,
        tutorEmail,
        role,
        invitedById,
        invitedByName,
        isActive,
        joinedAt,
      ];

  factory GroupTutorModel.fromJson(Map<String, dynamic> json) {
    return GroupTutorModel(
      id: json['id'] as int,
      groupId: json['group'] as int? ?? 0,
      tutorId: json['tutor'] as int? ?? 0,
      tutorName: json['tutor_name']?.toString(),
      tutorEmail: json['tutor_email']?.toString(),
      role: json['role']?.toString() ?? 'monitor',
      invitedById: json['invited_by'] as int?,
      invitedByName: json['invited_by_name']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group': groupId,
      'tutor': tutorId,
      if (tutorName != null) 'tutor_name': tutorName,
      if (tutorEmail != null) 'tutor_email': tutorEmail,
      'role': role,
      if (invitedById != null) 'invited_by': invitedById,
      if (invitedByName != null) 'invited_by_name': invitedByName,
      'is_active': isActive,
      if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isMonitor => role == 'monitor';
}

/// Modelo de zona segura del grupo
class GroupSafeZoneModel extends Equatable {
  const GroupSafeZoneModel({
    required this.id,
    required this.groupId,
    this.groupName,
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
  final int groupId;
  final String? groupName;
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
  List<Object?> get props => [
        id,
        groupId,
        groupName,
        name,
        zoneType,
        centerLatitude,
        centerLongitude,
        radiusMeters,
        polygonPoints,
        color,
        isActive,
        createdAt,
        updatedAt,
      ];

  factory GroupSafeZoneModel.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['polygon_points'] as List<dynamic>? ?? [];
    final points = pointsJson
        .map((p) => LatLngPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    return GroupSafeZoneModel(
      id: json['id'] as int,
      groupId: json['group'] as int? ?? 0,
      groupName: json['group_name']?.toString(),
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
      'id': id,
      'group': groupId,
      if (groupName != null) 'group_name': groupName,
      'name': name,
      'zone_type': zoneType,
      if (centerLatitude != null) 'center_latitude': centerLatitude,
      if (centerLongitude != null) 'center_longitude': centerLongitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      'polygon_points': polygonPoints.map((p) => p.toJson()).toList(),
      'color': color,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  GroupSafeZoneModel copyWith({
    int? id,
    int? groupId,
    String? groupName,
    String? name,
    String? zoneType,
    double? centerLatitude,
    double? centerLongitude,
    int? radiusMeters,
    List<LatLngPoint>? polygonPoints,
    String? color,
    bool? isActive,
  }) {
    return GroupSafeZoneModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
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

/// Modelo de niño con ubicación para vista de mapa del grupo
class GroupChildLocation extends Equatable {
  const GroupChildLocation({
    required this.childId,
    required this.childName,
    this.photoUrl,
    required this.isActive,
    this.device,
  });

  final int childId;
  final String childName;
  final String? photoUrl;
  final bool isActive;
  final DeviceModel? device;

  @override
  List<Object?> get props => [childId, childName, photoUrl, isActive, device];

  factory GroupChildLocation.fromJson(Map<String, dynamic> json) {
    return GroupChildLocation(
      childId: json['id'] as int,
      childName: json['full_name']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      device: json['device'] != null
          ? DeviceModel.fromJson(json['device'] as Map<String, dynamic>)
          : null,
    );
  }

  double? get latitude => device?.lastLatitude;
  double? get longitude => device?.lastLongitude;
  bool get hasLocation => latitude != null && longitude != null;
}

/// Respuesta de ubicaciones de grupo
class GroupLocationsResponse extends Equatable {
  const GroupLocationsResponse({
    required this.groupId,
    required this.groupName,
    required this.children,
    required this.safeZones,
    required this.childSafeZones,
  });

  final int groupId;
  final String groupName;
  final List<GroupChildLocation> children;
  final List<GroupSafeZoneModel> safeZones;
  final List<SafeZoneModel> childSafeZones;

  @override
  List<Object?> get props => [groupId, groupName, children, safeZones, childSafeZones];

  factory GroupLocationsResponse.fromJson(Map<String, dynamic> json) {
    return GroupLocationsResponse(
      groupId: json['group_id'] as int,
      groupName: json['group_name']?.toString() ?? '',
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => GroupChildLocation.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      safeZones: (json['safe_zones'] as List<dynamic>?)
              ?.map((z) => GroupSafeZoneModel.fromJson(z as Map<String, dynamic>))
              .toList() ??
          [],
      childSafeZones: (json['child_safe_zones'] as List<dynamic>?)
              ?.map((z) => SafeZoneModel.fromJson(z as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Payload para crear un grupo
class CreateGroupPayload {
  const CreateGroupPayload({
    required this.name,
    this.description,
    this.color = '#1E88E5',
    this.icon = 'users',
  });

  final String name;
  final String? description;
  final String color;
  final String icon;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'color': color,
      'icon': icon,
    };
  }
}

/// Payload para invitar a un tutor
class InviteTutorPayload {
  const InviteTutorPayload({
    required this.email,
    this.role = 'monitor',
  });

  final String email;
  final String role;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'role': role,
    };
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}
