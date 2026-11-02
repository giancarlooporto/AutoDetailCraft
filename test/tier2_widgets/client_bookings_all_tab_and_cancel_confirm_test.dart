import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPackage = ServicePackage(
    id: 'pkg_test_ceramic',
    title: '5-Year Ceramic Coating',
    description: 'Paint correction and ceramic coating application',
    basePrice: 850.0,
    estimatedDuration: '6 hrs',
    includes: ['Decon wash', '2-stage polish', 'Ceramic coat'],
  );

  group('Client Bookings: All Tab and Cancellation Confirmation Popup Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;
    });

    BookingAppointment makeBooking({
      required String id,
      required BookingStatus status,
      String vehicle = '2024 Porsche 911 GT3 RS',
      DateTime? scheduledDate,
      String timeSlot = '9:00 AM - 3:00 PM',
    }) {
      return BookingAppointment(
        id: id,
        clientId: repo.currentUser.id,
        detailerId: 'usr_detailer_austin',
        detailerName: 'Marcus Detailer',
        detailerBusinessName: 'Apex Precision Detailing',
        detailerAvatar: '',
        clientName: repo.currentUser.displayName.isNotEmpty ? repo.currentUser.displayName : 'Alex Client',
        clientPhone: '(512) 555-0199',
        clientEmail: repo.currentUser.username.contains('@') ? repo.currentUser.username : 'alex@example.com',
        vehicleYearMakeModel: vehicle,
        vehicleSize: VehicleSize.coupeSedan,
        package: testPackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin, TX',
        scheduledDate: scheduledDate ?? DateTime(2026, 12, 1),
        scheduledTimeSlot: timeSlot,
        totalPrice: 850.0,
        depositAmount: 170.0,
        status: status,
      );
    }

    testWidgets('1. Tab Bar renders 5 tabs: All, Upcoming, In Progress, Completed, Cancelled with correct counts', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b1 = makeBooking(id: 'bk_1', status: BookingStatus.confirmed, vehicle: '2024 Porsche GT3 RS', scheduledDate: DateTime(2026, 12, 1));
        final b2 = makeBooking(id: 'bk_2', status: BookingStatus.pending, vehicle: '2023 BMW M3 CS', scheduledDate: DateTime(2026, 12, 2));
        final b3 = makeBooking(id: 'bk_3', status: BookingStatus.inProgress, vehicle: '2022 Audi R8 V10', scheduledDate: DateTime(2026, 12, 3));
        final b4 = makeBooking(id: 'bk_4', status: BookingStatus.completed, vehicle: '2021 Mercedes-AMG GT', scheduledDate: DateTime(2026, 12, 4));
        final b5 = makeBooking(id: 'bk_5', status: BookingStatus.cancelled, vehicle: '2020 Corvette C8', scheduledDate: DateTime(2026, 12, 5));

        repo.addBooking(b1, allowOverbooking: true);
        repo.addBooking(b2, allowOverbooking: true);
        repo.addBooking(b3, allowOverbooking: true);
        repo.addBooking(b4, allowOverbooking: true);
        repo.addBooking(b5, allowOverbooking: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // 5 tabs must be present with accurate counts
        expect(find.text('All (5)'), findsOneWidget);
        expect(find.text('Upcoming (2)'), findsOneWidget);
        expect(find.text('In Progress (1)'), findsOneWidget);
        expect(find.text('Completed (1)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);

        // Switch to All tab (tab 0) and verify all 5 vehicle bookings are visible
        await tester.tap(find.text('All (5)'));
        await tester.pumpAndSettle();

        expect(find.text('2024 Porsche GT3 RS'), findsOneWidget);
        expect(find.text('2023 BMW M3 CS'), findsOneWidget);
        expect(find.text('2022 Audi R8 V10'), findsOneWidget);
        expect(find.text('2021 Mercedes-AMG GT'), findsOneWidget);
        expect(find.text('2020 Corvette C8'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2. Empty state on All tab renders dedicated empty view', (tester) async {
      setupMockImageHttpClient();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo, initialTabIndex: 0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('All (0)'), findsOneWidget);
        expect(find.text('No Bookings Found'), findsOneWidget);
        expect(find.text('All your booked detailing appointments will appear here.'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3. Client tapping Cancel Reservation shows confirmation popup dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b = makeBooking(id: 'bk_cancel_prompt_01', status: BookingStatus.confirmed, vehicle: '2024 BMW M4 Competition');
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Tap booking card to open details modal
        expect(find.text('2024 BMW M4 Competition'), findsOneWidget);
        await tester.tap(find.text('2024 BMW M4 Competition'));
        await tester.pumpAndSettle();

        // Inside modal: scroll to and tap Cancel Reservation
        expect(find.text('Cancel Reservation'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        // Confirmation dialog must appear
        expect(find.text('Cancel Reservation?'), findsOneWidget);
        expect(find.textContaining('Are you sure you want to cancel your appointment'), findsOneWidget);
        expect(find.text('Keep Appointment'), findsOneWidget);
        expect(find.text('Confirm Cancel'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('4. Dismissing cancellation dialog with Keep Appointment leaves booking active', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b = makeBooking(id: 'bk_keep_appt_01', status: BookingStatus.confirmed, vehicle: '2023 Porsche 718 Cayman');
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.text('2023 Porsche 718 Cayman'));
        await tester.pumpAndSettle();

        // Scroll to and tap Cancel Reservation
        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        // Tap Keep Appointment
        expect(find.text('Keep Appointment'), findsOneWidget);
        await tester.tap(find.text('Keep Appointment'));
        await tester.pumpAndSettle();

        // Confirmation dialog is closed, booking details modal is still open and status remains Confirmed
        expect(find.text('Cancel Reservation?'), findsNothing);
        expect(find.text('Cancel Reservation'), findsOneWidget);
        expect(repo.bookings.firstWhere((item) => item.id == 'bk_keep_appt_01').status, equals(BookingStatus.confirmed));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('5. Confirming cancellation cancels the reservation, dismisses modal, and shows SnackBar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b = makeBooking(id: 'bk_execute_cancel_01', status: BookingStatus.confirmed, vehicle: '2024 Lucid Air Sapphire');
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.text('2024 Lucid Air Sapphire'));
        await tester.pumpAndSettle();

        // Scroll to and tap Cancel Reservation
        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        // Tap Confirm Cancel in dialog
        expect(find.text('Confirm Cancel'), findsOneWidget);
        await tester.tap(find.text('Confirm Cancel'));
        await tester.pumpAndSettle();

        // Confirmation dialog and details modal must both be closed
        expect(find.text('Cancel Reservation?'), findsNothing);

        // Booking status in repository must now be cancelled
        expect(repo.bookings.firstWhere((item) => item.id == 'bk_execute_cancel_01').status, equals(BookingStatus.cancelled));

        // SnackBar must inform user of successful cancellation
        expect(find.text('Booking reservation has been cancelled.'), findsOneWidget);

        // Tab counts update accordingly
        expect(find.text('Upcoming (0)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);
        expect(find.text('All (1)'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('6. Tapping dialog barrier (outside) dismisses confirmation and preserves booking', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b = makeBooking(id: 'bk_barrier_dismiss_01', status: BookingStatus.confirmed, vehicle: '2024 McLaren Artura');
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('2024 McLaren Artura'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Reservation?'), findsOneWidget);

        // Tap on modal barrier (top-left outside the dialog)
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Dialog is dismissed, booking details modal is still active, booking remains confirmed
        expect(find.text('Cancel Reservation?'), findsNothing);
        expect(find.text('Cancel Reservation'), findsOneWidget);
        expect(repo.bookings.firstWhere((item) => item.id == 'bk_barrier_dismiss_01').status, equals(BookingStatus.confirmed));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('7. Cancelling directly from the All tab updates booking reactively to Cancelled in-place', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        final b = makeBooking(id: 'bk_all_tab_cancel_01', status: BookingStatus.confirmed, vehicle: '2025 Aston Martin Vantage');
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo, initialTabIndex: 0),
          ),
        );
        await tester.pumpAndSettle();

        // We are on All tab
        expect(find.text('All (1)'), findsOneWidget);
        expect(find.text('2025 Aston Martin Vantage'), findsOneWidget);

        // Tap booking from All tab
        await tester.tap(find.text('2025 Aston Martin Vantage'));
        await tester.pumpAndSettle();

        // Tap Cancel Reservation
        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.text('Confirm Cancel'));
        await tester.pumpAndSettle();

        // Booking on All tab is still visible but now reflects cancelled status and actions
        expect(find.text('2025 Aston Martin Vantage'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsOneWidget);
        expect(find.text('Dismiss from My Bookings'), findsOneWidget);
        expect(find.text('All (1)'), findsOneWidget);
        expect(find.text('Upcoming (0)'), findsOneWidget);
        expect(find.text('Cancelled (1)'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('8. Extremely narrow screens (<340px) with 5 tabs render without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      setupMockImageHttpClient();
      try {
        final b1 = makeBooking(id: 'bk_narrow_1', status: BookingStatus.confirmed, vehicle: 'Car 1');
        final b2 = makeBooking(id: 'bk_narrow_2', status: BookingStatus.inProgress, vehicle: 'Car 2');
        final b3 = makeBooking(id: 'bk_narrow_3', status: BookingStatus.completed, vehicle: 'Car 3');
        final b4 = makeBooking(id: 'bk_narrow_4', status: BookingStatus.cancelled, vehicle: 'Car 4');
        repo.addBooking(b1, allowOverbooking: true);
        repo.addBooking(b2, allowOverbooking: true);
        repo.addBooking(b3, allowOverbooking: true);
        repo.addBooking(b4, allowOverbooking: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow errors on narrow screen
        expect(errors, isEmpty);
        expect(find.text('All (4)'), findsOneWidget);
      } finally {
        FlutterError.onError = originalOnError;
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('9. Fallback strings render gracefully when package title and studio name are blank', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockImageHttpClient();
      try {
        const blankPkg = ServicePackage(
          id: 'pkg_blank',
          title: '',
          description: '',
          basePrice: 100.0,
          estimatedDuration: '1 hr',
          includes: [],
        );
        final b = BookingAppointment(
          id: 'bk_blank_meta',
          clientId: repo.currentUser.id,
          detailerId: 'usr_unknown',
          detailerName: '',
          detailerBusinessName: '',
          detailerAvatar: '',
          clientName: 'Alex',
          clientPhone: '555-0100',
          clientEmail: 'alex@example.com',
          vehicleYearMakeModel: 'Mystery Vehicle',
          vehicleSize: VehicleSize.coupeSedan,
          package: blankPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: '',
          scheduledDate: DateTime(2026, 12, 10),
          scheduledTimeSlot: '10:00 AM',
          totalPrice: 100.0,
          depositAmount: 20.0,
          status: BookingStatus.confirmed,
        );
        repo.addBooking(b);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mystery Vehicle'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Reservation'));
        await tester.pumpAndSettle();

        // Fallback text check
        expect(find.textContaining('Are you sure you want to cancel your appointment for your appointment with the detailing studio?'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
