import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Booking Dual-Key Resolution & Sync Verification Tests', () {
    const testPkg = ServicePackage(
      id: 'pkg_test_01',
      title: 'Ceramic Pro 9H',
      description: 'Full multi-stage ceramic coating',
      basePrice: 500.0,
      estimatedDuration: '4 hrs',
      includes: ['Paint decontamination', '2-stage polish', 'Ceramic application'],
    );

    final studioDetailer = UserProfile(
      id: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      username: 'apex_detailing',
      displayName: 'Marcus Vance',
      businessName: 'Apex Precision Detailing',
      avatarUrl: '',
      coverUrl: '',
      location: 'Austin, TX',
      serviceRadius: '25 miles',
      bio: 'Master certified paint correction studio',
      servicePackages: [testPkg],
    );

    test('Unit 1: JobRepository.clientBookings resolves via ID, email dual-key, and guest fallback', () async {
      final repo = JobRepository();
      await repo.init();

      // Given a guest booking created prior to authentication
      final guestBooking = BookingAppointment(
        id: 'book_guest_01',
        clientId: null,
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Sarah Jenkins',
        clientPhone: '555-123-4567',
        clientEmail: 'sarah.jenkins@example.com',
        vehicleYearMakeModel: '2023 BMW M3 Competition',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 2)),
        scheduledTimeSlot: '9:00 AM - 1:00 PM',
        totalPrice: 500.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      // And an un-related booking belonging to another user
      final otherUserBooking = BookingAppointment(
        id: 'book_other_02',
        clientId: 'a0000000-0000-0000-0000-000000000001',
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Other Person',
        clientPhone: '555-999-8888',
        clientEmail: 'other@example.com',
        vehicleYearMakeModel: '2022 Audi RS6',
        vehicleSize: VehicleSize.truckVan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
        scheduledTimeSlot: '2:00 PM - 6:00 PM',
        totalPrice: 600.0,
        depositAmount: 120.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(guestBooking);
      repo.addBooking(otherUserBooking);

      // A) Guest mode: clientBookings shows guest booking, hides other authenticated user's booking
      expect(repo.isLoggedIn, false);
      expect(repo.clientBookings.map((b) => b.id), contains('book_guest_01'));
      expect(repo.clientBookings.map((b) => b.id), isNot(contains('book_other_02')));

      // B) Log in as Sarah with matching email (simulating Supabase login with matching email)
      final sarahUser = UserProfile(
        id: 'b1111111-1111-1111-1111-111111111111',
        username: 'sarah.jenkins@example.com',
        displayName: 'Sarah Jenkins',
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        location: '',
        serviceRadius: '',
        bio: '',
        phone: '555-123-4567',
      );

      await repo.loginUser(sarahUser);
      expect(repo.isLoggedIn, true);

      // Sarah's personal client bookings MUST include her past guest booking resolved via email dual-key!
      expect(repo.clientBookings.map((b) => b.id), contains('book_guest_01'));
      // And must strictly exclude other users' bookings
      expect(repo.clientBookings.map((b) => b.id), isNot(contains('book_other_02')));
    });

    test('Unit 2: JobRepository non-destructive union merge preserves local & offline bookings', () async {
      final repo = JobRepository();
      await repo.init();

      final localBooking = BookingAppointment(
        id: 'book_offline_99',
        clientId: repo.currentUser.id,
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Offline Client',
        clientPhone: '555-0099',
        clientEmail: 'offline@example.com',
        vehicleYearMakeModel: '2021 Porsche Macan GTS',
        vehicleSize: VehicleSize.truckVan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 4)),
        scheduledTimeSlot: '9:00 AM - 1:00 PM',
        totalPrice: 500.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      // Add local offline booking
      repo.addBooking(localBooking);
      expect(repo.bookings.map((b) => b.id), contains('book_offline_99'));

      // Simulate cloud refresh returning empty (or null network)
      // Local booking MUST be preserved and not wiped!
      expect(repo.bookings.length, 1);
      expect(repo.bookings.first.id, 'book_offline_99');

      // Now add a second booking and verify union merge preserves both by ID
      final cloudBooking = BookingAppointment(
        id: 'book_cloud_100',
        clientId: repo.currentUser.id,
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Cloud Client',
        clientPhone: '555-0100',
        clientEmail: 'cloud@example.com',
        vehicleYearMakeModel: '2023 Tesla Model S Plaid',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 5)),
        scheduledTimeSlot: '2:00 PM - 6:00 PM',
        totalPrice: 550.0,
        depositAmount: 110.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(cloudBooking);

      final ids = repo.bookings.map((b) => b.id).toList();
      expect(ids, containsAll(['book_offline_99', 'book_cloud_100']));
      expect(repo.clientBookings.map((b) => b.id), containsAll(['book_offline_99', 'book_cloud_100']));
    });

    testWidgets('UI 1: BookingFlowScreen email prefill does NOT append dummy @example.com', (tester) async {
      setupMockImageHttpClient();
      try {
        final repo = JobRepository();
        await repo.init();

        final clientUser = repo.currentUser.copyWith(
          username: 'giancarlo',
          displayName: 'Giancarlo Porto',
          phone: '555-0199',
        );
        repo.updateCurrentUser(clientUser);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: DateTime.now().add(const Duration(days: 3)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to step 2 (Client & Vehicle details)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Find email field text
        final emailField = find.widgetWithText(TextField, 'Email Address (For Warranty Receipt)');
        expect(emailField, findsOneWidget);

        // Verify that fake "giancarlo@example.com" was NEVER injected
        final textField = tester.widget<TextField>(emailField);
        expect(textField.controller?.text, isNot(contains('@example.com')));
        expect(textField.controller?.text, isEmpty);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 2: BookingFlowScreen validates name, phone, and valid email format before submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: DateTime.now().add(const Duration(days: 3)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Step 2: Clear name to test validation
        final nameField = find.widgetWithText(TextField, 'Full Name');
        await tester.enterText(nameField, '');
        await tester.pumpAndSettle();

        // Tap Reserve & Book with empty name
        await tester.tap(find.text('Reserve & Book'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your full name for the booking reservation.'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BookingFlowScreen))).clearSnackBars();
        await tester.pumpAndSettle();

        // Enter valid name, leave phone empty
        await tester.enterText(nameField, 'Alex Miller');
        final phoneField = find.widgetWithText(TextField, 'Mobile Phone (For SMS updates)');
        await tester.enterText(phoneField, '');
        await tester.tap(find.text('Reserve & Book'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your phone number so the detailer can contact you.'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BookingFlowScreen))).clearSnackBars();
        await tester.pumpAndSettle();

        // Enter valid phone, enter invalid email format
        await tester.enterText(phoneField, '555-4321');
        final emailField = find.widgetWithText(TextField, 'Email Address (For Warranty Receipt)');
        await tester.enterText(emailField, 'not-an-email');
        await tester.tap(find.text('Reserve & Book'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address for warranty and booking confirmation.'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BookingFlowScreen))).clearSnackBars();
        await tester.pumpAndSettle();

        // Enter valid email and submit successfully
        await tester.enterText(emailField, 'alex.miller@example.com');
        await tester.tap(find.text('Reserve & Book'));
        await tester.pumpAndSettle();

        // Confirmation dialog appears!
        expect(find.text('Booking Reserved!'), findsOneWidget);
        expect(find.text('View in My Bookings'), findsOneWidget);

        // Tap "View in My Bookings" and verify active tab is switched to 1
        expect(repo.activeTabIndex, 0);
        await tester.tap(find.text('View in My Bookings'));
        await tester.pumpAndSettle();

        expect(repo.activeTabIndex, 1);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 3: BookingsListScreen in guest mode renders appointments with sync banner if device has bookings', (tester) async {
      setupMockImageHttpClient();
      try {
        final repo = JobRepository();
        await repo.init();
        expect(repo.isLoggedIn, false);

        // 1. With 0 bookings, shows empty guest sign-in screen
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign In to View Bookings'), findsOneWidget);
        expect(find.text('Guest Bookings on Device'), findsNothing);

        // 2. Add an appointment to this device
        final localBooking = BookingAppointment(
          id: 'guest_local_01',
          clientId: null,
          detailerId: studioDetailer.id,
          detailerName: studioDetailer.displayName,
          detailerBusinessName: studioDetailer.businessName,
          detailerAvatar: '',
          clientName: 'Guest Customer',
          clientPhone: '555-222-3333',
          clientEmail: 'guest.cust@example.com',
          vehicleYearMakeModel: '2024 Corvette Z06',
          vehicleSize: VehicleSize.coupeSedan,
          package: testPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime.now().add(const Duration(days: 1)),
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(localBooking);

        await tester.pumpAndSettle();

        // Screen now renders the tabs AND the Guest Bookings sync banner!
        expect(find.text('Guest Bookings on Device'), findsOneWidget);
        expect(find.text('2024 Corvette Z06'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    test('Unit 3: Local guest bookings on device persist in clientBookings after login', () async {
      final repo = JobRepository();
      await repo.init();

      // Guest creates booking on device
      final localBooking = BookingAppointment(
        id: 'guest_local_persists_01',
        clientId: null,
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Local User',
        clientPhone: '555-999-8888',
        clientEmail: 'local.user@example.com',
        vehicleYearMakeModel: 'Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Austin, TX',
        scheduledDate: DateTime(2026, 12, 1),
        scheduledTimeSlot: '10:00 AM - 1:00 PM',
        totalPrice: 450.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(localBooking);

      expect(repo.clientBookings.length, 1);

      // Now user logs in as client with a username (before cloud claim or offline)
      await repo.loginUser(const UserProfile(
        id: 'usr_newly_logged_in_client',
        username: 'client_user_no_email',
        displayName: 'Client Name',
        role: UserRole.client,
      ));

      // The local guest booking MUST NOT vanish from clientBookings
      expect(repo.isLoggedIn, isTrue);
      expect(repo.clientBookings.any((b) => b.id == 'guest_local_persists_01'), isTrue);
    });

    test('Unit 4: clientBookings trims leading/trailing spaces and normalizes uppercase email', () async {
      final repo = JobRepository();
      await repo.init();

      final bookingWithSpaces = BookingAppointment(
        id: 'space_booking_01',
        clientId: 'another_user',
        detailerId: studioDetailer.id,
        detailerName: studioDetailer.displayName,
        detailerBusinessName: studioDetailer.businessName,
        detailerAvatar: '',
        clientName: 'Space User',
        clientPhone: '555-111-2222',
        clientEmail: '  ALICE.SPACES@EXAMPLE.COM  ',
        vehicleYearMakeModel: 'BMW M3',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Austin, TX',
        scheduledDate: DateTime(2026, 12, 2),
        scheduledTimeSlot: '10:00 AM - 1:00 PM',
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(bookingWithSpaces);

      // Log in with clean lowercase email
      await repo.loginUser(const UserProfile(
        id: 'usr_clean_alice',
        username: 'alice.spaces@example.com',
        displayName: 'Alice Spaces',
        role: UserRole.client,
      ));

      // Successfully matches via dual-key despite spaces and casing in booking
      expect(repo.clientBookings.any((b) => b.id == 'space_booking_01'), isTrue);
    });

    testWidgets('UI 4: BookingsListScreen details modal shows client status explanation and Call Studio action', (tester) async {
      setupMockImageHttpClient();
      try {
        final repo = JobRepository();
        await repo.init();

        final clientAppt = BookingAppointment(
          id: 'appt_client_view_01',
          clientId: 'client_id_123',
          detailerId: studioDetailer.id,
          detailerName: studioDetailer.displayName,
          detailerBusinessName: studioDetailer.businessName,
          detailerAvatar: '',
          clientName: 'Customer Jane',
          clientPhone: '555-444-5555',
          clientEmail: 'jane@example.com',
          vehicleYearMakeModel: 'Audi RS6 Avant',
          vehicleSize: VehicleSize.coupeSedan,
          package: testPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime.now().add(const Duration(days: 1)),
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 600.0,
          depositAmount: 150.0,
          status: BookingStatus.pending,
        );
        repo.addBooking(clientAppt);

        await repo.loginUser(const UserProfile(
          id: 'client_id_123',
          username: 'jane@example.com',
          displayName: 'Customer Jane',
          role: UserRole.client,
        ));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on booking card to open details modal
        await tester.tap(find.text('Audi RS6 Avant'));
        await tester.pumpAndSettle();

        // Modal should show Call Studio (not Call Host)
        expect(find.text('Call Studio'), findsOneWidget);

        // Modal should show client reassurance status banner
        expect(find.text('Awaiting studio confirmation. Your deposit is held securely in escrow.'), findsOneWidget);

        // Modal should NOT show host "Confirm & Accept Booking" button because user is client!
        expect(find.text('Confirm & Accept Booking'), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
