import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection_container.dart' as di;
import 'bloc/group_detail_bloc.dart';
import 'bloc/groups_bloc.dart';
import '../domain/group_models.dart';
import '../../monitoring/domain/monitoring_models.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';

class GroupMapScreen extends StatelessWidget {
  const GroupMapScreen({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<GroupDetailBloc>()..add(GroupDetailLoadLocations(groupId)),
      child: _GroupMapView(groupId: groupId),
    );
  }
}

class _GroupMapView extends StatefulWidget {
  const _GroupMapView({required this.groupId});

  final int groupId;

  @override
  State<_GroupMapView> createState() => _GroupMapViewState();
}

class _GroupMapViewState extends State<_GroupMapView> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Timer? _refreshTimer;
  int? _selectedChildId;
  MapType _mapType = MapType.normal;
  bool _showSafeZones = true;

  // Santa Cruz, Bolivia por defecto
  static const _defaultPosition = LatLng(-17.7833, -63.1821);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cargar ubicaciones al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId));
    });
    // Auto-refresh cada 30 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refrescar cuando la app vuelve al primer plano
    if (state == AppLifecycleState.resumed) {
      context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId));
    }
  }

  // NUEVO: Detectar cuando volvemos a esta pantalla desde otra
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refrescar cada vez que la pantalla se vuelve visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupDetailBloc, GroupDetailState>(
      listener: (context, state) {
        if (state is GroupDetailLoaded && state.locations != null) {
          if (_selectedChildId != null &&
              state.locations!.children.every((c) => c.childId != _selectedChildId)) {
            setState(() => _selectedChildId = null);
          }
          _fitMapToChildren(state.locations!.children);
        }
      },
      builder: (context, state) {
        String title = 'Mapa del grupo';
        GroupLocationsResponse? locations;

        if (state is GroupDetailLoaded) {
          title = state.group.name;
          locations = state.locations;
        }

        final groupZones = _visibleGroupZones(locations);
        final childZones = _visibleChildZones(locations);

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                tooltip: 'Actualizar ubicaciones',
                onPressed: () {
                  context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId));
                },
              ),
              IconButton(
                icon: const Icon(LucideIcons.settings),
                tooltip: 'Gestionar grupo',
                onPressed: () async {
                  // Navegar a la pantalla de gestión y refrescar al volver
                  await context.pushNamed(
                    'group-detail',
                    pathParameters: {'id': widget.groupId.toString()},
                  );
                  // Refrescar datos cuando regresamos
                  if (context.mounted) {
                    context.read<GroupDetailBloc>().add(GroupDetailLoadLocations(widget.groupId));
                    // También refrescar los blocs globales - forceRefresh para omitir caché
                    di.sl<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
                    di.sl<GroupsBloc>().add(const GroupsFetchRequested(forceRefresh: true));
                  }
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultPosition,
                  zoom: 14,
                ),
                mapType: _mapType,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (locations != null) {
                    _fitMapToChildren(locations.children);
                  }
                },
                markers: _buildMarkers(locations?.children ?? []),
                polygons: {
                  ..._buildPolygons(groupZones),
                  ..._buildChildSafeZonePolygons(childZones),
                },
                circles: {
                  ..._buildCircles(groupZones),
                  ..._buildChildSafeZoneCircles(childZones),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                buildingsEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
              ),

              // Map type button
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: _showSafeZones ? LucideIcons.shield : LucideIcons.shieldOff,
                      onPressed: () {
                        setState(() => _showSafeZones = !_showSafeZones);
                      },
                      tooltip: _showSafeZones ? 'Ocultar zonas seguras' : 'Mostrar zonas seguras',
                    ),
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: LucideIcons.layers,
                      onPressed: _showMapTypeSelector,
                      tooltip: 'Tipo de mapa',
                    ),
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: LucideIcons.locateFixed,
                      onPressed: () {
                        if (locations != null) {
                          _fitMapToChildren(locations.children);
                        }
                      },
                      tooltip: 'Centrar',
                    ),
                  ],
                ),
              ),

              // Loading overlay
              if (state is GroupDetailLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // Children list overlay
              if (locations != null && locations.children.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ChildrenCarousel(
                    children: locations.children,
                    selectedChildId: _selectedChildId,
                    onChildSelected: (child) {
                      setState(() => _selectedChildId = child.childId);
                      if (child.hasLocation) {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(child.latitude!, child.longitude!),
                            17,
                          ),
                        );
                      }
                    },
                  ),
                ),

              // Empty state
              if (locations != null && locations.children.isEmpty)
                Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.mapPinOff,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin niños en el grupo',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega niños al grupo para ver sus ubicaciones',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => context.pushNamed(
                              'group-detail',
                              pathParameters: {'id': widget.groupId.toString()},
                            ),
                            icon: const Icon(LucideIcons.userPlus),
                            label: const Text('Agregar niños'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<GroupSafeZoneModel> _visibleGroupZones(GroupLocationsResponse? locations) {
    if (!_showSafeZones || locations == null) return [];
    return locations.safeZones.where((z) => z.isActive).toList();
  }

  List<SafeZoneModel> _visibleChildZones(GroupLocationsResponse? locations) {
    if (!_showSafeZones || locations == null) return [];
    final childId = _selectedChildId;
    final zones = locations.childSafeZones.where((z) => z.isActive);
    if (childId == null) return zones.toList();
    return zones.where((z) => z.childId == childId).toList();
  }

  Set<Marker> _buildMarkers(List<GroupChildLocation> children) {
    final markers = <Marker>{};

    for (final child in children) {
      if (child.hasLocation) {
        markers.add(Marker(
          markerId: MarkerId('child_${child.childId}'),
          position: LatLng(child.latitude!, child.longitude!),
          infoWindow: InfoWindow(
            title: child.childName,
            snippet: child.device?.lastSeen != null
                ? 'Hace ${_timeAgo(child.device!.lastSeen!)}'
                : 'Sin hora',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedChildId == child.childId
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueRed,
          ),
          onTap: () {
            setState(() => _selectedChildId = child.childId);
          },
        ));
      }
    }

    return markers;
  }

  Set<Polygon> _buildPolygons(List<GroupSafeZoneModel> zones) {
    final polygons = <Polygon>{};

    for (final zone in zones) {
      if (zone.zoneType == 'polygon' && zone.polygonPoints.length >= 3 && zone.isActive) {
        final color = _parseColor(zone.color);
        polygons.add(Polygon(
          polygonId: PolygonId('zone_${zone.id}'),
          points: zone.polygonPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
          fillColor: color.withValues(alpha: 0.2),
          strokeColor: color,
          strokeWidth: 2,
        ));
      }
    }

    return polygons;
  }

  Set<Polygon> _buildChildSafeZonePolygons(List<SafeZoneModel> zones) {
    final polygons = <Polygon>{};

    for (final zone in zones) {
      if (zone.zoneType == 'polygon' && zone.polygonPoints.length >= 3) {
        final color = _parseColor(zone.color);
        polygons.add(Polygon(
          polygonId: PolygonId('child_zone_${zone.id}'),
          points: zone.polygonPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
          fillColor: color.withValues(alpha: 0.18),
          strokeColor: color,
          strokeWidth: 2,
        ));
      }
    }

    return polygons;
  }

  Set<Circle> _buildCircles(List<GroupSafeZoneModel> zones) {
    final circles = <Circle>{};

    for (final zone in zones) {
      if (zone.zoneType == 'circle' &&
          zone.centerLatitude != null &&
          zone.centerLongitude != null &&
          zone.isActive) {
        final color = _parseColor(zone.color);
        circles.add(Circle(
          circleId: CircleId('zone_${zone.id}'),
          center: LatLng(zone.centerLatitude!, zone.centerLongitude!),
          radius: (zone.radiusMeters ?? 100).toDouble(),
          fillColor: color.withValues(alpha: 0.2),
          strokeColor: color,
          strokeWidth: 2,
        ));
      }
    }

    return circles;
  }

  Set<Circle> _buildChildSafeZoneCircles(List<SafeZoneModel> zones) {
    final circles = <Circle>{};

    for (final zone in zones) {
      if (zone.zoneType == 'circle' &&
          zone.centerLatitude != null &&
          zone.centerLongitude != null) {
        final color = _parseColor(zone.color);
        circles.add(Circle(
          circleId: CircleId('child_zone_${zone.id}'),
          center: LatLng(zone.centerLatitude!, zone.centerLongitude!),
          radius: (zone.radiusMeters ?? 100).toDouble(),
          fillColor: color.withValues(alpha: 0.18),
          strokeColor: color,
          strokeWidth: 2,
        ));
      }
    }

    return circles;
  }

  void _fitMapToChildren(List<GroupChildLocation> children) {
    final locatedChildren = children.where((c) => c.hasLocation).toList();
    
    if (locatedChildren.isEmpty) return;
    
    if (locatedChildren.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(locatedChildren.first.latitude!, locatedChildren.first.longitude!),
          16,
        ),
      );
      return;
    }

    // Calculate bounds for multiple children
    double minLat = locatedChildren.first.latitude!;
    double maxLat = locatedChildren.first.latitude!;
    double minLng = locatedChildren.first.longitude!;
    double maxLng = locatedChildren.first.longitude!;

    for (final child in locatedChildren) {
      if (child.latitude! < minLat) minLat = child.latitude!;
      if (child.latitude! > maxLat) maxLat = child.latitude!;
      if (child.longitude! < minLng) minLng = child.longitude!;
      if (child.longitude! > maxLng) maxLng = child.longitude!;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
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
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildrenCarousel extends StatelessWidget {
  const _ChildrenCarousel({
    required this.children,
    required this.selectedChildId,
    required this.onChildSelected,
  });

  final List<GroupChildLocation> children;
  final int? selectedChildId;
  final void Function(GroupChildLocation) onChildSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(LucideIcons.users, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${children.length} niño${children.length == 1 ? '' : 's'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${children.where((c) => c.hasLocation).length} con ubicación',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Children list
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final isSelected = selectedChildId == child.childId;
                
                return _ChildChip(
                  child: child,
                  isSelected: isSelected,
                  onTap: () => onChildSelected(child),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  final GroupChildLocation child;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                      ? NetworkImage(child.photoUrl!)
                      : null,
                  child: child.photoUrl == null || child.photoUrl!.isEmpty
                      ? Text(
                          child.childName.substring(0, 1).toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: child.hasLocation ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      child.hasLocation ? LucideIcons.mapPin : LucideIcons.mapPinOff,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              child.childName.split(' ').first,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String hexColor) {
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.green;
  }
}
