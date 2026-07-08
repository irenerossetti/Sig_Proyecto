class ApiConstants {
  ApiConstants._();

  // Backend en VM (Django)
  static const String baseUrl = String.fromEnvironment(
    'GEOGUARD_API_BASE',
    defaultValue: 'http://54.205.90.4',
  );

  static const String login = '/api/auth/login/';
  static const String logout = '/api/auth/logout/';
  static const String register = '/api/auth/register/';
  static const String profile = '/api/auth/profile/';
  static const String changePassword = '/api/auth/change-password/';

  static const String children = '/api/monitoring/children/';
  static const String alerts = '/api/monitoring/alerts/';
  static const String devices = '/api/monitoring/devices/';
  static const String safeZones = '/api/monitoring/safe-zones/';
  
  // Groups API
  static const String groups = '/api/monitoring/groups/';
  static const String groupSafeZones = '/api/monitoring/group-safe-zones/';
}
