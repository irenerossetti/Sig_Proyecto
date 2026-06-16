import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'core/config/theme_cubit.dart';
import 'core/services/notification_service.dart';
import 'core/services/image_cache_service.dart';
import 'core/services/api_cache_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/monitoring/presentation/bloc/alerts_bloc.dart';
import 'features/monitoring/presentation/bloc/children_bloc.dart';
import 'features/monitoring/presentation/bloc/map_bloc.dart';
import 'features/monitoring/presentation/bloc/safe_zone_bloc.dart';
import 'features/groups/presentation/bloc/groups_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Inicializar servicios en paralelo para arranque más rápido
  await Future.wait([
    NotificationService().initialize(),
    MapImageCacheService().initialize(),
    ApiCacheService().initialize(),
  ]);
  
  await di.init();
  
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<ThemeCubit>()),
        BlocProvider(create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequested())),
        BlocProvider(create: (_) => di.sl<ChildrenBloc>()),
        BlocProvider(create: (_) => di.sl<AlertsBloc>()),
        BlocProvider(create: (_) => di.sl<MapBloc>()),
        BlocProvider(create: (_) => di.sl<SafeZoneBloc>()),
        BlocProvider(create: (_) => di.sl<GroupsBloc>()),
      ],
      child: const GeoGuardApp(),
    ),
  );
}

