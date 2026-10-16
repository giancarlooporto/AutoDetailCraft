import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3 Challenger: Bookings, Slot Lockout & Race Conditions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 1. DOUBLE-BOOKING & CONCURRENCY RACE STRESS
    // ──────────────────────────────────────────────────────────────────────────

    group('1. Double-Booking & Concurrency Race Stress', () {
      test('1.1 Concurrent asynchronous addBooking calls targeting same tech and slot: exactly 1 succeeds', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        // Add a specialist technician to the studio
        repo.addTeamMember(const TeamMember(
          id: 'tm_expert_dave',
          name: 'Dave Vance',
          roleTitle: 'Paint Correction Lead',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 20);
        const slot = '10:00 AM - 2:00 PM';

        final bookingA = BookingAppointment(
          id: 'booking_race_a',
          clientId: 'client_alpha',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Alice Alpha',
          clientPhone: '(512) 555-1001',
          clientEmail: 'alice@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1500.0,
          depositAmount: 400.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_expert_dave',
          assignedTeamMemberName: 'Dave Vance',
        );

        final bookingB = BookingAppointment(
          id: 'booking_race_b',
          clientId: 'client_beta',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Bob Beta',
          clientPhone: '(512) 555-1002',
          clientEmail: 'bob@example.com',
          vehicleYearMakeModel: '2023 Ferrari 296 GTB',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1500.0,
          depositAmount: 400.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_expert_dave',
          assignedTeamMemberName: 'Dave Vance',
        );

        // Simulate concurrent execution via Future.wait
        final results = await Future.wait([
          Future(() => repo.addBooking(bookingA)),
          Future(() => repo.addBooking(bookingB)),
        ]);

        // Exactly one should succeed and one must be rejected
        final successCount = results.where((r) => r == true).length;
        final failureCount = results.where((r) => r == false).length;

        expect(successCount, equals(1), reason: 'Exactly one concurrent booking must succeed');
        expect(failureCount, equals(1), reason: 'The competing booking must be safely rejected');

        // Verify repository state: only 1 booking exists for that slot & tech
        final matchingBookings = repo.bookings.where((b) =>
            b.scheduledDate == date &&
            b.scheduledTimeSlot == slot &&
            b.assignedTeamMemberId == 'tm_expert_dave' &&
            b.status != BookingStatus.cancelled).toList();

        expect(matchingBookings.length, equals(1));

        // Verify local storage reflects only 1 booking
        final stored = await LocalStorageService.loadBookings();
        expect(stored, isNotNull);
        final storedMatching = stored!.where((b) =>
            b.scheduledDate == date &&
            b.scheduledTimeSlot == slot &&
            b.assignedTeamMemberId == 'tm_expert_dave' &&
            b.status != BookingStatus.cancelled).toList();
        expect(storedMatching.length, equals(1));
      });

      test('1.2 Specialist capacity limit lockout: rejects additional bookings when capacity reached unless allowOverbooking: true', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        // Studio has Founder + 2 technicians = 3 total specialists
        repo.addTeamMember(const TeamMember(
          id: 'tm_sarah',
          name: 'Sarah Connor',
          roleTitle: 'Detailer',
          avatarUrl: '',
        ));
        repo.addTeamMember(const TeamMember(
          id: 'tm_kyle',
          name: 'Kyle Reese',
          roleTitle: 'Detailer',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 19);
        const slot = '1:00 PM - 5:00 PM';

        // Check initial capacity
        var status = repo.getSlotStaffingStatus(date, slot);
        expect(status.onDutyCount, equals(3), reason: 'Founder + 2 team members on duty');
        expect(status.availableCapacity, equals(3));
        expect(status.isFullyBooked, isFalse);

        // Fill capacity: Book 1
        final b1 = BookingAppointment(
          id: 'booking_cap_1',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client 1',
          clientPhone: '555-0001',
          clientEmail: 'c1@example.com',
          vehicleYearMakeModel: 'Car 1',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );
        expect(repo.addBooking(b1), isTrue);

        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(2));
        expect(status.isFullyBooked, isFalse);

        // Book 2
        final b2 = b1.copyWith(id: 'booking_cap_2', clientName: 'Client 2');
        expect(repo.addBooking(b2), isTrue);

        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(1));
        expect(status.isFullyBooked, isFalse);

        // Book 3: Reaches full capacity (3 of 3 booked)
        final b3 = b1.copyWith(id: 'booking_cap_3', clientName: 'Client 3');
        expect(repo.addBooking(b3), isTrue);

        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(0));
        expect(status.isFullyBooked, isTrue, reason: 'All 3 staff members are now booked');

        // Book 4 without overbooking: MUST BE REJECTED
        final b4 = b1.copyWith(id: 'booking_cap_4', clientName: 'Client 4');
        final rejected = repo.addBooking(b4, allowOverbooking: false);
        expect(rejected, isFalse, reason: 'Slot must reject additional booking once capacity is reached');

        // Book 4 WITH allowOverbooking: true: MUST SUCCEED
        final overbooked = repo.addBooking(b4, allowOverbooking: true);
        expect(overbooked, isTrue, reason: 'Slot must accept additional booking when allowOverbooking is true');

        // Verify active bookings count is now 4
        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.activeBookingsCount, equals(4));
        expect(status.availableCapacity, equals(0));
      });

      test('1.3 Partial capacity reduction via explicit day block for one specialist', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        // Founder + 1 technician = 2 specialists
        repo.addTeamMember(const TeamMember(
          id: 'tm_john',
          name: 'John Wick',
          roleTitle: 'Master Detailer',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 18);
        const slot = '9:00 AM - 1:00 PM';

        // John Wick has an all-day block on this date
        repo.addAvailabilityBlock(CalendarAvailabilityBlock(
          id: 'block_john_nov18',
          detailerId: repo.currentUser.id,
          date: date,
          isAllDay: true,
          reason: 'Personal leave',
          teamMemberId: 'tm_john',
          createdAt: DateTime(2026, 11, 1),
        ));

        // Capacity should now be only 1 (Founder only)
        final status = repo.getSlotStaffingStatus(date, slot);
        expect(status.onDutyCount, equals(1), reason: 'John is blocked, only Founder is on duty');
        expect(status.availableCapacity, equals(1));

        // Booking 1 occupies Founder's slot
        final b1 = BookingAppointment(
          id: 'booking_founder_slot',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client 1',
          clientPhone: '555-0001',
          clientEmail: 'c1@example.com',
          vehicleYearMakeModel: 'Car 1',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );
        expect(repo.addBooking(b1), isTrue);

        // Booking 2 without overbooking is rejected because capacity (1) is exhausted
        final b2 = b1.copyWith(id: 'booking_overflow_slot');
        expect(repo.addBooking(b2, allowOverbooking: false), isFalse);

        // Attempting to book John specifically is also rejected because he is blocked
        final bJohn = b1.copyWith(
          id: 'booking_john_blocked',
          assignedTeamMemberId: 'tm_john',
          assignedTeamMemberName: 'John Wick',
        );
        expect(repo.addBooking(bJohn, allowOverbooking: false), isFalse);
      });

      test('1.4 Direct Technician Conflict vs Different Technician Coexistence', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_tech_a',
          name: 'Tech Alpha',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));
        repo.addTeamMember(const TeamMember(
          id: 'tm_tech_b',
          name: 'Tech Bravo',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 23);
        const slot = '10:00 AM - 2:00 PM';

        // 1. Client 1 books Tech A -> succeeds
        final bTechA1 = BookingAppointment(
          id: 'booking_ta_1',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client 1',
          clientPhone: '555-0001',
          clientEmail: 'c1@example.com',
          vehicleYearMakeModel: 'Car 1',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_tech_a',
          assignedTeamMemberName: 'Tech Alpha',
        );
        expect(repo.addBooking(bTechA1), isTrue);

        // 2. Client 2 attempts to book Tech A for the same slot -> rejected!
        final bTechA2 = bTechA1.copyWith(id: 'booking_ta_2', clientName: 'Client 2');
        expect(repo.addBooking(bTechA2), isFalse, reason: 'Tech A is already booked for this slot');

        // 3. Client 3 books Tech B for the SAME slot -> succeeds!
        final bTechB1 = bTechA1.copyWith(
          id: 'booking_tb_1',
          clientName: 'Client 3',
          assignedTeamMemberId: 'tm_tech_b',
          assignedTeamMemberName: 'Tech Bravo',
        );
        expect(repo.addBooking(bTechB1), isTrue, reason: 'Tech B is available for this slot');

        // 4. Client 4 attempts to book Tech B for the same slot -> rejected!
        final bTechB2 = bTechB1.copyWith(id: 'booking_tb_2', clientName: 'Client 4');
        expect(repo.addBooking(bTechB2), isFalse, reason: 'Tech B is now also booked for this slot');
      });

      test('1.5 High-volume burst concurrency stress (10 concurrent requests for 1 slot)', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        // Solo founder studio -> slot capacity is exactly 1
        final date = DateTime(2026, 11, 24);
        const slot = '2:00 PM - 6:00 PM';

        final bookings = List.generate(10, (index) => BookingAppointment(
          id: 'booking_burst_$index',
          clientId: 'client_$index',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client $index',
          clientPhone: '555-000$index',
          clientEmail: 'client$index@example.com',
          vehicleYearMakeModel: 'Vehicle $index',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 600.0,
          depositAmount: 150.0,
          status: BookingStatus.confirmed,
        ));

        // Fire 10 concurrent requests
        final results = await Future.wait(bookings.map((b) => Future(() => repo.addBooking(b))));

        final successCount = results.where((r) => r == true).length;
        final failCount = results.where((r) => r == false).length;

        expect(successCount, equals(1), reason: 'Only 1 of 10 concurrent bookings should succeed');
        expect(failCount, equals(9), reason: '9 of 10 concurrent bookings should be rejected');

        // Verify repository contains only 1 booking for this slot
        final slotBookings = repo.bookings.where((b) => b.scheduledDate == date && b.scheduledTimeSlot == slot).toList();
        expect(slotBookings.length, equals(1));
      });

      test('1.6 Idempotency: re-adding booking with same ID updates in place without double-booking conflict', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        final date = DateTime(2026, 11, 25);
        const slot = '9:00 AM - 1:00 PM';

        final initialBooking = BookingAppointment(
          id: 'booking_idempotent_test',
          clientId: 'client_idem',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Idempotent Client',
          clientPhone: '555-9988',
          clientEmail: 'idem@example.com',
          vehicleYearMakeModel: '2024 Lucid Air Sapphire',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1200.0,
          depositAmount: 300.0,
          status: BookingStatus.confirmed,
          clientNotes: 'Initial note',
        );

        // First insertion succeeds
        expect(repo.addBooking(initialBooking), isTrue);

        // Second insertion of SAME ID with updated notes and price must succeed (idempotency)
        final updatedBooking = initialBooking.copyWith(
          clientNotes: 'Updated note after customer consultation',
          totalPrice: 1400.0,
        );

        final reAdded = repo.addBooking(updatedBooking);
        expect(reAdded, isTrue, reason: 'Updating existing booking with same ID must be allowed');

        // Check repository does not duplicate the booking
        final matching = repo.bookings.where((b) => b.id == 'booking_idempotent_test').toList();
        expect(matching.length, equals(1));
        expect(matching.first.clientNotes, equals('Updated note after customer consultation'));
        expect(matching.first.totalPrice, equals(1400.0));
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 2. TECHNICIAN ASSIGNMENT PRESERVATION ACROSS LIFECYCLE & RELOADS
    // ──────────────────────────────────────────────────────────────────────────

    group('2. Technician Assignment Preservation Across Lifecycle & Reloads', () {
      test('2.1 assignBookingTechnician -> confirmed -> inProgress -> completed survives reload at each step', () async {
        var repo = await TestHarness.createSession(isLoggedIn: true);

        // Add technician
        repo.addTeamMember(const TeamMember(
          id: 'tm_specialist_marcus',
          name: 'Marcus Brody',
          roleTitle: 'Senior Specialist',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 26);
        const slot = '10:00 AM - 2:00 PM';

        // 1. Create booking initially unassigned
        final booking = BookingAppointment(
          id: 'booking_lifecycle_audit',
          clientId: 'client_marcus_car',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Julian Noble',
          clientPhone: '555-4321',
          clientEmail: 'julian@example.com',
          vehicleYearMakeModel: '2023 Aston Martin DBS',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1800.0,
          depositAmount: 500.0,
          status: BookingStatus.confirmed,
          clientNotes: 'Requires ceramic coating on wheels',
          warrantyPassportId: 'WAR-ASTON-9900',
        );

        expect(repo.addBooking(booking), isTrue);

        // 2. Assign technician via assignBookingTechnician
        repo.assignBookingTechnician('booking_lifecycle_audit', 'tm_specialist_marcus', 'Marcus Brody');

        var current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'));
        expect(current.assignedTeamMemberName, equals('Marcus Brody'));

        // RELOAD 1: Verify assignment survives immediately after assignBookingTechnician
        repo = await TestHarness.simulateBrowserRefresh(repo);
        current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'));
        expect(current.assignedTeamMemberName, equals('Marcus Brody'));
        expect(current.status, equals(BookingStatus.confirmed));
        expect(current.warrantyPassportId, equals('WAR-ASTON-9900'));
        expect(current.clientNotes, equals('Requires ceramic coating on wheels'));

        // 3. Update status to inProgress
        repo.updateBookingStatus('booking_lifecycle_audit', BookingStatus.inProgress);
        current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.status, equals(BookingStatus.inProgress));
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'));
        expect(current.assignedTeamMemberName, equals('Marcus Brody'));

        // RELOAD 2: Verify assignment survives after inProgress transition
        repo = await TestHarness.simulateBrowserRefresh(repo);
        current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.status, equals(BookingStatus.inProgress));
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'), reason: 'assignedTeamMemberId must persist across inProgress reload');
        expect(current.assignedTeamMemberName, equals('Marcus Brody'), reason: 'assignedTeamMemberName must persist across inProgress reload');
        expect(current.warrantyPassportId, equals('WAR-ASTON-9900'));

        // 4. Update status to completed
        repo.updateBookingStatus('booking_lifecycle_audit', BookingStatus.completed);
        current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.status, equals(BookingStatus.completed));
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'));
        expect(current.assignedTeamMemberName, equals('Marcus Brody'));

        // RELOAD 3: Verify assignment survives after completed transition
        repo = await TestHarness.simulateBrowserRefresh(repo);
        current = repo.bookings.firstWhere((b) => b.id == 'booking_lifecycle_audit');
        expect(current.status, equals(BookingStatus.completed));
        expect(current.assignedTeamMemberId, equals('tm_specialist_marcus'), reason: 'assignedTeamMemberId must persist across completed reload');
        expect(current.assignedTeamMemberName, equals('Marcus Brody'), reason: 'assignedTeamMemberName must persist across completed reload');
        expect(current.warrantyPassportId, equals('WAR-ASTON-9900'));
      });

      test('2.2 Technician reassignment updates slot locks and survives reload', () async {
        var repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_tech_1',
          name: 'Tech 1',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));
        repo.addTeamMember(const TeamMember(
          id: 'tm_tech_2',
          name: 'Tech 2',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 27);
        const slot = '10:00 AM - 2:00 PM';

        final booking = BookingAppointment(
          id: 'booking_reassign_test',
          clientId: 'client_reassign',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Reassign Client',
          clientPhone: '555-8888',
          clientEmail: 'reassign@example.com',
          vehicleYearMakeModel: '2024 Lucid Air',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1000.0,
          depositAmount: 200.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_tech_1',
          assignedTeamMemberName: 'Tech 1',
        );

        expect(repo.addBooking(booking), isTrue);

        // Tech 1 is currently booked
        expect(repo.isMemberBookedForSlot('tm_tech_1', date, slot), isTrue);
        expect(repo.isMemberBookedForSlot('tm_tech_2', date, slot), isFalse);

        // Reassign to Tech 2
        repo.assignBookingTechnician('booking_reassign_test', 'tm_tech_2', 'Tech 2');

        // Tech 1 is now freed, Tech 2 is now booked
        expect(repo.isMemberBookedForSlot('tm_tech_1', date, slot), isFalse);
        expect(repo.isMemberBookedForSlot('tm_tech_2', date, slot), isTrue);

        // Simulate refresh
        repo = await TestHarness.simulateBrowserRefresh(repo);

        final refreshedBooking = repo.bookings.firstWhere((b) => b.id == 'booking_reassign_test');
        expect(refreshedBooking.assignedTeamMemberId, equals('tm_tech_2'));
        expect(refreshedBooking.assignedTeamMemberName, equals('Tech 2'));
        expect(repo.isMemberBookedForSlot('tm_tech_1', date, slot), isFalse);
        expect(repo.isMemberBookedForSlot('tm_tech_2', date, slot), isTrue);
      });

      test('2.3 Non-existent booking ID calls are handled gracefully without exceptions', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        // Neither of these should throw
        expect(() => repo.assignBookingTechnician('invalid_id', 'tm_tech_x', 'Unknown'), returnsNormally);
        expect(() => repo.updateBookingStatus('invalid_id', BookingStatus.inProgress), returnsNormally);
        expect(() => repo.cancelBooking('invalid_id'), returnsNormally);
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 3. CANCELLATION & SLOT FREEING
    // ──────────────────────────────────────────────────────────────────────────

    group('3. Cancellation & Slot Freeing', () {
      test('3.1 cancelBooking unlocks slot and technician immediately for new booking', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_tech_claire',
          name: 'Claire Redfield',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 28);
        const slot = '11:00 AM - 3:00 PM';

        final booking1 = BookingAppointment(
          id: 'booking_cancel_claire',
          clientId: 'client_c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client Claire',
          clientPhone: '555-7766',
          clientEmail: 'claire@example.com',
          vehicleYearMakeModel: '2023 Defender 110',
          vehicleSize: VehicleSize.truckVan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1200.0,
          depositAmount: 300.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_tech_claire',
          assignedTeamMemberName: 'Claire Redfield',
        );

        expect(repo.addBooking(booking1), isTrue);

        // Slot and technician are locked
        expect(repo.isSlotConflictedByBooking(date, slot, teamMemberId: 'tm_tech_claire'), isTrue);
        expect(repo.isMemberBookedForSlot('tm_tech_claire', date, slot), isTrue);

        // Competing booking for Claire is rejected
        final competingBooking = booking1.copyWith(id: 'booking_competing_claire', clientName: 'Competing Client');
        expect(repo.addBooking(competingBooking), isFalse);

        // Cancel first booking via cancelBooking
        repo.cancelBooking('booking_cancel_claire');

        // Verify status transitioned
        final current = repo.bookings.firstWhere((b) => b.id == 'booking_cancel_claire');
        expect(current.status, equals(BookingStatus.cancelled));

        // Slot and technician must be IMMEDIATELY unlocked
        expect(repo.isSlotConflictedByBooking(date, slot, teamMemberId: 'tm_tech_claire'), isFalse);
        expect(repo.isMemberBookedForSlot('tm_tech_claire', date, slot), isFalse);

        // Now the competing booking can be placed and succeeds!
        expect(repo.addBooking(competingBooking), isTrue);
      });

      test('3.2 Slot unlock and cancelled status persist across browser refresh', () async {
        var repo = await TestHarness.createSession(isLoggedIn: true);

        final date = DateTime(2026, 11, 29);
        const slot = '10:00 AM - 2:00 PM';

        final booking = BookingAppointment(
          id: 'booking_cancel_refresh',
          clientId: 'client_cr',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Refresh Client',
          clientPhone: '555-3344',
          clientEmail: 'refresh@example.com',
          vehicleYearMakeModel: '2024 Genesis G90',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1000.0,
          depositAmount: 200.0,
          status: BookingStatus.confirmed,
        );

        expect(repo.addBooking(booking), isTrue);

        // Cancel booking
        repo.cancelBooking('booking_cancel_refresh');

        // Simulate browser refresh
        repo = await TestHarness.simulateBrowserRefresh(repo);

        final restored = repo.bookings.firstWhere((b) => b.id == 'booking_cancel_refresh');
        expect(restored.status, equals(BookingStatus.cancelled));

        // Slot remains unlocked after reload
        expect(repo.isSlotConflictedByBooking(date, slot), isFalse);

        // New booking can be added in the restored session
        final newBooking = booking.copyWith(id: 'booking_after_refresh_success', clientName: 'Next Client');
        expect(repo.addBooking(newBooking), isTrue);
      });

      test('3.3 Multi-specialist capacity is accurately restored upon cancellation', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_1',
          name: 'Tech One',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));

        // 2 staff members (Founder + Tech One)
        final date = DateTime(2026, 11, 30);
        const slot = '9:00 AM - 1:00 PM';

        var status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(2));

        // Book 1
        final b1 = BookingAppointment(
          id: 'booking_restore_1',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client 1',
          clientPhone: '555-1',
          clientEmail: 'c1@example.com',
          vehicleYearMakeModel: 'Car 1',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );
        expect(repo.addBooking(b1), isTrue);

        // Book 2 (exhausts capacity)
        final b2 = b1.copyWith(id: 'booking_restore_2', clientName: 'Client 2');
        expect(repo.addBooking(b2), isTrue);

        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(0));
        expect(status.isFullyBooked, isTrue);

        // Cancel Book 1
        repo.cancelBooking('booking_restore_1');

        // Capacity restored to 1!
        status = repo.getSlotStaffingStatus(date, slot);
        expect(status.availableCapacity, equals(1));
        expect(status.isFullyBooked, isFalse);

        // A new 3rd client can now book without overbooking
        final b3 = b1.copyWith(id: 'booking_restore_3', clientName: 'Client 3');
        expect(repo.addBooking(b3), isTrue);
      });

      test('3.4 Calling cancelBooking repeatedly is a safe idempotent operation', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        final date = DateTime(2026, 12, 1);
        const slot = '10:00 AM - 2:00 PM';

        final b = BookingAppointment(
          id: 'booking_double_cancel',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client Double Cancel',
          clientPhone: '555-0011',
          clientEmail: 'dc@example.com',
          vehicleYearMakeModel: 'Car',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 500.0,
          depositAmount: 100.0,
          status: BookingStatus.confirmed,
        );

        expect(repo.addBooking(b), isTrue);

        // Cancel twice
        repo.cancelBooking('booking_double_cancel');
        repo.cancelBooking('booking_double_cancel');

        final current = repo.bookings.firstWhere((item) => item.id == 'booking_double_cancel');
        expect(current.status, equals(BookingStatus.cancelled));
        expect(repo.isSlotConflictedByBooking(date, slot), isFalse);
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 4. ADVANCED EDGE CASES & ADVERSARIAL STRESS
    // ──────────────────────────────────────────────────────────────────────────

    group('4. Advanced Edge Cases & Adversarial Stress', () {
      test('4.1 Time interval overlap conflict detection for same technician', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_interval_tech',
          name: 'Interval Tech',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));
        repo.addTeamMember(const TeamMember(
          id: 'tm_free_tech',
          name: 'Free Tech',
          roleTitle: 'Specialist',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 18); // Wednesday

        // 1. Tech assigned to 9:00 AM - 1:00 PM
        final b1 = BookingAppointment(
          id: 'booking_interval_1',
          clientId: 'c1',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Client 1',
          clientPhone: '555-0101',
          clientEmail: 'c1@example.com',
          vehicleYearMakeModel: 'Car 1',
          vehicleSize: VehicleSize.coupeSedan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 600.0,
          depositAmount: 150.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_interval_tech',
          assignedTeamMemberName: 'Interval Tech',
        );
        expect(repo.addBooking(b1), isTrue);

        // 2. Overlapping slot 11:00 AM - 3:00 PM for the SAME technician must be rejected
        final b2Overlapping = b1.copyWith(
          id: 'booking_interval_2_overlap',
          clientName: 'Client 2 Overlap',
          scheduledTimeSlot: '11:00 AM - 3:00 PM',
        );
        expect(repo.addBooking(b2Overlapping), isFalse, reason: 'Overlapping time slot for same technician must be rejected');

        // 3. Same overlapping slot 11:00 AM - 3:00 PM for a DIFFERENT free technician must succeed!
        final b3DifferentTech = b2Overlapping.copyWith(
          id: 'booking_interval_3_other_tech',
          clientName: 'Client 3 Other Tech',
          assignedTeamMemberId: 'tm_free_tech',
          assignedTeamMemberName: 'Free Tech',
        );
        expect(repo.addBooking(b3DifferentTech), isTrue, reason: 'Different free technician should accept overlapping slot');
      });

      test('4.2 Multi-day booking slot lockout across multiple days and complete freeing on cancellation', () async {
        final repo = await TestHarness.createSession(isLoggedIn: true);

        final startDate = DateTime(2026, 11, 18); // Wednesday
        final secondDate = DateTime(2026, 11, 19); // Thursday

        // Create 2-day service package
        final multiDayPackage = ServicePackage(
          id: 'pkg_multi_day_coating',
          title: 'Full Multi-Day Paint Restoration & Glass Coating',
          description: 'Comprehensive 2-day service',
          basePrice: 3500.0,
          estimatedDuration: '2 days',
          includes: ['Paint Correction', 'Multi-layer Ceramic', 'Interior Detail'],
        );

        final multiDayBooking = BookingAppointment(
          id: 'booking_multi_day_test',
          clientId: 'client_md',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Multi-Day VIP Client',
          clientPhone: '555-7788',
          clientEmail: 'vip@example.com',
          vehicleYearMakeModel: '1970 Plymouth Barracuda 440 Six-Pack',
          vehicleSize: VehicleSize.coupeSedan,
          package: multiDayPackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: startDate,
          scheduledTimeSlot: '9:00 AM - 1:00 PM',
          totalPrice: 3500.0,
          depositAmount: 1000.0,
          status: BookingStatus.confirmed,
        );

        // Add 2-day booking
        expect(repo.addBooking(multiDayBooking), isTrue);

        // Day 1 (Nov 18) must be conflicted
        expect(repo.isSlotConflictedByBooking(startDate, '9:00 AM - 1:00 PM'), isTrue);

        // Day 2 (Nov 19) must ALSO be conflicted due to multi-day span
        expect(repo.isSlotConflictedByBooking(secondDate, '10:00 AM - 2:00 PM'), isTrue);

        // Competing booking on Day 2 without overbooking must be rejected
        final day2Competing = multiDayBooking.copyWith(
          id: 'booking_day2_competing',
          clientName: 'Day 2 Competitor',
          scheduledDate: secondDate,
          scheduledTimeSlot: '10:00 AM - 2:00 PM',
          package: repo.currentUser.servicePackages.first,
        );
        expect(repo.addBooking(day2Competing), isFalse, reason: 'Multi-day booking must block subsequent day');

        // Cancel the multi-day booking
        repo.cancelBooking('booking_multi_day_test');

        // Both Day 1 and Day 2 must now be freed
        expect(repo.isSlotConflictedByBooking(startDate, '9:00 AM - 1:00 PM'), isFalse);
        expect(repo.isSlotConflictedByBooking(secondDate, '10:00 AM - 2:00 PM'), isFalse);

        // Competing booking on Day 2 can now be added successfully
        expect(repo.addBooking(day2Competing), isTrue);
      });

      test('4.3 Technician assignment and warranty fields persist through cancellation and reload for audit history', () async {
        var repo = await TestHarness.createSession(isLoggedIn: true);

        repo.addTeamMember(const TeamMember(
          id: 'tm_audit_specialist',
          name: 'Audit Tech',
          roleTitle: 'Master Detailer',
          avatarUrl: '',
        ));

        final date = DateTime(2026, 11, 25);
        const slot = '10:00 AM - 2:00 PM';

        final b = BookingAppointment(
          id: 'booking_audit_history',
          clientId: 'client_audit',
          detailerId: repo.currentUser.id,
          detailerName: repo.currentUser.displayName,
          detailerBusinessName: repo.currentUser.businessName,
          detailerAvatar: '',
          clientName: 'Audit Client',
          clientPhone: '555-8822',
          clientEmail: 'audit@example.com',
          vehicleYearMakeModel: '2025 Rivian R2',
          vehicleSize: VehicleSize.truckVan,
          package: repo.currentUser.servicePackages.first,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Way',
          scheduledDate: date,
          scheduledTimeSlot: slot,
          totalPrice: 1200.0,
          depositAmount: 300.0,
          status: BookingStatus.confirmed,
          assignedTeamMemberId: 'tm_audit_specialist',
          assignedTeamMemberName: 'Audit Tech',
          warrantyPassportId: 'WARR-AUDIT-9090',
          clientNotes: 'Pre-cancellation client notes',
        );

        expect(repo.addBooking(b), isTrue);

        // Cancel booking
        repo.cancelBooking('booking_audit_history');

        // Simulate browser reload
        repo = await TestHarness.simulateBrowserRefresh(repo);

        final cancelled = repo.bookings.firstWhere((item) => item.id == 'booking_audit_history');
        expect(cancelled.status, equals(BookingStatus.cancelled));
        expect(cancelled.assignedTeamMemberId, equals('tm_audit_specialist'), reason: 'Cancelled booking must keep tech assignment for history');
        expect(cancelled.assignedTeamMemberName, equals('Audit Tech'));
        expect(cancelled.warrantyPassportId, equals('WARR-AUDIT-9090'));
        expect(cancelled.clientNotes, equals('Pre-cancellation client notes'));
      });

      test('4.4 Deserialization resilience: legacy or incomplete records handle null tech fields safely', () async {
        // Pre-seed mock SharedPreferences with a booking missing assignedTeamMemberId & assignedTeamMemberName
        final minimalBookingJson = {
          'id': 'booking_legacy_null_fields',
          'detailerId': 'usr_you',
          'detailerName': 'Test Detailer',
          'detailerBusinessName': 'Test Studio',
          'detailerAvatar': '',
          'clientName': 'Minimal Client',
          'clientPhone': '555-1234',
          'clientEmail': 'min@example.com',
          'vehicleYearMakeModel': 'Classic Bug',
          'vehicleSize': 'coupeSedan',
          'package': {
            'id': 'pkg_min',
            'title': 'Wash',
            'description': 'Basic',
            'basePrice': 100.0,
            'estimatedDuration': '1 hr',
            'includes': [],
          },
          'locationType': 'shop',
          'clientAddress': '100 Studio Way',
          'scheduledDate': '2026-11-20T00:00:00.000',
          'scheduledTimeSlot': '10:00 AM',
          'totalPrice': 100.0,
          'depositAmount': 20.0,
          'status': 'confirmed',
          // Note: assignedTeamMemberId, assignedTeamMemberName, warrantyPassportId omitted entirely!
        };

        SharedPreferences.setMockInitialValues({
          'adc_bookings_v1': '[${jsonEncode(minimalBookingJson)}]',
        });

        final loaded = await LocalStorageService.loadBookings();
        expect(loaded, isNotNull);
        expect(loaded!.length, equals(1));
        final record = loaded.first;
        expect(record.id, equals('booking_legacy_null_fields'));
        expect(record.assignedTeamMemberId, isNull);
        expect(record.assignedTeamMemberName, isNull);
        expect(record.warrantyPassportId, isNull);

        // Verify JobRepository can initialize and manage this record without error
        final repo = JobRepository();
        await repo.init();
        expect(repo.bookings.any((b) => b.id == 'booking_legacy_null_fields'), isTrue);

        // Can assign technician to this legacy record
        repo.assignBookingTechnician('booking_legacy_null_fields', 'tm_new_assign', 'New Specialist');
        final updated = repo.bookings.firstWhere((b) => b.id == 'booking_legacy_null_fields');
        expect(updated.assignedTeamMemberId, equals('tm_new_assign'));
        expect(updated.assignedTeamMemberName, equals('New Specialist'));
      });
    });
  });
}
