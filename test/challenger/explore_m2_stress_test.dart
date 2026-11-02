// =========================================================================
// File: test/challenger/explore_m2_stress_test.dart
// Description: Adversarial stress harness and empirical challenge suite for
//              Milestone M2: Explore Search & Near Me Proximity Sorting.
//
// Attack Vectors & Objectives:
// 1. Rapid Re-entrant GPS Taps:
//    - Tap "Near Me" 20 times in rapid succession under async latency simulation.
//    - Concurrent invocation of sortDetailersByProximity and toggle cycles.
//    - Verify zero race conditions, listener thrashing, or unhandled exceptions.
// 2. Extreme Coordinate Distances & Badges:
//    - Micro-distance (0.05 mi -> "Under 0.1 mi away"), 0.12 mi ("0.1 mi away").
//    - Antipodal points (~12,437 mi away) and studios with null coordinates.
//    - Verify badges render cleanly without RenderFlex overflows across 390px viewport.
// 3. Special Characters & Regex Injection in Search:
//    - Regex meta-characters: ".*", "[", "(", "$^", "\d+", "\b", "?+*{}".
//    - Emojis & surrogate pairs: "🚗📍", "✨", "🏎️".
//    - Null, whitespace, SQL injection, and long string queries.
//    - In-memory literal substring filtering verification without regex crashes.
// 4. Distance Formatting & Mathematical Boundary Invariants:
//    - NaN, Infinity, negative, 0.0, 0.099, 0.1, 9.9, 10.0, 12,000+ mi boundaries.
// =========================================================================

