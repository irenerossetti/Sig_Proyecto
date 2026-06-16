import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../core/constants/api_constants.dart';

/// Servicio de ubicación ULTRA-OPTIMIZADO estilo Uber/WhatsApp/Yango
/// 
/// Principios de diseño:
/// - ENVIAR INMEDIATAMENTE cada ubicación (sin procesamiento local)
/// - WebSocket siempre abierto con reconexión agresiva
/// - Mínima latencia (< 100ms desde GPS hasta servidor)
/// - Sin verificaciones locales que añadan delay
/// - Batería se actualiza en background (no bloquea)
class LocationService {
  final Battery _battery = Battery();
  
  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  // GPS streaming
  StreamSubscription<Position>? _positionStream;
  
  // Estado
  bool _isTracking = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _deviceId;
  String? _childName;
  int? _lastBatteryLevel;
  DateTime? _lastBatteryCheck;
  
  // Callbacks
  void Function(bool success, String message, double? lat, double? lng, int? battery)? _onUpdate;
  void Function(bool connected, String? childName)? _onConnectionChange;
  
  // Reconexión agresiva
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 100;
  static const Duration _pingInterval = Duration(seconds: 15);

  bool get isTracking => _isTracking;
  bool get isConnected => _isConnected;

  Future<String?> startTracking(
    String deviceId, {
    void Function(bool success, String message, double? lat, double? lng, int? battery)? onUpdate,
    void Function(bool connected, String? childName)? onConnectionChange,
  }) async {
    if (_isTracking) return null;

    // Verificar permisos (rápido)
    final permissionError = await _checkPermissions();
    if (permissionError != null) return permissionError;

    _deviceId = deviceId;
    _onUpdate = onUpdate;
    _onConnectionChange = onConnectionChange;
    _isTracking = true;
    _reconnectAttempts = 0;

    // 1. Conectar WebSocket PRIMERO
    _connectWebSocket();

    // 2. Iniciar GPS stream
    _startGpsStream();

    return null;
  }

  Future<String?> _checkPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS desactivado. Por favor activa la ubicación.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Permisos de ubicación denegados.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Permisos denegados permanentemente. Habilítalos en configuración.';
    }

    return null;
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    
    _positionStream?.cancel();
    _positionStream = null;
    
    _disconnectWebSocket();
    
    _deviceId = null;
    _childName = null;
    _onUpdate = null;
    _onConnectionChange = null;
  }

  void _startGpsStream() {
    _positionStream?.cancel();
    
    // CONFIGURACIÓN UBER-STYLE: Máxima velocidad posible
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // SIN FILTRO - cada cambio de GPS
      intervalDuration: const Duration(milliseconds: 500), // 2 updates/segundo
      forceLocationManager: false, // Fused Location = más rápido
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Rastreando ubicación en tiempo real",
        notificationTitle: "GeoGuard Tracker",
        enableWakeLock: true,
        enableWifiLock: true,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      ),
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onGpsUpdate,
      onError: (e) {
        debugPrint('❌ GPS Error: $e');
        _onUpdate?.call(false, 'Error GPS', null, null, _lastBatteryLevel);
      },
    );
    
    debugPrint('🛰️ GPS: Streaming ULTRA iniciado (500ms)');
  }

  /// GPS callback - ENVIAR INMEDIATAMENTE
  void _onGpsUpdate(Position pos) {
    _sendLocationFast(pos.latitude, pos.longitude);
  }

  /// Envía ubicación lo más rápido posible (sin awaits bloqueantes)
  void _sendLocationFast(double lat, double lng) async {
    // Actualizar batería sin bloquear el UI pero antes de enviar
    await _updateBatteryAsync();

    if (!_isConnected || _channel == null) {
      _onUpdate?.call(false, 'Sin conexión', lat, lng, _lastBatteryLevel);
      return;
    }

    try {
      // Payload mínimo = máxima velocidad
      _channel!.sink.add(jsonEncode({
        'type': 'location',
        'latitude': lat,
        'longitude': lng,
        'battery_level': _lastBatteryLevel,
      }));
      
      _onUpdate?.call(true, 'OK', lat, lng, _lastBatteryLevel);
      
    } catch (e) {
      debugPrint('❌ Send error: $e');
      _onUpdate?.call(false, 'Error', lat, lng, _lastBatteryLevel);
      _handleDisconnection();
    }
  }

  /// Actualiza batería cada 30s sin bloquear
  Future<void> _updateBatteryAsync() async {
    final now = DateTime.now();
    if (_lastBatteryCheck == null || now.difference(_lastBatteryCheck!).inSeconds > 30) {
      _lastBatteryCheck = now;
      try {
        _lastBatteryLevel = await _battery.batteryLevel;
      } catch (_) {
        // Si falla la lectura, mantener el último valor conocido
      }
    }
  }

  // ============ WEBSOCKET ============

  void _connectWebSocket() {
    if (_isConnecting || _isConnected) return;
    
    _isConnecting = true;
    
    try {
      final baseUrl = ApiConstants.baseUrl;
      final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
      final host = baseUrl.replaceAll(RegExp(r'https?://'), '');
      final wsUrl = '$wsScheme://$host/ws/tracker/?device_id=$_deviceId';

      debugPrint('🔌 Conectando: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _handleDisconnection(),
        onDone: _handleDisconnection,
        cancelOnError: false,
      );
      
    } catch (e) {
      debugPrint('❌ WebSocket error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'];

      if (type == 'connection_established') {
        _isConnecting = false;
        _isConnected = true;
        _reconnectAttempts = 0;
        _childName = data['child_name'];
        
        debugPrint('✅ Conectado: $_childName');
        _onConnectionChange?.call(true, _childName);
        _startPingTimer();
        
      } else if (type == 'pong') {
        // Conexión viva - OK
      } else if (type == 'error') {
        debugPrint('⚠️ Server: ${data['message']}');
      }
    } catch (e) {
      debugPrint('❌ Parse error: $e');
    }
  }

  void _handleDisconnection() {
    final wasConnected = _isConnected;
    _cleanup();
    
    if (wasConnected) {
      _onConnectionChange?.call(false, null);
    }
    
    if (_isTracking) {
      _scheduleReconnect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('{"type":"ping"}');
        } catch (_) {
          _handleDisconnection();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (!_isTracking) return;
    
    _reconnectTimer?.cancel();
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reintentos alcanzado');
      return;
    }

    _reconnectAttempts++;
    
    // Reconexión rápida: 1s, 2s, 4s, 8s, max 15s
    final delay = Duration(seconds: (1 << _reconnectAttempts.clamp(0, 4)).clamp(1, 15));
    
    debugPrint('🔄 Reconectando en ${delay.inSeconds}s...');

    _reconnectTimer = Timer(delay, () {
      if (_isTracking && !_isConnected && !_isConnecting) {
        _connectWebSocket();
      }
    });
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    
    try { _channel?.sink.close(status.goingAway); } catch (_) {}
    
    _channel = null;
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
}
