import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'places_autocomplete_service.dart';

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

  /// Merges [unitOrApt] into [address] right after the street segment when
  /// [unitOrApt] is an apartment/unit/suite/building/floor identifier not yet
  /// present in [address], and [address] does not already contain a unit designator.
  static String composeNavigationAddress(String? address, [String? unitOrApt]) {
    final cleanAddress = address?.trim() ?? '';
    final cleanUnit = unitOrApt?.trim() ?? '';
    if (cleanAddress.isEmpty || cleanUnit.isEmpty) {
      return cleanAddress;
    }
    if (!PlacesAutocompleteService.isUnitOrAptIdentifier(cleanUnit)) {
      return cleanAddress;
    }
    if (PlacesAutocompleteService.containsAddressSegment(cleanAddress, cleanUnit)) {
      return cleanAddress;
    }
    // If cleanAddress already contains an explicit apartment/unit/suite designator
    // (e.g. "800 Energy Way, Apt 703, Chula Vista, CA 91911"), never inject a second
    // unit or hash gate code (e.g. "#4105") into the navigation address.
    final existingInlineUnit = PlacesAutocompleteService.extractInlineUnitOrApt(cleanAddress);
    if (existingInlineUnit.unitOrApt.isNotEmpty) {
      return cleanAddress;
    }
    final firstComma = cleanAddress.indexOf(',');
    if (firstComma > 0) {
      final street = cleanAddress.substring(0, firstComma).trim();
      final rest = cleanAddress.substring(firstComma + 1).trim();
      return '$street, $cleanUnit, $rest';
    }
    return '$cleanAddress, $cleanUnit';
  }

  /// Builds a cross-platform navigation URL given street address and/or coordinates.
  ///
  /// Destination resolution priority:
  /// 1. Encoded `address` string if non-empty (ensuring street numbers and apartment/unit
  ///    numbers like "Apt 703" are preserved as the primary destination instead of
  ///    being reverse-geocoded from a parcel/street centroid coordinate into a
  ///    different building/unit like "4105"). When valid finite `latitude` and
  ///    `longitude` are also provided, they are included via `&center=lat,lng`.
  /// 2. Coordinates (`latitude`, `longitude`) as `daddr`/`destination` if `address`
  ///    is null/empty and both coordinates are non-null and finite.
  /// 3. Returns empty string `""` if neither address nor valid coordinates are present.
  static String buildNavigationUrl({
    required double? latitude,
    required double? longitude,
    String? address,
    String? unitOrApt,
    TargetPlatform? platform,
  }) {
    final hasCoords = latitude != null &&
        longitude != null &&
        !latitude.isNaN &&
        !longitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isInfinite;

    final cleanAddress = composeNavigationAddress(address, unitOrApt);
    final hasAddress = cleanAddress.isNotEmpty;

    if (!hasCoords && !hasAddress) {
      return '';
    }

    final destination = hasAddress
        ? Uri.encodeComponent(cleanAddress)
        : '$latitude,$longitude';

    final centerSuffix = (hasAddress && hasCoords)
        ? '&center=$latitude,$longitude'
        : '';

    final target = platform ??
        _mockPlatform ??
        (kIsWeb ? null : defaultTargetPlatform);

    final isApple = target == TargetPlatform.iOS || target == TargetPlatform.macOS;

    if (isApple) {
      return 'https://maps.apple.com/?daddr=$destination$centerSuffix';
    } else {
      return 'https://www.google.com/maps/dir/?api=1&destination=$destination$centerSuffix';
    }
  }

  /// Launches turn-by-turn navigation in the native mapping application.
  ///
  /// Returns `true` if navigation was successfully launched, `false` otherwise.
  static Future<bool> launchNavigation({
    required double? latitude,
    required double? longitude,
    String? address,
    String? unitOrApt,
  }) async {
    final url = buildNavigationUrl(
      latitude: latitude,
      longitude: longitude,
      address: address,
      unitOrApt: unitOrApt,
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
