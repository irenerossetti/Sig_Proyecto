import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? token;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.token,
    this.user,
    this.errorMessage,
  });

  factory AuthState.unknown() => const AuthState(status: AuthStatus.unknown);

  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);

  factory AuthState.authenticating() => const AuthState(status: AuthStatus.authenticating);

  factory AuthState.authenticated({
    required String token,
    User? user,
  }) => AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
      );

  factory AuthState.error(String message) => AuthState(
        status: AuthStatus.error,
        errorMessage: message,
      );

  @override
  List<Object?> get props => [status, token, user, errorMessage];
}
