import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget de avatar optimizado que usa cache de imágenes de red.
/// Evita recargar imágenes repetidamente y reduce consumo de datos.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Nombre para mostrar inicial si no hay imagen
  final String name;
  
  /// URL de la imagen (puede ser null)
  final String? imageUrl;
  
  /// Radio del avatar
  final double radius;
  
  /// Color de fondo cuando no hay imagen
  final Color? backgroundColor;
  
  /// Color del texto cuando no hay imagen
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final fgColor = foregroundColor ?? Theme.of(context).colorScheme.primary;

    // Si no hay URL, mostrar solo inicial
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    // Con URL, usar cache de imagen
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: SizedBox(
          width: radius,
          height: radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: fgColor,
          ),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      ),
      // Optimización: limitar tamaño en memoria
      memCacheWidth: (radius * 4).toInt(),
      memCacheHeight: (radius * 4).toInt(),
    );
  }
}
