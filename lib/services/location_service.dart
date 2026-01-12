import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show pi, sin, cos, atan2;
import 'env_config.dart';

class LocationService {
  // Google Maps API key loaded from environment
  static String get _googleMapsApiKey => EnvConfig.googleMapsApiKey;

  // Get current location
  static Future<Map<String, double>> getCurrentLocation() async {
    try {
      debugPrint('Getting current location from device');

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Get current position with high accuracy
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
        'Retrieved position: ${position.latitude}, ${position.longitude}',
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Don't return default location anymore - throw the exception
      // so the UI can properly handle it
      throw e;
    }
  }

  // Get address from coordinates using Google's Geocoding API
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$_googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Get the first result's formatted address
          return data['results'][0]['formatted_address'];
        } else {
          debugPrint('Error getting address: ${data['status']}');
          return 'Unknown location';
        }
      } else {
        debugPrint('Error with geocoding request: ${response.statusCode}');
        return 'Unknown location';
      }
    } catch (e) {
      debugPrint('Error in getAddressFromCoordinates: $e');
      return 'Unknown location';
    }
  }

  // Get coordinates from address using Google's Geocoding API
  static Future<Map<String, double>?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          return {'latitude': location['lat'], 'longitude': location['lng']};
        } else {
          debugPrint('Error getting coordinates: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('Error with geocoding request: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in getCoordinatesFromAddress: $e');
      return null;
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Earth's radius in kilometers
    const double earthRadius = 6371.0;

    // Convert degrees to radians
    final double lat1Rad = _degreesToRadians(lat1);
    final double lon1Rad = _degreesToRadians(lon1);
    final double lat2Rad = _degreesToRadians(lat2);
    final double lon2Rad = _degreesToRadians(lon2);

    // Haversine formula components
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;

    // a = sin²(Δlat/2) + cos(lat1) · cos(lat2) · sin²(Δlon/2)
    final double a =
        pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);

    // c = 2 · atan2(√a, √(1−a))
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Distance = radius * c
    return earthRadius * c;
  }

  // Helper method to convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  // Math helper methods
  static double pow(double x, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= x;
    }
    return result;
  }

  static double sqrt(double value) {
    if (value == 0) return 0;
    if (value < 0) return double.nan;

    double result = value;
    double prev;

    // Newton's method for square root
    do {
      prev = result;
      result = (result + value / result) / 2;
    } while ((result - prev).abs() > 1e-9);

    return result;
  }

  // Helper methods for the Haversine formula
  static double _haversine(double theta) {
    return sin(theta / 2) * sin(theta / 2);
  }

  static double atan2(double y, double x) {
    return _getAtan2Result(y, x);
  }

  static double cos(double radians) {
    return _getCosResult(radians);
  }

  static double sin(double radians) {
    return _getSinResult(radians);
  }

  // Simple implementations of math functions
  static double _getAtan2Result(double y, double x) {
    if (x > 0) {
      return _arcTan(y / x);
    } else if (x < 0 && y >= 0) {
      return _arcTan(y / x) + pi;
    } else if (x < 0 && y < 0) {
      return _arcTan(y / x) - pi;
    } else if (x == 0 && y > 0) {
      return pi / 2;
    } else if (x == 0 && y < 0) {
      return -pi / 2;
    } else {
      return 0; // x = 0, y = 0
    }
  }

  static double _arcTan(double x) {
    // Simple approximation of arctan
    const a = 0.9997878412794807;
    const b = -0.3258083974640975;
    const c = 0.1555786518463281;
    const d = -0.04432655554792128;

    final xx = x * x;
    return x + x * xx * (a + xx * (b + xx * (c + xx * d)));
  }

  static double _getCosResult(double radians) {
    // Approximate cosine using Taylor series
    return sin(pi / 2 - radians);
  }

  static double _getSinResult(double radians) {
    // Normalize radians to [-π, π]
    radians = radians % (2 * pi);
    if (radians > pi) radians -= 2 * pi;
    if (radians < -pi) radians += 2 * pi;

    // Approximate sine using Taylor series (first 4 terms)
    final x3 = radians * radians * radians;
    final x5 = x3 * radians * radians;
    final x7 = x5 * radians * radians;

    return radians - x3 / 6 + x5 / 120 - x7 / 5040;
  }

  // Simple constant for pi
  static const double pi = 3.14159265358979323846;
}
