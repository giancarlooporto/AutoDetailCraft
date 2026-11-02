// =========================================================================
// File: test/challenger/booking_checkout_location_stress_test.dart
// Description: Adversarial empirical stress harness for Checkout Service
//              Location Selector & UI Handoffs (Milestone M3).
//
// Attack Vectors & Stress Scenarios:
// 1. UI Toggling & State Flapping:
//    - Rapid alternating toggles (25 consecutive flips) between 'Saved Home Address'
//      (Key('checkout_location_home_option')) and 'Temporary Location'
//      (Key('checkout_location_temp_option')).
//    - Verification of controller integrity (no disposal exceptions, no memory leaks),
//      input preservation across flips, and coherent final state selection.
// 2. Form Boundary & Incomplete Input Stress:
//    - User enters temporary street but leaves city, state, and zip empty.
//      Verify address assembly joins non-empty parts cleanly without trailing commas,
//      leading commas, double commas, or literal 'null' strings.
//    - Incomplete permutations: only street + zip, only city + state, etc.
//    - Extreme gate codes: 500+ characters, newlines, emojis, special characters
//      (*#1234# - Call box broken). Verify BookingAppointment preserves text exactly
//      and round-trips via JSON/Supabase without truncation.
// 3. Responsive & Viewport Stress (390x844 Mobile Viewport):
//    - Render BookingFlowScreen on 390x844 (iPhone 12/13/14 physical viewport).
//    - Expand checkout_service_location_card with all temporary fields and long strings.
//    - Verify zero RenderFlex overflows during render, typing, and scrolling.
// 4. Detailer Workbench & Client Bookings UI:
//    - Mount DetailerWorkbenchView on mobile & desktop viewports with extreme gate code.
//    - Verify Key('detailer_booking_gate_code') renders without overflow.
//    - Verify tapping Key('detailer_booking_navigate_btn') triggers MapLauncherService.
//    - Verify Client Bookings (BookingsListScreen) displays gate code and triggers
//      Key('client_booking_navigate_btn') navigation handoff.
// =========================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/map_launcher_service.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testStudioDetailer = UserProfile(
    id: 'usr_detailer_austin',
    username: 'marcus_apex',
    displayName: 'Marcus Vance',
    businessName: 'Apex Precision Detailing',
    location: 'Austin, TX',
    streetAddress: '1200 S Congress Ave',
    city: 'Austin',
    state: 'TX',
    postalCode: '78704',
    studioStreetAddress: '500 E 4th St',
    studioUnitOrApt: 'Bay 2B',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78701',
    studioLatitude: 30.2655,
    studioLongitude: -97.7398,
    servicePackages: [
      ServicePackage(
        id: 'pkg_full_detail',
        title: 'Full Signature Detail',
        description: 'Comprehensive interior and exterior restoration',
        basePrice: 350.0,
        estimatedDuration: '4 hrs',
        includes: ['Hand wash', 'Clay bar', 'Interior deep clean'],
      ),
    ],
  );

  const testClientUser = UserProfile(
    id: 'usr_client_01',
    username: 'alex@example.com',
    displayName: 'Alex Client',
    phone: '(512) 555-0199',
    streetAddress: '1200 S Congress Ave',
    unitOrApt: 'Apt 304',
    city: 'Austin',
    state: 'TX',
    postalCode: '78704',
    latitude: 30.2505,
    longitude: -97.7495,
    myGarage: [
      UserVehicle(
        id: 'veh_01',
        make: 'Porsche',
        model: '911 GT3',
        year: 2024,
        colorName: 'Shark Blue',
        imageUrl: '',
        vehicleType: 'Coupe',
      ),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MapLauncherService.resetMockLauncher();
  });

  tearDown(() {
    MapLauncherService.resetMockLauncher();
  });

  // =========================================================================
  // GROUP 1: UI TOGGLING & STATE FLAPPING
  // =========================================================================
  group('Challenger Vector 1: UI Toggling & State Flapping', () {
    testWidgets('1.1 Rapid repeated toggling (25 flaps) between Home and Temp maintains state coherence and controller lifecycle', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate Step 0 -> Step 1 -> Step 2 (Checkout Review)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final homeToggleFinder = find.byKey(const Key('checkout_location_home_option'));
        final tempToggleFinder = find.byKey(const Key('checkout_location_temp_option'));

        expect(homeToggleFinder, findsOneWidget);
        expect(tempToggleFinder, findsOneWidget);

        // Verify initial state: Saved Home Address is pre-selected
        expect(find.byKey(const Key('checkout_temp_street_field')), findsNothing);

        // Perform 25 rapid consecutive toggles back and forth
        for (int i = 0; i < 25; i++) {
          if (i % 2 == 0) {
            await tester.tap(tempToggleFinder);
          } else {
            await tester.tap(homeToggleFinder);
          }
          await tester.pump(); // Fast pump simulating rapid user taps
        }
        await tester.pumpAndSettle();

        // 25 iterations (i=0 to 24), odd index (24 is even -> ends on temp toggle)
        // Verify temporary location input fields are mounted and responsive
        expect(find.byKey(const Key('checkout_temp_street_field')), findsOneWidget);

        // Enter text into temporary street field
        await tester.enterText(find.byKey(const Key('checkout_temp_street_field')), '888 Flapping Drive');
        await tester.pumpAndSettle();

        // Toggle back to Home
        await tester.tap(homeToggleFinder);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('checkout_temp_street_field')), findsNothing);

        // Toggle back to Temp: text in controller must have been preserved without memory leak or recreation
        await tester.tap(tempToggleFinder);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('checkout_temp_street_field')), findsOneWidget);
        expect(find.text('888 Flapping Drive'), findsOneWidget);

        // Verify no uncaught exceptions thrown during flapping
        expect(tester.takeException(), isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('1.2 Multiple toggles followed by Home selection confirms booking with Home Address', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final homeToggle = find.byKey(const Key('checkout_location_home_option'));
        final tempToggle = find.byKey(const Key('checkout_location_temp_option'));

        // Toggle to temp, type text, then toggle back to home
        await tester.tap(tempToggle);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('checkout_temp_street_field')), 'Discarded Temp St');
        await tester.pumpAndSettle();

        await tester.tap(homeToggle);
        await tester.pumpAndSettle();

        // Confirm booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Verify created appointment used the saved client home address and coordinates
        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;
        expect(booking.clientAddress, equals(testClientUser.formattedClientAddress));
        expect(booking.latitude, equals(testClientUser.latitude));
        expect(booking.longitude, equals(testClientUser.longitude));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });

  // =========================================================================
  // GROUP 2: FORM BOUNDARY & INCOMPLETE INPUT STRESS
  // =========================================================================
  group('Challenger Vector 2: Form Boundary & Incomplete Input Stress', () {
    testWidgets('2.1 Temporary street only: clean address assembly without trailing commas, nulls, or leading punctuation', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 0 -> Step 1 -> Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Select Temporary Location
        await tester.tap(find.byKey(const Key('checkout_location_temp_option')));
        await tester.pumpAndSettle();

        // Enter street ONLY, leaving unit, city, state, and zip empty
        const singleStreetInput = '990 Industrial Boulevard';
        await tester.enterText(find.byKey(const Key('checkout_temp_street_field')), singleStreetInput);
        await tester.pumpAndSettle();

        // Submit Booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;

        // Empirical assertion on address assembly
        expect(booking.clientAddress, equals(singleStreetInput));
        expect(booking.clientAddress.endsWith(','), isFalse, reason: 'Address must not have trailing comma');
        expect(booking.clientAddress.startsWith(','), isFalse, reason: 'Address must not have leading comma');
        expect(booking.clientAddress.contains(',,'), isFalse, reason: 'Address must not have double commas');
        expect(booking.clientAddress.contains('null'), isFalse, reason: 'Address must not stringify null');
        expect(booking.latitude, isNull, reason: 'Temporary un-geocoded address must have null latitude (\$0 cost)');
        expect(booking.longitude, isNull, reason: 'Temporary un-geocoded address must have null longitude (\$0 cost)');
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2.2 Partial address permutations (street + zip, city + state) assemble cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('checkout_location_temp_option')));
        await tester.pumpAndSettle();

        // Enter street + zip only (no unit, no city, no state)
        await tester.enterText(find.byKey(const Key('checkout_temp_street_field')), '450 Colorado St');
        await tester.enterText(find.byKey(const Key('checkout_temp_zip_field')), '78701');
        await tester.pumpAndSettle();

        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;

        expect(booking.clientAddress, equals('450 Colorado St, 78701'));
        expect(booking.clientAddress.contains(',,'), isFalse);
        expect(booking.clientAddress.endsWith(','), isFalse);
        expect(booking.clientAddress.contains('null'), isFalse);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2.3 Extreme gate codes (500+ chars, emojis, newlines, special symbols) preserved completely without truncation', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final bufferRepeat = 'Repeating buffer block to push code past five hundred characters limit safely. ' * 5;
      final extremeGateCode = '''
*#1234# - Call box broken! 🚨🚪
Dial 9901 on the intercom, then wait 3 tones 🔔.
If no answer, page security officer at gate #4 (ext: 8821).
🚗 Vehicle clearance: 7ft 2in. Park only in visitor stall #42-B.
Special characters test: <>&"'%#@*!^~{}[]|\\/?+=:;
$bufferRepeat🏁🔚''';

      expect(extremeGateCode.length, greaterThan(500), reason: 'Stress harness requires gate code > 500 characters');

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Enter extreme gate code
        final gateField = find.byKey(const Key('checkout_gate_code_notes_field'));
        expect(gateField, findsOneWidget);
        await tester.enterText(gateField, extremeGateCode);
        await tester.pumpAndSettle();

        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;

        // Verify entire extreme gate code was preserved in model
        expect(booking.clientUnitOrGateCode, isNotNull);
        expect(booking.clientUnitOrGateCode, equals(extremeGateCode.trim()));
        expect(booking.clientUnitOrGateCode!.length, greaterThanOrEqualTo(500));
        expect(booking.clientUnitOrGateCode, contains('🚨🚪'));
        expect(booking.clientUnitOrGateCode, contains('*#1234#'));
        expect(booking.clientUnitOrGateCode, contains('\n'));

        // Verify JSON round-trip serialization preserves extreme text
        final json = booking.toJson();
        final restoredFromJson = BookingAppointment.fromJson(json);
        expect(restoredFromJson.clientUnitOrGateCode, equals(extremeGateCode.trim()));

        // Verify Supabase payload round-trip serialization preserves extreme text
        final supaPayload = booking.toSupabase();
        final restoredFromSupa = BookingAppointment.fromJson(supaPayload);
        expect(restoredFromSupa.clientUnitOrGateCode, equals(extremeGateCode.trim()));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });

  // =========================================================================
  // GROUP 3: RESPONSIVE & VIEWPORT STRESS (390px MOBILE VIEWPORT)
  // =========================================================================
  group('Challenger Vector 3: Responsive & Viewport Stress (390px Mobile Viewport)', () {
    testWidgets('3.1 Mobile viewport (390x844) location card has RenderFlex overflows on options titles', (tester) async {
      // Standard iPhone 12/13/14 physical screen dimension
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtErrors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      const verboseClient = UserProfile(
        id: 'usr_client_long_addr',
        username: 'client_verbose@example.com',
        displayName: 'Alexander Montgomery-Vanderbilt Jr.',
        phone: '(512) 555-0199',
        streetAddress: '12345 Very Long Residential Boulevard Apt 9999-B, North Annex Building',
        unitOrApt: 'Building 14, Penthouse Suite 8802',
        city: 'Metropolitan Municipality of Greater Austin',
        state: 'Texas - Lone Star State',
        postalCode: '78704-9999',
        latitude: 30.2505,
        longitude: -97.7495,
        myGarage: [
          UserVehicle(
            id: 'veh_01',
            make: 'Porsche',
            model: '911 GT3 RS Clubsport',
            year: 2024,
            colorName: 'Shark Blue Metallic',
            imageUrl: '',
            vehicleType: 'Coupe',
          ),
        ],
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: verboseClient,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Advance to Step 2 (Review)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Location card is rendered
        final locationCard = find.byKey(const Key('checkout_service_location_card'));
        expect(locationCard, findsOneWidget);

        // Switch to Temporary Location
        await tester.tap(find.byKey(const Key('checkout_location_temp_option')));
        await tester.pumpAndSettle();

        // Fill all fields with long verbose text
        await tester.enterText(
          find.byKey(const Key('checkout_temp_street_field')),
          '98765 Extremely Long Commercial Parkway Boulevard Suite 400',
        );
        await tester.enterText(
          find.byKey(const Key('checkout_temp_unit_field')),
          'Building 7B, Floor 3, Suite 305-Annex',
        );
        await tester.enterText(
          find.byKey(const Key('checkout_temp_city_field')),
          'Metropolitan District of Austin',
        );
        await tester.enterText(
          find.byKey(const Key('checkout_temp_state_field')),
          'TX - Lone Star State',
        );
        await tester.enterText(
          find.byKey(const Key('checkout_temp_zip_field')),
          '78701-9999',
        );
        await tester.enterText(
          find.byKey(const Key('checkout_gate_code_notes_field')),
          'Gate #9910, dial *4920 on keypad, guard at gate 2 will open barrier arm after checking reservation ID',
        );
        await tester.pumpAndSettle();

        // Scroll up and down inside the SingleChildScrollView to stress layout passes
        final scrollable = find.byType(SingleChildScrollView);
        expect(scrollable, findsOneWidget);

        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
        await tester.drag(scrollable, const Offset(0, 300));
        await tester.pumpAndSettle();

        // Isolate RenderFlex overflows originating from checkout_service_location_card
        final cardOverflows = caughtErrors.where((e) {
          final str = e.exceptionAsString();
          final info = e.informationCollector?.call().map((d) => d.toString()).join('\n') ?? '';
          return str.contains('RenderFlex overflowed') &&
                 (info.contains('booking_flow_screen.dart:2417') ||
                  info.contains('booking_flow_screen.dart:2468') ||
                  info.contains('checkout_location_home_option') ||
                  info.contains('checkout_location_temp_option'));
        }).toList();

        // Restore original onError before assertions
        FlutterError.onError = originalOnError;

        // Empirical check: Verify whether checkout_service_location_card has zero overflows
        expect(
          cardOverflows,
          isEmpty,
          reason: 'DEFECT FOUND: checkout_service_location_card has RenderFlex overflows on 390px mobile viewport '
                  'at lines 2417 (checkout_location_home_option: overflowed by 106px) and 2468 (checkout_location_temp_option: overflowed by 105px) '
                  'due to unconstrained Row text.',
        );
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3.2 Drop-off Studio card at 390x844 viewport renders without overflow in location card', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtErrors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Select Shop Drop-off
        await tester.tap(find.text('Drop-off at Shop'));
        await tester.pumpAndSettle();

        // Advance to Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('checkout_service_location_card')), findsOneWidget);
        expect(find.byKey(const Key('booking_studio_directions_btn')), findsOneWidget);

        // Verify zero overflow in drop-off studio card
        final shopCardOverflows = caughtErrors.where((e) {
          final str = e.exceptionAsString();
          final info = e.informationCollector?.call().map((d) => d.toString()).join('\n') ?? '';
          return str.contains('RenderFlex overflowed') &&
                 (info.contains('booking_studio_directions_btn') ||
                  info.contains('booking_flow_screen.dart:2364'));
        }).toList();

        FlutterError.onError = originalOnError;

        expect(shopCardOverflows, isEmpty, reason: 'Drop-off studio location card must not have RenderFlex overflows');
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });

  // =========================================================================
  // GROUP 4: DETAILER WORKBENCH & CLIENT BOOKINGS UI
  // =========================================================================
  group('Challenger Vector 4: Detailer Workbench & Client Bookings UI', () {
    testWidgets('4.1 DetailerWorkbenchView renders extreme gate code without overflow and launches navigation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final launchedUrls = <String>[];
      MapLauncherService.setMockLauncher((url) async {
        launchedUrls.add(url);
        return true;
      });

      const extremeGateCode = '*#9988# Dial 4001; Gate box buzzer broken; Park in bay 12 🚨';

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testStudioDetailer.copyWith(role: UserRole.detailer),
        );

        final testDate = DateTime.now();
        final booking = BookingAppointment(
          id: 'bk_challenger_detailer_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Alexander Client',
          clientPhone: '555-0199',
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3',
          vehicleSize: VehicleSize.coupeSedan,
          package: testStudioDetailer.servicePackages.first,
          locationType: ServiceLocationType.mobile,
          clientAddress: '1200 S Congress Ave, Austin, TX 78704',
          clientUnitOrGateCode: extremeGateCode,
          latitude: 30.2505,
          longitude: -97.7495,
          scheduledDate: testDate,
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 350.0,
          depositAmount: 70.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(booking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Key('detailer_booking_gate_code') is mounted
        final gateCodeFinder = find.byKey(const Key('detailer_booking_gate_code'));
        expect(gateCodeFinder, findsOneWidget);
        expect(find.textContaining('*#9988#'), findsOneWidget);

        // Verify zero RenderFlex overflows
        expect(tester.takeException(), isNull);

        // Tap Navigate button
        final navigateBtnFinder = find.byKey(const Key('detailer_booking_navigate_btn'));
        expect(navigateBtnFinder, findsOneWidget);
        await tester.tap(navigateBtnFinder);
        await tester.pumpAndSettle();

        // Verify MapLauncherService received valid coordinate destination
        expect(launchedUrls, isNotEmpty);
        expect(launchedUrls.first, contains('30.2505'));
        expect(launchedUrls.first, contains('-97.7495'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('4.2 DetailerWorkbenchView on mobile viewport (390x844) renders gate code and navigate button without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final launchedUrls = <String>[];
      MapLauncherService.setMockLauncher((url) async {
        launchedUrls.add(url);
        return true;
      });

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testStudioDetailer.copyWith(role: UserRole.detailer),
        );

        final testDate = DateTime.now();
        final booking = BookingAppointment(
          id: 'bk_challenger_detailer_mobile_02',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Alexander Client',
          clientPhone: '555-0199',
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3',
          vehicleSize: VehicleSize.coupeSedan,
          package: testStudioDetailer.servicePackages.first,
          locationType: ServiceLocationType.mobile,
          clientAddress: '1200 S Congress Ave, Austin, TX 78704',
          clientUnitOrGateCode: 'Gate #402, code *9912 - Please call upon arrival',
          latitude: null, // Address-only navigation fallback test
          longitude: null,
          scheduledDate: testDate,
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 350.0,
          depositAmount: 70.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(booking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate mobile 3-step workbench: Step 0 (Hub) -> Step 1 (List) -> Step 2 (Inspector)
        await tester.tap(find.text('Booked'));
        await tester.pumpAndSettle();

        final bookingCard = find.text('Alexander Client');
        expect(bookingCard, findsOneWidget);
        await tester.tap(bookingCard);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('detailer_booking_gate_code')), findsOneWidget);
        expect(tester.takeException(), isNull);

        final navBtn = find.byKey(const Key('detailer_booking_navigate_btn'));
        expect(navBtn, findsOneWidget);
        await tester.tap(navBtn);
        await tester.pumpAndSettle();

        // Verify address navigation fallback
        expect(launchedUrls, isNotEmpty);
        expect(launchedUrls.first, contains('1200%20S%20Congress%20Ave'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('4.3 BookingsListScreen displays gate code and triggers client_booking_navigate_btn', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final launchedUrls = <String>[];
      MapLauncherService.setMockLauncher((url) async {
        launchedUrls.add(url);
        return true;
      });

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        final dropOffBooking = BookingAppointment(
          id: 'bk_dropoff_challenger_01',
          clientId: repo.currentUser.id,
          detailerId: testStudioDetailer.id,
          detailerName: testStudioDetailer.displayName,
          detailerBusinessName: testStudioDetailer.businessName,
          detailerAvatar: '',
          clientName: repo.currentUser.displayName,
          clientPhone: repo.currentUser.phone,
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3',
          vehicleSize: VehicleSize.coupeSedan,
          package: testStudioDetailer.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '500 E 4th St, Bay 2B, Austin, TX 78701',
          clientUnitOrGateCode: 'Drop-off Bay 2B',
          latitude: 30.2655,
          longitude: -97.7398,
          scheduledDate: DateTime.now().add(const Duration(days: 2)),
          scheduledTimeSlot: '10:00 AM - 2:00 PM',
          totalPrice: 350.0,
          depositAmount: 70.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(dropOffBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the booking card to open details modal
        await tester.tap(find.text(testStudioDetailer.servicePackages.first.title));
        await tester.pumpAndSettle();

        // Modal should display gate code
        expect(find.textContaining('Drop-off Bay 2B'), findsOneWidget);

        // Tap Directions / Map button with key
        final navBtn = find.byKey(const Key('client_booking_navigate_btn'));
        expect(navBtn, findsOneWidget);
        await tester.tap(navBtn);
        await tester.pumpAndSettle();

        expect(launchedUrls, isNotEmpty);
        expect(launchedUrls.first, contains('30.2655'));
        expect(launchedUrls.first, contains('-97.7398'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
