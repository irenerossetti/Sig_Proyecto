import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/monitoring_models.dart';
import 'bloc/safe_zone_bloc.dart';

/// Pantalla para crear o editar una zona segura (polígono)
class SafeZoneEditorScreen extends StatefulWidget {
  const SafeZoneEditorScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.initialLocation,
    this.existingZone,
  });

  final int childId;
  final String childName;
  final LatLng? initialLocation;
  final SafeZoneModel? existingZone;

  @override
  State<SafeZoneEditorScreen> createState() => _SafeZoneEditorScreenState();
}

class _SafeZoneEditorScreenState extends State<SafeZoneEditorScreen> {
  GoogleMapController? _mapController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  // Usar ValueNotifier para actualizaciones rápidas durante el arrastre
  final ValueNotifier<List<LatLng>> _polygonPointsNotifier = ValueNotifier([]);
  
  bool _isDrawing = true;
  String _selectedColor = '#1E8E3E';
  
  // Cache de iconos de marcador
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  
  final List<String> _availableColors = [
    '#1E8E3E', // Verde
    '#4285F4', // Azul
    '#EA4335', // Rojo
    '#FBBC04', // Amarillo
    '#9C27B0', // Púrpura
    '#FF5722', // Naranja
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingZone != null) {
      _nameController.text = widget.existingZone!.name;
      _selectedColor = widget.existingZone!.color;
      _polygonPointsNotifier.value = widget.existingZone!.polygonPoints
          .map((p) => LatLng(p.lat, p.lng))
          .toList();
      _isDrawing = false;
    }
    _createMarkerIcon(_selectedColor);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    _polygonPointsNotifier.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  /// Crea un icono circular pequeño para los marcadores (arrastrable)
  Future<void> _createMarkerIcon(String colorHex) async {
    if (_markerIconCache.containsKey(colorHex)) return;
    
    const double size = 24; // Tamaño más pequeño
    const double borderWidth = 2;
    
    final color = _parseColor(colorHex);
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    // Sombra sutil
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 1),
      size / 2 - borderWidth,
      shadowPaint,
    );
    
    // Borde blanco
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 1,
      borderPaint,
    );
    
    // Círculo interior del color seleccionado
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - borderWidth - 1,
      fillPaint,
    );
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    _markerIconCache[colorHex] = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    if (mounted) setState(() {});
  }

  /// Construye los marcadores arrastrables para los vértices
  Set<Marker> _buildDraggableMarkers(List<LatLng> points) {
    final markers = <Marker>{};
    final icon = _markerIconCache[_selectedColor];
    
    if (icon == null) return markers;
    
    for (int i = 0; i < points.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('vertex_$i'),
          position: points[i],
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          draggable: _isDrawing,
          // Actualización ultra rápida: modificar directamente la lista
          onDrag: (newPosition) {
            final newList = List<LatLng>.from(_polygonPointsNotifier.value);
            newList[i] = newPosition;
            _polygonPointsNotifier.value = newList;
          },
          onDragEnd: (newPosition) {
            final newList = List<LatLng>.from(_polygonPointsNotifier.value);
            newList[i] = newPosition;
            _polygonPointsNotifier.value = newList;
          },
        ),
      );
    }
    return markers;
  }

  void _onMapTap(LatLng position) {
    if (!_isDrawing) return;
    
    final newList = List<LatLng>.from(_polygonPointsNotifier.value);
    newList.add(position);
    _polygonPointsNotifier.value = newList;
    setState(() {}); // Actualizar UI de botones
  }

  void _saveZone() {
    if (!_formKey.currentState!.validate()) return;
    if (_polygonPointsNotifier.value.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dibuja un polígono con al menos 3 puntos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final points = _polygonPointsNotifier.value
        .map((p) => LatLngPoint(lat: p.latitude, lng: p.longitude))
        .toList();

    final bloc = context.read<SafeZoneBloc>();

    if (widget.existingZone != null) {
      // Actualizar zona existente
      bloc.add(SafeZoneUpdateRequested(
        zoneId: widget.existingZone!.id,
        data: {
          'name': _nameController.text.trim(),
          'polygon_points': points.map((p) => p.toJson()).toList(),
          'color': _selectedColor,
        },
      ));
    } else {
      // Crear nueva zona
      final payload = CreateSafeZonePayload(
        childId: widget.childId,
        name: _nameController.text.trim(),
        zoneType: 'polygon',
        polygonPoints: points,
        color: _selectedColor,
      );
      bloc.add(SafeZoneCreateRequested(payload));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Ubicación inicial: la del niño o Santa Cruz por defecto
    final initialPosition = widget.initialLocation ?? 
        const LatLng(-17.7833, -63.1821);

    return BlocListener<SafeZoneBloc, SafeZoneState>(
      listener: (context, state) {
        if (state is SafeZoneOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is SafeZoneOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingZone != null 
                ? 'Editar zona segura' 
                : 'Nueva zona segura',
          ),
        ),
        body: Column(
          children: [
            // Información del niño y formulario
            Container(
              padding: const EdgeInsets.all(16),
              color: colorScheme.surfaceContainerHighest,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona para: ${widget.childName}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        hintText: 'Ej: Casa, Escuela, Parque...',
                        prefixIcon: Icon(LucideIcons.mapPin),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre para la zona';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Selector de color
                    Row(
                      children: [
                        Text(
                          'Color: ',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        ..._availableColors.map((color) {
                          final isSelected = color == _selectedColor;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedColor = color);
                              _createMarkerIcon(color);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _parseColor(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected 
                                      ? colorScheme.onSurface 
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Mapa con ValueListenableBuilder para actualizaciones rápidas
            Expanded(
              child: Stack(
                children: [
                  ValueListenableBuilder<List<LatLng>>(
                    valueListenable: _polygonPointsNotifier,
                    builder: (context, points, _) {
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialPosition,
                          zoom: 16,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          // Si hay puntos existentes, ajustar la cámara
                          if (points.isNotEmpty) {
                            _fitPolygonBounds();
                          }
                        },
                        onTap: _onMapTap,
                        mapType: MapType.normal,
                        buildingsEnabled: false,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        // Marcadores arrastrables para los vértices
                        markers: _buildDraggableMarkers(points),
                        // Círculos decorativos (no arrastrables) detrás de los marcadores
                        circles: points.asMap().entries.map((entry) {
                          return Circle(
                            circleId: CircleId('circle_${entry.key}'),
                            center: entry.value,
                            radius: 3, // 3 metros
                            fillColor: _parseColor(_selectedColor).withValues(alpha: 0.3),
                            strokeColor: _parseColor(_selectedColor),
                            strokeWidth: 1,
                          );
                        }).toSet(),
                        // Polígono
                        polygons: points.length >= 3
                            ? {
                                Polygon(
                                  polygonId: const PolygonId('safe_zone'),
                                  points: points,
                                  fillColor: _parseColor(_selectedColor).withValues(alpha: 0.3),
                                  strokeColor: _parseColor(_selectedColor),
                                  strokeWidth: 3,
                                ),
                              }
                            : {},
                        // Líneas mientras se dibuja (menos de 3 puntos)
                        polylines: points.length >= 2 && points.length < 3
                            ? {
                                Polyline(
                                  polylineId: const PolylineId('drawing_line'),
                                  points: points,
                                  color: _parseColor(_selectedColor),
                                  width: 3,
                                ),
                              }
                            : {},
                      );
                    },
                  ),
                  
                  // Panel de instrucciones
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isDrawing ? LucideIcons.pencil : LucideIcons.check,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isDrawing
                                  ? 'Toca el mapa para agregar puntos (${_polygonPointsNotifier.value.length}/3+ puntos)'
                                  : 'Zona definida con ${_polygonPointsNotifier.value.length} puntos',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Botones de control
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fila de botones de edición
                        Row(
                          children: [
                            // Botón deshacer
                            if (_polygonPointsNotifier.value.isNotEmpty)
                              Expanded(
                                child: _ControlButton(
                                  icon: LucideIcons.undo2,
                                  label: 'Deshacer',
                                  onTap: () {
                                    final newList = List<LatLng>.from(_polygonPointsNotifier.value);
                                    newList.removeLast();
                                    _polygonPointsNotifier.value = newList;
                                    setState(() {});
                                  },
                                ),
                              ),
                            if (_polygonPointsNotifier.value.isNotEmpty)
                              const SizedBox(width: 8),
                            // Botón limpiar
                            if (_polygonPointsNotifier.value.isNotEmpty)
                              Expanded(
                                child: _ControlButton(
                                  icon: LucideIcons.trash2,
                                  label: 'Limpiar',
                                  onTap: () {
                                    _polygonPointsNotifier.value = [];
                                    setState(() {
                                      _isDrawing = true;
                                    });
                                  },
                                  isDestructive: true,
                                ),
                              ),
                            if (_polygonPointsNotifier.value.isEmpty)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.info,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Toca el mapa para dibujar',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Botón principal (Terminar o Guardar)
                        if (_polygonPointsNotifier.value.length >= 3)
                          SizedBox(
                            width: double.infinity,
                            child: BlocBuilder<SafeZoneBloc, SafeZoneState>(
                              builder: (context, state) {
                                final isLoading = state is SafeZoneOperationInProgress;
                                
                                if (_isDrawing) {
                                  // Botón para terminar de dibujar
                                  return FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isDrawing = false;
                                      });
                                    },
                                    icon: const Icon(LucideIcons.check),
                                    label: const Text('Terminar de dibujar'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  );
                                } else {
                                  // Botón para guardar
                                  return FilledButton.icon(
                                    onPressed: isLoading ? null : _saveZone,
                                    icon: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(LucideIcons.save),
                                    label: Text(isLoading ? 'Guardando...' : 'Guardar zona segura'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        // Botón editar (cuando ya terminó de dibujar)
                        if (!_isDrawing && _polygonPointsNotifier.value.length >= 3) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _isDrawing = true),
                              icon: const Icon(LucideIcons.pencil),
                              label: const Text('Seguir editando'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Botón mi ubicación
                  Positioned(
                    bottom: 180,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'my_location',
                      onPressed: _goToMyLocation,
                      child: const Icon(LucideIcons.locateFixed),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitPolygonBounds() {
    final points = _polygonPointsNotifier.value;
    if (points.isEmpty || _mapController == null) return;
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  void _goToMyLocation() {
    if (widget.initialLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(widget.initialLocation!, 17),
      );
    }
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive ? colorScheme.error : colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? colorScheme.error : colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
