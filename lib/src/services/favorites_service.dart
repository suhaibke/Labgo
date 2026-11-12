import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';
import 'lab_service.dart';

/// Favorite labs bookmarked by the signed-in patient.
///
/// The set of favorite lab ids is cached in memory so list screens can paint
/// their heart icons without a round trip per card.
class FavoritesService {
  static const String _endpoint = '/app/favorites';

  static Set<String> _cachedIds = <String>{};
  static bool _loaded = false;

  /// Ids known locally. Empty until [loadIds] (or a toggle) has run.
  static Set<String> get cachedIds => _cachedIds;

  static bool isFavorite(String labId) => _cachedIds.contains(labId);

  static void clearCache() {
    _cachedIds = <String>{};
    _loaded = false;
  }

  /// Fetches the favorite ids and refreshes the cache.
  /// Returns false for guests or on any failure (the UI just shows no hearts).
  static Future<bool> loadIds({bool force = false}) async {
    if (_loaded && !force) return true;

    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        clearCache();
        return false;
      }

      final response = await ApiService.get('$_endpoint/ids', token: token);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final ids = (data['data']?['labIds'] as List?) ?? [];
        _cachedIds = ids.map((e) => e.toString()).toSet();
        _loaded = true;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Adds the lab to favorites, or removes it when already favorited.
  /// Returns `{'success': bool, 'isFavorite': bool, 'message': String?}`.
  static Future<Map<String, dynamic>> toggle(String labId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'requiresLogin': true};
      }

      final response = await ApiService.post(
        '$_endpoint/$labId/toggle',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final isFavorite = data['data']?['isFavorite'] == true;
        final ids = (data['data']?['labIds'] as List?) ?? [];
        _cachedIds = ids.map((e) => e.toString()).toSet();
        _loaded = true;
        return {
          'success': true,
          'isFavorite': isFavorite,
          'message': data['message'],
        };
      }

      return {
        'success': false,
        'message': data['message'],
      };
    } catch (_) {
      return {'success': false};
    }
  }

  /// Full lab objects for the favorites screen.
  static Future<Map<String, dynamic>> getFavoriteLabs() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'requiresLogin': true, 'labs': <Lab>[]};
      }

      final response = await ApiService.get(_endpoint, token: token);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawLabs = (data['data']?['labs'] as List?) ?? [];
        final labs = rawLabs
            .map((e) => Lab.fromJson(e as Map<String, dynamic>))
            .toList();

        // Keep the cache in sync with what the server just returned
        _cachedIds = labs.map((l) => l.id).toSet();
        _loaded = true;

        return {'success': true, 'labs': labs};
      }

      return {
        'success': false,
        'message': data['message'],
        'labs': <Lab>[],
      };
    } catch (_) {
      return {'success': false, 'labs': <Lab>[]};
    }
  }
}
