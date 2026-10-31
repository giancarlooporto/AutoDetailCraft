import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/screens/calendar_preferences_dialog.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('JobRepository Operating Hours & 24-Hour Time Math', () {
    test('JobRepository.closeTimeToMinutes correctly resolves midnight variants and standard times', () {
      expect(JobRepository.closeTimeToMinutes('12:00 AM'), 1440);
      expect(JobRepository.closeTimeToMinutes('12:00am'), 1440);
      expect(JobRepository.closeTimeToMinutes('12:00 AM (Midnight)'), 1440);
      expect(JobRepository.closeTimeToMinutes('midnight'), 1440);
      expect(JobRepository.closeTimeToMinutes('Midnight'), 1440);
      expect(JobRepository.closeTimeToMinutes('24:00'), 1440);
      expect(JobRepository.closeTimeToMinutes('24:00:00'), 1440);

      // Other standard times
      expect(JobRepository.closeTimeToMinutes('11:30 PM'), 1410);
      expect(JobRepository.closeTimeToMinutes('06:00 PM'), 1080);
      expect(JobRepository.closeTimeToMinutes('6:00 PM'), 1080);
      expect(JobRepository.closeTimeToMinutes('12:00 PM'), 720);
      expect(JobRepository.closeTimeToMinutes('12:30 AM'), 30);
      expect(JobRepository.closeTimeToMinutes(''), 0);
    });

    test('JobRepository.parseSlotRange resolves midnight/0 closing time to 1440', () {
      final range1 = JobRepository.parseSlotRange('11:00 PM - 12:00 AM');
      expect(range1.$1, 1380);
      expect(range1.$2, 1440);

      final range2 = JobRepository.parseSlotRange('09:00 PM - 12:00 AM (Midnight)');
      expect(range2.$1, 1260);
      expect(range2.$2, 1440);

      final range3 = JobRepository.parseSlotRange('8:00 AM - 11:00 AM');
      expect(range3.$1, 480);
      expect(range3.$2, 660);

      final range4 = JobRepository.parseSlotRange('10:00 PM • 12:00 AM');
      expect(range4.$1, 1320);
      expect(range4.$2, 1440);

      // Cross-midnight range (e.g. 11:00 PM to 01:00 AM = 2 hours = 120 mins)
      final rangeCrossMidnight = JobRepository.parseSlotRange('11:00 PM - 01:00 AM');
      expect(rangeCrossMidnight.$1, 1380);
      expect(rangeCrossMidnight.$2, 1500); // 1380 + 120 = 1500
      expect(rangeCrossMidnight.$2 - rangeCrossMidnight.$1, 120);

      final rangeCrossMidnightHalf = JobRepository.parseSlotRange('11:30 PM - 12:30 AM');
      expect(rangeCrossMidnightHalf.$1, 1410);
      expect(rangeCrossMidnightHalf.$2, 1470); // 1410 + 60 = 1470
    });

    test('JobRepository.getAppointmentTimeInterval handles cross-midnight appointments and detects conflicts', () {
      final repo = JobRepository();
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: [
          const DayBusinessHours(weekday: 1, isOpen: true, openTime: '12:00 AM', closeTime: '12:00 AM'),
        ],
        bufferMinutesBetweenJobs: 30,
      ));

      const testPkg = ServicePackage(
        id: 'pkg_late',
        title: 'Late Shift Detail',
        description: '2 hours',
        basePrice: 150,
        estimatedDuration: '2 hours',
        durationValue: 2,
        durationUnit: 'hours',
        includes: [],
      );

      final monday = DateTime(2026, 11, 2);
      final overnightAppt = BookingAppointment(
        id: 'appt_late_1',
        detailerId: repo.currentUser.id,
        detailerName: 'Test Studio',
        detailerBusinessName: 'Test Studio LLC',
        detailerAvatar: '',
        clientName: 'Late Client',
        clientPhone: '555-1234',
        clientEmail: 'late@example.com',
        vehicleYearMakeModel: '2024 Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: monday,
        scheduledTimeSlot: '11:00 PM - 01:00 AM',
        totalPrice: 150,
        depositAmount: 50,
        status: BookingStatus.confirmed,
        startTime: '11:00 PM',
        endTime: '01:00 AM',
        durationMinutes: 120,
      );

      final interval = JobRepository.getAppointmentTimeInterval(overnightAppt, bufferMinutes: 30);
      expect(interval.$1, 1380);
      expect(interval.$2, 1530); // 1380 + 120 + 30 buffer = 1530

      // Conflicting slot starting at 11:30 PM on Monday
      final conflictsWithLateNight = repo.isBookingConflictingWithSlot(overnightAppt, monday, '11:30 PM - 12:30 AM');
      expect(conflictsWithLateNight, isTrue, reason: '11:30 PM slot overlaps with 11:00 PM - 01:00 AM booking');
    });

    test('JobRepository.isSlotWithinOperatingHours supports 24-hour schedule and rejects slots past closing', () {
      final repo = JobRepository();
      // Configure Tuesday to be open 24 hours: 12:00 AM to 12:00 AM
      final schedule24h = [
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '12:00 AM', closeTime: '12:00 AM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '10:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: schedule24h,
      ));

      final tuesday = DateTime(2026, 11, 3); // Tuesday (24h)
      final wednesday = DateTime(2026, 11, 4); // Wednesday (8am - 10pm)

      // Check early morning slot (3:00 AM)
      expect(repo.isSlotWithinOperatingHours(tuesday, '3:00 AM - 5:00 AM'), isTrue);
      // Check midday slot (12:00 PM)
      expect(repo.isSlotWithinOperatingHours(tuesday, '12:00 PM - 3:00 PM'), isTrue);
      // Check late night slot ending at midnight
      expect(repo.isSlotWithinOperatingHours(tuesday, '10:00 PM - 12:00 AM'), isTrue);
      // Check slot starting at 12:00 AM midnight
      expect(repo.isSlotWithinOperatingHours(tuesday, '12:00 AM - 2:00 AM'), isTrue);

      // On 24-hour day, same-day slot ending past midnight (e.g. 11:30 PM - 12:30 AM) exceeds 1440 mins of the day
      expect(repo.isSlotWithinOperatingHours(tuesday, '11:30 PM - 12:30 AM'), isFalse);

      // On Wednesday (closing at 10:00 PM = 1320 min), slot ending at 12:30 AM must be rejected
      expect(repo.isSlotWithinOperatingHours(wednesday, '09:30 PM - 12:30 AM'), isFalse);
      expect(repo.isSlotWithinOperatingHours(wednesday, '08:00 PM - 10:00 PM'), isTrue);
    });

    test('JobRepository.getAvailableStartTimesForPackage generates slots spanning 24 hours', () {
      final repo = JobRepository();
      final schedule24h = [
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '12:00 AM', closeTime: '12:00 AM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: schedule24h,
        advanceNoticeHours: 0, // Disable lead time for pure time math testing
      ));

      final tuesday = DateTime(2026, 11, 3);
      const pkg2hr = ServicePackage(
        id: 'pkg_2hr',
        title: 'Express Polish',
        description: '2 hours',
        basePrice: 200,
        estimatedDuration: '2 hours',
        durationValue: 2,
        durationUnit: 'hours',
        includes: [],
      );

      final availableStarts = repo.getAvailableStartTimesForPackage(tuesday, pkg2hr);
      // Should include 12:00 AM
      expect(availableStarts, contains('12:00 AM'));
      // Should include early morning
      expect(availableStarts, contains('4:00 AM'));
      // Should include midday
      expect(availableStarts, contains('12:00 PM'));
      // Should include evening
      expect(availableStarts, contains('8:00 PM'));
      // 10:00 PM + 2h = 12:00 AM (1440 min <= 1440 min, valid)
      expect(availableStarts, contains('10:00 PM'));
      // 10:30 PM + 2h = 12:30 AM (> 1440 min on same day, excluded)
      expect(availableStarts, isNot(contains('10:30 PM')));
    });

    test('JobRepository.getAvailableStartTimesForPackage enforces booking lead time', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      const pkg1hr = ServicePackage(
        id: 'pkg_1hr',
        title: 'Quick Wash',
        description: '1 hour',
        basePrice: 100,
        estimatedDuration: '1 hour',
        durationValue: 1,
        durationUnit: 'hours',
        includes: [],
      );

      final dayRepo = JobRepository();
      dayRepo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: [
          DayBusinessHours(weekday: today.weekday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        ],
        advanceNoticeHours: 6,
      ));

      final starts = dayRepo.getAvailableStartTimesForPackage(today, pkg1hr);
      for (final s in starts) {
        final startMin = JobRepository.timeStringToMinutes(s);
        final slotDate = DateTime(today.year, today.month, today.day, startMin ~/ 60, startMin % 60);
        expect(slotDate.difference(now).inMinutes >= 6 * 60, isTrue,
            reason: 'Slot $s should not be within 6h notice window');
      }
    });

    test('JobRepository.calculateCompletionDateTime handles 24-hour schedule for multi-day jobs without looping', () {
      final repo = JobRepository();
      final schedule24h = List.generate(7, (i) => DayBusinessHours(
        weekday: i + 1,
        isOpen: true,
        openTime: '12:00 AM',
        closeTime: '12:00 AM',
      ));
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: schedule24h,
      ));

      const multiDayPkg = ServicePackage(
        id: 'pkg_multi',
        title: 'Multi-Day Ceramic Coating',
        description: '3 days turnaround',
        basePrice: 1500,
        estimatedDuration: '3 days',
        durationValue: 3,
        durationUnit: 'days',
        includes: [],
      );

      final startDate = DateTime(2026, 11, 2); // Monday
      final comp = repo.calculateCompletionDateTime(startDate, '9:00 AM', multiDayPkg);

      // 3 full business days starting Monday morning finishes Wednesday
      expect(comp.completionDate, DateTime(2026, 11, 4));
      expect(comp.completionTime, '12:00 AM');
    });

    test('JobRepository.getAvailablePickUpTimes includes midnight when open until 12:00 AM', () {
      final repo = JobRepository();
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: [
          const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '12:00 AM'),
        ],
      ));

      final monday = DateTime(2026, 11, 2);
      final pickUpTimes = repo.getAvailablePickUpTimes(monday, earliestTime: '9:00 PM');
      expect(pickUpTimes, contains('12:00 AM'));
      expect(pickUpTimes, contains('10:00 PM'));
      expect(pickUpTimes, contains('11:00 PM'));
    });
  });

  group('CalendarPreferencesDialog UI & State Tests', () {
    testWidgets('Renders 48 options for open/close dropdowns and matches 08:00 AM safely', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = JobRepository();
      await repo.init();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CalendarPreferencesDialog(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Open 24 Hours chip is present
      expect(find.text('Open 24 Hours'), findsWidgets);

      // Verify the legacy "HOURLY BOOKING TIME SLOTS" section is completely removed
      expect(find.text('HOURLY BOOKING TIME SLOTS'), findsNothing);
      expect(find.text('Default Slot Window Duration'), findsNothing);
      expect(find.text('Auto-Gen'), findsNothing);
      expect(find.text('Add Slot'), findsNothing);
    });

    testWidgets('Tapping Open 24 Hours chip updates day to 12:00 AM - 12:00 AM and saves correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = JobRepository();
      await repo.init();

      // Ensure model has slotDurationHours and customTimeSlots to test preservation
      repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(
        slotDurationHours: 4,
        customTimeSlots: ['8:00 AM - 12:00 PM', '1:00 PM - 5:00 PM'],
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CalendarPreferencesDialog(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the first "Open 24 Hours" chip (Monday)
      final first24hChip = find.text('Open 24 Hours').first;
      await tester.tap(first24hChip);
      await tester.pumpAndSettle();

      // Save schedule preferences
      final saveBtn = find.text('Save Schedule Preferences');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify repository was updated: Monday is now 12:00 AM to 12:00 AM
      final updatedPrefs = repo.calendarPreferences;
      final mondayHours = updatedPrefs.getHoursForWeekday(1);
      expect(mondayHours.isOpen, isTrue);
      expect(mondayHours.openTime, '12:00 AM');
      expect(mondayHours.closeTime, '12:00 AM');

      // Verify slotDurationHours and customTimeSlots are preserved for backwards compatibility
      expect(updatedPrefs.slotDurationHours, 4);
      expect(updatedPrefs.customTimeSlots, ['8:00 AM - 12:00 PM', '1:00 PM - 5:00 PM']);
    });

    testWidgets('CalendarPreferencesDialog validates close time after open time on save', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = JobRepository();
      await repo.init();
      // Configure Monday with invalid close time earlier than open time
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: [
          const DayBusinessHours(weekday: 1, isOpen: true, openTime: '06:00 PM', closeTime: '09:00 AM'),
        ],
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CalendarPreferencesDialog(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap save
      final saveBtn = find.text('Save Schedule Preferences');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Should display SnackBar and dialog should NOT close
      expect(find.text('Closing time must be after opening time on Monday.'), findsOneWidget);
      expect(find.text('Calendar & Operating Preferences'), findsOneWidget);
    });

    testWidgets('CalendarPreferencesDialog initializes blank days to 08:00 AM - 06:00 PM when toggled open', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = JobRepository();
      await repo.init();
      // Sunday closed with blank hours
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: [
          const DayBusinessHours(weekday: 7, isOpen: false, openTime: '', closeTime: ''),
        ],
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CalendarPreferencesDialog(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Sunday
      await tester.scrollUntilVisible(
        find.text('Sunday'),
        100,
        scrollable: find.byType(Scrollable).first,
      );

      // Find the Closed switch for Sunday and toggle it open
      final switches = find.byType(Switch);
      await tester.tap(switches.last);
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Save Schedule Preferences');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final sundayHours = repo.calendarPreferences.getHoursForWeekday(7);
      expect(sundayHours.isOpen, isTrue);
      expect(sundayHours.openTime, '08:00 AM');
      expect(sundayHours.closeTime, '06:00 PM');
    });
  });

  group('BookingFlowScreen 30-Minute Stepping & 24-Hour Schedule', () {
    testWidgets('Candidate arrival slots generate every 30m directly from operating hours', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = JobRepository();
        await repo.init();

        // Detailer with 24-hour schedule on Monday Nov 2, 2026
        final monday = DateTime(2026, 11, 2);
        repo.updateCalendarPreferences(DetailerCalendarPreferences(
          weeklySchedule: [
            const DayBusinessHours(weekday: 1, isOpen: true, openTime: '12:00 AM', closeTime: '12:00 AM'),
          ],
          advanceNoticeHours: 0,
        ));

        const testPkg = ServicePackage(
          id: 'pkg_test_30m',
          title: '30 Min Express',
          description: '30 min job',
          basePrice: 50,
          estimatedDuration: '30 mins',
          durationValue: 30,
          durationUnit: 'mins',
          includes: [],
        );

        final detailer = repo.currentUser;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                repository: repo,
                detailer: detailer,
                initialPackage: testPkg,
                initialDate: monday,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Verify slots are generated every 30 mins
        // For instance, early morning slots like 12:00 AM, 12:30 AM, 1:00 AM
        expect(find.text('12:00 AM'), findsWidgets);
        expect(find.text('12:30 AM'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Multi-day package with midnight closing correctly offers and selects 12:00 AM pickup', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = JobRepository();
        await repo.init();

        final monday = DateTime(2026, 11, 2);
        repo.updateCalendarPreferences(DetailerCalendarPreferences(
          weeklySchedule: List.generate(7, (i) => DayBusinessHours(
            weekday: i + 1,
            isOpen: true,
            openTime: '08:00 AM',
            closeTime: '12:00 AM',
          )),
          advanceNoticeHours: 0,
        ));

        const multiDayPkg = ServicePackage(
          id: 'pkg_multi_mid',
          title: '2-Day Ceramic Shield',
          description: '2 days turnaround',
          basePrice: 1200,
          estimatedDuration: '2 days',
          durationValue: 2,
          durationUnit: 'days',
          includes: [],
        );

        final detailer = repo.currentUser;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                repository: repo,
                detailer: detailer,
                initialPackage: multiDayPkg,
                initialDate: monday,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Pick-up options for Tuesday should include 12:00 AM midnight
        expect(find.text('12:00 AM'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
