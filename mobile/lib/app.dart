import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_router.dart';
import 'core/config/app_theme.dart';
import 'core/config/theme_cubit.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

class GeoGuardApp extends StatefulWidget {
  const GeoGuardApp({super.key});

  @override
  State<GeoGuardApp> createState() => _GeoGuardAppState();
}

class _GeoGuardAppState extends State<GeoGuardApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(context.read<AuthBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp.router(
          title: 'GeoGuard',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: _appRouter.router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

