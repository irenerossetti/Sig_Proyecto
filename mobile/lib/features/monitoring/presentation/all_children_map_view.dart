import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/image_cache_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/domain/group_models.dart';
import '../data/monitoring_repository.dart';
import '../domain/monitoring_models.dart';

/// Clase para manejar el caché de zonas seguras del mapa
/// Permite invalidar el caché desde cualquier parte de la app
class SafeZonesCacheManager {
  static int _version = 0;

  /// Versión actual del caché
  static int get version => _version;

  /// Invalida el caché de zonas seguras
  /// Llamar cuando se crea, edita o elimina una zona
  static void invalidate() {
    _version++;
    debugPrint('🔄 SafeZones cache invalidated (v$_version)');
  }
}

/// Clase para manejar el caché de grupos del mapa
/// Permite invalidar cuando se agregan/eliminan miembros de grupos
class GroupsCacheManager {
  static int _version = 0;

  /// Versión actual del caché
  static int get version => _version;

  /// Invalida el caché de grupos
  /// Llamar cuando se agrega/elimina un niño de un grupo
  static void invalidate() {
    _version++;
    debugPrint('🔄 Groups cache invalidated (v$_version)');
  }
}

/// Tipos de filtro para el mapa
enum MapFilterType { all, group, single }

/// Widget de mapa que muestra todos los niños simultáneamente con filtros
class AllChildrenMapView extends StatefulWidget {
  const AllChildrenMapView({
    super.key,
    required this.children,
    this.onChildTapped,
  });

  final List<ChildModel> children;
  final void Function(ChildModel child)? onChildTapped;

  @override
  State<AllChildrenMapView> createState() => _AllChildrenMapViewState();
}

