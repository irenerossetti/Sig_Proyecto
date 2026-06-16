import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/monitoring_models.dart';
import 'bloc/safe_zone_bloc.dart';

/// Pantalla que lista las zonas seguras de un niño
class SafeZonesListScreen extends StatefulWidget {
  const SafeZonesListScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.childLocation,
  });

  final int childId;
  final String childName;
  final LatLng? childLocation;

  @override
  State<SafeZonesListScreen> createState() => _SafeZonesListScreenState();
}

class _SafeZonesListScreenState extends State<SafeZonesListScreen> {
  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  void _loadZones() {
    context.read<SafeZoneBloc>().add(SafeZonesFetchRequested(widget.childId));
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  void _navigateToEditor({SafeZoneModel? zone}) async {
    final result = await context.push<bool>(
      '/home/safe-zone-editor',
      extra: {
        'childId': widget.childId,
        'childName': widget.childName,
        'initialLocation': widget.childLocation,
        'existingZone': zone,
      },
    );
    
    if (result == true && mounted) {
      _loadZones();
    }
  }

  void _toggleZone(SafeZoneModel zone) {
    context.read<SafeZoneBloc>().add(
      SafeZoneToggleRequested(
        zoneId: zone.id,
        childId: widget.childId,
        isActive: !zone.isActive,
      ),
    );
  }

  void _confirmDelete(SafeZoneModel zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar zona'),
        content: Text('¿Estás seguro de eliminar la zona "${zone.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SafeZoneBloc>().add(
                SafeZoneDeleteRequested(
                  zoneId: zone.id,
                  childId: widget.childId,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<SafeZoneBloc, SafeZoneState>(
      listener: (context, state) {
        if (state is SafeZoneOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          // Recargar la lista después de una operación exitosa
          _loadZones();
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
          title: const Text('Zonas seguras'),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: _loadZones,
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con info del niño
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: const Icon(
                      LucideIcons.baby,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.childName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Gestiona las zonas seguras',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Lista de zonas
            Expanded(
              child: BlocBuilder<SafeZoneBloc, SafeZoneState>(
                builder: (context, state) {
                  if (state is SafeZoneLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is SafeZoneError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.circleAlert,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar zonas',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadZones,
                            icon: const Icon(LucideIcons.refreshCw),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (state is SafeZoneLoaded) {
                    if (state.zones.isEmpty) {
                      return _buildEmptyState(theme, colorScheme);
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.zones.length,
                      itemBuilder: (context, index) {
                        final zone = state.zones[index];
                        return _SafeZoneCard(
                          zone: zone,
                          color: _parseColor(zone.color),
                          onEdit: () => _navigateToEditor(zone: zone),
                          onDelete: () => _confirmDelete(zone),
                          onToggle: () => _toggleZone(zone),
                        );
                      },
                    );
                  }
                  
                  return _buildEmptyState(theme, colorScheme);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _navigateToEditor(),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Nueva zona'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin zonas seguras',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una zona segura para recibir alertas cuando ${widget.childName} salga del área definida.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _navigateToEditor(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Crear zona segura'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({
    required this.zone,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final SafeZoneModel zone;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Indicador de color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  LucideIcons.shield,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.hexagon,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${zone.polygonPoints.length} puntos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: zone.isActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            zone.isActive ? 'Activa' : 'Inactiva',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: zone.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Acciones
              PopupMenuButton<String>(
                icon: Icon(
                  LucideIcons.ellipsisVertical,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'toggle') {
                    onToggle();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          zone.isActive ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(zone.isActive ? 'Desactivar' : 'Activar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(LucideIcons.pencil, size: 18),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
