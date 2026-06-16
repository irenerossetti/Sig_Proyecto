import 'package:flutter/material.dart';
import '../../data/geocoding_repository.dart';

/// Widget que muestra la dirección de una ubicación usando Google Geocoding
/// Se actualiza automáticamente cuando las coordenadas cambian significativamente
class AddressDisplayWidget extends StatefulWidget {
  const AddressDisplayWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.token,
    this.childName,
    this.showIcon = true,
    this.compact = false,
    this.backgroundColor,
    this.textColor,
    this.onAddressLoaded,
  });

  final double latitude;
  final double longitude;
  final String token;
  final String? childName;
  final bool showIcon;
  final bool compact;
  final Color? backgroundColor;
  final Color? textColor;
  final void Function(String? address)? onAddressLoaded;

  @override
  State<AddressDisplayWidget> createState() => _AddressDisplayWidgetState();
}

class _AddressDisplayWidgetState extends State<AddressDisplayWidget> {
  late final GeocodingRepository _repository;
  String? _address;
  bool _isLoading = false;
  String? _error;

  // Última ubicación consultada (para evitar llamadas duplicadas)
  double? _lastLat;
  double? _lastLng;

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ AddressDisplayWidget initState - token: ${widget.token.isNotEmpty}, lat: ${widget.latitude}, lng: ${widget.longitude}');
    _repository = GeocodingRepository(token: widget.token);
    _loadAddress();
  }

  @override
  void didUpdateWidget(AddressDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Verificar si las coordenadas cambiaron significativamente (~30m)
    final latDiff = (widget.latitude - oldWidget.latitude).abs();
    final lngDiff = (widget.longitude - oldWidget.longitude).abs();
    
    if (latDiff > 0.0003 || lngDiff > 0.0003) {
      _loadAddress();
    }

    // Actualizar token si cambió
    if (widget.token != oldWidget.token) {
      _repository.updateToken(widget.token);
    }
  }

  Future<void> _loadAddress() async {
    debugPrint('🗺️ _loadAddress called - lastLat: $_lastLat, lat: ${widget.latitude}');
    
    // Evitar llamadas duplicadas
    if (_lastLat == widget.latitude && _lastLng == widget.longitude) {
      debugPrint('🗺️ Skipping - same coordinates');
      return;
    }

    _lastLat = widget.latitude;
    _lastLng = widget.longitude;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    debugPrint('🗺️ Calling reverseGeocode...');
    try {
      final address = await _repository.reverseGeocode(
        widget.latitude,
        widget.longitude,
      );
      debugPrint('🗺️ Got address: $address');

      if (mounted) {
        setState(() {
          _address = address;
          _isLoading = false;
        });
        widget.onAddressLoaded?.call(address);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando dirección';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    if (widget.compact) {
      return _buildCompactView(colorScheme, textTheme);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showIcon)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          if (widget.showIcon) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.childName != null)
                  Text(
                    'Ubicación de ${widget.childName}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (widget.childName != null) const SizedBox(height: 4),
                
                // Estado de la dirección
                _buildAddressContent(colorScheme, textTheme),
                
                const SizedBox(height: 8),
                // Coordenadas (siempre visibles)
                Text(
                  '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressContent(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Obteniendo dirección...',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Text(
        _error!,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.error,
        ),
      );
    }

    if (_address != null) {
      return Text(
        _address!,
        style: textTheme.bodyMedium?.copyWith(
          color: widget.textColor ?? colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      'Dirección no disponible',
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildCompactView(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          if (widget.childName != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ubicación de ${widget.childName}',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          if (widget.childName != null) const SizedBox(height: 4),
          
          // Dirección
          if (_isLoading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Obteniendo dirección...',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            Text(
              _address ?? 'Dirección no disponible',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          
          const SizedBox(height: 4),
          // Coordenadas
          Text(
            '${widget.latitude.toStringAsFixed(5)},  ${widget.longitude.toStringAsFixed(5)}',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white60,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip simple para mostrar dirección en espacios reducidos
class AddressChip extends StatelessWidget {
  const AddressChip({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.token,
    this.maxWidth,
  });

  final double latitude;
  final double longitude;
  final String token;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? 200,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AddressDisplayWidget(
        latitude: latitude,
        longitude: longitude,
        token: token,
        compact: true,
        showIcon: true,
        textColor: colorScheme.onSecondaryContainer,
      ),
    );
  }
}
