import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api_constants.dart';

/// Servicio de rastreo en segundo plano
class BackgroundTrackingService {
  static const String notificationChannelId = 'geoguard_tracking';
  static const String notificationChannelName = 'Rastreo GeoGuard';
  static const int notificationId = 888;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Inicializar el servicio
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configurar notificaciones
    await _initializeNotifications();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'GeoGuard Tracker',
        initialNotificationContent: 'Preparando rastreo...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);

    // Crear canal de notificación para Android 8+
    const androidChannel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: 'Notificaciones del servicio de rastreo GPS',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Iniciar el servicio de rastreo
  static Future<bool> startService(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_device_id', deviceId);
    await prefs.setBool('tracking_enabled', true);

    final service = FlutterBackgroundService();
    return await service.startService();
  }

  /// Detener el servicio
  static Future<void> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tracking_enabled', false);
    
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  /// Verificar si el servicio está corriendo
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
  
  /// Alias para compatibilidad
  static Future<bool> isServiceRunning() async {
    return await isRunning();
  }
}

// Callback para iOS en background
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Entry point del servicio en background
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString('tracking_device_id');

  if (deviceId == null || deviceId.isEmpty) {
    debugPrint('❌ No device_id configurado, deteniendo servicio');
    service.stopSelf();
    return;
  }

  debugPrint('🚀 Servicio de rastreo iniciado para device: $deviceId');

  // Crear tracker en background
  final tracker = _BackgroundTracker(
    service: service,
    deviceId: deviceId,
  );

  await tracker.start();

  // Escuchar comandos
  service.on('stop').listen((event) {
    debugPrint('🛑 Recibido comando de parada');
    tracker.stop();
    service.stopSelf();
  });

  // Escuchar solicitud de estado
  service.on('status').listen((event) {
    service.invoke('statusUpdate', {
      'isConnected': tracker.isConnected,
      'lastUpdate': tracker.lastUpdate?.toIso8601String(),
      'updateCount': tracker.updateCount,
    });
  });
}

/// Tracker que corre en el servicio de background
class _BackgroundTracker {
  final ServiceInstance service;
  final String deviceId;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final Battery _battery = Battery();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isRunning = false;
  String? _childName;
  DateTime? _lastUpdate;
  int _updateCount = 0;
  int _reconnectAttempts = 0;
  int? _lastBatteryLevel;
  DateTime? _lastBatteryCheck;

  bool get isConnected => _isConnected;
  DateTime? get lastUpdate => _lastUpdate;
  int get updateCount => _updateCount;

  _BackgroundTracker({
    required this.service,
    required this.deviceId,
  });

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Conectar WebSocket
    _connectWebSocket();

