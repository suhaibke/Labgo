import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Wraps a plain [http.Client] with a hard timeout on every request.
///
/// Without this, a tile request that hangs (e.g. a blocked/unreachable
/// CDN on some networks) never resolves - it neither succeeds nor errors -
/// so [TileLayer.fallbackUrl] is never triggered and the map just stays
/// blank forever instead of falling back to OSM.
class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() => _inner.close();
}

/// Street tiles. Carto Voyager is the default look (muted, overlay-friendly)
/// and needs a key compiled in via --dart-define=CARTO_API_KEY: without one
/// Carto answers 200 with an "API key required" watermark image, so the OSM
/// fallback does not kick in. OSM is the fallback if a Carto tile 404s or
/// times out. Stadia replaces Carto when --dart-define=STADIA_API_KEY is set.
class AppMapTileLayer extends StatelessWidget {
  const AppMapTileLayer({super.key});

  static const stadiaApiKey = String.fromEnvironment('STADIA_API_KEY');
  static const cartoApiKey = String.fromEnvironment('CARTO_API_KEY');
  static const _stadiaUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png';
  static const _cartoUrl =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static bool get usesStadia => stadiaApiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: usesStadia
          ? '$_stadiaUrl?api_key=$stadiaApiKey'
          : '$_cartoUrl?key=$cartoApiKey',
      fallbackUrl: _osmUrl,
      userAgentPackageName: 'com.labgo.app',
      // Must be a mutable map: flutter_map injects User-Agent into it.
      tileProvider: NetworkTileProvider(
        headers: {'User-Agent': 'LabGo/1.0 (com.labgo.app; healthcare)'},
        httpClient: _TimeoutHttpClient(http.Client(), const Duration(seconds: 8)),
      ),
      retinaMode: false,
      maxNativeZoom: 19,
      maxZoom: 19,
      keepBuffer: 4,
      panBuffer: 1,
      backgroundColor: const Color(0xFFE8EEF4),
      errorTileCallback: (tile, error, stackTrace) {
        // Intentionally not gated behind kDebugMode: debugPrint is a no-op
        // in neither mode, but that gate meant this never printed in a
        // release build - exactly the build where tile failures actually
        // needed diagnosing.
        debugPrint('Map tile failed (${tile.coordinates}): $error');
      },
    );
  }
}

class MapAttributionBadge extends StatelessWidget {
  const MapAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppMapTileLayer.usesStadia
        ? '© Stadia Maps © OSM'
        : '© CARTO © OSM';
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
        ),
      ),
    );
  }
}

class MapCenterPin extends StatelessWidget {
  const MapCenterPin({
    super.key,
    this.size = 52,
    this.photoUrl,
    this.name,
  });

  final double size;
  final String? photoUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()[0].toUpperCase()
        : '?';
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return SizedBox(
      width: size,
      height: size + 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppTheme.primaryColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth:
                          (size * MediaQuery.devicePixelRatioOf(context)).round(),
                      memCacheHeight:
                          (size * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorWidget: (_, __, ___) => _fallback(initial),
                    )
                  : _fallback(initial),
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinTipPainter(),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String initial) {
    return ColoredBox(
      color: const Color(0xFFEAE7FB),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.primaryColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
