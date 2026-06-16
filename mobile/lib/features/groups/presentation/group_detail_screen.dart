import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection_container.dart' as di;
import 'bloc/group_detail_bloc.dart';
import 'bloc/groups_bloc.dart';
import '../domain/group_models.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';
import '../../monitoring/presentation/bloc/alerts_bloc.dart';
import '../../monitoring/presentation/bloc/map_bloc.dart';
import 'group_safe_zone_editor_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          di.sl<GroupDetailBloc>()..add(GroupDetailLoadRequested(groupId)),
      child: _GroupDetailView(groupId: groupId),
    );
  }
}

class _GroupDetailView extends StatelessWidget {
  const _GroupDetailView({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupDetailBloc, GroupDetailState>(
      listener: (context, state) {
        if (state is GroupDetailActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          // Refrescar todos los tabs principales cuando se modifica un grupo
          // Usamos di.sl para garantizar acceso a las instancias singleton
          // IMPORTANTE: forceRefresh=true para omitir la caché

          // Tab de niños - forzar actualización sin caché
          di.sl<ChildrenBloc>().add(
            const ChildrenFetchRequested(forceRefresh: true),
          );
          // Tab de grupos - forzar actualización sin caché
          di.sl<GroupsBloc>().add(
            const GroupsFetchRequested(forceRefresh: true),
          );
          // Alertas
          di.sl<AlertsBloc>().add(AlertsFetchRequested());
          // Mapa - refrescar datos del niño seleccionado
          di.sl<MapBloc>().add(const MapRefreshChild());
        } else if (state is GroupDetailDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          // Refrescar lista de grupos y navegar atrás
          di.sl<GroupsBloc>().add(
            const GroupsFetchRequested(forceRefresh: true),
          );
          context.pop();
        } else if (state is GroupDetailError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is GroupDetailLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cargando...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        ChildGroupModel? group;
        if (state is GroupDetailLoaded) {
          group = state.group;
        } else if (state is GroupDetailActionLoading) {
          group = state.group;
        } else if (state is GroupDetailActionSuccess) {
          group = state.group;
        }

        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No se pudo cargar el grupo')),
          );
        }

        final groupColor = _parseColor(group.color);
        final currentUserId = context.read<AuthBloc>().state.user?.id ?? 0;
        final isOwner = group.ownerId == currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.mapPin),
                tooltip: 'Ver mapa',
                onPressed: () => context.pushNamed(
                  'group-map',
                  pathParameters: {'id': groupId.toString()},
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                tooltip: 'Actualizar',
                onPressed: () {
                  context.read<GroupDetailBloc>().add(
                    GroupDetailLoadRequested(groupId),
                  );
                },
              ),
              if (isOwner)
                IconButton(
                  icon: Icon(
                    LucideIcons.trash2,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Eliminar grupo',
                  onPressed: () => _confirmDeleteGroup(context, group!),
                ),
            ],
          ),
          body: state is GroupDetailActionLoading
              ? Stack(
                  children: [
                    _GroupDetailBody(
                      group: group,
                      groupColor: groupColor,
                      currentUserId: currentUserId,
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(state.action),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _GroupDetailBody(
                  group: group,
                  groupColor: groupColor,
                  currentUserId: currentUserId,
                ),
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, ChildGroupModel group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Estás seguro de eliminar el grupo "${group.name}"?\n\n'
          'Se eliminarán todas las zonas seguras del grupo y los tutores perderán acceso. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GroupDetailBloc>().add(
                const GroupDetailDeleteGroup(),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailBody extends StatelessWidget {
  const _GroupDetailBody({
    required this.group,
    required this.groupColor,
    required this.currentUserId,
  });

  final ChildGroupModel group;
  final Color groupColor;
  final int currentUserId;

  /// El usuario puede editar si es owner o admin
  bool get canEdit => group.canEdit(currentUserId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userRole = group.getUserRole(currentUserId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  groupColor.withValues(alpha: 0.15),
                  groupColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: groupColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.users,
                        color: groupColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (group.description != null &&
                              group.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                group.description!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatChip(
                      icon: LucideIcons.baby,
                      label:
                          '${group.membersCount} niño${group.membersCount == 1 ? '' : 's'}',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: LucideIcons.userCheck,
                      label:
                          '${group.tutorsCount} tutor${group.tutorsCount == 1 ? '' : 'es'}',
                      color: colorScheme.secondary,
                    ),
                  ],
                ),
                // Mostrar rol del usuario actual
                if (userRole != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: userRole == 'owner'
                          ? Colors.amber.withValues(alpha: 0.2)
                          : userRole == 'admin'
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userRole == 'owner'
                          ? '👑 Eres el dueño'
                          : userRole == 'admin'
                          ? '🛡️ Administrador'
                          : '👁️ Solo lectura',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: userRole == 'owner'
                            ? Colors.amber.shade800
                            : userRole == 'admin'
                            ? Colors.blue.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Members section
        _SectionHeader(
          icon: LucideIcons.baby,
          title: 'Niños del grupo',
          action: canEdit
              ? TextButton.icon(
                  onPressed: () => _showAddChildDialog(context),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Agregar'),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (group.memberships == null || group.memberships!.isEmpty)
          _EmptySection(
            icon: LucideIcons.baby,
            message: 'No hay niños en este grupo',
            action: canEdit
                ? 'Agrega niños para monitorearlos'
                : 'Sin niños registrados',
          )
        else
          ...group.memberships!.map(
            (m) => _MembershipCard(
              membership: m,
              canRemove: canEdit,
              onRemove: canEdit
                  ? () {
                      context.read<GroupDetailBloc>().add(
                        GroupDetailRemoveChild(m.childId),
                      );
                    }
                  : null,
            ),
          ),

        const SizedBox(height: 24),

        // Tutors section - Solo el owner puede invitar co-tutores
        _SectionHeader(
          icon: LucideIcons.userCheck,
          title: 'Co-tutores',
          action: group.isOwner(currentUserId)
              ? TextButton.icon(
                  onPressed: () => _showInviteTutorDialog(context),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: const Text('Invitar'),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (group.tutors == null || group.tutors!.isEmpty)
          _EmptySection(
            icon: LucideIcons.userCheck,
            message: 'Sin co-tutores',
            action: group.isOwner(currentUserId)
                ? 'Invita a otros para que ayuden a monitorear'
                : 'No hay co-tutores en este grupo',
          )
        else
          ...group.tutors!.map(
            (t) => _TutorCard(
              tutor: t,
              canRemove: group.isOwner(currentUserId),
              onRemove: group.isOwner(currentUserId)
                  ? () {
                      context.read<GroupDetailBloc>().add(
                        GroupDetailRemoveTutor(t.tutorId),
                      );
                    }
                  : null,
            ),
          ),

        const SizedBox(height: 24),

        // Safe zones section
        _SectionHeader(
          icon: LucideIcons.shield,
          title: 'Zonas seguras del grupo',
          action: canEdit
              ? TextButton.icon(
                  onPressed: () => _navigateToZoneEditor(context),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Crear'),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (group.safeZones == null || group.safeZones!.isEmpty)
          _EmptySection(
            icon: LucideIcons.shield,
            message: 'Sin zonas seguras de grupo',
            action: canEdit
                ? 'Crea una zona para aplicar a todos los niños'
                : 'No hay zonas seguras configuradas',
          )
        else
          ...group.safeZones!.map(
            (z) => _SafeZoneCard(
              zone: z,
              onTap: canEdit ? () => _navigateToZoneEditor(context, z) : null,
              onDelete: canEdit ? () => _confirmDeleteZone(context, z) : null,
              onToggle: canEdit ? () => _toggleZone(context, z) : null,
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _showAddChildDialog(BuildContext context) {
    // Get children from the ChildrenBloc
    final childrenState = context.read<ChildrenBloc>().state;

    if (childrenState is! ChildrenLoaded || childrenState.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra niños en tu cuenta')),
      );
      return;
    }

    // Filter out children already in the group
    final existingChildIds =
        group.memberships?.map((m) => m.childId).toSet() ?? {};
    final availableChildren = childrenState.children
        .where((c) => !existingChildIds.contains(c.id))
        .toList();

    if (availableChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos tus niños ya están en este grupo')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Selecciona un niño',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...availableChildren.map(
              (child) => ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      child.photoUrl != null && child.photoUrl!.isNotEmpty
                      ? NetworkImage(child.photoUrl!)
                      : null,
                  child: child.photoUrl == null || child.photoUrl!.isEmpty
                      ? Text(child.fullName.substring(0, 1).toUpperCase())
                      : null,
                ),
                title: Text(child.fullName),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  context.read<GroupDetailBloc>().add(
                    GroupDetailAddChild(child.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showInviteTutorDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'monitor';
    final bloc = context
        .read<GroupDetailBloc>(); // Obtener el bloc antes del diálogo

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                LucideIcons.userPlus,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Invitar co-tutor'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email del tutor',
                  hintText: 'usuario@email.com',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(LucideIcons.shield),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'monitor',
                    child: Text('Monitor (solo ver)'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (emailController.text.trim().isEmpty) {
                  return;
                }
                bloc.add(
                  GroupDetailInviteTutor(
                    email: emailController.text.trim(),
                    role: selectedRole,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Invitar'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToZoneEditor(
    BuildContext context, [
    GroupSafeZoneModel? existingZone,
  ]) {
    final bloc = context.read<GroupDetailBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: GroupSafeZoneEditorScreen(
            groupId: group.id,
            groupName: group.name,
            existingZone: existingZone,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteZone(BuildContext context, GroupSafeZoneModel zone) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar zona segura'),
        content: Text(
          '¿Estás seguro de eliminar la zona "${zone.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GroupDetailBloc>().add(
                GroupDetailDeleteSafeZone(zone.id),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _toggleZone(BuildContext context, GroupSafeZoneModel zone) {
    context.read<GroupDetailBloc>().add(
      GroupDetailToggleSafeZone(zoneId: zone.id, isActive: !zone.isActive),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String message;
  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            action,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    this.canRemove = true,
    this.onRemove,
  });

  final GroupMembershipModel membership;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage:
              membership.childPhoto != null && membership.childPhoto!.isNotEmpty
              ? NetworkImage(membership.childPhoto!)
              : null,
          child: membership.childPhoto == null || membership.childPhoto!.isEmpty
              ? Text(
                  membership.childName?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                )
              : null,
        ),
        title: Text(membership.childName ?? 'Niño'),
        subtitle: membership.addedByName != null
            ? Text(
                'Agregado por ${membership.addedByName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: canRemove
            ? IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  color: colorScheme.error,
                  size: 20,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Remover del grupo'),
                      content: Text(
                        '¿Remover a ${membership.childName} del grupo?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            onRemove?.call();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                          ),
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.tutor, this.canRemove = true, this.onRemove});

  final GroupTutorModel tutor;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tutor.isAdmin
              ? Colors.amber.withValues(alpha: 0.2)
              : colorScheme.secondaryContainer,
          child: Icon(
            tutor.isAdmin ? LucideIcons.crown : LucideIcons.user,
            color: tutor.isAdmin
                ? Colors.amber
                : colorScheme.onSecondaryContainer,
            size: 20,
          ),
        ),
        title: Text(tutor.tutorName ?? tutor.tutorEmail ?? 'Tutor'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tutor.tutorEmail != null)
              Text(
                tutor.tutorEmail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tutor.isAdmin
                    ? Colors.amber.withValues(alpha: 0.2)
                    : colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tutor.isAdmin ? 'Administrador' : 'Monitor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tutor.isAdmin
                      ? Colors.amber.shade700
                      : colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: tutor.tutorEmail != null,
        trailing: canRemove
            ? IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  color: colorScheme.error,
                  size: 20,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Remover tutor'),
                      content: Text(
                        '¿Remover a ${tutor.tutorName ?? tutor.tutorEmail} del grupo?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            onRemove?.call();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                          ),
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}

class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({
    required this.zone,
    this.onTap,
    this.onDelete,
    this.onToggle,
  });

  final GroupSafeZoneModel zone;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final zoneColor = _parseColor(zone.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: zoneColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            zone.zoneType == 'circle'
                ? LucideIcons.circle
                : LucideIcons.pentagon,
            color: zoneColor,
            size: 20,
          ),
        ),
        title: Text(zone.name),
        subtitle: Text(
          zone.zoneType == 'circle'
              ? 'Radio: ${zone.radiusMeters ?? 100}m'
              : '${zone.polygonPoints.length} puntos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              zone.isActive ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              color: zone.isActive ? Colors.green : colorScheme.outline,
              size: 20,
            ),
            if (onToggle != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  zone.isActive ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: colorScheme.primary,
                ),
                tooltip: zone.isActive ? 'Desactivar' : 'Activar',
                onPressed: onToggle,
              ),
            ],
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: colorScheme.error,
                ),
                tooltip: 'Eliminar zona',
                onPressed: onDelete,
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: colorScheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hexColor) {
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.blue;
  }
}
