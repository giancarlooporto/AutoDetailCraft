import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/widgets/booking_status_tracker.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';
import '../core/multi_device_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bidirectional Real-Time Booking Synchronization Widget Tests (R2 & R3)', () {
    late MultiDeviceTestHarness harness;
    late JobRepository clientRepo;
    late JobRepository detailerRepo;

    const samplePackage = ServicePackage(
      id: 'pkg_widget_sync_01',
      title: 'Full Exterior & Interior Detail',
      description: 'Complete foam wash, clay decon, and interior shampoo',
      basePrice: 250.0,
      estimatedDuration: '3 hrs',
      includes: ['Foam wash', 'Clay bar', 'Interior shampoo'],
    );

    BookingAppointment createTestBooking({
      required String id,
      BookingStatus status = BookingStatus.confirmed,
      DateTime? scheduledDate,
      String scheduledTimeSlot = '9:00 AM',
    }) {
      return BookingAppointment(
        id: id,
        clientId: clientRepo.currentUser.id,
        detailerId: detailerRepo.currentUser.id,
        detailerName: detailerRepo.currentUser.displayName,
        detailerBusinessName: detailerRepo.currentUser.businessName,
        detailerAvatar: '',
        clientName: clientRepo.currentUser.displayName,
        clientPhone: '(512) 555-1212',
        clientEmail: clientRepo.currentUser.username,
        vehicleYearMakeModel: '2024 BMW M4 Competition',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin TX',
        scheduledDate: scheduledDate ?? DateTime.now().add(const Duration(days: 2)),
        scheduledTimeSlot: scheduledTimeSlot,
        totalPrice: 250.0,
        depositAmount: 50.0,
        status: status,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      harness = MultiDeviceTestHarness();

      clientRepo = await harness.createClientDeviceSession(
        deviceId: 'client_device',
        userId: 'usr_client_widget',
        email: 'client@example.com',
        displayName: 'Client Jordan',
      );

      detailerRepo = await harness.createDetailerSession(
        detailerId: 'usr_detailer_widget',
        email: 'pro@apexdetail.com',
        displayName: 'Master Detailer',
        businessName: 'Apex Studio',
      );
    });

    tearDown(() {
      harness.dispose();
    });

    testWidgets('1. Detailer Confirms & Progresses Status -> Client UI Updates Immediately Without Reload', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final booking = createTestBooking(
          id: 'bk_rt_progress_01',
          status: BookingStatus.pending,
        );

        clientRepo.addBooking(booking);
        detailerRepo.addBooking(booking);

        // Pump Client BookingsListScreen
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: clientRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in Upcoming tab with Pending status
        expect(find.text('Upcoming (1)'), findsOneWidget);
        expect(find.text('In Progress (0)'), findsOneWidget);
        expect(find.text('Completed (0)'), findsOneWidget);
        expect(find.byType(BookingStatusTracker), findsOneWidget);
        expect(find.text('Pending'), findsWidgets);

        // Step 1: Detailer confirms booking
        await detailerRepo.updateBookingStatus('bk_rt_progress_01', BookingStatus.confirmed);
        harness.syncRawPayload(detailerRepo, {
          'id': 'bk_rt_progress_01',
          'status': 'confirmed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump();

        // Immediate reactive update without reload
        expect(find.text('Confirmed'), findsWidgets);
        expect(find.text('Upcoming (1)'), findsOneWidget);

        // Step 2: Detailer moves booking to In Progress
        await detailerRepo.updateBookingStatus('bk_rt_progress_01', BookingStatus.inProgress);
        harness.syncRawPayload(detailerRepo, {
          'id': 'bk_rt_progress_01',
          'status': 'in_progress',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump();

        // Tab count immediately flips
        expect(find.text('Upcoming (0)'), findsOneWidget);
        expect(find.text('In Progress (1)'), findsOneWidget);

        // Step 3: Detailer marks booking Completed
        await detailerRepo.updateBookingStatus('bk_rt_progress_01', BookingStatus.completed);
        harness.syncRawPayload(detailerRepo, {
          'id': 'bk_rt_progress_01',
          'status': 'completed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump();

        expect(find.text('In Progress (0)'), findsOneWidget);
        expect(find.text('Completed (1)'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2. Detailer Cancels Booking -> Client UI Updates Tab Badge, Shows Notice Banner & Releases Slot', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final booking = createTestBooking(
          id: 'bk_rt_cancel_client_01',
          status: BookingStatus.confirmed,
        );

        clientRepo.addBooking(booking);
        detailerRepo.addBooking(booking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: clientRepo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Upcoming (1)'), findsOneWidget);
        expect(find.text('Cancelled (0)'), findsOneWidget);

        // Detailer cancels booking with notification
        await detailerRepo.cancelStudioBookingWithClientNotification(
          'bk_rt_cancel_client_01',
          reason: 'Emergency weather hazard',
        );

        harness.syncRawPayload(detailerRepo, {
          'id': 'bk_rt_cancel_client_01',
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pumpAndSettle();

        // Client UI tabs update instantly
        expect(find.text('Upcoming (0)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);

        // Cancellation notice banner is displayed
        expect(
          find.textContaining('cancelled by the studio. Review under the Cancelled tab.'),
          findsOneWidget,
        );

        // Tap the Cancelled tab
        await tester.tap(find.text('Cancelled (1)'));
        await tester.pumpAndSettle();

        // Card displays Status: Cancelled • Slot Released
        expect(find.text('Status: Cancelled • Slot Released'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3. Client Cancels Booking -> Detailer Workbench Updates Immediately & Releases Slot', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final targetDate = DateTime.now().add(const Duration(days: 3));
        const targetSlot = '9:00 AM';

        final booking = createTestBooking(
          id: 'bk_client_initiates_cancel',
          status: BookingStatus.confirmed,
          scheduledDate: targetDate,
          scheduledTimeSlot: targetSlot,
        );

        clientRepo.addBooking(booking);
        detailerRepo.addBooking(booking);

        expect(detailerRepo.activeStudioBookings.length, equals(1));
        expect(detailerRepo.isSlotConflictedByBooking(targetDate, targetSlot), isTrue);

        // Pump Detailer Workbench
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: detailerRepo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Appointment is visible on Detailer Workbench
        expect(find.text('Client Jordan'), findsWidgets);

        // Client cancels booking from client app
        await clientRepo.cancelBooking('bk_client_initiates_cancel');
        harness.syncRawPayload(clientRepo, {
          'id': 'bk_client_initiates_cancel',
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pumpAndSettle();

        // Detailer active studio bookings cleared
        expect(detailerRepo.activeStudioBookings, isEmpty);

        // Calendar slot is immediately unlocked
        expect(detailerRepo.isSlotConflictedByBooking(targetDate, targetSlot), isFalse);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('4. Client Reschedules Booking -> Detailer Workbench Updates Appointment Slot in Real Time', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final initialDate = DateTime.now().add(const Duration(days: 2));
        final newDate = DateTime.now().add(const Duration(days: 5));

        final booking = createTestBooking(
          id: 'bk_resched_01',
          status: BookingStatus.confirmed,
          scheduledDate: initialDate,
          scheduledTimeSlot: '9:00 AM',
        );

        clientRepo.addBooking(booking);
        detailerRepo.addBooking(booking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: detailerRepo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('9:00 AM'), findsWidgets);

        // Client reschedules to new date and time slot
        clientRepo.rescheduleBooking('bk_resched_01', newDate, '2:00 PM - 5:00 PM');
        final updatedBooking = clientRepo.bookings.firstWhere((b) => b.id == 'bk_resched_01');
        harness.syncBookingChange(clientRepo, updatedBooking);
        await tester.pumpAndSettle();

        // Detailer workbench reflects the updated scheduled time slot immediately
        expect(find.text('2:00 PM - 5:00 PM'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('5. Reactive Modal: Open booking details modal updates status chip and action buttons on realtime cancellation without closing', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final booking = createTestBooking(
          id: 'bk_live_modal_01',
          status: BookingStatus.confirmed,
        );
        clientRepo.addBooking(booking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: clientRepo),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open the Booking Details Modal by tapping the booking card
        expect(find.text('2024 BMW M4 Competition'), findsOneWidget);
        await tester.tap(find.text('2024 BMW M4 Competition'));
        await tester.pumpAndSettle();

        // 2. Modal is open: verify initial Confirmed status and Cancel button
        expect(find.text('Appointment Details'), findsOneWidget);
        expect(find.text('Cancel Reservation'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsNothing);

        // 3. Simulate incoming Supabase Realtime broadcast: Detailer cancelled the booking
        clientRepo.simulateRealtimeBookingPayload({
          'id': 'bk_live_modal_01',
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump(); // trigger ListenableBuilder rebuild

        // 4. Verify modal is STILL open and reflects cancelled status dynamically
        expect(find.text('Appointment Details'), findsOneWidget);
        expect(find.text('Status: Cancelled • Slot Released'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsOneWidget);
        expect(find.text('Cancel Reservation'), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
