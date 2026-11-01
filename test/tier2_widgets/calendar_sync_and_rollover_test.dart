import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Calendar Sync, Technician Assignment & Late Drop-off Rollover Tests', () {
    test('Rollover: 5:30 PM drop-off with 6:00 PM close rolls over to next open business day', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      // Monday Nov 2, 2026. Standard hours 8:00 AM - 6:00 PM.
      final monday = DateTime(2026, 11, 2);
      const pkg = ServicePackage(
        id: 'pkg_rollover',
        title: 'Paint Correction & Ceramic Coating',
        description: 'Multi-hour correction',
        basePrice: 600.0,
        estimatedDuration: '3 hrs',
        includes: ['Decon', 'Correction', 'Ceramic'],
      );

      // Start at 5:30 PM (17:30). Shop closes at 6:00 PM (18:00).
      // Work is scheduled to start at shop opening (8:00 AM) the next open business day (Tuesday Nov 3).
      // 8:00 AM + 3 hours (180 mins) = 11:00 AM.
      final result = repo.calculateCompletionDateTime(
        monday,
        '5:30 PM',
        pkg,
      );

      final isRollover = result.completionDate.isAfter(DateTime(monday.year, monday.month, monday.day));
      expect(isRollover, isTrue, reason: 'Job should roll over because duration exceeds remaining shop time');
      expect(result.completionDate.year, equals(2026));
      expect(result.completionDate.month, equals(11));
      expect(result.completionDate.day, equals(3), reason: 'Completion date must be Tuesday (next business day)');
      expect(result.completionTime, equals('11:00 AM'), reason: '8:00 AM opening + 180 min duration = 11:00 AM');
    });

    test('Rollover: Friday late drop-off rolls over past weekend to Monday when closed on weekends', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      // Update operating hours: Friday open 8am-6pm, Saturday & Sunday closed.
      final customSchedule = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '04:00 PM'),
      ];

      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: customSchedule));

      // Friday Nov 6, 2026.
      final friday = DateTime(2026, 11, 6);
      const pkg = ServicePackage(
        id: 'pkg_weekend_roll',
        title: 'Full Overhaul',
        description: 'Multi-hour overhaul',
        basePrice: 800.0,
        estimatedDuration: '4 hrs',
        includes: ['Detail'],
      );

      // Drop off Friday at 5:00 PM (17:00). 1 hr before close.
      // Scheduled to start on next open business day: Monday Nov 9 at 8:00 AM.
      // 8:00 AM + 4 hrs = 12:00 PM.
      final result = repo.calculateCompletionDateTime(
        friday,
        '5:00 PM',
        pkg,
      );

      final isRollover = result.completionDate.isAfter(DateTime(friday.year, friday.month, friday.day));
      expect(isRollover, isTrue);
      expect(result.completionDate.year, equals(2026));
      expect(result.completionDate.month, equals(11));
      expect(result.completionDate.day, equals(9), reason: 'Completion must skip Sat/Sun to Monday Nov 9');
      expect(result.completionTime, equals('12:00 PM'));
    });

    test('Conflict Detection: Rollover booking blocks Day 1 drop-off and Day 2 completion window', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      final monday = DateTime(2026, 11, 2);
      final tuesday = DateTime(2026, 11, 3);

      const pkg = ServicePackage(
        id: 'pkg_test',
        title: 'Test Package',
        description: 'Test',
        basePrice: 300.0,
        estimatedDuration: '2 hrs',
        includes: [],
      );

      // Existing rollover booking: Monday 5:30 PM drop-off, completes Tuesday 9:30 AM (8am + 90 min)
      final rolloverBooking = BookingAppointment(
        id: 'b_rollover_existing',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Charlie Rollover',
        clientPhone: '555-1111',
        clientEmail: 'charlie@test.com',
        vehicleYearMakeModel: 'Corvette C8',
        vehicleSize: VehicleSize.coupeSedan,
        package: pkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: monday,
        scheduledTimeSlot: 'Drop-off: 5:30 PM • Ready Next Day: 9:30 AM',
        startTime: '5:30 PM',
        endTime: '9:30 AM',
        completionDate: tuesday,
        durationMinutes: 120,
        isMultiDay: true,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(rolloverBooking);

      // 1. Another appointment on Monday at 5:45 PM overlaps Day 1 window (5:30 PM - 6:00 PM)
      final conflictMon = repo.isBookingConflictingWithSlot(
        rolloverBooking,
        monday,
        '5:45 PM - 6:15 PM',
      );
      expect(conflictMon, isTrue, reason: 'Monday drop-off window 5:30-6:00 PM is reserved');

      // 2. Another appointment on Tuesday at 8:30 AM overlaps Day 2 window (8:00 AM - 9:30 AM)
      final conflictTueMorning = repo.isBookingConflictingWithSlot(
        rolloverBooking,
        tuesday,
        '8:30 AM - 9:00 AM',
      );
      expect(conflictTueMorning, isTrue, reason: 'Tuesday morning 8:00-9:30 AM is reserved for rollover completion');

      // 3. Appointment on Tuesday at 10:00 AM is after 9:30 AM completion -> should NOT conflict
      final freeTueAfter = repo.isBookingConflictingWithSlot(
        rolloverBooking,
        tuesday,
        '10:00 AM - 11:00 AM',
      );
      expect(freeTueAfter, isFalse, reason: 'Tuesday 10:00 AM onwards is free');
    });

    test('BookingAppointment: Safe date parsing avoids UTC-5 midnight shift', () {
      final json = {
        'id': 'b_safe_date',
        'detailer_id': 'det_1',
        'detailer_name': 'Detail Master',
        'scheduled_date': '2026-11-05T00:00:00.000Z',
        'start_time': '5:30 PM',
        'end_time': '10:30 AM',
        'completion_date': '2026-11-06T10:30:00.000Z',
        'duration_minutes': 180,
        'is_multi_day': true,
        'status': 'confirmed',
        'total_price': 500.0,
      };

      final appointment = BookingAppointment.fromJson(json);

      // Must strictly be Nov 5, NOT Nov 4 even if running in UTC-5 timezone
      expect(appointment.scheduledDate.year, equals(2026));
      expect(appointment.scheduledDate.month, equals(11));
      expect(appointment.scheduledDate.day, equals(5));

      // Completion date must be Nov 6
      expect(appointment.completionDate, isNotNull);
      expect(appointment.completionDate!.day, equals(6));

      expect(appointment.startTime, equals('5:30 PM'));
      expect(appointment.endTime, equals('10:30 AM'));
      expect(appointment.isMultiDay, isTrue);
      expect(appointment.durationMinutes, equals(180));
    });

    testWidgets('UI: Calendar and Booked tab badges synchronize immediately across months', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        // Add a booking for next month (December 2026)
        final futureBooking = BookingAppointment(
          id: 'b_december_sync',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Daniel Dec',
          clientPhone: '555-9999',
          clientEmail: 'dan@example.com',
          vehicleYearMakeModel: 'Porsche 911 GT3',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.isNotEmpty
              ? repo.currentUser.servicePackages.first
              : MockDataService.standardPackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime(2026, 12, 15),
          scheduledTimeSlot: '10:00 AM - 2:00 PM',
          totalPrice: 450.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );

        repo.addBooking(futureBooking);

        // Studio bookings now has 1 active booking
        expect(repo.studioBookings.length, equals(1));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: DetailerWorkbenchView(
              repository: repo,
              initialCalendarDate: DateTime(2026, 11, 2), // Viewing November
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both Calendar and Booked hub tiles must display '1' badge
        final badgeFinder = find.text('1');
        expect(badgeFinder, findsAtLeastNWidgets(2),
            reason: 'Both Calendar and Booked hubs must show 1 badge immediately without requiring date navigation');
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    testWidgets('UI: Unassigned bookings are displayed in workbench calendar even when technician filter is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        final teamMember = const TeamMember(
          id: 'tm_expert',
          name: 'Sarah Connor',
          roleTitle: 'Senior Specialist',
          avatarUrl: '',
        );

        final standardPkg = repo.currentUser.servicePackages.isNotEmpty
            ? repo.currentUser.servicePackages.first
            : MockDataService.standardPackages.first;

        await repo.updateCurrentUser(
          repo.currentUser.copyWith(
            teamMembers: [teamMember],
            servicePackages: [standardPkg],
          ),
        );

        // Add an incoming unassigned booking for Monday Nov 2, 2026
        final unassignedBooking = BookingAppointment(
          id: 'b_unassigned_1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Eve Unassigned',
          clientPhone: '555-4444',
          clientEmail: 'eve@example.com',
          vehicleYearMakeModel: 'BMW M4',
          vehicleSize: VehicleSize.coupeSedan,
          package: standardPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime(2026, 11, 2),
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 350.0,
          depositAmount: 50.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: null, // Unassigned
        );

        repo.addBooking(unassignedBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: DetailerWorkbenchView(
              repository: repo,
              initialCalendarDate: DateTime(2026, 11, 2),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Calendar hub tile
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Verify unassigned appointment is visible in the Day Inspector
        expect(find.textContaining('Eve Unassigned'), findsOneWidget);
        expect(find.textContaining('BMW M4'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    test('Rollover: all late drop-off slots up to closing time (4:00, 4:30, 5:00, 5:30 PM for 6:00 PM close) are included and not blocked', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      final monday = DateTime(2026, 11, 2); // 8:00 AM - 6:00 PM
      const pkg3hr = ServicePackage(
        id: 'pkg_3hr',
        title: '3-Hour Detail',
        description: 'Detailing',
        basePrice: 350.0,
        estimatedDuration: '3 hrs',
        includes: ['Wash'],
      );

      final availableTimes = repo.getAvailableStartTimesForPackage(
        monday,
        pkg3hr,
        allowLateDropOff: true,
      );

      expect(availableTimes.contains('4:00 PM'), isTrue, reason: '4:00 PM drop-off should be available');
      expect(availableTimes.contains('4:30 PM'), isTrue, reason: '4:30 PM drop-off should be available');
      expect(availableTimes.contains('5:00 PM'), isTrue, reason: '5:00 PM drop-off should be available');
      expect(availableTimes.contains('5:30 PM'), isTrue, reason: '5:30 PM drop-off should be available');
      expect(availableTimes.contains('6:00 PM'), isFalse, reason: '6:00 PM is closing time, cannot start at/after close');
    });

    test('Conflict Detection: Rollover booking with null explicit endTime frees Day 2 afternoon', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      final monday = DateTime(2026, 11, 2);
      final tuesday = DateTime(2026, 11, 3);

      const pkg = ServicePackage(
        id: 'pkg_test2',
        title: 'Test Package',
        description: 'Test',
        basePrice: 300.0,
        estimatedDuration: '2 hrs',
        includes: [],
      );

      // Rollover booking where endTime is null and only in scheduledTimeSlot
      final rollover = BookingAppointment(
        id: 'b_rollover_no_end_field',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'No End Time Field',
        clientPhone: '555-2222',
        clientEmail: 'noend@test.com',
        vehicleYearMakeModel: 'Ford Mustang',
        vehicleSize: VehicleSize.coupeSedan,
        package: pkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: monday,
        scheduledTimeSlot: 'Drop-off: 5:30 PM • Ready Next Day: 10:00 AM',
        startTime: '5:30 PM',
        endTime: null, // intentionally null
        completionDate: tuesday,
        durationMinutes: 120,
        isMultiDay: true,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(rollover);

      // Tuesday 8:30 AM should conflict (before 10:00 AM)
      expect(repo.isBookingConflictingWithSlot(rollover, tuesday, '8:30 AM - 9:30 AM'), isTrue);

      // Tuesday 2:00 PM should NOT conflict (after 10:00 AM)
      expect(repo.isBookingConflictingWithSlot(rollover, tuesday, '2:00 PM - 3:00 PM'), isFalse);
    });

    testWidgets('UI: BookingFlowScreen allows 5:00 PM and 5:30 PM drop-off, shows Ready Next Day, and repo updates do not reset selection', (tester) async {
      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        const longPkg = ServicePackage(
          id: 'pkg_3hr',
          title: 'Full Ceramic Protection',
          description: 'Ceramic Coating',
          basePrice: 500.0,
          estimatedDuration: '3 hrs',
          includes: ['Wash', 'Coating'],
        );

        final detailer = repo.currentUser.copyWith(
          servicePackages: [longPkg],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: detailer,
              initialPackage: longPkg,
              repository: repo,
              initialDate: DateTime(2026, 11, 2), // Monday
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 0: Proceed to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 5:30 PM chip should be visible and NOT marked CLOSED or lineThrough
        final chip530Finder = find.widgetWithText(FilterChip, '5:30 PM');
        expect(chip530Finder, findsOneWidget, reason: '5:30 PM drop-off slot must be offered');

        // Tap 5:30 PM chip
        await tester.tap(chip530Finder);
        await tester.pumpAndSettle();

        // Schedule window should show Ready Next Day: 11:00 AM
        expect(find.textContaining('Ready Next Day'), findsWidgets);

        // Simulate repository update (e.g. background sync)
        repo.notifyListeners();
        await tester.pumpAndSettle();

        // The selected chip must STILL be 5:30 PM and NOT reset to 8:00 AM!
        final chip530Widget = tester.widget<FilterChip>(chip530Finder);
        expect(chip530Widget.selected, isTrue, reason: '5:30 PM selection must survive repo notifyListeners');

        // Tap Continue button to proceed to Step 2
        final continueBtn = find.text('Continue');
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        // Step 2 should display appointment summary with Ready Next Day
        expect(find.textContaining('Ready Next Day'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    testWidgets('UI: Assign technician button is visible and operable for unassigned bookings when filtered to a technician', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        final teamMember = const TeamMember(
          id: 'tm_expert',
          name: 'Sarah Connor',
          roleTitle: 'Senior Specialist',
          avatarUrl: '',
        );

        final standardPkg = repo.currentUser.servicePackages.isNotEmpty
            ? repo.currentUser.servicePackages.first
            : MockDataService.standardPackages.first;

        await repo.updateCurrentUser(
          repo.currentUser.copyWith(
            teamMembers: [teamMember],
            servicePackages: [standardPkg],
          ),
        );

        final unassignedBooking = BookingAppointment(
          id: 'b_assign_test_1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Sarah Booking Test',
          clientPhone: '555-8888',
          clientEmail: 'sarah_client@example.com',
          vehicleYearMakeModel: 'Porsche Taycan',
          vehicleSize: VehicleSize.coupeSedan,
          package: standardPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: DateTime(2026, 11, 2),
          scheduledTimeSlot: '10:00 AM - 1:00 PM',
          totalPrice: 350.0,
          depositAmount: 50.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: null, // Unassigned
        );

        repo.addBooking(unassignedBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: DetailerWorkbenchView(
              repository: repo,
              initialCalendarDate: DateTime(2026, 11, 2),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Calendar hub tile
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Filter to Sarah Connor (team member) using pane 2 dropdown
        final dropdown = find.byKey(const Key('calendar_team_dropdown_pane2'));
        expect(dropdown, findsOneWidget);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        final item = find.text('Sarah Connor').last;
        await tester.tap(item);
        await tester.pumpAndSettle();

        // Unassigned booking should still be visible
        expect(find.textContaining('Sarah Booking Test'), findsOneWidget);

        // Assign button should be visible even though Sarah Connor filter is active
        final assignBtn = find.text('Assign');
        expect(assignBtn, findsOneWidget, reason: 'Assign button must be visible for unassigned bookings under tech filter');

        // Tap Assign button
        await tester.tap(assignBtn);
        await tester.pumpAndSettle();

        // Assignment dialog should appear
        expect(find.text('Assign Technician to Booking'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    test('Operating Hours Sync: refreshDetailerPreferences updates _detailerPreferencesMap and propagates across detailer and client views', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      const detailerId = 'detailer_target_sync_1';
      final detailerSchedule5pm = [
        for (int w = 1; w <= 7; w++)
          DayBusinessHours(weekday: w, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
      ];
      final prefs5pm = DetailerCalendarPreferences(
        weeklySchedule: detailerSchedule5pm,
        autoConfirmBookings: false,
      );

      // Save directly to local storage for this specific detailer
      await LocalStorageService.saveDetailerCalendarPreferences(prefs5pm, detailerId: detailerId);

      // Call refreshDetailerPreferences to load and hydrate into repo
      await repo.refreshDetailerPreferences(detailerId);

      final loadedPrefs = repo.getCalendarPreferences(detailerId: detailerId);
      expect(loadedPrefs.weeklySchedule.first.closeTime, equals('05:00 PM'));
      expect(loadedPrefs.autoConfirmBookings, isFalse);

      final hoursMonday = repo.getHoursForDate(DateTime(2026, 11, 2), detailerId: detailerId);
      expect(hoursMonday.closeTime, equals('05:00 PM'));

      // Detailer updates operating hours to 6:00 PM closing
      final detailerSchedule6pm = [
        for (int w = 1; w <= 7; w++)
          DayBusinessHours(weekday: w, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
      ];
      final prefs6pm = DetailerCalendarPreferences(
        weeklySchedule: detailerSchedule6pm,
        autoConfirmBookings: true,
      );

      repo.updateCalendarPreferences(prefs6pm, detailerId: detailerId);

      final updatedPrefs = repo.getCalendarPreferences(detailerId: detailerId);
      expect(updatedPrefs.weeklySchedule.first.closeTime, equals('06:00 PM'));
      expect(updatedPrefs.autoConfirmBookings, isTrue);

      final updatedHours = repo.getHoursForDate(DateTime(2026, 11, 2), detailerId: detailerId);
      expect(updatedHours.closeTime, equals('06:00 PM'));
    });

    testWidgets('Operating Hours: Detailer changes closing time to 5:00 PM -> client drop-off slots end at 4:30 PM; 5:00 PM and 5:30 PM do NOT appear', (tester) async {
      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        const targetDetailerId = 'detailer_5pm_studio';
        final schedule5pm = [
          for (int w = 1; w <= 7; w++)
            DayBusinessHours(weekday: w, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        ];
        final prefs5pm = DetailerCalendarPreferences(weeklySchedule: schedule5pm);
        repo.updateCalendarPreferences(prefs5pm, detailerId: targetDetailerId);

        const standardPkg = ServicePackage(
          id: 'pkg_5pm_test',
          title: 'Standard Detail Service',
          description: 'Basic Wash',
          basePrice: 120.0,
          estimatedDuration: '2 hrs',
          includes: ['Wash'],
        );

        final targetDetailer = UserProfile(
          id: targetDetailerId,
          username: 'detailer_5pm',
          displayName: 'Five PM Studio',
          businessName: 'Five PM Studio',
          servicePackages: [standardPkg],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: targetDetailer,
              initialPackage: standardPkg,
              repository: repo,
              initialDate: DateTime(2026, 11, 2), // Monday
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (date & time selection)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 4:30 PM drop-off slot MUST appear as the last drop-off slot
        final chip430Finder = find.widgetWithText(FilterChip, '4:30 PM');
        expect(chip430Finder, findsOneWidget, reason: '4:30 PM drop-off slot must appear for 5:00 PM closing');

        // 5:00 PM and 5:30 PM must NEVER be generated, rendered, or shown as blocked
        final chip500Finder = find.widgetWithText(FilterChip, '5:00 PM');
        expect(chip500Finder, findsNothing, reason: '5:00 PM slot must NOT appear when closing at 5:00 PM');

        final chip530Finder = find.widgetWithText(FilterChip, '5:30 PM');
        expect(chip530Finder, findsNothing, reason: '5:30 PM slot must NOT appear when closing at 5:00 PM');

        // Verify there is no 'BLOCKED' badge displayed for 5:30 PM
        expect(find.text('BLOCKED'), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    testWidgets('Operating Hours: Detailer changes closing time to 6:00 PM -> 5:30 PM drop-off is generated, open/available (NOT blocked) for both same-day rollover and multi-day packages', (tester) async {
      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        const targetDetailerId = 'detailer_6pm_studio';
        final schedule6pm = [
          for (int w = 1; w <= 7; w++)
            DayBusinessHours(weekday: w, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        ];
        final prefs6pm = DetailerCalendarPreferences(weeklySchedule: schedule6pm);
        repo.updateCalendarPreferences(prefs6pm, detailerId: targetDetailerId);

        const rolloverPkg = ServicePackage(
          id: 'pkg_rollover_3hr',
          title: '3-Hour Paint Correction',
          description: 'Paint correction',
          basePrice: 400.0,
          estimatedDuration: '3 hrs',
          includes: ['Correction'],
        );

        const multiDayPkg = ServicePackage(
          id: 'pkg_multiday_full',
          title: 'Full Multi-Day Resto',
          description: 'Multi-day restoration',
          basePrice: 1200.0,
          estimatedDuration: '2 days',
          includes: ['Restoration'],
        );

        final targetDetailer = UserProfile(
          id: targetDetailerId,
          username: 'detailer_6pm',
          displayName: 'Six PM Studio',
          businessName: 'Six PM Studio',
          servicePackages: [rolloverPkg, multiDayPkg],
        );

        // 1. Test Same-day rollover package
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: targetDetailer,
              initialPackage: rolloverPkg,
              repository: repo,
              initialDate: DateTime(2026, 11, 2), // Monday
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final chip530Rollover = find.widgetWithText(FilterChip, '5:30 PM');
        expect(chip530Rollover, findsOneWidget, reason: '5:30 PM drop-off slot must exist for 6:00 PM closing');

        final filterChipWidgetRollover = tester.widget<FilterChip>(chip530Rollover);
        expect(filterChipWidgetRollover.onSelected, isNotNull, reason: '5:30 PM drop-off must be selectable (NOT disabled/blocked)');
        expect(find.text('BLOCKED'), findsNothing, reason: 'No BLOCKED badge for 5:30 PM slot');

        await tester.tap(chip530Rollover);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(chip530Rollover).selected, isTrue);

        // 2. Test Multi-day package
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: targetDetailer,
              initialPackage: multiDayPkg,
              repository: repo,
              initialDate: DateTime(2026, 11, 2), // Monday
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final chip530MultiDay = find.widgetWithText(FilterChip, '5:30 PM');
        expect(chip530MultiDay, findsOneWidget, reason: '5:30 PM drop-off slot must exist for multi-day package');

        final filterChipWidgetMultiDay = tester.widget<FilterChip>(chip530MultiDay);
        expect(filterChipWidgetMultiDay.onSelected, isNotNull, reason: '5:30 PM drop-off must be selectable for multi-day');
        expect(find.text('BLOCKED'), findsNothing, reason: 'No BLOCKED badge for multi-day 5:30 PM slot');

        await tester.ensureVisible(chip530MultiDay);
        await tester.tap(chip530MultiDay, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(chip530MultiDay).selected, isTrue);
      } finally {
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  });
}
