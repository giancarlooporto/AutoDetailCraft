// =========================================================================
// File: test/tier2_widgets/explore_location_search_and_near_me_test.dart
// Description: Widget test suite for Explore Location Search & Near Me GPS
// Milestone: M2 (Zero-cost browsing, GPS proximity sorting, and error resilience)
// =========================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/location_service.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Synthetic User Benchmark: Downtown Austin (6th & Congress)
  const mockAustinCoords = LocationCoordinates(
    latitude: 30.2672,
    longitude: -97.7431,
  );

  // 1. Studio Austin (~1.2 miles from user benchmark)
  final studioAustin = const UserProfile(
    id: 'det_austin',
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
    averageRating: 4.9,
    servicePackages: [
      ServicePackage(
        id: 'pkg_atx_1',
        title: 'Ceramic Coating',
        description: 'Full ceramic coating',
        basePrice: 500.0,
        estimatedDuration: '4 hours',
        includes: ['Paint correction', 'Coating'],
      ),
    ],
  );

  // 2. Studio Round Rock (~17.0 miles from user benchmark)
  final studioRoundRock = const UserProfile(
    id: 'det_round_rock',
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
    averageRating: 4.8,
    servicePackages: [
      ServicePackage(
        id: 'pkg_rr_1',
        title: 'Interior Deep Clean',
        description: 'Shampoo and steam',
        basePrice: 200.0,
        estimatedDuration: '3 hours',
        includes: ['Steam', 'Extraction'],
      ),
    ],
  );

  // 3. Studio San Antonio (~73.5 miles from user benchmark)
  final studioSanAntonio = const UserProfile(
    id: 'det_san_antonio',
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
    averageRating: 4.7,
    servicePackages: [
      ServicePackage(
        id: 'pkg_sa_1',
        title: 'Paint Correction',
        description: '2-Stage paint correction',
        basePrice: 400.0,
        estimatedDuration: '5 hours',
        includes: ['Cut', 'Polish'],
      ),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.resetMockLocationProvider();
  });

  tearDown(() {
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

  Future<void> triggerNearMeFromDropdown(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('location_dropdown_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location_menu_near_me_item')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // =========================================================================
  // SECTION 1: Unified Location Switcher ("Current Location (Near Me)") Rendering
  // =========================================================================
  group('1. Unified Location Switcher Rendering', () {
    testWidgets('1.1 Desktop Viewport: Removes standalone Near Me button and provides Current Location in dropdown', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Standalone Near Me button is removed (Turo / Airbnb unified bar)
      expect(find.byKey(const Key('near_me_gps_btn')), findsNothing);
      final locationDropdown = find.byKey(const Key('location_dropdown_btn'));
      expect(locationDropdown, findsOneWidget, reason: 'Location dropdown must be rendered on desktop');

      // Proximity sorting must initially be inactive without GPS coordinates
      expect(repo.currentUserGpsLocation, isNull);
      expect(find.textContaining('mi away'), findsNothing, reason: 'Distance badges must not show prior to GPS action');

      // Opening location dropdown exposes Current Location (Near Me) as #1 option
      await tester.tap(locationDropdown);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location_menu_near_me_item')), findsOneWidget);
    });

    testWidgets('1.2 Mobile Viewport: Removes standalone Near Me button and provides Current Location in dropdown', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('near_me_gps_btn')), findsNothing);
      final locationDropdown = find.byKey(const Key('location_dropdown_btn'));
      expect(locationDropdown, findsOneWidget, reason: 'Location dropdown must be rendered on mobile filter bar');

      await tester.tap(locationDropdown);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location_menu_near_me_item')), findsOneWidget);
    });
  });

  // =========================================================================
  // SECTION 2: Near Me GPS Proximity Sorting & Distance Badges
  // =========================================================================
  group('2. Near Me GPS Proximity Sorting & Distance Badges', () {
    testWidgets('2.1 Selecting "Current Location (Near Me)" sorts studios by distance and displays distance badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Inject deterministic mock GPS coordinates
      LocationService.setMockLocationProvider(() async => mockAustinCoords);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      // Seed detailers in non-proximity order: San Antonio (~74 mi), Round Rock (~17 mi), Austin (~1.2 mi)
      repo.setPublicDetailersForTesting([studioSanAntonio, studioRoundRock, studioAustin]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select "Current Location (Near Me)" from location dropdown
      await triggerNearMeFromDropdown(tester);

      // 1. Verify repository state reflects GPS location
      expect(repo.currentUserGpsLocation, isNotNull);
      expect(repo.currentUserGpsLocation!.latitude, 30.2672);
      expect(repo.currentUserGpsLocation!.longitude, -97.7431);

      // 2. Verify repository order: Austin (1.2 mi) < Round Rock (17 mi) < San Antonio (74 mi)
      final sortedDetailers = repo.filteredDetailers;
      expect(sortedDetailers.length, 3);
      expect(sortedDetailers[0].id, 'det_austin');
      expect(sortedDetailers[1].id, 'det_round_rock');
      expect(sortedDetailers[2].id, 'det_san_antonio');

      // 3. Verify horizontal visual positioning on screen
      final austinCard = find.byKey(const Key('detailer_card_det_austin'));
      final roundRockCard = find.byKey(const Key('detailer_card_det_round_rock'));
      final sanAntonioCard = find.byKey(const Key('detailer_card_det_san_antonio'));

      expect(austinCard, findsOneWidget);
      expect(roundRockCard, findsOneWidget);
      expect(sanAntonioCard, findsOneWidget);

      final austinX = tester.getTopLeft(austinCard).dx;
      final roundRockX = tester.getTopLeft(roundRockCard).dx;
      final sanAntonioX = tester.getTopLeft(sanAntonioCard).dx;

      expect(austinX, lessThan(roundRockX), reason: 'Austin studio must be rendered to the left of Round Rock');
      expect(roundRockX, lessThan(sanAntonioX), reason: 'Round Rock studio must be rendered to the left of San Antonio');

      // 4. Verify distance badges rendered on cards
      expect(find.text('1.2 mi away'), findsOneWidget);
      expect(find.text('17 mi away'), findsOneWidget);
      expect(find.text('74 mi away'), findsOneWidget);
      expect(find.textContaining('mi away'), findsNWidgets(3));
    });

    testWidgets('2.2 Resetting filters clears proximity sort and distance badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocationService.setMockLocationProvider(() async => mockAustinCoords);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger Near Me
      await triggerNearMeFromDropdown(tester);
      expect(find.textContaining('mi away'), findsWidgets);

      // Tap Reset Filters button
      final resetBtn = find.byKey(const Key('reset_filters_btn'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify distance badges disappear and proximity sort is cleared
      expect(find.textContaining('mi away'), findsNothing);
      expect(repo.currentUserGpsLocation, isNull);
    });

    testWidgets('2.3 Selecting Current Location (Near Me) while active toggles it off and clears proximity sort', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocationService.setMockLocationProvider(() async => mockAustinCoords);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 1: Activate Near Me
      await triggerNearMeFromDropdown(tester);
      expect(repo.currentUserGpsLocation, isNotNull);
      expect(find.textContaining('mi away'), findsWidgets);

      // Tap 2: Toggle off
      await triggerNearMeFromDropdown(tester);

      expect(repo.currentUserGpsLocation, isNull);
      expect(find.textContaining('mi away'), findsNothing);
    });
  });

  // =========================================================================
  // SECTION 3: Zero-Cost City & ZIP Search ($0.00 External Quota)
  // =========================================================================
  group('3. Zero-Cost City & ZIP Search', () {
    testWidgets('3.1 City text search filters studios in-memory without network calls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock, studioSanAntonio]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find search field
      final searchField = find.byType(TextField).first;
      expect(searchField, findsOneWidget);

      // Search for "Round Rock"
      await tester.enterText(searchField, 'Round Rock');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify only Round Rock studio remains visible
      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_austin')), findsNothing);
      expect(find.byKey(const Key('detailer_card_det_san_antonio')), findsNothing);

      // Clear search query
      await tester.enterText(searchField, '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // All studios return
      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_austin')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_san_antonio')), findsOneWidget);
    });

    testWidgets('3.2 ZIP code text search isolates studios by postal code', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock, studioSanAntonio]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).first;

      // Search by Round Rock ZIP: 78664
      await tester.enterText(searchField, '78664');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_austin')), findsNothing);
      expect(find.byKey(const Key('detailer_card_det_san_antonio')), findsNothing);

      // Search by Austin ZIP: 78704
      await tester.enterText(searchField, '78704');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('detailer_card_det_austin')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsNothing);
      expect(find.byKey(const Key('detailer_card_det_san_antonio')), findsNothing);
    });

    test('3.3 Near Me is active by default (sorting nearby detailers and their posts first) until user searches a place (city, province, state)', () async {
      final austinClient = const UserProfile(
        id: 'usr_austin_client',
        role: UserRole.client,
        username: 'austinclient',
        displayName: 'Austin Client',
        businessName: '',
        city: 'Austin',
        state: 'TX',
        latitude: 30.2672,
        longitude: -97.7431,
      );

      final repo = await TestHarness.createSession(isLoggedIn: false);
      await repo.updateCurrentUser(austinClient);
      repo.isLoggedIn = true;
      // Seed San Antonio BEFORE Austin so default ordering proves Near Me sorting
      repo.setPublicDetailersForTesting([studioSanAntonio, studioAustin]);

      final saPost = DetailJob(
        id: 'job_sa_post_01',
        author: studioSanAntonio,
        createdAt: DateTime.now(),
        title: 'San Antonio Newer Post',
        description: 'Latest post from farther city',
        vehicleYear: 2025,
        vehicleMake: 'BMW',
        vehicleModel: 'M3',
        paintColorName: 'Black Sapphire',
        paintCode: '475',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 130,
        finalPaintThicknessMicrons: 126,
        defectSeverity: 2,
        serviceType: 'Paint Correction',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/sa_b.jpg',
        afterImageUrl: 'https://example.com/sa_a.jpg',
      );
      final austinPost = DetailJob(
        id: 'job_austin_post_01',
        author: studioAustin,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        title: 'Austin Nearby Post',
        description: 'Older post from nearby studio',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: '911',
        paintColorName: 'Guards Red',
        paintCode: '84A',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 132,
        finalPaintThicknessMicrons: 128,
        defectSeverity: 2,
        serviceType: 'Ceramic Coating',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/atx_b.jpg',
        afterImageUrl: 'https://example.com/atx_a.jpg',
      );

      repo.addJob(saPost);
      repo.addJob(austinPost);

      // 1. Default Explore state has Near Me active, showing Austin studio & Austin post first
      expect(repo.isNearMeActive, isTrue);
      expect(repo.filteredDetailers.first.id, equals(studioAustin.id));
      expect(repo.filteredJobs.first.id, equals(austinPost.id));

      // 2. Searching a place by city or state/province switches off default Near Me and shows that place
      repo.setSearchQuery('San Antonio');
      expect(repo.isNearMeActive, isFalse);
      expect(repo.filteredDetailers.map((d) => d.id), equals([studioSanAntonio.id]));
      expect(repo.filteredJobs.map((j) => j.id), equals([saPost.id]));

      repo.setSearchQuery('');
      expect(repo.isNearMeActive, isTrue);
      expect(repo.filteredDetailers.first.id, equals(studioAustin.id));
      expect(repo.filteredJobs.first.id, equals(austinPost.id));

      // 3. Selecting a city from the location dropdown also deactivates Near Me until reset to All Locations
      repo.setLocationFilter('San Antonio, TX');
      expect(repo.isNearMeActive, isFalse);
      expect(repo.filteredDetailers.map((d) => d.id), equals([studioSanAntonio.id]));
      expect(repo.filteredJobs.map((j) => j.id), equals([saPost.id]));

      repo.setLocationFilter('All Locations');
      expect(repo.isNearMeActive, isTrue);
      expect(repo.filteredDetailers.first.id, equals(studioAustin.id));
      expect(repo.filteredJobs.first.id, equals(austinPost.id));
    });

    test('3.4 Searching "near me" or "<service> near me" in search bar strips "near me" phrase, activates proximity sorting, and filters by service keyword', () async {
      // 1. Phrase detection and stripping
      expect(JobRepository.containsNearMePhrase('near me'), isTrue);
      expect(JobRepository.containsNearMePhrase('Near Me'), isTrue);
      expect(JobRepository.containsNearMePhrase('ceramic coating near me'), isTrue);
      expect(JobRepository.containsNearMePhrase('near me paint correction'), isTrue);
      expect(JobRepository.containsNearMePhrase('tint nearby'), isTrue);
      expect(JobRepository.containsNearMePhrase('mobile detailing around me'), isTrue);
      expect(JobRepository.containsNearMePhrase('Austin, TX'), isFalse);

      expect(JobRepository.stripNearMePhrase('near me'), equals(''));
      expect(JobRepository.stripNearMePhrase('Near Me'), equals(''));
      expect(JobRepository.stripNearMePhrase('ceramic coating near me'), equals('ceramic coating'));
      expect(JobRepository.stripNearMePhrase('near me paint correction'), equals('paint correction'));
      expect(JobRepository.stripNearMePhrase('tint nearby'), equals('tint'));
      expect(JobRepository.stripNearMePhrase('mobile detailing around me'), equals('mobile detailing'));

      final austinClient = const UserProfile(
        id: 'usr_austin_client',
        role: UserRole.client,
        username: 'austinclient',
        displayName: 'Austin Client',
        businessName: '',
        city: 'Austin',
        state: 'TX',
        latitude: 30.2672,
        longitude: -97.7431,
      );

      final studioSanAntonioCeramic = studioSanAntonio.copyWith(
        id: 'det_sa_ceramic',
        servicePackages: studioAustin.servicePackages,
      );

      final repo = await TestHarness.createSession(isLoggedIn: false);
      await repo.updateCurrentUser(austinClient);
      repo.isLoggedIn = true;
      repo.setPublicDetailersForTesting([studioSanAntonio, studioSanAntonioCeramic, studioAustin]);

      final saPost = DetailJob(
        id: 'job_sa_post_02',
        author: studioSanAntonio,
        createdAt: DateTime.now(),
        title: 'San Antonio Newer Post',
        description: 'Multi-step paint correction in SA',
        vehicleYear: 2025,
        vehicleMake: 'BMW',
        vehicleModel: 'M3',
        paintColorName: 'Black Sapphire',
        paintCode: '475',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 130,
        finalPaintThicknessMicrons: 126,
        defectSeverity: 2,
        serviceType: 'Paint Correction',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/sa_b.jpg',
        afterImageUrl: 'https://example.com/sa_a.jpg',
      );
      final austinPost = DetailJob(
        id: 'job_austin_post_02',
        author: studioAustin,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        title: 'Austin Nearby Gloss',
        description: '9H gloss protection package',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: '911',
        paintColorName: 'Guards Red',
        paintCode: '84A',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 132,
        finalPaintThicknessMicrons: 128,
        defectSeverity: 2,
        serviceType: 'Ceramic Coating',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/atx_b.jpg',
        afterImageUrl: 'https://example.com/atx_a.jpg',
      );

      repo.addJob(saPost);
      repo.addJob(austinPost);

      // First select San Antonio in dropdown (deactivating Near Me)
      repo.setLocationFilter('San Antonio, TX');
      expect(repo.isNearMeActive, isFalse);
      expect(repo.selectedLocationCity, equals('San Antonio, TX'));

      // 2. Typing standalone 'near me' resets city filter and restores Near Me sorting
      repo.setSearchQuery('near me');
      expect(repo.isNearMeActive, isTrue);
      expect(repo.selectedLocationCity, equals('All Locations'));
      expect(repo.effectiveSearchQuery, isEmpty);
      expect(repo.filteredDetailers.length, equals(3));
      expect(repo.filteredDetailers.first.id, equals(studioAustin.id));
      expect(repo.filteredJobs.first.id, equals(austinPost.id));

      // 3. Typing '<service> near me' strips 'near me', filters by service, and sorts nearest first
      repo.setSearchQuery('Ceramic Coating near me');
      expect(repo.isNearMeActive, isTrue);
      expect(repo.effectiveSearchQuery, equals('Ceramic Coating'));
      expect(repo.filteredDetailers.map((d) => d.id), equals([studioAustin.id, studioSanAntonioCeramic.id]));
      expect(repo.filteredJobs.map((j) => j.id), equals([austinPost.id]));

      repo.setSearchQuery('Paint Correction near me');
      expect(repo.isNearMeActive, isTrue);
      expect(repo.effectiveSearchQuery, equals('Paint Correction'));
      expect(repo.filteredJobs.map((j) => j.id), equals([saPost.id]));
    });
  });

  // =========================================================================
  // SECTION 4: Error & Permission Denied Handling
  // =========================================================================
  group('4. Error & Permission Denied Handling', () {
    testWidgets('4.1 Location permission denied (null coordinates) shows feedback gracefully without crashing', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Simulate permission denied or GPS disabled (returns null)
      LocationService.setMockLocationProvider(() async => null);

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select "Current Location (Near Me)" from location dropdown
      await triggerNearMeFromDropdown(tester);

      // Verification: App did not crash, studio cards remain visible, no unhandled error
      expect(find.byKey(const Key('detailer_card_det_austin')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsOneWidget);
      expect(repo.currentUserGpsLocation, isNull);

      // Informational feedback is presented to the user
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('4.2 Platform exception in GPS provider is caught safely without app crash', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Simulate hardware error / permission permanently denied throwing exception
      LocationService.setMockLocationProvider(() async => throw Exception('Location hardware error: GPS timeout'));

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.setPublicDetailersForTesting([studioAustin, studioRoundRock]);

      await tester.pumpWidget(buildFeedScreen(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select "Current Location (Near Me)" from location dropdown
      await triggerNearMeFromDropdown(tester);

      // Verification: App caught the error safely; no unhandled exception thrown to tester
      expect(find.byKey(const Key('detailer_card_det_austin')), findsOneWidget);
      expect(find.byKey(const Key('detailer_card_det_round_rock')), findsOneWidget);
      expect(repo.currentUserGpsLocation, isNull);
    });
  });
}
