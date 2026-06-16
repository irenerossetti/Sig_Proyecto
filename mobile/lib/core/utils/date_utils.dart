/// Utilidades de formateo de fechas - SINGLETON para evitar duplicación
/// 
/// Este archivo centraliza todas las funciones de formateo que estaban
/// duplicadas en múltiples archivos del proyecto.
library;

/// Formatea una diferencia de tiempo relativa (ej: "hace 5 min")
String relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return formatDate(dateTime);
}

/// Formatea una fecha corta (ej: "15 Nov 2024")
String formatDate(DateTime date) {
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formatea una fecha simple (ej: "15/11/2024")
String formatDateSimple(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Calcula la edad a partir de una fecha de nacimiento
int calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month || 
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}
