import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final IAuthRepository repository;

  RegisterUseCase(this.repository);

  Future<User?> call({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) {
    return repository.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
    );
  }
}
