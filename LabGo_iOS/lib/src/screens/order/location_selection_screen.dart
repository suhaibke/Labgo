import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../../../l10n/app_localizations.dart';

// Search result model
class SearchResult {
  final String displayName;
  final String address;
  final LatLng latLng;

  SearchResult({
    required this.displayName,
    required this.address,
    required this.latLng,
  });
}

// Full screen map page
class FullScreenMapPage extends StatefulWidget {
  final LatLng initialLocation;
  final Function(LatLng) onLocationSelected;

  const FullScreenMapPage({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  late MapController _mapController;
  LatLng _selectedLocation;
  Marker? _marker;
  double _currentZoom = 16;

  _FullScreenMapPageState() : _selectedLocation = const LatLng(33.3152, 44.3661);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
    _updateMarker();

    // Move to location after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController.move(_selectedLocation, _currentZoom);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _updateMarker() {
    setState(() {
      _marker = Marker(
        point: _selectedLocation,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on_rounded,
            size: 30,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _updateMarker();
    });
  }

  void _zoomIn() {
    if (_currentZoom < 19) {
      _currentZoom++;
      _mapController.move(_mapController.camera.center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_currentZoom > 10) {
      _currentZoom--;
      _mapController.move(_mapController.camera.center, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select precise location',
          style: TextStyle(
            color: AppTheme.gray900,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onLocationSelected(_selectedLocation);
              Navigator.pop(context);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: _currentZoom,
              minZoom: 10,
              maxZoom: 19,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (MapEvent event) {
                if (event is MapEventWithMove) {
                  setState(() {
                    _currentZoom = event.camera.zoom;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.labgo.app',
                maxZoom: 19,
              ),
              if (_marker != null) MarkerLayer(markers: [_marker!]),
            ],
          ),

          // Zoom controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: _zoomIn,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gray200,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.gray700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: _zoomOut,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gray200,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.remove_rounded,
                        color: AppTheme.gray700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center crosshair
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tap anywhere on the map to drop the pin',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationSelectionScreen extends StatefulWidget {
  final OrderLocation? initialLocation;

  const LocationSelectionScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  MapController? _mapController;
  LatLng _selectedLocation = const LatLng(33.3152, 44.3661); // Default: Baghdad
  Marker? _marker;
  bool _isLoading = true;
  bool _isGettingLocation = false;
  bool _isSearching = false;

  // Address controller
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Search results
  List<SearchResult> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLocation != null) {
      _selectedLocation = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _addressController.text = widget.initialLocation!.address;
      _updateMarker();
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Request to enable location service
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) {
          setState(() {
            _isLoading = false;
            _isGettingLocation = false;
          });
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _updateMarker();
          _isLoading = false;
          _isGettingLocation = false;
        });

        // Move map to user's location
        _mapController?.move(_selectedLocation, 16);

        // Reverse geocode to get address
        _getAddressFromCoordinates(position.latitude, position.longitude);
      }
    } catch (e) {
      // If getting location fails, just load the map with default location
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGettingLocation = false;
        });
      }
    }
  }

  // Search location using Nominatim (OpenStreetMap's free geocoding)
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&countrycodes=iq&format=json&limit=5&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'LabGo App',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final results = data.map((item) {
          return SearchResult(
            displayName: item['display_name']?.toString() ?? '',
            address: _formatAddress(item['address'] ?? {}),
            latLng: LatLng(
              double.parse(item['lat']?.toString() ?? '0.0'),
              double.parse(item['lon']?.toString() ?? '0.0'),
            ),
          );
        }).toList();

        setState(() {
          _searchResults = results;
          _showSearchResults = true;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
    }
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    if (address['house_number'] != null) parts.add(address['house_number']);
    if (address['road'] != null) parts.add(address['road']);
    if (address['neighbourhood'] != null) parts.add(address['neighbourhood']);
    if (address['suburb'] != null) parts.add(address['suburb']);
    if (address['city'] != null || address['town'] != null || address['village'] != null) {
      parts.add(address['city'] ?? address['town'] ?? address['village']);
    }
    if (address['country'] != null) parts.add(address['country']);

    return parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'LabGo App',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null && mounted) {
          setState(() {
            _addressController.text = _formatAddress(data['address'] ?? {});
          });
        }
      }
    } catch (e) {
      // Silently fail - user will enter address manually
    }
  }

  void _selectSearchResult(SearchResult result) {
    setState(() {
      _selectedLocation = result.latLng;
      _addressController.text = result.address;
      _showSearchResults = false;
      _searchController.clear();
      _updateMarker();
    });

    // Move map to selected location
    _mapController?.move(result.latLng, 16);
  }

  void _updateMarker() {
    setState(() {
      _marker = Marker(
        point: _selectedLocation,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on_rounded,
            size: 30,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedLocation = point);
    _updateMarker();
    _getAddressFromCoordinates(point.latitude, point.longitude);
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMapPage(
          initialLocation: _selectedLocation,
          onLocationSelected: (LatLng newLocation) {
            setState(() {
              _selectedLocation = newLocation;
              _updateMarker();
            });
            _getAddressFromCoordinates(newLocation.latitude, newLocation.longitude);
            _mapController?.move(newLocation, 16);
          },
        ),
      ),
    );
  }

  void _confirmLocation() {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterAddress),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final location = OrderLocation(
      address: _addressController.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );

    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.selectLocation),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search input
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.gray50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.gray200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.search_rounded,
                          color: AppTheme.gray400,
                          size: 22,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            hintStyle: const TextStyle(
                              color: AppTheme.gray400,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length >= 3) {
                              _searchLocation(value);
                            } else if (value.isEmpty) {
                              setState(() {
                                _searchResults = [];
                                _showSearchResults = false;
                              });
                            }
                          },
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Search results dropdown
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: AppTheme.gray200,
                        width: 1,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppTheme.gray100,
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.place_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            result.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gray900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 2,
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.loadingMap,
                          style: const TextStyle(
                            color: AppTheme.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _openFullScreenMap,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation,
                            initialZoom: 14,
                            minZoom: 10,
                            maxZoom: 19,
                            onTap: _onMapTap,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.labgo.app',
                              maxZoom: 19,
                            ),
                            if (_marker != null) MarkerLayer(markers: [_marker!]),
                          ],
                        ),
                        // Full screen button
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 4,
                            child: InkWell(
                              onTap: _openFullScreenMap,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.gray200,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fullscreen_rounded,
                                  color: AppTheme.gray700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Current location button
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 4,
                            child: InkWell(
                              onTap: _isGettingLocation ? null : _getCurrentLocation,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.gray200,
                                    width: 1,
                                  ),
                                ),
                                child: _isGettingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        color: AppTheme.primaryColor,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // Center pin indicator
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        // Full screen hint
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_full_rounded,
                                  size: 14,
                                  color: AppTheme.gray600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to open full screen',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.gray600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Address Form
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.dragPinToAdjust,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.gray700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Address (Required)
                    Text(
                      '${l10n.address} *',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gray200,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: l10n.enterAddress,
                          hintStyle: const TextStyle(
                            color: AppTheme.gray400,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    // Coordinates display
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gray200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.gps_fixed,
                            color: AppTheme.gray400,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.gray600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmLocation,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppTheme.primaryColor, Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.confirmLocation,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
