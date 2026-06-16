import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../services/background_service.dart';

class TrackingScreen extends StatefulWidget {
  final VoidCallback onStopTracking;

  const TrackingScreen({super.key, required this.onStopTracking});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
  String _deviceId = '';
  String _childName = '';
  String? _lastUpdate;
  int _updateCount = 0;
  int _errorCount = 0;
  String? _lastCoords;
  String? _errorMessage;
  bool _isConnected = false;
  int? _batteryLevel;
  bool _isServiceRunning = false;
  
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeService();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check service status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkServiceStatus();
    }
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    
    if (deviceId == null) return;
    
    setState(() {
      _deviceId = deviceId;
    });
    
    // Listen to service events
    _listenToServiceEvents();
    
    // Check if service is already running
    final isRunning = await BackgroundTrackingService.isServiceRunning();
    
    if (!isRunning) {
      // Start the background service
      await BackgroundTrackingService.startService(deviceId);
    }
    
    _checkServiceStatus();
  }
  
  void _listenToServiceEvents() {
    final service = FlutterBackgroundService();
    
    _serviceSubscription = service.on('serviceStatus').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isServiceRunning = event['isRunning'] ?? false;
        });
      }
    });
    
    service.on('connectionUpdate').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isConnected = event['connected'] ?? false;
          if (event['childName'] != null) {
            _childName = event['childName'];
          }
          if (_isConnected) {
            _errorMessage = null;
          } else if (event['error'] != null) {
            _errorMessage = event['error'];
            _errorCount++;
          }
        });
      }
    });
    
    service.on('locationUpdate').listen((event) {
      if (event != null && mounted) {
        final success = event['success'] ?? false;
        setState(() {
          _lastUpdate = _formatTime(DateTime.now());
          if (event['battery'] != null) {
            _batteryLevel = event['battery'];
          }
          if (success) {
            _updateCount++;
            final lat = event['latitude'];
            final lng = event['longitude'];
            if (lat != null && lng != null) {
              _lastCoords = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
            }
            _errorMessage = null;
          } else {
            _errorCount++;
            _errorMessage = event['error'];
          }
        });
      }
    });
  }
  
  Future<void> _checkServiceStatus() async {
    final isRunning = await BackgroundTrackingService.isServiceRunning();
    if (mounted) {
      setState(() {
        _isServiceRunning = isRunning;
      });
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Future<void> _stopService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detener rastreo'),
        content: const Text(
          '¿Estás seguro de que deseas detener el rastreo GPS?\n\n'
          'El tutor dejará de recibir actualizaciones de ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Detener'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Stop background service
    await BackgroundTrackingService.stopService();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_id');

    widget.onStopTracking();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = _errorMessage != null && !_isConnected;
    
    // Determinar color de estado
    final statusColor = hasError 
        ? AppTheme.warning 
        : _isConnected 
            ? AppTheme.success 
            : colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('GeoGuard Tracker'),
            if (_childName.isNotEmpty)
              Text(
                _childName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // Service status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isServiceRunning 
                  ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                  : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isServiceRunning ? Icons.sync : Icons.sync_disabled,
                  size: 14,
                  color: _isServiceRunning ? AppTheme.primaryGreen : AppTheme.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  _isServiceRunning ? 'BG' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _isServiceRunning ? AppTheme.primaryGreen : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
          // Indicador de conexión
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected 
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: _isConnected ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isConnected ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Background service status banner
            if (_isServiceRunning)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.running_with_errors, color: AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Servicio en segundo plano activo\nPuedes cerrar la app - el rastreo continuará',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Estado principal
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasError 
                    ? Icons.warning_rounded 
                    : _isConnected 
                        ? Icons.location_on 
                        : Icons.sync,
                size: 72,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasError 
                  ? 'Sin Conexión' 
                  : _isConnected 
                      ? 'Rastreo Activo' 
                      : 'Conectando...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (_isConnected) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WebSocket en tiempo real',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            
            // Error message
            if (_errorMessage != null && !_isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Stats cards
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _StatRow(
                      icon: Icons.tag,
                      label: 'Device ID',
                      value: _deviceId,
                      iconColor: AppTheme.primaryGreen,
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      icon: Icons.my_location,
                      label: 'Ubicación actual',
                      value: _lastCoords ?? 'Esperando GPS...',
                      iconColor: AppTheme.primaryGreen,
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      icon: Icons.access_time,
                      label: 'Última actualización',
                      value: _lastUpdate ?? 'Pendiente...',
                      iconColor: AppTheme.primaryGreen,
                    ),
                    if (_batteryLevel != null) ...[
                      const Divider(height: 24),
                      _StatRow(
                        icon: _batteryLevel! > 50 
                            ? Icons.battery_full 
                            : _batteryLevel! > 20 
                                ? Icons.battery_5_bar
                                : Icons.battery_1_bar,
                        label: 'Batería',
                        value: '$_batteryLevel%',
                        iconColor: _batteryLevel! > 50 
                            ? AppTheme.success 
                            : _batteryLevel! > 20 
                                ? AppTheme.warning 
                                : AppTheme.error,
                        valueColor: _batteryLevel! > 50 
                            ? AppTheme.success 
                            : _batteryLevel! > 20 
                                ? AppTheme.warning 
                                : AppTheme.error,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Contador de envíos
            Row(
              children: [
                Expanded(
                  child: _CounterCard(
                    icon: Icons.check_circle,
                    label: 'Enviados',
                    value: _updateCount,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CounterCard(
                    icon: Icons.error,
                    label: 'Errores',
                    value: _errorCount,
                    color: _errorCount > 0 ? AppTheme.error : colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Info card
            Card(
              color: AppTheme.primaryGreen.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ubicación ULTRA-RÁPIDA via WebSocket.\nActualiza cada 500ms (como Uber/Yango).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Botón detener
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _stopService,
                icon: const Icon(Icons.stop, color: AppTheme.error),
                label: const Text('Detener Rastreo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? valueColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _CounterCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
