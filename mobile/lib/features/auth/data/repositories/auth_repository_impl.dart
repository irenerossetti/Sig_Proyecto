import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<User?> login({required String email, required String password}) async {
    final response = await remoteDataSource.login(email: email, password: password);
    await localDataSource.cacheToken(response.token);
    if (response.user != null) {
      await localDataSource.cacheUser(response.user!);
    }
    return response.user;
  }

  @override
  Future<User?> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await remoteDataSource.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
    );
    await localDataSource.cacheToken(response.token);
    if (response.user != null) {
      await localDataSource.cacheUser(response.user!);
    }
    return response.user;
  }

  @override
  Future<void> logout() async {
    final token = await localDataSource.getToken();
    if (token != null) {
      try {
        await remoteDataSource.logout(token);
      } catch (_) {
        // Ignore logout errors
      }
    }
    await localDataSource.clearSession();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await remoteDataSource.requestPasswordReset(email);
  }

  @override
  Future<User?> getCurrentUser() async {
    return await localDataSource.getUser();
  }

  @override
  Future<String?> getToken() async {
    return await localDataSource.getToken();
  }
}
