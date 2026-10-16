import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3: Calendar Operating Hours & Day Blocks Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('C1: Detailer calendar preferences survive simulated browser refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final customSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '07:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '07:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '07:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '07:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '07:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      final customPrefs = DetailerCalendarPreferences(
        weeklySchedule: customSchedule,
        advanceNoticeHours: 12,
        bufferMinutesBetweenJobs: 45,
        maxAdvanceBookingDays: 90,
        autoConfirmBookings: false,
        slotDurationHours: 4,
        customTimeSlots: const [
          '7:00 AM - 11:00 AM',
          '11:45 AM - 3:45 PM',
          '4:30 PM - 8:30 PM',
        ],
      );

      await repo1.saveDetailerCalendarPreferences(customPrefs);

      // Verify dedicated storage contains updated preferences immediately
      final dedicated = await LocalStorageService.loadDetailerCalendarPreferences(detailerId: repo1.currentUser.id);
      expect(dedicated, isNotNull);
      expect(dedicated!.advanceNoticeHours, equals(12));
      expect(dedicated.slotDurationHours, equals(4));
      expect(dedicated.autoConfirmBookings, isFalse);
      expect(dedicated.customTimeSlots.length, equals(3));
      expect(dedicated.weeklySchedule[0].openTime, equals('07:00 AM'));

      // Simulate browser refresh (Cmd+R)
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);

      expect(repo2.calendarPreferences.advanceNoticeHours, equals(12));
      expect(repo2.calendarPreferences.bufferMinutesBetweenJobs, equals(45));
      expect(repo2.calendarPreferences.maxAdvanceBookingDays, equals(90));
      expect(repo2.calendarPreferences.autoConfirmBookings, isFalse);
      expect(repo2.calendarPreferences.slotDurationHours, equals(4));
      expect(repo2.calendarPreferences.customTimeSlots, equals(customPrefs.customTimeSlots));
      expect(repo2.calendarPreferences.weeklySchedule[0].openTime, equals('07:00 AM'));
      expect(repo2.calendarPreferences.weeklySchedule[6].isOpen, isFalse);
    });

    test('C2: Studio-wide day block persists and survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      final targetDate = DateTime(2026, 11, 20);

      repo1.toggleBlockDay(targetDate, reason: 'Shop renovation closure');
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate), isTrue);

      // Verify dedicated storage
      final dedicated = await LocalStorageService.loadCalendarBlocks();
      expect(dedicated.length, equals(1));
      expect(dedicated.first.date.year, equals(2026));
      expect(dedicated.first.date.month, equals(11));
      expect(dedicated.first.date.day, equals(20));
      expect(dedicated.first.isAllDay, isTrue);
      expect(dedicated.first.reason, equals('Shop renovation closure'));

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, targetDate), isTrue);
      expect(repo2.availabilityBlocks.length, equals(1));
      expect(repo2.availabilityBlocks.first.reason, equals('Shop renovation closure'));
    });

    test('C3: Multi-tech independent day blocks coexist without overwriting each other', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      final targetDate = DateTime(2026, 10, 25);

      // Add 2 team members
      repo1.addTeamMember(const TeamMember(id: 'tm_carlos', name: 'Carlos M.', roleTitle: 'Specialist', avatarUrl: ''));
      repo1.addTeamMember(const TeamMember(id: 'tm_elena', name: 'Elena R.', roleTitle: 'Specialist', avatarUrl: ''));

      // Block Carlos on Oct 25
      repo1.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_carlos_25',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tm_carlos',
        date: targetDate,
        isAllDay: true,
        reason: 'Offsite certification',
        createdAt: DateTime.now(),
      ));

      // Block Elena on Oct 25
      repo1.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_elena_25',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tm_elena',
        date: targetDate,
        isAllDay: true,
        reason: 'Personal time off',
        createdAt: DateTime.now(),
      ));

      // Both blocks must exist simultaneously (critical multi-tech bug fix!)
      expect(repo1.availabilityBlocks.length, equals(2));
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate, teamMemberId: 'tm_carlos'), isTrue);
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate, teamMemberId: 'tm_elena'), isTrue);

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.availabilityBlocks.length, equals(2));
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, targetDate, teamMemberId: 'tm_carlos'), isTrue);
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, targetDate, teamMemberId: 'tm_elena'), isTrue);
    });

    test('C4: Auto-generating time slots updates preferences and survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      repo1.autoGenerateTimeSlots(
        openTime: '08:00 AM',
        closeTime: '08:00 PM',
        slotDurationHours: 4,
      );

      final expectedSlots = [
        '8:00 AM - 12:00 PM',
        '12:00 PM - 4:00 PM',
        '4:00 PM - 8:00 PM',
      ];
      expect(repo1.calendarPreferences.customTimeSlots, equals(expectedSlots));
      expect(repo1.calendarPreferences.slotDurationHours, equals(4));

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.calendarPreferences.customTimeSlots, equals(expectedSlots));
      expect(repo2.calendarPreferences.slotDurationHours, equals(4));
    });

    test('C5: Date-specific custom slots override schedule defaults and survive reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      final highDemandDate = DateTime(2026, 11, 28);

      repo1.addCustomTimeSlot('6:00 AM - 9:00 AM', specificDate: highDemandDate);
      repo1.addCustomTimeSlot('9:00 PM - 12:00 AM', specificDate: highDemandDate);

      final slotsForDate = repo1.getTimeSlotsForDate(highDemandDate);
      expect(slotsForDate, containsAll(['6:00 AM - 9:00 AM', '9:00 PM - 12:00 AM']));

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      final restoredSlots = repo2.getTimeSlotsForDate(highDemandDate);
      expect(restoredSlots, containsAll(['6:00 AM - 9:00 AM', '9:00 PM - 12:00 AM']));
    });
  });
}
