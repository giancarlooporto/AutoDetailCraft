// =========================================================================
// File: test/challenger/map_launcher_stress_test.dart
// Description: Adversarial empirical stress harness for MapLauncherService
//              (Milestone M3 Location & Navigation Handoff).
//
// Attack Vectors & Objectives:
// 1. Punctuation, Symbols, Unicode & Malicious Address Inputs:
//    - Complex suite/unit prefixes: '#402-B, Floor 3 & 1/2, Bldg @ Tech Ridge'.
//    - Non-ASCII, accented & international scripts: '100 Münchener Straße', 'São Paulo', '東京都'.
//    - Whitespace stress: tabs, newlines, carriage returns, leading/trailing spaces.
//    - Malicious inputs: SQL injection ('OR 1=1; DROP TABLE bookings;--'), XSS ('<script>alert(1)</script>'),
//      pre-encoded substrings ('%20%23%26%2F'), and 2,000+ character strings.
//    - URI RFC 3986 compliance: Uri.parse succeeds, no unencoded '#' in query, exact roundtrip decoding.
// 2. Coordinate Extremes, Non-Finite Floats & Precedence:
//    - Antipodal boundaries: (90.0, 180.0), (-90.0, -180.0), (0.0, 0.0), (-0.0, -0.0).
//    - Non-finite floating point oddities: double.nan, double.infinity, double.negativeInfinity.
//    - Mixed coordinate validity: (valid lat, NaN lon), (Inf lat, valid lon), (null lat, valid lon), etc.
//    - Coordinate precedence: valid coordinates must override address; non-finite coordinates must
//      cleanly fall back to address without throwing or generating malformed URLs.
//    - Null/empty handling: null coordinates + null or whitespace-only address must return empty string
//      and launchNavigation must return false without attempting launch.
// 3. Concurrent Execution & Mock Failure Resilience:
//    - 50 rapid concurrent invocations of launchNavigation via Future.wait.
//    - Mock launcher throwing synchronous Exception.
//    - Mock launcher throwing synchronous PlatformException.
//    - Mock launcher returning asynchronous Future.error(PlatformException).
//    - Unhandled exception shielding: launchNavigation must never bubble exceptions to caller.
// =========================================================================

