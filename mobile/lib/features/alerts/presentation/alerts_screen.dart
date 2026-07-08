import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../monitoring/presentation/bloc/alerts_bloc.dart';
import '../../monitoring/domain/monitoring_models.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/utils/ui_utils.dart' as ui_utils;

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Alertas'),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                onPressed: () => context.read<AlertsBloc>().add(AlertsFetchRequested()),
              ),
            ],
          ),
          body: const AlertsListView(padding: EdgeInsets.all(16)),
        );
      },
    );
  }
}

class AlertsListView extends StatelessWidget {
  const AlertsListView({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, state) {
        if (state is AlertsLoaded) {
          if (state.alerts.isEmpty) {
            return _RefreshableAlertsList(
              padding: padding,
              onRefresh: () async => context.read<AlertsBloc>().add(AlertsFetchRequested()),
              child: const _EmptyAlerts(),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<AlertsBloc>().add(AlertsFetchRequested()),
            child: ListView.separated(
              padding: padding,
              itemBuilder: (context, index) => _AlertTile(alert: state.alerts[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: state.alerts.length,
            ),
          );
        } else if (state is AlertsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is AlertsError) {
          return _RefreshableAlertsList(
            padding: padding,
            onRefresh: () async => context.read<AlertsBloc>().add(AlertsFetchRequested()),
            child: Center(child: Text(state.message, textAlign: TextAlign.center)),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _RefreshableAlertsList extends StatelessWidget {
  const _RefreshableAlertsList({
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

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final AlertModel alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ui_utils.alertStatusColor(alert.status);
    
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Redirigir a la pestaña del mapa interactivo centrado en el niño
          context.go('/home?tab=3&childId=${alert.childId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.bell, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.childName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          date_utils.relativeTime(alert.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: alert.status, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDIENTE';
      case 'resolved':
        return 'RESUELTA';
      case 'acknowledged':
        return 'RECONOCIDA';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _translateStatus(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleCheck, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No tienes alertas pendientes.'),
        ],
      ),
    );
  }
}
