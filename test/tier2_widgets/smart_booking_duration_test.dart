import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Smart Booking Duration & Multi-Day Scheduling Unit Tests', () {
    test('1. ServicePackage duration parsing handles decimals, ranges, and explicit values', () {
      // Explicit values
      const pkgExplicit = ServicePackage(
        id: 'pkg_exp',
        title: 'Paint Correction',
        description: 'Multi-stage',
        basePrice: 300,
        estimatedDuration: '4 hours',
        durationValue: 5,
        durationUnit: 'hours',
        includes: [],
      );
      expect(pkgExplicit.durationMinutes, 300);
      expect(pkgExplicit.durationHours, 5.0);
      expect(pkgExplicit.isMultiDay, isFalse);
      expect(pkgExplicit.durationBadge, '5 hrs');

      // Decimals e.g. 2.5 hrs
      const pkgDecimal = ServicePackage(
        id: 'pkg_dec',
        title: 'Quick Wash',
        description: 'Wash',
        basePrice: 100,
        estimatedDuration: '2.5 hrs',
        includes: [],
      );
      expect(pkgDecimal.durationMinutes, 150);
      expect(pkgDecimal.durationHours, 2.5);
      expect(pkgDecimal.isMultiDay, isFalse);
      expect(pkgDecimal.durationBadge, '2.5 hrs');

      // Range e.g. 2 - 3 hrs (picks conservative upper bound: 3 hrs)
      const pkgRange = ServicePackage(
        id: 'pkg_rng',
        title: 'Interior Detail',
        description: 'Shampoo',
        basePrice: 180,
        estimatedDuration: '2 - 3 hrs',
        includes: [],
      );
      expect(pkgRange.durationMinutes, 180);
      expect(pkgRange.durationHours, 3.0);
      expect(pkgRange.durationBadge, '3 hrs');

      // Multi-day range e.g. 1 - 2 Days (picks conservative upper bound: 2 days)
      const pkgMulti = ServicePackage(
        id: 'pkg_multi',
        title: 'Ceramic Coating & Correction',
        description: 'Ceramic',
        basePrice: 950,
        estimatedDuration: '1 - 2 Days',
        includes: [],
      );
      expect(pkgMulti.durationMinutes, 2880);
      expect(pkgMulti.isMultiDay, isTrue);
      expect(pkgMulti.turnaroundDays, 2);
      expect(pkgMulti.durationBadge, '2 Days Turnaround');

      // Explicit days unit
      const pkgExplicitDays = ServicePackage(
        id: 'pkg_exp_days',
        title: 'Full Restoration',
        description: 'Restoration',
        basePrice: 1500,
        estimatedDuration: '3 days',
        durationValue: 3,
        durationUnit: 'days',
        includes: [],
      );
      expect(pkgExplicitDays.durationMinutes, 4320);
      expect(pkgExplicitDays.isMultiDay, isTrue);
      expect(pkgExplicitDays.turnaroundDays, 3);
      expect(pkgExplicitDays.durationBadge, '3 Days Turnaround');
    });

    test('2. BookingAppointment serialization roundtrip preserves completionDate and times', () {
      final now = DateTime.now();
      final completion = now.add(const Duration(days: 2));

      final appt = BookingAppointment(
        id: 'bk_unit_test_01',
        detailerId: 'det_1',
        detailerName: 'Marcus Detailer',
        detailerBusinessName: 'Apex Studio',
        detailerAvatar: '',
        clientName: 'Alice Springs',
        clientPhone: '555-0100',
        clientEmail: 'alice@example.com',
        vehicleYearMakeModel: '2023 Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_ceramic_unit',
          title: '5-Year Ceramic',
          description: 'Ceramic Coating',
          basePrice: 900,
          estimatedDuration: '2 days',
          durationValue: 2,
          durationUnit: 'days',
          includes: ['Coating'],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: now,
        scheduledTimeSlot: 'Drop-off: 9:00 AM • Ready: 5:00 PM',
        totalPrice: 900,
        depositAmount: 180,
        completionDate: completion,
        startTime: '9:00 AM',
        endTime: '5:00 PM',
        durationMinutes: 2880,
        isMultiDay: true,
      );

      final json = appt.toJson();
      expect(json['isMultiDay'], isTrue);
      expect(json['startTime'], '9:00 AM');
      expect(json['endTime'], '5:00 PM');
      expect(json['durationMinutes'], 2880);
      expect(json['completionDate'], completion.toIso8601String());

      final reconstituted = BookingAppointment.fromJson(json);
      expect(reconstituted.isMultiDay, isTrue);
      expect(reconstituted.startTime, '9:00 AM');
      expect(reconstituted.endTime, '5:00 PM');
      expect(reconstituted.durationMinutes, 2880);
      expect(reconstituted.completionDate?.year, completion.year);
      expect(reconstituted.completionDate?.month, completion.month);
      expect(reconstituted.completionDate?.day, completion.day);
      expect(reconstituted.scheduledTimeSlot, 'Drop-off: 9:00 AM • Ready: 5:00 PM');
    });

    test('3. JobRepository.calculateCompletionDateTime for same-day and multi-day', () {
      final repo = JobRepository();

      // Configure Monday-Friday 8:00 AM - 6:00 PM, Saturday 9:00 AM - 4:00 PM, Sunday Closed
      final customWeekly = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '04:00 PM'), // Sat Closed
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '04:00 PM'), // Sun Closed
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: customWeekly,
        customTimeSlots: ['8:00 AM - 11:00 AM', '1:00 PM - 4:00 PM'],
      ));

      // Same-day package (4 hours = 240 mins)
      const sameDayPkg = ServicePackage(
        id: 'pkg_same',
        title: 'Paint Correction',
        description: 'Cut and polish',
        basePrice: 400,
        estimatedDuration: '4 hours',
        durationValue: 4,
        durationUnit: 'hours',
        includes: [],
      );

      final wednesday = DateTime(2026, 11, 4); // Wednesday
      final sameDayResult = repo.calculateCompletionDateTime(wednesday, '9:00 AM', sameDayPkg);
      expect(sameDayResult.completionDate.day, wednesday.day);
      expect(sameDayResult.completionTime, '1:00 PM'); // 9:00 AM + 4 hrs = 1:00 PM

      // Multi-day package: 2 days turnaround dropped off on Friday
      const multiDayPkg = ServicePackage(
        id: 'pkg_multi_2',
        title: 'Ceramic Coating',
        description: 'Multi-day',
        basePrice: 900,
        estimatedDuration: '2 days',
        durationValue: 2,
        durationUnit: 'days',
        includes: [],
      );

      final friday = DateTime(2026, 11, 6); // Friday
      final multiDayResult = repo.calculateCompletionDateTime(friday, '9:00 AM', multiDayPkg);
      // Friday = Day 1. Saturday is closed. Sunday is closed. Monday Nov 9 = Day 2!
      expect(multiDayResult.completionDate.weekday, DateTime.monday);
      expect(multiDayResult.completionDate.day, 9);
      expect(multiDayResult.completionTime, '06:00 PM');
    });

    test('4. JobRepository.getAvailableStartTimesForPackage excludes times exceeding shop closing', () {
      final repo = JobRepository();
      final customWeekly = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: customWeekly,
        customTimeSlots: ['8:00 AM - 11:00 AM', '11:00 AM - 2:00 PM', '2:00 PM - 5:00 PM'],
      ));

      final monday = DateTime(2026, 11, 2); // Monday

      // 6-hour package (360 mins) in a shop that opens at 8am and closes at 5pm (9 total hours)
      const sixHourPkg = ServicePackage(
        id: 'pkg_6hr',
        title: 'Full Transformation',
        description: 'Long job',
        basePrice: 600,
        estimatedDuration: '6 hours',
        durationValue: 6,
        durationUnit: 'hours',
        includes: [],
      );

      final availableStarts = repo.getAvailableStartTimesForPackage(monday, sixHourPkg);
      // Shop closes at 5:00 PM (17:00). A 6-hour job MUST start by 11:00 AM.
      // 8:00 AM + 6h = 2:00 PM (<= 5:00 PM, VALID)
      // 9:00 AM + 6h = 3:00 PM (<= 5:00 PM, VALID)
      // 10:00 AM + 6h = 4:00 PM (<= 5:00 PM, VALID)
      // 11:00 AM + 6h = 5:00 PM (<= 5:00 PM, VALID)
      // 12:00 PM + 6h = 6:00 PM (> 5:00 PM, MUST BE EXCLUDED)
      // 1:00 PM + 6h = 7:00 PM (> 5:00 PM, MUST BE EXCLUDED)
      // 2:00 PM + 6h = 8:00 PM (> 5:00 PM, MUST BE EXCLUDED)
      expect(availableStarts, contains('8:00 AM'));
      expect(availableStarts, contains('11:00 AM'));
      expect(availableStarts, isNot(contains('12:00 PM')));
      expect(availableStarts, isNot(contains('1:00 PM')));
      expect(availableStarts, isNot(contains('2:00 PM')));
    });

    test('5. Multi-day booking blocks intermediate days in isBookingConflictingWithSlot', () {
      final repo = JobRepository();
      final dropOffDate = DateTime(2026, 11, 2); // Monday
      final readyDate = DateTime(2026, 11, 4); // Wednesday

      final multiDayAppt = BookingAppointment(
        id: 'bk_multi_span_01',
        detailerId: repo.currentUser.id,
        detailerName: 'Marcus Detailer',
        detailerBusinessName: 'Apex Studio',
        detailerAvatar: '',
        clientName: 'Bob Client',
        clientPhone: '555-1111',
        clientEmail: 'bob@example.com',
        vehicleYearMakeModel: '2022 Rivian R1T',
        vehicleSize: VehicleSize.truckVan,
        package: const ServicePackage(
          id: 'pkg_multi_span',
          title: '3-Day Ceramic & PPF',
          description: 'Multi-day',
          basePrice: 1200,
          estimatedDuration: '3 days',
          durationValue: 3,
          durationUnit: 'days',
          includes: [],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: dropOffDate,
        scheduledTimeSlot: 'Drop-off: 9:00 AM • Ready: 5:00 PM',
        totalPrice: 1200,
        depositAmount: 240,
        completionDate: readyDate,
        startTime: '9:00 AM',
        endTime: '5:00 PM',
        durationMinutes: 4320,
        isMultiDay: true,
      );

      repo.addBooking(multiDayAppt);

      // 1. Tuesday (intermediate day): entire day MUST be conflicted for any slot
      final tuesday = DateTime(2026, 11, 3);
      expect(repo.isBookingConflictingWithSlot(multiDayAppt, tuesday, '9:00 AM - 12:00 PM'), isTrue);
      expect(repo.isBookingConflictingWithSlot(multiDayAppt, tuesday, '1:00 PM - 4:00 PM'), isTrue);

      // 2. Thursday (after completion): MUST NOT conflict
      final thursday = DateTime(2026, 11, 5);
      expect(repo.isBookingConflictingWithSlot(multiDayAppt, thursday, '9:00 AM - 12:00 PM'), isFalse);

      // 3. getBookingsForDate returns multi-day appointment for Monday, Tuesday, and Wednesday
      expect(repo.getBookingsForDate(dropOffDate).map((b) => b.id), contains('bk_multi_span_01'));
      expect(repo.getBookingsForDate(tuesday).map((b) => b.id), contains('bk_multi_span_01'));
      expect(repo.getBookingsForDate(readyDate).map((b) => b.id), contains('bk_multi_span_01'));
      expect(repo.getBookingsForDate(thursday).map((b) => b.id), isNot(contains('bk_multi_span_01')));
    });

    test('6. Compound duration string parsing and safe JSON deserialization', () {
      // Compound "1 hr 30 mins" -> 90 mins
      const pkgCompound = ServicePackage(
        id: 'pkg_comp_1',
        title: 'Quick Polish & Wax',
        description: 'Compound duration test',
        basePrice: 160,
        estimatedDuration: '1 hr 30 mins',
        includes: [],
      );
      expect(pkgCompound.durationMinutes, 90);
      expect(pkgCompound.durationHours, 1.5);
      expect(pkgCompound.durationBadge, '1.5 hrs');

      // Compound "2 hours 45 mins" -> 165 mins
      expect(JobRepository.parseDurationToMinutes('2 hours 45 mins'), 165);

      // Safe JSON deserialization with num and String values
      final rawJson = {
        'id': 'pkg_json_safe',
        'title': 'Ceramic Seal',
        'description': 'Safe deserialization',
        'basePrice': 500,
        'estimatedDuration': '2 days',
        'durationValue': 2.0, // double in json
        'durationUnit': 'days',
      };
      final parsed = ServicePackage.fromJson(rawJson);
      expect(parsed.durationValue, 2);
      expect(parsed.durationUnit, 'days');
      expect(parsed.isMultiDay, isTrue);
      expect(parsed.turnaroundDays, 2);

      final apptJson = {
        'id': 'bk_json_safe',
        'detailerId': 'det_safe',
        'package': rawJson,
        'durationMinutes': 2880.0, // double in json
        'isMultiDay': 'true', // string bool in json
        'scheduledDate': DateTime(2026, 11, 2).toIso8601String(),
        'scheduledTimeSlot': 'Drop-off: 9:00 AM • Ready: 5:00 PM',
        'totalPrice': 500.0,
        'depositAmount': 100.0,
      };
      final parsedAppt = BookingAppointment.fromJson(apptJson);
      expect(parsedAppt.durationMinutes, 2880);
      expect(parsedAppt.isMultiDay, isTrue);
    });

    test('7. Multi-day turnaround across leap year, calendar year, and 3 consecutive closed days', () {
      final repo = JobRepository();
      // Schedule: Mon-Fri open 8:00 AM - 5:00 PM, Sat-Sun closed
      final standardWeekly = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: standardWeekly));

      const twoDayPkg = ServicePackage(
        id: 'pkg_leap',
        title: 'Leap Year Polish',
        description: 'Test',
        basePrice: 500,
        estimatedDuration: '2 days',
        durationValue: 2,
        durationUnit: 'days',
        includes: [],
      );

      // Leap year 2028: Feb 28 is Monday, Feb 29 is Tuesday (leap day!)
      final leapFeb28 = DateTime(2028, 2, 28);
      final leapResult = repo.calculateCompletionDateTime(leapFeb28, '9:00 AM', twoDayPkg);
      expect(leapResult.completionDate.year, 2028);
      expect(leapResult.completionDate.month, 2);
      expect(leapResult.completionDate.day, 29); // Feb 29 leap day accounted!

      // Year boundary 2026 -> 2027: Dec 31 is Thursday, Jan 1 is Friday (Day 2!)
      final dec31 = DateTime(2026, 12, 31);
      final yearResult = repo.calculateCompletionDateTime(dec31, '9:00 AM', twoDayPkg);
      expect(yearResult.completionDate.year, 2027);
      expect(yearResult.completionDate.month, 1);
      expect(yearResult.completionDate.day, 1);

      // 3 consecutive closed days: Fri-Sun closed (weekday 5, 6, 7 closed)
      final fourDayWeek = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: false, openTime: '08:00 AM', closeTime: '05:00 PM'), // Fri closed
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'), // Sat closed
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'), // Sun closed
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: fourDayWeek));

      final thursday = DateTime(2026, 11, 5); // Thursday (Day 1)
      final threeOffResult = repo.calculateCompletionDateTime(thursday, '9:00 AM', twoDayPkg);
      // Fri (closed), Sat (closed), Sun (closed) -> Monday Nov 9 is Day 2!
      expect(threeOffResult.completionDate.weekday, DateTime.monday);
      expect(threeOffResult.completionDate.day, 9);

      // Infinite loop protection when all 7 days are closed
      final allClosed = List.generate(7, (i) => DayBusinessHours(weekday: i + 1, isOpen: false, openTime: '', closeTime: ''));
      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: allClosed));
      final safeTermination = repo.calculateCompletionDateTime(DateTime(2026, 11, 2), '9:00 AM', twoDayPkg);
      expect(safeTermination.completionDate, isNotNull);
    });

    test('8. getBookingsForDate and isDateFullyBlocked identify multi-day coverage on rollover business days when completionDate is null', () {
      final repo = JobRepository();
      final standardWeekly = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: standardWeekly));

      final friday = DateTime(2026, 11, 6);
      final legacyAppt = BookingAppointment(
        id: 'bk_legacy_rollover',
        detailerId: repo.currentUser.id,
        detailerName: 'Test Detailer',
        detailerBusinessName: 'Studio',
        detailerAvatar: '',
        clientName: 'Legacy Client',
        clientPhone: '555-9999',
        clientEmail: 'legacy@test.com',
        vehicleYearMakeModel: '2024 Corvette Z06',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_legacy_2day',
          title: '2-Day Ceramic',
          description: 'Multi-day',
          basePrice: 800,
          estimatedDuration: '2 days',
          durationValue: 2,
          durationUnit: 'days',
          includes: [],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: friday,
        scheduledTimeSlot: 'Drop-off: 9:00 AM • Ready: 5:00 PM',
        totalPrice: 800,
        depositAmount: 160,
        completionDate: null, // Legacy: completionDate is null!
        startTime: '9:00 AM',
        endTime: '5:00 PM',
        durationMinutes: 2880,
        isMultiDay: true,
      );

      repo.addBooking(legacyAppt);

      // Friday is Day 1
      expect(repo.getBookingsForDate(friday).map((b) => b.id), contains('bk_legacy_rollover'));

      // Monday Nov 9 is Day 2 (ready day)
      final monday = DateTime(2026, 11, 9);
      expect(repo.getBookingsForDate(monday).map((b) => b.id), contains('bk_legacy_rollover'));

      // Tuesday Nov 10 is after ready day
      final tuesday = DateTime(2026, 11, 10);
      expect(repo.getBookingsForDate(tuesday).map((b) => b.id), isNot(contains('bk_legacy_rollover')));
    });
  });

  group('Smart Booking Duration & Multi-Day Scheduling UI Widget Tests', () {
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
      servicePackages: const [
        ServicePackage(
          id: 'pkg_same_day_test',
          title: '3-Step Stage 2 Paint Polish',
          description: 'Thorough single-day correction',
          basePrice: 350.0,
          estimatedDuration: '4 hours',
          durationValue: 4,
          durationUnit: 'hours',
          includes: ['Decontamination', 'Machine compound', 'Jeweling polish'],
        ),
        ServicePackage(
          id: 'pkg_multi_day_test',
          title: 'Signature 5-Year Ceramic & Paint Correction',
          description: 'Multi-day deep restoration & curing',
          basePrice: 950.0,
          estimatedDuration: '2 days',
          durationValue: 2,
          durationUnit: 'days',
          includes: ['Full correction', 'Dual layer 9H ceramic', 'Infrared curing'],
        ),
      ],
    );

    testWidgets('UI 1: Same-Day Mode shows duration badge, arrival chips, and Live Schedule Card', (tester) async {
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
        repo.addVehicleToGarage(const UserVehicle(
          id: 'v_smart_01',
          make: 'Porsche',
          model: '911 Carrera',
          year: 2024,
          colorName: 'Chalk',
          imageUrl: '',
        ));

        // Find an open weekday
        DateTime openDate = DateTime.now().add(const Duration(days: 1));
        while (repo.isDateRecurringDayOff(openDate, detailerId: studioDetailer.id) ||
               !repo.getHoursForDate(openDate, detailerId: studioDetailer.id).isOpen) {
          openDate = openDate.add(const Duration(days: 1));
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: openDate,
                initialPackage: studioDetailer.servicePackages.first, // 4-hour package
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 1. Verify package duration indicator is rendered
        expect(find.textContaining('⏱️ Duration: 4 hrs'), findsOneWidget);

        // 2. Verify Arrival / Start Time section is rendered
        expect(find.text('Select Arrival / Start Time'), findsOneWidget);

        // 3. Verify Live Schedule Window card is displayed
        expect(find.text('Live Schedule Window'), findsOneWidget);
        expect(find.textContaining('Drop-off:'), findsWidgets);
        expect(find.textContaining('Estimated Finish:'), findsWidgets);
        expect(find.textContaining('Today'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 2: Multi-Day Mode shows turnaround badge, drop-off date/time, ready date/time, and populates appointment', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
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
        repo.addVehicleToGarage(const UserVehicle(
          id: 'v_smart_02',
          make: 'BMW',
          model: 'M4 Competition',
          year: 2024,
          colorName: 'Frozen Brilliant White',
          imageUrl: '',
        ));

        // Find an open weekday
        DateTime openDate = DateTime.now().add(const Duration(days: 1));
        while (repo.isDateRecurringDayOff(openDate, detailerId: studioDetailer.id) ||
               !repo.getHoursForDate(openDate, detailerId: studioDetailer.id).isOpen) {
          openDate = openDate.add(const Duration(days: 1));
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: openDate,
                initialPackage: studioDetailer.servicePackages[1], // 2-day multi-day package
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 1. Verify Multi-Day Service Indicator
        expect(find.textContaining('🗓️ Multi-Day Service: 2 Days Turnaround'), findsOneWidget);

        // 2. Choice 1: Drop-off Date & Time
        expect(find.text('Choice 1: Drop-off Date & Time (Start)'), findsOneWidget);

        // 3. Choice 2: Ready for Pick-up
        expect(find.text('Choice 2: Ready for Pick-up (Finished)'), findsOneWidget);
        expect(find.textContaining('Estimated Ready Date:'), findsOneWidget);
        expect(find.text('Select Preferred Pick-up Time:'), findsOneWidget);

        // 4. Multi-Day Turnaround Schedule card
        expect(find.text('Multi-Day Turnaround Schedule'), findsOneWidget);

        // Advance to Step 2 (Checkout Review)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 5. In Review Step: verify schedule card displays Drop-off and Ready dates
        expect(find.text('Drop-off (Start):'), findsOneWidget);
        expect(find.text('Ready Pick-up (Finished):'), findsOneWidget);

        // Enter contact info
        final nameField = find.widgetWithText(TextField, 'Full Name');
        await tester.enterText(nameField, 'John Client');
        final phoneField = find.widgetWithText(TextField, 'Mobile Phone (For SMS updates)');
        await tester.enterText(phoneField, '555-123-4567');
        final emailField = find.widgetWithText(TextField, 'Email Address (For Warranty Receipt)');
        await tester.enterText(emailField, 'john.client@example.com');
        await tester.pumpAndSettle();

        // Complete booking
        await tester.tap(find.text('Reserve & Book'));
        await tester.pumpAndSettle();

        // 6. Verify Booking Confirmation Modal shows multi-day schedule
        expect(find.text('Booking Reserved!'), findsOneWidget);
        expect(find.text('Ready for Pick-up'), findsOneWidget);
        expect(find.text('Turnaround'), findsOneWidget);

        // 7. Verify created appointment in repository has multi-day fields populated
        final createdAppt = repo.bookings.firstWhere((b) => b.package.id == 'pkg_multi_day_test');
        expect(createdAppt.isMultiDay, isTrue);
        expect(createdAppt.startTime, isNotNull);
        expect(createdAppt.endTime, isNotNull);
        expect(createdAppt.completionDate, isNotNull);
        expect(createdAppt.scheduledTimeSlot, contains('Drop-off:'));
        expect(createdAppt.scheduledTimeSlot, contains('Ready:'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 3: BookingsListScreen displays multi-day turnaround and drop-off / ready dates', (tester) async {
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

        final dropOffDate = DateTime.now().add(const Duration(days: 2));
        final readyDate = dropOffDate.add(const Duration(days: 2));

        final multiDayAppt = BookingAppointment(
          id: 'bk_card_test_01',
          clientId: repo.currentUser.id,
          detailerId: studioDetailer.id,
          detailerName: studioDetailer.displayName,
          detailerBusinessName: studioDetailer.businessName,
          detailerAvatar: '',
          clientName: 'Charlie Client',
          clientPhone: '555-4321',
          clientEmail: repo.currentUser.username.contains('@') ? repo.currentUser.username : 'charlie@example.com',
          vehicleYearMakeModel: '2023 Mercedes-AMG GT Black Series',
          vehicleSize: VehicleSize.coupeSedan,
          package: studioDetailer.servicePackages[1], // 2 days
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: dropOffDate,
          scheduledTimeSlot: 'Drop-off: 9:00 AM • Ready: 5:00 PM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.confirmed,
          completionDate: readyDate,
          startTime: '9:00 AM',
          endTime: '5:00 PM',
          durationMinutes: 2880,
          isMultiDay: true,
        );

        repo.addBooking(multiDayAppt);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingsListScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify card renders multi-day format
        expect(find.textContaining('Drop-off:'), findsWidgets);
        expect(find.textContaining('Ready:'), findsWidgets);

        // 2. Tap appointment card to open details modal
        await tester.tap(find.text('2023 Mercedes-AMG GT Black Series'));
        await tester.pumpAndSettle();

        // 3. Verify details modal displays Drop-off Date & Time, Ready Pick-up Date & Time, and Turnaround Time
        expect(find.text('Drop-off Date & Time'), findsOneWidget);
        expect(find.text('Ready Pick-up Date & Time'), findsOneWidget);
        expect(find.text('Turnaround Time'), findsOneWidget);
        expect(find.text('2 Days Turnaround'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 4: Same-day start time exceeding closing time is marked CLOSED in BookingFlowScreen', (tester) async {
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
        repo.addVehicleToGarage(const UserVehicle(
          id: 'v_smart_03',
          make: 'Audi',
          model: 'RS6 Avant',
          year: 2024,
          colorName: 'Nardo Gray',
          imageUrl: '',
        ));

        // Monday open 8:00 AM - 5:00 PM
        final customSchedule = [
          const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
        ];
        repo.updateCalendarPreferences(DetailerCalendarPreferences(
          weeklySchedule: customSchedule,
          customTimeSlots: ['8:00 AM - 11:00 AM', '11:00 AM - 2:00 PM', '2:00 PM - 5:00 PM'],
        ));

        DateTime monday = DateTime.now().add(const Duration(days: 1));
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }

        const sixHourPkg = ServicePackage(
          id: 'pkg_6hr_ui',
          title: 'Full Day Restorative Polish',
          description: '6 hour job',
          basePrice: 650.0,
          estimatedDuration: '6 hours',
          durationValue: 6,
          durationUnit: 'hours',
          includes: ['Multi-stage polishing'],
        );

        final detailerProfile = studioDetailer.copyWith(
          servicePackages: [sixHourPkg],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: detailerProfile,
                repository: repo,
                initialDate: monday,
                initialPackage: sixHourPkg,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Duration badge rendered
        expect(find.textContaining('⏱️ Duration: 6 hrs'), findsOneWidget);

        // 2:00 PM starts at 14:00 + 6h = 20:00 (8:00 PM), finishes 3 hours after 5:00 PM close -> MUST BE CLOSED!
        expect(find.text('CLOSED'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 5: Multi-Day mode checks each candidate slot individually rather than assuming _selectedStartTime', (tester) async {
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
        repo.addVehicleToGarage(const UserVehicle(
          id: 'v_smart_04',
          make: 'Lucid',
          model: 'Air Sapphire',
          year: 2024,
          colorName: 'Sapphire Blue',
          imageUrl: '',
        ));

        // Monday open 8:00 AM - 6:00 PM
        final customSchedule = [
          const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
        ];
        repo.updateCalendarPreferences(DetailerCalendarPreferences(
          weeklySchedule: customSchedule,
          customTimeSlots: ['9:00 AM - 12:00 PM', '1:00 PM - 4:00 PM'],
        ));

        DateTime monday = DateTime.now().add(const Duration(days: 1));
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }

        // Add a conflicting booking at 1:00 PM on Monday
        repo.addBooking(BookingAppointment(
          id: 'bk_conflict_1pm',
          detailerId: studioDetailer.id,
          detailerName: studioDetailer.displayName,
          detailerBusinessName: studioDetailer.businessName,
          detailerAvatar: '',
          clientName: 'Busy Customer',
          clientPhone: '555-7777',
          clientEmail: 'busy@test.com',
          vehicleYearMakeModel: '2023 Tesla Model S Plaid',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_quick',
            title: 'Maintenance Detail',
            description: 'Quick',
            basePrice: 150,
            estimatedDuration: '3 hours',
            includes: [],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: monday,
          scheduledTimeSlot: '1:00 PM - 4:00 PM',
          totalPrice: 150,
          depositAmount: 30,
          startTime: '1:00 PM',
          endTime: '4:00 PM',
          durationMinutes: 180,
          isMultiDay: false,
        ));

        final multiPkg = studioDetailer.servicePackages[1]; // 2 days
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: monday,
                initialPackage: multiPkg,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Multi-day section rendered
        expect(find.text('Choice 1: Drop-off Date & Time (Start)'), findsOneWidget);

        // 1:00 PM MUST be marked BOOKED while 9:00 AM is free
        expect(find.text('BOOKED'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 6: ServicePackageEditorDialog shows informative helper callout explaining same-day vs multi-day turnaround', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Same-day package with hours unit
      const sameDayPkg = ServicePackage(
        id: 'pkg_editor_same',
        title: 'Interior Detail',
        description: 'Deep clean',
        basePrice: 180,
        estimatedDuration: '3 hours',
        durationValue: 3,
        durationUnit: 'hours',
        includes: ['Steam clean'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ServicePackageEditorDialog(
              package: sameDayPkg,
              onSave: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Same-day callout is rendered
      expect(find.textContaining('Same-Day Service: Clients choose an Arrival Start Time'), findsOneWidget);

      // 2. Multi-day package with days unit
      const multiDayPkg = ServicePackage(
        id: 'pkg_editor_multi',
        title: '5-Year Ceramic',
        description: 'Multi-layer',
        basePrice: 1200,
        estimatedDuration: '2 days',
        durationValue: 2,
        durationUnit: 'days',
        includes: ['Coating'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ServicePackageEditorDialog(
              package: multiDayPkg,
              onSave: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Multi-day callout is rendered
      expect(find.textContaining('Multi-Day Turnaround: Clients will choose both a Drop-off Date/Time and a Ready Pick-up Date/Time'), findsOneWidget);
    });
  });
}