class _AllChildrenMapViewState extends State<AllChildrenMapView> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;

  // Caché de marcadores
  final MapImageCacheService _markerCache = MapImageCacheService();
  final Map<int, BitmapDescriptor> _childMarkers = {};

  // Zonas seguras
  List<SafeZoneModel> _allSafeZones = [];
  bool _showSafeZones = true;

  // Versión de zonas que tenemos cargada (usa el manager global)
  int _loadedVersion = -1;

  // Versión de grupos que tenemos cargada
  int _loadedGroupsVersion = -1;

  // Niño seleccionado para mostrar info
  ChildModel? _selectedChild;

  // Filtros
  MapFilterType _filterType = MapFilterType.all;
  int? _selectedChildId; // Para filtro de un solo niño
  int? _selectedGroupId; // Para filtro de grupo
  List<ChildGroupModel> _groups = [];
  bool _groupsLoaded = false;

  // WebSocket para actualizaciones en tiempo real
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription<LocationUpdate>? _locationSubscription;

  // Mapa mutable de ubicaciones en tiempo real (para actualizar sin rebuild completo)
  final Map<int, LatLng> _realtimePositions = {};
  final Map<int, int?> _realtimeBattery = {};
  final Map<int, DateTime> _realtimeLastSeen = {};

  @override
  void initState() {
    super.initState();

    // Suscribirse a actualizaciones de ubicación en tiempo real
    _locationSubscription = _webSocketService.locationUpdates.listen(
      _onRealtimeLocationUpdate,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllMarkers();
      _loadAllSafeZones();
      _loadGroups();

      // Suscribirse a todos los niños
      for (final child in widget.children) {
        _webSocketService.subscribeToChild(child.id);
      }
    });
  }

  /// Cantidad de zonas seguras visibles según el filtro actual (niño/grupo)
  int _visibleSafeZoneCount() {
    // Filtro por grupo: SOLO contar zonas del grupo
    if (_filterType == MapFilterType.group) {
      return _currentGroupZones().length;
    }

    // Filtro por niño individual o todos: contar zonas individuales
    final filteredChildIds = _filteredChildren.map((c) => c.id).toSet();
    return _allSafeZones
        .where(
          (zone) => zone.isActive && filteredChildIds.contains(zone.childId),
        )
        .length;
  }

  /// Maneja actualizaciones de ubicación en tiempo real via WebSocket
  void _onRealtimeLocationUpdate(LocationUpdate update) {
    // Verificar que el niño pertenece a la lista actual
    final childExists = widget.children.any((c) => c.id == update.childId);
    if (!childExists) return;

    debugPrint(
      '📍 AllChildrenMap REALTIME: child=${update.childId}, lat=${update.latitude}, lng=${update.longitude}',
    );

    // Actualizar posición en tiempo real (muy eficiente, sin rebuild de widgets pesados)
    if (mounted) {
      setState(() {
        _realtimePositions[update.childId] = LatLng(
          update.latitude,
          update.longitude,
        );
        _realtimeBattery[update.childId] = update.batteryLevel;
        _realtimeLastSeen[update.childId] = update.timestamp;
      });
    }
  }

  /// Obtiene la posición actual de un niño (prioriza tiempo real)
  LatLng? _getChildPosition(ChildModel child) {
    // Priorizar posición en tiempo real
    if (_realtimePositions.containsKey(child.id)) {
      return _realtimePositions[child.id];
    }

    // Fallback a posición del widget
    final lat = child.device?.lastLatitude;
    final lng = child.device?.lastLongitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    return null;
  }

  /// Obtiene la última actualización de un niño (prioriza tiempo real)
  DateTime? _getChildLastSeen(ChildModel child) {
    return _realtimeLastSeen[child.id] ?? child.device?.lastSeen;
  }

  @override
  void didUpdateWidget(covariant AllChildrenMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Verificar si las zonas seguras fueron invalidadas
    if (_loadedVersion != SafeZonesCacheManager.version) {
      debugPrint('🔄 Reloading safe zones due to cache invalidation');
      _loadAllSafeZones();
    }

    // Verificar si los grupos fueron invalidados (por cambios de membresías)
    if (_loadedGroupsVersion != GroupsCacheManager.version) {
      debugPrint('🔄 Reloading groups due to cache invalidation');
      // NO vaciar _groups inmediatamente para evitar mostrar "0 niños"
      // Solo marcar que necesita recarga
      _groupsLoaded = false;
      _loadGroups(force: true);
    }

    // Detectar si cambió la lista de niños (cantidad o IDs diferentes)
    final oldIds = oldWidget.children.map((c) => c.id).toSet();
    final newIds = widget.children.map((c) => c.id).toSet();
    final hasNewChildren = newIds.difference(oldIds).isNotEmpty;
    final hasRemovedChildren = oldIds.difference(newIds).isNotEmpty;

    if (hasNewChildren ||
        hasRemovedChildren ||
        oldWidget.children.length != widget.children.length) {
      // Recargar todo si hay cambios en la lista
      _loadAllMarkers();
      _loadAllSafeZones();

      // Forzar recarga de grupos para actualizar membresías y zonas tras cambios
      // NO vaciar _groups inmediatamente para evitar mostrar "0 niños" mientras carga
      _groupsLoaded = false;
      _loadGroups(force: true);

      // Si se eliminó un niño y teníamos ese niño seleccionado, resetear a "Todos"
      if (hasRemovedChildren && _filterType == MapFilterType.single) {
        final removedIds = oldIds.difference(newIds);
        if (removedIds.contains(_selectedChildId)) {
          setState(() {
            _filterType = MapFilterType.all;
            _selectedChildId = null;
          });
        }
      }

      // Ajustar el mapa para mostrar todos los marcadores después de cargar
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _fitAllMarkers();
      });
    }

    // Verificar si hay nuevas ubicaciones o estados para niños existentes
    for (final child in widget.children) {
      final oldChild = oldWidget.children.firstWhere(
        (c) => c.id == child.id,
        orElse: () => child,
      );

      final oldIsOnline = oldChild.device?.isOnline ?? false;
      final newIsOnline = child.device?.isOnline ?? false;

      if (oldIsOnline != newIsOnline) {
        // Recargar marcador si cambió estado
        _loadMarkerForChild(child);
      }
    }
  }

  /// Carga todos los marcadores personalizados
  Future<void> _loadAllMarkers() async {
    final primaryColor = Theme.of(context).colorScheme.primary;

    for (final child in widget.children) {
      if (!_hasCoordinates(child)) continue;

      final isOnline = child.device?.isOnline ?? false;

      final marker = await _markerCache.getChildMarker(
        name: child.fullName,
        color: primaryColor,
        isActive: isOnline,
        photoUrl: child.photoUrl,
      );

      if (mounted) {
        setState(() {
          _childMarkers[child.id] = marker;
        });
      }
    }
  }

  /// Carga marcador para un niño específico
  Future<void> _loadMarkerForChild(ChildModel child) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isOnline = child.device?.isOnline ?? false;

    final marker = await _markerCache.getChildMarker(
      name: child.fullName,
      color: primaryColor,
      isActive: isOnline,
      photoUrl: child.photoUrl,
    );

    if (mounted) {
      setState(() {
        _childMarkers[child.id] = marker;
      });
    }
  }

  /// Carga todas las zonas seguras de todos los niños
  Future<void> _loadAllSafeZones() async {
    // Solo recargar si la versión cambió o nunca se cargó
    if (_loadedVersion == SafeZonesCacheManager.version &&
        _loadedVersion != -1) {
      debugPrint('✓ SafeZones already loaded (v$_loadedVersion)');
      return;
    }

    try {
      final token = context.read<AuthBloc>().state.token;
      if (token == null) return;

      final allZones = <SafeZoneModel>[];

      for (final child in widget.children) {
        final zones = await sl<MonitoringRepository>().fetchSafeZones(
          token: token,
          childId: child.id,
        );
        allZones.addAll(zones);
      }

      if (mounted) {
        setState(() {
          _allSafeZones = allZones;
          _loadedVersion = SafeZonesCacheManager.version;
        });
      }
    } catch (e) {
      debugPrint('Error loading safe zones: $e');
    }
  }

  /// Carga los grupos disponibles con sus detalles (incluyendo membresías)
  Future<void> _loadGroups({bool force = false}) async {
    // Solo recargar si la versión cambió, se fuerza, o nunca se cargó
    if (_groupsLoaded &&
        !force &&
        _loadedGroupsVersion == GroupsCacheManager.version &&
        _loadedGroupsVersion != -1) {
      debugPrint('✓ Groups already loaded (v$_loadedGroupsVersion)');
      return;
    }

    try {
      final token = context.read<AuthBloc>().state.token;
      if (token == null) return;

      final repo = sl<GroupRepository>();

      // Primero obtener la lista de grupos
      final basicGroups = await repo.fetchGroups(token: token);

      // Luego cargar detalles de cada grupo para obtener membresías
      final detailedGroups = <ChildGroupModel>[];
      for (final group in basicGroups) {
        try {
          final detail = await repo.fetchGroupDetail(
            token: token,
            groupId: group.id,
          );
          detailedGroups.add(detail);
        } catch (e) {
          debugPrint('Error loading group ${group.id} details: $e');
          detailedGroups.add(group); // Usar el básico si falla
        }
      }

      if (mounted) {
        setState(() {
          _groups = detailedGroups;
          _groupsLoaded = true;
          _loadedGroupsVersion = GroupsCacheManager.version;
        });
        debugPrint(
          '✓ Groups loaded: ${detailedGroups.length} groups (v$_loadedGroupsVersion)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading groups: $e');
    }
  }

  /// Obtiene los niños según el filtro actual
  List<ChildModel> get _filteredChildren {
    switch (_filterType) {
      case MapFilterType.all:
        return widget.children;
      case MapFilterType.single:
        if (_selectedChildId == null) return widget.children;
        // Verificar que el niño seleccionado aún existe
        final childExists = widget.children.any((c) => c.id == _selectedChildId);
        if (!childExists) {
          // El niño fue eliminado, mostrar todos
          return widget.children;
        }
        return widget.children.where((c) => c.id == _selectedChildId).toList();
      case MapFilterType.group:
        if (_selectedGroupId == null) return widget.children;
        // Buscar el grupo seleccionado
        final groupIndex = _groups.indexWhere((g) => g.id == _selectedGroupId);
        if (groupIndex == -1) {
          // El grupo no está cargado aún o fue eliminado
          // Mostrar todos los niños mientras se carga
          return widget.children;
        }
        final group = _groups[groupIndex];
        // Obtener los IDs de niños de las membresías del grupo
        final childIds =
            group.memberships?.map((m) => m.childId).toSet() ?? <int>{};
        // Filtrar solo niños que existen en la lista actual
        final filteredChildren = widget.children.where((c) => childIds.contains(c.id)).toList();
        return filteredChildren;
    }
  }

  /// Obtiene el texto del filtro actual
  String get _filterLabel {
    switch (_filterType) {
      case MapFilterType.all:
        return 'Todos los niños';
      case MapFilterType.single:
        if (_selectedChildId == null) return 'Seleccionar niño';
        // Verificar que el niño aún existe
        final childIndex = widget.children.indexWhere((c) => c.id == _selectedChildId);
        if (childIndex == -1) {
          return 'Todos los niños'; // Niño eliminado
        }
        return widget.children[childIndex].fullName;
      case MapFilterType.group:
        if (_selectedGroupId == null) return 'Seleccionar grupo';
        // Verificar que el grupo está cargado
        final groupIndex = _groups.indexWhere((g) => g.id == _selectedGroupId);
        if (groupIndex == -1) {
          // Si no hay grupos cargados, mostrar "Cargando..."
          // Si hay grupos pero no encontramos el seleccionado, volver a "Todos"
          return _groups.isEmpty ? 'Cargando...' : 'Todos los niños';
        }
        return _groups[groupIndex].name;
    }
  }

  /// Obtiene el ícono del filtro actual
  IconData get _filterIcon {
    switch (_filterType) {
      case MapFilterType.all:
        return LucideIcons.users;
      case MapFilterType.single:
        return LucideIcons.user;
      case MapFilterType.group:
        return LucideIcons.usersRound;
    }
  }

  bool _hasCoordinates(ChildModel child) {
    // Verificar posición en tiempo real O posición del widget
    return _realtimePositions.containsKey(child.id) ||
        (child.device?.lastLatitude != null &&
            child.device?.lastLongitude != null);
  }

  /// Calcula el centro y bounds para mostrar todos los marcadores
  LatLngBounds? _calculateBounds() {
    final trackable = _filteredChildren.where(_hasCoordinates).toList();
    if (trackable.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final child in trackable) {
      final position = _getChildPosition(child);
      if (position == null) continue;

      minLat = math.min(minLat, position.latitude);
      maxLat = math.max(maxLat, position.latitude);
      minLng = math.min(minLng, position.longitude);
      maxLng = math.max(maxLng, position.longitude);
    }

    // Agregar padding
    const padding = 0.002;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  LatLng _calculateCenter() {
    final trackable = _filteredChildren.where(_hasCoordinates).toList();
    if (trackable.isEmpty) {
      // Santa Cruz de la Sierra por defecto
      return const LatLng(-17.7833, -63.1821);
    }

    double totalLat = 0;
    double totalLng = 0;

    for (final child in trackable) {
      final position = _getChildPosition(child);
      if (position == null) continue;

      totalLat += position.latitude;
      totalLng += position.longitude;
    }

    return LatLng(totalLat / trackable.length, totalLng / trackable.length);
  }

  void _fitAllMarkers() {
    final bounds = _calculateBounds();
    if (bounds != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    }
  }

  /// Muestra el selector de filtros
  void _showFilterSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filtrar en el mapa',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),

            // Opciones de filtro
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Opción: Todos
                    _FilterOptionTile(
                      icon: LucideIcons.users,
                      title: 'Todos los niños',
                      subtitle: '${widget.children.length} niños registrados',
                      isSelected: _filterType == MapFilterType.all,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _filterType = MapFilterType.all;
                          _selectedChildId = null;
                          _selectedGroupId = null;
                        });
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          _fitAllMarkers,
                        );
                      },
                    ),

                    const Divider(height: 1),

                    // Sección: Grupos
                    if (_groups.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Por grupo',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      ..._groups.map(
                        (group) => _FilterOptionTile(
                          icon: LucideIcons.usersRound,
                          title: group.name,
                          subtitle:
                              '${group.membersCount} niño${group.membersCount == 1 ? '' : 's'}',
                          isSelected:
                              _filterType == MapFilterType.group &&
                              _selectedGroupId == group.id,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _filterType = MapFilterType.group;
                              _selectedGroupId = group.id;
                              _selectedChildId = null;
                            });
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              _fitAllMarkers,
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                    ],

                    // Sección: Niños individuales
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Un solo niño',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...widget.children.map((child) {
                      final isOnline = child.device?.isOnline ?? false;
                      final hasLocation = _hasCoordinates(child);
                      return _FilterOptionTile(
                        icon: LucideIcons.user,
                        title: child.fullName,
                        subtitle: !hasLocation
                            ? 'Sin ubicación'
                            : isOnline
                            ? 'En línea'
                            : 'Sin conexión',
                        isSelected:
                            _filterType == MapFilterType.single &&
                            _selectedChildId == child.id,
                        isDisabled: !hasLocation,
                        statusColor: !hasLocation
                            ? Colors.grey
                            : (isOnline ? Colors.green : Colors.grey),
                        onTap: hasLocation
                            ? () {
                                Navigator.pop(context);
                                setState(() {
                                  _filterType = MapFilterType.single;
                                  _selectedChildId = child.id;
                                  _selectedGroupId = null;
                                });
                                // Centrar en el niño seleccionado
                                if (child.device?.lastLatitude != null &&
                                    child.device?.lastLongitude != null) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(
                                        child.device!.lastLatitude!,
                                        child.device!.lastLongitude!,
                                      ),
                                      16,
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    }),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Tipo de mapa',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMapTypeOption(MapType.normal, 'Estándar'),
                  _buildMapTypeOption(MapType.hybrid, 'Satélite'),
                  _buildMapTypeOption(MapType.terrain, 'Relieve'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(MapType type, String label) {
    final isSelected = _mapType == type;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() => _mapType = type);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              type == MapType.normal
                  ? LucideIcons.map
                  : type == MapType.hybrid
                  ? LucideIcons.globe
                  : LucideIcons.mountain,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseZoneColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  List<GroupSafeZoneModel> _currentGroupZones() {
    if (_filterType != MapFilterType.group || _selectedGroupId == null) {
      return [];
    }
    final group = _groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => const ChildGroupModel(
        id: 0,
        name: '',
        ownerId: 0,
        color: '#000000',
        icon: 'users',
        isActive: false,
        membersCount: 0,
        tutorsCount: 0,
      ),
    );
    return (group.safeZones ?? []).where((z) => z.isActive).toList();
  }

  Set<Polygon> _buildSafeZonePolygons() {
    if (!_showSafeZones) return {};
    final polygons = <Polygon>{};

    // Zonas individuales: SOLO mostrar cuando NO estamos filtrando por grupo
    // - Filtro "Todos": mostrar zonas de todos los niños
    // - Filtro "Niño individual": mostrar zonas de ese niño
    // - Filtro "Grupo": NO mostrar zonas individuales (solo las del grupo)
    if (_filterType != MapFilterType.group && _allSafeZones.isNotEmpty) {
      final filteredChildIds = _filteredChildren.map((c) => c.id).toSet();
      final zonesToShow = _allSafeZones.where(
        (zone) =>
            zone.isActive &&
            zone.polygonPoints.length >= 3 &&
            filteredChildIds.contains(zone.childId),
      );

      for (final zone in zonesToShow) {
        final color = _parseZoneColor(zone.color);
        polygons.add(
          Polygon(
            polygonId: PolygonId('safe_zone_${zone.id}'),
            points: zone.polygonPoints
                .map((p) => LatLng(p.lat, p.lng))
                .toList(),
            fillColor: color.withValues(alpha: 0.2),
            strokeColor: color,
            strokeWidth: 2,
          ),
        );
      }
    }

    // Zonas seguras de grupo: SOLO cuando se filtra por grupo
    final groupZones = _currentGroupZones();
    for (final zone in groupZones) {
      if (zone.zoneType != 'polygon' || zone.polygonPoints.length < 3) continue;
      final color = _parseZoneColor(zone.color);
      polygons.add(
        Polygon(
          polygonId: PolygonId('group_zone_${zone.id}'),
          points: zone.polygonPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
          fillColor: color.withValues(alpha: 0.18),
          strokeColor: color,
          strokeWidth: 2,
        ),
      );
    }

    return polygons;
  }

  Set<Circle> _buildGroupZoneCircles() {
    if (!_showSafeZones) return {};
    final circles = <Circle>{};
    final groupZones = _currentGroupZones();

    for (final zone in groupZones) {
      if (zone.zoneType == 'circle' &&
          zone.centerLatitude != null &&
          zone.centerLongitude != null) {
        final color = _parseZoneColor(zone.color);
        circles.add(
          Circle(
            circleId: CircleId('group_zone_${zone.id}'),
            center: LatLng(zone.centerLatitude!, zone.centerLongitude!),
            radius: (zone.radiusMeters ?? 100).toDouble(),
            fillColor: color.withValues(alpha: 0.18),
            strokeColor: color,
            strokeWidth: 2,
          ),
        );
      }
    }

    return circles;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final child in _filteredChildren) {
      // Usar posición en tiempo real si está disponible
      final position = _getChildPosition(child);
      if (position == null) continue;

      final lastSeen = _getChildLastSeen(child);
      final marker = _childMarkers[child.id] ?? _markerCache.childMarker;

      markers.add(
        Marker(
          markerId: MarkerId('child_${child.id}'),
          position: position, // Usa posición en tiempo real
          anchor: const Offset(0.5, 1.0), // Anclar desde la punta del puntero
          icon: marker,
          infoWindow: InfoWindow(
            title: child.fullName,
            snippet: lastSeen != null
                ? 'Última vez: ${date_utils.relativeTime(lastSeen)}'
                : 'Sin datos recientes',
          ),
          onTap: () {
            setState(() => _selectedChild = child);
          },
        ),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    // Cancelar suscripción WebSocket
    _locationSubscription?.cancel();

    // Desuscribirse de todos los niños
    for (final child in widget.children) {
      _webSocketService.unsubscribeFromChild(child.id);
    }

    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si las zonas seguras fueron invalidadas y recargar
    if (_loadedVersion != SafeZonesCacheManager.version) {
      // Programar recarga para después del frame actual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAllSafeZones();
      });
    }

    // Verificar si los grupos fueron invalidados y recargar
    if (_loadedGroupsVersion != GroupsCacheManager.version) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // NO vaciar _groups para evitar mostrar "0 niños"
          // Solo marcar como no cargados y recargar
          _groupsLoaded = false;
          _loadGroups(force: true);
        }
      });
    }

    final trackable = _filteredChildren.where(_hasCoordinates).toList();

    if (widget.children.where(_hasCoordinates).isEmpty) {
      return _buildEmptyState();
    }

    final center = _calculateCenter();
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Mapa
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 14),
          mapType: _mapType,
          onMapCreated: (controller) {
            _mapController = controller;
            // Ajustar para mostrar todos los marcadores
            Future.delayed(const Duration(milliseconds: 500), _fitAllMarkers);
          },
          markers: _buildMarkers(),
          polygons: _buildSafeZonePolygons(),
          circles: _buildGroupZoneCircles(),
          myLocationEnabled: true, // Mostrar ubicación del tutor
          myLocationButtonEnabled: false, // Botón custom mejor
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false, // No necesario para monitoreo
          buildingsEnabled: false, // Mejor rendimiento
          tiltGesturesEnabled: false, // Vista 2D más clara para ver niños
          rotateGesturesEnabled: false, // Norte siempre arriba, menos confusión
          minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
        ),

        // Selector de filtro (arriba izquierda)
        Positioned(
          top: 60,
          left: 16,
          child: GestureDetector(
            onTap: _showFilterSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_filterIcon, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      _filterLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Contador de niños visibles (debajo del filtro)
        Positioned(
          top: 108,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${trackable.length} en el mapa',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),

        // Controles (derecha)
        Positioned(
          top: 60,
          right: 16,
          child: Column(
            children: [
              // Botón para mostrar todos
              _MapControlButton(
                icon: LucideIcons.maximize2,
                onTap: _fitAllMarkers,
                tooltip: 'Ver todos',
              ),
              const SizedBox(height: 8),
              // Tipo de mapa
              _MapControlButton(
                icon: LucideIcons.layers,
                onTap: _showMapTypeSelector,
                tooltip: 'Tipo de mapa',
              ),
              const SizedBox(height: 8),
              // Zonas seguras
              _MapControlButton(
                icon: _showSafeZones
                    ? LucideIcons.shield
                    : LucideIcons.shieldOff,
                onTap: () => setState(() => _showSafeZones = !_showSafeZones),
                tooltip: _showSafeZones ? 'Ocultar zonas' : 'Mostrar zonas',
                isActive: _showSafeZones,
                badge: () {
                  final count = _visibleSafeZoneCount();
                  return count > 0 ? count.toString() : null;
                }(),
              ),
            ],
          ),
        ),

        // Panel de niño seleccionado
        if (_selectedChild != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedChildPanel(
              child: _selectedChild!,
              realtimeBattery: _realtimeBattery[_selectedChild!.id],
              realtimeLastSeen: _realtimeLastSeen[_selectedChild!.id],
              realtimePosition: _realtimePositions[_selectedChild!.id],
              onClose: () => setState(() => _selectedChild = null),
              onNavigate: () {
                widget.onChildTapped?.call(_selectedChild!);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.mapPinOff,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ubicaciones disponibles',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los niños aparecerán aquí cuando sus dispositivos envíen ubicación',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isActive;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isActive ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface,
                ),
                if (badge != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedChildPanel extends StatelessWidget {
  const _SelectedChildPanel({
    required this.child,
    required this.onClose,
    required this.onNavigate,
    this.realtimeBattery,
    this.realtimeLastSeen,
    this.realtimePosition,
  });

  final ChildModel child;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final int? realtimeBattery;
  final DateTime? realtimeLastSeen;
  final LatLng? realtimePosition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final device = child.device;
    // Usar datos en tiempo real si están disponibles, sino los del modelo
    final lastSeen = realtimeLastSeen ?? device?.lastSeen;
    final batteryLevel = realtimeBattery ?? device?.batteryLevel;
    final lat = realtimePosition?.latitude ?? device?.lastLatitude;
    final lng = realtimePosition?.longitude ?? device?.lastLongitude;
    // isOnline se determina por si hay datos recientes (menos de 5 minutos)
    final isOnline =
        lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con avatar, nombre y botón cerrar
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: child.photoUrl != null
                    ? NetworkImage(child.photoUrl!)
                    : null,
                child: child.photoUrl == null
                    ? Text(
                        child.fullName.isNotEmpty
                            ? child.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Nombre y estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      child.fullName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'En línea' : 'Sin conexión',
                          style: textTheme.bodySmall?.copyWith(
                            color: isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Cerrar
              IconButton(
                onPressed: onClose,
                icon: Icon(LucideIcons.x, color: colorScheme.outline, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Fila de detalles del dispositivo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Batería
                Expanded(
                  child: _DetailItem(
                    icon: _getBatteryIcon(batteryLevel),
                    iconColor: _getBatteryColor(batteryLevel),
                    label: 'Batería',
                    value: batteryLevel != null ? '$batteryLevel%' : '--',
                  ),
                ),

                Container(
                  width: 1,
                  height: 36,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),

                // Última actualización
                Expanded(
                  child: _DetailItem(
                    icon: LucideIcons.clock,
                    iconColor: colorScheme.primary,
                    label: 'Actualizado',
                    value: lastSeen != null
                        ? date_utils.relativeTime(lastSeen)
                        : '--',
                  ),
                ),

                Container(
                  width: 1,
                  height: 36,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),

                // Coordenadas
                Expanded(
                  child: _DetailItem(
                    icon: LucideIcons.mapPin,
                    iconColor: colorScheme.tertiary,
                    label: 'Ubicación',
                    value: lat != null && lng != null
                        ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
                        : '--',
                    isSmallText: true,
                  ),
                ),
              ],
            ),
          ),

          // Botón de ver perfil (opcional)
          if (!child.isOwnChild && child.tutorName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.users, size: 14, color: colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Compartido por ${child.tutorName}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getBatteryIcon(int? level) {
    if (level == null) return LucideIcons.batteryWarning;
    if (level <= 10) return LucideIcons.batteryWarning;
    if (level <= 25) return LucideIcons.batteryLow;
    if (level <= 50) return LucideIcons.batteryMedium;
    return LucideIcons.batteryFull;
  }

  Color _getBatteryColor(int? level) {
    if (level == null) return Colors.grey;
    if (level <= 15) return Colors.red;
    if (level <= 30) return Colors.orange;
    return Colors.green;
  }
}

/// Widget reutilizable para mostrar un detalle con ícono
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isSmallText = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isSmallText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isSmallText ? 10 : null,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.isDisabled = false,
    this.statusColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDisabled;
  final Color? statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      enabled: !isDisabled,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDisabled
              ? colorScheme.outline
              : (isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isDisabled ? colorScheme.outline : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (statusColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            subtitle,
            style: TextStyle(
              color: isDisabled
                  ? colorScheme.outline
                  : statusColor ?? colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: isSelected
          ? Icon(LucideIcons.check, color: colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
