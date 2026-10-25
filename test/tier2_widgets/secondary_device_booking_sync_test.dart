import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secondary Device Booking Sync & Role Verification Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('Unit 1: User with service packages is NOT forced into detailer role on login if role is client', () async {
      const clientWithPackages = UserProfile(
        id: 'usr_client_device_b',
        role: UserRole.client,
        username: 'alex_owner',
        displayName: 'Alex Vehicle Owner',
        businessName: '',
        servicePackages: [
          ServicePackage(
            id: 'pkg_custom_test',
            title: 'Express Exterior Wash',
            description: 'Foam wash and dry',
            basePrice: 75.0,
            estimatedDuration: '1.5 hrs',
            includes: ['Wash', 'Dry'],
          ),
        ],
      );

      await repo.loginUser(clientWithPackages);

      expect(repo.currentUser.role, equals(UserRole.client));
      expect(repo.isDetailerWorkbenchMode, isFalse);
      expect(repo.workbenchMode, equals('garage'));

      final savedMode = await LocalStorageService.loadWorkbenchMode();
      expect(savedMode, equals('garage'));
    });

    test('Unit 2: User explicitly registered as studio detailer with businessName enters studio mode', () async {
      const studioDetailer = UserProfile(
        id: 'usr_studio_owner',
        role: UserRole.detailer,
        username: 'pro_detailer',
        displayName: 'Carlos Precision',
        businessName: 'Apex Precision Detailing',
        servicePackages: [
          ServicePackage(
            id: 'pkg_ceramic_9h',
            title: '5-Year Ceramic Coating',
            description: 'Ultra 9H ceramic protection',
            basePrice: 950.0,
            estimatedDuration: '1-2 days',
            includes: ['9H Coating'],
          ),
        ],
      );

      await repo.loginUser(studioDetailer);

      expect(repo.currentUser.role, equals(UserRole.detailer));
      expect(repo.isDetailerWorkbenchMode, isTrue);
      expect(repo.workbenchMode, equals('studio'));

      final savedMode = await LocalStorageService.loadWorkbenchMode();
      expect(savedMode, equals('studio'));
    });

    test('Unit 3: JobRepository.refreshBookings is exposed publicly and completes cleanly', () async {
      final initialCount = repo.bookings.length;

      // Call public refreshBookings method
      await repo.refreshBookings();

      expect(repo.bookings.length, equals(initialCount));
    });

    test('Unit 4: addBookingAsync adds booking and verifies cloud sync without duplicates', () async {
      final testBooking = BookingAppointment(
        id: 'bk_async_sync_test_01',
        clientId: repo.currentUser.id,
        detailerId: '5ecfac74-435a-4c99-bb19-cbda2d0a1d65',
        detailerName: 'Apex Studio',
        detailerBusinessName: 'Apex Detailing Studio',
        detailerAvatar: '',
        clientName: 'Alex Smith',
        clientPhone: '555-0199',
        clientEmail: 'alex@example.com',
        vehicleYearMakeModel: '2024 BMW M3',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_decon',
          title: 'Full Decon',
          description: 'Iron and clay decon',
          basePrice: 200.0,
          estimatedDuration: '3 hrs',
          includes: ['Iron Decon', 'Clay Bar'],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: 'Austin, TX',
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
        scheduledTimeSlot: '10:00 AM - 12:00 PM',
        totalPrice: 200.0,
        depositAmount: 50.0,
      );

      final result = await repo.addBookingAsync(testBooking);
      expect(result, isTrue);
      expect(repo.bookings.any((b) => b.id == 'bk_async_sync_test_01'), isTrue);
      expect(repo.clientBookings.any((b) => b.id == 'bk_async_sync_test_01'), isTrue);

      // Re-adding same booking (idempotency) succeeds cleanly
      final reAdd = await repo.addBookingAsync(testBooking);
      expect(reAdd, isTrue);
      expect(repo.bookings.where((b) => b.id == 'bk_async_sync_test_01').length, equals(1));
    });

    testWidgets('UI 1: BookingsListScreen empty state renders RefreshIndicator and Refresh Bookings action', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repo.isLoggedIn = true; // Logged in but has 0 bookings initially

        await tester.pumpWidget(
          MaterialApp(
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Check empty state is rendered
        expect(find.text('No Upcoming Appointments'), findsOneWidget);

        // Verify Refresh Bookings action button exists
        final refreshBtn = find.widgetWithText(OutlinedButton, 'Refresh Bookings');
        expect(refreshBtn, findsOneWidget);

        // Tap Refresh Bookings
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();

        // Verify RefreshIndicator widget is present
        expect(find.byType(RefreshIndicator), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 2: BookingsListScreen with bookings allows pull-to-refresh', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repo.isLoggedIn = true;
        final testBooking = BookingAppointment(
          id: 'bk_rendered_01',
          clientId: repo.currentUser.id,
          detailerId: '5ecfac74-435a-4c99-bb19-cbda2d0a1d65',
          detailerName: 'Apex Studio',
          detailerBusinessName: 'Apex Detailing Studio',
          detailerAvatar: '',
          clientName: 'Alex Smith',
          clientPhone: '555-0199',
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: '2024 BMW M3',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_decon',
            title: 'Full Decon',
            description: 'Iron and clay decon',
            basePrice: 200.0,
            estimatedDuration: '3 hrs',
            includes: ['Iron Decon', 'Clay Bar'],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: 'Austin, TX',
          scheduledDate: DateTime.now().add(const Duration(days: 3)),
          scheduledTimeSlot: '10:00 AM - 12:00 PM',
          totalPrice: 200.0,
          depositAmount: 50.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(testBooking);

        await tester.pumpWidget(
          MaterialApp(
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Apex Detailing Studio'), findsOneWidget);
        expect(find.text('Full Decon'), findsOneWidget);

        // Verify pull to refresh via RefreshIndicator
        final refreshFinder = find.byType(RefreshIndicator);
        expect(refreshFinder, findsWidgets);

        // Pull down to trigger refresh
        await tester.fling(find.text('Full Decon'), const Offset(0, 300), 1000);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Booking remains visible after refresh
        expect(find.text('Apex Detailing Studio'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
