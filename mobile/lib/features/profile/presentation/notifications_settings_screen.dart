import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de configuración de notificaciones
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _alertsEnabled = true;
  bool _exitZoneAlerts = true;
  bool _enterZoneAlerts = true;
  bool _batteryAlerts = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alertsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _exitZoneAlerts = prefs.getBool('exit_zone_alerts') ?? true;
      _enterZoneAlerts = prefs.getBool('enter_zone_alerts') ?? true;
      _batteryAlerts = prefs.getBool('battery_alerts') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _alertsEnabled);
    await prefs.setBool('exit_zone_alerts', _exitZoneAlerts);
    await prefs.setBool('enter_zone_alerts', _enterZoneAlerts);
    await prefs.setBool('battery_alerts', _batteryAlerts);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.bell,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración de alertas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Personaliza cómo quieres recibir las notificaciones',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main toggle
          SwitchListTile(
            title: const Text('Notificaciones'),
            subtitle: const Text('Activar o desactivar todas las notificaciones'),
            secondary: Icon(
              _alertsEnabled ? LucideIcons.bellRing : LucideIcons.bellOff,
              color: _alertsEnabled ? colorScheme.primary : colorScheme.outline,
            ),
            value: _alertsEnabled,
            onChanged: (value) {
              setState(() => _alertsEnabled = value);
              _saveSettings();
            },
          ),
          const Divider(),

          // Alert types section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tipos de alertas',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            title: const Text('Salida de zona segura'),
            subtitle: const Text('Cuando el niño sale del área definida'),
            secondary: const Icon(LucideIcons.mapPinOff),
            value: _exitZoneAlerts && _alertsEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _exitZoneAlerts = value);
                    _saveSettings();
                  }
                : null,
          ),

          SwitchListTile(
            title: const Text('Entrada a zona segura'),
            subtitle: const Text('Cuando el niño regresa al área definida'),
            secondary: const Icon(LucideIcons.mapPinCheck),
            value: _enterZoneAlerts && _alertsEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _enterZoneAlerts = value);
                    _saveSettings();
                  }
                : null,
          ),

          SwitchListTile(
            title: const Text('Batería baja'),
            subtitle: const Text('Cuando el dispositivo tiene poca batería'),
            secondary: const Icon(LucideIcons.batteryLow),
            value: _batteryAlerts && _alertsEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _batteryAlerts = value);
                    _saveSettings();
                  }
                : null,
          ),

          const Divider(),

          // Sound and vibration section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sonido y vibración',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            title: const Text('Sonido'),
            subtitle: const Text('Reproducir sonido con las alertas'),
            secondary: Icon(
              _soundEnabled ? LucideIcons.volume2 : LucideIcons.volumeOff,
            ),
            value: _soundEnabled && _alertsEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _soundEnabled = value);
                    _saveSettings();
                  }
                : null,
          ),

          SwitchListTile(
            title: const Text('Vibración'),
            subtitle: const Text('Vibrar el dispositivo con las alertas'),
            secondary: Icon(
              _vibrationEnabled ? LucideIcons.vibrate : LucideIcons.smartphoneNfc,
            ),
            value: _vibrationEnabled && _alertsEnabled,
            onChanged: _alertsEnabled
                ? (value) {
                    setState(() => _vibrationEnabled = value);
                    _saveSettings();
                  }
                : null,
          ),

          const SizedBox(height: 24),

          // Info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Las notificaciones push deben estar habilitadas en los ajustes del sistema para recibir alertas.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
