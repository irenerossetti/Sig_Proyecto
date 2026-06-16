import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../constants/api_constants.dart';

/// Modelo para actualizaciones de ubicación en tiempo real
class LocationUpdate {
  final int childId;
  final String childName;
  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final DateTime timestamp;

  LocationUpdate({
    required this.childId,
    required this.childName,
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    required this.timestamp,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      childId: json['child_id'] as int,
      childName: json['child_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      batteryLevel: json['battery_level'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Modelo para alertas en tiempo real
class RealtimeAlert {
  final int alertId;
  final int childId;
  final String childName;
  final String message;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  RealtimeAlert({
    required this.alertId,
    required this.childId,
    required this.childName,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory RealtimeAlert.fromJson(Map<String, dynamic> json) {
    return RealtimeAlert(
      alertId: json['alert_id'] as int,
      childId: json['child_id'] as int,
      childName: json['child_name'] as String,
      message: json['message'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Servicio WebSocket para recibir actualizaciones de ubicación en tiempo real
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _token;
  bool _isConnecting = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 3);
  static const Duration _pingInterval = Duration(seconds: 25);

  // Stream controllers para exponer eventos
  final _locationController = StreamController<LocationUpdate>.broadcast();
  final _alertController = StreamController<RealtimeAlert>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Stream de actualizaciones de ubicación
  Stream<LocationUpdate> get locationUpdates => _locationController.stream;

  /// Stream de alertas
  Stream<RealtimeAlert> get alerts => _alertController.stream;

  /// Stream de estado de conexión
  Stream<bool> get connectionState => _connectionController.stream;

  /// Verifica si está conectado
  bool get isConnected => _isConnected;

  /// Conectar al WebSocket
  Future<void> connect(String token) async {
    if (_isConnecting || _isConnected) {
      debugPrint('⚠️ WebSocket ya conectando o conectado');
      return;
    }
    
    _token = token;
    _reconnectAttempts = 0;

    _connect();
  }

  void _connect() {
    if (_isConnecting || _isConnected) return;
    
    _isConnecting = true;
    
    try {
      // Construir URL del WebSocket
      final baseUrl = ApiConstants.baseUrl;
      final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
      final host = baseUrl.replaceAll(RegExp(r'https?://'), '');
      final wsUrl = '$wsScheme://$host/ws/location/?token=$_token';

      debugPrint('🔌 WebSocket connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Escuchar mensajes
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      debugPrint('📡 WebSocket stream iniciado, esperando confirmación...');
      
    } catch (e) {
      debugPrint('❌ WebSocket connection error: $e');
      _isConnecting = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('📨 WebSocket message: $type');

      switch (type) {
        case 'connection_established':
          // ¡CONEXIÓN CONFIRMADA POR EL SERVIDOR!
          _isConnecting = false;
          _isConnected = true;
          _reconnectAttempts = 0;
          _connectionController.add(true);
          
          // Iniciar ping timer solo cuando la conexión está confirmada
          _startPingTimer();
          
          debugPrint('✅ WebSocket: Connection confirmed, tutor_id=${data['tutor_id']}');
          break;

        case 'location_update':
          final update = LocationUpdate.fromJson(data);
          _locationController.add(update);
          debugPrint('📍 LOCATION UPDATE: child=${update.childId}, lat=${update.latitude}, lng=${update.longitude}, bat=${update.batteryLevel}%');
          break;

        case 'alert':
          final alert = RealtimeAlert.fromJson(data);
          _alertController.add(alert);
          debugPrint('🚨 ALERT: child ${alert.childId} - ${alert.message}');
          break;

        case 'pong':
          debugPrint('💓 Pong recibido');
          break;

        case 'subscribed':
          debugPrint('✅ Subscribed to child ${data['child_id']}');
          break;

        case 'error':
          debugPrint('❌ WebSocket error: ${data['message']}');
          break;
      }
    } catch (e) {
      debugPrint('❌ WebSocket message parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('❌ WebSocket stream error: $error');
    _handleDisconnection();
  }

  void _onDone() {
    debugPrint('🔌 WebSocket stream closed');
    _handleDisconnection();
  }
  
  void _handleDisconnection() {
    final wasConnected = _isConnected;
    
    _cleanup();
    
    // Solo notificar si realmente estábamos conectados
    if (wasConnected) {
      _connectionController.add(false);
    }
    
    if (_token != null) {
      _scheduleReconnect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
          debugPrint('💓 Ping enviado');
        } catch (e) {
          debugPrint('❌ WebSocket ping failed: $e');
          _handleDisconnection();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (_token == null) return;
    
    _reconnectTimer?.cancel();
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ WebSocket: Max reconnect attempts reached ($_maxReconnectAttempts)');
      return;
    }

    _reconnectAttempts++;
    
    // Backoff exponencial: 3s, 6s, 12s, max 30s
    final delaySeconds = (_initialReconnectDelay.inSeconds * (1 << (_reconnectAttempts - 1).clamp(0, 3))).clamp(3, 30);
    final delay = Duration(seconds: delaySeconds);
    
    debugPrint('🔄 WebSocket: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (_token != null && !_isConnected && !_isConnecting) {
        _connect();
      }
    });
  }

  /// Suscribirse a actualizaciones de un niño específico
  void subscribeToChild(int childId) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'subscribe_child',
        'child_id': childId,
      }));
      debugPrint('📬 Subscribing to child $childId');
    }
  }

  /// Desuscribirse de un niño
  void unsubscribeFromChild(int childId) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'unsubscribe_child',
        'child_id': childId,
      }));
      debugPrint('📭 Unsubscribing from child $childId');
    }
  }

  /// Desconectar WebSocket
  void disconnect() {
    _token = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    
    if (_channel != null) {
      try {
        _channel!.sink.close(status.goingAway);
      } catch (e) {
        debugPrint('Error cerrando WebSocket: $e');
      }
      _channel = null;
    }
    
    _isConnected = false;
    _isConnecting = false;
    debugPrint('🔌 WebSocket disconnected by user');
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

  /// Dispose del servicio
  void dispose() {
    disconnect();
    _locationController.close();
    _alertController.close();
    _connectionController.close();
  }
}
