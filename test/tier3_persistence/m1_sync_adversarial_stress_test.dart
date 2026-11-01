import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/multi_device_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M1 Adversarial Stress Testing & Empirical Verification', () {
    late MultiDeviceTestHarness harness;
    late JobRepository clientA;
    late JobRepository clientB;
    late JobRepository detailer;

    const testPackage = ServicePackage(
      id: 'pkg_adv_stress_01',
      title: 'Full Ceramic & Paint Correction',
      description: 'Adversarial stress test detailing package',
      basePrice: 850.0,
      estimatedDuration: '4 hrs',
      includes: ['Decon Wash', 'Stage 2 Polish', 'Ceramic 9H'],
    );

    BookingAppointment createBooking({
      required String id,
      String? clientId = 'usr_client_01',
      String clientEmail = 'client1@example.com',
      String detailerId = 'usr_detailer_pro',
      BookingStatus status = BookingStatus.confirmed,
      DateTime? scheduledDate,
      String scheduledTimeSlot = '9:00 AM - 12:00 PM',
      double totalPrice = 850.0,
      double depositAmount = 200.0,
    }) {
      return BookingAppointment(
        id: id,
        clientId: clientId,
        detailerId: detailerId,
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Precision Detailing',
        detailerAvatar: '',
        clientName: 'Alex Mercer',
        clientPhone: '(512) 555-1234',
        clientEmail: clientEmail,
        vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin TX',
        scheduledDate: scheduledDate ?? DateTime(2026, 12, 15), // Tuesday (open)
        scheduledTimeSlot: scheduledTimeSlot,
        totalPrice: totalPrice,
        depositAmount: depositAmount,
        status: status,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      harness = MultiDeviceTestHarness();

      clientA = await harness.createClientDeviceSession(
        deviceId: 'device_client_a',
        userId: 'usr_client_01',
        email: 'client1@example.com',
        displayName: 'Client Device A',
      );

      clientB = await harness.createClientDeviceSession(
        deviceId: 'device_client_b',
        userId: 'usr_client_02',
        email: 'client2@example.com',
        displayName: 'Client Device B',
      );

      detailer = await harness.createDetailerSession(
        detailerId: 'usr_detailer_pro',
        email: 'marcus@apexprecision.com',
        displayName: 'Marcus Vance',
        businessName: 'Apex Precision Detailing',
      );
    });

    tearDown(() {
      harness.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 1: Burst CDC Payload Ingestion
    // ─────────────────────────────────────────────────────────────────────────
    group('Scenario 1: Burst CDC Payload Ingestion', () {
      test('1.1 Rapid Ingestion of 60 Updates across All Status Transitions on a Single Booking', () async {
        final initial = createBooking(
          id: 'bk_burst_01',
          status: BookingStatus.pending,
        );

        // Initial creation registered on Detailer and synced across bus to all listening sessions
        detailer.addBooking(initial, allowOverbooking: true);
        harness.bus.broadcastToAll(initial.toSupabase());

        expect(detailer.bookings.where((b) => b.id == 'bk_burst_01').length, equals(1));
        expect(clientA.bookings.where((b) => b.id == 'bk_burst_01').length, equals(1));

        // Sequence of 60 rapid status transitions
        final statusCycle = [
          BookingStatus.pending,
          BookingStatus.confirmed,
          BookingStatus.inProgress,
          BookingStatus.completed,
          BookingStatus.confirmed,
          BookingStatus.inProgress,
        ];

        int listenerNotifications = 0;
        void listener() => listenerNotifications++;
        clientA.addListener(listener);

        for (int i = 0; i < 60; i++) {
          final nextStatus = statusCycle[i % statusCycle.length];
          final payload = {
            'id': 'bk_burst_01',
            'client_id': 'usr_client_01',
            'detailer_id': 'usr_detailer_pro',
            'status': nextStatus.name,
            'status_formatted': nextStatus.name,
            'client_notes': 'Burst iteration $i',
          };
          harness.bus.broadcastToAll(payload);
        }

        // Final payload to cancelled
        harness.bus.broadcastToAll({
          'id': 'bk_burst_01',
          'client_id': 'usr_client_01',
          'detailer_id': 'usr_detailer_pro',
          'status': 'cancelled',
          'client_notes': 'Final cancelled status',
        });

        clientA.removeListener(listener);

        // Verify zero crashes, memory consistency (exactly 1 booking retained, no duplicates)
        expect(detailer.bookings.where((b) => b.id == 'bk_burst_01').length, equals(1));
        expect(clientA.bookings.where((b) => b.id == 'bk_burst_01').length, equals(1));
        expect(clientA.bookings.firstWhere((b) => b.id == 'bk_burst_01').status, equals(BookingStatus.cancelled));
        expect(detailer.bookings.firstWhere((b) => b.id == 'bk_burst_01').status, equals(BookingStatus.cancelled));
        expect(listenerNotifications, greaterThanOrEqualTo(60));
      });

      test('1.2 Concurrent Multi-Booking Burst (10 Bookings x 10 Rapid Updates = 100 CDC Events)', () async {
        final bookings = List.generate(
          10,
          (index) => createBooking(
            id: 'bk_multi_burst_$index',
            scheduledDate: DateTime(2026, 12, 15).add(Duration(days: index)),
            status: BookingStatus.pending,
          ),
        );

        for (final b in bookings) {
          detailer.addBooking(b, allowOverbooking: true);
          harness.bus.broadcastToAll(b.toSupabase());
        }

        expect(detailer.bookings.length, equals(10));
        expect(clientA.bookings.length, equals(10));

        // Interleaved rapid burst updates across all 10 bookings
        for (int cycle = 0; cycle < 10; cycle++) {
          for (int bIdx = 0; bIdx < 10; bIdx++) {
            final nextStatus = cycle == 9 ? BookingStatus.completed : BookingStatus.inProgress;
            harness.bus.broadcastToAll({
              'id': 'bk_multi_burst_$bIdx',
              'client_id': 'usr_client_01',
              'detailer_id': 'usr_detailer_pro',
              'status': nextStatus.name,
              'client_notes': 'Cycle $cycle for booking $bIdx',
            });
          }
        }

        // Verify count and final status across all sessions
        expect(clientA.bookings.length, equals(10));
        expect(detailer.bookings.length, equals(10));
        for (int bIdx = 0; bIdx < 10; bIdx++) {
          final bA = clientA.bookings.firstWhere((b) => b.id == 'bk_multi_burst_$bIdx');
          final bD = detailer.bookings.firstWhere((b) => b.id == 'bk_multi_burst_$bIdx');
          expect(bA.status, equals(BookingStatus.completed));
          expect(bD.status, equals(BookingStatus.completed));
        }
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 2: Simultaneous Mutual Cancellation
    // ─────────────────────────────────────────────────────────────────────────
    group('Scenario 2: Simultaneous Mutual Cancellation', () {
      test('2.1 Client & Detailer Cancel Same Appointment Concurrently (Zero Deadlock, Convergence)', () async {
        final targetDate = DateTime(2026, 12, 15);
        const targetSlot = '9:00 AM - 12:00 PM';

        final booking = createBooking(
          id: 'bk_mutual_cancel_01',
          scheduledDate: targetDate,
          scheduledTimeSlot: targetSlot,
          status: BookingStatus.confirmed,
        );

        detailer.addBooking(booking, allowOverbooking: true);
        clientA.addBooking(booking, allowOverbooking: true);

        expect(detailer.isSlotConflictedByBooking(targetDate, targetSlot), isTrue);

        // Simulate simultaneous cancellation triggered at the exact same time
        final futureClientCancel = clientA.cancelBooking('bk_mutual_cancel_01');
        final futureDetailerCancel = detailer.cancelBooking('bk_mutual_cancel_01');

        await Future.wait([futureClientCancel, futureDetailerCancel]);

        // Cross-propagate cancellation payloads across the bus simultaneously
        harness.syncRawPayload(clientA, {
          'id': 'bk_mutual_cancel_01',
          'client_id': 'usr_client_01',
          'detailer_id': 'usr_detailer_pro',
          'status': 'cancelled',
        });
        harness.syncRawPayload(detailer, {
          'id': 'bk_mutual_cancel_01',
          'client_id': 'usr_client_01',
          'detailer_id': 'usr_detailer_pro',
          'status': 'cancelled',
        });

        // 1. Both sessions converge to cancelled
        expect(clientA.bookings.firstWhere((b) => b.id == 'bk_mutual_cancel_01').status, equals(BookingStatus.cancelled));
        expect(detailer.bookings.firstWhere((b) => b.id == 'bk_mutual_cancel_01').status, equals(BookingStatus.cancelled));

        // 2. Slot is instantly released on both
        expect(detailer.isSlotConflictedByBooking(targetDate, targetSlot), isFalse);

        // 3. Absence of duplicate records
        expect(clientA.bookings.where((b) => b.id == 'bk_mutual_cancel_01').length, equals(1));
        expect(detailer.bookings.where((b) => b.id == 'bk_mutual_cancel_01').length, equals(1));
      });

      test('2.2 Repeated Redundant Cancellation Flood (Idempotency Guard)', () async {
        final booking = createBooking(
          id: 'bk_flood_cancel',
          status: BookingStatus.confirmed,
        );

        detailer.addBooking(booking, allowOverbooking: true);
        clientA.addBooking(booking, allowOverbooking: true);

        // Flood 30 redundant cancellation events
        for (int i = 0; i < 30; i++) {
          detailer.cancelBooking('bk_flood_cancel');
          harness.syncRawPayload(detailer, {
            'id': 'bk_flood_cancel',
            'client_id': 'usr_client_01',
            'detailer_id': 'usr_detailer_pro',
            'status': 'cancelled',
          });
        }

        expect(clientA.bookings.where((b) => b.id == 'bk_flood_cancel').length, equals(1));
        expect(clientA.bookings.firstWhere((b) => b.id == 'bk_flood_cancel').status, equals(BookingStatus.cancelled));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 3: Slot Lockout & Re-Booking Cycle
    // ─────────────────────────────────────────────────────────────────────────
    group('Scenario 3: Slot Lockout & Re-Booking Cycle', () {
      test('3.1 Full Lifecycle: Lockout -> Cancellation Release -> Immediate Re-booking by Secondary Client', () async {
        final slotDate = DateTime(2026, 12, 15); // Tuesday (open)
        const slotTime = '9:00 AM - 12:00 PM';

        // Client B sets active studio to Marcus's studio to see real-time slot availability
        clientB.activeStudioDetailerId = 'usr_detailer_pro';

        final clientABooking = createBooking(
          id: 'bk_lockout_client_a',
          clientId: 'usr_client_01',
          clientEmail: 'client1@example.com',
          scheduledDate: slotDate,
          scheduledTimeSlot: slotTime,
          status: BookingStatus.confirmed,
        );

        // 1. Client A books slot
        final addedA = detailer.addBooking(clientABooking);
        expect(addedA, isTrue);
        clientA.addBooking(clientABooking);
        harness.syncBookingChange(detailer, clientABooking);

        // 2. Verify Lockout: Slot is conflicted on Detailer
        expect(detailer.isSlotConflictedByBooking(slotDate, slotTime), isTrue);

        // Secondary client attempts to book same slot -> must be rejected
        final clientBBooking = createBooking(
          id: 'bk_lockout_client_b',
          clientId: 'usr_client_02',
          clientEmail: 'client2@example.com',
          scheduledDate: slotDate,
          scheduledTimeSlot: slotTime,
          status: BookingStatus.confirmed,
        );

        final addedBConflict = detailer.addBooking(clientBBooking);
        expect(addedBConflict, isFalse, reason: 'Secondary client booking must be rejected due to slot lockout');

        // 3. Client A cancels booking -> instant release
        await detailer.cancelBooking('bk_lockout_client_a');
        harness.syncRawPayload(detailer, {
          'id': 'bk_lockout_client_a',
          'detailer_id': 'usr_detailer_pro',
          'client_id': 'usr_client_01',
          'status': 'cancelled',
        });

        expect(detailer.isSlotConflictedByBooking(slotDate, slotTime), isFalse,
            reason: 'Slot must be released immediately upon cancellation');

        // 4. Client B immediately re-books the freed slot -> must succeed
        final addedBSuccess = detailer.addBooking(clientBBooking);
        expect(addedBSuccess, isTrue, reason: 'Client B must be able to claim the freed slot');
        clientB.addBooking(clientBBooking);
        harness.syncBookingChange(detailer, clientBBooking);

        // Slot is locked out again by Client B
        expect(detailer.isSlotConflictedByBooking(slotDate, slotTime), isTrue);

        // Verify privacy isolation: Client A's clientBookings does NOT show Client B's booking
        expect(clientA.clientBookings.any((b) => b.id == 'bk_lockout_client_b'), isFalse);
        expect(clientB.clientBookings.any((b) => b.id == 'bk_lockout_client_b'), isTrue);
      });

      test('3.2 Rapid 10-Cycle Stress Loop: Repeated Book -> Cancel -> Free -> Rebook', () async {
        final loopDate = DateTime(2026, 12, 15); // Tuesday (open)
        const loopSlot = '1:00 PM - 4:00 PM';

        for (int cycle = 0; cycle < 10; cycle++) {
          final isEven = cycle % 2 == 0;
          final bookingId = 'bk_cycle_${cycle}_${isEven ? "a" : "b"}';
          final clientId = isEven ? 'usr_client_01' : 'usr_client_02';
          final clientEmail = isEven ? 'client1@example.com' : 'client2@example.com';

          final booking = createBooking(
            id: bookingId,
            clientId: clientId,
            clientEmail: clientEmail,
            scheduledDate: loopDate,
            scheduledTimeSlot: loopSlot,
          );

          // 1. Slot must be free before booking
          expect(detailer.isSlotConflictedByBooking(loopDate, loopSlot), isFalse,
              reason: 'Cycle $cycle: Slot must be available before booking');

          // 2. Book slot
          final booked = detailer.addBooking(booking);
          expect(booked, isTrue, reason: 'Cycle $cycle: Booking must succeed');
          harness.syncBookingChange(detailer, booking);

          // 3. Slot must now be locked
          expect(detailer.isSlotConflictedByBooking(loopDate, loopSlot), isTrue,
              reason: 'Cycle $cycle: Slot must be locked after booking');

          // 4. Cancel booking
          await detailer.cancelBooking(bookingId);
          harness.syncRawPayload(detailer, {
            'id': bookingId,
            'detailer_id': 'usr_detailer_pro',
            'client_id': clientId,
            'status': 'cancelled',
          });

          // 5. Slot must be instantly freed
          expect(detailer.isSlotConflictedByBooking(loopDate, loopSlot), isFalse,
              reason: 'Cycle $cycle: Slot must be freed after cancellation');
        }
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 4: Malformed CDC Payloads & Ingestion Hardening
    // ─────────────────────────────────────────────────────────────────────────
    group('Scenario 4: Malformed CDC Payloads & Ingestion Hardening', () {
      test('4.1 Ingestion of Empty Map and Null/Empty ID Payloads (No Crash, No State Corruption)', () {
        final validBooking = createBooking(id: 'bk_safe_01');
        detailer.addBooking(validBooking, allowOverbooking: true);
        clientA.addBooking(validBooking, allowOverbooking: true);

        // Ingest completely empty payload
        clientA.simulateRealtimeBookingPayload({});
        expect(clientA.bookings.length, equals(1));

        // Ingest payload with explicit null ID
        clientA.simulateRealtimeBookingPayload({'id': null, 'status': 'confirmed'});
        expect(clientA.bookings.length, equals(1));

        // Ingest payload with empty string ID
        clientA.simulateRealtimeBookingPayload({'id': '', 'status': 'confirmed'});
        expect(clientA.bookings.length, equals(1));

        // Existing booking remains unharmed
        expect(clientA.bookings.first.id, equals('bk_safe_01'));
      });

      test('4.2 Ingestion of Corrupted Timestamps & Null Slots (Graceful Fallback)', () {
        // Unknown booking with malformed date format
        final malformedPayload = {
          'id': 'bk_bad_date_01',
          'client_id': 'usr_client_01',
          'client_email': 'client1@example.com',
          'detailer_id': 'usr_detailer_pro',
          'scheduled_date': 'NOT_A_VALID_DATE_STRING',
          'scheduled_time_slot': null,
          'status': 'confirmed',
        };

        // Should not throw uncaught format exception
        expect(() => clientA.simulateRealtimeBookingPayload(malformedPayload), returnsNormally);

        // Booking is parsed using fallback DateTime.now() and default slot
        final parsed = clientA.bookings.firstWhere((b) => b.id == 'bk_bad_date_01');
        expect(parsed.scheduledDate, isNotNull);
        expect(parsed.scheduledTimeSlot, isNotEmpty);
      });

      test('4.3 Ingestion of Invalid / Corrupted Status Strings (Graceful Parsing)', () {
        final initial = createBooking(id: 'bk_status_corrupt');
        clientA.addBooking(initial, allowOverbooking: true);

        // Inject unknown / invalid status string
        final corruptStatusPayload = {
          'id': 'bk_status_corrupt',
          'status': 'TOTALLY_UNKNOWN_STATUS_99999',
        };

        expect(() => clientA.simulateRealtimeBookingPayload(corruptStatusPayload), returnsNormally);
        final current = clientA.bookings.firstWhere((b) => b.id == 'bk_status_corrupt');
        // Defaults safely to confirmed or preserves valid enum
        expect(BookingStatus.values.contains(current.status), isTrue);
      });

      test('4.4 Foreign UUID Ingestion Rejected by Scoped Ingestion Guard', () {
        // A foreign booking belonging to unrelated client and unrelated detailer
        final foreignPayload = {
          'id': 'bk_foreign_attack_01',
          'client_id': 'usr_foreign_attacker_99',
          'client_email': 'attacker@darkweb.io',
          'detailer_id': 'usr_unknown_studio_xyz',
          'status': 'confirmed',
          'scheduled_date': '2026-12-25',
          'scheduled_time_slot': '10:00 AM',
        };

        // Broadcast to clientA, clientB, detailer
        harness.bus.broadcastToAll(foreignPayload);

        // None of the sessions should accept or store this foreign booking!
        expect(clientA.bookings.any((b) => b.id == 'bk_foreign_attack_01'), isFalse,
            reason: 'Client A must NOT ingest foreign booking');
        expect(clientB.bookings.any((b) => b.id == 'bk_foreign_attack_01'), isFalse,
            reason: 'Client B must NOT ingest foreign booking');
        expect(detailer.bookings.any((b) => b.id == 'bk_foreign_attack_01'), isFalse,
            reason: 'Detailer must NOT ingest foreign booking');
      });

      test('4.5 Corrupted Types Targeting Existing Booking (Preserves Intact Model)', () {
        final validBooking = createBooking(
          id: 'bk_target_intact',
          totalPrice: 850.0,
          status: BookingStatus.confirmed,
        );
        clientA.addBooking(validBooking, allowOverbooking: true);

        // Send payload with type violations (total_price as String, package as invalid type)
        final typeCorruptPayload = {
          'id': 'bk_target_intact',
          'total_price': 'INVALID_STRING_PRICE',
          'status': 'in_progress',
        };

        expect(() => clientA.simulateRealtimeBookingPayload(typeCorruptPayload), returnsNormally);

        // Existing booking must NOT be corrupted or wiped
        final retained = clientA.bookings.firstWhere((b) => b.id == 'bk_target_intact');
        expect(retained.totalPrice, equals(850.0));
      });

      test('4.6 Malformed Deletion Payloads (isDelete: true) with Null/Empty/Nonexistent IDs', () {
        final booking = createBooking(id: 'bk_delete_test');
        clientA.addBooking(booking, allowOverbooking: true);

        // 1. isDelete with null ID
        expect(() => clientA.simulateRealtimeBookingPayload({'id': null}, isDelete: true), returnsNormally);
        expect(clientA.bookings.length, equals(1));

        // 2. isDelete with empty ID
        expect(() => clientA.simulateRealtimeBookingPayload({'id': ''}, isDelete: true), returnsNormally);
        expect(clientA.bookings.length, equals(1));

        // 3. isDelete with non-existent ID
        expect(() => clientA.simulateRealtimeBookingPayload({'id': 'bk_nonexistent'}, isDelete: true), returnsNormally);
        expect(clientA.bookings.length, equals(1));

        // 4. isDelete with matching ID deletes successfully
        expect(() => clientA.simulateRealtimeBookingPayload({'id': 'bk_delete_test'}, isDelete: true), returnsNormally);
        expect(clientA.bookings.isEmpty, isTrue);
      });

      test('4.7 Malformed Deletion Payloads with Integer / Non-String IDs (Type Safety Check)', () {
        // Test whether isDelete with integer ID (e.g. 12345) throws uncaught TypeError or handles safely
        final booking = createBooking(id: 'bk_int_test');
        clientA.addBooking(booking, allowOverbooking: true);

        // This tests whether simulateRealtimeBookingPayload is immune to integer IDs in isDelete payloads
        // Note: If (record['id']) as String? is used without try-catch, it throws TypeError
        try {
          clientA.simulateRealtimeBookingPayload({'id': 12345}, isDelete: true);
        } catch (e) {
          // If it throws, we catch and fail test with clear finding
          fail('simulateRealtimeBookingPayload threw an uncaught exception on integer ID: $e');
        }

        expect(clientA.bookings.length, equals(1));
      });
    });
  });
}
