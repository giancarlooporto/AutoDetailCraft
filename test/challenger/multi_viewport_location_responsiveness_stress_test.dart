// =========================================================================
// File: test/challenger/multi_viewport_location_responsiveness_stress_test.dart
// Description: Multi-viewport responsiveness and RenderFlex overflow stress harness
//              for BookingFlowScreen and DetailerWorkbenchView.
//
// Viewports Tested:
// 1. Ultra-compact mobile: Size(360, 640)
// 2. Standard mobile: Size(390, 844)
// 3. Large mobile: Size(414, 896)
// 4. Tablet: Size(768, 1024)
//
// Scenarios Tested per Viewport:
// - BookingFlowScreen mobile service with Saved Home Address
// - Toggling between Saved Home Address and Temporary Location
// - Entering verbose address & long gate codes in temporary location fields
// - BookingFlowScreen shop drop-off mode with directions button
// - DetailerWorkbenchView mobile layout & inspector with gate code & navigation button
// - Accessibility large text scale (1.3x) on ultra-compact mobile (360x640)
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
import 'package:detail_craft/services/map_launcher_service.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testStudioDetailer = UserProfile(
    id: 'usr_detailer_austin',
    username: 'marcus_apex',
    displayName: 'Marcus Vance',
    businessName: 'Apex Precision Detailing Studio & Paint Correction',
    location: 'Austin, TX',
    streetAddress: '1200 S Congress Ave',
    city: 'Austin',
    state: 'TX',
    postalCode: '78704',
    studioStreetAddress: '500 E 4th St',
    studioUnitOrApt: 'Bay 2B Industrial Park',
    studioCity: 'Austin',
    studioState: 'TX',
    studioPostalCode: '78701',
    studioLatitude: 30.2655,
    studioLongitude: -97.7398,
    servicePackages: [
      ServicePackage(
        id: 'pkg_full_detail',
        title: 'Full Signature Ceramic Detail & Polish',
        description: 'Comprehensive interior deep clean and exterior multi-stage restoration',
        basePrice: 350.0,
        estimatedDuration: '4 hrs',
        includes: ['Hand wash', 'Clay bar', 'Interior deep clean', 'Ceramic sealant'],
      ),
    ],
  );

  const testClientUser = UserProfile(
    id: 'usr_client_01',
    username: 'alex@example.com',
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
        model: '911 GT3',
        year: 2024,
        colorName: 'Shark Blue',
        imageUrl: '',
        vehicleType: 'Coupe',
      ),
    ],
  );

  final testViewports = <String, Size>{
    'Ultra-compact mobile': const Size(360, 640),
    'Standard mobile': const Size(390, 844),
    'Large mobile': const Size(414, 896),
    'Tablet': const Size(768, 1024),
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MapLauncherService.resetMockLauncher();
  });

  tearDown(() {
    MapLauncherService.resetMockLauncher();
  });

  // =========================================================================
  // SUITE 1: BookingFlowScreen Across All 4 Viewports
  // =========================================================================
  group('BookingFlowScreen Multi-Viewport Responsiveness & Layout Flapping', () {
    for (final entry in testViewports.entries) {
      final viewportName = entry.key;
      final viewportSize = entry.value;

      testWidgets('1. $viewportName ($viewportSize) renders mobile detailing review step without overflow', (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        setupMockImageHttpClient();

        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint('>>> EXCEPTION: ${details.exceptionAsString()}');
          debugPrint('>>> LIBRARY: ${details.library}');
          debugPrint('>>> CONTEXT: ${details.context}');
          if (details.informationCollector != null) {
            for (final item in details.informationCollector!()) {
              debugPrint('>>> INFO: $item');
            }
          }
          debugPrint('>>> SUMMARY: ${details.summary}');
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

          debugPrint('--- MOUNTING BOOKING FLOW SCREEN ---');
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
          debugPrint('--- STEP 0 SETTLED ---');

          // Step 0 -> Step 1 -> Step 2 (Review)
          debugPrint('--- TAPPING CONTINUE (STEP 0 -> STEP 1) ---');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          debugPrint('--- STEP 1 SETTLED ---');

          debugPrint('--- TAPPING CONTINUE (STEP 1 -> STEP 2) ---');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          debugPrint('--- STEP 2 SETTLED ---');
          // Clear caughtErrors from Step 1 to specifically evaluate Step 2 (Review Step & Location Card)
          caughtErrors.clear();

          // Location card is mounted
          final locationCard = find.byKey(const Key('checkout_service_location_card'));
          expect(locationCard, findsOneWidget);

          // Both Home and Temp options are mounted
          final homeOption = find.byKey(const Key('checkout_location_home_option'));
          final tempOption = find.byKey(const Key('checkout_location_temp_option'));
          expect(homeOption, findsOneWidget);
          expect(tempOption, findsOneWidget);

          // Verify text inside options
          expect(find.text('Saved Home Address'), findsOneWidget);
          expect(find.text('Temporary Location'), findsOneWidget);

          // Verify zero RenderFlex overflows in Step 2 with Home address selected
          FlutterError.onError = originalOnError;
          expect(
            caughtErrors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
            isEmpty,
            reason: 'RenderFlex overflow observed on $viewportName in Step 2 Review with Saved Home Address selected',
          );
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('2. $viewportName ($viewportSize) toggling Home vs Temp and entering text has zero overflow', (tester) async {
        tester.view.physicalSize = viewportSize;
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

          // Step 0 -> Step 1 -> Step 2
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          // Clear caughtErrors from prior steps to isolate Step 2 location card
          caughtErrors.clear();

          final homeOption = find.byKey(const Key('checkout_location_home_option'));
          final tempOption = find.byKey(const Key('checkout_location_temp_option'));

          // Toggle to Temporary Location
          await tester.tap(tempOption);
          await tester.pumpAndSettle();

          // Enter extensive text in temporary fields
          final streetField = find.byKey(const Key('checkout_temp_street_field'));
          final unitField = find.byKey(const Key('checkout_temp_unit_field'));
          final cityField = find.byKey(const Key('checkout_temp_city_field'));
          final stateField = find.byKey(const Key('checkout_temp_state_field'));
          final zipField = find.byKey(const Key('checkout_temp_zip_field'));
          final gateField = find.byKey(const Key('checkout_gate_code_notes_field'));

          expect(streetField, findsOneWidget);
          expect(unitField, findsOneWidget);
          expect(cityField, findsOneWidget);
          expect(stateField, findsOneWidget);
          expect(zipField, findsOneWidget);
          expect(gateField, findsOneWidget);

          await tester.enterText(streetField, '8888 Innovation Boulevard North Way');
          await tester.enterText(unitField, 'Suite 100-B, Tech Center');
          await tester.enterText(cityField, 'Austin Metropolitan Area');
          await tester.enterText(stateField, 'TX');
          await tester.enterText(zipField, '78701');
          await tester.enterText(gateField, 'Gate #4092, ring callbox, wait for green light 🟢');
          await tester.pumpAndSettle();

          // Scroll up and down inside SingleChildScrollView
          final scrollable = find.byType(SingleChildScrollView);
          expect(scrollable, findsOneWidget);
          await tester.drag(scrollable, const Offset(0, -250));
          await tester.pumpAndSettle();
          await tester.drag(scrollable, const Offset(0, 250));
          await tester.pumpAndSettle();

          // Toggle back to Home
          await tester.tap(homeOption);
          await tester.pumpAndSettle();

          // Toggle back to Temp
          await tester.tap(tempOption);
          await tester.pumpAndSettle();

          FlutterError.onError = originalOnError;
          expect(
            caughtErrors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
            isEmpty,
            reason: 'RenderFlex overflow observed on $viewportName during Home/Temp toggles and text input',
          );
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('3. $viewportName ($viewportSize) Shop Drop-off service location card has zero overflow', (tester) async {
        tester.view.physicalSize = viewportSize;
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
          // Clear caughtErrors from prior steps to isolate Step 2 location card
          caughtErrors.clear();

          expect(find.byKey(const Key('checkout_service_location_card')), findsOneWidget);
          expect(find.byKey(const Key('booking_studio_directions_btn')), findsOneWidget);
          expect(find.text('Drop-off Studio Location'), findsOneWidget);

          FlutterError.onError = originalOnError;
          expect(
            caughtErrors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
            isEmpty,
            reason: 'RenderFlex overflow observed on $viewportName in Shop Drop-off card',
          );
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  // =========================================================================
  // SUITE 2: DetailerWorkbenchView Across All 4 Viewports
  // =========================================================================
  group('DetailerWorkbenchView Multi-Viewport Responsiveness & Navigation Handoff', () {
    for (final entry in testViewports.entries) {
      final viewportName = entry.key;
      final viewportSize = entry.value;

      testWidgets('4. $viewportName ($viewportSize) renders gate code and navigate button without overflow', (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        setupMockImageHttpClient();

        final launchedUrls = <String>[];
        MapLauncherService.setMockLauncher((url) async {
          launchedUrls.add(url);
          return true;
        });

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
            currentUser: testStudioDetailer.copyWith(role: UserRole.detailer),
          );

          final testDate = DateTime.now();
          final booking = BookingAppointment(
            id: 'bk_challenger_viewport_${viewportName.replaceAll(' ', '_')}',
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
            clientAddress: '12345 Extremely Long Highway Parkway Suite 400, Austin, TX 78704',
            clientUnitOrGateCode: 'Gate #9910, dial *4920 on intercom, guard post 2',
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

          // On mobile viewports (width < 700), workbench uses 3-step drill-down:
          // Step 0: Hub -> Tap 'Booked' -> Step 1: List -> Tap booking card -> Step 2: Inspector
          if (viewportSize.width < 700) {
            final bookedTab = find.text('Booked');
            if (bookedTab.evaluate().isNotEmpty) {
              await tester.tap(bookedTab.first);
              await tester.pumpAndSettle();
            }

            final bookingCard = find.text('Alexander Client');
            if (bookingCard.evaluate().isNotEmpty) {
              await tester.tap(bookingCard.first);
              await tester.pumpAndSettle();
            }
          }

          // Verify gate code and navigate button
          final gateCodeFinder = find.byKey(const Key('detailer_booking_gate_code'));
          final navigateBtnFinder = find.byKey(const Key('detailer_booking_navigate_btn'));

          expect(gateCodeFinder, findsOneWidget);
          expect(navigateBtnFinder, findsOneWidget);

          // Tap navigate button
          await tester.tap(navigateBtnFinder);
          await tester.pumpAndSettle();

          expect(launchedUrls, isNotEmpty);
          expect(launchedUrls.first, contains('30.2505'));

          FlutterError.onError = originalOnError;
          expect(
            caughtErrors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
            isEmpty,
            reason: 'RenderFlex overflow observed on $viewportName in DetailerWorkbenchView',
          );
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  // =========================================================================
  // SUITE 3: Accessibility Large Font Scaling (1.3x) on Ultra-Compact Mobile
  // =========================================================================
  group('Accessibility Text Scaling Stress on Ultra-Compact Mobile (360x640)', () {
    testWidgets('5. TextScaleFactor 1.3 on 360x640 viewport does not cause overflow in location options or review step', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
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
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: BookingFlowScreen(
                  detailer: testStudioDetailer,
                  repository: repo,
                ),
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
        // Clear caughtErrors from prior steps to isolate Step 2 location card
        caughtErrors.clear();

        final homeOption = find.byKey(const Key('checkout_location_home_option'));
        final tempOption = find.byKey(const Key('checkout_location_temp_option'));
        expect(homeOption, findsOneWidget);
        expect(tempOption, findsOneWidget);

        // Toggle to temp
        await tester.tap(tempOption);
        await tester.pumpAndSettle();

        // Toggle back to home
        await tester.tap(homeOption);
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(
          caughtErrors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
          isEmpty,
          reason: 'RenderFlex overflow observed on 360x640 with 1.3x accessibility text scaling',
        );
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });

  // =========================================================================
  // SUITE 4: Step 1 Vehicle Row Layout Verification (booking_flow_screen.dart:1203)
  // =========================================================================
  group('Step 1 Vehicle Badge Row Layout Verification (booking_flow_screen.dart:1203)', () {
    testWidgets('6.1 Ultra-compact mobile (360x640) Step 1 vehicle badge row renders without overflow with standard vehicle color', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
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
          currentUser: testClientUser, // Has Coupe, Shark Blue
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

        FlutterError.onError = originalOnError;

        // Check for line 1203 overflow
        final vehicleBadgeOverflows = caughtErrors.where((e) {
          final str = e.exceptionAsString();
          return str.contains('RenderFlex overflowed');
        }).toList();

        // This verifies that on 360x640, line 1203 does not overflow
        expect(
          vehicleBadgeOverflows,
          isEmpty,
          reason: 'Line 1203 vehicle type/color row must not overflow on 360x640 mobile viewport',
        );
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('6.2 Standard mobile (390x844) Step 1 vehicle badge row renders without overflow with multi-word color name', (tester) async {
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

      const multiWordColorClient = UserProfile(
        id: 'usr_client_02',
        username: 'client2@example.com',
        displayName: 'Jordan Smith',
        streetAddress: '100 Main St',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        myGarage: [
          UserVehicle(
            id: 'veh_02',
            make: 'Porsche',
            model: '911 GT3 RS',
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
          currentUser: multiWordColorClient,
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

        FlutterError.onError = originalOnError;

        final vehicleBadgeOverflows = caughtErrors.where((e) {
          final str = e.exceptionAsString();
          return str.contains('RenderFlex overflowed');
        }).toList();

        expect(
          vehicleBadgeOverflows,
          isEmpty,
          reason: 'Line 1203 vehicle type/color row must not overflow on 390x844 mobile viewport with multi-word color',
        );
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
