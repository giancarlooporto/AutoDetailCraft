import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M2: My Teams Staff & Schedule Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1: Add team member with customWeeklySchedule and localAvatarBytes survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      expect(repo1.currentUser.teamMembers, isEmpty);

      final avatarBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02]);
      final customSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false), // Tuesday off
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '09:00 AM', closeTime: '02:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false), // Sunday off
      ];

      final member = TeamMember(
        id: 'staff_mateo_01',
        name: 'Mateo Rossi',
        roleTitle: 'PPF & Ceramic Lead',
        avatarUrl: 'https://images.unsplash.com/photo-test',
        localAvatarBytes: avatarBytes,
        customWeeklySchedule: customSchedule,
      );

      // Add team member
      repo1.addTeamMember(member);
      expect(repo1.currentUser.teamMembers.length, 1);
      expect(repo1.currentUser.teamMembers.first.id, 'staff_mateo_01');

      // Verify dedicated storage contains member
      final dedicated = await LocalStorageService.loadTeamMembers();
      expect(dedicated.length, 1);
      expect(dedicated.first.id, 'staff_mateo_01');
      expect(dedicated.first.name, 'Mateo Rossi');
      expect(dedicated.first.localAvatarBytes, equals(avatarBytes));
      expect(dedicated.first.customWeeklySchedule, isNotNull);
      expect(dedicated.first.customWeeklySchedule![1].isOpen, isFalse);

      // Simulate browser refresh (Cmd+R)
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.teamMembers.length, 1);
      final restored = repo2.currentUser.teamMembers.first;
      expect(restored.id, 'staff_mateo_01');
      expect(restored.name, 'Mateo Rossi');
      expect(restored.roleTitle, 'PPF & Ceramic Lead');
      expect(restored.localAvatarBytes, equals(avatarBytes));
      expect(restored.customWeeklySchedule, isNotNull);
      expect(restored.customWeeklySchedule!.length, 7);
      expect(restored.customWeeklySchedule![1].isOpen, isFalse); // Tuesday off persisted!
    });

    test('T2: updateTeamMemberWeeklySchedule persists immediately and survives refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const member = TeamMember(
        id: 'staff_elena_02',
        name: 'Elena Rostova',
        roleTitle: 'Interior Specialist',
        avatarUrl: '',
      );
      repo1.addTeamMember(member);
      expect(repo1.currentUser.teamMembers.first.customWeeklySchedule, isNull);

      final updatedShifts = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: false), // Monday off
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '09:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      // Update shift schedule
      repo1.updateTeamMemberWeeklySchedule('staff_elena_02', updatedShifts);

      // Verify dedicated storage has updated schedule immediately
      final dedicated = await LocalStorageService.loadTeamMembers();
      final dedicatedElena = dedicated.firstWhere((m) => m.id == 'staff_elena_02');
      expect(dedicatedElena.customWeeklySchedule, isNotNull);
      expect(dedicatedElena.customWeeklySchedule![0].isOpen, isFalse);
      expect(dedicatedElena.customWeeklySchedule![1].openTime, '10:00 AM');

      // Refresh simulation
      final repo2 = JobRepository();
      await repo2.init();

      final restored = repo2.currentUser.teamMembers.firstWhere((m) => m.id == 'staff_elena_02');
      expect(restored.customWeeklySchedule, isNotNull);
      expect(restored.customWeeklySchedule![0].isOpen, isFalse);
      expect(restored.customWeeklySchedule![1].openTime, '10:00 AM');
      expect(restored.customWeeklySchedule![1].closeTime, '07:00 PM');
    });

    test('T3: updateTeamMember and removeTeamMember update dedicated storage and survive refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const m1 = TeamMember(id: 'tm_1', name: 'Tech 1', roleTitle: 'Apprentice Detailer', avatarUrl: '');
      const m2 = TeamMember(id: 'tm_2', name: 'Tech 2', roleTitle: 'Lead Detailer', avatarUrl: '');
      repo1.addTeamMember(m1);
      repo1.addTeamMember(m2);
      expect(repo1.currentUser.teamMembers.length, 2);

      // Update m1 role
      final updatedM1 = m1.copyWith(roleTitle: 'Ceramic Coating Tech', completedJobsCount: 15);
      repo1.updateTeamMember(updatedM1);

      // Remove m2
      repo1.removeTeamMember('tm_2');
      expect(repo1.currentUser.teamMembers.length, 1);
      expect(repo1.currentUser.teamMembers.first.roleTitle, 'Ceramic Coating Tech');

      // Refresh simulation
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.teamMembers.length, 1);
      expect(repo2.currentUser.teamMembers.first.id, 'tm_1');
      expect(repo2.currentUser.teamMembers.first.roleTitle, 'Ceramic Coating Tech');
      expect(repo2.currentUser.teamMembers.first.completedJobsCount, 15);
    });

    test('T4: Cloud refresh non-destructive merge preserves local team members', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const localStaff = TeamMember(
        id: 'tm_local_specialist',
        name: 'Jordan Sparks',
        roleTitle: 'Master Detailer',
        avatarUrl: '',
      );
      repo1.addTeamMember(localStaff);
      expect(repo1.currentUser.teamMembers.any((m) => m.id == 'tm_local_specialist'), isTrue);

      // Refresh simulation where cloud returns empty team list
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.teamMembers.any((m) => m.id == 'tm_local_specialist'), isTrue);
      expect(repo2.currentUser.teamMembers.first.name, 'Jordan Sparks');
    });

    test('T5: Multi-tech capacity check (getSlotStaffingStatus) with technician schedules and technician assignment persistence', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // Studio has Founder + Carlos
      // Setup Carlos off on Tuesdays
      final carlosSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false), // OFF Tuesday
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '09:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      final carlos = TeamMember(
        id: 'tech_carlos',
        name: 'Carlos Ruiz',
        roleTitle: 'Paint Correction Specialist',
        avatarUrl: '',
        customWeeklySchedule: carlosSchedule,
      );
      repo1.addTeamMember(carlos);

      // Pick next Tuesday and Wednesday
      DateTime nextTuesday = DateTime.now();
      while (nextTuesday.weekday != DateTime.tuesday) {
        nextTuesday = nextTuesday.add(const Duration(days: 1));
      }
      final tuesdayDate = DateTime(nextTuesday.year, nextTuesday.month, nextTuesday.day);

      DateTime nextWednesday = DateTime.now();
      while (nextWednesday.weekday != DateTime.wednesday) {
        nextWednesday = nextWednesday.add(const Duration(days: 1));
      }
      final wednesdayDate = DateTime(nextWednesday.year, nextWednesday.month, nextWednesday.day);

      // On Tuesday: Carlos is off duty. Only Founder is on duty.
      final tuesdayStatus = repo1.getSlotStaffingStatus(tuesdayDate, '10:00 AM');
      expect(tuesdayStatus.onDutyCount, equals(1));
      expect(tuesdayStatus.availableCapacity, equals(1));
      expect(tuesdayStatus.isFullyBooked, isFalse);
      expect(repo1.isMemberOnDutyOnDate('tech_carlos', tuesdayDate), isFalse);

      // On Wednesday: Both Founder and Carlos are on duty.
      final wednesdayStatus = repo1.getSlotStaffingStatus(wednesdayDate, '10:00 AM');
      expect(wednesdayStatus.onDutyCount, equals(2));
      expect(wednesdayStatus.availableCapacity, equals(2));
      expect(wednesdayStatus.isFullyBooked, isFalse);
      expect(repo1.isMemberOnDutyOnDate('tech_carlos', wednesdayDate), isTrue);

      // 1. Add first booking on Wednesday 10:00 AM
      final booking1 = BookingAppointment(
        id: 'bk_wed_01',
        detailerId: repo1.currentUser.id,
        detailerName: repo1.currentUser.displayName,
        detailerBusinessName: repo1.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Alice Walker',
        clientPhone: '555-0101',
        clientEmail: 'alice@example.com',
        vehicleYearMakeModel: '2024 Porsche Taycan',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo1.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: wednesdayDate,
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
      );
      repo1.addBooking(booking1);

      // Assign booking1 to tech_carlos
      repo1.assignBookingTechnician('bk_wed_01', 'tech_carlos', 'Carlos Ruiz');

      // Verify Wednesday status with 1 active booking
      final wedStatusAfter1 = repo1.getSlotStaffingStatus(wednesdayDate, '10:00 AM');
      expect(wedStatusAfter1.activeBookingsCount, equals(1));
      expect(wedStatusAfter1.availableCapacity, equals(1));
      expect(wedStatusAfter1.isFullyBooked, isFalse);

      // Refresh simulation: Technician assignment must survive reload
      final repo2 = JobRepository();
      await repo2.init();

      final restoredBooking1 = repo2.bookings.firstWhere((b) => b.id == 'bk_wed_01');
      expect(restoredBooking1.assignedTeamMemberId, 'tech_carlos');
      expect(restoredBooking1.assignedTeamMemberName, 'Carlos Ruiz');

      // 2. Add second booking on Wednesday 10:00 AM (exhausting capacity)
      final booking2 = BookingAppointment(
        id: 'bk_wed_02',
        detailerId: repo2.currentUser.id,
        detailerName: repo2.currentUser.displayName,
        detailerBusinessName: repo2.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Bob Miller',
        clientPhone: '555-0102',
        clientEmail: 'bob@example.com',
        vehicleYearMakeModel: '2023 BMW M3',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo2.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: wednesdayDate,
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
      );
      repo2.addBooking(booking2);

      // Now 2 active bookings out of 2 on-duty techs -> Slot is FULLY BOOKED
      final wedStatusAfter2 = repo2.getSlotStaffingStatus(wednesdayDate, '10:00 AM');
      expect(wedStatusAfter2.activeBookingsCount, equals(2));
      expect(wedStatusAfter2.availableCapacity, equals(0));
      expect(wedStatusAfter2.isFullyBooked, isTrue);

      // Repository conflict check confirms slot is conflicted across entire studio
      expect(repo2.isSlotConflictedByBooking(wednesdayDate, '10:00 AM'), isTrue);
    });
  });
}
