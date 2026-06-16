import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/children/presentation/children_list_screen.dart';
import '../../features/children/presentation/child_form_screen.dart';
import '../../features/children/presentation/child_detail_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/monitoring/domain/monitoring_models.dart';
import '../../features/monitoring/presentation/device_form_screen.dart';
import '../../features/monitoring/presentation/safe_zone_editor_screen.dart';
import '../../features/monitoring/presentation/safe_zones_list_screen.dart';
import '../../features/profile/presentation/change_password_screen.dart';
import '../../features/profile/presentation/notifications_settings_screen.dart';
import '../../features/profile/presentation/help_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/group_map_screen.dart';
import '../../features/groups/presentation/group_form_screen.dart';
import '../../features/groups/presentation/group_safe_zone_editor_screen.dart';
import '../../features/groups/domain/group_models.dart';
import '../../features/auth/domain/entities/user.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter(this.authBloc);

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: RouterRefreshStream(authBloc.stream),
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const MaterialPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => const MaterialPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => const MaterialPage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) {
          // Soporte para query parameters: ?tab=3&childId=1
          final tabParam = state.uri.queryParameters['tab'];
          final childIdParam = state.uri.queryParameters['childId'];
          final initialTab = tabParam != null ? int.tryParse(tabParam) : null;
          final initialChildId = childIdParam != null ? int.tryParse(childIdParam) : null;
          
          // Usar key única para forzar recreación cuando hay parámetros
          final key = initialTab != null || initialChildId != null
              ? ValueKey('home_${initialTab}_$initialChildId')
              : null;
          
          return MaterialPage(
            key: key,
            child: HomeScreen(
              initialTab: initialTab,
              initialChildId: initialChildId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'children',
            name: 'children',
            pageBuilder: (context, state) => const MaterialPage(child: ChildrenListScreen()),
          ),
          GoRoute(
            path: 'children/new',
            name: 'child-create',
            pageBuilder: (context, state) => const MaterialPage(child: ChildFormScreen()),
          ),
          GoRoute(
            path: 'children/:id/detail',
            name: 'child-detail',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final childId = int.tryParse(idParam ?? '');
              if (childId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final initialChild = state.extra is ChildModel ? state.extra as ChildModel : null;
              return MaterialPage(
                child: ChildDetailScreen(
                  childId: childId,
                  initialChild: initialChild,
                ),
              );
            },
          ),
          GoRoute(
            path: 'children/:id/edit',
            name: 'child-edit',
            pageBuilder: (context, state) {
              final child = state.extra is ChildModel ? state.extra as ChildModel : null;
              return MaterialPage(
                child: ChildFormScreen(child: child),
              );
            },
          ),
          GoRoute(
            path: 'alerts',
            name: 'alerts',
            pageBuilder: (context, state) => const MaterialPage(child: AlertsScreen()),
          ),
          GoRoute(
            path: 'children/:id/device',
            name: 'device-create',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final childId = int.tryParse(idParam ?? '');
              if (childId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final childName = state.extra is String ? state.extra as String : 'Niño';
              return MaterialPage(
                child: DeviceFormScreen(
                  childId: childId,
                  childName: childName,
                ),
              );
            },
          ),
          GoRoute(
            path: 'children/:id/safe-zones',
            name: 'safe-zones-list',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final childId = int.tryParse(idParam ?? '');
              if (childId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final extra = state.extra as Map<String, dynamic>?;
              final childName = extra?['childName'] as String? ?? 'Niño';
              final childLocation = extra?['location'] as LatLng?;
              return MaterialPage(
                child: SafeZonesListScreen(
                  childId: childId,
                  childName: childName,
                  childLocation: childLocation,
                ),
              );
            },
          ),
          GoRoute(
            path: 'children/:id/safe-zone',
            name: 'safe-zone-create',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final childId = int.tryParse(idParam ?? '');
              if (childId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final extra = state.extra as Map<String, dynamic>?;
              final childName = extra?['childName'] as String? ?? 'Niño';
              final initialLocation = extra?['location'] as LatLng?;
              return MaterialPage(
                child: SafeZoneEditorScreen(
                  childId: childId,
                  childName: childName,
                  initialLocation: initialLocation,
                ),
              );
            },
          ),
          GoRoute(
            path: 'safe-zones/:id/edit',
            name: 'safe-zone-edit',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final zone = extra?['zone'] as SafeZoneModel?;
              final childName = extra?['childName'] as String? ?? 'Niño';
              if (zone == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              return MaterialPage(
                child: SafeZoneEditorScreen(
                  childId: zone.childId,
                  childName: childName,
                  existingZone: zone,
                ),
              );
            },
          ),
          GoRoute(
            path: 'safe-zone-editor',
            name: 'safe-zone-editor',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final childId = extra['childId'] as int;
              final childName = extra['childName'] as String? ?? 'Niño';
              final initialLocation = extra['initialLocation'] as LatLng?;
              final existingZone = extra['existingZone'] as SafeZoneModel?;
              return MaterialPage(
                child: SafeZoneEditorScreen(
                  childId: childId,
                  childName: childName,
                  initialLocation: initialLocation,
                  existingZone: existingZone,
                ),
              );
            },
          ),
          // Profile routes
          GoRoute(
            path: 'change-password',
            name: 'change-password',
            pageBuilder: (context, state) {
              final token = state.extra as String? ?? '';
              return MaterialPage(
                child: ChangePasswordScreen(token: token),
              );
            },
          ),
          GoRoute(
            path: 'notifications',
            name: 'notifications-settings',
            pageBuilder: (context, state) => const MaterialPage(
              child: NotificationsSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'help',
            name: 'help',
            pageBuilder: (context, state) => const MaterialPage(
              child: HelpScreen(),
            ),
          ),
          GoRoute(
            path: 'edit-profile',
            name: 'edit-profile',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final user = extra?['user'] as User?;
              final token = extra?['token'] as String? ?? '';
              if (user == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              return MaterialPage(
                child: EditProfileScreen(user: user, token: token),
              );
            },
          ),
          // Group routes
          GoRoute(
            path: 'groups',
            name: 'groups',
            pageBuilder: (context, state) => const MaterialPage(child: GroupsListScreen()),
          ),
          GoRoute(
            path: 'groups/new',
            name: 'group-create',
            pageBuilder: (context, state) => const MaterialPage(child: GroupFormScreen()),
          ),
          GoRoute(
            path: 'groups/:id/detail',
            name: 'group-detail',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final groupId = int.tryParse(idParam ?? '');
              if (groupId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              return MaterialPage(
                child: GroupDetailScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'groups/:id/edit',
            name: 'group-edit',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final group = extra?['group'];
              return MaterialPage(
                child: GroupFormScreen(group: group),
              );
            },
          ),
          GoRoute(
            path: 'groups/:id/map',
            name: 'group-map',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final groupId = int.tryParse(idParam ?? '');
              if (groupId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              return MaterialPage(
                child: GroupMapScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'groups/:id/safe-zone',
            name: 'group-safe-zone-editor',
            pageBuilder: (context, state) {
              final idParam = state.pathParameters['id'];
              final groupId = int.tryParse(idParam ?? '');
              if (groupId == null) {
                return const MaterialPage(child: _InvalidChildRoute());
              }
              final extra = state.extra as Map<String, dynamic>?;
              final groupName = extra?['groupName'] as String? ?? 'Grupo';
              final existingZone = extra?['existingZone'] as GroupSafeZoneModel?;
              return MaterialPage(
                child: GroupSafeZoneEditorScreen(
                  groupId: groupId,
                  groupName: groupName,
                  existingZone: existingZone,
                ),
              );
            },
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authStatus = authBloc.state.status;
      final authenticatingRoute = state.matchedLocation == '/login' || 
                                  state.matchedLocation == '/register' ||
                                  state.matchedLocation == '/forgot-password';
      final isAuthed = authStatus == AuthStatus.authenticated;

      if (!isAuthed && !authenticatingRoute) return '/login';
      if (isAuthed && authenticatingRoute) return '/home';
      return null;
    },
  );
}

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _InvalidChildRoute extends StatelessWidget {
  const _InvalidChildRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Ruta de niño inválida.'),
      ),
    );
  }
}

