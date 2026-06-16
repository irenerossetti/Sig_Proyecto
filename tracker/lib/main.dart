import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'screens/setup_screen.dart';
import 'screens/tracking_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar orientación y barra de estado
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Inicializar servicio de background
  await BackgroundTrackingService.initialize();
  
  runApp(const TrackerApp());
}

class TrackerApp extends StatefulWidget {
  const TrackerApp({super.key});

  @override
  State<TrackerApp> createState() => _TrackerAppState();
}

class _TrackerAppState extends State<TrackerApp> {
  bool _isConfigured = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    
    // También verificar si el servicio está corriendo
    final isServiceRunning = await BackgroundTrackingService.isRunning();
    
    setState(() {
      _isConfigured = (deviceId != null && deviceId.isNotEmpty) || isServiceRunning;
      _isLoading = false;
    });
  }

  void _onTrackingStarted() {
    setState(() {
      _isConfigured = true;
    });
  }

  void _onStopTracking() {
    setState(() {
      _isConfigured = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'GeoGuard Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: _isConfigured
          ? TrackingScreen(onStopTracking: _onStopTracking)
          : SetupScreen(onTrackingStarted: _onTrackingStarted),
    );
  }
}
