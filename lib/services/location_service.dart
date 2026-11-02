// =========================================================================
// File: lib/services/location_service.dart
// Description: Device GPS wrapper & pure-Dart Haversine distance calculator
// =========================================================================

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Immutable representation of geographical coordinates (latitude and longitude).
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationCoordinates &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'LocationCoordinates(latitude: $latitude, longitude: $longitude)';
}

/// Lightweight service wrapping device geolocation and providing pure-Dart
/// Haversine distance calculations without billable external API requests ($0.00).
class LocationService {
  /// Spherical radius of Earth in statute miles.
  static const double earthRadiusMiles = 3958.8;

  /// Deterministic mock provider hook for zero-hardware unit and widget tests.
  static Future<LocationCoordinates?> Function()? _mockLocationProvider;

  /// Sets a mock location provider to simulate location states deterministically.
  static void setMockLocationProvider(Future<LocationCoordinates?> Function()? provider) {
    _mockLocationProvider = provider;
  }

  /// Clears any configured mock provider, restoring default hardware execution.
  static void resetMockLocationProvider() {
    _mockLocationProvider = null;
  }

  /// Retrieves current device GPS coordinates with safe permission checks and fallbacks.
  /// Returns null if location services are disabled, permissions are denied,
  /// or if an error / timeout occurs.
  static Future<LocationCoordinates?> getCurrentLocation() async {
    // 1. Zero-hardware test hook override
    if (_mockLocationProvider != null) {
      try {
        return await _mockLocationProvider!();
      } catch (e) {
        if (kDebugMode) {
          print('[LocationService] Mock location provider threw error: $e');
        }
        return null;
      }
    }

    try {
      // 2. Check if device location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (kDebugMode) {
          print('[LocationService] Location services are disabled on device.');
        }
        return null;
      }

      // 3. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('[LocationService] Location permission denied by user.');
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('[LocationService] Location permission permanently denied.');
        }
        return null;
      }

      // 4. Retrieve current position with balanced accuracy and timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[LocationService] Error acquiring location: $e');
      }
      return null;
    }
  }

  /// Calculates the great-circle distance in miles between two coordinates
  /// using the pure-Dart Haversine formula (Earth radius: 3958.8 miles).
  ///
  /// Executed in-app with $0.00 external API quota consumption.
  static double calculateDistanceMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    if (lat1 == lat2 && lon1 == lon2) return 0.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final radLat1 = _degToRad(lat1);
    final radLat2 = _degToRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radLat1) * math.cos(radLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final clampedA = a.clamp(0.0, 1.0);
    final c = 2 * math.asin(math.sqrt(clampedA));

    return earthRadiusMiles * c;
  }

  /// Formats distance in miles into a user-friendly label (e.g. "1.2 mi away").
  /// Returns empty string `""` for null, negative, NaN, or infinite values.
  static String formatDistance(double? miles) {
    if (miles == null || miles.isNaN || miles.isInfinite || miles < 0) return '';
    if (miles < 0.1) return 'Under 0.1 mi away';
    if (miles < 10.0) return '${miles.toStringAsFixed(1)} mi away';
    return '${miles.round()} mi away';
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
