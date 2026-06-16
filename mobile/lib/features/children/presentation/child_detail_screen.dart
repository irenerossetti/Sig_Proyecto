import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../monitoring/domain/monitoring_models.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';
import '../../monitoring/presentation/all_children_map_view.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../monitoring/data/monitoring_repository.dart';
import '../../groups/presentation/bloc/groups_bloc.dart';
import '../../../core/di/injection_container.dart';

class ChildDetailScreen extends StatefulWidget {
  const ChildDetailScreen({
    super.key,
    required this.childId,
    this.initialChild,
  });

  final int childId;
  final ChildModel? initialChild;

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  late ChildModel? _child;
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _child = widget.initialChild;
    if (_child == null) {
      _loadChild();
    }
  }

  Future<void> _loadChild() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthBloc>().state.token;
      if (token == null) throw Exception('No autenticado');

      final child = await sl<MonitoringRepository>().fetchChildDetail(
        token: token,
        childId: widget.childId,
      );
      setState(() {
        _child = child;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChild() async {
    // Guardar referencias antes del await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final childrenBloc = context.read<ChildrenBloc>();
    final token = context.read<AuthBloc>().state.token;
    final navigator = Navigator.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar niño'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${_child?.fullName}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    if (token == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('No autenticado')),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await sl<MonitoringRepository>().deleteChild(
        token: token,
        childId: widget.childId,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Niño eliminado correctamente')),
        );
        // Invalidar caché de grupos para que el mapa se actualice correctamente
        GroupsCacheManager.invalidate();
        // Forzar refresh de niños y grupos (ignorar caché)
        childrenBloc.add(const ChildrenFetchRequested(forceRefresh: true));
        sl<GroupsBloc>().add(const GroupsFetchRequested(forceRefresh: true));
        navigator.pop();
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_child?.fullName ?? 'Detalle del niño'),
        actions: [
          if (_child != null) ...[
            IconButton(
              icon: const Icon(LucideIcons.pencil),
              tooltip: 'Editar',
              onPressed: () async {
                final result = await context.pushNamed(
                  'child-edit',
                  pathParameters: {'id': widget.childId.toString()},
                  extra: _child,
                );
                if (result == true) {
                  _loadChild();
                }
              },
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.trash2),
              tooltip: 'Eliminar',
              onPressed: _isDeleting ? null : _deleteChild,
            ),
          ],
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadChild,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_child == null) {
      return const Center(child: Text('No se encontró el niño'));
    }

    final child = _child!;
    final initial = child.fullName.isNotEmpty
        ? child.fullName.substring(0, 1)
        : '?';

    return RefreshIndicator(
      onRefresh: _loadChild,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con avatar
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                        ? NetworkImage(child.photoUrl!)
                        : null,
                    child: child.photoUrl == null || child.photoUrl!.isEmpty
                        ? Text(
                            initial,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    child.fullName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(isActive: child.isActive),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Información básica
            _SectionCard(
              title: 'Información',
              icon: LucideIcons.info,
              children: [
                _InfoRow(
                  label: 'Fecha de nacimiento',
                  value: _formatDate(child.dateOfBirth),
                  icon: LucideIcons.calendar,
                ),
                _InfoRow(
                  label: 'Edad',
                  value: _calculateAge(child.dateOfBirth),
                  icon: LucideIcons.cake,
                ),
                if (child.notes != null && child.notes!.isNotEmpty)
                  _InfoRow(
                    label: 'Notas',
                    value: child.notes!,
                    icon: LucideIcons.stickyNote,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Dispositivo
            _SectionCard(
              title: 'Dispositivo',
              icon: LucideIcons.watch,
              children: [
                if (child.device != null) ...[
                  _InfoRow(
                    label: 'Device ID (usar en Tracker)',
                    value: child.device!.deviceId,
                    icon: LucideIcons.hash,
                  ),
                  if (child.device!.batteryLevel != null)
                    _InfoRow(
                      label: 'Batería',
                      value: '${child.device!.batteryLevel}%',
                      icon: LucideIcons.battery,
                    ),
                  if (child.device!.lastSeen != null)
                    _InfoRow(
                      label: 'Última conexión',
                      value: _formatDateTime(child.device!.lastSeen!),
                      icon: LucideIcons.clock,
                    ),
                  _InfoRow(
                    label: 'Estado',
                    value: child.device!.isActive ? 'Activo' : 'Inactivo',
                    icon: LucideIcons.activity,
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.unlink,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin dispositivo asignado',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.pushNamed(
                            'device-create',
                            pathParameters: {'id': child.id.toString()},
                            extra: child.fullName,
                          ),
                          icon: const Icon(LucideIcons.link),
                          label: const Text('Asignar dispositivo'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Acciones
            if (child.device != null && _hasCoordinates(child)) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.mapPin),
                  label: const Text('Ver ubicación en mapa'),
                  onPressed: () {
                    // Navegar al Home con la pestaña Mapa (3) y el niño seleccionado
                    context.go('/home?tab=3&childId=${child.id}');
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.shield),
                  label: const Text('Zonas seguras'),
                  onPressed: () {
                    final location = child.device?.lastLatitude != null && 
                                     child.device?.lastLongitude != null
                        ? LatLng(child.device!.lastLatitude!, child.device!.lastLongitude!)
                        : null;
                    context.pushNamed(
                      'safe-zones-list',
                      pathParameters: {'id': child.id.toString()},
                      extra: {
                        'childName': child.fullName,
                        'location': location,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botón eliminar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(LucideIcons.trash2, color: theme.colorScheme.error),
                label: Text(
                  'Eliminar niño',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                onPressed: _isDeleting ? null : _deleteChild,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? Colors.green : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _formatDateTime(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String _calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  int years = now.year - birthDate.year;
  int months = now.month - birthDate.month;

  if (months < 0 || (months == 0 && now.day < birthDate.day)) {
    years--;
    months += 12;
  }

  if (now.day < birthDate.day) {
    months--;
  }

  if (years > 0) {
    return '$years años${months > 0 ? ' y $months meses' : ''}';
  }
  return '$months meses';
}

bool _hasCoordinates(ChildModel child) {
  final lat = child.device?.lastLatitude;
  final lng = child.device?.lastLongitude;
  return lat != null && lng != null;
}
