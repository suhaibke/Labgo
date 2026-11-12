import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import 'app_map_tiles.dart';

/// Plots the patient and technician with profile-photo pins, a driving
/// route between them, and the distance in km sitting on the path.
class TrackingMap extends StatefulWidget {
  final LatLng? labLocation;
  final LatLng? patientLocation;
  final LatLng? nurseLocation;
  final String? patientPhotoUrl;
  final String? nursePhotoUrl;
  final String? patientName;
  final String? nurseName;
  final double height;

  const TrackingMap({
    super.key,
    this.labLocation,
    this.patientLocation,
    this.nurseLocation,
    this.patientPhotoUrl,
    this.nursePhotoUrl,
    this.patientName,
    this.nurseName,
    this.height = 240,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  static const _haversine = Distance();

  final MapController _mapController = MapController();
  List<LatLng> _route = const [];
  double? _routeKm;
  String? _routeKey;
  bool _hasFitBounds = false;

  List<LatLng> get _points => [
        if (widget.labLocation != null) widget.labLocation!,
        if (widget.patientLocation != null) widget.patientLocation!,
        if (widget.nurseLocation != null) widget.nurseLocation!,
      ];

  LatLng? get _from => widget.nurseLocation ?? widget.labLocation;
  LatLng? get _to => widget.patientLocation;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    // Don't also schedule a postFrameCallback here: MapOptions.onMapReady
    // (below) is flutter_map's own signal that its camera is actually
    // attached and safe to move. Racing it with a blind postFrameCallback
    // meant fitCamera could be called before the camera was ready - in a
    // release build that race went the wrong way more often (faster raw
    // execution vs. onMapReady's setup work), throwing partway through and
    // leaving the camera in an invalid state, which then can't resolve any
    // real tile and paints as a permanently blank/grey map.
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadRoute();
    // Only auto-fit the camera the first time we get enough points to show
    // a route (e.g. the technician's marker just appeared). Never re-fit
    // after that, so periodic location refreshes don't fight the user's
    // own pan/zoom.
    if (!_hasFitBounds && _points.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsOnce());
    }
  }

