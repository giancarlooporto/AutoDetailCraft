import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/multi_device_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Device Booking Synchronization Tier 1 Unit Tests (R1 & R2)', () {
    late MultiDeviceTestHarness harness;
    late JobRepository deviceA;
    late JobRepository deviceB;
    late JobRepository detailerRepo;

    const testPackage = ServicePackage(
      id: 'pkg_unit_sync_01',
      title: 'Ceramic Coating & Paint Correction',
      description: 'Comprehensive 2-stage paint correction with ceramic protection',
      basePrice: 650.0,
      estimatedDuration: '4 hrs',
      includes: ['Paint Decontamination', 'Stage 2 Polish', 'Ceramic 9H Coating'],
    );

    BookingAppointment createTestBooking({
      required String id,
      String? clientId = 'usr_client_01',
      String clientEmail = 'alex.mercer@example.com',
      String detailerId = 'usr_detailer_pro',
      BookingStatus status = BookingStatus.confirmed,
      DateTime? scheduledDate,
      String scheduledTimeSlot = '10:00 AM - 2:00 PM',
    }) {
      return BookingAppointment(
        id: id,
        clientId: clientId,
        detailerId: detailerId,
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Precision Detailing',
        detailerAvatar: '',
        clientName: 'Alex Mercer',
        clientPhone: '(512) 555-4321',
        clientEmail: clientEmail,
        vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin TX',
        scheduledDate: scheduledDate ?? DateTime.now().add(const Duration(days: 2)),
        scheduledTimeSlot: scheduledTimeSlot,
        totalPrice: 650.0,
        depositAmount: 150.0,
        status: status,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      harness = MultiDeviceTestHarness();

      deviceA = await harness.createClientDeviceSession(
        deviceId: 'device_a',
        userId: 'usr_client_01',
        email: 'alex.mercer@example.com',
        displayName: 'Alex Mercer',
      );

      deviceB = await harness.createClientDeviceSession(
        deviceId: 'device_b',
        userId: 'usr_client_01',
        email: 'alex.mercer@example.com',
        displayName: 'Alex Mercer',
      );

      detailerRepo = await harness.createDetailerSession(
        detailerId: 'usr_detailer_pro',
        email: 'marcus@apexprecision.com',
        displayName: 'Marcus Vance',
        businessName: 'Apex Precision Detailing',
      );
    });

    tearDown(() {
      harness.dispose();
    });

    test('1. All 4 Status Categories Parity Across Client Devices (R1)', () {
      final bookingConfirmed = createTestBooking(
        id: 'bk_cat_confirmed',
        status: BookingStatus.confirmed,
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
      );
      final bookingPending = createTestBooking(
        id: 'bk_cat_pending',
        status: BookingStatus.pending,
        scheduledDate: DateTime.now().add(const Duration(days: 4)),
      );
      final bookingInProgress = createTestBooking(
        id: 'bk_cat_inprogress',
        status: BookingStatus.inProgress,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      );
      final bookingCompleted = createTestBooking(
        id: 'bk_cat_completed',
        status: BookingStatus.completed,
        scheduledDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      final bookingCancelled = createTestBooking(
        id: 'bk_cat_cancelled',
        status: BookingStatus.cancelled,
        scheduledDate: DateTime.now().add(const Duration(days: 5)),
      );

      // Seed all 5 bookings into Device A
      deviceA.addBooking(bookingConfirmed);
      deviceA.addBooking(bookingPending);
      deviceA.addBooking(bookingInProgress);
      deviceA.addBooking(bookingCompleted);
      deviceA.addBooking(bookingCancelled);

      // Broadcast changes across the bus to Device B
      harness.syncBookingChange(deviceA, bookingConfirmed);
      harness.syncBookingChange(deviceA, bookingPending);
      harness.syncBookingChange(deviceA, bookingInProgress);
      harness.syncBookingChange(deviceA, bookingCompleted);
      harness.syncBookingChange(deviceA, bookingCancelled);

      // Verify overall count parity
      expect(deviceA.clientBookings.length, equals(5));
      expect(deviceB.clientBookings.length, equals(5));

      // 1. Upcoming Category: Confirmed + Pending
      final aUpcoming = deviceA.clientBookings
          .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending)
          .map((b) => b.id)
          .toSet();
      final bUpcoming = deviceB.clientBookings
          .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending)
          .map((b) => b.id)
          .toSet();
      expect(aUpcoming, equals({'bk_cat_confirmed', 'bk_cat_pending'}));
      expect(bUpcoming, equals(aUpcoming));

      // 2. In Progress Category
      final aInProgress = deviceA.clientBookings
          .where((b) => b.status == BookingStatus.inProgress)
          .map((b) => b.id)
          .toSet();
      final bInProgress = deviceB.clientBookings
          .where((b) => b.status == BookingStatus.inProgress)
          .map((b) => b.id)
          .toSet();
      expect(aInProgress, equals({'bk_cat_inprogress'}));
      expect(bInProgress, equals(aInProgress));

      // 3. Completed Category
      final aCompleted = deviceA.clientBookings
          .where((b) => b.status == BookingStatus.completed)
          .map((b) => b.id)
          .toSet();
      final bCompleted = deviceB.clientBookings
          .where((b) => b.status == BookingStatus.completed)
          .map((b) => b.id)
          .toSet();
      expect(aCompleted, equals({'bk_cat_completed'}));
      expect(bCompleted, equals(aCompleted));

      // 4. Cancelled Category
      final aCancelled = deviceA.clientBookings
          .where((b) => b.status == BookingStatus.cancelled)
          .map((b) => b.id)
          .toSet();
      final bCancelled = deviceB.clientBookings
          .where((b) => b.status == BookingStatus.cancelled)
          .map((b) => b.id)
          .toSet();
      expect(aCancelled, equals({'bk_cat_cancelled'}));
      expect(bCancelled, equals(aCancelled));
    });

    test('2. Real-Time Booking Creation & Ingestion Idempotency Across Devices', () async {
      final newBooking = createTestBooking(
        id: 'bk_idempotent_01',
        status: BookingStatus.confirmed,
      );

      // Device A adds new booking
      final addedOnA = deviceA.addBooking(newBooking);
      expect(addedOnA, isTrue);

      // Broadcast payload to Device B
      harness.syncBookingChange(deviceA, newBooking);

      expect(deviceB.clientBookings.any((b) => b.id == 'bk_idempotent_01'), isTrue);
      expect(deviceB.clientBookings.where((b) => b.id == 'bk_idempotent_01').length, equals(1));

      // Re-broadcasting the identical payload must NOT duplicate entries (idempotent CDC)
      harness.syncBookingChange(deviceA, newBooking);
      expect(deviceB.clientBookings.where((b) => b.id == 'bk_idempotent_01').length, equals(1));

      // Re-invoking addBookingAsync on Device B is also idempotent
      final reAdd = await deviceB.addBookingAsync(newBooking);
      expect(reAdd, isTrue);
      expect(deviceB.clientBookings.where((b) => b.id == 'bk_idempotent_01').length, equals(1));
    });

    test('3. Status Progression Lifecycle Propagation Across All 4 States', () {
      final lifecycleBooking = createTestBooking(
        id: 'bk_lifecycle_01',
        status: BookingStatus.pending,
      );

      deviceA.addBooking(lifecycleBooking);
      harness.syncBookingChange(deviceA, lifecycleBooking);

      expect(deviceB.clientBookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.pending));

      // Step 1: Detailer confirms booking
      final confirmedPayload = {
        'id': 'bk_lifecycle_01',
        'status': 'confirmed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      harness.syncRawPayload(detailerRepo, confirmedPayload);
      expect(deviceB.clientBookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.confirmed));

      // Step 2: Detailer moves booking to in_progress
      final inProgressPayload = {
        'id': 'bk_lifecycle_01',
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      harness.syncRawPayload(detailerRepo, inProgressPayload);
      expect(deviceB.clientBookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.inProgress));

      // Step 3: Detailer completes booking
      final completedPayload = {
        'id': 'bk_lifecycle_01',
        'status': 'completed',
        'completion_date': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      harness.syncRawPayload(detailerRepo, completedPayload);
      expect(deviceB.clientBookings.firstWhere((b) => b.id == 'bk_lifecycle_01').status, equals(BookingStatus.completed));
    });

    test('4. Dual-Key (Client ID & Client Email) Cross-Device Resolution & Privacy Protection', () async {
      // Device A books as guest (clientId is null), but supplies clientEmail
      final guestBooking = createTestBooking(
        id: 'bk_guest_dualkey_01',
        clientId: null,
        clientEmail: 'alex.mercer@example.com',
      );
      deviceA.addBooking(guestBooking);
      harness.syncBookingChange(deviceA, guestBooking);

      // Device B is logged in as alex.mercer@example.com (with different user ID)
      expect(deviceB.clientBookings.any((b) => b.id == 'bk_guest_dualkey_01'), isTrue);

      // Privacy Check: Broadcast a booking belonging to another user
      final strangerBooking = createTestBooking(
        id: 'bk_stranger_private_99',
        clientId: 'usr_stranger_888',
        clientEmail: 'stranger@example.com',
      );
      harness.bus.broadcastToAll(strangerBooking.toSupabase());

      // Device B must NOT display stranger's booking in clientBookings
      expect(deviceB.clientBookings.any((b) => b.id == 'bk_stranger_private_99'), isFalse);
    });

    test('5. Concurrent Slot Conflict Guards on Dual Devices & Slot Release on Cancellation', () {
      final sharedDate = DateTime(2026, 12, 1);
      const sharedSlot = '10:00 AM - 2:00 PM';

      final bookingFromDeviceA = createTestBooking(
        id: 'bk_slot_dev_a',
        clientId: 'usr_client_01',
        clientEmail: 'alex.mercer@example.com',
        scheduledDate: sharedDate,
        scheduledTimeSlot: sharedSlot,
      );

      final bookingFromDeviceB = createTestBooking(
        id: 'bk_slot_dev_b',
        clientId: 'usr_client_02',
        clientEmail: 'jordan@example.com',
        scheduledDate: sharedDate,
        scheduledTimeSlot: sharedSlot,
      );

      // Device A claims the slot first
      final successA = detailerRepo.addBooking(bookingFromDeviceA);
      expect(successA, isTrue);
      harness.syncBookingChange(detailerRepo, bookingFromDeviceA);

      // Verify slot is now locked
      expect(detailerRepo.isSlotConflictedByBooking(sharedDate, sharedSlot), isTrue);

      // Device B attempts to claim the exact same slot
      final successB = detailerRepo.addBooking(bookingFromDeviceB);
      expect(successB, isFalse); // Rejected by race condition guard

      // Device A cancels booking
      detailerRepo.cancelBooking('bk_slot_dev_a');
      harness.syncRawPayload(detailerRepo, {
        'id': 'bk_slot_dev_a',
        'status': 'cancelled',
      });

      // Slot is released immediately
      expect(detailerRepo.isSlotConflictedByBooking(sharedDate, sharedSlot), isFalse);

      // Device B retries booking and now succeeds
      final retryB = detailerRepo.addBooking(bookingFromDeviceB);
      expect(retryB, isTrue);
    });
  });
}
