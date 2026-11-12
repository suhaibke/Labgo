import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map_tiles.dart';

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
  late final MapController _mapController;
  late LatLng _selectedLocation;
  String? _profilePhotoUrl;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getUserData();
    if (!mounted || user == null) return;
    setState(() {
      _profilePhotoUrl = ApiService.resolveMediaUrl(user['profilePicture']?.toString());
      _profileName = user['name']?.toString();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.setOnMap,
          style: const TextStyle(
            color: AppTheme.gray900,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onLocationSelected(_selectedLocation);
              Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context)!.confirmLocation,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
              initialZoom: 16,
              minZoom: 5,
              maxZoom: 20,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _selectedLocation = event.camera.center;
                }
              },
            ),
            children: const [AppMapTileLayer()],
          ),
          IgnorePointer(
            child: Center(
              child: MapCenterPin(
                photoUrl: _profilePhotoUrl,
                name: _profileName,
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 16,
            child: MapAttributionBadge(),
          ),
        ],
      ),
    );
  }
}

class LocationSelectionScreen extends StatefulWidget {
  final OrderLocation? initialLocation;
  /// When true, the screen cannot be dismissed without picking a location
  /// (no back button, system back gesture disabled).
  final bool mandatory;

  const LocationSelectionScreen({
    super.key,
    this.initialLocation,
    this.mandatory = false,
  });

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(33.3152, 44.3661);
  bool _isGettingLocation = false;
  bool _isSearching = false;
  bool _mapReady = false;

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<SearchResult> _searchResults = [];
  bool _showSearchResults = false;
  Timer? _searchDebounce;
  String? _profilePhotoUrl;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    if (initial != null) {
      _selectedLocation = LatLng(initial.latitude, initial.longitude);
      _addressController.text = initial.address;
      _landmarkController.text = initial.landmark ?? '';
      _phoneController.text = initial.phone ?? '';
    }
    _loadProfile();
    // Only jump to live GPS when there is no previously saved location;
    // otherwise the saved pin would be silently replaced on open. The user
    // can still tap the "my location" button to use GPS.
    if (initial == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getUserData();
    if (!mounted || user == null) return;
    setState(() {
      _profilePhotoUrl = ApiService.resolveMediaUrl(user['profilePicture']?.toString());
      _profileName = user['name']?.toString();
      if (_phoneController.text.isEmpty) {
        _phoneController.text = user['phone']?.toString() ?? '';
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _landmarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        enabled = await Geolocator.openLocationSettings();
        if (!enabled) return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = point);
      if (_mapReady) {
        _mapController.move(point, 16.5);
      }
    } catch (_) {
      // Keep last / default pin.
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _searchLocation(value);
    });
  }

  Future<void> _searchLocation(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&countrycodes=iq&format=json&limit=5&addressdetails=1',
        ),
        headers: {'User-Agent': 'LabGo App'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = data.map((item) {
            return SearchResult(
              displayName: item['display_name']?.toString() ?? '',
              address: item['display_name']?.toString() ?? '',
              latLng: LatLng(
                double.tryParse(item['lat']?.toString() ?? '') ?? 0,
                double.tryParse(item['lon']?.toString() ?? '') ?? 0,
              ),
            );
          }).toList();
          _showSearchResults = _searchResults.isNotEmpty;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchResult(SearchResult result) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = result.latLng;
      _showSearchResults = false;
      _searchController.clear();
    });
    _mapController.move(result.latLng, 16.5);
  }

  void _confirmLocation() {
    final l10n = AppLocalizations.of(context)!;
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterAddress),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterYourPhoneNumber),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      OrderLocation(
        address: _addressController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        landmark: _optional(_landmarkController),
        phone: _phoneController.text.trim(),
      ),
    );
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  widget.mandatory
                      ? const SizedBox(width: 48)
                      : IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                  Expanded(
                    child: Text(
                      l10n.selectLocation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1444),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: 300,
                child: _buildMap(l10n),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.gray200,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        children: [
                          _plainField(
                            label: '${l10n.address} *',
                            controller: _addressController,
                            hint: l10n.enterAddress,
                          ),
                          const SizedBox(height: 8),
                          _plainField(
                            label: l10n.landmark,
                            controller: _landmarkController,
                            hint: l10n.enterLandmark,
                          ),
                          const SizedBox(height: 8),
                          _plainField(
                            label: l10n.phoneNumber,
                            controller: _phoneController,
                            hint: l10n.enterYourPhoneNumber,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            l10n.confirmLocation,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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
    );
  }

  Widget _buildMap(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              minZoom: 5,
              maxZoom: 20,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapReady = true;
                _mapController.move(_selectedLocation, 15.8);
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _selectedLocation = event.camera.center;
                }
              },
            ),
            children: const [
              AppMapTileLayer(),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: MapCenterPin(
                photoUrl: _profilePhotoUrl,
                name: _profileName,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              children: [
                _searchBar(l10n),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  _searchResultsCard(),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _mapFab(
                  icon: Icons.add_rounded,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    (_mapController.camera.zoom + 1).clamp(5, 20),
                  ),
                ),
                const SizedBox(height: 8),
                _mapFab(
                  icon: Icons.remove_rounded,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    (_mapController.camera.zoom - 1).clamp(5, 20),
                  ),
                ),
                const SizedBox(height: 8),
                _mapFab(
                  icon: Icons.my_location_rounded,
                  loading: _isGettingLocation,
                  accent: true,
                  onTap: _isGettingLocation
                      ? null
                      : () => _getCurrentLocation(),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: MapAttributionBadge(),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(AppLocalizations l10n) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: l10n.setOnMap,
            hintStyle: const TextStyle(
              color: AppTheme.gray400,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.gray400),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.gray400),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _searchResultsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 168),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(TablerIcons.map_pin, color: AppTheme.primaryColor),
            title: Text(
              result.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1444),
              ),
            ),
            onTap: () => _selectSearchResult(result),
          );
        },
      ),
    );
  }

  Widget _mapFab({
    required IconData icon,
    VoidCallback? onTap,
    bool loading = false,
    bool accent = false,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : Icon(
                  icon,
                  color: accent ? AppTheme.primaryColor : const Color(0xFF1B1444),
                  size: 20,
                ),
        ),
      ),
    );
  }

  Widget _plainField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1444),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppTheme.gray400,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.backgroundLavender,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
