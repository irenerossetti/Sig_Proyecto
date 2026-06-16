import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/image_cache_service.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/monitoring_repository.dart';
import '../domain/monitoring_models.dart';

/// Widget reutilizable para mostrar el mapa de un niño
/// Optimizado para rendimiento con lazy loading de zonas seguras
class ChildMapView extends StatefulWidget {
  const ChildMapView({
    super.key,
    required this.child,
    this.locationHistory = const [],
  });

  final ChildModel child;
  final List<LatLng> locationHistory;

  @override
  State<ChildMapView> createState() => _ChildMapViewState();
}

class _ChildMapViewState extends State<ChildMapView> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _showRoute = true;
  bool _isFollowingChild = true;
  LatLng? _lastAnimatedPosition;
  
  // Caché de marcadores para evitar recreación
  final MapImageCacheService _markerCache = MapImageCacheService();
  BitmapDescriptor? _childCustomMarker; // Marcador personalizado con nombre
  
  // Modo navegación
  bool _isNavigationMode = false;
  LatLng? _tutorLocation;
  StreamSubscription<Position>? _positionStream;
  double? _distanceToChild;
  List<LatLng> _routePoints = [];
  String? _estimatedTime;
  bool _isLoadingRoute = false;
  String _travelMode = 'driving'; // driving, walking, motorcycling
  
  // Navegación activa (turn-by-turn)
  bool _isActiveNavigation = false;
  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  String? _totalDistance;
  
  // Zonas seguras - carga lazy
  List<SafeZoneModel> _safeZones = [];
  bool _showSafeZones = true;
  bool _safeZonesLoaded = false;
  
  // API Key de Google (la misma del AndroidManifest)
  static const String _googleApiKey = 'AIzaSyCxaZHuPIOCf04eE9GsNyYE3H1E6vsDePI';

  @override
  bool get wantKeepAlive => true; // Mantener estado al cambiar tabs

  @override
  void initState() {
    super.initState();
    // Cargar zonas seguras y marcador personalizado de forma lazy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSafeZones();
      _loadCustomMarker();
    });
  }

  /// Cargar marcador personalizado con el nombre del niño
  Future<void> _loadCustomMarker() async {
    final isOnline = widget.child.device?.isOnline ?? false;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final marker = await _markerCache.getChildMarker(
      name: widget.child.fullName,
      color: primaryColor,
      isActive: isOnline,
      photoUrl: widget.child.photoUrl,
    );
    
    if (mounted) {
      setState(() => _childCustomMarker = marker);
    }
  }

  Future<void> _loadSafeZones() async {
    if (_safeZonesLoaded) return; // Evitar cargas duplicadas
    
    try {
      final token = context.read<AuthBloc>().state.token;
      if (token == null) {
        debugPrint('SafeZones: No token available');
        return;
      }
      
      debugPrint('SafeZones: Loading zones for child ${widget.child.id}');
      
      final zones = await sl<MonitoringRepository>().fetchSafeZones(
        token: token,
        childId: widget.child.id,
      );
      
      debugPrint('SafeZones: Loaded ${zones.length} zones');
      
      if (mounted) {
        setState(() {
          _safeZones = zones;
          _safeZonesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading safe zones: $e');
    }
  }

  Color _parseZoneColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
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
                  _MapTypeOption(
                    mapType: MapType.normal,
                    label: 'Estándar',
                    isSelected: _mapType == MapType.normal,
                    onTap: () => _selectMapType(MapType.normal),
                  ),
                  _MapTypeOption(
                    mapType: MapType.hybrid,
                    label: 'Satélite',
                    isSelected: _mapType == MapType.hybrid,
                    onTap: () => _selectMapType(MapType.hybrid),
                  ),
                  _MapTypeOption(
                    mapType: MapType.terrain,
                    label: 'Relieve',
                    isSelected: _mapType == MapType.terrain,
                    onTap: () => _selectMapType(MapType.terrain),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _selectMapType(MapType type) {
    Navigator.pop(context);
    setState(() => _mapType = type);
  }

  @override
  void didUpdateWidget(covariant ChildMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newLat = widget.child.device?.lastLatitude;
    final newLng = widget.child.device?.lastLongitude;
    
    if (newLat == null || newLng == null) return;
    
    final newLocation = LatLng(newLat, newLng);
    
    // Si cambió el niño seleccionado, centrar en su ubicación y recargar zonas/marcador
    if (oldWidget.child.id != widget.child.id) {
      _lastAnimatedPosition = newLocation;
      _isFollowingChild = true;
      _safeZonesLoaded = false; // Forzar recarga de zonas
      _childCustomMarker = null; // Forzar recarga del marcador
      _animateCameraToLocation(newLocation, zoom: 17);
      _loadSafeZones(); // Recargar zonas del nuevo niño
      _loadCustomMarker(); // Recargar marcador del nuevo niño
      return;
    }
    
    // Si cambió el estado activo del niño o la foto, actualizar marcador
    final oldIsOnline = oldWidget.child.device?.isOnline ?? false;
    final newIsOnline = widget.child.device?.isOnline ?? false;
    final oldPhotoUrl = oldWidget.child.photoUrl;
    final newPhotoUrl = widget.child.photoUrl;
    if (oldIsOnline != newIsOnline || oldPhotoUrl != newPhotoUrl) {
      _childCustomMarker = null; // Forzar recarga del marcador con nueva foto
      _loadCustomMarker();
    }
    
    // Animar cámara cuando la ubicación del niño cambia (si está siguiendo)
    if (_isFollowingChild && _lastAnimatedPosition != newLocation) {
      _lastAnimatedPosition = newLocation;
      _animateCameraToLocation(newLocation);
    }
  }

  void _animateCameraToLocation(LatLng location, {double? zoom}) {
    _mapController?.animateCamera(
      zoom != null
          ? CameraUpdate.newLatLngZoom(location, zoom)
          : CameraUpdate.newLatLng(location),
    );
  }

  void _centerOnChild() {
    final lat = widget.child.device?.lastLatitude;
    final lng = widget.child.device?.lastLongitude;
    if (lat != null && lng != null) {
      setState(() => _isFollowingChild = true);
      _animateCameraToLocation(LatLng(lat, lng), zoom: 17);
    }
  }

  void _toggleRoute() {
    setState(() => _showRoute = !_showRoute);
  }

  Future<void> _toggleNavigationMode() async {
    if (_isNavigationMode) {
      // Desactivar modo navegación
      _positionStream?.cancel();
      setState(() {
        _isNavigationMode = false;
        _tutorLocation = null;
        _distanceToChild = null;
        _routePoints = [];
        _estimatedTime = null;
        _isLoadingRoute = false;
      });
    } else {
      // Activar modo navegación
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return;
      
      setState(() => _isNavigationMode = true);
      
      // Obtener ubicación inicial
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _updateTutorLocation(position);
        
        // Escuchar actualizaciones de ubicación
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Actualizar cada 5 metros
          ),
        ).listen(_updateTutorLocation);
        
        // Ajustar cámara para mostrar ambos marcadores
        _fitBothMarkers();
      } catch (e) {
        setState(() => _isNavigationMode = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al obtener ubicación: $e')),
          );
        }
      }
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor activa el GPS')),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
        }
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente. Habilítalo en configuración.'),
          ),
        );
      }
      return false;
    }
    
    return true;
  }

  void _updateTutorLocation(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);
    final childLat = widget.child.device?.lastLatitude;
    final childLng = widget.child.device?.lastLongitude;
    
    double? distance;
    if (childLat != null && childLng != null) {
      distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        childLat,
        childLng,
      );
    }
    
    final oldLocation = _tutorLocation;
    final isFirstLocation = oldLocation == null;
    
    setState(() {
      _tutorLocation = newLocation;
      _distanceToChild = distance;
    });
    
    // Obtener ruta si es la primera vez o la ubicación cambió significativamente
    if (childLat != null && childLng != null) {
      if (isFirstLocation || 
          Geolocator.distanceBetween(
            oldLocation.latitude, oldLocation.longitude,
            newLocation.latitude, newLocation.longitude,
          ) > 20) {
        await _fetchRoute(newLocation, LatLng(childLat, childLng));
      }
    }
    
    // Actualizar paso actual si está en navegación activa
    if (_isActiveNavigation) {
      _updateCurrentStep();
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng destination) async {
    if (_isLoadingRoute) return;
    
    setState(() => _isLoadingRoute = true);
    
    try {
      // Para la API: moto usa 'driving' ya que no hay modo moto en Google
      final apiMode = _travelMode == 'motorcycling' ? 'driving' : _travelMode;
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$apiMode'
        '&language=es'
        '&key=$_googleApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          final leg = route['legs'][0];
          final duration = leg['duration']['text'];
          final distance = leg['distance']['text'];
          
          // Extraer pasos de navegación
          final steps = leg['steps'] as List;
          final navSteps = steps.map<NavigationStep>((step) {
            return NavigationStep(
              instruction: _stripHtmlTags(step['html_instructions'] ?? ''),
              distance: step['distance']['text'] ?? '',
              duration: step['duration']['text'] ?? '',
              maneuver: step['maneuver'] ?? '',
              startLocation: LatLng(
                step['start_location']['lat'],
                step['start_location']['lng'],
              ),
              endLocation: LatLng(
                step['end_location']['lat'],
                step['end_location']['lng'],
              ),
            );
          }).toList();
          
          // Decodificar la polyline
          final points = _decodePolyline(overviewPolyline);
          
          setState(() {
            _routePoints = points;
            _estimatedTime = duration;
            _totalDistance = distance;
            _navigationSteps = navSteps;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  /// Decodifica una polyline codificada de Google Maps
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }

  /// Elimina etiquetas HTML de las instrucciones
  String _stripHtmlTags(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  void _fitBothMarkers() {
    final childLat = widget.child.device?.lastLatitude;
    final childLng = widget.child.device?.lastLongitude;
    
    if (_tutorLocation != null && childLat != null && childLng != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_tutorLocation!.latitude, childLat),
          math.min(_tutorLocation!.longitude, childLng),
        ),
        northeast: LatLng(
          math.max(_tutorLocation!.latitude, childLat),
          math.max(_tutorLocation!.longitude, childLng),
        ),
      );
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  void _changeTravelMode(String mode) {
    setState(() {
      _travelMode = mode;
      _routePoints = [];
      _estimatedTime = null;
    });
    
    // Recalcular ruta con el nuevo modo
    if (_tutorLocation != null) {
      final childLat = widget.child.device?.lastLatitude;
      final childLng = widget.child.device?.lastLongitude;
      if (childLat != null && childLng != null) {
        _fetchRoute(_tutorLocation!, LatLng(childLat, childLng));
      }
    }
  }

  void _startActiveNavigation() {
    if (_navigationSteps.isEmpty) return;
    
    setState(() {
      _isActiveNavigation = true;
      _currentStepIndex = 0;
      _isFollowingChild = false;
    });
    
    // Centrar en la ubicación del tutor con zoom alto
    if (_tutorLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _tutorLocation!,
            zoom: 18,
          ),
        ),
      );
    }
  }

  void _stopActiveNavigation() {
    setState(() {
      _isActiveNavigation = false;
      _currentStepIndex = 0;
    });
    
    // Volver a vista normal
    _fitBothMarkers();
  }

  void _updateCurrentStep() {
    if (!_isActiveNavigation || _tutorLocation == null || _navigationSteps.isEmpty) return;
    
    // Encontrar el paso más cercano
    double minDistance = double.infinity;
    int closestStep = _currentStepIndex;
    
    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      final step = _navigationSteps[i];
      final distance = Geolocator.distanceBetween(
        _tutorLocation!.latitude,
        _tutorLocation!.longitude,
        step.startLocation.latitude,
        step.startLocation.longitude,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        closestStep = i;
      }
      
      // Si estamos cerca del punto final del paso actual, avanzar
      final endDistance = Geolocator.distanceBetween(
        _tutorLocation!.latitude,
        _tutorLocation!.longitude,
        step.endLocation.latitude,
        step.endLocation.longitude,
      );
      
      if (endDistance < 30 && i == _currentStepIndex && i < _navigationSteps.length - 1) {
        closestStep = i + 1;
        break;
      }
    }
    
    if (closestStep != _currentStepIndex) {
      setState(() => _currentStepIndex = closestStep);
    }
    
    // Actualizar la cámara para seguir al usuario
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _tutorLocation!,
          zoom: 18,
        ),
      ),
    );
  }

  /// Construye los polígonos de las zonas seguras
  Set<Polygon> _buildSafeZonePolygons() {
    if (!_showSafeZones || _safeZones.isEmpty) return {};
    
    return _safeZones.where((zone) => zone.isActive && zone.polygonPoints.length >= 3).map((zone) {
      final color = _parseZoneColor(zone.color);
      final points = zone.polygonPoints.map((p) => LatLng(p.lat, p.lng)).toList();
      
      return Polygon(
        polygonId: PolygonId('safe_zone_${zone.id}'),
        points: points,
        fillColor: color.withValues(alpha: 0.2),
        strokeColor: color,
        strokeWidth: 3,
        consumeTapEvents: true,
        onTap: () => _showZoneInfo(zone),
      );
    }).toSet();
  }

  /// Muestra información de la zona segura
  void _showZoneInfo(SafeZoneModel zone) {
    final color = _parseZoneColor(zone.color);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(LucideIcons.shield, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Zona segura · ${zone.polygonPoints.length} puntos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: zone.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    zone.isActive ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: zone.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Verificar si el niño está dentro de la zona
            _buildChildInZoneStatus(zone),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildChildInZoneStatus(SafeZoneModel zone) {
    final lat = widget.child.device?.lastLatitude;
    final lng = widget.child.device?.lastLongitude;
    
    if (lat == null || lng == null) {
      return const SizedBox.shrink();
    }
    
    // Verificar si está dentro usando ray casting
    final isInside = _isPointInPolygon(lat, lng, zone.polygonPoints);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInside 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInside ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isInside ? LucideIcons.circleCheck : LucideIcons.bellRing,
            color: isInside ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isInside 
                  ? '${widget.child.fullName} está dentro de esta zona'
                  : '${widget.child.fullName} está FUERA de esta zona',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isInside ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Algoritmo ray casting para verificar si un punto está dentro del polígono
  bool _isPointInPolygon(double lat, double lng, List<LatLngPoint> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].lat;
      final yi = polygon[i].lng;
      final xj = polygon[j].lat;
      final yj = polygon[j].lng;
      
      if (((yi > lng) != (yj > lng)) && 
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    
    final lat = widget.child.device?.lastLatitude;
    final lng = widget.child.device?.lastLongitude;
    final lastSeen = widget.child.device?.lastSeen;

    if (lat == null || lng == null) {
      return _MapErrorState(
        message: 'No hay coordenadas recientes para ${widget.child.fullName}.',
      );
    }

    final location = LatLng(lat, lng);

    // Usar RepaintBoundary para aislar el mapa y mejorar rendimiento
    return RepaintBoundary(
      child: Stack(
        children: [
          GoogleMap(
          initialCameraPosition: CameraPosition(target: location, zoom: 17),
          mapType: _mapType,
          onMapCreated: (controller) {
            _mapController = controller;
            _lastAnimatedPosition = location;
          },
          onCameraMoveStarted: () {
            // Si el usuario mueve el mapa manualmente, dejar de seguir
            setState(() => _isFollowingChild = false);
          },
          // Optimizaciones de rendimiento
          tiltGesturesEnabled: false, // Desactivar inclinación 3D
          rotateGesturesEnabled: false, // Desactivar rotación para mejor rendimiento
          indoorViewEnabled: false, // Desactivar vistas interiores
          trafficEnabled: false, // Desactivar tráfico
          markers: {
            // Marcador del niño - personalizado con nombre e inicial
            Marker(
              markerId: MarkerId('child_${widget.child.id}'),
              position: location,
              anchor: const Offset(0.5, 1.0), // Anclar en la punta inferior
              infoWindow: InfoWindow(
                title: widget.child.fullName,
                snippet:
                    'Última actualización: ${lastSeen != null ? date_utils.relativeTime(lastSeen) : "Desconocida"}',
              ),
              icon: _childCustomMarker ?? _markerCache.childMarker,
            ),
            // Marcador del tutor (si está en modo navegación)
            if (_isNavigationMode && _tutorLocation != null)
              Marker(
                markerId: const MarkerId('tutor_location'),
                position: _tutorLocation!,
                infoWindow: const InfoWindow(title: 'Tu ubicación'),
                icon: _markerCache.tutorMarker,
              ),
          },
          // Líneas en el mapa
          polylines: {
            // Historial de rutas del niño
            if (_showRoute && widget.locationHistory.length > 1)
              Polyline(
                polylineId: const PolylineId('route_history'),
                points: widget.locationHistory,
                color: Colors.blue.withValues(alpha: 0.7),
                width: 4,
                patterns: [PatternItem.dot, PatternItem.gap(8)],
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            // Ruta de navegación hacia el niño (ruta real por calles)
            if (_isNavigationMode && _routePoints.isNotEmpty)
              Polyline(
                polylineId: const PolylineId('navigation_route'),
                points: _routePoints,
                color: const Color(0xFF1E8E3E), // Verde GeoGuard
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            // Línea recta de respaldo (solo si NO está cargando y NO hay ruta)
            if (_isNavigationMode && _tutorLocation != null && _routePoints.isEmpty && !_isLoadingRoute)
              Polyline(
                polylineId: const PolylineId('navigation_line'),
                points: [_tutorLocation!, location],
                color: const Color(0xFF1E8E3E).withValues(alpha: 0.6),
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
          },
          circles: {
            Circle(
              circleId: CircleId('accuracy_${widget.child.id}'),
              center: location,
              radius: 30,
              fillColor: Colors.blue.withValues(alpha: 0.1),
              strokeColor: Colors.blue.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
          },
          // Zonas seguras (polígonos)
          polygons: _buildSafeZonePolygons(),
          myLocationEnabled: false,
          zoomControlsEnabled: false, // Usaremos nuestros propios controles
          mapToolbarEnabled: false,
          compassEnabled: false,
          liteModeEnabled: false, // Mantener interactivo
          buildingsEnabled: false, // Desactivar edificios 3D
          minMaxZoomPreference: const MinMaxZoomPreference(10, 20), // Limitar zoom para rendimiento
          padding: const EdgeInsets.only(top: 16, bottom: 16),
        ),

        // Panel de controles (derecha)
        Positioned(
          top: 60,
          right: 16,
          child: Column(
            children: [
              // Botón localizar niño
              _MapControlButton(
                icon: LucideIcons.locateFixed,
                onTap: _centerOnChild,
                tooltip: 'Localizar a ${widget.child.fullName}',
                isActive: _isFollowingChild,
              ),
              const SizedBox(height: 8),
              // Botón modo navegación
              _MapControlButton(
                icon: LucideIcons.navigation,
                onTap: _toggleNavigationMode,
                tooltip: _isNavigationMode ? 'Desactivar navegación' : 'Navegar hacia ${widget.child.fullName}',
                isActive: _isNavigationMode,
              ),
              const SizedBox(height: 8),
              // Botón cambiar tipo de mapa
              _MapControlButton(
                icon: LucideIcons.layers,
                onTap: _showMapTypeSelector,
                tooltip: 'Tipo de mapa',
              ),
              const SizedBox(height: 8),
              // Botón mostrar/ocultar ruta
              _MapControlButton(
                icon: _showRoute ? LucideIcons.route : LucideIcons.routeOff,
                onTap: _toggleRoute,
                tooltip: _showRoute ? 'Ocultar ruta' : 'Mostrar ruta',
                isActive: _showRoute,
              ),
              const SizedBox(height: 8),
              // Botón mostrar/ocultar zonas seguras
              _MapControlButton(
                icon: _showSafeZones ? LucideIcons.shield : LucideIcons.shieldOff,
                onTap: () => setState(() => _showSafeZones = !_showSafeZones),
                tooltip: _showSafeZones ? 'Ocultar zonas seguras' : 'Mostrar zonas seguras',
                isActive: _showSafeZones,
                badge: _safeZones.isNotEmpty ? _safeZones.length.toString() : null,
              ),
              // Botón para ajustar vista a ambos marcadores (solo en modo navegación)
              if (_isNavigationMode && _tutorLocation != null) ...[
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: LucideIcons.maximize2,
                  onTap: _fitBothMarkers,
                  tooltip: 'Ver ambas ubicaciones',
                ),
              ],
            ],
          ),
        ),
        
        // Panel de información de navegación (encima del bottom sheet)
        if (_isNavigationMode && _distanceToChild != null && !_isActiveNavigation)
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: _NavigationInfoPanel(
              childName: widget.child.fullName,
              distance: _distanceToChild!,
              formatDistance: _formatDistance,
              onClose: _toggleNavigationMode,
              estimatedTime: _estimatedTime,
              totalDistance: _totalDistance,
              isLoadingRoute: _isLoadingRoute,
              travelMode: _travelMode,
              onTravelModeChanged: _changeTravelMode,
              onStartNavigation: _startActiveNavigation,
            ),
          ),
        
        // Panel de navegación activa (turn-by-turn)
        if (_isActiveNavigation && _navigationSteps.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _ActiveNavigationPanel(
              currentStep: _navigationSteps[_currentStepIndex],
              nextStep: _currentStepIndex < _navigationSteps.length - 1
                  ? _navigationSteps[_currentStepIndex + 1]
                  : null,
              totalSteps: _navigationSteps.length,
              currentStepIndex: _currentStepIndex,
              estimatedTime: _estimatedTime,
              totalDistance: _totalDistance,
              distanceToChild: _distanceToChild,
              formatDistance: _formatDistance,
              onClose: _stopActiveNavigation,
              childName: widget.child.fullName,
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
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
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

class _NavigationInfoPanel extends StatelessWidget {
  const _NavigationInfoPanel({
    required this.childName,
    required this.distance,
    required this.formatDistance,
    required this.onClose,
    required this.travelMode,
    required this.onTravelModeChanged,
    required this.onStartNavigation,
    this.estimatedTime,
    this.totalDistance,
    this.isLoadingRoute = false,
  });

  final String childName;
  final double distance;
  final String Function(double) formatDistance;
  final VoidCallback onClose;
  final String? estimatedTime;
  final String? totalDistance;
  final bool isLoadingRoute;
  final String travelMode;
  final void Function(String) onTravelModeChanged;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          // Fila superior: info y botón cerrar
          Row(
            children: [
              // Icono de navegación
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.navigation,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Navegando hacia $childName',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDistance(distance),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (estimatedTime != null && !isLoadingRoute) ...[
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.clock,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            estimatedTime!,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                        if (isLoadingRoute) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Botón cerrar
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  LucideIcons.x,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: 'Detener navegación',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Selector de modo de transporte
          Row(
            children: [
              Expanded(
                child: _TravelModeButton(
                  icon: LucideIcons.footprints,
                  label: 'A pie',
                  isSelected: travelMode == 'walking',
                  onTap: () => onTravelModeChanged('walking'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TravelModeButton(
                  icon: Icons.two_wheeler,
                  label: 'Moto',
                  isSelected: travelMode == 'motorcycling',
                  onTap: () => onTravelModeChanged('motorcycling'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TravelModeButton(
                  icon: LucideIcons.car,
                  label: 'Auto',
                  isSelected: travelMode == 'driving',
                  onTap: () => onTravelModeChanged('driving'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botón iniciar navegación
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartNavigation,
              icon: const Icon(LucideIcons.play, size: 18),
              label: const Text('Iniciar navegación'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelModeButton extends StatelessWidget {
  const _TravelModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTypeOption extends StatelessWidget {
  const _MapTypeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.mapType,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final MapType mapType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
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
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildMapPreview(isDark),
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

  Widget _buildMapPreview(bool isDark) {
    switch (mapType) {
      case MapType.normal:
        return _NormalMapPreview(isDark: isDark);
      case MapType.hybrid:
        return const _SatelliteMapPreview();
      case MapType.terrain:
        return const _TerrainMapPreview();
      default:
        return _NormalMapPreview(isDark: isDark);
    }
  }
}

// Vista previa del mapa Normal (calles)
class _NormalMapPreview extends StatelessWidget {
  const _NormalMapPreview({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF242f3e) : const Color(0xFFF5F5F3);
    final roadColor = isDark ? const Color(0xFF38414e) : Colors.white;
    final buildingColor = isDark
        ? const Color(0xFF333f54)
        : const Color(0xFFE8E8E8);

    return Container(
      color: bgColor,
      child: CustomPaint(
        painter: _NormalMapPainter(
          roadColor: roadColor,
          buildingColor: buildingColor,
        ),
        size: const Size(70, 70),
      ),
    );
  }
}

class _NormalMapPainter extends CustomPainter {
  final Color roadColor;
  final Color buildingColor;

  _NormalMapPainter({required this.roadColor, required this.buildingColor});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Calles horizontales
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      roadPaint,
    );

    // Calles verticales
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.7, size.height),
      roadPaint,
    );

    // Edificios (rectángulos pequeños)
    final buildingPaint = Paint()
      ..color = buildingColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(5, 5, 15, 12), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(5, 38, 18, 15), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(42, 5, 12, 10), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(42, 38, 14, 12), buildingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Vista previa del mapa Satélite
class _SatelliteMapPreview extends StatelessWidget {
  const _SatelliteMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4332),
            Color(0xFF2D6A4F),
            Color(0xFF40916C),
            Color(0xFF1B4332),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _SatelliteMapPainter(),
        size: const Size(70, 70),
      ),
    );
  }
}

class _SatelliteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Techos de edificios (grises oscuros)
    final roofPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(8, 8, 18, 14), roofPaint);
    canvas.drawRect(Rect.fromLTWH(45, 10, 16, 12), roofPaint);
    canvas.drawRect(Rect.fromLTWH(10, 45, 20, 16), roofPaint);
    canvas.drawRect(Rect.fromLTWH(48, 42, 14, 18), roofPaint);

    // Calles (gris claro)
    final roadPaint = Paint()
      ..color = const Color(0xFF6B6B6B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(size.width, size.height * 0.38),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.42, 0),
      Offset(size.width * 0.42, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Vista previa del mapa Terreno
class _TerrainMapPreview extends StatelessWidget {
  const _TerrainMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F1E6),
      child: CustomPaint(
        painter: _TerrainMapPainter(),
        size: const Size(70, 70),
      ),
    );
  }
}

class _TerrainMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Curvas de nivel (líneas topográficas)
    final contourPaint = Paint()
      ..color = const Color(0xFFD4C5A9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path1 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.3,
        size.width * 0.6,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.65,
        size.width,
        size.height * 0.4,
      );

    final path2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.5,
        size.width * 0.7,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.8,
        size.width,
        size.height * 0.6,
      );

    final path3 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.2,
        size.width * 0.5,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.4,
        size.width,
        size.height * 0.2,
      );

    canvas.drawPath(path1, contourPaint);
    canvas.drawPath(path2, contourPaint);
    canvas.drawPath(path3, contourPaint);

    // Zonas verdes (vegetación)
    final greenPaint = Paint()
      ..color = const Color(0xFFC8D9B8)
      ..style = PaintingStyle.fill;

    canvas.drawOval(Rect.fromLTWH(5, 5, 25, 20), greenPaint);
    canvas.drawOval(Rect.fromLTWH(45, 50, 20, 15), greenPaint);

    // Calle
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapErrorState extends StatelessWidget {
  const _MapErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mapPinOff, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modelo para un paso de navegación
class NavigationStep {
  final String instruction;
  final String distance;
  final String duration;
  final String maneuver;
  final LatLng startLocation;
  final LatLng endLocation;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.startLocation,
    required this.endLocation,
  });
}

/// Panel de navegación activa (turn-by-turn) - Estilo Google Maps
class _ActiveNavigationPanel extends StatelessWidget {
  const _ActiveNavigationPanel({
    required this.currentStep,
    required this.totalSteps,
    required this.currentStepIndex,
    required this.onClose,
    required this.childName,
    required this.formatDistance,
    this.nextStep,
    this.estimatedTime,
    this.totalDistance,
    this.distanceToChild,
  });

  final NavigationStep currentStep;
  final NavigationStep? nextStep;
  final int totalSteps;
  final int currentStepIndex;
  final String? estimatedTime;
  final String? totalDistance;
  final double? distanceToChild;
  final String Function(double) formatDistance;
  final VoidCallback onClose;
  final String childName;

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'uturn-right':
        return Icons.u_turn_right;
      case 'roundabout-left':
        return Icons.roundabout_left;
      case 'roundabout-right':
        return Icons.roundabout_right;
      case 'merge':
        return Icons.merge;
      case 'fork-left':
        return Icons.fork_left;
      case 'fork-right':
        return Icons.fork_right;
      case 'ramp-left':
        return Icons.ramp_left;
      case 'ramp-right':
        return Icons.ramp_right;
      default:
        return Icons.straight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Panel principal verde (estilo Google Maps)
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: statusBarHeight + 16,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono de maniobra grande
              Icon(
                _getManeuverIcon(currentStep.maneuver),
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              // Distancia e instrucción
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Distancia grande
                    Text(
                      currentStep.distance,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Instrucción
                    Text(
                      currentStep.instruction,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Panel inferior con info de llegada
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Tiempo estimado
              if (estimatedTime != null)
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        estimatedTime!,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (totalDistance != null)
                        Text(
                          '· $totalDistance',
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              // Botón cerrar navegación
              Material(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Salir',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Siguiente maniobra (si existe)
        if (nextStep != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _getManeuverIcon(nextStep!.maneuver),
                  size: 24,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 12),
                Text(
                  'Después ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Text(
                    nextStep!.instruction,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
