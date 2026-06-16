import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Servicio singleton para cachear marcadores e imágenes del mapa
/// Mejora significativamente el rendimiento al evitar recrear BitmapDescriptors
class MapImageCacheService {
  static final MapImageCacheService _instance = MapImageCacheService._internal();
  factory MapImageCacheService() => _instance;
  MapImageCacheService._internal();

  final Map<String, BitmapDescriptor> _markerCache = {};
  final Map<String, ui.Image> _imageCache = {};
  bool _isInitialized = false;

  /// Pre-cachear marcadores comunes al inicio de la app
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Pre-cachear marcadores de colores más usados
    await Future.wait([
      _cacheColorMarker('azure', BitmapDescriptor.hueAzure),
      _cacheColorMarker('green', BitmapDescriptor.hueGreen),
      _cacheColorMarker('red', BitmapDescriptor.hueRed),
      _cacheColorMarker('orange', BitmapDescriptor.hueOrange),
    ]);
    
    _isInitialized = true;
  }

  Future<void> _cacheColorMarker(String key, double hue) async {
    if (!_markerCache.containsKey(key)) {
      _markerCache[key] = BitmapDescriptor.defaultMarkerWithHue(hue);
    }
  }

  /// Obtener marcador cacheado por color
  BitmapDescriptor getColorMarker(String color) {
    return _markerCache[color] ?? BitmapDescriptor.defaultMarker;
  }

  /// Marcador azul para niños
  BitmapDescriptor get childMarker => 
      _markerCache['azure'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  /// Marcador verde para tutor
  BitmapDescriptor get tutorMarker =>
      _markerCache['green'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  /// Crear marcador estilo Google Maps con foto y glow de estado
  /// Tamaño fijo que se comporta como marcador nativo de Google Maps
  Future<BitmapDescriptor> getChildMarker({
    required String name,
    required Color color,
    bool isActive = true,
    String? photoUrl,
  }) async {
    final cacheKey = 'child_marker_v4_${color.toARGB32()}_${isActive}_${photoUrl?.hashCode ?? 0}';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    try {
      ui.Image? photoImage;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        photoImage = await _loadNetworkImage(photoUrl);
      }
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Tamaño similar al marcador nativo de Google Maps
      const double photoSize = 80.0;
      const double borderWidth = 6.0;
      const double glowSize = 8.0;
      const double pointerHeight = 16.0;
      const double totalWidth = photoSize + borderWidth * 2 + glowSize * 2;
      const double totalHeight = photoSize + borderWidth * 2 + pointerHeight + glowSize;
      
      final centerX = totalWidth / 2;
      final centerY = glowSize + borderWidth + photoSize / 2;
      
      // Color del borde según estado
      final statusColor = isActive 
          ? const Color(0xFF2ECC71)  // Verde
          : const Color(0xFF9E9E9E); // Gris
      
      // Sombra suave
      canvas.drawCircle(
        Offset(centerX, centerY + 2),
        photoSize / 2 + borderWidth,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      
      // Glow sutil del color de estado
      canvas.drawCircle(
        Offset(centerX, centerY),
        photoSize / 2 + borderWidth + glowSize / 2,
        Paint()
          ..color = statusColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      
      // Borde exterior (color de estado)
      canvas.drawCircle(
        Offset(centerX, centerY),
        photoSize / 2 + borderWidth / 2,
        Paint()
          ..color = statusColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
      
      // Fondo blanco
      canvas.drawCircle(
        Offset(centerX, centerY),
        photoSize / 2,
        Paint()..color = Colors.white,
      );
      
      if (photoImage != null) {
        // Foto circular
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: photoSize / 2 - 1,
        )));
        canvas.drawImageRect(
          photoImage,
          Rect.fromLTWH(0, 0, photoImage.width.toDouble(), photoImage.height.toDouble()),
          Rect.fromCircle(center: Offset(centerX, centerY), radius: photoSize / 2 - 1),
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true,
        );
        canvas.restore();
      } else {
        // Inicial si no hay foto
        canvas.drawCircle(
          Offset(centerX, centerY),
          photoSize / 2 - 1,
          Paint()..color = color.withValues(alpha: 0.2),
        );
        
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final textPainter = TextPainter(
          text: TextSpan(
            text: initial,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(centerX - textPainter.width / 2, centerY - textPainter.height / 2),
        );
      }
      
      // Puntero (flecha hacia abajo)
      final pointerTop = centerY + photoSize / 2 + borderWidth / 2 - 2;
      final pointerPath = Path()
        ..moveTo(centerX - 10, pointerTop)
        ..lineTo(centerX + 10, pointerTop)
        ..lineTo(centerX, pointerTop + pointerHeight)
        ..close();
      
      // Sombra del puntero
      canvas.drawPath(
        pointerPath.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      
      // Puntero con color de estado
      canvas.drawPath(pointerPath, Paint()..color = statusColor);
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final marker = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _markerCache[cacheKey] = marker;
        return marker;
      }
    } catch (e) {
      debugPrint('Error creating child marker: $e');
    }
    
    return childMarker;
  }

  /// Cargar imagen desde URL (alta resolución para marcadores nítidos)
  /// Recomendación: Subir fotos de al menos 300x300px para mejor calidad
  Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      // Verificar cache de imágenes
      if (_imageCache.containsKey(url)) {
        return _imageCache[url];
      }
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );
      
      if (response.statusCode == 200) {
        // Resolución alta para mantener calidad en todos los niveles de zoom
        final codec = await ui.instantiateImageCodec(
          response.bodyBytes,
          targetWidth: 300,
          targetHeight: 300,
        );
        final frameInfo = await codec.getNextFrame();
        _imageCache[url] = frameInfo.image;
        return frameInfo.image;
      }
    } catch (e) {
      debugPrint('Error loading network image for marker: $e');
    }
    return null;
  }

  /// Crear un marcador personalizado desde asset (con cache)
  Future<BitmapDescriptor> getCustomMarker(
    String assetPath, {
    int width = 100,
  }) async {
    final cacheKey = '$assetPath-$width';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      final frameInfo = await codec.getNextFrame();
      final byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData != null) {
        final marker = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _markerCache[cacheKey] = marker;
        return marker;
      }
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
    }
    
    return BitmapDescriptor.defaultMarker;
  }

  /// Limpiar cache (llamar en dispose si es necesario)
  void clearCache() {
    _markerCache.clear();
    _imageCache.clear();
    _isInitialized = false;
  }
}

/// Extension para facilitar el uso
extension BitmapDescriptorCache on BitmapDescriptor {
  static BitmapDescriptor cachedAzure() => 
      MapImageCacheService().childMarker;
  
  static BitmapDescriptor cachedGreen() => 
      MapImageCacheService().tutorMarker;
}
