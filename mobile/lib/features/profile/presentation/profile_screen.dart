import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';
import '../../auth/presentation/bloc/auth_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;

        if (state.status != AuthStatus.authenticated) {
          return _EmptyProfileState(
            padding: padding,
            message: 'Inicie sesión para ver su perfil.',
            onLogout: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          );
        }

        if (user == null) {
          return _EmptyProfileState(
            padding: padding,
            message: 'No pudimos recuperar los datos del perfil. Inicie sesión nuevamente.',
            onLogout: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);

        return ListView(
          padding: padding ?? const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            // Profile header (sin fondo de card)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                        ? Text(
                            user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : '?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.mail, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (user.phone != null && user.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.phone, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          user.phone!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account section
            _SectionHeader(title: 'Cuenta', icon: LucideIcons.user),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: LucideIcons.keyRound,
                    title: 'Cambiar contraseña',
                    subtitle: 'Actualiza tu contraseña de acceso',
                    onTap: () => context.push('/home/change-password', extra: state.token),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                    icon: LucideIcons.userPen,
                    title: 'Editar perfil',
                    subtitle: 'Modifica tus datos personales',
                    onTap: () => context.push('/home/edit-profile', extra: {
                      'user': user,
                      'token': state.token,
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Configuration section
            _SectionHeader(title: 'Configuración', icon: LucideIcons.settings),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: LucideIcons.bell,
                    title: 'Notificaciones',
                    subtitle: 'Configura las alertas que recibes',
                    onTap: () => context.push('/home/notifications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Support section
            _SectionHeader(title: 'Soporte', icon: LucideIcons.headset),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: LucideIcons.info,
                    title: 'Ayuda',
                    subtitle: 'Preguntas frecuentes y contacto',
                    onTap: () => context.push('/home/help'),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                    icon: LucideIcons.messageSquare,
                    title: 'Enviar comentarios',
                    subtitle: 'Ayúdanos a mejorar la app',
                    onTap: () => _showFeedbackDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout button
            FilledButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Cerrar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Version info
            Center(
              child: Text(
                'GeoGuard v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar comentarios'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe tus comentarios o sugerencias...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Gracias por tus comentarios!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState({
    this.padding,
    required this.message,
    required this.onLogout,
  });

  final EdgeInsetsGeometry? padding;
  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