import 'package:flutter/services.dart';
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

  group('Vector 1: Address Punctuation, Symbols, Unicode & Injection Attacks', () {
    test('1.1 Complex apartment/suite prefixes and symbols are safely encoded', () {
      const address = '#402-B, Floor 3 & 1/2, Bldg @ Tech Ridge';

      // Test on Apple Maps (iOS)
      final appleUrl = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: address,
        platform: TargetPlatform.iOS,
      );

      expect(appleUrl, isNotEmpty);
      expect(appleUrl.startsWith('https://maps.apple.com/?daddr='), isTrue);
      // '#' must be percent-encoded as '%23' so it is not treated as a URI fragment identifier
      expect(appleUrl, isNot(contains('#402-B')));
      expect(appleUrl, contains('%23402-B'));
      // '&' must be percent-encoded as '%26' so it does not fragment query parameters
      expect(appleUrl, contains('%26'));
      // '/' must be percent-encoded as '%2F'
      expect(appleUrl, contains('%2F'));
      // '@' must be percent-encoded as '%40'
      expect(appleUrl, contains('%40'));

      final parsedApple = Uri.parse(appleUrl);
      expect(parsedApple.scheme, equals('https'));
      expect(parsedApple.host, equals('maps.apple.com'));
      expect(parsedApple.queryParameters['daddr'], equals(address));

      // Test on Google Maps (Android)
      final googleUrl = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: address,
        platform: TargetPlatform.android,
      );

      expect(googleUrl, isNotEmpty);
      expect(googleUrl.startsWith('https://www.google.com/maps/dir/?api=1&destination='), isTrue);
      expect(googleUrl, isNot(contains('#402-B')));
      expect(googleUrl, contains('%23402-B'));

      final parsedGoogle = Uri.parse(googleUrl);
      expect(parsedGoogle.scheme, equals('https'));
      expect(parsedGoogle.host, equals('www.google.com'));
      expect(parsedGoogle.queryParameters['destination'], equals(address));
    });

    test('1.2 International, non-ASCII and UTF-8 multi-byte scripts', () {
      const addresses = [
        '100 Münchener Straße, 80331 München, Germany',
        'Avenida Paulista, 1578 - Bela Vista, São Paulo - SP, Brasil',
        '〒100-0001 東京都千代田区千代田1-1',
        'شارع الشيخ زايد, دبي, الإمارات العربية المتحدة',
        '500 Café & Crêperie, Montréal, QC H2Y 1C6, Canada',
      ];

      for (final addr in addresses) {
        for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
          final url = MapLauncherService.buildNavigationUrl(
            latitude: null,
            longitude: null,
            address: addr,
            platform: platform,
          );

          expect(url, isNotEmpty);
          final parsed = Uri.parse(url);
          final paramKey = platform == TargetPlatform.iOS ? 'daddr' : 'destination';
          expect(
            parsed.queryParameters[paramKey],
            equals(addr),
            reason: 'Address "$addr" must survive roundtrip encoding on $platform',
          );
        }
      }
    });

    test('1.3 Whitespace, newlines, tabs, and carriage returns are sanitized and encoded', () {
      const rawAddress = '  \n\t  1200 S Congress Ave  \r\n Suite 100 \t  \n';
      const expectedClean = '1200 S Congress Ave  \r\n Suite 100';

      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: rawAddress,
        platform: TargetPlatform.android,
      );

      expect(url, isNotEmpty);
      final parsed = Uri.parse(url);
      expect(parsed.queryParameters['destination'], equals(expectedClean));

      // Pure whitespace should collapse to empty URL
      const whitespaceOnly = '   \t\t \n\r\n   ';
      final emptyUrl = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: whitespaceOnly,
        platform: TargetPlatform.android,
      );
      expect(emptyUrl, isEmpty);
    });

    test('1.4 Malicious strings: SQL injection, XSS script tags, pre-encoded tokens', () {
      const attacks = [
        "123 Main St'; DROP TABLE bookings;--",
        '<script>alert("XSS")</script>',
        '"><img src=x onerror=alert(1)>',
        '100 Main St %20 %23 %26 %3D %3F',
        'param1=val1&param2=val2#fragment_leak',
      ];

      for (final payload in attacks) {
        final url = MapLauncherService.buildNavigationUrl(
          latitude: null,
          longitude: null,
          address: payload,
          platform: TargetPlatform.iOS,
        );

        // URL must be syntactically valid and parseable
        expect(() => Uri.parse(url), returnsNormally);
        final parsed = Uri.parse(url);

        // Crucial security invariant: Query parameter keys must NOT be polluted
        // If an unescaped '&param2=val2' leaked, queryParameters would contain 'param2'
        expect(parsed.queryParameters.containsKey('daddr'), isTrue);
        expect(
          parsed.queryParameters.containsKey('param2'),
          isFalse,
          reason: 'Unencoded ampersand must not inject new query parameters',
        );

        // Crucial security invariant: URI fragment must NOT be populated by address payload
        expect(
          parsed.hasFragment,
          isFalse,
          reason: 'Unencoded hash symbol must not become a URI fragment',
        );

        // Verify accurate payload roundtrip decoding
        expect(parsed.queryParameters['daddr'], equals(payload));
      }
    });

    test('1.5 Extreme string lengths (2,500+ characters) do not crash or corrupt URL', () {
      final longStreet = 'A' * 1500;
      final longCity = 'B' * 1000;
      final massiveAddress = '$longStreet, $longCity, TX 78701';

      final url = MapLauncherService.buildNavigationUrl(
        latitude: null,
        longitude: null,
        address: massiveAddress,
        platform: TargetPlatform.android,
      );

      expect(url, isNotEmpty);
      expect(url.length, greaterThan(2500));
      expect(() => Uri.parse(url), returnsNormally);
      final parsed = Uri.parse(url);
      expect(parsed.queryParameters['destination'], equals(massiveAddress));
    });
  });

  group('Vector 2: Coordinate Edge Cases, Extremes & Fallbacks', () {
    test('2.1 Antipodal and boundary coordinates format correctly', () {
      final testCoords = [
        {'lat': 90.0, 'lon': 180.0, 'expected': '90.0,180.0'},
        {'lat': -90.0, 'lon': -180.0, 'expected': '-90.0,-180.0'},
        {'lat': 0.0, 'lon': 0.0, 'expected': '0.0,0.0'},
        {'lat': -0.0, 'lon': -0.0, 'expected': '-0.0,-0.0'},
        {'lat': 89.999999, 'lon': -179.999999, 'expected': '89.999999,-179.999999'},
      ];

      for (final tc in testCoords) {
        final lat = tc['lat'] as double;
        final lon = tc['lon'] as double;
        final exp = tc['expected'] as String;

        // Apple Maps
        final appleUrl = MapLauncherService.buildNavigationUrl(
          latitude: lat,
          longitude: lon,
          platform: TargetPlatform.iOS,
        );
        expect(appleUrl, equals('https://maps.apple.com/?daddr=$exp'));

        // Google Maps
        final googleUrl = MapLauncherService.buildNavigationUrl(
          latitude: lat,
          longitude: lon,
          platform: TargetPlatform.android,
        );
        expect(googleUrl, equals('https://www.google.com/maps/dir/?api=1&destination=$exp'));
      }
    });

    test('2.2 Address string is used as primary destination while valid coordinates are passed as center', () {
      const address = '800 Energy Way, Apt 703, Chula Vista, CA 91911';
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
        address: address,
        platform: TargetPlatform.iOS,
      );

      expect(
        url,
        equals('https://maps.apple.com/?daddr=800%20Energy%20Way%2C%20Apt%20703%2C%20Chula%20Vista%2C%20CA%2091911&center=30.2672,-97.7431'),
      );
    });

    test('2.3 Non-finite coordinates (NaN, Infinity, -Infinity) fall back cleanly to address', () {
      const fallbackAddress = '700 Lavaca St, Austin, TX 78701';

      final nonFiniteCombinations = [
        {'lat': double.nan, 'lon': double.nan},
        {'lat': double.infinity, 'lon': double.infinity},
        {'lat': double.negativeInfinity, 'lon': double.negativeInfinity},
        {'lat': 30.2672, 'lon': double.nan},
        {'lat': double.nan, 'lon': -97.7431},
        {'lat': 30.2672, 'lon': double.infinity},
        {'lat': double.negativeInfinity, 'lon': -97.7431},
        {'lat': 30.2672, 'lon': null},
        {'lat': null, 'lon': -97.7431},
      ];

      for (final combo in nonFiniteCombinations) {
        final lat = combo['lat'];
        final lon = combo['lon'];

        final url = MapLauncherService.buildNavigationUrl(
          latitude: lat,
          longitude: lon,
          address: fallbackAddress,
          platform: TargetPlatform.android,
        );

        expect(
          url,
          equals('https://www.google.com/maps/dir/?api=1&destination=700%20Lavaca%20St%2C%20Austin%2C%20TX%2078701'),
          reason: 'Failed to fall back to address with lat: $lat, lon: $lon',
        );
      }
    });

    test('2.4 Non-finite coordinates with empty or null address return empty string', () {
      final nonFiniteInvalid = [
        {'lat': double.nan, 'lon': double.nan, 'addr': null},
        {'lat': double.infinity, 'lon': double.infinity, 'addr': ''},
        {'lat': double.negativeInfinity, 'lon': -97.7431, 'addr': '   '},
        {'lat': null, 'lon': null, 'addr': null},
        {'lat': null, 'lon': null, 'addr': ''},
        {'lat': null, 'lon': null, 'addr': '  \n\t  '},
      ];

      for (final tc in nonFiniteInvalid) {
        final lat = tc['lat'] as double?;
        final lon = tc['lon'] as double?;
        final addr = tc['addr'] as String?;

        final url = MapLauncherService.buildNavigationUrl(
          latitude: lat,
          longitude: lon,
          address: addr,
        );
        expect(url, isEmpty, reason: 'Expected empty URL for lat: $lat, lon: $lon, addr: "$addr"');
      }
    });

    test('2.5 launchNavigation returns false immediately when coordinates and address are invalid', () async {
      var mockTriggered = false;
      MapLauncherService.setMockLauncher((url) async {
        mockTriggered = true;
        return true;
      });

      final result = await MapLauncherService.launchNavigation(
        latitude: double.nan,
        longitude: double.infinity,
        address: '   \n  ',
      );

      expect(result, isFalse);
      expect(mockTriggered, isFalse, reason: 'Mock launcher must not be invoked for invalid destinations');
    });
  });

  group('Vector 3: Concurrency, Asynchronous Resilience & Exception Shielding', () {
    test('3.1 50 rapid concurrent invocations succeed without race conditions or crosstalk', () async {
      final recordedUrls = <String>[];
      MapLauncherService.setMockLauncher((url) async {
        recordedUrls.add(url);
        // Simulate tiny asynchronous processing jitter
        await Future.delayed(const Duration(milliseconds: 2));
        return true;
      });

      // Spawn 50 simultaneous calls with distinct coordinate indices
      final futures = List.generate(50, (index) {
        return MapLauncherService.launchNavigation(
          latitude: 30.0 + (index * 0.01),
          longitude: -97.0 - (index * 0.01),
        );
      });

      final results = await Future.wait(futures);

      expect(results.length, equals(50));
      expect(results.every((r) => r == true), isTrue);
      expect(recordedUrls.length, equals(50));

      // Verify every call generated its unique coordinate URL without being overwritten
      for (var i = 0; i < 50; i++) {
        final latValue = 30.0 + (i * 0.01);
        final found = recordedUrls.any((u) => u.contains(latValue.toString()));
        expect(found, isTrue, reason: 'URL for coordinate index $i ($latValue) was lost or mutated');
      }
    });

    test('3.2 Synchronous Exception thrown by mock launcher is caught and returns false', () async {
      MapLauncherService.setMockLauncher((url) {
        throw Exception('Simulated fatal platform channel sync exception');
      });

      final result = await MapLauncherService.launchNavigation(
        latitude: 30.2672,
        longitude: -97.7431,
      );

      expect(result, isFalse);
    });

    test('3.3 Synchronous PlatformException thrown by mock launcher is caught and returns false', () async {
      MapLauncherService.setMockLauncher((url) {
        throw PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
          message: 'No mapping application installed to handle URI',
        );
      });

      final result = await MapLauncherService.launchNavigation(
        latitude: 30.2672,
        longitude: -97.7431,
      );

      expect(result, isFalse);
    });

    test('3.4 Asynchronous rejected Future (Future.error) is caught and returns false', () async {
      MapLauncherService.setMockLauncher((url) async {
        await Future.delayed(const Duration(milliseconds: 5));
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Intent launch blocked by sandbox policy',
        );
      });

      final result = await MapLauncherService.launchNavigation(
        latitude: 30.2672,
        longitude: -97.7431,
      );

      expect(result, isFalse);
    });

    test('3.5 Error in mock launcher returns false without bubbling Error or crashing isolate', () async {
      MapLauncherService.setMockLauncher((url) {
        throw StateError('Isolate state corruption simulation');
      });

      // Expect launchNavigation to safely handle any Object/Exception
      final result = await MapLauncherService.launchNavigation(
        latitude: 30.2672,
        longitude: -97.7431,
      );

      expect(result, isFalse);
    });
  });

  group('Vector 4: Platform Mapping Scheme Fidelity Across TargetPlatforms', () {
    test('4.1 TargetPlatform verification across iOS, macOS, Android, Linux, Windows, Fuchsia', () {
      const coords = '30.2672,-97.7431';

      // Apple Maps platforms
      for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        final url = MapLauncherService.buildNavigationUrl(
          latitude: 30.2672,
          longitude: -97.7431,
          platform: p,
        );
        expect(url, equals('https://maps.apple.com/?daddr=$coords'), reason: 'Failed for platform $p');
      }

      // Google Maps platforms
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        final url = MapLauncherService.buildNavigationUrl(
          latitude: 30.2672,
          longitude: -97.7431,
          platform: p,
        );
        expect(
          url,
          equals('https://www.google.com/maps/dir/?api=1&destination=$coords'),
          reason: 'Failed for platform $p',
        );
      }
    });

    test('4.2 setMockPlatform overrides defaultTargetPlatform deterministically', () {
      MapLauncherService.setMockPlatform(TargetPlatform.macOS);
      final url = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
      );
      expect(url, startsWith('https://maps.apple.com/'));

      MapLauncherService.setMockPlatform(TargetPlatform.android);
      final url2 = MapLauncherService.buildNavigationUrl(
        latitude: 30.2672,
        longitude: -97.7431,
      );
      expect(url2, startsWith('https://www.google.com/maps/dir/'));

      MapLauncherService.resetMockLauncher();
    });
  });
}
