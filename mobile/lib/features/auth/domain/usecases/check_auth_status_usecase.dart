import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class CheckAuthStatusUseCase {
  final IAuthRepository repository;

  CheckAuthStatusUseCase(this.repository);

  Future<User?> call() async {
    final token = await repository.getToken();
    if (token != null && token.isNotEmpty) {
      return await repository.getCurrentUser();
    }
    return null;
  }
  
  Future<String?> getToken() {
    return repository.getToken();
  }
}
