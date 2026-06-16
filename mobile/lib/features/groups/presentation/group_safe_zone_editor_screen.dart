import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/group_models.dart';
import 'bloc/group_detail_bloc.dart';

/// Pantalla para crear o editar una zona segura de grupo (polígono)
class GroupSafeZoneEditorScreen extends StatefulWidget {
  const GroupSafeZoneEditorScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialLocation,
    this.existingZone,
  });

  final int groupId;
  final String groupName;
  final LatLng? initialLocation;
  final GroupSafeZoneModel? existingZone;

  @override
  State<GroupSafeZoneEditorScreen> createState() => _GroupSafeZoneEditorScreenState();
}

class _GroupSafeZoneEditorScreenState extends State<GroupSafeZoneEditorScreen> {
  GoogleMapController? _mapController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  final ValueNotifier<List<LatLng>> _polygonPointsNotifier = ValueNotifier([]);
  
  bool _isDrawing = true;
  String _selectedColor = '#4CAF50';
  
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  
  final List<String> _availableColors = [
    '#4CAF50', // Verde
    '#2196F3', // Azul
    '#F44336', // Rojo
    '#FF9800', // Naranja
    '#9C27B0', // Púrpura
    '#00BCD4', // Cyan
  ];

  bool get _isEditing => widget.existingZone != null;

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

  Future<void> _createMarkerIcon(String colorHex) async {
    if (_markerIconCache.containsKey(colorHex)) return;
    
    const double size = 28;
    const double borderWidth = 3;
    
    final color = _parseColor(colorHex);
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    // Sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
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
    
    // Círculo interior
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
    setState(() {});
  }

  void _undoLastPoint() {
    if (_polygonPointsNotifier.value.isEmpty) return;
    final newList = List<LatLng>.from(_polygonPointsNotifier.value);
    newList.removeLast();
    _polygonPointsNotifier.value = newList;
    setState(() {});
  }

  void _clearAllPoints() {
    _polygonPointsNotifier.value = [];
    setState(() {});
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

    final bloc = context.read<GroupDetailBloc>();

    if (_isEditing) {
      bloc.add(GroupDetailUpdateSafeZone(
        zoneId: widget.existingZone!.id,
        name: _nameController.text.trim(),
        polygonPoints: points,
        color: _selectedColor,
      ));
    } else {
      bloc.add(GroupDetailCreatePolygonSafeZone(
        name: _nameController.text.trim(),
        polygonPoints: points,
        color: _selectedColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Santa Cruz de la Sierra por defecto
    final initialPosition = widget.initialLocation ?? 
        const LatLng(-17.7833, -63.1821);

    return BlocListener<GroupDetailBloc, GroupDetailState>(
      listener: (context, state) {
        if (state is GroupDetailActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is GroupDetailError) {
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
          title: Text(_isEditing ? 'Editar zona' : 'Nueva zona del grupo'),
          actions: [
            if (_polygonPointsNotifier.value.isNotEmpty)
              IconButton(
                onPressed: _undoLastPoint,
                icon: const Icon(LucideIcons.undo),
                tooltip: 'Deshacer último punto',
              ),
            if (_polygonPointsNotifier.value.length > 1)
              IconButton(
                onPressed: _clearAllPoints,
                icon: const Icon(LucideIcons.trash2),
                tooltip: 'Limpiar todo',
              ),
          ],
        ),
        body: Column(
          children: [
            // Formulario superior
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grupo info
                    Row(
                      children: [
                        Icon(
                          LucideIcons.users,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Zona para: ${widget.groupName}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Nombre de zona
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        hintText: 'Ej: Área del colegio, Patio, etc.',
                        prefixIcon: Icon(LucideIcons.tag),
                        isDense: true,
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
                        Text('Color:', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 12),
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
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _parseColor(color).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
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
            
            // Instrucciones
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _parseColor(_selectedColor).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    _isDrawing ? LucideIcons.pencil : LucideIcons.lock,
                    size: 16,
                    color: _parseColor(_selectedColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isDrawing
                          ? 'Toca el mapa para agregar puntos del polígono (mínimo 3)'
                          : 'Toca "Editar" para modificar la zona',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _parseColor(_selectedColor),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${_polygonPointsNotifier.value.length} puntos',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _parseColor(_selectedColor),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Mapa
            Expanded(
              child: ValueListenableBuilder<List<LatLng>>(
                valueListenable: _polygonPointsNotifier,
                builder: (context, points, _) {
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialPosition,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: _onMapTap,
                    markers: _buildDraggableMarkers(points),
                    polygons: points.length >= 3
                        ? {
                            Polygon(
                              polygonId: const PolygonId('zone'),
                              points: points,
                              fillColor: _parseColor(_selectedColor).withValues(alpha: 0.25),
                              strokeColor: _parseColor(_selectedColor),
                              strokeWidth: 3,
                            ),
                          }
                        : {},
                    polylines: points.length >= 2 && points.length < 3
                        ? {
                            Polyline(
                              polylineId: const PolylineId('preview'),
                              points: points,
                              color: _parseColor(_selectedColor),
                              width: 3,
                            ),
                          }
                        : {},
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  );
                },
              ),
            ),
            
            // Botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (!_isDrawing)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _isDrawing = true),
                          icon: const Icon(LucideIcons.pencil),
                          label: const Text('Editar'),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _polygonPointsNotifier.value.length >= 3
                              ? () => setState(() => _isDrawing = false)
                              : null,
                          icon: const Icon(LucideIcons.lock),
                          label: const Text('Bloquear'),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: BlocBuilder<GroupDetailBloc, GroupDetailState>(
                        builder: (context, state) {
                          final isLoading = state is GroupDetailActionLoading;
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
                            label: Text(_isEditing ? 'Actualizar' : 'Guardar zona'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
