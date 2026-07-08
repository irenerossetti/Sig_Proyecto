import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Maneja notificaciones en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _pendingRedirectPath;
  final _onTapController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap {
    if (_pendingRedirectPath != null) {
      final path = _pendingRedirectPath!;
      _pendingRedirectPath = null;
      Future.delayed(const Duration(milliseconds: 600), () {
        _onTapController.add(path);
      });
    }
    return _onTapController.stream;
  }

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Canal de notificaciones para Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'geoguard_alerts',
    'Alertas de GeoGuard',
    description: 'Notificaciones cuando un niño sale de la zona segura',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    // Configurar handler para mensajes en background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permisos
    await _requestPermissions();

    // Configurar notificaciones locales
    await _setupLocalNotifications();

    // Obtener token FCM
    await _getToken();

    // Escuchar mensajes en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Escuchar cuando el usuario toca una notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Verificar si la app se abrió desde una notificación
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('NotificationService initialized');
  }

  /// Solicita permisos de notificación
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Configura notificaciones locales (para mostrar notificaciones en foreground)
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            debugPrint('Local notification tapped with payload: $data');
            final type = data['type'];
            final childId = data['child_id'];
            if (type == 'zone_exit' && childId != null) {
              _triggerRedirect('/home?tab=3&childId=$childId');
            } else {
              _triggerRedirect('/home?tab=2');
            }
          } catch (e) {
            debugPrint('Error parsing local notification payload: $e');
          }
        }
      },
    );

    // Crear canal de notificaciones en Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Obtiene el token FCM
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token obtained: ${_fcmToken != null ? "${_fcmToken!.substring(0, 30)}..." : "NULL"}');

      // Escuchar cambios de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: ${newToken.substring(0, 30)}...');
        // Aquí podrías enviar el nuevo token al backend
      });

      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Maneja mensajes recibidos cuando la app está en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      // Mostrar notificación local
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFD32F2F),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Maneja cuando el usuario toca una notificación
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    
    final type = message.data['type'];
    final childId = message.data['child_id'];
    
    if (type == 'zone_exit' && childId != null) {
      _triggerRedirect('/home?tab=3&childId=$childId');
    } else {
      _triggerRedirect('/home?tab=2'); // Default to Alerts tab
    }
  }

  void _triggerRedirect(String path) {
    if (_onTapController.hasListener) {
      _onTapController.add(path);
    } else {
      _pendingRedirectPath = path;
    }
  }

  /// Obtiene el token actual (para enviar al backend)
  Future<String?> getToken() async {
    if (_fcmToken == null) {
      return await _getToken();
    }
    return _fcmToken;
  }
}
