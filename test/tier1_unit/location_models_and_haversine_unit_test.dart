import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/location_service.dart';
import 'package:detail_craft/services/job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. UserProfile Location Serialization & Deserialization
  // =========================================================================
  group('UserProfile Location Serialization & Deserialization', () {
    test('1.1 Roundtrip: Full client and studio structured address serialization (camelCase)', () {
      const profile = UserProfile(
        id: 'usr_loc_test_01',
        username: 'austin_detailer',
        displayName: 'Austin Detailer',
        businessName: 'Apex Auto Spa',
        location: 'Austin, TX',
        // Personal Client Address
        streetAddress: '1200 S Congress Ave',
        unitOrApt: 'Apt 304',
        city: 'Austin',
        state: 'TX',
        postalCode: '78704',
        latitude: 30.2505,
        longitude: -97.7495,
        // Commercial Studio Address
        studioStreetAddress: '500 E 4th St',
        studioUnitOrApt: 'Bay 2B',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78701',
        studioLatitude: 30.2655,
        studioLongitude: -97.7398,
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, 'usr_loc_test_01');
      expect(restored.streetAddress, '1200 S Congress Ave');
      expect(restored.unitOrApt, 'Apt 304');
      expect(restored.city, 'Austin');
      expect(restored.state, 'TX');
      expect(restored.postalCode, '78704');
      expect(restored.latitude, 30.2505);
      expect(restored.longitude, -97.7495);

      expect(restored.studioStreetAddress, '500 E 4th St');
      expect(restored.studioUnitOrApt, 'Bay 2B');
      expect(restored.studioCity, 'Austin');
      expect(restored.studioState, 'TX');
      expect(restored.studioPostalCode, '78701');
      expect(restored.studioLatitude, 30.2655);
      expect(restored.studioLongitude, -97.7398);
    });

    test('1.2 Deserialization: Handles Supabase/PostgREST snake_case keys correctly', () {
      final snakeJson = <String, dynamic>{
        'id': 'usr_snake_02',
        'username': 'snake_user',
        'displayName': 'Snake User',
        'street_address': '742 Evergreen Terrace',
        'unit_or_apt': 'Unit 1',
        'city': 'Springfield',
        'state': 'IL',
        'postal_code': '62704',
        'latitude': 39.7817,
        'longitude': -89.6501,
        'studio_street_address': '100 Industrial Pkwy',
        'studio_unit_or_apt': 'Shop C',
        'studio_city': 'Springfield',
        'studio_state': 'IL',
        'studio_postal_code': '62703',
        'studio_latitude': 39.7750,
        'studio_longitude': -89.6400,
      };

      final restored = UserProfile.fromJson(snakeJson);

      expect(restored.streetAddress, '742 Evergreen Terrace');
      expect(restored.unitOrApt, 'Unit 1');
      expect(restored.city, 'Springfield');
      expect(restored.state, 'IL');
      expect(restored.postalCode, '62704');
      expect(restored.latitude, 39.7817);
      expect(restored.longitude, -89.6501);

      expect(restored.studioStreetAddress, '100 Industrial Pkwy');
      expect(restored.studioUnitOrApt, 'Shop C');
      expect(restored.studioCity, 'Springfield');
      expect(restored.studioState, 'IL');
      expect(restored.studioPostalCode, '62703');
      expect(restored.studioLatitude, 39.7750);
      expect(restored.studioLongitude, -89.6400);
    });

    test('1.3 Backward Compatibility: Deserializes legacy JSON with only flat location string', () {
      final legacyJson = <String, dynamic>{
        'id': 'usr_legacy_03',
        'username': 'legacy_user',
        'displayName': 'Legacy User',
        'location': 'Dallas, Texas',
      };

      final restored = UserProfile.fromJson(legacyJson);

      expect(restored.location, 'Dallas, Texas');
      expect(restored.streetAddress, '');
      expect(restored.unitOrApt, '');
      expect(restored.city, '');
      expect(restored.state, '');
      expect(restored.postalCode, '');
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
      expect(restored.studioStreetAddress, '');
      expect(restored.studioLatitude, isNull);
    });

    test('1.4 copyWith: Preserves client home address when updating commercial studio address', () {
      const original = UserProfile(
        id: 'usr_iso_04',
        username: 'iso_user',
        displayName: 'Dual Address User',
        streetAddress: '900 Residential Lane',
        unitOrApt: 'Apt 1A',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        studioStreetAddress: '100 Old Studio Rd',
      );

      final updated = original.copyWith(
        studioStreetAddress: '200 New Studio Rd',
        studioCity: 'Round Rock',
      );

      expect(updated.studioStreetAddress, '200 New Studio Rd');
      expect(updated.studioCity, 'Round Rock');
      // Personal address strictly unchanged
      expect(updated.streetAddress, '900 Residential Lane');
      expect(updated.unitOrApt, 'Apt 1A');
      expect(updated.city, 'Austin');
      expect(updated.state, 'TX');
      expect(updated.postalCode, '78701');
    });

    test('1.5 Helper Getters: formattedClientAddress, formattedStudioAddress and coordinates', () {
      const full = UserProfile(
        id: 'usr_helpers_05',
        username: 'helpers_user',
        displayName: 'Helpers User',
        streetAddress: '100 Main St',
        unitOrApt: 'Ste 5',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        latitude: 30.2672,
        longitude: -97.7431,
        location: 'Austin, TX',
      );

      expect(full.formattedClientAddress, contains('100 Main St'));
      expect(full.formattedClientAddress, contains('Ste 5'));
      expect(full.formattedClientAddress, contains('Austin, TX 78701'));
      expect(full.hasClientAddress, isTrue);
      expect(full.hasStudioAddress, isFalse);
      expect(full.effectiveLatitude, 30.2672);
      expect(full.effectiveLongitude, -97.7431);
      expect(full.effectiveStudioLatitude, 30.2672); // Falls back to client lat
      expect(full.effectiveStudioLongitude, -97.7431);

      // If studio address is blank, formattedStudioAddress falls back to location
      expect(full.formattedStudioAddress, 'Austin, TX');
    });

    test('1.6 Defensive Coordinate Deserialization: Handles string-encoded numbers and invalid strings gracefully', () {
      // 1. Valid string-encoded coordinates in camelCase
      final camelStringJson = <String, dynamic>{
        'id': 'usr_str_camel_01',
        'streetAddress': '1200 S Congress Ave',
        'city': 'Austin',
        'state': 'TX',
        'postalCode': '78704',
        'latitude': '30.2672',
        'longitude': '-97.7431',
        'studioLatitude': '30.2655',
        'studioLongitude': '-97.7398',
      };

      expect(() => UserProfile.fromJson(camelStringJson), returnsNormally);
      final camelProfile = UserProfile.fromJson(camelStringJson);
      expect(camelProfile.latitude, equals(30.2672));
      expect(camelProfile.longitude, equals(-97.7431));
      expect(camelProfile.studioLatitude, equals(30.2655));
      expect(camelProfile.studioLongitude, equals(-97.7398));

      // 2. Valid string-encoded coordinates in snake_case (Supabase/PostgREST)
      final snakeStringJson = <String, dynamic>{
        'id': 'usr_str_snake_02',
        'street_address': '500 E 4th St',
        'city': 'Austin',
        'state': 'TX',
        'postal_code': '78701',
        'latitude': '30.2500',
        'longitude': '-97.7400',
        'studio_latitude': '30.2900',
        'studio_longitude': '-97.7500',
      };

      expect(() => UserProfile.fromJson(snakeStringJson), returnsNormally);
      final snakeProfile = UserProfile.fromJson(snakeStringJson);
      expect(snakeProfile.latitude, equals(30.2500));
      expect(snakeProfile.longitude, equals(-97.7400));
      expect(snakeProfile.studioLatitude, equals(30.2900));
      expect(snakeProfile.studioLongitude, equals(-97.7500));

      // 3. Corrupt/non-numeric strings and empty strings must fallback to null without throwing
      final corruptCoordsJson = <String, dynamic>{
        'id': 'usr_corrupt_coords_03',
        'latitude': 'invalid',
        'longitude': 'abc',
        'studioLatitude': '',
        'studioLongitude': '   ',
      };

      expect(() => UserProfile.fromJson(corruptCoordsJson), returnsNormally);
      final corruptProfile = UserProfile.fromJson(corruptCoordsJson);
      expect(corruptProfile.latitude, isNull);
      expect(corruptProfile.longitude, isNull);
      expect(corruptProfile.studioLatitude, isNull);
      expect(corruptProfile.studioLongitude, isNull);
    });
  });

  // =========================================================================
  // 2. BookingAppointment Location Fields & Backward Compatibility
  // =========================================================================
  group('BookingAppointment Location Fields & Backward Compatibility', () {
    test('2.1 Roundtrip: Retains clientAddress, clientUnitOrGateCode, latitude, and longitude', () {
      final booking = BookingAppointment(
        id: 'bk_loc_01',
        clientId: 'cli_01',
        detailerId: 'det_01',
        detailerName: 'Pro Detailer',
        detailerBusinessName: 'Pro Shine',
        detailerAvatar: '',
        clientName: 'Alice Client',
        clientPhone: '512-555-0101',
        clientEmail: 'alice@example.com',
        vehicleYearMakeModel: '2024 Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_test_01',
          title: 'Full Detail',
          description: 'Deep clean',
          basePrice: 250.0,
          estimatedDuration: '3 hrs',
          includes: ['Wash', 'Wax'],
        ),
        locationType: ServiceLocationType.mobile,
        clientAddress: '1500 Barton Springs Rd, Austin, TX 78704',
        clientUnitOrGateCode: 'Gate #4412, Park in driveway',
        latitude: 30.2600,
        longitude: -97.7600,
        scheduledDate: DateTime(2026, 11, 15),
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 250.0,
        depositAmount: 50.0,
      );

      final json = booking.toJson();
      expect(json['clientAddress'], '1500 Barton Springs Rd, Austin, TX 78704');
      expect(json['clientUnitOrGateCode'], 'Gate #4412, Park in driveway');
      expect(json['latitude'], 30.2600);
      expect(json['longitude'], -97.7600);

      final restored = BookingAppointment.fromJson(json);
      expect(restored.clientAddress, booking.clientAddress);
      expect(restored.clientUnitOrGateCode, 'Gate #4412, Park in driveway');
      expect(restored.latitude, 30.2600);
      expect(restored.longitude, -97.7600);

      final supabaseMap = booking.toSupabase();
      expect(supabaseMap['client_address'], booking.clientAddress);
      expect(supabaseMap['client_unit_or_gate_code'], 'Gate #4412, Park in driveway');
      expect(supabaseMap['latitude'], 30.2600);
      expect(supabaseMap['longitude'], -97.7600);
    });

    test('2.2 Backward Compatibility: Legacy booking JSON missing coordinates and gate code', () {
      final legacyJson = <String, dynamic>{
        'id': 'bk_legacy_02',
        'detailerId': 'det_01',
        'detailerName': 'Pro Detailer',
        'detailerBusinessName': 'Pro Shine',
        'detailerAvatar': '',
        'clientName': 'Bob Client',
        'clientPhone': '512-555-0202',
        'clientEmail': 'bob@example.com',
        'vehicleYearMakeModel': '2023 Tesla Model Y',
        'vehicleSize': 'suvCrossover',
        'package': {
          'id': 'pkg_test_02',
          'title': 'Quick Wash',
          'description': 'Exterior only',
          'basePrice': 80.0,
          'estimatedDuration': '1 hr',
          'includes': ['Wash'],
        },
        'locationType': 'mobile',
        'clientAddress': '300 Congress Ave, Austin, TX 78701',
        'scheduledDate': '2026-11-10T09:00:00.000',
        'scheduledTimeSlot': '09:00 AM',
        'totalPrice': 80.0,
        'depositAmount': 20.0,
      };

      final restored = BookingAppointment.fromJson(legacyJson);
      expect(restored.clientAddress, '300 Congress Ave, Austin, TX 78701');
      expect(restored.clientUnitOrGateCode, isNull);
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
    });

    test('2.3 copyWith: Allows updating gate code and coordinates without dropping properties', () {
      final original = BookingAppointment(
        id: 'bk_copy_03',
        detailerId: 'det_01',
        detailerName: 'Pro Detailer',
        detailerBusinessName: 'Pro Shine',
        detailerAvatar: '',
        clientName: 'Charlie Client',
        clientPhone: '512-555-0303',
        clientEmail: 'charlie@example.com',
        vehicleYearMakeModel: '2021 BMW M3',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_test_03',
          title: 'Wash',
          description: 'Wash',
          basePrice: 100.0,
          estimatedDuration: '1 hr',
          includes: ['Wash'],
        ),
        locationType: ServiceLocationType.mobile,
        clientAddress: '500 E 4th St',
        scheduledDate: DateTime(2026, 11, 20),
        scheduledTimeSlot: '2:00 PM',
        totalPrice: 100.0,
        depositAmount: 20.0,
      );

      final updated = original.copyWith(
        clientUnitOrGateCode: 'Gate #9999',
        latitude: 30.2660,
        longitude: -97.7400,
      );

      expect(updated.clientUnitOrGateCode, 'Gate #9999');
      expect(updated.latitude, 30.2660);
      expect(updated.longitude, -97.7400);
      expect(updated.clientAddress, '500 E 4th St');
      expect(updated.clientName, 'Charlie Client');
    });

    test('2.4 Defensive Coordinate Deserialization: Handles string-encoded numbers and invalid strings gracefully', () {
      // 1. String-encoded coordinates
      final stringCoordsBookingJson = <String, dynamic>{
        'id': 'bk_str_coords_01',
        'detailerId': 'det_01',
        'detailerName': 'Pro Detailer',
        'detailerBusinessName': 'Pro Shine',
        'detailerAvatar': '',
        'clientName': 'David Client',
        'clientPhone': '512-555-0404',
        'clientEmail': 'david@example.com',
        'vehicleYearMakeModel': '2024 Porsche 911',
        'vehicleSize': 'coupeSedan',
        'package': {
          'id': 'pkg_01',
          'title': 'Wash',
          'description': 'Wash',
          'basePrice': 100.0,
          'estimatedDuration': '1 hr',
          'includes': ['Wash'],
        },
        'locationType': 'mobile',
        'clientAddress': '1500 Barton Springs Rd, Austin, TX 78704',
        'scheduledDate': '2026-11-25T10:00:00.000',
        'scheduledTimeSlot': '10:00 AM',
        'totalPrice': 100.0,
        'depositAmount': 20.0,
        'latitude': '30.2600',
        'longitude': '-97.7600',
      };

      expect(() => BookingAppointment.fromJson(stringCoordsBookingJson), returnsNormally);
      final stringBooking = BookingAppointment.fromJson(stringCoordsBookingJson);
      expect(stringBooking.latitude, equals(30.2600));
      expect(stringBooking.longitude, equals(-97.7600));

      // 2. Corrupt/non-numeric strings fallback to null without throwing TypeError
      final corruptCoordsBookingJson = Map<String, dynamic>.from(stringCoordsBookingJson)
        ..['id'] = 'bk_corrupt_coords_02'
        ..['latitude'] = 'invalid'
        ..['longitude'] = 'not_a_number';

      expect(() => BookingAppointment.fromJson(corruptCoordsBookingJson), returnsNormally);
      final corruptBooking = BookingAppointment.fromJson(corruptCoordsBookingJson);
      expect(corruptBooking.latitude, isNull);
      expect(corruptBooking.longitude, isNull);

      // 3. Whitespace / empty string coordinates fallback to null without throwing
      final whitespaceCoordsJson = Map<String, dynamic>.from(stringCoordsBookingJson)
        ..['id'] = 'bk_whitespace_coords_03'
        ..['latitude'] = '   '
        ..['longitude'] = '';

      expect(() => BookingAppointment.fromJson(whitespaceCoordsJson), returnsNormally);
      final whitespaceBooking = BookingAppointment.fromJson(whitespaceCoordsJson);
      expect(whitespaceBooking.latitude, isNull);
      expect(whitespaceBooking.longitude, isNull);
    });
  });

  // =========================================================================
  // 3. JobRepository Detailer Mode Activation, Isolation & Proximity
  // =========================================================================
  group('JobRepository Detailer Mode Activation, Isolation & Proximity', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('3.1 Detailer mode activation auto-inherits client address when studio address is unset', () async {
      final repo = JobRepository();
      await repo.init();

      // Configure current user with a personal home address
      final clientUser = repo.currentUser.copyWith(
        role: UserRole.client,
        streetAddress: '789 Residential Way',
        unitOrApt: 'Apt 202',
        city: 'Round Rock',
        state: 'TX',
        postalCode: '78664',
        latitude: 30.5083,
        longitude: -97.6789,
        // Studio address intentionally empty
        studioStreetAddress: '',
        studioUnitOrApt: '',
        studioCity: '',
        studioState: '',
        studioPostalCode: '',
      );
      await repo.updateCurrentUser(clientUser);

      // Activate Detailer / Host mode
      await repo.enableDetailerMode();

      expect(repo.currentUser.role, UserRole.detailer);
      expect(repo.currentUser.studioStreetAddress, '789 Residential Way');
      expect(repo.currentUser.studioUnitOrApt, 'Apt 202');
      expect(repo.currentUser.studioCity, 'Round Rock');
      expect(repo.currentUser.studioState, 'TX');
      expect(repo.currentUser.studioPostalCode, '78664');
      expect(repo.currentUser.studioLatitude, 30.5083);
      expect(repo.currentUser.studioLongitude, -97.6789);

      // Verify personal client home address remains intact
      expect(repo.currentUser.streetAddress, '789 Residential Way');
    });

    test('3.2 Detailer mode activation preserves existing studio address if already set', () async {
      final repo = JobRepository();
      await repo.init();

      final existingUser = repo.currentUser.copyWith(
        role: UserRole.client,
        streetAddress: '111 Home St',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        studioStreetAddress: '999 Commercial Shop Blvd',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78702',
      );
      await repo.updateCurrentUser(existingUser);

      // Activating detailer mode should NOT overwrite the commercial shop address
      await repo.enableDetailerMode();

      expect(repo.currentUser.studioStreetAddress, '999 Commercial Shop Blvd');
      expect(repo.currentUser.streetAddress, '111 Home St');
    });

    test('3.3 Updating commercial studio address does not mutate personal home address', () async {
      final repo = JobRepository();
      await repo.init();

      final initialUser = repo.currentUser.copyWith(
        role: UserRole.detailer,
        streetAddress: '555 Private Home Lane',
        unitOrApt: 'House',
        city: 'Austin',
        state: 'TX',
        postalCode: '78703',
        studioStreetAddress: '100 Studio Way',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78704',
      );
      await repo.updateCurrentUser(initialUser);

      // Update studio address via isolated repository method
      await repo.updateStudioAddress(
        street: '800 Brand New Studio Blvd',
        unit: 'Bay 5',
        city: 'Austin',
        state: 'TX',
        postalCode: '78705',
        latitude: 30.2900,
        longitude: -97.7400,
      );

      expect(repo.currentUser.studioStreetAddress, '800 Brand New Studio Blvd');
      expect(repo.currentUser.studioUnitOrApt, 'Bay 5');
      expect(repo.currentUser.studioPostalCode, '78705');

      // Crucial privacy check: personal home address remains untouched
      expect(repo.currentUser.streetAddress, '555 Private Home Lane');
      expect(repo.currentUser.unitOrApt, 'House');
      expect(repo.currentUser.postalCode, '78703');
    });

    test('3.4 Updating personal client address does not mutate commercial studio address', () async {
      final repo = JobRepository();
      await repo.init();

      final initialUser = repo.currentUser.copyWith(
        role: UserRole.detailer,
        streetAddress: '123 Initial Home Way',
        city: 'Austin',
        state: 'TX',
        postalCode: '78701',
        studioStreetAddress: '777 Commercial Studio Ave',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78702',
      );
      await repo.updateCurrentUser(initialUser);

      await repo.updateClientAddress(
        streetAddress: '456 New Home Way',
        unitOrApt: 'Apt 2B',
        city: 'Austin',
        state: 'TX',
        postalCode: '78703',
      );

      expect(repo.currentUser.streetAddress, '456 New Home Way');
      expect(repo.currentUser.unitOrApt, 'Apt 2B');
      expect(repo.currentUser.postalCode, '78703');

      // Commercial studio address remains untouched
      expect(repo.currentUser.studioStreetAddress, '777 Commercial Studio Ave');
      expect(repo.currentUser.studioPostalCode, '78702');
    });

    test('3.5 sortDetailersByProximity correctly calculates distances and orders public detailers', () async {
      final repo = JobRepository();
      await repo.init();

      final detAustin = const UserProfile(
        id: 'det_austin',
        username: 'austin_craft',
        displayName: 'Austin Craft Detail',
        businessName: 'Austin Craft Studio',
        role: UserRole.detailer,
        studioStreetAddress: '1200 S Congress Ave',
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78704',
        studioLatitude: 30.2500,
        studioLongitude: -97.7400,
        servicePackages: [ServicePackage(id: 'p1', title: 'Wash', description: 'Wash', basePrice: 100, estimatedDuration: '1h', includes: [])],
      );

      final detRoundRock = const UserProfile(
        id: 'det_round_rock',
        username: 'round_rock_shine',
        displayName: 'Round Rock Shine',
        businessName: 'Round Rock Spa',
        role: UserRole.detailer,
        studioStreetAddress: '500 E Main St',
        studioCity: 'Round Rock',
        studioState: 'TX',
        studioPostalCode: '78664',
        studioLatitude: 30.5083,
        studioLongitude: -97.6789,
        servicePackages: [ServicePackage(id: 'p2', title: 'Coating', description: 'Coating', basePrice: 500, estimatedDuration: '4h', includes: [])],
      );

      final detSanAntonio = const UserProfile(
        id: 'det_san_antonio',
        username: 'alamo_detail',
        displayName: 'Alamo Auto Spa',
        businessName: 'Alamo Detailers',
        role: UserRole.detailer,
        studioStreetAddress: '100 Alamo Plaza',
        studioCity: 'San Antonio',
        studioState: 'TX',
        studioPostalCode: '78205',
        studioLatitude: 29.4241,
        studioLongitude: -98.4936,
        servicePackages: [ServicePackage(id: 'p3', title: 'Detail', description: 'Detail', basePrice: 200, estimatedDuration: '2h', includes: [])],
      );

      repo.setPublicDetailersForTesting([detRoundRock, detSanAntonio, detAustin]);
      expect(repo.publicDetailers.length, 3);

      // Call sortDetailersByProximity near Austin downtown (30.2672, -97.7431)
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      expect(repo.currentUserGpsLocation, isNotNull);
      expect(repo.currentUserGpsLocation!.latitude, 30.2672);

      // Verify cached distances: Austin (~1.2 mi) < Round Rock (~17.0 mi) < San Antonio (~73.5 mi)
      final distAustin = repo.getDistanceToDetailer('det_austin');
      final distRoundRock = repo.getDistanceToDetailer('det_round_rock');
      final distSanAntonio = repo.getDistanceToDetailer('det_san_antonio');

      expect(distAustin, isNotNull);
      expect(distRoundRock, isNotNull);
      expect(distSanAntonio, isNotNull);
      expect(distAustin!, closeTo(1.2, 0.5));
      expect(distRoundRock!, closeTo(17.0, 1.0));
      expect(distSanAntonio!, closeTo(73.5, 1.5));

      // Verify filteredDetailers is sorted ascending by distance
      final sorted = repo.filteredDetailers;
      expect(sorted.length, 3);
      expect(sorted[0].id, 'det_austin');
      expect(sorted[1].id, 'det_round_rock');
      expect(sorted[2].id, 'det_san_antonio');

      // Clear proximity sort
      repo.clearProximitySort();
      expect(repo.currentUserGpsLocation, isNull);
      expect(repo.getDistanceToDetailer('det_austin'), isNull);
    });

    test('3.6 In-memory zero-cost text search by city and ZIP code filters studios without API calls', () async {
      final repo = JobRepository();
      await repo.init();

      final detAustin = const UserProfile(
        id: 'det_austin',
        username: 'austin_craft',
        displayName: 'Austin Craft Detail',
        businessName: 'Austin Craft Studio',
        role: UserRole.detailer,
        studioCity: 'Austin',
        studioState: 'TX',
        studioPostalCode: '78704',
        servicePackages: [ServicePackage(id: 'p1', title: 'Wash', description: 'Wash', basePrice: 100, estimatedDuration: '1h', includes: [])],
      );

      final detRoundRock = const UserProfile(
        id: 'det_round_rock',
        username: 'round_rock_shine',
        displayName: 'Round Rock Shine',
        businessName: 'Round Rock Spa',
        role: UserRole.detailer,
        studioCity: 'Round Rock',
        studioState: 'TX',
        studioPostalCode: '78664',
        servicePackages: [ServicePackage(id: 'p2', title: 'Coating', description: 'Coating', basePrice: 500, estimatedDuration: '4h', includes: [])],
      );

      repo.setPublicDetailersForTesting([detAustin, detRoundRock]);

      // Search by ZIP code '78664'
      repo.searchDetailers('78664');
      var results = repo.filteredDetailers;
      expect(results.length, 1);
      expect(results.first.id, 'det_round_rock');

      // Search by City 'Austin'
      repo.searchDetailers('Austin');
      results = repo.filteredDetailers;
      expect(results.length, 1);
      expect(results.first.id, 'det_austin');

      // Clear search
      repo.searchDetailers('');
      results = repo.filteredDetailers;
      expect(results.length, 2);
    });
  });

  // =========================================================================
  // 4. LocationService Haversine Distance & Test Mocking
  // =========================================================================
  group('LocationService Haversine Distance & Test Mocking', () {
    tearDown(() {
      LocationService.resetMockLocationProvider();
    });

    test('4.1 Zero distance for identical coordinates', () {
      const lat = 30.2672;
      const lon = -97.7431;
      final distance = LocationService.calculateDistanceMiles(lat, lon, lat, lon);
      expect(distance, closeTo(0.0, 0.001));
    });

    test('4.2 Known geographic benchmark distances', () {
      // Benchmark 1: Austin Downtown to Round Rock (~17.0 miles)
      final austinToRoundRock = LocationService.calculateDistanceMiles(
        30.2672, -97.7431, // Austin
        30.5083, -97.6789, // Round Rock
      );
      expect(austinToRoundRock, closeTo(17.0, 1.0));

      // Benchmark 2: Austin Downtown to San Antonio Downtown (~73.5 miles)
      final austinToSanAntonio = LocationService.calculateDistanceMiles(
        30.2672, -97.7431, // Austin
        29.4241, -98.4936, // San Antonio
      );
      expect(austinToSanAntonio, closeTo(73.5, 1.5));

      // Benchmark 3: New York City to Los Angeles (~2451 miles)
      final nycToLa = LocationService.calculateDistanceMiles(
        40.7128, -74.0060, // NYC
        34.0522, -118.2437, // LA
      );
      expect(nycToLa, closeTo(2451.0, 20.0));
    });

    test('4.3 Mathematical symmetry and non-negativity', () {
      const p1Lat = 30.2672;
      const p1Lon = -97.7431;
      const p2Lat = 32.7767;
      const p2Lon = -96.7970; // Dallas

      final d1 = LocationService.calculateDistanceMiles(p1Lat, p1Lon, p2Lat, p2Lon);
      final d2 = LocationService.calculateDistanceMiles(p2Lat, p2Lon, p1Lat, p1Lon);

      expect(d1, equals(d2));
      expect(d1, greaterThan(0.0));
      expect(d1, closeTo(182.0, 5.0)); // Austin to Dallas is ~182 miles
    });

    test('4.4 Distance formatting helper produces clear user-facing labels', () {
      expect(LocationService.formatDistance(0.05), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(1.24), '1.2 mi away');
      expect(LocationService.formatDistance(9.94), '9.9 mi away');
      expect(LocationService.formatDistance(14.8), '15 mi away');
      expect(LocationService.formatDistance(73.5), '74 mi away');
    });

    test('4.5 Zero-hardware deterministic mocking hook', () async {
      LocationService.setMockLocationProvider(() async => const LocationCoordinates(
        latitude: 30.2672,
        longitude: -97.7431,
      ));

      final coords = await LocationService.getCurrentLocation();
      expect(coords, isNotNull);
      expect(coords!.latitude, 30.2672);
      expect(coords.longitude, -97.7431);

      LocationService.resetMockLocationProvider();
    });

    test('4.6 Antipodal points distance calculation is numerically stable and never returns NaN', () {
      // 1. Challenger 1 deterministic float64 roundoff reproducer pair
      const lat1 = -18.974101086836882;
      const lon1 = -179.98050231629463;
      const lat2 = 18.974101086836882;
      const lon2 = 0.019497683705367308;

      final dist1 = LocationService.calculateDistanceMiles(lat1, lon1, lat2, lon2);
      expect(dist1.isNaN, isFalse, reason: 'Distance between antipodal coordinates must not evaluate to NaN');
      expect(dist1, closeTo(12436.81, 20.0), reason: 'Antipodal distance on Earth must be ~12,437 - 12,450 miles');

      // 2. Exact equator antipodal points: (0, 0) and (0, 180) / (0, -180)
      final dEquator = LocationService.calculateDistanceMiles(0.0, 0.0, 0.0, 180.0);
      expect(dEquator.isNaN, isFalse);
      expect(dEquator, closeTo(12436.81, 20.0));

      final dEquatorNeg = LocationService.calculateDistanceMiles(0.0, 0.0, 0.0, -180.0);
      expect(dEquatorNeg.isNaN, isFalse);
      expect(dEquatorNeg, closeTo(12436.81, 20.0));

      // 3. Geographic pole-to-pole antipodals (North Pole 90 to South Pole -90)
      final dPoles = LocationService.calculateDistanceMiles(90.0, 0.0, -90.0, 0.0);
      expect(dPoles.isNaN, isFalse);
      expect(dPoles, closeTo(12436.81, 20.0));

      // 4. Antipodal latitude sweep across Earth
      for (final lat in [-75.0, -45.0, -15.0, 15.0, 45.0, 75.0]) {
        final d = LocationService.calculateDistanceMiles(lat, 0.0, -lat, 180.0);
        expect(d.isNaN, isFalse, reason: 'Antipodal distance at latitude $lat must not be NaN');
        expect(d, closeTo(12436.81, 20.0));
      }
    });

    test('4.7 formatDistance defensive guards: returns empty string on NaN, infinity, null, or negative values without throwing', () {
      // 1. double.nan must not throw UnsupportedError: NaN and must return empty string ''
      expect(() => LocationService.formatDistance(double.nan), returnsNormally);
      expect(LocationService.formatDistance(double.nan), equals(''));

      // 2. double.infinity and double.negativeInfinity must return empty string ''
      expect(() => LocationService.formatDistance(double.infinity), returnsNormally);
      expect(LocationService.formatDistance(double.infinity), equals(''));
      expect(() => LocationService.formatDistance(double.negativeInfinity), returnsNormally);
      expect(LocationService.formatDistance(double.negativeInfinity), equals(''));

      // 3. null value must return empty string ''
      expect(() => LocationService.formatDistance(null), returnsNormally);
      expect(LocationService.formatDistance(null), equals(''));

      // 4. Negative values must return empty string '' without throwing
      expect(() => LocationService.formatDistance(-1.0), returnsNormally);
      expect(LocationService.formatDistance(-1.0), equals(''));
      expect(LocationService.formatDistance(-0.0001), equals(''));
      expect(LocationService.formatDistance(-500.0), equals(''));

      // 5. Valid values still format as expected (regression guard)
      expect(LocationService.formatDistance(0.0), equals('Under 0.1 mi away'));
      expect(LocationService.formatDistance(0.05), equals('Under 0.1 mi away'));
      expect(LocationService.formatDistance(1.24), equals('1.2 mi away'));
      expect(LocationService.formatDistance(9.94), equals('9.9 mi away'));
      expect(LocationService.formatDistance(14.8), equals('15 mi away'));
    });
  });
}
