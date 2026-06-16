import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({required String email, required String password});
  Future<AuthResponseModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });
  Future<void> logout(String token);
  Future<void> requestPasswordReset(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.login);
    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AuthResponseModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractError(response, fallback: 'Error al iniciar sesión'));
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.register);
    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AuthResponseModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractError(response, fallback: 'Error al registrarse'));
    }
  }

  @override
  Future<void> logout(String token) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.logout);
    await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Note: Add '/password-reset/' to ApiConstants or hardcode here for now
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/auth/password-reset/');
    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractError(response, fallback: 'Error al solicitar restablecimiento'));
    }
  }

  String _extractError(http.Response response, {required String fallback}) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['error'] != null) return json['error'].toString();
      if (json['detail'] != null) return json['detail'].toString();
      if (json['message'] != null) return json['message'].toString();
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

class AuthResponseModel {
  final String token;
  final UserModel? user;

  AuthResponseModel({required this.token, this.user});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    if (token == null) throw Exception('Token missing in response');
    
    final userJson = json['user'];
    final user = userJson is Map<String, dynamic> ? UserModel.fromJson(userJson) : null;
    
    return AuthResponseModel(token: token, user: user);
  }
}
