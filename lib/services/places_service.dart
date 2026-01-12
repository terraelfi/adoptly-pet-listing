import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/shop_place.dart';
import 'env_config.dart';

class PlacesService {
  // Google Places API key loaded from environment
  static String get placesApiKey => EnvConfig.googlePlacesApiKey;

  static const _nearbyBase =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const _photoBase = 'https://maps.googleapis.com/maps/api/place/photo';

  // Simple in-memory cache to avoid excessive requests on the free tier
  static final Map<String, List<ShopPlace>> _nearbyCache = {};
  static final Map<String, DateTime> _nearbyCacheTime = {};

  // Cache TTL to limit requests. E.g., 5 minutes.
  static const Duration _cacheTtl = Duration(minutes: 5);

  static String buildPhotoUrl(String photoReference, {int maxWidth = 400}) {
    final uri = Uri.parse(_photoBase).replace(
      queryParameters: {
        'maxwidth': maxWidth.toString(),
        'photo_reference': photoReference,
        'key': placesApiKey,
      },
    );
    return uri.toString();
  }

  static Future<List<ShopPlace>> getNearbyPetShops({
    required LatLng location,
    required double radiusKm,
  }) async {
    // Cap radius at 10km as requested
    final double boundedKm = radiusKm.clamp(0.5, 10.0);
    final int radiusMeters = (boundedKm * 1000).round();

    // Cache key by lat/lng rounded to 3 decimals (~100m) + radius
    final String key =
        '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}:$radiusMeters';

    // Serve from cache if fresh
    final now = DateTime.now();
    if (_nearbyCache.containsKey(key)) {
      final cachedAt = _nearbyCacheTime[key];
      if (cachedAt != null && now.difference(cachedAt) < _cacheTtl) {
        return _nearbyCache[key]!;
      }
    }

    final uri = Uri.parse(_nearbyBase).replace(
      queryParameters: {
        'location': '${location.latitude},${location.longitude}',
        'radius': radiusMeters.toString(),
        'type': 'pet_store',
        'key': placesApiKey,
        // fields are for Place Details; Nearby supports keyword/opennow. Keep minimal.
      },
    );

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      final List results = (data['results'] as List?) ?? [];
      final places =
          results
              .map((raw) {
                final m = raw as Map<String, dynamic>;
                final geometry = m['geometry'] as Map<String, dynamic>?;
                final loc =
                    geometry != null
                        ? geometry['location'] as Map<String, dynamic>?
                        : null;
                final photos = (m['photos'] as List?) ?? [];
                final firstPhoto =
                    photos.isNotEmpty
                        ? photos.first as Map<String, dynamic>
                        : null;
                return ShopPlace(
                  placeId: (m['place_id'] as String?) ?? '',
                  name: (m['name'] as String?) ?? 'Pet Shop',
                  address: m['vicinity'] as String?,
                  location: LatLng(
                    (loc?['lat'] as num?)?.toDouble() ?? 0,
                    (loc?['lng'] as num?)?.toDouble() ?? 0,
                  ),
                  rating: (m['rating'] as num?)?.toDouble(),
                  userRatingsTotal: (m['user_ratings_total'] as num?)?.toInt(),
                  openNow:
                      (m['opening_hours'] as Map<String, dynamic>?)?['open_now']
                          as bool?,
                  photoReference:
                      firstPhoto != null
                          ? firstPhoto['photo_reference'] as String?
                          : null,
                );
              })
              .whereType<ShopPlace>()
              .toList();

      _nearbyCache[key] = places;
      _nearbyCacheTime[key] = now;
      return places;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PlacesService error: $e');
      }
      return [];
    }
  }
}

