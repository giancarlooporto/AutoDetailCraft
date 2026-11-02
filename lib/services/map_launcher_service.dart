import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cross-platform map navigation launcher supporting Apple Maps and Google Maps
/// with deterministic testing hooks.
class MapLauncherService {
  static Future<bool> Function(String url)? _mockLauncher;
  static TargetPlatform? _mockPlatform;

  /// Sets a mock launcher callback to intercept URL launches during testing.
  static void setMockLauncher(Future<bool> Function(String url)? launcher) {
    _mockLauncher = launcher;
  }

  /// Sets a mock target platform for deterministic URL scheme testing.
  static void setMockPlatform(TargetPlatform? platform) {
    _mockPlatform = platform;
  }

  /// Clears configured mock launcher and mock platform.
  static void resetMockLauncher() {
    _mockLauncher = null;
    _mockPlatform = null;
  }

  /// Builds a cross-platform navigation URL given coordinates or street address.
  ///
  /// Destination resolution priority:
  /// 1. Coordinates (`latitude`, `longitude`) if both are non-null and finite.
  /// 2. Encoded `address` string if coordinates are missing/invalid.
  /// 3. Returns empty string `""` if neither coordinates nor address are present.
  static String buildNavigationUrl({
    required double? latitude,
    required double? longitude,
    String? address,
    TargetPlatform? platform,
  }) {
    final hasCoords = latitude != null &&
        longitude != null &&
        !latitude.isNaN &&
        !longitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isInfinite;

    final cleanAddress = address?.trim() ?? '';
    final hasAddress = cleanAddress.isNotEmpty;

    if (!hasCoords && !hasAddress) {
      return '';
    }

    final destination = hasCoords
        ? '$latitude,$longitude'
        : Uri.encodeComponent(cleanAddress);

    final target = platform ??
        _mockPlatform ??
        (kIsWeb ? null : defaultTargetPlatform);

    final isApple = target == TargetPlatform.iOS || target == TargetPlatform.macOS;

    if (isApple) {
      return 'https://maps.apple.com/?daddr=$destination';
    } else {
      return 'https://www.google.com/maps/dir/?api=1&destination=$destination';
    }
  }

  /// Launches turn-by-turn navigation in the native mapping application.
  ///
  /// Returns `true` if navigation was successfully launched, `false` otherwise.
  static Future<bool> launchNavigation({
    required double? latitude,
    required double? longitude,
    String? address,
  }) async {
    final url = buildNavigationUrl(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );

    if (url.isEmpty) {
      return false;
    }

    if (_mockLauncher != null) {
      try {
        return await _mockLauncher!(url);
      } catch (e) {
        return false;
      }
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
