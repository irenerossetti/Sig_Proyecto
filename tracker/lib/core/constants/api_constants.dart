class ApiConstants {
  ApiConstants._();

  // Backend en VM (Django)
  static const String baseUrl = 'http://54.205.90.4';

  // Auth endpoints
  static const String login = '/api/auth/login/';
  static const String register = '/api/auth/register/';
  static const String logout = '/api/auth/logout/';

  // Tracker endpoints
  static const String locations = '/api/monitoring/locations/';
  static const String devices = '/api/monitoring/devices/';
}