  void _fitBoundsOnce() {
    if (_hasFitBounds || !mounted) return;
    final points = _points;
    if (points.length < 2) return;

    // The vertical padding used to be a fixed 56/40, which is more than
    // half of this widget's own height on the compact card usages (120 and
    // 175px) - on a map that short, padding alone can exceed the available
    // space, so fitCamera has to solve for an extreme/degenerate zoom to
    // satisfy it. That computed zoom can land outside any real tile
    // coverage, which paints as a permanently blank/grey map. Scale the
    // padding down for short maps, and clamp the resulting zoom to a sane
    // range as a hard backstop regardless of the padding math.
    final verticalPadding = (widget.height * 0.12).clamp(8.0, 40.0);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: verticalPadding),
          minZoom: 3,
          maxZoom: 17,
        ),
      );
      // Only latch once fitCamera actually succeeds - if it's called before
      // flutter_map's camera is attached and throws, leave this false so
      // the next trigger (onMapReady, or a later didUpdateWidget) can retry
      // instead of the map being stuck with whatever broken state a failed
      // attempt left it in.
      _hasFitBounds = true;
    } catch (error, stackTrace) {
      debugPrint('TrackingMap: fitCamera failed, will retry on next trigger: $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  Future<void> _loadRoute() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      if (_route.isNotEmpty) {
        setState(() {
          _route = const [];
          _routeKm = null;
          _routeKey = null;
        });
      }
      return;
    }

    final key =
        '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}-'
        '${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
    if (key == _routeKey) return;

    setState(() {
      _routeKey = key;
    });

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'LabGo/1.0 (com.labgo.app)',
      }).timeout(const Duration(seconds: 8));

      if (!mounted || key != _routeKey) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final meters = (route['distance'] as num?)?.toDouble();
          final coords =
              (route['geometry'] as Map?)?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            setState(() {
              _route = [
                for (final c in coords)
                  if (c is List && c.length >= 2)
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              ];
              _routeKm = meters != null ? meters / 1000 : null;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Fall through to the curved fallback.
    }

    if (!mounted || key != _routeKey) return;
    setState(() {
      _route = _arc(from, to);
      _routeKm = _haversine.as(LengthUnit.Kilometer, from, to);
    });
  }

  /// Gentle quadratic arc so a missing OSRM response still looks like a path.
  List<LatLng> _arc(LatLng a, LatLng b) {
    final midLat = (a.latitude + b.latitude) / 2;
    final midLng = (a.longitude + b.longitude) / 2;
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final offset = 0.18;
    final control = LatLng(midLat + dx * offset, midLng - dy * offset);
    return [
      for (int i = 0; i <= 24; i++)
        _quad(a, control, b, i / 24),
    ];
  }

  LatLng _quad(LatLng a, LatLng c, LatLng b, double t) {
    final mt = 1 - t;
    return LatLng(
      mt * mt * a.latitude + 2 * mt * t * c.latitude + t * t * b.latitude,
      mt * mt * a.longitude + 2 * mt * t * c.longitude + t * t * b.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final points = _points;
    if (points.isEmpty) return const SizedBox.shrink();

    final center = points.length == 1
        ? points.first
        : LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) /
                points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) /
                points.length,
          );
    final path = _route.length >= 2 ? _route : null;
    final km = _routeKm ??
        (widget.nurseLocation != null && widget.patientLocation != null
            ? _haversine.as(
                LengthUnit.Kilometer,
                widget.nurseLocation!,
                widget.patientLocation!,
              )
            : null);
    final mid = path != null ? path[path.length ~/ 2] : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        // FlutterMap wraps every entry in its own `children` list in a
        // TranslucentPointer before adding it to its internal Stack, so a
        // Positioned passed there is no longer a *direct* Stack child and
        // throws "type 'ParentData' is not a subtype of type
        // 'StackParentData'" the moment it mounts - repeatedly, on every
        // rebuild, which was pinning the UI thread long enough to trigger
        // an ANR. The badge has to be positioned in a Stack of our own,
        // outside FlutterMap's children.
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onMapReady: _fitBoundsOnce,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                const AppMapTileLayer(),
                if (path != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: path,
                        color: Colors.white,
                        strokeWidth: 10,
                      ),
                      Polyline(
                        points: path,
                        gradientColors: const [
                          Color(0xFF7C5CFC),
                          Color(0xFF5B3FE8),
                          Color(0xFF7C5CFC),
                        ],
                        colorsStop: const [0.0, 0.5, 1.0],
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (widget.labLocation != null && widget.nurseLocation == null)
                      Marker(
                        point: widget.labLocation!,
                        width: 36,
                        height: 36,
                        child: _labDot(),
                      ),
                    if (widget.patientLocation != null)
                      Marker(
                        point: widget.patientLocation!,
                        width: 52,
                        height: 66,
                        alignment: Alignment.bottomCenter,
                        child: MapCenterPin(
                          size: 46,
                          photoUrl: widget.patientPhotoUrl,
                          name: widget.patientName,
                        ),
                      ),
                    if (widget.nurseLocation != null)
                      Marker(
                        point: widget.nurseLocation!,
                        width: 52,
                        height: 66,
                        alignment: Alignment.bottomCenter,
                        child: MapCenterPin(
                          size: 46,
                          photoUrl: widget.nursePhotoUrl,
                          name: widget.nurseName,
                        ),
                      ),
                    if (mid != null && km != null)
                      Marker(
                        point: mid,
                        width: 92,
                        height: 32,
                        child: _DistanceChip(
                          label:
                              '${km.toStringAsFixed(km >= 10 ? 0 : 1)} ${l10n.kilometersUnit}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Positioned(
              left: 8,
              bottom: 8,
              child: MapAttributionBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labDot() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final String label;

  const _DistanceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3FE8).withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFF7C5CFC), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF5B3FE8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1444),
            ),
          ),
        ],
      ),
    );
  }
}
