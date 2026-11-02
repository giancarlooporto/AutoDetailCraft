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

  group('Milestone M3: Booking Checkout Location Selector & Navigation Handoff', () {
    testWidgets('Case 1: When user has saved home address, review step defaults to pre-selected saved home address', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
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

        // Advance: Step 0 -> Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Ensure Mobile detailing is selected
        expect(find.text('Mobile (Home/Work)'), findsOneWidget);

        // Advance: Step 1 -> Step 2 (Review Step)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Verify Service Location Card is present
        expect(find.text('Service Location'), findsOneWidget);
        // Verify formatted address is displayed
        expect(find.textContaining('1200 S Congress Ave, Apt 304, Austin, TX 78704'), findsOneWidget);
        // Verify Home Address toggle/radio is active by default
        expect(find.text('Saved Home Address'), findsOneWidget);
        expect(find.byKey(const Key('checkout_service_location_card')), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Case 2: Toggling to Temporary Location exposes inputs and updates selected location', (tester) async {
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

        // Tap Temporary Location toggle
        final tempRadio = find.text('Temporary Location');
        expect(tempRadio, findsOneWidget);
        await tester.tap(tempRadio);
        await tester.pumpAndSettle();

        // Enter temporary location fields
        final streetFinder = find.widgetWithText(TextField, 'Street Address');
        expect(streetFinder, findsOneWidget);
        await tester.enterText(streetFinder, '701 Brazos St');

        final cityFinder = find.widgetWithText(TextField, 'City');
        expect(cityFinder, findsOneWidget);
        await tester.enterText(cityFinder, 'Austin');

        final zipFinder = find.widgetWithText(TextField, 'ZIP Code');
        expect(zipFinder, findsOneWidget);
        await tester.enterText(zipFinder, '78701');

        await tester.pumpAndSettle();
        expect(find.text('701 Brazos St'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Case 3: Gate Code / Parking Notes persists into BookingAppointment upon confirmation', (tester) async {
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

        // Enter Gate Code / Parking Notes
        final gateField = find.widgetWithText(TextField, 'Gate Code / Access Instructions (Optional)');
        if (gateField.evaluate().isNotEmpty) {
          await tester.enterText(gateField, 'Gate #4812, code *9912');
        }

        // Tap Reserve & Book / Confirm & Request Booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Verify booking in repository
        expect(repo.bookings, isNotEmpty);
        final created = repo.bookings.last;
        expect(created.clientAddress, contains('1200 S Congress Ave'));
        expect(created.clientUnitOrGateCode, isNotNull);
        expect(created.clientUnitOrGateCode, contains('4812'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Case 4: Drop-off studio detailing displays detailer studio address with instructions', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
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

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Select Drop-off at Shop
        await tester.tap(find.text('Drop-off at Shop'));
        await tester.pumpAndSettle();

        // Advance to Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Verify studio address is displayed
        expect(find.textContaining('500 E 4th St, Bay 2B, Austin, TX 78701'), findsOneWidget);
        // Verify drop-off instructions are rendered
        expect(find.textContaining('Drop off vehicle at detailer studio'), findsOneWidget);
        expect(find.byKey(const Key('booking_studio_directions_btn')), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Case 5: Tapping Navigate button in detailer workbench invokes MapLauncherService', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
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
        final mobileBooking = BookingAppointment(
          id: 'bk_mobile_nav_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Alex Client',
          clientPhone: '555-0199',
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3',
          vehicleSize: VehicleSize.coupeSedan,
          package: testStudioDetailer.servicePackages.first,
          locationType: ServiceLocationType.mobile,
          clientAddress: '1200 S Congress Ave, Austin, TX 78704',
          clientUnitOrGateCode: 'Gate #402',
          latitude: 30.2505,
          longitude: -97.7495,
          scheduledDate: testDate,
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 350.0,
          depositAmount: 70.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(mobileBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialCalendarDate: testDate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Calendar tab
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Tap Navigate button on the appointment card
        final navBtn = find.widgetWithText(OutlinedButton, 'Navigate');
        expect(navBtn, findsOneWidget);
        await tester.tap(navBtn);
        await tester.pumpAndSettle();

        // Verify MapLauncherService received coordinate destination
        expect(launchedUrls, isNotEmpty);
        expect(launchedUrls.first, contains('30.2505'));
        expect(launchedUrls.first, contains('-97.7495'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Case 6: Tapping Navigate to Studio in client bookings invokes MapLauncherService', (tester) async {
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
          id: 'bk_dropoff_nav_01',
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

        // Tap Directions / Map button in modal
        final directionsBtn = find.text('Directions / Map');
        expect(directionsBtn, findsOneWidget);
        await tester.tap(directionsBtn);
        await tester.pumpAndSettle();

        // Verify MapLauncherService was called with studio coordinates
        expect(launchedUrls, isNotEmpty);
        expect(launchedUrls.first, contains('30.2655'));
        expect(launchedUrls.first, contains('-97.7398'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
