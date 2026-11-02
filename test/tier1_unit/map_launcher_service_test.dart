import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/services/map_launcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MapLauncherService.resetMockLauncher();
  });

  tearDown(() {
    MapLauncherService.resetMockLauncher();
  });

  group('MapLauncherService Unit Tests', () {
    // 1. Apple Maps URL Scheme Generation
    test('1.1 Generates Apple Maps URL on iOS with coordinates', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        platform: TargetPlatform.iOS,
      );
      expect(url, equals('https://maps.apple.com/?daddr=30.2672,-97.7431'));
    });

    test('1.2 Generates Apple Maps URL on macOS with coordinates', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        platform: TargetPlatform.macOS,
      );
      expect(url, equals('https://maps.apple.com/?daddr=30.2672,-97.7431'));
    });

    // 2. Google Maps URL Scheme Generation
    test('2.1 Generates Google Maps URL on Android with coordinates', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        platform: TargetPlatform.android,
      );
      expect(url, equals('https://www.google.com/maps/dir/?api=1&destination=30.2672,-97.7431'));
    });

    test('2.2 Generates Google Maps URL for web and desktop fallback', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        platform: TargetPlatform.linux,
      );
      expect(url, equals('https://www.google.com/maps/dir/?api=1&destination=30.2672,-97.7431'));
    });

    // 3. Coordinate vs. Address Fallback
    test('3.1 Coordinates take precedence over address when both provided', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        address: '1200 S Congress Ave, Austin, TX',
        platform: TargetPlatform.android,
      );
      expect(url, contains('destination=30.2672,-97.7431'));
    });

    test('3.2 Falls back to address when coordinates are null', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: '1200 S Congress Ave, Austin, TX',
        platform: TargetPlatform.android,
      );
      expect(url, equals('https://www.google.com/maps/dir/?api=1&destination=1200%20S%20Congress%20Ave%2C%20Austin%2C%20TX'));
    });

    test('3.3 Falls back to address when coordinates are NaN', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: double.nan,
        longitude: double.nan,
        address: '500 E 4th St, Austin, TX',
        platform: TargetPlatform.iOS,
      );
      expect(url, equals('https://maps.apple.com/?daddr=500%20E%204th%20St%2C%20Austin%2C%20TX'));
    });

    test('3.4 Returns empty string when both coordinates and address are empty', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: '',
      );
      expect(url, isEmpty);
    });

    // 4. URL Encoding for Complex Address Strings
    test('4.1 Properly encodes complex address strings with unit numbers, commas, and spaces', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: '#402, 123 Main St, New York, NY',
        platform: TargetPlatform.android,
      );
      expect(url, contains('destination=%23402%2C%20123%20Main%20St%2C%20New%20York%2C%20NY'));
      expect(url, isNot(contains('#402'))); // Must not contain raw hash symbol
    });

    test('4.2 Encodes ampersands and special symbols safely', () {
      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: 'Studio & Spa, Suite 5/B, San José, CA',
        platform: TargetPlatform.iOS,
      );
      expect(url, contains('daddr=Studio%20%26%20Spa%2C%20Suite%205%2FB%2C%20San%20Jos%C3%A9%2C%20CA'));
    });

    // 5. Mock Launcher Callback Hook
    test('5.1 Intercepts launch via setMockLauncher without native plugin call', () async {
      String? launchedUrl;
      MapLauncherService.setMockLauncher((url) async {
        launchedUrl = url;
        return true;
      });

      final success = await MapLauncherService.launchNavigation(
        latitude: 30.2505,
        longitude: -97.7495,
      );

      expect(success, isTrue);
      expect(launchedUrl, isNotNull);
      expect(launchedUrl, contains('30.2505'));
    });

    test('5.2 Propagates false return value from mock launcher', () async {
      MapLauncherService.setMockLauncher((url) async => false);
      final success = await MapLauncherService.launchNavigation(
        latitude: 30.2505,
        longitude: -97.7495,
      );
      expect(success, isFalse);
    });

    // 6. Defensive Failure Handling
    test('6.1 Catches exceptions thrown by mock launcher gracefully and returns false', () async {
      MapLauncherService.setMockLauncher((url) async {
        throw Exception('Simulated launcher failure');
      });

      final success = await MapLauncherService.launchNavigation(
        latitude: 30.2505,
        longitude: -97.7495,
      );
      expect(success, isFalse);
    });

    test('6.2 Returns false immediately if both coordinates and address are invalid', () async {
      var launcherCalled = false;
      MapLauncherService.setMockLauncher((url) async {
        launcherCalled = true;
        return true;
      });

      final success = await MapLauncherService.launchNavigation(
        latitude: null,
        longitude: null,
        address: null,
      );
      expect(success, isFalse);
      expect(launcherCalled, isFalse);
    });
  });
}
