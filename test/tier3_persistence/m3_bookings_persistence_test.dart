import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3: Client Booking Flow & Appointment Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1: Booking Lifecycle & Dedicated Storage Persistence survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final booking = BookingAppointment(
        id: 'booking_m3_test_1',
        clientId: 'client_marcus',
        detailerId: repo1.currentUser.id,
        detailerName: repo1.currentUser.displayName,
        detailerBusinessName: repo1.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Arthur Pendelton',
        clientPhone: '(512) 555-8822',
        clientEmail: 'arthur@example.com',
        vehicleYearMakeModel: '2023 BMW M3 Competition',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo1.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin TX',
        scheduledDate: DateTime(2026, 11, 15),
        scheduledTimeSlot: '9:00 AM - 1:00 PM',
        totalPrice: 1200.0,
        depositAmount: 300.0,
        status: BookingStatus.confirmed,
        clientNotes: 'Front bumper has fresh PPF',
        warrantyPassportId: 'ADC-BMW-9988',
      );

      final added = repo1.addBooking(booking);
      expect(added, isTrue);

      // Verify dedicated storage contains booking immediately
      final dedicated = await LocalStorageService.loadBookings();
      expect(dedicated, isNotNull);
      expect(dedicated!.any((b) => b.id == 'booking_m3_test_1'), isTrue);
      final stored = dedicated.firstWhere((b) => b.id == 'booking_m3_test_1');
      expect(stored.clientName, equals('Arthur Pendelton'));
      expect(stored.vehicleYearMakeModel, equals('2023 BMW M3 Competition'));
      expect(stored.totalPrice, equals(1200.0));
      expect(stored.warrantyPassportId, equals('ADC-BMW-9988'));

      // Simulate browser refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.bookings.any((b) => b.id == 'booking_m3_test_1'), isTrue);
      final restored = repo2.bookings.firstWhere((b) => b.id == 'booking_m3_test_1');
      expect(restored.clientName, equals('Arthur Pendelton'));
      expect(restored.status, equals(BookingStatus.confirmed));
      expect(restored.warrantyPassportId, equals('ADC-BMW-9988'));
    });

    test('T2: Technician Assignment & Status Lifecycle via copyWith preserves tech fields', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // Add a technician to the studio
      repo1.addTeamMember(const TeamMember(
        id: 'tm_specialist_leo',
        name: 'Leo Rossi',
        roleTitle: 'Master Detailer',
        avatarUrl: '',
      ));

      final booking = BookingAppointment(
        id: 'booking_tech_assignment_test',
        clientId: 'client_elena',
        detailerId: repo1.currentUser.id,
        detailerName: repo1.currentUser.displayName,
        detailerBusinessName: repo1.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Elena Rostova',
        clientPhone: '(512) 555-4411',
        clientEmail: 'elena@example.com',
        vehicleYearMakeModel: '2024 Audi RS6 Avant',
        vehicleSize: VehicleSize.truckVan,
        package: repo1.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime(2026, 12, 5),
        scheduledTimeSlot: '1:00 PM - 5:00 PM',
        totalPrice: 1500.0,
        depositAmount: 400.0,
        status: BookingStatus.confirmed,
        assignedTeamMemberId: 'tm_specialist_leo',
        assignedTeamMemberName: 'Leo Rossi',
      );

      repo1.addBooking(booking);

      // Verify technician assignment is in place
      var current = repo1.bookings.firstWhere((b) => b.id == 'booking_tech_assignment_test');
      expect(current.assignedTeamMemberId, equals('tm_specialist_leo'));
      expect(current.assignedTeamMemberName, equals('Leo Rossi'));

      // 1. Transition confirmed -> inProgress
      repo1.updateBookingStatus('booking_tech_assignment_test', BookingStatus.inProgress);
      current = repo1.bookings.firstWhere((b) => b.id == 'booking_tech_assignment_test');
      expect(current.status, equals(BookingStatus.inProgress));
      expect(current.assignedTeamMemberId, equals('tm_specialist_leo'), reason: 'assignedTeamMemberId must NOT be stripped on inProgress update');
      expect(current.assignedTeamMemberName, equals('Leo Rossi'), reason: 'assignedTeamMemberName must NOT be stripped on inProgress update');

      // 2. Transition inProgress -> completed
      repo1.updateBookingStatus('booking_tech_assignment_test', BookingStatus.completed);
      current = repo1.bookings.firstWhere((b) => b.id == 'booking_tech_assignment_test');
      expect(current.status, equals(BookingStatus.completed));
      expect(current.assignedTeamMemberId, equals('tm_specialist_leo'), reason: 'assignedTeamMemberId must NOT be stripped on completed update');
      expect(current.assignedTeamMemberName, equals('Leo Rossi'), reason: 'assignedTeamMemberName must NOT be stripped on completed update');

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      final restored = repo2.bookings.firstWhere((b) => b.id == 'booking_tech_assignment_test');
      expect(restored.status, equals(BookingStatus.completed));
      expect(restored.assignedTeamMemberId, equals('tm_specialist_leo'));
      expect(restored.assignedTeamMemberName, equals('Leo Rossi'));
    });

    test('T3: Smooth Legacy Migration: Seed adc_bookings_state_v3 promotes to adc_bookings_v1', () async {
      final legacyAppointment = BookingAppointment(
        id: 'booking_legacy_migration_test',
        clientId: 'client_legacy',
        detailerId: 'detailer_legacy',
        detailerName: 'Legacy Detailer',
        detailerBusinessName: 'Legacy Studio',
        detailerAvatar: '',
        clientName: 'Legacy Customer',
        clientPhone: '(512) 555-1212',
        clientEmail: 'legacy@example.com',
        vehicleYearMakeModel: '1967 Ford Mustang Fastback',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_legacy',
          title: 'Classic Paint Restoration',
          description: 'Restoration',
          basePrice: 2000.0,
          estimatedDuration: '12 hrs',
          includes: ['Multi-Stage Correction'],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime(2026, 11, 30),
        scheduledTimeSlot: '8:00 AM - 12:00 PM',
        totalPrice: 2000.0,
        depositAmount: 500.0,
        status: BookingStatus.confirmed,
      );

      // Pre-seed ONLY the legacy storage key (adc_bookings_state_v3)
      SharedPreferences.setMockInitialValues({
        'adc_bookings_state_v3': jsonEncode([legacyAppointment.toJson()]),
      });

      // Verify dedicated key does not exist yet
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adc_bookings_v1'), isNull);

      // Hydrate via LocalStorageService.loadBookings()
      final loaded = await LocalStorageService.loadBookings();
      expect(loaded, isNotNull);
      expect(loaded!.length, equals(1));
      expect(loaded.first.id, equals('booking_legacy_migration_test'));

      // Verify smooth migration: dedicated key is now populated!
      final dedicatedRaw = prefs.getString('adc_bookings_v1');
      expect(dedicatedRaw, isNotNull);
      expect(dedicatedRaw!.contains('booking_legacy_migration_test'), isTrue);

      // Test with full JobRepository.init()
      final repo = JobRepository();
      await repo.init();
      expect(repo.bookings.any((b) => b.id == 'booking_legacy_migration_test'), isTrue);
    });

    test('T4: Concurrent Double-Booking Race Condition Guard rejects conflicting slot bookings', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      final date = DateTime(2026, 11, 18);
      const slot = '10:00 AM - 2:00 PM';

      final booking1 = BookingAppointment(
        id: 'booking_race_first',
        clientId: 'client_1',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'First Client',
        clientPhone: '(512) 555-1111',
        clientEmail: 'first@example.com',
        vehicleYearMakeModel: '2024 Tesla Model S Plaid',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 800.0,
        depositAmount: 200.0,
        status: BookingStatus.confirmed,
      );

      // First booking succeeds
      final res1 = repo.addBooking(booking1);
      expect(res1, isTrue);

      // Attempting to book the EXACT SAME SLOT without overbooking capability
      final booking2 = BookingAppointment(
        id: 'booking_race_second',
        clientId: 'client_2',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Second Client',
        clientPhone: '(512) 555-2222',
        clientEmail: 'second@example.com',
        vehicleYearMakeModel: '2023 Mercedes AMG GT',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 800.0,
        depositAmount: 200.0,
        status: BookingStatus.confirmed,
      );

      // Second booking must be rejected because slot is already taken!
      final res2 = repo.addBooking(booking2, allowOverbooking: false);
      expect(res2, isFalse, reason: 'Duplicate slot reservation should be rejected by conflict guard');

      // Verify repository contains only the first booking for that slot
      expect(repo.bookings.where((b) => b.scheduledDate == date && b.scheduledTimeSlot == slot).length, equals(1));
      expect(repo.bookings.first.id, equals('booking_race_first'));
    });

    test('T5: Cancellation updates status and unlocks slot for new bookings', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      final date = DateTime(2026, 11, 25);
      const slot = '10:00 AM - 2:00 PM';

      final booking = BookingAppointment(
        id: 'booking_cancel_test',
        clientId: 'client_cancel',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Cancel Test Client',
        clientPhone: '(512) 555-3333',
        clientEmail: 'cancel@example.com',
        vehicleYearMakeModel: '2022 Rivian R1T',
        vehicleSize: VehicleSize.truckVan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 1000.0,
        depositAmount: 250.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(booking);

      // Slot is currently conflicted
      expect(repo.isSlotConflictedByBooking(date, slot, detailerId: repo.currentUser.id), isTrue);

      // Cancel the booking via cancelBooking API
      repo.cancelBooking('booking_cancel_test');

      final cancelledBooking = repo.bookings.firstWhere((b) => b.id == 'booking_cancel_test');
      expect(cancelledBooking.status, equals(BookingStatus.cancelled));

      // Now the slot must be unlocked!
      expect(repo.isSlotConflictedByBooking(date, slot, detailerId: repo.currentUser.id), isFalse);

      // A new client can now book this slot
      final newBooking = BookingAppointment(
        id: 'booking_new_client_slot',
        clientId: 'client_new',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'New Client',
        clientPhone: '(512) 555-9999',
        clientEmail: 'new@example.com',
        vehicleYearMakeModel: '2024 Corvette Z06',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 1000.0,
        depositAmount: 250.0,
        status: BookingStatus.confirmed,
      );

      final newSuccess = repo.addBooking(newBooking);
      expect(newSuccess, isTrue);
    });
  });
}
