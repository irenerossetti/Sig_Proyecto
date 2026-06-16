// Utilidades de UI compartidas - evita duplicación de funciones helper

import 'package:flutter/material.dart';

/// Color según estado de alerta
Color alertStatusColor(String status) {
  switch (status) {
    case 'resolved':
      return const Color(0xFF2ECC71); // Verde Esmeralda
    case 'acknowledged':
      return Colors.orange;
    default:
      return const Color(0xFFE74C3C); // Rojo Carmesí
  }
}

/// Color según nivel de batería
Color batteryColor(int level) {
  if (level <= 20) return const Color(0xFFE74C3C);
  if (level <= 50) return Colors.orange;
  return const Color(0xFF2ECC71);
}

/// Icono según nivel de batería
IconData batteryIcon(int level) {
  if (level <= 20) return Icons.battery_alert;
  if (level <= 50) return Icons.battery_4_bar;
  return Icons.battery_full;
}

/// Verifica si un niño tiene coordenadas GPS válidas
bool hasValidCoordinates(double? lat, double? lng) {
  return lat != null && lng != null;
}
