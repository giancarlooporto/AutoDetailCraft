import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. Dual-Address Privacy Leak Stress Tests
  // =========================================================================
  group('1. Dual-Address Privacy Leak Stress Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1.1 Dual-Address Isolation: Client home address is inherited on activation, preserved on studio edit, and untouched by client edit', () async {
      final repo = JobRepository();
      await repo.init();

      // Step 1: Create client with private home address and gate code
      final privateClient = repo.currentUser.copyWith(
        role: UserRole.client,
        streetAddress: '123 Secret Home Way',
        unitOrApt: 'Gate #9999',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        latitude: 30.2672,
        longitude: -97.7431,
        // Studio address initially empty
        studioStreetAddress: '',
        studioUnitOrApt: '',
        studioCity: '',
        studioState: '',
        studioPostalCode: '',
        studioLatitude: null,
        studioLongitude: null,
      );
      await repo.updateCurrentUser(privateClient);

      expect(repo.currentUser.streetAddress, '123 Secret Home Way');
      expect(repo.currentUser.unitOrApt, 'Gate #9999');
      expect(repo.currentUser.studioStreetAddress, '');

      // Step 2: Activate detailer mode -> verify address is inherited
      await repo.enableDetailerMode();

      expect(repo.currentUser.role, UserRole.detailer);
      expect(repo.currentUser.studioStreetAddress, '123 Secret Home Way');
      expect(repo.currentUser.studioUnitOrApt, 'Gate #9999');
      expect(repo.currentUser.studioCity, 'Austin');
      expect(repo.currentUser.studioState, 'TX');
      expect(repo.currentUser.studioPostalCode, '78701');
      expect(repo.currentUser.studioLatitude, 30.2672);
      expect(repo.currentUser.studioLongitude, -97.7431);

      // Verify client home address is intact
      expect(repo.currentUser.streetAddress, '123 Secret Home Way');
      expect(repo.currentUser.unitOrApt, 'Gate #9999');

      // Step 3: Update commercial studio address to public shop
      await repo.updateStudioAddress(
        street: '789 Commercial Boulevard',
        unit: 'Suite 100',
        city: 'Austin',
        state: 'TX',
        postalCode: '78702',
        latitude: 30.2700,
        longitude: -97.7300,
      );

      // Verify studio address was updated
      expect(repo.currentUser.studioStreetAddress, '789 Commercial Boulevard');
      expect(repo.currentUser.studioUnitOrApt, 'Suite 100');
      expect(repo.currentUser.studioCity, 'Austin');
      expect(repo.currentUser.studioState, 'TX');
      expect(repo.currentUser.studioPostalCode, '78702');
      expect(repo.currentUser.studioLatitude, 30.2700);
      expect(repo.currentUser.studioLongitude, -97.7300);

      // Step 4: CRITICAL PRIVACY CHECK — Verify client home address remains 100% untouched
      expect(repo.currentUser.streetAddress, '123 Secret Home Way');
      expect(repo.currentUser.unitOrApt, 'Gate #9999');
      expect(repo.currentUser.city, 'Austin');
      expect(repo.currentUser.state, 'TX');
      expect(repo.currentUser.postalCode, '78701');
      expect(repo.currentUser.latitude, 30.2672);
      expect(repo.currentUser.longitude, -97.7431);

      // Step 5: Update client home address -> verify studio address is NOT mutated
      await repo.updateClientAddress(
        streetAddress: '999 Private Mountain Rd',
        unitOrApt: 'Gate #0001',
        city: 'West Lake Hills',
        state: 'TX',
        postalCode: '78746',
        latitude: 30.2900,
        longitude: -97.8000,
      );

      // Verify client home address was updated
      expect(repo.currentUser.streetAddress, '999 Private Mountain Rd');
      expect(repo.currentUser.unitOrApt, 'Gate #0001');
      expect(repo.currentUser.city, 'West Lake Hills');
      expect(repo.currentUser.state, 'TX');
      expect(repo.currentUser.postalCode, '78746');
      expect(repo.currentUser.latitude, 30.2900);
      expect(repo.currentUser.longitude, -97.8000);

      // Verify studio address is 100% UNTOUCHED by client address update
      expect(repo.currentUser.studioStreetAddress, '789 Commercial Boulevard');
      expect(repo.currentUser.studioUnitOrApt, 'Suite 100');
      expect(repo.currentUser.studioCity, 'Austin');
      expect(repo.currentUser.studioState, 'TX');
      expect(repo.currentUser.studioPostalCode, '78702');
      expect(repo.currentUser.studioLatitude, 30.2700);
      expect(repo.currentUser.studioLongitude, -97.7300);
    });

    test('1.2 Address formatters strictly isolate client and studio representations', () {
      const dualProfile = UserProfile(
        id: 'usr_dual_test',
        username: 'dual_user',
        displayName: 'Dual User',
        // Private home
        streetAddress: '123 Secret Home Way',
        unitOrApt: 'Gate #9999',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        // Commercial studio
        studioStreetAddress: '789 Commercial Blvd',
        studioUnitOrApt: 'Suite 100',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78702',
      );

      expect(dualProfile.formattedClientAddress, '123 Secret Home Way, Gate #9999, Austin, TX 78701');
      expect(dualProfile.formattedStudioAddress, '789 Commercial Blvd, Suite 100, Austin, TX 78702');

      // Neither formatter leaks into the other
      expect(dualProfile.formattedClientAddress.contains('Commercial Blvd'), isFalse);
      expect(dualProfile.formattedClientAddress.contains('Suite 100'), isFalse);
      expect(dualProfile.formattedStudioAddress.contains('Secret Home Way'), isFalse);
      expect(dualProfile.formattedStudioAddress.contains('Gate #9999'), isFalse);
    });
  });

  // =========================================================================
  // 2. Rapid Re-entrant Role Toggling Stress Tests
  // =========================================================================
  group('2. Rapid Re-entrant Role Toggling Stress Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('2.1 Sequential Rapid Role Toggling: 50 successive role switches do not wipe or corrupt studio address', () async {
      final repo = JobRepository();
      await repo.init();

      // Set up user with distinct client and studio addresses
      final initialUser = repo.currentUser.copyWith(
        role: UserRole.client,
        streetAddress: '123 Secret Home Way',
        unitOrApt: 'Gate #9999',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        studioStreetAddress: '789 Commercial Blvd',
        studioUnitOrApt: 'Suite 100',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78702',
        studioLatitude: 30.2700,
        studioLongitude: -97.7300,
      );
      await repo.updateCurrentUser(initialUser);

      // Perform 50 rapid sequential role toggles
      for (int i = 0; i < 50; i++) {
        await repo.toggleHostMode();
        final expectedRole = (i % 2 == 0) ? UserRole.detailer : UserRole.client;
        expect(repo.currentUser.role, expectedRole, reason: 'Role mismatch at toggle iteration $i');

        // Studio address must NEVER be wiped or corrupted across toggles
        expect(repo.currentUser.studioStreetAddress, '789 Commercial Blvd', reason: 'Studio street wiped at toggle $i');
        expect(repo.currentUser.studioUnitOrApt, 'Suite 100');
        expect(repo.currentUser.studioCity, 'Austin');
        expect(repo.currentUser.studioState, 'TX');
        expect(repo.currentUser.studioPostalCode, '78702');

        // Client address must NEVER be corrupted
        expect(repo.currentUser.streetAddress, '123 Secret Home Way', reason: 'Client street corrupted at toggle $i');
        expect(repo.currentUser.unitOrApt, 'Gate #9999');
      }

      // After 50 toggles (even number), role returns to initial client role
      expect(repo.currentUser.role, UserRole.client);
      expect(repo.currentUser.studioStreetAddress, '789 Commercial Blvd');
      expect(repo.currentUser.streetAddress, '123 Secret Home Way');
    });

    test('2.2 Concurrent Re-entrant Role Toggling: 50 concurrent toggles do not crash or corrupt addresses', () async {
      final repo = JobRepository();
      await repo.init();

      final initialUser = repo.currentUser.copyWith(
        role: UserRole.client,
        streetAddress: '123 Secret Home Way',
        unitOrApt: 'Gate #9999',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        studioStreetAddress: '789 Commercial Blvd',
        studioUnitOrApt: 'Suite 100',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78702',
      );
      await repo.updateCurrentUser(initialUser);

      // Fire 50 concurrent toggles
      await Future.wait(List.generate(50, (_) => repo.toggleHostMode()));

      // Studio and client address data must remain intact despite concurrency
      expect(repo.currentUser.studioStreetAddress, '789 Commercial Blvd');
      expect(repo.currentUser.studioUnitOrApt, 'Suite 100');
      expect(repo.currentUser.streetAddress, '123 Secret Home Way');
      expect(repo.currentUser.unitOrApt, 'Gate #9999');
    });
  });

  // =========================================================================
  // 3. Malformed Ingestion & Legacy Boundary Stress Tests
  // =========================================================================
  group('3. Malformed Ingestion & Legacy Boundary Stress Tests', () {
    test('3.1 UserProfile.fromJson: handles missing keys, null objects, and empty JSON gracefully', () {
      expect(() => UserProfile.fromJson({}), returnsNormally);
      final emptyProfile = UserProfile.fromJson({});
      expect(emptyProfile.id, 'usr_you');
      expect(emptyProfile.streetAddress, '');
      expect(emptyProfile.studioStreetAddress, '');
      expect(emptyProfile.latitude, isNull);
      expect(emptyProfile.longitude, isNull);
      expect(emptyProfile.studioLatitude, isNull);
      expect(emptyProfile.studioLongitude, isNull);
    });

    test('3.2 REMEDIATED: UserProfile.fromJson parses numeric coordinates provided as String ("30.2672")', () {
      final numericStringJson = <String, dynamic>{
        'id': 'usr_num_str',
        'street_address': '123 Test St',
        'latitude': '30.2672',
        'longitude': '-97.7431',
      };

      final profile = UserProfile.fromJson(numericStringJson);
      expect(profile.latitude, 30.2672);
      expect(profile.longitude, -97.7431);
    });

    test('3.3 REMEDIATED: UserProfile.fromJson handles non-numeric corrupt string latitude ("abc") gracefully as null', () {
      final corruptCoordsJson = <String, dynamic>{
        'id': 'usr_corrupt_coords',
        'latitude': 'abc',
        'longitude': 'def',
      };

      final profile = UserProfile.fromJson(corruptCoordsJson);
      expect(profile.latitude, isNull);
      expect(profile.longitude, isNull);
    });

    test('3.4 REMEDIATED: UserProfile.fromJson handles studioLatitude as string without operator precedence errors', () {
      final corruptStudioJson = <String, dynamic>{
        'id': 'usr_corrupt_studio',
        'studioLatitude': 'abc',
        'studioLongitude': '-97.7300',
      };

      final profile = UserProfile.fromJson(corruptStudioJson);
      expect(profile.studioLatitude, isNull);
      expect(profile.studioLongitude, -97.7300);
    });

    test('3.5 BookingAppointment.fromJson: handles missing keys and empty JSON gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'bk_min_01',
        'detailerId': 'det_01',
        'detailerName': 'Detailer',
        'detailerBusinessName': 'Shop',
        'detailerAvatar': '',
        'clientName': 'Client',
        'clientPhone': '555-1234',
        'clientEmail': 'client@test.com',
        'vehicleYearMakeModel': '2024 Ford F-150',
        'vehicleSize': 'truckVan',
        'locationType': 'mobile',
        'clientAddress': '100 Main St',
        'scheduledDate': '2026-11-20',
        'scheduledTimeSlot': '10:00 AM',
        'totalPrice': 150.0,
        'depositAmount': 50.0,
      };

      expect(() => BookingAppointment.fromJson(minimalJson), returnsNormally);
      final booking = BookingAppointment.fromJson(minimalJson);
      expect(booking.clientUnitOrGateCode, isNull);
      expect(booking.latitude, isNull);
      expect(booking.longitude, isNull);
    });

    test('3.6 REMEDIATED: BookingAppointment.fromJson handles string coordinates gracefully without throwing', () {
      final corruptBookingJson = <String, dynamic>{
        'id': 'bk_corrupt_01',
        'detailerId': 'det_01',
        'detailerName': 'Detailer',
        'detailerBusinessName': 'Shop',
        'detailerAvatar': '',
        'clientName': 'Client',
        'clientPhone': '555-1234',
        'clientEmail': 'client@test.com',
        'vehicleYearMakeModel': '2024 Ford F-150',
        'vehicleSize': 'truckVan',
        'locationType': 'mobile',
        'clientAddress': '100 Main St',
        'scheduledDate': '2026-11-20',
        'scheduledTimeSlot': '10:00 AM',
        'totalPrice': 150.0,
        'depositAmount': 50.0,
        'latitude': 'abc',
        'longitude': 'def',
      };

      final booking = BookingAppointment.fromJson(corruptBookingJson);
      expect(booking.latitude, isNull);
      expect(booking.longitude, isNull);

      // Also verify valid string numeric coordinates parse cleanly
      final validStringBookingJson = Map<String, dynamic>.from(corruptBookingJson)
        ..['latitude'] = '30.2672'
        ..['longitude'] = '-97.7431';
      final validBooking = BookingAppointment.fromJson(validStringBookingJson);
      expect(validBooking.latitude, 30.2672);
      expect(validBooking.longitude, -97.7431);
    });

    test('3.7 BookingAppointment.fromJson: throws FormatException on invalid price formats', () {
      final invalidPriceJson = <String, dynamic>{
        'id': 'bk_invalid_price',
        'detailerId': 'det_01',
        'detailerName': 'Detailer',
        'detailerBusinessName': 'Shop',
        'detailerAvatar': '',
        'clientName': 'Client',
        'clientPhone': '555-1234',
        'clientEmail': 'client@test.com',
        'vehicleYearMakeModel': '2024 Ford F-150',
        'vehicleSize': 'truckVan',
        'locationType': 'mobile',
        'clientAddress': '100 Main St',
        'scheduledDate': '2026-11-20',
        'scheduledTimeSlot': '10:00 AM',
        'totalPrice': 'invalid_price',
        'depositAmount': 50.0,
      };

      expect(() => BookingAppointment.fromJson(invalidPriceJson), throwsA(isA<FormatException>()));
    });
  });
}
