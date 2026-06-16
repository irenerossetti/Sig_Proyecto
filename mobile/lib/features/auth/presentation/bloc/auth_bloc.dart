import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/check_auth_status_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final CheckAuthStatusUseCase _checkAuthStatusUseCase;
  final WebSocketService _webSocketService = WebSocketService();

  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required CheckAuthStatusUseCase checkAuthStatusUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _checkAuthStatusUseCase = checkAuthStatusUseCase,
        super(AuthState.unknown()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _checkAuthStatusUseCase();
    final token = await _checkAuthStatusUseCase.getToken();
    
    if (user != null && token != null) {
      emit(AuthState.authenticated(token: token, user: user));
      // Conectar WebSocket automáticamente
      _webSocketService.connect(token);
      // Registrar token FCM si el usuario ya está autenticado
      _registerFcmToken(token);
    } else {
      emit(AuthState.unauthenticated());
    }
  }

  /// Registra el token FCM en el backend
  Future<void> _registerFcmToken(String authToken) async {
    try {
      final fcmToken = await NotificationService().getToken();
      if (fcmToken == null) {
        debugPrint('❌ FCM Token is null, skipping registration');
        return;
      }

      debugPrint('📱 FCM Token obtained: ${fcmToken.substring(0, 30)}...');
      debugPrint('🔗 Registering FCM token to: ${ApiConstants.baseUrl}/api/auth/fcm-token/');
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/auth/fcm-token/');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ FCM token registered successfully!');
      } else {
        debugPrint('❌ FCM token registration failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.authenticating());
    try {
      final user = await _loginUseCase(email: event.email, password: event.password);
      final token = await _checkAuthStatusUseCase.getToken(); // Token is cached by repo
      if (token != null) {
        emit(AuthState.authenticated(token: token, user: user));
        // Conectar WebSocket después del login exitoso
        _webSocketService.connect(token);
        // Registrar token FCM después del login
        _registerFcmToken(token);
      } else {
        emit(AuthState.error('Error al obtener el token.'));
      }
    } catch (e) {
      emit(AuthState.error(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.authenticating());
    try {
      final user = await _registerUseCase(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
        phone: event.phone,
      );
      final token = await _checkAuthStatusUseCase.getToken();
      if (token != null) {
        emit(AuthState.authenticated(token: token, user: user));
        // Conectar WebSocket después del registro exitoso
        _webSocketService.connect(token);
        // Registrar token FCM después del registro
        _registerFcmToken(token);
      } else {
        emit(AuthState.error('Error al obtener el token.'));
      }
    } catch (e) {
      emit(AuthState.error(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Desconectar WebSocket antes del logout
    _webSocketService.disconnect();
    await _logoutUseCase();
    emit(AuthState.unauthenticated());
  }

  void _onAuthUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) {
    if (state.status == AuthStatus.authenticated && state.user != null) {
      final updatedUser = User(
        id: state.user!.id,
        fullName: event.fullName,
        email: state.user!.email,
        phone: event.phone,
        photoUrl: event.photoUrl ?? state.user!.photoUrl,
      );
      emit(AuthState.authenticated(
        token: state.token!,
        user: updatedUser,
      ));
    }
  }
}
