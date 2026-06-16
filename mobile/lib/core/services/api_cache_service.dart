import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de caché para respuestas de API
/// Implementa una estrategia stale-while-revalidate para mejor UX
class ApiCacheService {
  static final ApiCacheService _instance = ApiCacheService._internal();
  factory ApiCacheService() => _instance;
  ApiCacheService._internal();

  SharedPreferences? _prefs;
  static const String _cachePrefix = 'api_cache_';
  static const String _timestampPrefix = 'api_cache_ts_';
  
  /// Tiempos de expiración por tipo de datos (en segundos)
  static const Map<String, int> _ttl = {
    'children': 60, // 1 minuto - datos que cambian frecuentemente
    'alerts': 30, // 30 segundos - alertas críticas
    'safe_zones': 300, // 5 minutos - zonas seguras cambian poco
    'devices': 120, // 2 minutos
    'profile': 600, // 10 minutos - perfil cambia raramente
  };

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Obtener datos del caché si no han expirado
  Future<T?> get<T>(String key, {String? category}) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    
    final cached = _prefs?.getString(cacheKey);
    final timestamp = _prefs?.getInt(timestampKey);
    
    if (cached == null || timestamp == null) return null;
    
    // Verificar si el caché ha expirado
    final ttl = _ttl[category] ?? 120; // Default 2 minutos
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (now - timestamp > ttl) {
      // Caché expirado, pero aún retornamos el valor para stale-while-revalidate
      debugPrint('Cache STALE for $key');
      return null;
    }
    
    try {
      return jsonDecode(cached) as T;
    } catch (e) {
      debugPrint('Error decoding cache for $key: $e');
      return null;
    }
  }

  /// Obtener datos del caché incluso si están expirados (para stale-while-revalidate)
  Future<T?> getStale<T>(String key) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final cached = _prefs?.getString(cacheKey);
    
    if (cached == null) return null;
    
    try {
      return jsonDecode(cached) as T;
    } catch (e) {
      return null;
    }
  }

  /// Guardar datos en el caché
  Future<void> set(String key, dynamic data) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    try {
      await _prefs?.setString(cacheKey, jsonEncode(data));
      await _prefs?.setInt(timestampKey, now);
    } catch (e) {
      debugPrint('Error saving cache for $key: $e');
    }
  }

  /// Invalidar una entrada específica del caché
  Future<void> invalidate(String key) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix$key';
    final timestampKey = '$_timestampPrefix$key';
    
    await _prefs?.remove(cacheKey);
    await _prefs?.remove(timestampKey);
  }

  /// Invalidar todo el caché de una categoría
  Future<void> invalidateCategory(String category) async {
    await initialize();
    
    final allKeys = _prefs?.getKeys() ?? <String>{};
    final keys = allKeys.where(
      (key) => key.startsWith('$_cachePrefix$category'),
    );
    
    for (final key in keys) {
      await _prefs?.remove(key);
      await _prefs?.remove(key.replaceFirst(_cachePrefix, _timestampPrefix));
    }
  }

  /// Limpiar todo el caché
  Future<void> clearAll() async {
    await initialize();
    
    final allKeys = _prefs?.getKeys() ?? <String>{};
    final keys = allKeys.where(
      (key) => key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix),
    );
    
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }
}

/// Extensión para el repository con soporte de caché
mixin CacheableMixin {
  final ApiCacheService _cache = ApiCacheService();

  /// Ejecutar con estrategia stale-while-revalidate
  Future<T> withCache<T>({
    required String key,
    required String category,
    required Future<T> Function() fetch,
    required T Function(dynamic json) fromJson,
    required dynamic Function(T data) toJson,
  }) async {
    // 1. Intentar obtener del caché
    final cached = await _cache.get<dynamic>(key, category: category);
    
    if (cached != null) {
      debugPrint('Cache HIT for $key');
      // Refrescar en background
      _refreshInBackground(key, fetch, toJson);
      return fromJson(cached);
    }
    
    // 2. Si no hay caché, intentar obtener stale
    final stale = await _cache.getStale<dynamic>(key);
    
    if (stale != null) {
      debugPrint('Cache STALE-HIT for $key');
      // Refrescar en background y retornar stale
      _refreshInBackground(key, fetch, toJson);
      return fromJson(stale);
    }
    
    // 3. No hay nada en caché, fetch obligatorio
    debugPrint('Cache MISS for $key');
    final fresh = await fetch();
    await _cache.set(key, toJson(fresh));
    return fresh;
  }

  void _refreshInBackground<T>(
    String key,
    Future<T> Function() fetch,
    dynamic Function(T data) toJson,
  ) {
    // Fire and forget
    fetch().then((fresh) {
      _cache.set(key, toJson(fresh));
    }).catchError((e) {
      debugPrint('Background refresh failed for $key: $e');
    });
  }
}
