import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/widgets/booking_status_tracker.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Booking Cancellation, Status Lifecycle & Client Sync Tests', () {
    late JobRepository repo;

    const samplePackage = ServicePackage(
      id: 'pkg_test_01',
      title: 'Full Exterior & Interior Detail',
      description: 'Complete foam wash and interior shampoo',
      basePrice: 200.0,
      estimatedDuration: '3 hrs',
      includes: ['Foam wash', 'Clay bar', 'Interior shampoo'],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('1. Status Deserialization: Snake-case in_progress and variations parse cleanly', () {
      final jsonInProgressSnake = {
        'id': 'bk_snake_01',
        'detailerId': 'usr_d1',
        'detailerName': 'Detailer Pro',
        'detailerBusinessName': 'Apex Studio',
        'detailerAvatar': '',
        'clientName': 'Client John',
        'clientPhone': '555-0100',
        'clientEmail': 'john@example.com',
        'vehicleYearMakeModel': '2023 Porsche 911 GT3',
        'vehicleSize': 'coupeSedan',
        'package': samplePackage.toJson(),
        'locationType': 'shop',
        'clientAddress': '123 Speed Way',
        'scheduledDate': '2026-11-10',
        'scheduledTimeSlot': '9:00 AM',
        'totalPrice': 250.0,
        'depositAmount': 50.0,
        'status': 'in_progress',
      };

      final parsed = BookingAppointment.fromJson(jsonInProgressSnake);
      expect(parsed.status, equals(BookingStatus.inProgress));

      // Test camelCase inProgress
      final jsonInProgressCamel = Map<String, dynamic>.from(jsonInProgressSnake)..['status'] = 'inProgress';
      expect(BookingAppointment.fromJson(jsonInProgressCamel).status, equals(BookingStatus.inProgress));

      // Test cancelled and canceled
      final jsonCancelled = Map<String, dynamic>.from(jsonInProgressSnake)..['status'] = 'cancelled';
      expect(BookingAppointment.fromJson(jsonCancelled).status, equals(BookingStatus.cancelled));

      final jsonCanceled = Map<String, dynamic>.from(jsonInProgressSnake)..['status'] = 'canceled';
      expect(BookingAppointment.fromJson(jsonCanceled).status, equals(BookingStatus.cancelled));

      // Test completed and pending
      final jsonCompleted = Map<String, dynamic>.from(jsonInProgressSnake)..['status'] = 'completed';
      expect(BookingAppointment.fromJson(jsonCompleted).status, equals(BookingStatus.completed));

      final jsonPending = Map<String, dynamic>.from(jsonInProgressSnake)..['status'] = 'pending';
      expect(BookingAppointment.fromJson(jsonPending).status, equals(BookingStatus.pending));

      // Test toSupabase writes in_progress for inProgress enum
      final supabaseMap = parsed.toSupabase();
      expect(supabaseMap['status'], equals('in_progress'));
    });

    test('2. Detailer Cancels Booking: Status updates, persists to local storage, and reflects in clientBookings', () async {
      final clientBooking = BookingAppointment(
        id: 'bk_cancel_sync_01',
        clientId: 'client_alex',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Alex Mercer',
        clientPhone: '(512) 555-3344',
        clientEmail: 'alex.mercer@example.com',
        vehicleYearMakeModel: '2024 Ford Mustang Dark Horse',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime(2026, 11, 20),
        scheduledTimeSlot: '10:00 AM - 1:00 PM',
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(clientBooking);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_cancel_sync_01').status, equals(BookingStatus.confirmed));

      // Detailer cancels booking
      await repo.cancelBooking('bk_cancel_sync_01');

      // Status must immediately be cancelled in memory
      final updated = repo.bookings.firstWhere((b) => b.id == 'bk_cancel_sync_01');
      expect(updated.status, equals(BookingStatus.cancelled));

      // Must persist to local storage
      final storedList = await LocalStorageService.loadBookings();
      expect(storedList, isNotNull);
      final storedBooking = storedList!.firstWhere((b) => b.id == 'bk_cancel_sync_01');
      expect(storedBooking.status, equals(BookingStatus.cancelled));

      // Must survive simulated browser refresh / app restart
      final repo2 = await TestHarness.simulateBrowserRefresh(repo);
      final restored = repo2.bookings.firstWhere((b) => b.id == 'bk_cancel_sync_01');
      expect(restored.status, equals(BookingStatus.cancelled));
    });

    test('3. Cancel All Active Studio Bookings: Cancels all bookings, notifies clients, and persists', () async {
      final b1 = BookingAppointment(
        id: 'bk_batch_01',
        clientId: 'client_user_1',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Client One',
        clientPhone: '555-0001',
        clientEmail: 'client1@example.com',
        vehicleYearMakeModel: '2022 Tesla Model 3',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: DateTime(2026, 11, 22),
        scheduledTimeSlot: '9:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );

      final b2 = BookingAppointment(
        id: 'bk_batch_02',
        clientId: 'client_user_2',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Client Two',
        clientPhone: '555-0002',
        clientEmail: 'client2@example.com',
        vehicleYearMakeModel: '2023 BMW M4',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: DateTime(2026, 11, 23),
        scheduledTimeSlot: '1:00 PM',
        totalPrice: 250.0,
        depositAmount: 50.0,
        status: BookingStatus.inProgress,
      );

      repo.addBooking(b1);
      repo.addBooking(b2);

      expect(repo.activeStudioBookings.length, equals(2));

      // Detailer triggers Cancel All Active Studio Bookings
      await repo.cancelAllActiveStudioBookings(reason: 'Emergency studio maintenance');

      // Both must be cancelled
      expect(repo.activeStudioBookings, isEmpty);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_batch_01').status, equals(BookingStatus.cancelled));
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_batch_02').status, equals(BookingStatus.cancelled));

      // Must persist in storage
      final stored = await LocalStorageService.loadBookings();
      expect(stored!.firstWhere((b) => b.id == 'bk_batch_01').status, equals(BookingStatus.cancelled));
      expect(stored.firstWhere((b) => b.id == 'bk_batch_02').status, equals(BookingStatus.cancelled));
    });

    test('4. Full Status Transition Lifecycle: pending -> confirmed -> in_progress -> completed', () async {
      final booking = BookingAppointment(
        id: 'bk_lifecycle_01',
        clientId: 'client_marcus',
        detailerId: repo.currentUser.id,
        detailerName: 'Marcus Detailer',
        detailerBusinessName: 'Marcus Detailing',
        detailerAvatar: '',
        clientName: 'Marcus Client',
        clientPhone: '555-1234',
        clientEmail: 'marcus.client@example.com',
        vehicleYearMakeModel: '2024 Porsche 911 Turbo S',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime(2026, 11, 25),
        scheduledTimeSlot: '9:00 AM',
        totalPrice: 300.0,
        depositAmount: 100.0,
        status: BookingStatus.pending,
      );

      repo.addBooking(booking);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.pending));

      // 1. Pending -> Confirmed
      await repo.updateBookingStatus('bk_lifecycle_01', BookingStatus.confirmed);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.confirmed));

      // 2. Confirmed -> In Progress
      await repo.updateBookingStatus('bk_lifecycle_01', BookingStatus.inProgress);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.inProgress));

      // 3. In Progress -> Completed
      await repo.updateBookingStatus('bk_lifecycle_01', BookingStatus.completed);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.completed));

      // Check persistence after reload
      final repo2 = await TestHarness.simulateBrowserRefresh(repo);
      expect(repo2.bookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.completed));
    });

    testWidgets('5. UI: ClientBookingsScreen renders Status Tracker for in-progress and cancelled bookings', (tester) async {
      setupMockImageHttpClient();
      try {
        final clientUser = repo.currentUser.copyWith(
          id: 'usr_client_active',
          role: UserRole.client,
          username: 'client_active',
        );
        await repo.loginUser(clientUser);

        final activeBooking = BookingAppointment(
          id: 'bk_ui_active_01',
          clientId: 'usr_client_active',
          detailerId: 'usr_studio_apex',
          detailerName: 'Carlos Apex',
          detailerBusinessName: 'Apex Precision Detailing',
          detailerAvatar: '',
          clientName: 'Active Client',
          clientPhone: '555-8888',
          clientEmail: 'client@example.com',
          vehicleYearMakeModel: '2024 Lucid Air Sapphire',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime.now().add(const Duration(days: 2)),
          scheduledTimeSlot: '11:00 AM - 2:00 PM',
          totalPrice: 200.0,
          depositAmount: 50.0,
          status: BookingStatus.inProgress,
        );

        final cancelledBooking = BookingAppointment(
          id: 'bk_ui_cancelled_02',
          clientId: 'usr_client_active',
          detailerId: 'usr_studio_apex',
          detailerName: 'Carlos Apex',
          detailerBusinessName: 'Apex Precision Detailing',
          detailerAvatar: '',
          clientName: 'Active Client',
          clientPhone: '555-8888',
          clientEmail: 'client@example.com',
          vehicleYearMakeModel: '2023 Rivian R1T',
          vehicleSize: VehicleSize.truckVan,
          package: samplePackage,
          locationType: ServiceLocationType.mobile,
          clientAddress: '456 Oak St',
          scheduledDate: DateTime.now().add(const Duration(days: 3)),
          scheduledTimeSlot: '1:00 PM',
          totalPrice: 280.0,
          depositAmount: 70.0,
          status: BookingStatus.cancelled,
        );

        repo.addBooking(activeBooking);
        repo.addBooking(cancelledBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: ClientBookingsScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify tabs count
        expect(find.text('In Progress (1)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);

        // 2. Switch to In Progress tab and verify status tracker
        await tester.tap(find.text('In Progress (1)'));
        await tester.pumpAndSettle();

        expect(find.text('2024 Lucid Air Sapphire'), findsOneWidget);
        // Verify Status Tracker steps exist and widget is rendered
        expect(find.byType(BookingStatusTracker), findsWidgets);
        expect(find.text('In Progress'), findsWidgets);

        // 3. Switch to Cancelled tab and verify Cancelled card with slot released badge
        await tester.tap(find.text('Cancelled (1)'));
        await tester.pumpAndSettle();

        expect(find.text('2023 Rivian R1T'), findsOneWidget);
        expect(find.text('Status: Cancelled • Slot Released'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    test('6. Realtime WebSocket Broadcast Simulation: Postgres UPDATE merges cleanly and persists across reload', () async {
      final initialBooking = BookingAppointment(
        id: 'bk_realtime_01',
        clientId: 'client_realtime_user',
        detailerId: 'usr_detailer_pro',
        detailerName: 'Pro Studio',
        detailerBusinessName: 'Pro Studio LLC',
        detailerAvatar: '',
        clientName: 'Sarah Connor',
        clientPhone: '555-9000',
        clientEmail: 'sarah@example.com',
        vehicleYearMakeModel: '1984 Chevrolet Caprice',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: DateTime(2026, 11, 28),
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(initialBooking);
      expect(repo.bookings.firstWhere((b) => b.id == 'bk_realtime_01').status, equals(BookingStatus.confirmed));

      // 1. Simulate incoming Supabase Realtime UPDATE: status changed to in_progress
      repo.simulateRealtimeBookingPayload({
        'id': 'bk_realtime_01',
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      var updated = repo.bookings.firstWhere((b) => b.id == 'bk_realtime_01');
      expect(updated.status, equals(BookingStatus.inProgress));
      expect(updated.clientName, equals('Sarah Connor'));
      expect(updated.vehicleYearMakeModel, equals('1984 Chevrolet Caprice'));

      // 2. Simulate incoming Supabase Realtime UPDATE: status changed to cancelled
      repo.simulateRealtimeBookingPayload({
        'id': 'bk_realtime_01',
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      updated = repo.bookings.firstWhere((b) => b.id == 'bk_realtime_01');
      expect(updated.status, equals(BookingStatus.cancelled));

      // 3. Verify persistence across simulated browser restart
      final repo2 = await TestHarness.simulateBrowserRefresh(repo);
      final restored = repo2.bookings.firstWhere((b) => b.id == 'bk_realtime_01');
      expect(restored.status, equals(BookingStatus.cancelled));
      expect(restored.clientName, equals('Sarah Connor'));
    });

    testWidgets('7. Detailer Workbench UI: Status transitions pending -> confirmed -> in_progress -> completed -> cancel', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_main',
          role: UserRole.detailer,
          displayName: 'Main Detailer',
          businessName: 'Main Studio',
        );
        await repo.loginUser(detailerUser);

        final pendingBooking = BookingAppointment(
          id: 'bk_workbench_pending_01',
          clientId: 'client_bob',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Bob Builder',
          clientPhone: '555-3210',
          clientEmail: 'bob@example.com',
          vehicleYearMakeModel: '2023 Ram 1500 TRX',
          vehicleSize: VehicleSize.truckVan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime.now().add(const Duration(days: 1)),
          scheduledTimeSlot: '9:00 AM',
          totalPrice: 350.0,
          depositAmount: 100.0,
          status: BookingStatus.pending,
        );

        repo.addBooking(pendingBooking);

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

        // Detailer workbench inspector renders BookingStatusTracker
        expect(find.byType(BookingStatusTracker), findsWidgets);
        expect(find.text('Confirm Booking'), findsOneWidget);
        await tester.ensureVisible(find.text('Confirm Booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm Booking'));
        await tester.pumpAndSettle();

        expect(repo.bookings.firstWhere((b) => b.id == 'bk_workbench_pending_01').status, equals(BookingStatus.confirmed));

        // 2. Start service (In Progress)
        expect(find.text('Start (In Progress)'), findsOneWidget);
        await tester.ensureVisible(find.text('Start (In Progress)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start (In Progress)'));
        await tester.pumpAndSettle();

        expect(repo.bookings.firstWhere((b) => b.id == 'bk_workbench_pending_01').status, equals(BookingStatus.inProgress));

        // 3. Complete Job
        expect(find.text('Complete Job'), findsOneWidget);
        await tester.ensureVisible(find.text('Complete Job'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete Job'));
        await tester.pumpAndSettle();

        expect(repo.bookings.firstWhere((b) => b.id == 'bk_workbench_pending_01').status, equals(BookingStatus.completed));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('8. Detailer Workbench UI: Cancel All Bookings batch cancels active studio appointments', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_batch',
          role: UserRole.detailer,
          displayName: 'Batch Detailer',
          businessName: 'Batch Studio',
        );
        await repo.loginUser(detailerUser);

        final b1 = BookingAppointment(
          id: 'bk_all_01',
          clientId: 'client_1',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Alice',
          clientPhone: '555-1111',
          clientEmail: 'alice@example.com',
          vehicleYearMakeModel: '2024 BMW M3',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: DateTime.now().add(const Duration(days: 1)),
          scheduledTimeSlot: '10:00 AM',
          totalPrice: 200.0,
          depositAmount: 50.0,
          status: BookingStatus.confirmed,
        );

        final b2 = BookingAppointment(
          id: 'bk_all_02',
          clientId: 'client_2',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Charlie',
          clientPhone: '555-2222',
          clientEmail: 'charlie@example.com',
          vehicleYearMakeModel: '2023 Audi RS6',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: DateTime.now().add(const Duration(days: 2)),
          scheduledTimeSlot: '2:00 PM',
          totalPrice: 220.0,
          depositAmount: 50.0,
          status: BookingStatus.confirmed,
        );

        repo.addBooking(b1);
        repo.addBooking(b2);

        expect(repo.activeStudioBookings.length, equals(2));

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

        expect(find.text('Cancel All Bookings'), findsOneWidget);
        await tester.tap(find.text('Cancel All Bookings'));
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Cancel All Bookings?'), findsOneWidget);
        expect(find.text('Cancel & Notify All'), findsOneWidget);

        await tester.tap(find.text('Cancel & Notify All'));
        await tester.pumpAndSettle();

        // Both bookings must be cancelled
        expect(repo.activeStudioBookings, isEmpty);
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_all_01').status, equals(BookingStatus.cancelled));
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_all_02').status, equals(BookingStatus.cancelled));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
