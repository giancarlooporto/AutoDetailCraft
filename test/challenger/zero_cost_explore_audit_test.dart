// =========================================================================
// File: test/challenger/zero_cost_explore_audit_test.dart
// Description: Adversarial verification of Zero-Cost Browsing ($0.00)
//              and Studio vs Client Coordinate Resolution in Explore.
// Milestone: M2 (Zero-Cost Browsing Guarantee & Privacy Resolution)
// =========================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/location_service.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import '../core/test_harness.dart';

/// Adversarial HTTP network interceptor that counts and monitors all outgoing
/// HTTP network calls made by the Dart VM / Flutter runtime.
class AdversarialNetworkInterceptor extends HttpOverrides {
  int totalHttpRequests = 0;
  int googleMapsApiRequests = 0;
  final List<Uri> interceptedUris = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _AdversarialHttpClient(this);
  }
}

class _AdversarialHttpClient implements HttpClient {
  final AdversarialNetworkInterceptor interceptor;
  _AdversarialHttpClient(this.interceptor);

  void _record(Uri url) {
    interceptor.totalHttpRequests++;
    interceptor.interceptedUris.add(url);
    final host = url.host.toLowerCase();
    final path = url.path.toLowerCase();
    if (host.contains('maps.googleapis.com') ||
        host.contains('googleapis.com') ||
        path.contains('maps') ||
        path.contains('geocode') ||
        path.contains('places')) {
      interceptor.googleMapsApiRequests++;
    }
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    _record(url);
    throw UnsupportedError('Adversarial interceptor blocked network call: $method $url');
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      for (final arg in invocation.positionalArguments) {
        if (arg is Uri) {
          _record(arg);
        }
      }
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdversarialNetworkInterceptor interceptor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.resetMockLocationProvider();
    interceptor = AdversarialNetworkInterceptor();
    HttpOverrides.global = interceptor;
  });

  tearDown(() {
    HttpOverrides.global = null;
    LocationService.resetMockLocationProvider();
  });

  Widget buildFeedScreen(JobRepository repo) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: FeedScreen(repository: repo),
      ),
    );
  }

  // =========================================================================
  // SECTION 1: Zero External API Calls Audit ($0.00 Guarantee)
  // =========================================================================
  group(r'1. Zero External API Calls Audit ($0.00 Cost Guarantee)', () {
    test('1.1 105-Query Stress Suite across cities, ZIPs, shops, GPS, and edge cases: Zero external API calls', () async {
      final repo = await TestHarness.createSession(isLoggedIn: false);

      // Seed 5 diverse studios across regions
      final testStudios = [
        const UserProfile(
          id: 'det_austin_craft',
          username: 'austin_craft',
          displayName: 'Austin Craft Detail',
          businessName: 'Austin Craft Studio',
          role: UserRole.detailer,
          location: 'Austin, TX',
          studioStreetAddress: '1200 S Congress Ave',
          studioCity: 'Austin',
          studioState: 'TX',
          studioPostalCode: '78704',
          studioLatitude: 30.2500,
          studioLongitude: -97.7400,
          serviceRadius: '25 miles',
          servicePackages: [
            ServicePackage(
              id: 'p1',
              title: 'Ceramic Coating',
              description: '9H ceramic paint protection',
              basePrice: 600,
              estimatedDuration: '5 hours',
              includes: ['Paint Correction', 'Ceramic Coat'],
            ),
          ],
        ),
        const UserProfile(
          id: 'det_rr_shine',
          username: 'round_rock_shine',
          displayName: 'Round Rock Shine',
          businessName: 'Round Rock Studio',
          role: UserRole.detailer,
          location: 'Round Rock, TX',
          studioStreetAddress: '500 E Main St',
          studioCity: 'Round Rock',
          studioState: 'TX',
          studioPostalCode: '78664',
          studioLatitude: 30.5083,
          studioLongitude: -97.6789,
          serviceRadius: '20 miles',
          servicePackages: [
            ServicePackage(
              id: 'p2',
              title: 'Interior Deep Clean',
              description: 'Steam extraction detailing',
              basePrice: 250,
              estimatedDuration: '3 hours',
              includes: ['Steam', 'Extraction'],
            ),
          ],
        ),
        const UserProfile(
          id: 'det_sa_alamo',
          username: 'alamo_detail',
          displayName: 'Alamo Auto Spa',
          businessName: 'Alamo Studio',
          role: UserRole.detailer,
          location: 'San Antonio, TX',
          studioStreetAddress: '100 Alamo Plaza',
          studioCity: 'San Antonio',
          studioState: 'TX',
          studioPostalCode: '78205',
          studioLatitude: 29.4241,
          studioLongitude: -98.4936,
          serviceRadius: '30 miles',
          servicePackages: [
            ServicePackage(
              id: 'p3',
              title: 'Paint Correction',
              description: '2-Stage paint correction',
              basePrice: 450,
              estimatedDuration: '4 hours',
              includes: ['Compound', 'Polish'],
            ),
          ],
        ),
        const UserProfile(
          id: 'det_dallas_apex',
          username: 'apex_detailing',
          displayName: 'Apex Detail Studio',
          businessName: 'Apex Studio',
          role: UserRole.detailer,
          location: 'Dallas, TX',
          studioStreetAddress: '1500 Commerce St',
          studioCity: 'Dallas',
          studioState: 'TX',
          studioPostalCode: '75201',
          studioLatitude: 32.7767,
          studioLongitude: -96.7970,
          serviceRadius: '35 miles',
          servicePackages: [
            ServicePackage(
              id: 'p4',
              title: 'Full Exterior Wash',
              description: 'Foam bath and wax',
              basePrice: 150,
              estimatedDuration: '2 hours',
              includes: ['Foam Bath', 'Carnuba Wax'],
            ),
          ],
        ),
        const UserProfile(
          id: 'det_denver_peak',
          username: 'peak_gloss',
          displayName: 'Peak Gloss Pro',
          businessName: 'Peak Gloss Studio',
          role: UserRole.detailer,
          location: 'Denver, CO',
          studioStreetAddress: '1600 California St',
          studioCity: 'Denver',
          studioState: 'CO',
          studioPostalCode: '80202',
          studioLatitude: 39.7392,
          studioLongitude: -104.9903,
          serviceRadius: '40 miles',
          servicePackages: [
            ServicePackage(
              id: 'p5',
              title: 'Winter Protection Package',
              description: 'Underbody and sealant',
              basePrice: 350,
              estimatedDuration: '3.5 hours',
              includes: ['Underbody Wash', 'Sealant'],
            ),
          ],
        ),
      ];

      repo.setPublicDetailersForTesting(testStudios);

      // Define 105 distinct queries across 5 categories
      final cityQueries = [
        'Austin', 'Round Rock', 'San Antonio', 'Dallas', 'Houston',
        'Miami', 'New York', 'Seattle', 'Chicago', 'Denver',
        'Los Angeles', 'San Francisco', 'Phoenix', 'San Diego', 'San Jose',
        'Atlanta', 'Boston', 'Portland', 'Nashville', 'Las Vegas',
        'Detroit', 'Charlotte', 'Orlando', 'Tampa', 'Fort Worth',
      ]; // 25

      final zipQueries = [
        '78701', '78704', '78664', '78205', '90210',
        '10001', '30301', '75001', '75201', '98101',
        '02138', '33139', '60601', '80202', '94102',
        '97201', '89101', '37201', '28202', '32801',
        '33602', '76102', '85001', '92101', '00000',
      ]; // 25

      final shopAndServiceQueries = [
        'Austin Craft Studio', 'Round Rock Studio', 'Alamo Studio', 'Apex Studio', 'Peak Gloss Studio',
        'Ceramic Coating', 'Interior Deep Clean', 'Paint Correction', 'Full Exterior Wash', 'Winter Protection',
        'Steam', 'Extraction', 'Compound', 'Polish', 'Foam Bath',
        'Carnuba Wax', 'Underbody', 'Sealant', 'Detail', 'Studio',
        'Pro', 'Shine', 'Auto Spa', 'Craft', 'Gloss',
      ]; // 25

      final nearMeLocations = [
        const LocationCoordinates(latitude: 30.2672, longitude: -97.7431), // Austin Downtown
        const LocationCoordinates(latitude: 30.5083, longitude: -97.6789), // Round Rock
        const LocationCoordinates(latitude: 29.4241, longitude: -98.4936), // San Antonio
        const LocationCoordinates(latitude: 32.7767, longitude: -96.7970), // Dallas
        const LocationCoordinates(latitude: 29.7604, longitude: -95.3698), // Houston
        const LocationCoordinates(latitude: 39.7392, longitude: -104.9903), // Denver
        const LocationCoordinates(latitude: 40.7128, longitude: -74.0060), // New York
        const LocationCoordinates(latitude: 34.0522, longitude: -118.2437), // Los Angeles
        const LocationCoordinates(latitude: 41.8781, longitude: -87.6298), // Chicago
        const LocationCoordinates(latitude: 25.7617, longitude: -80.1918), // Miami
        const LocationCoordinates(latitude: 47.6062, longitude: -122.3321), // Seattle
        const LocationCoordinates(latitude: 0.0, longitude: 0.0), // Equator / Prime Meridian
        const LocationCoordinates(latitude: 90.0, longitude: 0.0), // North Pole
        const LocationCoordinates(latitude: -90.0, longitude: 0.0), // South Pole
        const LocationCoordinates(latitude: 0.0, longitude: 180.0), // International Date Line
      ]; // 15

      final adversarialEdgeQueries = [
        '', // Empty query
        '   \t\n   ', // Whitespace only
        '!@#\$%^&*()_+', // Special characters
        "' OR '1'='1", // SQL injection pattern
        '"; DROP TABLE profiles; --', // Malicious SQL DDL
        '<script>alert("xss")</script>', // XSS payload
        'A' * 1500, // Very long query string
        '🚗✨🧼🏎️', // Unicode emojis
        'Café Röck Straße', // Accents & Umlauts
        '.*', // Regex wildcard
        '^Studio.*\$', // Regex anchors
        '787', // Partial ZIP prefix
        'NONEXISTENT_SHOP_NAME_12345', // Guaranteed empty match
        'AuStIn CrAfT', // Mixed case
        '  Round Rock  ', // Untrimmed whitespace
      ]; // 15

      var queryCount = 0;

      // 1. Execute 25 City queries
      for (final city in cityQueries) {
        queryCount++;
        repo.setSearchQuery(city);
        final results = repo.filteredDetailers;
        expect(results, isNotNull);
        expect(interceptor.googleMapsApiRequests, 0, reason: 'City query "$city" must not make external Google Maps API calls');
        expect(interceptor.totalHttpRequests, 0, reason: 'City query "$city" must not make any HTTP calls');
      }

      // 2. Execute 25 Postal / ZIP code queries
      for (final zip in zipQueries) {
        queryCount++;
        repo.setSearchQuery(zip);
        final results = repo.filteredDetailers;
        expect(results, isNotNull);
        expect(interceptor.googleMapsApiRequests, 0, reason: 'ZIP query "$zip" must not make external Google Maps API calls');
        expect(interceptor.totalHttpRequests, 0, reason: 'ZIP query "$zip" must not make any HTTP calls');
      }

      // 3. Execute 25 Shop & Service queries
      for (final shop in shopAndServiceQueries) {
        queryCount++;
        repo.setSearchQuery(shop);
        final results = repo.filteredDetailers;
        expect(results, isNotNull);
        expect(interceptor.googleMapsApiRequests, 0, reason: 'Shop query "$shop" must not make external Google Maps API calls');
        expect(interceptor.totalHttpRequests, 0, reason: 'Shop query "$shop" must not make any HTTP calls');
      }

      // 4. Execute 15 Near Me GPS proximity calculations
      for (final coords in nearMeLocations) {
        queryCount++;
        await repo.sortDetailersByProximity(coords.latitude, coords.longitude);
        final results = repo.filteredDetailers;
        expect(results, isNotNull);
        expect(repo.currentUserGpsLocation, equals(coords));
        expect(interceptor.googleMapsApiRequests, 0, reason: 'Near Me GPS sort at (${coords.latitude}, ${coords.longitude}) must not call Google Maps');
        expect(interceptor.totalHttpRequests, 0, reason: r'Near Me GPS sort must be computed in-memory via Haversine ($0.00)');
      }

      // 5. Execute 15 Adversarial edge queries
      for (final edge in adversarialEdgeQueries) {
        queryCount++;
        repo.setSearchQuery(edge);
        final results = repo.filteredDetailers;
        expect(results, isNotNull);
        expect(interceptor.googleMapsApiRequests, 0, reason: 'Adversarial query "$edge" must not make external Google Maps API calls');
        expect(interceptor.totalHttpRequests, 0, reason: 'Adversarial query "$edge" must not make any HTTP calls');
      }

      // Verify total queries executed
      expect(queryCount, equals(105), reason: 'Must execute at least 100 queries across search and proximity sorts');
      expect(interceptor.googleMapsApiRequests, 0, reason: r'Zero Google Maps API calls across all 105 queries ($0.00 cost verified)');
      expect(interceptor.totalHttpRequests, 0, reason: 'Zero external network calls of any kind during search and filtering');
    });

    testWidgets('1.2 End-to-End UI Audit on FeedScreen: Interactive search and Near Me toggle triggers 0 external HTTP calls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockUserLocation = LocationCoordinates(latitude: 30.2672, longitude: -97.7431);
      LocationService.setMockLocationProvider(() async => mockUserLocation);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      final studio = const UserProfile(
        id: 'det_test_ui',
        username: 'craft_ui',
        displayName: 'Craft UI Studio',
        businessName: 'Craft UI Studio',
        role: UserRole.detailer,
        location: 'Austin, TX',
        studioStreetAddress: '100 Congress Ave',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78701',
        studioLatitude: 30.2650,
        studioLongitude: -97.7420,
        serviceRadius: '25 miles',
      );
      repo.setPublicDetailersForTesting([studio]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Enter text query through UI
      final searchInput = find.byType(TextField);
      expect(searchInput, findsWidgets);
      await tester.enterText(searchInput.first, 'Austin');
      await tester.pumpAndSettle();
      expect(interceptor.googleMapsApiRequests, 0);

      // 2. Enter ZIP query
      await tester.enterText(searchInput.first, '78701');
      await tester.pumpAndSettle();
      expect(interceptor.googleMapsApiRequests, 0);

      // 3. Select Current Location (Near Me) from location dropdown
      Future<void> triggerNearMe() async {
        await tester.tap(find.byKey(const Key('location_dropdown_btn')));
        await tester.pumpAndSettle();
        final menuNearMeItem = find.byKey(const Key('location_menu_near_me_item'));
        expect(menuNearMeItem, findsOneWidget);
        await tester.tap(menuNearMeItem);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await triggerNearMe();
      expect(interceptor.googleMapsApiRequests, 0);
      expect(interceptor.totalHttpRequests, 0);

      // Distance badge rendered
      expect(find.byKey(const Key('studio_distance_badge_det_test_ui')), findsOneWidget);

      // 4. Rapid toggle of Near Me option (toggle off then back on)
      await triggerNearMe();
      expect(repo.currentUserGpsLocation, isNull);

      await triggerNearMe();
      expect(repo.currentUserGpsLocation, isNotNull);

      // 5. Reset filters via quick reset button
      final resetBtn = find.byKey(const Key('reset_filters_btn'));
      if (resetBtn.evaluate().isNotEmpty) {
        await tester.tap(resetBtn.first);
        await tester.pumpAndSettle();
      }

      // Assert zero billable API requests occurred
      expect(interceptor.googleMapsApiRequests, 0, reason: r'Zero Google Maps API calls during interactive UI search & Near Me toggle ($0.00 cost verified)');
      expect(interceptor.totalHttpRequests, 0, reason: 'Zero HTTP requests during explore browsing');
    });

    test('1.3 Zero-Cost City Dropdown & Combined Facet Filtering: 48 permutations trigger zero external network requests', () async {
      final repo = await TestHarness.createSession(isLoggedIn: false);

      final testStudios = [
        const UserProfile(
          id: 'det_1',
          username: 'det_1',
          displayName: 'Austin Detailer',
          businessName: 'Austin Shop',
          role: UserRole.detailer,
          location: 'Austin, TX',
          studioCity: 'Austin',
          studioState: 'TX',
          studioPostalCode: '78701',
          studioLatitude: 30.2672,
          studioLongitude: -97.7431,
        ),
        const UserProfile(
          id: 'det_2',
          username: 'det_2',
          displayName: 'Dallas Detailer',
          businessName: 'Dallas Shop',
          role: UserRole.detailer,
          location: 'Dallas, TX',
          studioCity: 'Dallas',
          studioState: 'TX',
          studioPostalCode: '75201',
          studioLatitude: 32.7767,
          studioLongitude: -96.7970,
        ),
      ];
      repo.setPublicDetailersForTesting(testStudios);

      final cities = ['All Locations', 'Austin', 'Dallas', 'Round Rock', 'Houston', 'San Antonio'];
      final queries = ['', 'Detailer', 'Shop', '78701', '75201', 'Ceramic', 'Paint', 'Wax'];

      var permutations = 0;
      for (final city in cities) {
        repo.setLocationFilter(city);
        for (final q in queries) {
          permutations++;
          repo.setSearchQuery(q);
          final res = repo.filteredDetailers;
          expect(res, isNotNull);
          expect(interceptor.googleMapsApiRequests, 0);
          expect(interceptor.totalHttpRequests, 0);
        }
      }

      expect(permutations, equals(48));
      expect(interceptor.googleMapsApiRequests, 0, reason: r'$0.00 cost verified across all city/query filter permutations');
      expect(interceptor.totalHttpRequests, 0);
    });
  });

  // =========================================================================
  // SECTION 2: Studio vs Client Coordinate Resolution & Privacy Audit
  // =========================================================================
  group('2. Studio vs Client Coordinate Resolution & Residential Privacy Audit', () {
    test('2.1 Commercial Studio coordinates take precedence over Private Client residential coordinates in effective getters', () {
      // Detailer with distinct residential home address and commercial studio address
      const detailer = UserProfile(
        id: 'det_dual_addr',
        username: 'marcus_dual',
        displayName: 'Marcus Vance',
        businessName: 'Vance Commercial Studio',
        role: UserRole.detailer,
        // Private Client Residential Address (Downtown Austin)
        streetAddress: '742 Evergreen Terrace (Private Residence)',
        unitOrApt: 'Gate Code #9999',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        latitude: 30.2672,
        longitude: -97.7431,
        // Public Commercial Studio Address (Round Rock, ~17 miles north)
        studioStreetAddress: '500 E Industrial Blvd (Commercial Shop)',
        studioUnitOrApt: 'Suite A',
        studioCity: 'Round Rock',
        studioState: 'TX',
        studioPostalCode: '78664',
        studioLatitude: 30.5083,
        studioLongitude: -97.6789,
      );

      // 1. Check Studio coordinates resolution
      expect(detailer.effectiveStudioLatitude, equals(30.5083),
          reason: 'effectiveStudioLatitude MUST use commercial studioLatitude, NOT private client latitude');
      expect(detailer.effectiveStudioLongitude, equals(-97.6789),
          reason: 'effectiveStudioLongitude MUST use commercial studioLongitude, NOT private client longitude');

      // 2. Check Client residential coordinates resolution (for client booking context)
      expect(detailer.effectiveLatitude, equals(30.2672),
          reason: 'effectiveLatitude MUST preserve private client home latitude for client mobile bookings');
      expect(detailer.effectiveLongitude, equals(-97.7431),
          reason: 'effectiveLongitude MUST preserve private client home longitude for client mobile bookings');

      // 3. Confirm mathematical distinction between studio and client home
      final studioDistance = LocationService.calculateDistanceMiles(
        30.5083, -97.6789,
        detailer.effectiveStudioLatitude!,
        detailer.effectiveStudioLongitude!,
      );
      final homeDistance = LocationService.calculateDistanceMiles(
        30.5083, -97.6789,
        detailer.effectiveLatitude!,
        detailer.effectiveLongitude!,
      );

      expect(studioDistance, closeTo(0.0, 0.001), reason: 'Studio distance from its own location is 0 miles');
      expect(homeDistance, greaterThan(15.0), reason: 'Home distance from Round Rock is > 15 miles');
    });

    test('2.2 Proximity sorting and distance caching strictly uses commercial studio coordinates, preserving client privacy', () async {
      final repo = await TestHarness.createSession(isLoggedIn: false);

      // Detailer A: Commercial Studio in Round Rock (30.5083), Home in Austin (30.2672)
      const detailerA = UserProfile(
        id: 'det_a_shop_round_rock',
        username: 'shop_rr',
        displayName: 'Round Rock Pro',
        businessName: 'Round Rock Commercial Studio',
        role: UserRole.detailer,
        streetAddress: '100 Secret Home Way',
        latitude: 30.2672, // Home: Austin
        longitude: -97.7431,
        studioStreetAddress: '500 E Industrial Blvd',
        studioLatitude: 30.5083, // Studio: Round Rock
        studioLongitude: -97.6789,
        serviceRadius: '25 miles',
      );

      // Detailer B: Commercial Studio in Austin (30.2672), Home in Round Rock (30.5083)
      const detailerB = UserProfile(
        id: 'det_b_shop_austin',
        username: 'shop_atx',
        displayName: 'Austin Pro',
        businessName: 'Austin Commercial Studio',
        role: UserRole.detailer,
        streetAddress: '999 Secret Home Way',
        latitude: 30.5083, // Home: Round Rock
        longitude: -97.6789,
        studioStreetAddress: '1200 S Congress Ave',
        studioLatitude: 30.2672, // Studio: Austin
        studioLongitude: -97.7431,
        serviceRadius: '25 miles',
      );

      // Detailer C: Studio in San Antonio (29.4241), Home in San Antonio (29.4241)
      const detailerC = UserProfile(
        id: 'det_c_shop_san_antonio',
        username: 'shop_sa',
        displayName: 'Alamo Pro',
        businessName: 'Alamo Commercial Studio',
        role: UserRole.detailer,
        streetAddress: '777 Alamo Home St',
        latitude: 29.4241,
        longitude: -98.4936,
        studioStreetAddress: '100 Alamo Plaza',
        studioLatitude: 29.4241,
        studioLongitude: -98.4936,
        serviceRadius: '25 miles',
      );

      repo.setPublicDetailersForTesting([detailerB, detailerC, detailerA]);

      // Benchmark User at Round Rock: (30.5083, -97.6789)
      const userLat = 30.5083;
      const userLon = -97.6789;

      await repo.sortDetailersByProximity(userLat, userLon);

      // Check distance values computed for each detailer
      final distA = repo.getDistanceToDetailer(detailerA.id);
      final distB = repo.getDistanceToDetailer(detailerB.id);
      final distC = repo.getDistanceToDetailer(detailerC.id);

      expect(distA, isNotNull);
      expect(distB, isNotNull);
      expect(distC, isNotNull);

      // Detailer A's studio is at (30.5083, -97.6789) -> dist must be ~0.0 mi
      // If Detailer A's private home had leaked, dist would be ~17.0 mi!
      expect(distA!, closeTo(0.0, 0.01),
          reason: 'Detailer A distance must be 0.0 mi based on commercial studio coordinates, NOT 17.0 mi from client home');

      // Detailer B's studio is at (30.2672, -97.7431) -> dist must be ~17.0 mi
      // If Detailer B's private home had been used, dist would be ~0.0 mi!
      expect(distB!, closeTo(17.0, 1.0),
          reason: 'Detailer B distance must be ~17.0 mi based on commercial studio coordinates, NOT 0.0 mi from client home');

      // Detailer C's studio is at San Antonio -> dist from Round Rock is ~89.4 mi
      expect(distC!, closeTo(89.4, 1.0));

      // Assert strict ranking order in filteredDetailers
      final ranked = repo.filteredDetailers;
      expect(ranked.length, equals(3));
      expect(ranked[0].id, equals(detailerA.id),
          reason: 'Rank #1 MUST be Detailer A (commercial studio in Round Rock, dist ~0.0 mi)');
      expect(ranked[1].id, equals(detailerB.id),
          reason: 'Rank #2 MUST be Detailer B (commercial studio in Austin, dist ~17.0 mi)');
      expect(ranked[2].id, equals(detailerC.id),
          reason: 'Rank #3 MUST be Detailer C (commercial studio in San Antonio, dist ~73.5 mi)');
    });

    test('2.3 Mobile Detailer Fallback: Studio coordinates unset safely fall back to client coordinates without throwing', () async {
      // Mobile detailer who operates from home and has no separate commercial studio coordinates
      const mobileDetailer = UserProfile(
        id: 'det_mobile_van',
        username: 'mobile_pro',
        displayName: 'Mobile Van Detailing',
        businessName: 'Mobile Pro Studio',
        role: UserRole.detailer,
        streetAddress: '123 Mobile Base Rd',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        latitude: 30.2672,
        longitude: -97.7431,
        // Commercial studio coordinates null / unset
        studioLatitude: null,
        studioLongitude: null,
      );

      // Verify fallback getters
      expect(mobileDetailer.effectiveStudioLatitude, equals(30.2672),
          reason: 'When studioLatitude is null, effectiveStudioLatitude safely falls back to latitude');
      expect(mobileDetailer.effectiveStudioLongitude, equals(-97.7431),
          reason: 'When studioLongitude is null, effectiveStudioLongitude safely falls back to longitude');

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([mobileDetailer]);

      // Calculate proximity from Austin Downtown
      await repo.sortDetailersByProximity(30.2672, -97.7431);
      final dist = repo.getDistanceToDetailer(mobileDetailer.id);

      expect(dist, isNotNull);
      expect(dist!, closeTo(0.0, 0.01), reason: 'Fallback distance resolves accurately to 0.0 mi');

      // Now suppose detailer acquires a commercial facility in Round Rock
      final updatedWithStudio = mobileDetailer.copyWith(
        studioStreetAddress: '9900 Commercial Industrial Pkwy',
        studioCity: 'Round Rock',
        studioLatitude: 30.5083,
        studioLongitude: -97.6789,
      );

      // Verify that once studio coordinates are defined, effectiveStudioLatitude immediately switches
      expect(updatedWithStudio.effectiveStudioLatitude, equals(30.5083),
          reason: 'Once commercial studioLatitude is set, it MUST override client home latitude');
      expect(updatedWithStudio.effectiveStudioLongitude, equals(-97.6789));
      expect(updatedWithStudio.latitude, equals(30.2672),
          reason: 'Client home latitude remains intact and untouched');
    });

    testWidgets('2.4 UI Leakage Check: Private residential street address and gate codes NEVER appear on public studio cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);

      const secretHomeStreet = '742 Confidential Home Way';
      const secretGateCode = 'Gate #9876-SECRET';
      const publicStudioStreet = '500 Public Commercial Blvd';

      const detailer = UserProfile(
        id: 'det_privacy_check',
        username: 'privacy_detailer',
        displayName: 'Private Home Detailer',
        businessName: 'Public Commercial Auto Spa',
        role: UserRole.detailer,
        streetAddress: secretHomeStreet,
        unitOrApt: secretGateCode,
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        latitude: 30.2672,
        longitude: -97.7431,
        studioStreetAddress: publicStudioStreet,
        studioUnitOrApt: 'Suite 100',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78701',
        studioLatitude: 30.2650,
        studioLongitude: -97.7420,
        serviceRadius: '25 miles',
      );

      repo.setPublicDetailersForTesting([detailer]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify business name is rendered
      expect(find.text('Public Commercial Auto Spa'), findsOneWidget);

      // 2. CRITICAL PRIVACY ASSERTIONS: Private residence street & gate code MUST NOT be in widget tree
      expect(find.textContaining('Confidential Home Way'), findsNothing,
          reason: 'Client residential street address must NEVER be rendered on public studio cards');
      expect(find.textContaining('9876-SECRET'), findsNothing,
          reason: 'Client residential gate code / unit must NEVER be rendered on public studio cards');
      expect(find.textContaining('742'), findsNothing,
          reason: 'Residential house number must not be exposed');
    });

    test('2.5 Boundary & Extreme Coordinates: Detailer with both coordinates null handles proximity sort gracefully', () async {
      final repo = await TestHarness.createSession(isLoggedIn: false);

      const nullCoordsDetailer = UserProfile(
        id: 'det_no_coords',
        username: 'unmapped_detailer',
        displayName: 'Unmapped Detailer',
        businessName: 'Unmapped Studio',
        role: UserRole.detailer,
        location: 'Nowhere, US',
        latitude: null,
        longitude: null,
        studioLatitude: null,
        studioLongitude: null,
      );

      const mappedDetailer = UserProfile(
        id: 'det_mapped',
        username: 'mapped_detailer',
        displayName: 'Mapped Detailer',
        businessName: 'Mapped Studio',
        role: UserRole.detailer,
        location: 'Austin, TX',
        studioLatitude: 30.2672,
        studioLongitude: -97.7431,
      );

      repo.setPublicDetailersForTesting([nullCoordsDetailer, mappedDetailer]);

      // Sort by proximity from Austin
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      // Mapped detailer has distance ~0.0 mi
      expect(repo.getDistanceToDetailer(mappedDetailer.id), closeTo(0.0, 0.01));

      // Unmapped detailer returns null distance without throwing or NaN
      expect(repo.getDistanceToDetailer(nullCoordsDetailer.id), isNull);

      // Unmapped detailer sorted to the end
      final ranked = repo.filteredDetailers;
      expect(ranked.first.id, equals(mappedDetailer.id));
      expect(ranked.last.id, equals(nullCoordsDetailer.id));
    });

    test('2.6 Detailer activation carry-over & subsequent independent studio relocation retains strict coordinate privacy', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // Start as Client with residential address in South Austin
      await repo.updateClientAddress(
        streetAddress: '123 Private Home Lane',
        unitOrApt: 'Apt 4B',
        city: 'Austin',
        state: 'TX',
        postalCode: '78704',
        latitude: 30.2500,
        longitude: -97.7500,
      );

      expect(repo.currentUser.latitude, equals(30.2500));
      expect(repo.currentUser.longitude, equals(-97.7500));
      expect(repo.currentUser.studioLatitude, isNull);

      // Activate detailer mode -> auto-inherits client coordinates
      await repo.enableDetailerMode();
      expect(repo.currentUser.studioLatitude, equals(30.2500));
      expect(repo.currentUser.studioLongitude, equals(-97.7500));
      expect(repo.currentUser.effectiveStudioLatitude, equals(30.2500));

      // Detailer opens commercial shop in Pflugerville (~18 mi north)
      await repo.updateStudioAddress(
        streetAddress: '900 Commercial Blvd',
        unitOrApt: 'Suite 200',
        city: 'Pflugerville',
        state: 'TX',
        postalCode: '78660',
        latitude: 30.4393,
        longitude: -97.6200,
      );

      // Verify studio coordinates updated, but client residential coordinates preserved
      expect(repo.currentUser.effectiveStudioLatitude, equals(30.4393),
          reason: 'effectiveStudioLatitude must now point to commercial studio in Pflugerville');
      expect(repo.currentUser.effectiveStudioLongitude, equals(-97.6200));

      expect(repo.currentUser.latitude, equals(30.2500),
          reason: 'Client residential home latitude must remain completely untouched');
      expect(repo.currentUser.longitude, equals(-97.7500));
      expect(repo.currentUser.streetAddress, equals('123 Private Home Lane'));

      // Sort public detailers from Austin Downtown (30.2672, -97.7431)
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      // Distance to this detailer must reflect commercial studio (~13.6 mi), not home (~1.2 mi)
      final dist = repo.getDistanceToDetailer(repo.currentUser.id);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(10.0),
          reason: 'Distance must be calculated against Pflugerville studio (>10 mi), not South Austin home (~1.2 mi)');
    });
  });
}
