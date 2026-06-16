import '../entities/user.dart';

abstract class IAuthRepository {
  Future<User?> login({required String email, required String password});
  Future<User?> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
  Future<User?> getCurrentUser();
  Future<String?> getToken();
}
