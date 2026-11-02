import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/location_service.dart';
import 'package:detail_craft/services/job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. Haversine Extremes & Corner Cases
  // =========================================================================
  group('1. Haversine Extremes & Corner Cases', () {
    test('1.1 Identical points return exactly 0.0 distance', () {
      final testCases = [
        [0.0, 0.0],
        [90.0, 0.0],
        [-90.0, 0.0],
        [0.0, 180.0],
        [0.0, -180.0],
        [37.7749, -122.4194],
        [-33.8688, 151.2093],
        [51.5074, -0.1278],
      ];

      for (final tc in testCases) {
        final dist = LocationService.calculateDistanceMiles(tc[0], tc[1], tc[0], tc[1]);
        expect(dist, 0.0, reason: 'Identical point (${tc[0]}, ${tc[1]}) must return 0.0');
        expect(dist.isNaN, isFalse);
      }
    });

    test('1.2 Micro-degree identical proximity does not produce negative or NaN distance', () {
      const lat = 30.2672;
      const lon = -97.7431;
      const microEps = 1e-9;

      final dist = LocationService.calculateDistanceMiles(lat, lon, lat + microEps, lon + microEps);
      expect(dist.isNaN, isFalse);
      expect(dist, greaterThanOrEqualTo(0.0));
      expect(dist, lessThan(0.001));
    });

    test('1.3 Antipodal points (exact opposite sides of Earth)', () {
      // Antipodal points on equator: (0, 0) and (0, 180)
      // Theoretical maximum distance: pi * R ≈ 3.141592653589793 * 3958.8 ≈ 12436.81 miles (~12,437 - 12,450 mi)
      final dEquator = LocationService.calculateDistanceMiles(0.0, 0.0, 0.0, 180.0);
      expect(dEquator.isNaN, isFalse, reason: 'Equator antipodal must not be NaN');
      expect(dEquator, closeTo(12436.81, 10.0));

      final dEquatorNeg = LocationService.calculateDistanceMiles(0.0, 0.0, 0.0, -180.0);
      expect(dEquatorNeg.isNaN, isFalse);
      expect(dEquatorNeg, closeTo(12436.81, 10.0));

      // Test antipodal across a spectrum of latitudes
      for (double lat = -89.0; lat <= 89.0; lat += 10.0) {
        final double antiLat = -lat;
        final double antiLon = 180.0;
        final d = LocationService.calculateDistanceMiles(lat, 0.0, antiLat, antiLon);
        expect(d.isNaN, isFalse, reason: 'Antipodal at lat $lat must not be NaN');
        expect(d, closeTo(12436.81, 10.0));
      }
    });

    test('1.4 Geographic Poles (North Pole 90, South Pole -90)', () {
      // North pole to South pole
      final poleToPole = LocationService.calculateDistanceMiles(90.0, 0.0, -90.0, 0.0);
      expect(poleToPole.isNaN, isFalse);
      expect(poleToPole, closeTo(12436.81, 10.0));

      // Any longitude at North Pole represents the same physical point
      final northPoleDiffLon = LocationService.calculateDistanceMiles(90.0, -120.0, 90.0, 60.0);
      expect(northPoleDiffLon.isNaN, isFalse);
      expect(northPoleDiffLon, closeTo(0.0, 0.01));

      // South Pole different longitudes
      final southPoleDiffLon = LocationService.calculateDistanceMiles(-90.0, -45.0, -90.0, 135.0);
      expect(southPoleDiffLon.isNaN, isFalse);
      expect(southPoleDiffLon, closeTo(0.0, 0.01));

      // North Pole to Equator is 1/4 of Earth circumference (pi/2 * 3958.8 ≈ 6218.4 miles)
      final poleToEquator = LocationService.calculateDistanceMiles(90.0, 0.0, 0.0, 0.0);
      expect(poleToEquator.isNaN, isFalse);
      expect(poleToEquator, closeTo(6218.4, 5.0));
    });

    test('1.5 Equator & International Date Line crossing (lon -179 to +179)', () {
      // Distance across the antimeridian (179 to -179 is 2 degrees of longitude)
      // 2 degrees at the equator ≈ (2 / 360) * 2 * pi * 3958.8 ≈ 138.19 miles
      final dCrossing = LocationService.calculateDistanceMiles(0.0, 179.0, 0.0, -179.0);
      expect(dCrossing.isNaN, isFalse);
      expect(dCrossing, closeTo(138.19, 1.0));

      // Reverse direction should be identical
      final dCrossingRev = LocationService.calculateDistanceMiles(0.0, -179.0, 0.0, 179.0);
      expect(dCrossingRev.isNaN, isFalse);
      expect(dCrossingRev, closeTo(138.19, 1.0));

      // Micro-crossing right at the antimeridian: 179.999 to -179.999 (0.002 deg ≈ 0.138 miles)
      final dMicro = LocationService.calculateDistanceMiles(0.0, 179.999, 0.0, -179.999);
      expect(dMicro.isNaN, isFalse);
      expect(dMicro, closeTo(0.138, 0.05));
    });

    test('1.6 Deterministic Antipodal NaN Reproducer (shows mathematical instability)', () {
      // Exactly reproducible antipodal pair found during scan:
      const lat1 = -18.974101086836882;
      const lon1 = -179.98050231629463;
      const lat2 = 18.974101086836882;
      const lon2 = 0.019497683705367308;

      final dist = LocationService.calculateDistanceMiles(lat1, lon1, lat2, lon2);
      // In a numerically stable implementation, this should be ~12,436.81 miles.
      // Currently in LocationService, `a` evaluates to 1.0000000000000002, so sqrt(1 - a) evaluates to NaN.
      expect(dist.isNaN, isFalse,
          reason: 'calculateDistanceMiles returned NaN for antipodal coordinates ($lat1,$lon1) and ($lat2,$lon2) because `a` exceeds 1.0 in float64 without clamping');
    });

    test('1.7 formatDistance safely guards null, NaN, infinite, and negative without throwing', () {
      const lat1 = -18.974101086836882;
      const lon1 = -179.98050231629463;
      const lat2 = 18.974101086836882;
      const lon2 = 0.019497683705367308;

      final dist = LocationService.calculateDistanceMiles(lat1, lon1, lat2, lon2);
      expect(dist.isNaN, isFalse);

      // Verify formatDistance accepts null, NaN, and extremes without throwing UnsupportedError
      expect(LocationService.formatDistance(null), '');
      expect(LocationService.formatDistance(double.nan), '');
      expect(LocationService.formatDistance(double.infinity), '');
      expect(LocationService.formatDistance(double.negativeInfinity), '');
      expect(LocationService.formatDistance(-1.0), '');
      expect(LocationService.formatDistance(dist), '12437 mi away');
    });

    test('1.8 Distance formatting edge cases and boundaries', () {
      expect(LocationService.formatDistance(0.0), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(0.04), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(0.099), 'Under 0.1 mi away');
      expect(LocationService.formatDistance(0.1), '0.1 mi away');
      expect(LocationService.formatDistance(1.0), '1.0 mi away');
      expect(LocationService.formatDistance(9.94), '9.9 mi away');
      expect(LocationService.formatDistance(9.99), '10.0 mi away');
      expect(LocationService.formatDistance(10.0), '10 mi away');
      expect(LocationService.formatDistance(10.49), '10 mi away');
      expect(LocationService.formatDistance(10.51), '11 mi away');
      expect(LocationService.formatDistance(12436.8), '12437 mi away');
    });
  });

  // =========================================================================
  // 2. Proximity Sorting & Cache Resilience
  // =========================================================================
  group('2. Proximity Sorting & Cache Resilience', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('2.1 Tie-breaking with identical distances: does not crash and preserves all studios', () async {
      final repo = JobRepository();
      await repo.init();

      // Create 10 studios all placed at the exact same coordinates (30.2500, -97.7400)
      final identicalStudios = List.generate(
        10,
        (i) => UserProfile(
          id: 'det_tie_$i',
          username: 'tie_user_$i',
          displayName: 'Tie Studio $i',
          businessName: 'Identical Studio $i',
          role: UserRole.detailer,
          studioCity: 'Austin',
          studioState: 'TX',
          studioPostalCode: '78704',
          studioLatitude: 30.2500,
          studioLongitude: -97.7400,
        ),
      );

      repo.setPublicDetailersForTesting(identicalStudios);
      expect(repo.publicDetailers.length, 10);

      // Sort proximity from user location at (30.2672, -97.7431)
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      // Verify all 10 studios are preserved
      final sorted = repo.filteredDetailers;
      expect(sorted.length, 10);

      // Verify all 10 studios have cached distance and are equal
      final firstDist = repo.getDistanceToDetailer('det_tie_0');
      expect(firstDist, isNotNull);
      for (var i = 0; i < 10; i++) {
        final d = repo.getDistanceToDetailer('det_tie_$i');
        expect(d, equals(firstDist));
      }
    });

    test('2.2 Null coordinates handling: does not throw and places null coordinates at the end', () async {
      final repo = JobRepository();
      await repo.init();

      final studioNear = const UserProfile(
        id: 'det_near',
        username: 'near_user',
        displayName: 'Near Studio',
        businessName: 'Near Studio Shop',
        role: UserRole.detailer,
        studioLatitude: 30.2670,
        studioLongitude: -97.7430, // ~0.02 mi
      );

      final studioFar = const UserProfile(
        id: 'det_far',
        username: 'far_user',
        displayName: 'Far Studio',
        businessName: 'Far Studio Shop',
        role: UserRole.detailer,
        studioLatitude: 32.7767,
        studioLongitude: -96.7970, // Dallas ~182 mi
      );

      final studioNullCoords = const UserProfile(
        id: 'det_null_coords',
        username: 'null_coords_user',
        displayName: 'Null Coords Studio',
        businessName: 'Null Coords Shop',
        role: UserRole.detailer,
        studioLatitude: null,
        studioLongitude: null,
      );

      final studioPartialNullLat = const UserProfile(
        id: 'det_partial_null_lat',
        username: 'partial_null_lat',
        displayName: 'Partial Null Lat Studio',
        businessName: 'Partial Null Lat Shop',
        role: UserRole.detailer,
        studioLatitude: null,
        studioLongitude: -97.7430,
      );

      final studioPartialNullLon = const UserProfile(
        id: 'det_partial_null_lon',
        username: 'partial_null_lon',
        displayName: 'Partial Null Lon Studio',
        businessName: 'Partial Null Lon Shop',
        role: UserRole.detailer,
        studioLatitude: 30.2670,
        studioLongitude: null,
      );

      final studioEmpty = const UserProfile(
        id: 'det_empty',
        username: 'empty_user',
        displayName: 'Empty Studio',
        businessName: 'Empty Shop',
        role: UserRole.detailer,
      );

      // Set mixed order
      repo.setPublicDetailersForTesting([
        studioNullCoords,
        studioFar,
        studioPartialNullLat,
        studioNear,
        studioEmpty,
        studioPartialNullLon,
      ]);

      // Execute sort
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      final sorted = repo.filteredDetailers;
      expect(sorted.length, 6);

      // First two MUST be studioNear and studioFar in ascending proximity
      expect(sorted[0].id, 'det_near');
      expect(sorted[1].id, 'det_far');

      // The remaining 4 must be the null/partial coordinates studios at the end
      final tailIds = sorted.sublist(2).map((s) => s.id).toSet();
      expect(tailIds, containsAll(['det_null_coords', 'det_partial_null_lat', 'det_partial_null_lon', 'det_empty']));

      // Verify null studios have null cached distance
      expect(repo.getDistanceToDetailer('det_null_coords'), isNull);
      expect(repo.getDistanceToDetailer('det_partial_null_lat'), isNull);
      expect(repo.getDistanceToDetailer('det_partial_null_lon'), isNull);
      expect(repo.getDistanceToDetailer('det_empty'), isNull);

      // Verify valid studios have non-null cached distance
      expect(repo.getDistanceToDetailer('det_near'), isNotNull);
      expect(repo.getDistanceToDetailer('det_far'), isNotNull);
    });

    test('2.3 High volume stress test: sorting 1,000 synthetic studios in memory', () async {
      final repo = JobRepository();
      await repo.init();

      final rand = math.Random(12345);
      const studioCount = 1000;

      final syntheticStudios = List.generate(studioCount, (i) {
        // 90% have coordinates, 10% have null coordinates
        final hasCoords = (i % 10 != 0);
        final lat = hasCoords ? 25.0 + rand.nextDouble() * 20.0 : null; // Lat 25 to 45 (Continental US)
        final lon = hasCoords ? -125.0 + rand.nextDouble() * 55.0 : null; // Lon -125 to -70

        return UserProfile(
          id: 'det_stress_$i',
          username: 'stress_detailer_$i',
          displayName: 'Stress Studio $i',
          businessName: 'Business $i',
          role: UserRole.detailer,
          studioCity: hasCoords ? 'City $i' : '',
          studioState: 'TX',
          studioPostalCode: '7870$i',
          studioLatitude: lat,
          studioLongitude: lon,
        );
      });

      repo.setPublicDetailersForTesting(syntheticStudios);
      expect(repo.publicDetailers.length, studioCount);

      // Measure execution time of sorting 1,000 studios from Austin (30.2672, -97.7431)
      final stopwatch = Stopwatch()..start();
      await repo.sortDetailersByProximity(30.2672, -97.7431);
      stopwatch.stop();

      // Ensure high volume sorting is extremely fast (< 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Sorting 1,000 studios in memory should execute well under 100ms');

      final sorted = repo.filteredDetailers;
      expect(sorted.length, studioCount);

      // Verify that all non-null studios appear first and are strictly monotonically increasing by distance
      double? prevDist;
      var nullEncountered = false;

      for (var i = 0; i < sorted.length; i++) {
        final dist = repo.getDistanceToDetailer(sorted[i].id);
        if (dist == null) {
          nullEncountered = true;
        } else {
          expect(nullEncountered, isFalse,
              reason: 'Non-null distance studio (${sorted[i].id}) found after null distance studios at index $i');
          if (prevDist != null) {
            expect(dist, greaterThanOrEqualTo(prevDist),
                reason: 'Distance must be sorted in ascending monotonic order at index $i: $dist >= $prevDist');
          }
          prevDist = dist;
        }
      }

      // Clear proximity sort and verify clean state restoration
      repo.clearProximitySort();
      expect(repo.currentUserGpsLocation, isNull);
      expect(repo.getDistanceToDetailer(sorted.first.id), isNull);
    });

    test('2.4 Empty studio list handles proximity sorting without error', () async {
      final repo = JobRepository();
      await repo.init();

      repo.setPublicDetailersForTesting([]);
      expect(repo.publicDetailers.isEmpty, isTrue);

      await repo.sortDetailersByProximity(30.2672, -97.7431);
      expect(repo.filteredDetailers.isEmpty, isTrue);

      repo.clearProximitySort();
    });

    test('2.5 All studios having null coordinates handles proximity sorting gracefully', () async {
      final repo = JobRepository();
      await repo.init();

      final allNullStudios = List.generate(
        5,
        (i) => UserProfile(
          id: 'det_null_$i',
          username: 'null_user_$i',
          displayName: 'Null Studio $i',
          businessName: 'Business Null $i',
          role: UserRole.detailer,
          studioLatitude: null,
          studioLongitude: null,
        ),
      );

      repo.setPublicDetailersForTesting(allNullStudios);
      await repo.sortDetailersByProximity(30.2672, -97.7431);

      final sorted = repo.filteredDetailers;
      expect(sorted.length, 5);
      for (final s in sorted) {
        expect(repo.getDistanceToDetailer(s.id), isNull);
      }
    });

    test('2.6 In-memory search by city and ZIP code handles whitespace and case variations', () async {
      final repo = JobRepository();
      await repo.init();

      final studioAustin = const UserProfile(
        id: 'det_austin_search',
        username: 'austin_user',
        displayName: 'Austin Studio',
        businessName: 'Capital Shine',
        role: UserRole.detailer,
        studioCity: 'Austin',
        studioPostalCode: '78704',
      );

      final studioDallas = const UserProfile(
        id: 'det_dallas_search',
        username: 'dallas_user',
        displayName: 'Dallas Studio',
        businessName: 'Big D Spa',
        role: UserRole.detailer,
        studioCity: 'Dallas',
        studioPostalCode: '75201',
      );

      repo.setPublicDetailersForTesting([studioAustin, studioDallas]);

      // Mixed case and leading/trailing whitespace
      repo.searchDetailers('  aUsTiN  ');
      var results = repo.filteredDetailers;
      expect(results.length, 1);
      expect(results.first.id, 'det_austin_search');

      // Partial ZIP code
      repo.searchDetailers('7520');
      results = repo.filteredDetailers;
      expect(results.length, 1);
      expect(results.first.id, 'det_dallas_search');

      // Clear search
      repo.searchDetailers('   ');
      results = repo.filteredDetailers;
      expect(results.length, 2);
    });
  });

  // =========================================================================
  // 3. UserProfile & Booking Data Integrity Stress Tests
  // =========================================================================
  group('3. UserProfile & Booking Data Integrity Stress Tests', () {
    test('3.1 UserProfile fallback getters handle whitespace and partial fields gracefully', () {
      const partialProfile = UserProfile(
        id: 'usr_partial',
        username: 'partial_user',
        displayName: 'Partial User',
        streetAddress: '   100 Main St   ',
        unitOrApt: '   ',
        city: 'Austin',
        state: '  TX  ',
        postalCode: ' 78701 ',
        studioStreetAddress: '',
        studioCity: '',
      );

      expect(partialProfile.hasClientAddress, isTrue);
      expect(partialProfile.hasStudioAddress, isFalse);
      expect(partialProfile.formattedClientAddress, contains('100 Main St'));
      expect(partialProfile.formattedClientAddress, contains('Austin'));
      expect(partialProfile.formattedStudioAddress, equals(''));
    });

    test('3.2 BookingAppointment handles empty or unusual coordinates without throwing', () {
      final booking = BookingAppointment(
        id: 'bk_stress_01',
        detailerId: 'det_01',
        detailerName: 'Detailer',
        detailerBusinessName: 'Shop',
        detailerAvatar: '',
        clientName: 'Client',
        clientPhone: '555-1234',
        clientEmail: 'test@example.com',
        vehicleYearMakeModel: '2024 Ford F-150',
        vehicleSize: VehicleSize.truckVan,
        package: const ServicePackage(
          id: 'pkg_1',
          title: 'Wash',
          description: 'Wash',
          basePrice: 50,
          estimatedDuration: '1h',
          includes: [],
        ),
        locationType: ServiceLocationType.mobile,
        clientAddress: '123 Test St',
        clientUnitOrGateCode: 'Gate code: *#1234#* (press call)',
        latitude: -89.9999,
        longitude: 179.9999,
        scheduledDate: DateTime(2026, 12, 1),
        scheduledTimeSlot: '11:00 AM',
        totalPrice: 50.0,
        depositAmount: 10.0,
      );

      final json = booking.toJson();
      final restored = BookingAppointment.fromJson(json);

      expect(restored.latitude, -89.9999);
      expect(restored.longitude, 179.9999);
      expect(restored.clientUnitOrGateCode, 'Gate code: *#1234#* (press call)');
    });
  });
}