import 'dart:async';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Synthetic Anchor: Downtown Austin (6th & Congress)
  const userAustin = LocationCoordinates(
    latitude: 30.2672,
    longitude: -97.7431,
  );

  // Studio 1: Micro-distance (~0.05 miles away)
  // 30.2679, -97.7431 -> dLat = 0.0007 deg ≈ 0.0483 miles
  final studioMicroDist = const UserProfile(
    id: 'det_micro_dist',
    username: 'micro_shine',
    displayName: 'Micro Shine Co',
    businessName: 'Micro Precision Detailing',
    role: UserRole.detailer,
    location: 'Austin, TX',
    studioStreetAddress: '100 Congress Ave',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78701',
    studioLatitude: 30.2679,
    studioLongitude: -97.7431,
    serviceRadius: '5 miles',
    averageRating: 5.0,
    servicePackages: [
      ServicePackage(
        id: 'pkg_micro_1',
        title: 'Ceramic Coating Express',
        description: 'Rapid exterior detail & ceramic coating',
        basePrice: 150.0,
        estimatedDuration: '1 hour',
        includes: ['Hand wash', 'Tire shine', 'Ceramic spray'],
      ),
    ],
  );

  // Studio 2: Sub-mile distance (~0.12 miles away)
  // 30.2689, -97.7431 -> dLat = 0.0017 deg ≈ 0.117 miles -> formats to "0.1 mi away"
  final studioSubMile = const UserProfile(
    id: 'det_sub_mile',
    username: 'sub_mile_shine',
    displayName: 'Downtown Auto Detail',
    businessName: 'Sub-Mile Detail Studio',
    role: UserRole.detailer,
    location: 'Austin, TX',
    studioStreetAddress: '200 Congress Ave',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78701',
    studioLatitude: 30.2689,
    studioLongitude: -97.7431,
    serviceRadius: '10 miles',
    averageRating: 4.8,
    servicePackages: [
      ServicePackage(
        id: 'pkg_sub_1',
        title: 'Interior Refresh',
        description: 'Vacuum and wipe',
        basePrice: 80.0,
        estimatedDuration: '1.5 hours',
        includes: ['Vacuum', 'Wipe down'],
      ),
    ],
  );

  // Studio 3: Antipodal extreme distance (~12,437 miles away, opposite hemisphere)
  // Opposite of (30.2672, -97.7431) is (-30.2672, 82.2569 in Indian Ocean)
  final studioAntipodal = const UserProfile(
    id: 'det_antipodal',
    username: 'antipodal_spa',
    displayName: 'Antipodal Auto Care',
    businessName: 'Global Antipodal Studio',
    role: UserRole.detailer,
    location: 'Indian Ocean Outpost',
    studioStreetAddress: 'Zero Latitude Way',
    studioCity: 'Perth Oceanic',
    studioState: 'OC',
    studioPostalCode: '00000',
    studioLatitude: -30.2672,
    studioLongitude: 82.2569,
    serviceRadius: '500 miles',
    averageRating: 4.6,
    servicePackages: [
      ServicePackage(
        id: 'pkg_anti_1',
        title: 'Deep Ocean Ceramic',
        description: 'Salt-resistant coat',
        basePrice: 999.0,
        estimatedDuration: '8 hours',
        includes: ['Marine prep', 'Titanium coat'],
      ),
    ],
  );

  // Studio 4: Null coordinates (unmapped studio)
  final studioNullCoords = const UserProfile(
    id: 'det_null_coords',
    username: 'nomad_detailer',
    displayName: 'Nomad Detailer',
    businessName: 'Mobile Nomad Services',
    role: UserRole.detailer,
    location: 'Mobile Only, TX',
    studioStreetAddress: '',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78701',
    studioLatitude: null,
    studioLongitude: null,
    latitude: null,
    longitude: null,
    serviceRadius: 'Mobile Only',
    averageRating: 4.5,
    servicePackages: [
      ServicePackage(
        id: 'pkg_nomad_1',
        title: 'Mobile Express',
        description: 'On-demand detailing at your door',
        basePrice: 120.0,
        estimatedDuration: '2 hours',
        includes: ['Waterless wash'],
      ),
    ],
  );

  // Studio 5: Extreme label lengths with micro-distance
  final studioSuperLongLabels = const UserProfile(
    id: 'det_long_labels',
    username: 'hyper_long_name_studio',
    displayName: 'The Most Luxurious Exquisite High-End Concierge Detailing & Paint Protection Studio of Texas',
    businessName: 'Super Ultra Hyper Platinum Precision Detailing Studio of Greater Central Texas Metropolitan Area',
    role: UserRole.detailer,
    location: 'Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch, TX',
    studioStreetAddress: '9999999999 Infinite Boulevard Suite 999999999',
    studioCity: 'Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch',
    studioState: 'TX',
    studioPostalCode: '99999-9999',
    studioLatitude: 30.2673,
    studioLongitude: -97.7431,
    serviceRadius: '1000 miles',
    averageRating: 4.9,
    servicePackages: [
      ServicePackage(
        id: 'pkg_long_1',
        title: 'The Ultimate Legendary Multi-Stage Paint Correction And Graphene Armor Coating Package [VIP Special Edition]',
        description: 'Comprehensive 100-step detailing process',
        basePrice: 5000.0,
        estimatedDuration: '48 hours',
        includes: ['Complete paint decontamination', 'Multi-stage wet sanding', 'Graphene infusion'],
      ),
    ],
  );

  // Studio 6: Emojis and special characters in business name and packages
  final studioEmojiSpecial = const UserProfile(
    id: 'det_emoji_special',
    username: 'sparkle_car_pro',
    displayName: '✨ Sparkle Auto Spa 🏎️💨',
    businessName: '⚡ Apex Auto Pro 🚗📍 [Premium & Custom]',
    role: UserRole.detailer,
    location: 'Austin (Downtown) [Central], TX',
    bio: 'Top-tier detailing with special care: (Ceramic+PPF) & [VIP] guarantees! \$100 off.',
    studioStreetAddress: '777 Electric Ave #4-B',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78702',
    studioLatitude: 30.2600,
    studioLongitude: -97.7300,
    serviceRadius: '15 miles',
    averageRating: 4.95,
    servicePackages: [
      ServicePackage(
        id: 'pkg_special_1',
        title: '🏎️ Track Day Prep & Ceramic (9H+)',
        description: 'High-speed resistance coating with .* regex test string and (special) guarantee!',
        basePrice: 750.0,
        estimatedDuration: '6 hours',
        includes: ['Wheel-off detail', 'Brake caliper coat', 'Hydrophobic glass (front+rear)'],
      ),
    ],
  );

  Widget buildTestScreen(JobRepository repo) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: FeedScreen(repository: repo),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.resetMockLocationProvider();
  });

  tearDown(() {
    LocationService.resetMockLocationProvider();
  });

  // =========================================================================
  // 1. RAPID RE-ENTRANT GPS TAPS & RACE CONDITION STRESS
  // =========================================================================
  group('1. Rapid Re-entrant GPS Taps & Race Conditions', () {
    testWidgets('1.1 Tap "Near Me" 20 times in rapid succession with async latency simulation', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());



      var locationRequestCount = 0;
      final completerList = <Completer<LocationCoordinates?>>[];

      // Latency simulation: each GPS request takes 40ms before resolving
      LocationService.setMockLocationProvider(() async {
        locationRequestCount++;
        final c = Completer<LocationCoordinates?>();
        completerList.add(c);
        // Simulate real GPS delay
        await Future.delayed(const Duration(milliseconds: 40));
        if (!c.isCompleted) c.complete(userAustin);
        return userAustin;
      });

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioMicroDist, studioAntipodal]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final nearMeFinder = find.byKey(const Key('near_me_gps_btn'));
      expect(nearMeFinder, findsOneWidget);

      // Rapidly fire 20 taps without pumping between them to test re-entrancy protection
      for (int i = 0; i < 20; i++) {
        await tester.tap(nearMeFinder, warnIfMissed: false);
      }

      // First pump to let the first tap trigger _isLocating = true
      await tester.pump();

      // Fire 10 more taps while _isLocating is active
      for (int i = 0; i < 10; i++) {
        await tester.tap(nearMeFinder, warnIfMissed: false);
      }

      // Allow the async simulated GPS delay to finish
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Empirical assertions:
      final caughtException = tester.takeException();
      if (caughtException is FlutterError) {
        FlutterError.dumpErrorToConsole(FlutterErrorDetails(exception: caughtException));
      }
      expect(caughtException, isNull);

      // 2. Button safely ignored concurrent taps while _isLocating was active (only 1 location request dispatched)
      expect(locationRequestCount, 1, reason: 'Re-entrant taps while locating must be debounced/disabled');

      // 3. Proximity sort successfully applied
      expect(repo.currentUserGpsLocation, isNotNull);
      expect(repo.currentUserGpsLocation!.latitude, userAustin.latitude);
      expect(repo.currentUserGpsLocation!.longitude, userAustin.longitude);
      expect(find.textContaining('mi away'), findsWidgets);
    });

    testWidgets('1.2 Concurrent repository-level sortDetailersByProximity (20 parallel calls)', (tester) async {
      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([
        studioMicroDist,
        studioSubMile,
        studioAntipodal,
        studioNullCoords,
      ]);

      var notificationCount = 0;
      repo.addListener(() {
        notificationCount++;
      });

      // Launch 20 concurrent proximity sorts with slight coordinate jitters (testing race-free concurrent sorting)
      final parallelSorts = List.generate(20, (index) {
        final jitter = index * 0.00001;
        return repo.sortDetailersByProximity(userAustin.latitude + jitter, userAustin.longitude - jitter);
      });

      await Future.wait(parallelSorts);

      // Verify repository remains in consistent, uncorrupted state
      expect(repo.currentUserGpsLocation, isNotNull);
      final sorted = repo.filteredDetailers;
      expect(sorted.length, 4);

      // Detailer order must be deterministic: micro (~0.05 mi) < sub-mile (~0.12 mi) < antipodal (~12,437 mi) < null coords (null at end)
      expect(sorted[0].id, studioMicroDist.id);
      expect(sorted[1].id, studioSubMile.id);
      expect(sorted[2].id, studioAntipodal.id);
      expect(sorted[3].id, studioNullCoords.id);

      // Distance cache holds valid values
      expect(repo.getDistanceToDetailer(studioMicroDist.id), isNotNull);
      expect(repo.getDistanceToDetailer(studioSubMile.id), isNotNull);
      expect(repo.getDistanceToDetailer(studioAntipodal.id), isNotNull);
      expect(repo.getDistanceToDetailer(studioNullCoords.id), isNull);

      // Listeners were notified without crashes or infinite loops
      expect(notificationCount, greaterThanOrEqualTo(20));
    });

    testWidgets('1.3 Alternating Rapid Toggle Cycle: 20 sequential On/Off toggles', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocationService.setMockLocationProvider(() async => userAustin);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioMicroDist, studioSubMile]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final nearMeFinder = find.byKey(const Key('near_me_gps_btn'));

      // Perform 20 toggle cycles (10 ON, 10 OFF)
      for (int i = 0; i < 20; i++) {
        await tester.tap(nearMeFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        if (i % 2 == 0) {
          // Even iteration (0, 2, ...): Should be ON
          expect(repo.currentUserGpsLocation, isNotNull, reason: 'Iteration $i should be active');
        } else {
          // Odd iteration (1, 3, ...): Should be OFF
          expect(repo.currentUserGpsLocation, isNull, reason: 'Iteration $i should be cleared');
        }
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.4 Disposing FeedScreen while GPS request is in-flight does not throw setState() on unmounted widget', (tester) async {
      final gpsCompleter = Completer<LocationCoordinates?>();
      LocationService.setMockLocationProvider(() => gpsCompleter.future);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioMicroDist]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();

      // Trigger Near Me (request now in-flight)
      await tester.tap(find.byKey(const Key('near_me_gps_btn')));
      await tester.pump();

      // Immediately unmount FeedScreen by pumping an empty SizedBox
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      // Now complete the delayed GPS request
      gpsCompleter.complete(userAustin);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verification: The unmounted check `if (!context.mounted) return;` prevented any FlutterError
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 2. EXTREME COORDINATE DISTANCES, BADGES & VIEWPORT LAYOUT (390px Mobile)
  // =========================================================================
  group('2. Extreme Coordinate Distances & Viewport Layout Safety (390px Mobile Viewport)', () {
    testWidgets('2.1 Mobile Viewport (390px): Micro-distance, Antipodal, Null coords & Long labels render with 0 overflow', (tester) async {
      // Set to standard 390x844 mobile viewport (iPhone 12/13/14)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocationService.setMockLocationProvider(() async => userAustin);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([
        studioMicroDist,       // ~0.048 mi -> "Under 0.1 mi away"
        studioSubMile,         // ~0.117 mi -> "0.1 mi away"
        studioAntipodal,       // ~12,437 mi -> "12437 mi away"
        studioNullCoords,      // null coords -> location text fallback
        studioSuperLongLabels, // massive text + micro-distance
      ]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger "Near Me" GPS sort on mobile
      final nearMeButton = find.byKey(const Key('near_me_gps_btn'));
      expect(nearMeButton, findsOneWidget);
      await tester.tap(nearMeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Empirical Assertions:
      // 1. Zero RenderFlex overflow errors on 390px viewport
      expect(tester.takeException(), isNull);

      // 2. Verify Micro-distance badge (< 0.1 mi): "Under 0.1 mi away" and super long labels on initial viewport
      expect(find.text('Under 0.1 mi away'), findsWidgets);
      expect(find.byKey(Key('detailer_card_${studioSuperLongLabels.id}')), findsOneWidget);
      expect(find.byKey(Key('studio_distance_badge_${studioSuperLongLabels.id}')), findsOneWidget);

      // Scroll the horizontal detailer ListView across the 390px viewport to verify remaining studios
      final horizontalList = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);

      // 3. Scroll to sub-mile badge (~0.12 mi): "0.1 mi away"
      await tester.drag(horizontalList, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('0.1 mi away'), findsOneWidget);

      // 4. Scroll to antipodal badge (> 12,000 mi): "12437 mi away"
      await tester.drag(horizontalList, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('12437 mi away'), findsOneWidget);

      // 5. Scroll to null coordinate studio: NO distance badge and renders fallback location text
      await tester.drag(horizontalList, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('studio_distance_badge_${studioNullCoords.id}')), findsNothing);
      expect(find.byKey(Key('studio_location_text_${studioNullCoords.id}')), findsOneWidget);

      expect(tester.takeException(), isNull, reason: 'Scrolling detailer cards on 390px viewport must not overflow');
    });

    testWidgets('2.2 Zero-distance identical coordinates return "Under 0.1 mi away"', (tester) async {
      // Detailer at the EXACT same lat/lon as user
      final studioExactUserLoc = studioMicroDist.copyWith(
        id: 'det_exact_loc',
        studioLatitude: userAustin.latitude,
        studioLongitude: userAustin.longitude,
      );

      LocationService.setMockLocationProvider(() async => userAustin);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioExactUserLoc]);

      await repo.sortDetailersByProximity(userAustin.latitude, userAustin.longitude);
      final dist = repo.getDistanceToDetailer('det_exact_loc');

      expect(dist, 0.0);
      final formatted = LocationService.formatDistance(dist);
      expect(formatted, 'Under 0.1 mi away');
    });
  });

  // =========================================================================
  // 3. SPECIAL CHARACTERS & REGEX INJECTION IN SEARCH
  // =========================================================================
  group('3. Special Characters, Regex Injection & Unicode Search Stress', () {
    testWidgets('3.1 Regex meta-characters search does not throw regex syntax exceptions and matches literally', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([
        studioMicroDist,
        studioSubMile,
        studioEmojiSpecial, // Contains '.*', '[VIP]', '(special)' in title/bio
      ]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).first;

      // Adversarial regex attack vectors:
      final adversarialQueries = [
        r'.*',             // Wildcard match
        r'[',              // Unclosed bracket class
        r'(',              // Unclosed group
        r'$^',             // Start/end anchor mismatch
        r'\d+',           // Regex escape
        r'\bword\b',     // Word boundary
        r'?+*{}',          // Repetition quantifier stack
        r'a{1,100000}',    // ReDoS quantifier attempt
        r'^(.*)$',        // Full-line regex capture
        r'([a-zA-Z0-9_]+)*$', // Catastrophic backtracking attempt
      ];

      for (final query in adversarialQueries) {
        await tester.enterText(searchField, query);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 1. Zero regex syntax exceptions
        expect(tester.takeException(), isNull, reason: 'Query "$query" must not throw FormatException');

        // 2. Query is evaluated as literal substring:
        // '.*' and '[' and '(' are present literally in studioEmojiSpecial!
        if (query == '.*' || query == '[' || query == '(') {
          expect(repo.filteredDetailers.any((d) => d.id == studioEmojiSpecial.id), isTrue,
              reason: 'Query "$query" should match studioEmojiSpecial literally');
        } else {
          // Other patterns do not match literal strings, so list is empty safely
          expect(repo.filteredDetailers.where((d) => d.id == studioMicroDist.id), isEmpty);
        }
      }

      // Clear search to restore state
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(repo.filteredDetailers.length, 3);
    });

    testWidgets('3.2 Emojis and UTF-16 surrogate pairs in search queries and studio names', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([
        studioMicroDist,
        studioEmojiSpecial, // Business name: '⚡ Apex Auto Pro 🚗📍 [Premium & Custom]'
      ]);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).first;

      // 1. Search for emoji '🚗📍'
      await tester.enterText(searchField, '🚗📍');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.filteredDetailers.length, 1);
      expect(repo.filteredDetailers.first.id, studioEmojiSpecial.id);
      expect(find.byKey(Key('detailer_card_${studioEmojiSpecial.id}')), findsOneWidget);
      expect(find.byKey(Key('detailer_card_${studioMicroDist.id}')), findsNothing);

      // 2. Search for emoji '✨'
      await tester.enterText(searchField, '✨');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.filteredDetailers.length, 1);
      expect(repo.filteredDetailers.first.id, studioEmojiSpecial.id);

      // 3. Search for emoji not present in any studio: '🛸'
      await tester.enterText(searchField, '🛸');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.filteredDetailers, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.3 Extreme input queries: Whitespace, 5,000 chars, SQL/XSS injections', (tester) async {
      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioMicroDist, studioSubMile]);

      // Whitespace and tab queries
      repo.setSearchQuery('     ');
      expect(repo.filteredDetailers.length, 2, reason: 'Whitespace-only query must not filter out all detailers');

      repo.setSearchQuery('\t\n\r');
      expect(repo.filteredDetailers.length, 2);

      // SQL injection strings
      repo.setSearchQuery("'; DROP TABLE profiles; SELECT * FROM bookings WHERE '1'='1");
      expect(repo.filteredDetailers, isEmpty);

      // XSS injection strings
      repo.setSearchQuery("<script>alert('xss');</script><img src=x onerror=alert(1)>");
      expect(repo.filteredDetailers, isEmpty);

      // Massive 5,000 character string
      final hugeString = 'A' * 5000;
      repo.setSearchQuery(hugeString);
      expect(repo.filteredDetailers, isEmpty);

      // Reset query
      repo.setSearchQuery('');
      expect(repo.filteredDetailers.length, 2);
    });

    testWidgets('3.4 Combined Proximity Sorting + Search Query Filtering', (tester) async {
      LocationService.setMockLocationProvider(() async => userAustin);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([
        studioMicroDist, // Austin (0.05 mi), Ceramic Coating
        studioSubMile,   // Austin (0.12 mi), Interior Deep Clean
        studioAntipodal, // Oceanic (12,437 mi), Ceramic
      ]);

      // Activate Near Me GPS proximity sort
      await repo.sortDetailersByProximity(userAustin.latitude, userAustin.longitude);
      expect(repo.filteredDetailers.length, 3);
      expect(repo.filteredDetailers[0].id, studioMicroDist.id);
      expect(repo.filteredDetailers[1].id, studioSubMile.id);
      expect(repo.filteredDetailers[2].id, studioAntipodal.id);

      // Search for 'Ceramic' while proximity sort is active
      repo.setSearchQuery('Ceramic');
      final filtered = repo.filteredDetailers;

      // Only studioMicroDist and studioAntipodal have 'Ceramic' in packages
      expect(filtered.length, 2);
      expect(filtered[0].id, studioMicroDist.id);   // ~0.05 mi away
      expect(filtered[1].id, studioAntipodal.id);   // ~12,437 mi away
      expect(repo.getDistanceToDetailer(filtered[0].id), isNotNull);
      expect(repo.getDistanceToDetailer(filtered[1].id), isNotNull);
    });
  });

  // =========================================================================
  // 4. DISTANCE FORMATTING & MATHEMATICAL BOUNDARY INVARIANTS
  // =========================================================================
  group('4. Distance Formatting & Mathematical Boundary Invariants', () {
    test('4.1 LocationService.formatDistance handles all edge cases and boundaries', () {
      // Null, NaN, Infinite, Negative
      expect(LocationService.formatDistance(null), '');
      expect(LocationService.formatDistance(double.nan), '');
      expect(LocationService.formatDistance(double.infinity), '');
      expect(LocationService.formatDistance(double.negativeInfinity), '');
      expect(LocationService.formatDistance(-0.001), '');
      expect(LocationService.formatDistance(-100.0), '');

      // Boundary: Exactly 0.0 miles
      expect(LocationService.formatDistance(0.0), 'Under 0.1 mi away');

      // Boundary: Sub-0.1 miles (< 0.1)
      expect(LocationService.formatDistance(0.0001), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(0.05), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(0.0999), 'Under 0.1 mi away');

      // Boundary: Exactly 0.1 miles
      expect(LocationService.formatDistance(0.1), '0.1 mi away');
      expect(LocationService.formatDistance(0.12), '0.1 mi away');
      // Due to IEEE 754 floating point representation, 0.95 is slightly below 0.95 (0.94999...) -> '0.9 mi away'
      expect(LocationService.formatDistance(0.95), '0.9 mi away');
      expect(LocationService.formatDistance(0.96), '1.0 mi away');

      // Boundary: Single decimal place (0.1 to 9.9)
      expect(LocationService.formatDistance(1.24), '1.2 mi away');
      expect(LocationService.formatDistance(1.26), '1.3 mi away');
      expect(LocationService.formatDistance(9.94), '9.9 mi away');

      // Boundary: 10.0+ miles (integer rounding)
      expect(LocationService.formatDistance(10.0), '10 mi away');
      expect(LocationService.formatDistance(10.4), '10 mi away');
      expect(LocationService.formatDistance(10.6), '11 mi away');
      expect(LocationService.formatDistance(99.9), '100 mi away');
      expect(LocationService.formatDistance(12436.8), '12437 mi away');
    });

    test('4.2 Dynamic Detailer addition during active GPS sort computes distance on-demand', () {
      final repo = JobRepository();
      repo.setPublicDetailersForTesting([studioMicroDist]);

      // Sort with only 1 detailer
      repo.sortDetailersByProximity(userAustin.latitude, userAustin.longitude);
      expect(repo.getDistanceToDetailer(studioMicroDist.id), isNotNull);

      // Now dynamically add studioAntipodal into publicDetailers
      repo.setPublicDetailersForTesting([studioMicroDist, studioAntipodal]);

      // Cache did not originally have studioAntipodal, but getDistanceToDetailer calculates on-demand!
      final onDemandDist = repo.getDistanceToDetailer(studioAntipodal.id);
      expect(onDemandDist, isNotNull);
      expect(onDemandDist!, greaterThan(10000.0));
      expect(LocationService.formatDistance(onDemandDist), '12437 mi away');
    });
  });
}
