import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheToken(String token);
  Future<String?> getToken();
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage storage;
  static const _tokenKey = 'geoguard_token';
  static const _userKey = 'geoguard_user';

  AuthLocalDataSourceImpl({required this.storage});

  @override
  Future<void> cacheToken(String token) async {
    await storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> getToken() async {
    return await storage.read(key: _tokenKey);
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    await storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  @override
  Future<UserModel?> getUser() async {
    final jsonStr = await storage.read(key: _userKey);
    if (jsonStr != null) {
      try {
        return UserModel.fromJson(jsonDecode(jsonStr));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> clearSession() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _userKey);
  }
}
