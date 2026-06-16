import '../repositories/auth_repository.dart';

class RequestPasswordResetUseCase {
  final IAuthRepository repository;

  RequestPasswordResetUseCase(this.repository);

  Future<void> call(String email) {
    return repository.requestPasswordReset(email);
  }
}
