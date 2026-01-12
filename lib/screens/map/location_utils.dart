import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class LocationUtils {
  // In-memory cache for geocoding results
  static final Map<String, String> _addressCache = {};

  // Function to calculate distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1 = point1.latitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  // Get a human-readable address from coordinates with caching
  static Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    // Create a cache key with reasonable precision (5 decimal places is ~1 meter accuracy)
    String cacheKey =
        "${coordinates.latitude.toStringAsFixed(5)},${coordinates.longitude.toStringAsFixed(5)}";

    // Check if this location is already cached
    if (_addressCache.containsKey(cacheKey)) {
      print("Using cached address for $cacheKey");
      return _addressCache[cacheKey];
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;

        // Build the address string
        List<String> addressParts = [];
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          addressParts.add(placemark.country!);
        }

        String address = addressParts.join(', ');

        // Cache the result
        _addressCache[cacheKey] = address;

        return address;
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return null;
  }

  // Method to clear cache if needed
  static void clearAddressCache() {
    _addressCache.clear();
  }
}
