import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../services/background_service.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onTrackingStarted;

  const SetupScreen({super.key, required this.onTrackingStarted});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _deviceIdController = TextEditingController();
  bool _isLoading = false;
  bool _locationGranted = false;
  bool _backgroundLocationGranted = false;
  bool _notificationGranted = false;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDeviceId();
    _checkPermissions();
  }

  Future<void> _loadSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('device_id');
    if (savedId != null) {
      _deviceIdController.text = savedId;
    }
  }
  
  Future<void> _checkPermissions() async {
    final locationStatus = await Permission.locationWhenInUse.status;
    final backgroundStatus = await Permission.locationAlways.status;
    final notificationStatus = await Permission.notification.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    
    setState(() {
      _locationGranted = locationStatus.isGranted;
      _backgroundLocationGranted = backgroundStatus.isGranted;
      _notificationGranted = notificationStatus.isGranted;
      _batteryOptimizationIgnored = batteryStatus.isGranted;
    });
  }
  
  Future<bool> _requestAllPermissions() async {
    // 1. Request basic location permission first
    var locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      if (mounted) {
        _showPermissionDeniedDialog(
          'Permiso de Ubicación',
          'GeoGuard necesita acceso a la ubicación para rastrear el dispositivo.',
        );
      }
      return false;
    }
    setState(() => _locationGranted = true);
    
    // 2. Request background location
    var backgroundStatus = await Permission.locationAlways.request();
    if (!backgroundStatus.isGranted) {
      if (mounted) {
        _showPermissionDeniedDialog(
          'Ubicación en Segundo Plano',
          'Para que el rastreo funcione cuando la app está cerrada, necesitas permitir "Siempre" en la configuración de ubicación.',
        );
      }
      return false;
    }
    setState(() => _backgroundLocationGranted = true);
    
    // 3. Request notification permission
    var notificationStatus = await Permission.notification.request();
    setState(() => _notificationGranted = notificationStatus.isGranted);
    
    // 4. Request battery optimization exemption
    var batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    setState(() => _batteryOptimizationIgnored = batteryStatus.isGranted);
    
    return true;
  }
  
  void _showPermissionDeniedDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTracking() async {
    if (_deviceIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor ingresa el Device ID'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Request all permissions
    final permissionsGranted = await _requestAllPermissions();
    
    if (!permissionsGranted) {
      setState(() => _isLoading = false);
      return;
    }

    final deviceId = _deviceIdController.text.trim();
    
    // Guardar Device ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
    
    // Start background service
    await BackgroundTrackingService.startService(deviceId);
    
    widget.onTrackingStarted();
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Logo/Icono GeoGuard
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 56,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              
              // Título
              Text(
                'GeoGuard',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Tracker',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Dispositivo de rastreo GPS en tiempo real',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Card de instrucciones
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, 
                            color: AppTheme.primaryGreen, 
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Instrucciones',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _InstructionStep(
                        number: '1',
                        text: 'Abre la app GeoGuard (tutor) en otro dispositivo',
                      ),
                      const SizedBox(height: 12),
                      const _InstructionStep(
                        number: '2',
                        text: 'Ve a "Niños" y selecciona el perfil del niño',
                      ),
                      const SizedBox(height: 12),
                      const _InstructionStep(
                        number: '3',
                        text: 'Copia el "Device ID" del dispositivo asignado',
                      ),
                      const SizedBox(height: 12),
                      const _InstructionStep(
                        number: '4',
                        text: 'Pégalo aquí abajo para iniciar el rastreo',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Permission status card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: AppTheme.primaryGreen, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Permisos Requeridos',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PermissionRow(
                        icon: Icons.location_on,
                        label: 'Ubicación',
                        granted: _locationGranted,
                      ),
                      _PermissionRow(
                        icon: Icons.location_searching,
                        label: 'Ubicación en segundo plano',
                        granted: _backgroundLocationGranted,
                        isRequired: true,
                      ),
                      _PermissionRow(
                        icon: Icons.notifications,
                        label: 'Notificaciones',
                        granted: _notificationGranted,
                      ),
                      _PermissionRow(
                        icon: Icons.battery_saver,
                        label: 'Optimización de batería',
                        granted: _batteryOptimizationIgnored,
                      ),
                      if (!_backgroundLocationGranted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '⚠️ El permiso de ubicación en segundo plano es necesario para que el rastreo funcione cuando la app está cerrada.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Campo Device ID
              TextField(
                controller: _deviceIdController,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'Ej: TRACKER-ABC123',
                  prefixIcon: const Icon(Icons.qr_code, color: AppTheme.primaryGreen),
                  suffixIcon: _deviceIdController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _deviceIdController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),
              
              // Botón iniciar
              FilledButton.icon(
                onPressed: _isLoading ? null : _startTracking,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Iniciando...' : 'Iniciar Rastreo'),
              ),
              
              const SizedBox(height: 48),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Ubicación segura y encriptada',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool granted;
  final bool isRequired;

  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.granted,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: granted ? AppTheme.success : (isRequired ? AppTheme.warning : Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: granted ? AppTheme.success : (isRequired ? AppTheme.warning : Colors.grey),
          ),
        ],
      ),
    );
  }
}