    // Iniciar GPS
    _startLocationStream();
  }

  void stop() {
    _isRunning = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _disconnectWebSocket();
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    // ULTRA-AGRESIVO estilo Uber - máxima velocidad en background
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // SIN FILTRO - cada cambio GPS
      intervalDuration: const Duration(milliseconds: 500), // 2 updates/segundo
      forceLocationManager: false, // Fused Location = más rápido
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _sendLocation(position.latitude, position.longitude);
      },
      onError: (error) {
        debugPrint('❌ GPS Error: $error');
        service.invoke('locationUpdate', {
          'success': false,
          'error': 'Error GPS: $error',
        });
      },
    );

    debugPrint('🛰️ GPS streaming ULTRA iniciado en background (500ms)');
  }

  void _connectWebSocket() {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    try {
      final baseUrl = ApiConstants.baseUrl;
      final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
      final host = baseUrl.replaceAll(RegExp(r'https?://'), '');
      final wsUrl = '$wsScheme://$host/ws/tracker/?device_id=$deviceId';

      debugPrint('🔌 [BG] Conectando WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('❌ [BG] Error WebSocket: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connection_established':
          _isConnecting = false;
          _isConnected = true;
          _reconnectAttempts = 0;
          _childName = data['child_name'] as String?;
          
          debugPrint('✅ [BG] Conectado: $_childName');
          _updateNotification('Rastreando: $_childName', 'Conexión activa');
          _startPingTimer();
          
          // Notificar a la UI
          service.invoke('connectionUpdate', {
            'connected': true,
            'childName': _childName,
          });
          break;

        case 'location_ack':
          final success = data['success'] as bool? ?? false;
          if (success) {
            _updateCount++;
            _lastUpdate = DateTime.now();
            _updateNotification(
              'Rastreando: ${_childName ?? deviceId}',
              'Última actualización: ${_formatTime(_lastUpdate!)} • $_updateCount envíos',
            );
          }
          break;

        case 'pong':
          break;

        case 'error':
          debugPrint('❌ [BG] Error servidor: ${data['message']}');
          break;
      }
    } catch (e) {
      debugPrint('❌ [BG] Error parseando: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('❌ [BG] WebSocket error: $error');
    service.invoke('connectionUpdate', {
      'connected': false,
      'error': 'Error de conexión: $error',
    });
    _handleDisconnection();
  }

  void _onDone() {
    debugPrint('🔌 [BG] WebSocket cerrado');
    
    // Verificar el código de cierre si está disponible
    final closeCode = _channel?.closeCode;
    String errorMsg = 'Conexión cerrada';
    
    if (closeCode != null) {
      switch (closeCode) {
        case 4002:
          errorMsg = 'Error: Device ID no proporcionado';
          break;
        case 4003:
          errorMsg = 'Error: Device ID no existe en el servidor';
          break;
        case 4000:
          errorMsg = 'Error del servidor';
          break;
        default:
          errorMsg = 'Conexión cerrada (código: $closeCode)';
      }
    }
    
    service.invoke('connectionUpdate', {
      'connected': false,
      'error': errorMsg,
    });
    
    _handleDisconnection();
  }

  void _handleDisconnection() {
    final wasConnected = _isConnected;
    _cleanup();

    if (wasConnected) {
      _updateNotification('GeoGuard Tracker', 'Reconectando...');
    }

    if (_isRunning) {
      _scheduleReconnect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          debugPrint('❌ [BG] Ping fallido: $e');
          _handleDisconnection();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (!_isRunning) return;
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= 100) {
      debugPrint('❌ [BG] Máximo de reintentos');
      _updateNotification('GeoGuard Tracker', 'Error de conexión - reintentos agotados');
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = (3 * (1 << (_reconnectAttempts - 1).clamp(0, 4))).clamp(3, 60);
    
    debugPrint('🔄 [BG] Reconectando en ${delaySeconds}s (intento $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isRunning && !_isConnected && !_isConnecting) {
        _connectWebSocket();
      }
    });
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    
    if (_channel != null) {
      try {
        // Cerrar sin código (el sink.close() sin args usa null internamente)
        // Esto evita el error "Invalid argument: 1001"
        _channel!.sink.close();
      } catch (e) {
        debugPrint('🔌 [BG] Error cerrando WebSocket: $e');
      }
      _channel = null;
    }
    
    _isConnected = false;
    _isConnecting = false;
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  Future<void> _sendLocation(double latitude, double longitude) async {
    if (!_isConnected || _channel == null) {
      return; // No guardar localmente - enviar cuando reconecte
    }

    await _updateBatteryAsync();

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'battery_level': _lastBatteryLevel,
      }));
      
      // Notificar UI sin esperar
      service.invoke('locationUpdate', {
        'success': true,
        'latitude': latitude,
        'longitude': longitude,
        'battery': _lastBatteryLevel,
      });
    } catch (e) {
      debugPrint('❌ [BG] Error enviando: $e');
      _handleDisconnection();
    }
  }

  Future<void> _updateBatteryAsync() async {
    final now = DateTime.now();
    if (_lastBatteryCheck == null || now.difference(_lastBatteryCheck!).inSeconds > 30) {
      _lastBatteryCheck = now;
      try {
        _lastBatteryLevel = await _battery.batteryLevel;
      } catch (_) {
        // Ignorar errores de lectura de batería para no bloquear el envío
      }
    }
  }

  void _updateNotification(String title, String body) {
    if (service is AndroidServiceInstance) {
      (service as AndroidServiceInstance).setForegroundNotificationInfo(
        title: title,
        content: body,
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}