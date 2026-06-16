import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../monitoring/domain/monitoring_models.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';
import '../../monitoring/presentation/bloc/alerts_bloc.dart';
import '../../../core/utils/date_utils.dart' as date_utils;

class ChildrenListScreen extends StatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChildrenBloc, ChildrenState>(
      builder: (context, state) {
        final childCount = state is ChildrenLoaded ? state.children.length : 0;
        
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Niños registrados'),
                if (childCount > 0)
                  Text(
                    '$childCount niño${childCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                tooltip: 'Actualizar',
                onPressed: () {
                  context.read<ChildrenBloc>().add(ChildrenFetchRequested());
                  // También actualizar alertas
                  context.read<AlertsBloc>().add(AlertsFetchRequested());
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.pushNamed('child-create'),
            icon: const Icon(LucideIcons.userPlus),
            label: const Text('Registrar niño'),
          ),
          body: Column(
            children: [
              // Search bar
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              // Children list
              Expanded(
                child: ChildrenListView(
                  padding: const EdgeInsets.all(16),
                  searchQuery: _searchQuery,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ChildrenListView extends StatelessWidget {
  const ChildrenListView({
    super.key,
    this.padding = EdgeInsets.zero,
    this.searchQuery = '',
  });

  final EdgeInsetsGeometry padding;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChildrenBloc, ChildrenState>(
      builder: (context, state) {
        if (state is ChildrenLoaded) {
          // Filter children by search query
          final filteredChildren = searchQuery.isEmpty
              ? state.children
              : state.children.where((child) =>
                  child.fullName.toLowerCase().contains(searchQuery.toLowerCase())
                ).toList();

          if (state.children.isEmpty) {
            return _RefreshableList(
              padding: padding,
              onRefresh: () async =>
                  context.read<ChildrenBloc>().add(ChildrenFetchRequested()),
              child: const _EmptyState(),
            );
          }

          if (filteredChildren.isEmpty) {
            return _RefreshableList(
              padding: padding,
              onRefresh: () async =>
                  context.read<ChildrenBloc>().add(ChildrenFetchRequested()),
              child: _NoResultsState(query: searchQuery),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<ChildrenBloc>().add(ChildrenFetchRequested()),
            child: ListView.separated(
              padding: padding,
              itemBuilder: (context, index) =>
                  _ChildCard(child: filteredChildren[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: filteredChildren.length,
            ),
          );
        } else if (state is ChildrenLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ChildrenError) {
          return _RefreshableList(
            padding: padding,
            onRefresh: () async =>
                context.read<ChildrenBloc>().add(ChildrenFetchRequested()),
            child: _ErrorState(message: state.message),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _RefreshableList extends StatelessWidget {
  const _RefreshableList({
    required this.child,
    required this.onRefresh,
    required this.padding,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: padding,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final ChildModel child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = child.fullName.isNotEmpty
        ? child.fullName.substring(0, 1).toUpperCase()
        : '?';
    final age = date_utils.calculateAge(child.dateOfBirth);
    final hasRecentLocation = _hasRecentLocation(child);
    final isSharedChild = !child.isOwnChild;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSharedChild 
              ? colorScheme.secondary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await context.pushNamed(
            'child-detail',
            pathParameters: {'id': child.id.toString()},
            extra: child,
          );
          // Refrescar cuando regresamos del detalle
          if (context.mounted) {
            context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador de niño compartido
            if (isSharedChild)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(LucideIcons.users, size: 14, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        child.tutorName != null 
                            ? 'Compartido por ${child.tutorName}'
                            : 'Niño de grupo compartido',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Solo lectura',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Header con avatar y info principal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar con indicador de ubicación
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isSharedChild 
                            ? colorScheme.secondaryContainer
                            : colorScheme.primaryContainer,
                        backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                            ? NetworkImage(child.photoUrl!)
                            : null,
                        child: child.photoUrl == null || child.photoUrl!.isEmpty
                            ? Text(
                                initial,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: isSharedChild 
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (child.device != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: hasRecentLocation ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.surface, width: 2),
                            ),
                            child: Icon(
                              hasRecentLocation ? LucideIcons.mapPin : LucideIcons.mapPinOff,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                child.fullName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusChip(isActive: child.isActive),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.cake, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '$age años',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(LucideIcons.calendar, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              date_utils.formatDate(child.dateOfBirth),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    color: colorScheme.outline,
                    size: 20,
                  ),
                ],
              ),
            ),
            
            // Alertas pendientes (si hay)
            BlocBuilder<AlertsBloc, AlertsState>(
              builder: (context, alertsState) {
                if (alertsState is AlertsLoaded) {
                  final pendingAlerts = alertsState.alerts
                      .where((a) => a.childId == child.id && a.status == 'pending')
                      .length;
                  if (pendingAlerts > 0) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      child: Row(
                        children: [
                          Icon(LucideIcons.bellRing, size: 16, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            '$pendingAlerts alerta${pendingAlerts == 1 ? '' : 's'} pendiente${pendingAlerts == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => context.push('/home/alerts'),
                            icon: const Icon(LucideIcons.eye, size: 14),
                            label: const Text('Ver'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),

            // Notas (si hay)
            if ((child.notes ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.stickyNote, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        child.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Device info o asignar dispositivo
            Padding(
              padding: const EdgeInsets.all(16),
              child: child.device != null
                  ? _DeviceInfo(child: child, hasRecentLocation: hasRecentLocation)
                  : _NoDeviceWarning(child: child, isSharedChild: isSharedChild),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceInfo extends StatelessWidget {
  const _DeviceInfo({required this.child, required this.hasRecentLocation});

  final ChildModel child;
  final bool hasRecentLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final device = child.device!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.watch,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dispositivo: ${device.deviceId}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _LocationStatusBadge(
                              hasRecentLocation: hasRecentLocation,
                              lastSeen: device.lastSeen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (device.batteryLevel != null)
                    _BatteryIndicator(level: device.batteryLevel!),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: _hasCoordinates(child)
                  ? FilledButton.icon(
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: const Text('Ver en mapa'),
                      onPressed: () => context.go('/home?tab=3&childId=${child.id}'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  : OutlinedButton.icon(
                      icon: Icon(LucideIcons.mapPinOff, size: 18, color: colorScheme.outline),
                      label: Text(
                        'Sin ubicación',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.shield, size: 18),
                label: const Text('Zonas seguras'),
                onPressed: () async {
                  await context.pushNamed(
                    'safe-zones-list',
                    pathParameters: {'id': child.id.toString()},
                    extra: {
                      'childName': child.fullName,
                      'location': _hasCoordinates(child)
                          ? null // Would need to import LatLng
                          : null,
                    },
                  );
                  if (context.mounted) {
                    context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationStatusBadge extends StatelessWidget {
  const _LocationStatusBadge({required this.hasRecentLocation, this.lastSeen});

  final bool hasRecentLocation;
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasRecentLocation ? Colors.green : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            lastSeen != null
                ? date_utils.relativeTime(lastSeen!)
                : 'Sin conexión',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDeviceWarning extends StatelessWidget {
  const _NoDeviceWarning({required this.child, this.isSharedChild = false});

  final ChildModel child;
  final bool isSharedChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSharedChild 
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : colorScheme.errorContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSharedChild 
                  ? colorScheme.outline.withValues(alpha: 0.3)
                  : colorScheme.error.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSharedChild 
                      ? colorScheme.secondaryContainer
                      : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.unlink,
                  size: 20,
                  color: isSharedChild 
                      ? colorScheme.secondary
                      : colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin dispositivo',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSharedChild 
                            ? colorScheme.secondary
                            : colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isSharedChild 
                          ? 'El tutor principal debe asignar un tracker'
                          : 'Asigna un tracker para monitorear',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSharedChild 
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Solo mostrar botón de asignar si es hijo propio
        if (!isSharedChild) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.link),
              label: const Text('Asignar dispositivo'),
              onPressed: () async {
                await context.pushNamed(
                  'device-create',
                  pathParameters: {'id': child.id.toString()},
                  extra: child.fullName,
                );
                if (context.mounted) {
                  context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Activo' : 'Inactivo',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final color = level > 50 
        ? Colors.green 
        : level > 20 
            ? Colors.orange 
            : Colors.red;
    final icon = level > 50 
        ? LucideIcons.batteryFull 
        : level > 20 
            ? LucideIcons.batteryMedium 
            : LucideIcons.batteryLow;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.baby,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin niños registrados',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra a tu primer niño para comenzar a monitorear su ubicación',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin resultados',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron niños con "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Funciones helper privadas a nivel de archivo
bool _hasCoordinates(ChildModel child) {
  final lat = child.device?.lastLatitude;
  final lng = child.device?.lastLongitude;
  return lat != null && lng != null;
}

bool _hasRecentLocation(ChildModel child) {
  if (!_hasCoordinates(child)) return false;
  final lastSeen = child.device?.lastSeen;
  if (lastSeen == null) return false;
  // Consideramos "reciente" si es menos de 10 minutos
  return DateTime.now().difference(lastSeen).inMinutes < 10;
}

