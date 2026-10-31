import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/calendar_preferences_dialog.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:intl/intl.dart';
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

    test('9. Multi-day 2-day work precision: morning vs afternoon drop-offs and pick-up constraints', () {
      final repo = JobRepository();
      final schedule = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '05:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(weeklySchedule: schedule));

      const twoDayPkg = ServicePackage(
        id: 'pkg_precise_2day',
        title: '2-Day Ceramic Coating',
        description: 'Multi-stage paint correction and 2-layer coating',
        basePrice: 1000,
        estimatedDuration: '2 days',
        durationValue: 2,
        durationUnit: 'days',
        includes: [],
      );

      final monday = DateTime(2026, 11, 2); // Monday

      // 1. Drop-off on Monday morning (9:00 AM): 2 full days of work -> ready end of Tuesday (Day 2 closing)
      final morningResult = repo.calculateCompletionDateTime(monday, '9:00 AM', twoDayPkg);
      expect(morningResult.completionDate.weekday, DateTime.tuesday);
      expect(morningResult.completionDate.day, 3);
      expect(morningResult.completionTime, '05:00 PM');

      // Pick-up times on Tuesday: ONLY 5:00 PM (closing). Client cannot take car back before 2 full days!
      final tuesdayPickUp = repo.getAvailablePickUpTimes(
        morningResult.completionDate,
        earliestTime: morningResult.completionTime,
      );
      expect(tuesdayPickUp, ['05:00 PM']);
      expect(tuesdayPickUp, isNot(contains('1:00 PM')));
      expect(tuesdayPickUp, isNot(contains('2:00 PM')));
      expect(tuesdayPickUp, isNot(contains('3:00 PM')));

      // 2. Drop-off on Monday afternoon (1:00 PM): Day 1 provides 4h, Day 2 provides 9h, Day 3 provides 5h
      // Ready Wednesday at 1:00 PM (Day 3)!
      final afternoon1pmResult = repo.calculateCompletionDateTime(monday, '1:00 PM', twoDayPkg);
      expect(afternoon1pmResult.completionDate.weekday, DateTime.wednesday);
      expect(afternoon1pmResult.completionDate.day, 4);
      expect(afternoon1pmResult.completionTime, '1:00 PM');

      // Pick-up times on Wednesday: from 1:00 PM to 5:00 PM closing
      final wednesday1pmPickUp = repo.getAvailablePickUpTimes(
        afternoon1pmResult.completionDate,
        earliestTime: afternoon1pmResult.completionTime,
      );
      expect(wednesday1pmPickUp, contains('1:00 PM'));
      expect(wednesday1pmPickUp, contains('2:00 PM'));
      expect(wednesday1pmPickUp, contains('5:00 PM'));
      expect(wednesday1pmPickUp, isNot(contains('9:00 AM')));
      expect(wednesday1pmPickUp, isNot(contains('10:00 AM')));
      expect(wednesday1pmPickUp, isNot(contains('11:00 AM')));
      expect(wednesday1pmPickUp, isNot(contains('12:00 PM')));

      // 3. Drop-off on Monday afternoon (2:00 PM): ready Wednesday at 2:00 PM
      final afternoon2pmResult = repo.calculateCompletionDateTime(monday, '2:00 PM', twoDayPkg);
      expect(afternoon2pmResult.completionDate.weekday, DateTime.wednesday);
      expect(afternoon2pmResult.completionDate.day, 4);
      expect(afternoon2pmResult.completionTime, '2:00 PM');

      // 4. Drop-off on Friday afternoon (1:00 PM): weekend closed -> ready Tuesday (Day 3) at 1:00 PM
      final friday = DateTime(2026, 11, 6);
      final friAfternoonResult = repo.calculateCompletionDateTime(friday, '1:00 PM', twoDayPkg);
      expect(friAfternoonResult.completionDate.weekday, DateTime.tuesday);
      expect(friAfternoonResult.completionDate.day, 10);
      expect(friAfternoonResult.completionTime, '1:00 PM');
    });

    test('10. Turnaround days parsing handles multi-day hours and clean deduplication', () {
      const pkg48Hrs = ServicePackage(
        id: 'pkg_48',
        title: '48 Hour Coating',
        description: 'Multi-day work expressed in hours',
        basePrice: 800,
        estimatedDuration: '48 hours',
        includes: [],
      );
      expect(pkg48Hrs.isMultiDay, isTrue);
      expect(pkg48Hrs.turnaroundDays, 2); // 48h = 2 days, not 30!

      const pkg24Hrs = ServicePackage(
        id: 'pkg_24',
        title: '24 Hour Paint Correction',
        description: 'Full day work expressed in hours',
        basePrice: 500,
        estimatedDuration: '24 hrs',
        includes: [],
      );
      expect(pkg24Hrs.isMultiDay, isTrue);
      expect(pkg24Hrs.turnaroundDays, 1); // 24h = 1 day, not 24!

      const pkg3Days = ServicePackage(
        id: 'pkg_3d',
        title: '3-Day Restoration',
        description: 'Multi-stage paint correction and curing',
        basePrice: 1500,
        estimatedDuration: '3 days',
        includes: [],
      );
      expect(pkg3Days.isMultiDay, isTrue);
      expect(pkg3Days.turnaroundDays, 3);

      final repo = JobRepository();
      // Default closing is 06:00 PM; verify pickup times deduplication even if earliestTime has leading zero
      final slots = repo.getAvailablePickUpTimes(
        DateTime(2026, 11, 2),
        earliestTime: '06:00 PM',
      );
      expect(slots, ['06:00 PM']);
      expect(slots.length, 1);
    });

    test('11. 30-min candidate slots, exact 1.5h job + 30m buffer leaving 10:00 AM open, and shop closing protection', () {
      final repo = JobRepository();
      final customWeekly = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
      ];
      repo.updateCalendarPreferences(DetailerCalendarPreferences(
        weeklySchedule: customWeekly,
        bufferMinutesBetweenJobs: 30,
      ));

      final monday = DateTime(2026, 11, 2); // Monday

      // 1.5-hour package (90 mins)
      const onePointFiveHourPkg = ServicePackage(
        id: 'pkg_1_5hr',
        title: 'Paint Polish & Seal',
        description: '1.5 hr job',
        basePrice: 180,
        estimatedDuration: '1 hr 30 mins',
        durationUnit: 'hours',
        includes: [],
      );

      // Book 8:00 AM to 9:30 AM
      final appt8am = BookingAppointment(
        id: 'bk_8am_930am',
        detailerId: repo.currentUser.id,
        detailerName: 'Detailer',
        detailerBusinessName: 'Studio',
        detailerAvatar: '',
        clientName: 'Early Client',
        clientPhone: '555-0001',
        clientEmail: 'early@test.com',
        vehicleYearMakeModel: 'Porsche Cayman',
        vehicleSize: VehicleSize.coupeSedan,
        package: onePointFiveHourPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: monday,
        scheduledTimeSlot: '8:00 AM - 9:30 AM',
        startTime: '8:00 AM',
        endTime: '9:30 AM',
        durationMinutes: 90,
        totalPrice: 180,
        depositAmount: 36,
      );
      repo.addBooking(appt8am);

      // 8:00 AM, 8:30 AM, 9:00 AM conflict with the job itself
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '8:00 AM - 9:30 AM'), isTrue);
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '8:30 AM - 10:00 AM'), isTrue);
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '9:00 AM - 10:30 AM'), isTrue);

      // 9:30 AM conflicts with the 30-min buffer (9:30 AM - 10:00 AM)
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '9:30 AM - 11:00 AM'), isTrue);

      // 10:00 AM is completely OPEN and AVAILABLE!
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '10:00 AM - 11:30 AM'), isFalse);
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '10:30 AM - 12:00 PM'), isFalse);

      // getAvailableStartTimesForPackage includes 10:00 AM and excludes 8:00 - 9:30 AM
      final availableStarts = repo.getAvailableStartTimesForPackage(monday, onePointFiveHourPkg);
      expect(availableStarts, contains('10:00 AM'));
      expect(availableStarts, contains('10:30 AM'));
      expect(availableStarts, isNot(contains('8:00 AM')));
      expect(availableStarts, isNot(contains('8:30 AM')));
      expect(availableStarts, isNot(contains('9:00 AM')));
      expect(availableStarts, isNot(contains('9:30 AM')));

      // Closing time protection: shop closes at 5:00 PM.
      // 3:30 PM + 90m = 5:00 PM (<= 5:00 PM -> available)
      // 4:00 PM + 90m = 5:30 PM (> 5:00 PM -> excluded)
      expect(availableStarts, contains('3:30 PM'));
      expect(availableStarts, isNot(contains('4:00 PM')));
      expect(availableStarts, isNot(contains('4:30 PM')));

      // Test buffer variation: If detailer changes buffer to 15 mins
      repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(bufferMinutesBetweenJobs: 15));
      // 10:00 AM is still open
      expect(repo.isBookingConflictingWithSlot(appt8am, monday, '10:00 AM - 11:30 AM'), isFalse);

      // Test interval math in isSlotExplicitlyBlocked:
      // Detailer blocks 8:00 AM - 10:00 AM
      repo.toggleBlockSlot(monday, '8:00 AM - 10:00 AM');
      expect(repo.isSlotExplicitlyBlocked(repo.currentUser.id, monday, '10:00 AM - 11:30 AM'), isFalse);
      expect(repo.isSlotExplicitlyBlocked(repo.currentUser.id, monday, '9:30 AM - 11:00 AM'), isTrue);

      // Verify false-positive blocking fix: blocking 10:00 AM - 11:00 AM does NOT block 8:00 AM - 8:30 AM
      final wednesday = DateTime(2026, 11, 4);
      repo.toggleBlockSlot(wednesday, '10:00 AM - 11:00 AM');
      expect(repo.isSlotExplicitlyBlocked(repo.currentUser.id, wednesday, '8:00 AM - 8:30 AM'), isFalse);
      expect(repo.isSlotExplicitlyBlocked(repo.currentUser.id, wednesday, '10:30 AM - 11:30 AM'), isTrue);

      // Verify getAvailableStartTimesForPackage respects explicit custom day overrides:
      // 1. Cleared slots override (customSlots: []) returns empty list without resurrecting default stepping
      final tuesday = DateTime(2026, 11, 3);
      repo.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'override_tues_clear',
        detailerId: repo.currentUser.id,
        date: tuesday,
        isAllDay: false,
        hasCustomSlotsOverride: true,
        customSlots: const [],
        createdAt: DateTime.now(),
      ));
      expect(repo.getAvailableStartTimesForPackage(tuesday, onePointFiveHourPkg), isEmpty);
      expect(repo.isDateFullyBlocked(repo.currentUser.id, tuesday), isTrue);

      // 2. Specific custom slots override returns ONLY custom slots without resurrecting default 30-min stepping
      final thursday = DateTime(2026, 11, 5);
      repo.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'override_thur_custom',
        detailerId: repo.currentUser.id,
        date: thursday,
        isAllDay: false,
        hasCustomSlotsOverride: true,
        customSlots: const ['10:00 AM - 12:00 PM'],
        createdAt: DateTime.now(),
      ));
      final thurStarts = repo.getAvailableStartTimesForPackage(thursday, onePointFiveHourPkg);
      expect(thurStarts, ['10:00 AM']);
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

    testWidgets('UI 7: Multi-Day 2-day work in BookingFlowScreen: switching to afternoon drop-off pushes ready date to Day 3', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
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
          id: 'v_smart_07',
          make: 'Porsche',
          model: 'Taycan Turbo S',
          year: 2024,
          colorName: 'Frozen Blue',
          imageUrl: '',
        ));

        // Monday-Friday 8:00 AM - 5:00 PM
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
          customTimeSlots: ['9:00 AM - 12:00 PM', '1:00 PM - 4:00 PM'],
        ));

        DateTime monday = DateTime.now().add(const Duration(days: 1));
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }

        final twoDayPkg = studioDetailer.servicePackages[1]; // 2 days

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: monday,
                initialPackage: twoDayPkg,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 1. Initial default is morning (9:00 AM).
        // 2-day work from Monday morning is ready Tuesday at closing (Day 2 closing)!
        final tuesday = monday.add(const Duration(days: 1));
        final expectedTuesdayStr = DateFormat('EEEE, MMMM d, yyyy').format(tuesday);
        expect(find.textContaining('Estimated Ready Date: $expectedTuesdayStr'), findsOneWidget);

        // 2. Select 1:00 PM drop-off slot (Monday afternoon)
        final chip1pm = find.widgetWithText(FilterChip, '1:00 PM');
        await tester.ensureVisible(chip1pm);
        await tester.pumpAndSettle();
        await tester.tap(chip1pm);
        await tester.pumpAndSettle();

        // 3. Since Monday afternoon drop-off has only 4h, 2 full days pushes to Wednesday 1:00 PM (Day 3)!
        final wednesday = monday.add(const Duration(days: 2));
        final expectedWednesdayStr = DateFormat('EEEE, MMMM d, yyyy').format(wednesday);
        expect(find.textContaining('Estimated Ready Date: $expectedWednesdayStr'), findsOneWidget);

        // Turnaround schedule summary card reflects Monday drop-off & Wednesday pick-up
        expect(find.textContaining('1:00 PM • Ready: ${DateFormat('EEE, MMM d').format(wednesday)} 1:00 PM'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 8: Multi-Day Calendar date tap updates Estimated Ready Date and custom pickup selection is preserved', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
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
          id: 'v_smart_08',
          make: 'BMW',
          model: 'M4 Competition',
          year: 2024,
          colorName: 'Isle of Man Green',
          imageUrl: '',
        ));

        // Monday-Friday 8:00 AM - 5:00 PM
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
          customTimeSlots: ['9:00 AM - 12:00 PM', '1:00 PM - 4:00 PM'],
        ));

        DateTime monday = DateTime.now().add(const Duration(days: 1));
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }

        final twoDayPkg = studioDetailer.servicePackages[1]; // 2 days

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: studioDetailer,
                repository: repo,
                initialDate: monday,
                initialPackage: twoDayPkg,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 1. Initial Monday drop-off is ready Tuesday
        final tuesday = monday.add(const Duration(days: 1));
        expect(find.textContaining('Estimated Ready Date: ${DateFormat('EEEE, MMMM d, yyyy').format(tuesday)}'), findsOneWidget);

        // 2. Select Tuesday in the calendar grid as the new drop-off date
        final tuesdayDayNumber = '${tuesday.day}';
        final tuesdayFinder = find.descendant(
          of: find.byType(GridView),
          matching: find.text(tuesdayDayNumber),
        ).first;
        await tester.tap(tuesdayFinder);
        await tester.pumpAndSettle();

        // 3. Estimated Ready Date must immediately update to Wednesday (Day 2 for Tuesday drop-off)
        final wednesday = tuesday.add(const Duration(days: 1));
        expect(find.textContaining('Estimated Ready Date: ${DateFormat('EEEE, MMMM d, yyyy').format(wednesday)}'), findsOneWidget);

        // 4. Drop-off in the afternoon (1:00 PM Tuesday) -> pushes to Thursday (Day 3)
        final chip1pm = find.widgetWithText(FilterChip, '1:00 PM');
        await tester.ensureVisible(chip1pm);
        await tester.pumpAndSettle();
        await tester.tap(chip1pm);
        await tester.pumpAndSettle();

        final thursday = wednesday.add(const Duration(days: 1));
        expect(find.textContaining('Estimated Ready Date: ${DateFormat('EEEE, MMMM d, yyyy').format(thursday)}'), findsOneWidget);

        // 5. Select a custom later pickup time on Thursday (3:00 PM) in Choice 2
        final chip3pm = find.widgetWithText(FilterChip, '3:00 PM').last;
        await tester.ensureVisible(chip3pm);
        await tester.pumpAndSettle();
        await tester.tap(chip3pm);
        await tester.pumpAndSettle();

        // Turnaround schedule summary card reflects Thursday 3:00 PM
        expect(find.textContaining('1:00 PM • Ready: ${DateFormat('EEE, MMM d').format(thursday)} 3:00 PM'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 9: BookingFlowScreen displays 30-min candidate slots, opens 10:00 AM when 8:00 AM-9:30 AM job + 30m buffer is booked, and marks late slots CLOSED', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
          id: 'v_smart_09',
          make: 'Porsche',
          model: '911 Carrera',
          year: 2024,
          colorName: 'GT Silver',
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
          bufferMinutesBetweenJobs: 30,
        ));

        DateTime monday = DateTime.now().add(const Duration(days: 1));
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }

        const onePointFiveHourPkg = ServicePackage(
          id: 'pkg_1_5hr_ui',
          title: 'Express Polish & Protect',
          description: '1.5 hr job',
          basePrice: 190.0,
          estimatedDuration: '1 hr 30 mins',
          durationUnit: 'hours',
          includes: ['Polish', 'Sealant'],
        );

        final detailer = studioDetailer.copyWith(
          servicePackages: [onePointFiveHourPkg],
        );

        // Add confirmed booking 8:00 AM - 9:30 AM
        repo.addBooking(BookingAppointment(
          id: 'bk_ui_8am_930am',
          detailerId: detailer.id,
          detailerName: detailer.displayName,
          detailerBusinessName: detailer.businessName,
          detailerAvatar: '',
          clientName: 'Early Client',
          clientPhone: '555-0001',
          clientEmail: 'early@test.com',
          vehicleYearMakeModel: 'Porsche Cayman',
          vehicleSize: VehicleSize.coupeSedan,
          package: onePointFiveHourPkg,
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: monday,
          scheduledTimeSlot: '8:00 AM - 9:30 AM',
          startTime: '8:00 AM',
          endTime: '9:30 AM',
          durationMinutes: 90,
          totalPrice: 190,
          depositAmount: 38,
        ));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: detailer,
                repository: repo,
                initialDate: monday,
                initialPackage: onePointFiveHourPkg,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 1 (Schedule & Vehicle)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Verify candidate slots are rendered in 30-min steps: 8:00 AM, 8:30 AM, 9:00 AM, 9:30 AM, 10:00 AM, 10:30 AM, etc.
        expect(find.text('8:00 AM'), findsOneWidget);
        expect(find.text('8:30 AM'), findsOneWidget);
        expect(find.text('9:00 AM'), findsOneWidget);
        expect(find.text('9:30 AM'), findsOneWidget);
        expect(find.text('10:00 AM'), findsOneWidget);
        expect(find.text('10:30 AM'), findsOneWidget);

        // 8:00 AM, 8:30 AM, 9:00 AM, 9:30 AM must show BOOKED
        expect(find.text('BOOKED'), findsWidgets);

        // 10:00 AM is available! Let's tap 10:00 AM
        final chip10am = find.widgetWithText(FilterChip, '10:00 AM');
        await tester.ensureVisible(chip10am);
        await tester.pumpAndSettle();
        await tester.tap(chip10am);
        await tester.pumpAndSettle();

        // Check Live Schedule Window: 10:00 AM to 11:30 AM
        expect(find.textContaining('Drop-off: 10:00 AM'), findsWidgets);
        expect(find.textContaining('Estimated Finish: 11:30 AM'), findsWidgets);

        // Closing time protection: shop closes at 5:00 PM.
        // 4:00 PM (+ 1.5h = 5:30 PM > 5:00 PM) must be marked CLOSED
        expect(find.text('CLOSED'), findsWidgets);

        // 4. Test explicit custom day cleared override (hasCustomSlotsOverride: true, customSlots: [])
        final tuesday = monday.add(const Duration(days: 1));
        repo.addAvailabilityBlock(CalendarAvailabilityBlock(
          id: 'custom_override_tuesday',
          detailerId: detailer.id,
          date: tuesday,
          isAllDay: false,
          hasCustomSlotsOverride: true,
          customSlots: const [],
          createdAt: DateTime.now(),
        ));

        // Tap Tuesday on calendar
        final tuesdayFinder = find.descendant(
          of: find.byType(GridView),
          matching: find.text('${tuesday.day}'),
        ).first;
        await tester.tap(tuesdayFinder);
        await tester.pumpAndSettle();

        // Cleared override has 0 slots, does NOT resurrect default slots!
        expect(find.byType(FilterChip), findsNothing);
        expect(find.text('No appointment slots available for this date. Please select another date.'), findsOneWidget);

        // Attempting to advance to Step 2 without a valid slot triggers error SnackBar and stays on Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('No time slots available for this date'), findsOneWidget);
        expect(find.text('Select Arrival / Start Time'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 10: CalendarPreferencesDialog includes 15 and 45 minute buffer options', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
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

      // Scroll to the buffer dropdown row
      final rowFinder = find.text('Turnaround Buffer Between Jobs');
      await tester.scrollUntilVisible(
        rowFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(rowFinder, findsOneWidget);

      final bufferFinder = find.text('30 minutes turnaround');
      expect(bufferFinder, findsOneWidget);
      await tester.tap(bufferFinder);
      await tester.pumpAndSettle();

      // Verify 15 and 45 minute options exist
      expect(find.text('15 minutes turnaround'), findsWidgets);
      expect(find.text('45 minutes turnaround'), findsWidgets);
    });

    testWidgets('UI 11: DetailerWorkbenchView Add Slot dialog respects slotDurationHours and offers 30-min increments', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = JobRepository();
      await repo.init();
      repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(
        slotDurationHours: 2,
      ));

      final testDate = DateTime(2026, 11, 2);

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

      // Navigate to Calendar section
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Tap "Add Slot" button
      final addSlotBtn = find.widgetWithText(ElevatedButton, 'Add Slot');
      expect(addSlotBtn, findsWidgets);
      await tester.tap(addSlotBtn.first);
      await tester.pumpAndSettle();

      // Verify Dialog opened
      expect(find.text('Add Booking Slot'), findsOneWidget);

      // Verify End Time computed as startTime (8:00 AM) + 2 hours (120 mins) = 10:00 AM
      expect(find.text('10:00 AM'), findsWidgets);

      // Open Start Time dropdown to verify 30-min options exist
      final startDropdown = find.text('8:00 AM');
      expect(startDropdown, findsWidgets);
      await tester.tap(startDropdown.first);
      await tester.pumpAndSettle();

      // 8:30 AM exists in the dropdown options
      expect(find.text('8:30 AM'), findsWidgets);

      // Select 8:30 AM
      await tester.tap(find.text('8:30 AM').last);
      await tester.pumpAndSettle();

      // End time automatically updates to 8:30 AM + 2 hours = 10:30 AM
      expect(find.text('10:30 AM'), findsWidgets);

      // Save slot
      final saveBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Add Slot'),
      );
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify new custom slot is saved in repository preferences
      expect(repo.calendarPreferences.customTimeSlots, contains('8:30 AM - 10:30 AM'));
    });

    testWidgets('UI 12: DetailerWorkbenchView Pane 3 Day Inspector renders exact booked appointment details and no fake overlap cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 2);
        final booking = BookingAppointment(
          id: 'bk_ui_exact_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Sarah Jenkins',
          clientPhone: '555-0199',
          clientEmail: 'sarah@example.com',
          vehicleYearMakeModel: '2024 BMW M4',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_paint_corr',
            title: 'Full Paint Correction & Ceramic',
            description: 'Paint correction',
            basePrice: 850,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: ['Wash', 'Correction', 'Ceramic'],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: '123 Main St',
          scheduledDate: testDate,
          scheduledTimeSlot: '8:00 AM - 10:00 AM',
          startTime: '8:00 AM',
          endTime: '10:00 AM',
          durationMinutes: 120,
          totalPrice: 850,
          depositAmount: 170,
        );
        repo.addBooking(booking);

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

        // Navigate to Calendar
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Verify exact booking details are rendered in Pane 3
        expect(find.text('8:00 AM - 10:00 AM'), findsWidgets);
        expect(find.text('Booked by Sarah Jenkins'), findsOneWidget);
        expect(find.textContaining('2024 BMW M4 • Full Paint Correction & Ceramic • \$850'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Cancel Booking'), findsOneWidget);

        // Verify absence of obsolete 3-hour template grid overlap warnings
        expect(find.textContaining('Overlaps with'), findsNothing);
        expect(find.textContaining('Reserved •'), findsNothing);

        // Verify Available for Booking card is also visible
        expect(find.text('Available for Booking'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 13: Cancelling an appointment from Workbench releases slot immediately in calendar and repository', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 2);
        final booking = BookingAppointment(
          id: 'bk_ui_cancel_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Sarah Jenkins',
          clientPhone: '555-0199',
          clientEmail: 'sarah@example.com',
          vehicleYearMakeModel: '2024 BMW M4',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_paint_corr',
            title: 'Full Paint Correction & Ceramic',
            description: 'Paint correction',
            basePrice: 850,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: ['Wash', 'Correction', 'Ceramic'],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: '123 Main St',
          scheduledDate: testDate,
          scheduledTimeSlot: '8:00 AM - 10:00 AM',
          startTime: '8:00 AM',
          endTime: '10:00 AM',
          durationMinutes: 120,
          totalPrice: 850,
          depositAmount: 170,
        );
        repo.addBooking(booking);

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Ensure booking is initially visible
        expect(find.text('Booked by Sarah Jenkins'), findsOneWidget);
        expect(repo.isBookingConflictingWithSlot(booking, testDate, '8:00 AM - 10:00 AM'), isTrue);

        // Tap Cancel Booking button
        final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel Booking');
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Cancel Booking?'), findsOneWidget);
        final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Cancellation');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Booking is removed from Calendar Inspector
        expect(find.text('Booked by Sarah Jenkins'), findsNothing);

        // Slot is immediately released in repository
        final updatedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_ui_cancel_01');
        expect(updatedBooking.status, BookingStatus.cancelled);
        expect(repo.isBookingConflictingWithSlot(updatedBooking, testDate, '8:00 AM - 10:00 AM'), isFalse);
        expect(repo.getBookingsForDate(testDate).where((b) => b.id == 'bk_ui_cancel_01'), isEmpty);

        // Available status card remains available for new bookings
        expect(find.text('Available for Booking'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 14: DetailerWorkbenchView blocks 30-minute interval with custom reason and reopens slot', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 3);

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Tap Block Slot button
        final blockSlotBtn = find.widgetWithText(ElevatedButton, 'Block Slot').first;
        expect(blockSlotBtn, findsOneWidget);
        await tester.tap(blockSlotBtn);
        await tester.pumpAndSettle();

        // Block Time Window dialog opens
        expect(find.text('Block Time Window'), findsOneWidget);
        expect(find.text('30 mins'), findsWidgets);

        // Enter custom reason
        final reasonField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        expect(reasonField, findsOneWidget);
        await tester.enterText(reasonField, 'Equipment maintenance');
        await tester.pumpAndSettle();

        // Tap Block Slot in dialog
        final confirmBlockBtn = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Block Slot'),
        );
        await tester.tap(confirmBlockBtn);
        await tester.pumpAndSettle();

        // Blocked slot card is displayed in Pane 3
        expect(find.text('Blocked by Detailer (Equipment maintenance)'), findsOneWidget);
        expect(find.text('8:00 AM - 8:30 AM'), findsWidgets);
        final reopenBtn = find.widgetWithText(OutlinedButton, 'Reopen');
        expect(reopenBtn, findsOneWidget);

        // Verify slot is blocked in repository
        expect(repo.isSlotBlocked(repo.currentUser.id, testDate, '8:00 AM - 8:30 AM'), isTrue);

        // Tap Reopen to unblock
        await tester.tap(reopenBtn);
        await tester.pumpAndSettle();

        // Blocked card is removed and slot is reopened
        expect(find.text('Blocked by Detailer (Equipment maintenance)'), findsNothing);
        expect(repo.isSlotBlocked(repo.currentUser.id, testDate, '8:00 AM - 8:30 AM'), isFalse);
        expect(find.text('Available for Booking'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 15: DetailerWorkbenchView team member filtering isolates tech schedule while studio owner sees all', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        const tech1 = TeamMember(
          id: 'tech_dave',
          name: 'Dave Miller',
          roleTitle: 'PPF Specialist',
          avatarUrl: '',
        );
        const tech2 = TeamMember(
          id: 'tech_elena',
          name: 'Elena Rostova',
          roleTitle: 'Ceramic Specialist',
          avatarUrl: '',
        );
        repo.addTeamMember(tech1);
        repo.addTeamMember(tech2);

        final testDate = DateTime(2026, 11, 4);

        // Dave's booking: 8:00 AM - 10:00 AM
        final daveBooking = BookingAppointment(
          id: 'bk_dave_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Dave Client',
          clientPhone: '555-1111',
          clientEmail: 'daveclient@test.com',
          vehicleYearMakeModel: '2023 Tesla Model S',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_ppf',
            title: 'Full Front PPF',
            description: 'PPF',
            basePrice: 600,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: [],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: testDate,
          scheduledTimeSlot: '8:00 AM - 10:00 AM',
          startTime: '8:00 AM',
          endTime: '10:00 AM',
          durationMinutes: 120,
          totalPrice: 600,
          depositAmount: 120,
          assignedTeamMemberId: tech1.id,
          assignedTeamMemberName: tech1.name,
        );
        repo.addBooking(daveBooking);

        // Elena's booking: 11:00 AM - 1:00 PM
        final elenaBooking = BookingAppointment(
          id: 'bk_elena_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Elena Client',
          clientPhone: '555-2222',
          clientEmail: 'elenaclient@test.com',
          vehicleYearMakeModel: '2024 Porsche 911',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_cer',
            title: 'Ceramic Pro',
            description: 'Ceramic',
            basePrice: 900,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: [],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: testDate,
          scheduledTimeSlot: '11:00 AM - 1:00 PM',
          startTime: '11:00 AM',
          endTime: '1:00 PM',
          durationMinutes: 120,
          totalPrice: 900,
          depositAmount: 180,
          assignedTeamMemberId: tech2.id,
          assignedTeamMemberName: tech2.name,
        );
        repo.addBooking(elenaBooking);

        // Elena's blocked window: 2:00 PM - 3:00 PM
        repo.toggleBlockSlot(
          testDate,
          '2:00 PM - 3:00 PM',
          reason: 'Elena Training',
          teamMemberId: tech2.id,
          detailerId: repo.currentUser.id,
        );

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // 1. Studio Owner Master View ('all'):
        // Shows general title
        expect(find.text('HOURLY SLOT AVAILABILITY'), findsOneWidget);

        // Sees both Dave's and Elena's appointments with assigned tech badges
        expect(find.text('Booked by Dave Client'), findsOneWidget);
        expect(find.text('Assigned: Dave Miller'), findsOneWidget);
        expect(find.text('Booked by Elena Client'), findsOneWidget);
        expect(find.text('Assigned: Elena Rostova'), findsOneWidget);

        // Sees Elena's blocked slot with tech badge
        expect(find.text('Blocked by Detailer (Elena Training)'), findsOneWidget);
        expect(find.text('Assigned Tech: Elena Rostova'), findsOneWidget);

        // 2. Switch calendar filter to Elena Rostova
        final dropdownFinder = find.byKey(const Key('calendar_team_dropdown_pane3'));
        expect(dropdownFinder, findsOneWidget);
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Select Elena from dropdown items
        final elenaOption = find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('Elena Rostova')).first;
        await tester.tap(elenaOption);
        await tester.pumpAndSettle();

        // Section 1 title now isolates Elena's availability
        expect(find.text("ELENA ROSTOVA'S AVAILABILITY"), findsOneWidget);

        // Only Elena's schedule is shown; Dave's booking is filtered out
        expect(find.text('Booked by Elena Client'), findsOneWidget);
        expect(find.text('Booked by Dave Client'), findsNothing);
        expect(find.text('Blocked by Detailer (Elena Training)'), findsOneWidget);

        // Personal Schedule banner is present with Back to All Team button
        expect(find.text('Back to All Team'), findsOneWidget);

        // Tap 'Back to All Team' to return to Owner Master View
        await tester.tap(find.text('Back to All Team'));
        await tester.pumpAndSettle();

        // Master studio view restored
        expect(find.text('HOURLY SLOT AVAILABILITY'), findsOneWidget);
        expect(find.text('Booked by Dave Client'), findsOneWidget);
        expect(find.text('Booked by Elena Client'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 16: DetailerWorkbenchView displays smart bookings and blocked windows even when daySlots is empty', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 5);

        // Add a smart booking
        final booking = BookingAppointment(
          id: 'bk_smart_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Smart Client',
          clientPhone: '555-3333',
          clientEmail: 'smart@test.com',
          vehicleYearMakeModel: '2024 BMW M3',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_smart',
            title: 'Express Detail',
            description: 'Express',
            basePrice: 150,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: [],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: testDate,
          scheduledTimeSlot: '8:00 AM - 10:00 AM',
          startTime: '8:00 AM',
          endTime: '10:00 AM',
          durationMinutes: 120,
          totalPrice: 150,
          depositAmount: 30,
        );
        repo.addBooking(booking);

        // Explicitly clear legacy arrival window slots for this day
        repo.clearTimeSlotsForDate(testDate, detailerId: repo.currentUser.id);
        expect(repo.getTimeSlotsForDate(testDate, detailerId: repo.currentUser.id).isEmpty, isTrue);

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Booking is NOT swallowed or hidden by the empty template slots
        expect(find.text('Booked by Smart Client'), findsOneWidget);
        expect(find.text('8:00 AM - 10:00 AM'), findsOneWidget);
        expect(find.text('Day Blocked by Detailer'), findsOneWidget);
        expect(find.text('No slots defined for this day.'), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 17: 30-minute block dialog strictly clamps quick duration chips to closing time and restricts operating hours', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 6);

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Tap Block Slot
        final blockSlotBtn = find.widgetWithText(ElevatedButton, 'Block Slot').first;
        await tester.tap(blockSlotBtn);
        await tester.pumpAndSettle();

        expect(find.text('Block Time Window'), findsOneWidget);

        // Select Start Time dropdown
        final startTimeDropdown = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButton<String>),
        ).first;
        await tester.tap(startTimeDropdown);
        await tester.pumpAndSettle();

        // Select 5:00 PM as Start Time (shop closes at 6:00 PM)
        final fivePmOption = find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('5:00 PM')).last;
        await tester.tap(fivePmOption);
        await tester.pumpAndSettle();

        // Tap "2 hours" quick duration chip
        final twoHoursChip = find.descendant(of: find.byType(AlertDialog), matching: find.text('2 hours'));
        expect(twoHoursChip, findsOneWidget);
        await tester.tap(twoHoursChip);
        await tester.pumpAndSettle();

        // Verify End Time dropdown clamped strictly to shop closing time (6:00 PM)
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('6:00 PM')), findsWidgets);

        // Confirm Block Slot
        final confirmBtn = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(ElevatedButton, 'Block Slot'));
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Blocked slot rendered as 5:00 PM - 6:00 PM
        expect(find.text('5:00 PM - 6:00 PM'), findsOneWidget);
        expect(find.text('Blocked by Detailer'), findsOneWidget);
        expect(repo.isSlotBlocked(repo.currentUser.id, testDate, '5:00 PM - 6:00 PM'), isTrue);

        // Reopen slot
        final reopenBtn = find.widgetWithText(OutlinedButton, 'Reopen');
        await tester.tap(reopenBtn);
        await tester.pumpAndSettle();
        expect(find.text('5:00 PM - 6:00 PM'), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI 18: Confirmed bookings remain visible and actionable on full-day blocked dates', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final repo = JobRepository();
        await repo.init();
        if (repo.currentUser.role != UserRole.detailer) {
          repo.toggleHostMode();
        }
        final openSchedule = repo.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM')).toList();
        repo.updateCalendarPreferences(repo.calendarPreferences.copyWith(weeklySchedule: openSchedule));

        final testDate = DateTime(2026, 11, 7);

        // Add confirmed booking: 1:00 PM - 3:00 PM
        final booking = BookingAppointment(
          id: 'bk_conflict_01',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Reserved Client',
          clientPhone: '555-4444',
          clientEmail: 'reserved@test.com',
          vehicleYearMakeModel: '2022 Audi RS6',
          vehicleSize: VehicleSize.coupeSedan,
          package: const ServicePackage(
            id: 'pkg_res',
            title: 'Maintenance Wash',
            description: 'Wash',
            basePrice: 120,
            estimatedDuration: '2 hours',
            durationValue: 2,
            durationUnit: 'hours',
            includes: [],
          ),
          locationType: ServiceLocationType.shop,
          clientAddress: 'Studio',
          scheduledDate: testDate,
          scheduledTimeSlot: '1:00 PM - 3:00 PM',
          startTime: '1:00 PM',
          endTime: '3:00 PM',
          durationMinutes: 120,
          totalPrice: 120,
          depositAmount: 24,
        );
        repo.addBooking(booking);

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

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Tap Block Full Day
        final blockFullDayBtn = find.text('Block Full Day');
        expect(blockFullDayBtn, findsOneWidget);
        await tester.tap(blockFullDayBtn);
        await tester.pumpAndSettle();

        // Both the Day Blocked banner AND the confirmed booking are visible!
        expect(find.text('DAY BLOCKED'), findsOneWidget);
        expect(find.text('Day Blocked by Detailer'), findsOneWidget);
        expect(find.text('Booked by Reserved Client'), findsOneWidget);
        expect(find.text('1:00 PM - 3:00 PM'), findsOneWidget);

        // Cancel the booking directly from the blocked day view
        final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel Booking');
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // Confirm cancellation in dialog
        final confirmCancelBtn = find.text('Confirm Cancellation');
        expect(confirmCancelBtn, findsOneWidget);
        await tester.tap(confirmCancelBtn);
        await tester.pumpAndSettle();

        // Booking is removed from schedule immediately
        expect(find.text('Booked by Reserved Client'), findsNothing);
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_conflict_01').status, BookingStatus.cancelled);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    test('UI 19: CalendarAvailabilityBlock Supabase snake_case & camelCase bidirectional compatibility', () {
      final block = CalendarAvailabilityBlock(
        id: 'block_test_cloud',
        detailerId: 'usr_det_99',
        teamMemberId: 'tech_01',
        date: DateTime(2026, 11, 15),
        isAllDay: false,
        blockedSlots: ['10:00 AM - 11:30 AM'],
        customSlots: ['12:00 PM - 1:00 PM'],
        hasCustomSlotsOverride: true,
        reason: 'Staff Lunch',
        createdAt: DateTime(2026, 10, 31, 12, 0, 0),
      );

      // Verify toSupabase() produces valid snake_case payload for Postgres
      final supabaseMap = block.toSupabase();
      expect(supabaseMap['id'], 'block_test_cloud');
      expect(supabaseMap['detailer_id'], 'usr_det_99');
      expect(supabaseMap['team_member_id'], 'tech_01');
      expect(supabaseMap['is_all_day'], isFalse);
      expect(supabaseMap['blocked_slots'], ['10:00 AM - 11:30 AM']);
      expect(supabaseMap['custom_slots'], ['12:00 PM - 1:00 PM']);
      expect(supabaseMap['has_custom_slots_override'], isTrue);
      expect(supabaseMap['reason'], 'Staff Lunch');

      // Verify fromJson() deserializes snake_case seamlessly
      final fromSnake = CalendarAvailabilityBlock.fromJson(supabaseMap);
      expect(fromSnake.id, 'block_test_cloud');
      expect(fromSnake.detailerId, 'usr_det_99');
      expect(fromSnake.teamMemberId, 'tech_01');
      expect(fromSnake.isAllDay, isFalse);
      expect(fromSnake.blockedSlots, ['10:00 AM - 11:30 AM']);
      expect(fromSnake.customSlots, ['12:00 PM - 1:00 PM']);
      expect(fromSnake.hasCustomSlotsOverride, isTrue);
      expect(fromSnake.reason, 'Staff Lunch');

      // Verify fromJson() deserializes camelCase local storage seamlessly
      final localJson = block.toJson();
      final fromCamel = CalendarAvailabilityBlock.fromJson(localJson);
      expect(fromCamel.id, 'block_test_cloud');
      expect(fromCamel.detailerId, 'usr_det_99');
      expect(fromCamel.teamMemberId, 'tech_01');
      expect(fromCamel.isAllDay, isFalse);
      expect(fromCamel.blockedSlots, ['10:00 AM - 11:30 AM']);
    });

    test('UI 20: toggleBlockSlot and toggleBlockDay update memory and allow cloud sync trigger', () async {
      final repo = JobRepository();
      final date = DateTime(2026, 11, 20);

      expect(repo.getBlocksForDate(date).isEmpty, isTrue);

      // Block a 30-min slot
      repo.toggleBlockSlot(date, '1:00 PM - 1:30 PM', reason: 'Oil Change Break');
      final blocksAfterSlot = repo.getBlocksForDate(date);
      expect(blocksAfterSlot.length, 1);
      expect(blocksAfterSlot.first.blockedSlots, contains('1:00 PM - 1:30 PM'));
      expect(blocksAfterSlot.first.reason, 'Oil Change Break');

      // Toggle off the slot
      repo.toggleBlockSlot(date, '1:00 PM - 1:30 PM');
      expect(repo.getBlocksForDate(date).isEmpty, isTrue);

      // Block entire day
      repo.toggleBlockDay(date, reason: 'Holiday Closed');
      final blocksAfterDay = repo.getBlocksForDate(date);
      expect(blocksAfterDay.length, 1);
      expect(blocksAfterDay.first.isAllDay, isTrue);
      expect(blocksAfterDay.first.reason, 'Holiday Closed');

      // Toggle off full day
      repo.toggleBlockDay(date);
      expect(repo.getBlocksForDate(date).isEmpty, isTrue);
    });
  });
}
