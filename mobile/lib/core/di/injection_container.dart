import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/check_auth_status_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/request_password_reset_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/forgot_password_cubit.dart';
import '../../features/monitoring/data/monitoring_repository.dart';
import '../../features/monitoring/presentation/bloc/children_bloc.dart';
import '../../features/monitoring/presentation/bloc/alerts_bloc.dart';
import '../../features/monitoring/presentation/bloc/map_bloc.dart';
import '../../features/monitoring/presentation/bloc/device_bloc.dart';
import '../../features/monitoring/presentation/bloc/safe_zone_bloc.dart';
import '../../features/children/presentation/bloc/child_form_bloc.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/presentation/bloc/groups_bloc.dart';
import '../../features/groups/presentation/bloc/group_detail_bloc.dart';
import '../config/theme_cubit.dart';

final sl = GetIt.instance;

/// Cliente HTTP optimizado con conexiones persistentes
http.Client _createOptimizedHttpClient() {
  // Usar el cliente estándar que mantiene conexiones abiertas por defecto
  // Flutter usa dart:io HttpClient internamente que soporta keep-alive
  return http.Client();
}

Future<void> init() async {
  // External - HTTP Client optimizado (singleton para reutilizar conexiones)
  sl.registerLazySingleton<http.Client>(_createOptimizedHttpClient);
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(storage: sl()),
  );

  // Repositories
  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton(() => MonitoringRepository(client: sl()));
  sl.registerLazySingleton(() => GroupRepository(client: sl()));

  // Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => CheckAuthStatusUseCase(sl()));
  sl.registerLazySingleton(() => RequestPasswordResetUseCase(sl()));

  // Blocs
  sl.registerLazySingleton(() => ThemeCubit());
  sl.registerLazySingleton(() => AuthBloc(
        loginUseCase: sl(),
        registerUseCase: sl(),
        logoutUseCase: sl(),
        checkAuthStatusUseCase: sl(),
      ));
  sl.registerFactory(() => ForgotPasswordCubit(sl()));
  sl.registerFactory(() => ChildrenBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => AlertsBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => MapBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => ChildFormBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => DeviceBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => SafeZoneBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => GroupsBloc(repo: sl(), authBloc: sl()));
  sl.registerFactory(() => GroupDetailBloc(repo: sl(), authBloc: sl()));
}
