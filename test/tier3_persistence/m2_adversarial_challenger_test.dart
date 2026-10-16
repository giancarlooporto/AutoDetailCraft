import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import '../core/test_harness.dart';

// ─── MOCK HTTP INFRASTRUCTURE FOR SUPABASE TESTING ──────────────────────────

typedef CloudResponseProvider = Map<String, dynamic> Function(Uri uri, String method);

CloudResponseProvider? _activeCloudProvider;

class AdversarialHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _AdversarialHttpClient();
  }
}

class _AdversarialHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _AdversarialHttpRequest(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
}

class _AdversarialHttpRequest extends Fake implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  _AdversarialHttpRequest(this.method, this.uri);

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeln([Object? obj = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future flush() async {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async {
    if (_activeCloudProvider != null) {
      final res = _activeCloudProvider!(uri, method);
      final body = res['body'];
      final statusCode = res['statusCode'] as int? ?? 200;
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      return _AdversarialHttpResponse(statusCode, Uint8List.fromList(jsonBytes));
    }
    // Default fallback: return empty JSON array
    return _AdversarialHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];

  @override
  String? value(String name) => _map[name.toLowerCase()]?.firstOrNull;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }
}

class _AdversarialHttpResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final Uint8List bodyBytes;

  _AdversarialHttpResponse(this.statusCode, this.bodyBytes);

  @override
  int get contentLength => bodyBytes.length;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => true;

  @override
  HttpHeaders get headers => _MockResponseHeaders();

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(bodyBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MockResponseHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers;

  _MockResponseHeaders([Map<String, List<String>>? headers])
      : _headers = headers ?? {
          'content-type': ['application/json; charset=utf-8'],
        };

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.firstOrNull;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }
}

// ─── MAIN ADVERSARIAL TEST SUITE ─────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Install mock HTTP overrides to safely test SupabaseDbService
    HttpOverrides.global = AdversarialHttpOverrides();
    await SupabaseService.initialize();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    _activeCloudProvider = null;
  });

  group('Milestone M2 Adversarial Verification: Cloud Union Merge', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _activeCloudProvider = null;
    });

    test('ADV-1: When SupabaseDbService returns empty garage and staff, local custom items are NOT erased', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // 1. Seed local custom vehicles
      final localVehicle1 = UserVehicle(
        id: 'veh_local_custom_99',
        year: 2024,
        make: 'Porsche',
        model: '911 GT3 RS',
        colorName: 'Shark Blue',
        paintCode: 'D5C',
        imageUrl: '',
        lastDetailService: 'Full Paint Correction & Ceramic',
        lastDetailDate: DateTime(2026, 3, 15),
      );
      repo.addVehicleToGarage(localVehicle1);

      // 2. Seed local custom team member
      final localMember1 = TeamMember(
        id: 'staff_local_specialist_44',
        name: 'Diego Alvarez',
        roleTitle: 'Master Paint Correction Tech',
        avatarUrl: '',
        rating: 4.95,
        completedJobsCount: 120,
        customWeeklySchedule: const [
          DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ],
      );
      repo.addTeamMember(localMember1);

      expect(repo.currentUser.myGarage.length, equals(1));
      expect(repo.currentUser.teamMembers.length, equals(1));

      // 3. Configure mock Supabase HTTP responses to return an EMPTY garage and EMPTY staff
      _activeCloudProvider = (Uri uri, String method) {
        final path = uri.path;
        if (path.contains('profiles')) {
          return {
            'statusCode': 200,
            'body': {
              'id': repo.currentUser.id,
              'display_name': repo.currentUser.displayName,
              'business_name': repo.currentUser.businessName,
              'role': 'detailer',
              'email': 'detailer@autodetailcraft.com',
              'service_packages': [],
            },
          };
        } else if (path.contains('vehicles')) {
          // Cloud returns empty garage
          return {'statusCode': 200, 'body': <dynamic>[]};
        } else if (path.contains('team_members')) {
          // Cloud returns empty team roster
          return {'statusCode': 200, 'body': <dynamic>[]};
        } else if (path.contains('jobs')) {
          return {'statusCode': 200, 'body': <dynamic>[]};
        } else if (path.contains('bookings')) {
          return {'statusCode': 200, 'body': <dynamic>[]};
        }
        return {'statusCode': 200, 'body': <dynamic>[]};
      };

      // 4. Trigger cloud profile sync via loginUser (which invokes _refreshProfileFromCloud)
      await repo.loginUser(repo.currentUser);

      // 5. Assert: Local custom vehicle and local custom team member are NOT erased!
      expect(repo.currentUser.myGarage.length, equals(1));
      expect(repo.currentUser.myGarage.first.id, equals('veh_local_custom_99'));
      expect(repo.currentUser.myGarage.first.make, equals('Porsche'));
      expect(repo.currentUser.myGarage.first.lastDetailService, equals('Full Paint Correction & Ceramic'));

      expect(repo.currentUser.teamMembers.length, equals(1));
      expect(repo.currentUser.teamMembers.first.id, equals('staff_local_specialist_44'));
      expect(repo.currentUser.teamMembers.first.name, equals('Diego Alvarez'));
      expect(repo.currentUser.teamMembers.first.customWeeklySchedule, isNotNull);
      expect(repo.currentUser.teamMembers.first.customWeeklySchedule!.length, equals(7));

      // 6. Assert: LocalStorageService also retains local vehicles and team
      final localSavedVehicles = await LocalStorageService.loadGarageVehicles();
      expect(localSavedVehicles.length, equals(1));
      expect(localSavedVehicles.first.id, equals('veh_local_custom_99'));

      final localSavedTeam = await LocalStorageService.loadTeamMembers();
      expect(localSavedTeam.length, equals(1));
      expect(localSavedTeam.first.id, equals('staff_local_specialist_44'));

      // 7. Simulate browser reload (Cmd+R) with empty cloud
      final refreshedRepo = JobRepository();
      await refreshedRepo.init();

      expect(refreshedRepo.currentUser.myGarage.length, equals(1));
      expect(refreshedRepo.currentUser.myGarage.first.id, equals('veh_local_custom_99'));
      expect(refreshedRepo.currentUser.teamMembers.length, equals(1));
      expect(refreshedRepo.currentUser.teamMembers.first.id, equals('staff_local_specialist_44'));
    });

    test('ADV-2: Union merge preserves BOTH local items and distinct cloud items when cloud returns 1 vehicle and 1 team member', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // 1. Local user has local items
      final localVehicle = UserVehicle(
        id: 'veh_local_001',
        year: 2023,
        make: 'BMW',
        model: 'M3 Competition',
        colorName: 'Isle of Man Green',
        imageUrl: '',
        lastDetailService: 'Single Stage Polish',
      );
      repo.addVehicleToGarage(localVehicle);

      final localMember = TeamMember(
        id: 'staff_local_001',
        name: 'Marcus Vance',
        roleTitle: 'Interior Specialist',
        avatarUrl: '',
        customWeeklySchedule: const [
          DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        ],
      );
      repo.addTeamMember(localMember);

      expect(repo.currentUser.myGarage.length, equals(1));
      expect(repo.currentUser.teamMembers.length, equals(1));

      // 2. Configure mock cloud responses returning a DIFFERENT vehicle and a DIFFERENT team member
      _activeCloudProvider = (Uri uri, String method) {
        final path = uri.path;
        if (path.contains('profiles')) {
          return {
            'statusCode': 200,
            'body': {
              'id': repo.currentUser.id,
              'display_name': 'Detail Studio Pro',
              'business_name': 'Apex Detailing',
              'role': 'detailer',
              'email': 'pro@apex.com',
              'service_packages': [],
            },
          };
        } else if (path.contains('vehicles')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'veh_cloud_remote_88',
                'user_id': repo.currentUser.id,
                'year': 2025,
                'make': 'Ferrari',
                'model': '296 GTB',
                'paint_color': 'Rosso Corsa',
                'paint_code': 'FER322',
                'image_url': 'https://example.com/ferrari296.jpg',
                'last_detail_service': 'Gtechniq Crystal Serum Ultra',
                'last_detail_date': '2026-04-01T12:00:00Z',
              }
            ],
          };
        } else if (path.contains('team_members')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'staff_cloud_remote_77',
                'studio_id': repo.currentUser.id,
                'name': 'Sofia Loren',
                'role_title': 'Master Tinter & PPF Installer',
                'avatar_url': 'https://example.com/sofia.jpg',
                'rating': 5.0,
                'completed_jobs_count': 84,
                'is_available': true,
                'is_founder': false,
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': <dynamic>[]};
      };

      // 3. Trigger cloud hydration
      await repo.loginUser(repo.currentUser);

      // 4. Assert: Union merge has preserved BOTH local items and distinct cloud items!
      final mergedGarage = repo.currentUser.myGarage;
      expect(mergedGarage.length, equals(2), reason: 'Must contain both local BMW and cloud Ferrari');
      expect(mergedGarage.any((v) => v.id == 'veh_local_001'), isTrue);
      expect(mergedGarage.any((v) => v.id == 'veh_cloud_remote_88'), isTrue);

      final mergedTeam = repo.currentUser.teamMembers;
      expect(mergedTeam.length, equals(2), reason: 'Must contain both local Marcus and cloud Sofia');
      expect(mergedTeam.any((m) => m.id == 'staff_local_001'), isTrue);
      expect(mergedTeam.any((m) => m.id == 'staff_cloud_remote_77'), isTrue);

      // 5. Verify local member schedule was preserved
      final restoredMarcus = mergedTeam.firstWhere((m) => m.id == 'staff_local_001');
      expect(restoredMarcus.customWeeklySchedule, isNotNull);
      expect(restoredMarcus.customWeeklySchedule!.first.openTime, equals('09:00 AM'));

      // 6. Verify dedicated storage contains both
      final dedicatedVehicles = await LocalStorageService.loadGarageVehicles();
      expect(dedicatedVehicles.length, equals(2));

      final dedicatedTeam = await LocalStorageService.loadTeamMembers();
      expect(dedicatedTeam.length, equals(2));

      // 7. Simulate browser refresh: the merged union survives reload
      final refreshedRepo = JobRepository();
      await refreshedRepo.init();

      expect(refreshedRepo.currentUser.myGarage.length, equals(2));
      expect(refreshedRepo.currentUser.teamMembers.length, equals(2));
    });
  });

  group('Milestone M2 Adversarial Verification: Technician Assignment Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _activeCloudProvider = null;
    });

    test('ADV-3: Booking appointment technician assignment survives browser reload', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // 1. Create a service booking
      final testBooking = BookingAppointment(
        id: 'bk_assignment_test_99',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Alexander Hayes',
        clientPhone: '512-555-0199',
        clientEmail: 'alex@example.com',
        vehicleYearMakeModel: '2024 Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: const ServicePackage(
          id: 'pkg_track_prep',
          title: 'Track Day Prep & Coating',
          description: 'High heat wheel & caliper coating plus front track PPF wash',
          basePrice: 450.0,
          estimatedDuration: '4 hours',
          includes: ['Wheels-off coating', 'Decontamination wash'],
        ),
        locationType: ServiceLocationType.shop,
        clientAddress: '120 Studio Blvd, Austin, TX',
        scheduledDate: DateTime(2026, 11, 20),
        scheduledTimeSlot: '09:00 AM',
        totalPrice: 450.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      repo.addBooking(testBooking);
      expect(repo.bookings.length, equals(1));
      expect(repo.bookings.first.assignedTeamMemberId, isNull);
      expect(repo.bookings.first.assignedTeamMemberName, isNull);

      // 2. Call assignBookingTechnician
      repo.assignBookingTechnician(
        'bk_assignment_test_99',
        'tech_mateo_01',
        'Mateo Rossi (PPF Lead)',
      );

      // 3. Verify in-memory assignment
      final updatedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_assignment_test_99');
      expect(updatedBooking.assignedTeamMemberId, equals('tech_mateo_01'));
      expect(updatedBooking.assignedTeamMemberName, equals('Mateo Rossi (PPF Lead)'));

      // 4. Verify LocalStorageService persistence
      final savedBookings = await LocalStorageService.loadBookings();
      expect(savedBookings, isNotNull);
      expect(savedBookings!.length, equals(1));
      expect(savedBookings.first.assignedTeamMemberId, equals('tech_mateo_01'));
      expect(savedBookings.first.assignedTeamMemberName, equals('Mateo Rossi (PPF Lead)'));

      // 5. Simulate browser reload (Cmd+R / F5)
      final refreshedRepo = JobRepository();
      await refreshedRepo.init();

      // 6. Assert: Refreshed repository retains technician assignment
      expect(refreshedRepo.bookings.length, equals(1));
      final reloadedBooking = refreshedRepo.bookings.firstWhere((b) => b.id == 'bk_assignment_test_99');
      expect(reloadedBooking.assignedTeamMemberId, equals('tech_mateo_01'));
      expect(reloadedBooking.assignedTeamMemberName, equals('Mateo Rossi (PPF Lead)'));

      // 7. Re-assign to a different technician and reload again to verify update cycle
      refreshedRepo.assignBookingTechnician(
        'bk_assignment_test_99',
        'tech_elena_02',
        'Elena Rostova (Coating Specialist)',
      );

      final secondReload = JobRepository();
      await secondReload.init();

      final reloadedTwice = secondReload.bookings.firstWhere((b) => b.id == 'bk_assignment_test_99');
      expect(reloadedTwice.assignedTeamMemberId, equals('tech_elena_02'));
      expect(reloadedTwice.assignedTeamMemberName, equals('Elena Rostova (Coating Specialist)'));
    });
  });

  group('Milestone M2 Adversarial Verification: Multi-Tech Capacity & Scheduling', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _activeCloudProvider = null;
    });

    test('ADV-4: getSlotStaffingStatus accurately computes on-duty breakdown and remaining capacity based on team schedules', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // Detailer studio has:
      // 1. Founder (always on duty Mon-Sat)
      // 2. Tech Carlos: ON Mon, Wed, Fri (OFF Tue, Thu, Sat, Sun)
      final carlosSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false), // OFF Tuesday
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: false), // OFF Thursday
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      // 3. Tech Elena: ON Tue, Thu (OFF Mon, Wed, Fri, Sat, Sun)
      final elenaSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: false), // OFF Monday
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: false), // OFF Wednesday
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      repo.addTeamMember(TeamMember(
        id: 'tech_carlos',
        name: 'Carlos Ruiz',
        roleTitle: 'Paint Specialist',
        avatarUrl: '',
        customWeeklySchedule: carlosSchedule,
      ));

      repo.addTeamMember(TeamMember(
        id: 'tech_elena',
        name: 'Elena Vance',
        roleTitle: 'Ceramic Specialist',
        avatarUrl: '',
        customWeeklySchedule: elenaSchedule,
      ));

      // Calculate upcoming Tuesday (Founder + Elena on duty, Carlos OFF)
      DateTime nextTuesday = DateTime.now();
      while (nextTuesday.weekday != DateTime.tuesday) {
        nextTuesday = nextTuesday.add(const Duration(days: 1));
      }
      final tuesday = DateTime(nextTuesday.year, nextTuesday.month, nextTuesday.day);

      // Calculate upcoming Wednesday (Founder + Carlos on duty, Elena OFF)
      DateTime nextWednesday = DateTime.now();
      while (nextWednesday.weekday != DateTime.wednesday) {
        nextWednesday = nextWednesday.add(const Duration(days: 1));
      }
      final wednesday = DateTime(nextWednesday.year, nextWednesday.month, nextWednesday.day);

      // ─── TUESDAY VERIFICATION ───
      final tueStatus = repo.getSlotStaffingStatus(tuesday, '10:00 AM');
      expect(tueStatus.totalStaff, equals(3), reason: 'Founder + Carlos + Elena = 3 staff');
      expect(tueStatus.onDutyCount, equals(2), reason: 'Founder + Elena are on duty on Tuesday');
      expect(tueStatus.onDutyMemberIds, containsAll(['founder', 'tech_elena']));
      expect(tueStatus.offMemberIds, contains('tech_carlos'));
      expect(tueStatus.availableCapacity, equals(2));
      expect(tueStatus.isFullyBooked, isFalse);
      expect(tueStatus.isBlocked, isFalse);

      // ─── WEDNESDAY VERIFICATION ───
      final wedStatus = repo.getSlotStaffingStatus(wednesday, '10:00 AM');
      expect(wedStatus.totalStaff, equals(3));
      expect(wedStatus.onDutyCount, equals(2), reason: 'Founder + Carlos are on duty on Wednesday');
      expect(wedStatus.onDutyMemberIds, containsAll(['founder', 'tech_carlos']));
      expect(wedStatus.offMemberIds, contains('tech_elena'));
      expect(wedStatus.availableCapacity, equals(2));
      expect(wedStatus.isFullyBooked, isFalse);

      // ─── ADD BOOKING 1 ON WEDNESDAY 10:00 AM ───
      final b1 = BookingAppointment(
        id: 'bk_w1',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Client 1',
        clientPhone: '555-1111',
        clientEmail: 'c1@example.com',
        vehicleYearMakeModel: '2023 Audi RS6',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Shop',
        scheduledDate: wednesday,
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(b1);

      final wedAfter1 = repo.getSlotStaffingStatus(wednesday, '10:00 AM');
      expect(wedAfter1.activeBookingsCount, equals(1));
      expect(wedAfter1.availableCapacity, equals(1));
      expect(wedAfter1.isFullyBooked, isFalse);

      // ─── ADD BOOKING 2 ON WEDNESDAY 10:00 AM (CAPACITY EXHAUSTED) ───
      final b2 = BookingAppointment(
        id: 'bk_w2',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Client 2',
        clientPhone: '555-2222',
        clientEmail: 'c2@example.com',
        vehicleYearMakeModel: '2022 Porsche 718',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Shop',
        scheduledDate: wednesday,
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(b2);

      final wedAfter2 = repo.getSlotStaffingStatus(wednesday, '10:00 AM');
      expect(wedAfter2.activeBookingsCount, equals(2));
      expect(wedAfter2.availableCapacity, equals(0));
      expect(wedAfter2.isFullyBooked, isTrue);

      // Studio conflicts query must report slot is conflicted
      expect(repo.isSlotConflictedByBooking(wednesday, '10:00 AM'), isTrue);

      // ─── CANCEL BOOKING 1 RE-OPENS CAPACITY ───
      repo.updateBookingStatus('bk_w1', BookingStatus.cancelled);
      final wedAfterCancel = repo.getSlotStaffingStatus(wednesday, '10:00 AM');
      expect(wedAfterCancel.activeBookingsCount, equals(1));
      expect(wedAfterCancel.availableCapacity, equals(1));
      expect(wedAfterCancel.isFullyBooked, isFalse);

      // ─── EXPLICIT AVAILABILITY BLOCK ON CARLOS SPECIFICALLY ───
      repo.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_carlos_wed',
        detailerId: repo.currentUser.id,
        date: wednesday,
        isAllDay: false,
        blockedSlots: ['10:00 AM'],
        teamMemberId: 'tech_carlos',
        reason: 'Dentist appointment',
        createdAt: DateTime.now(),
      ));

      final wedCarlosBlocked = repo.getSlotStaffingStatus(wednesday, '10:00 AM');
      expect(wedCarlosBlocked.onDutyCount, equals(1), reason: 'Carlos is blocked for 10am, only Founder remains');
      expect(wedCarlosBlocked.onDutyMemberIds, equals(['founder']));
      expect(wedCarlosBlocked.offMemberIds, containsAll(['tech_carlos', 'tech_elena']));
      // With 1 remaining booking (bk_w2) and 1 on duty (founder), slot is fully booked
      expect(wedCarlosBlocked.activeBookingsCount, equals(1));
      expect(wedCarlosBlocked.availableCapacity, equals(0));
      expect(wedCarlosBlocked.isFullyBooked, isTrue);
    });

    test('ADV-5: Out-of-hours and closed-day slots report isBlocked: true, zero capacity, and all staff off', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      repo.addTeamMember(const TeamMember(
        id: 'tech_sam',
        name: 'Sam T.',
        roleTitle: 'Apprentice Detailer',
        avatarUrl: '',
      ));

      // Calculate upcoming Sunday (studio closed by default)
      DateTime nextSunday = DateTime.now();
      while (nextSunday.weekday != DateTime.sunday) {
        nextSunday = nextSunday.add(const Duration(days: 1));
      }
      final sunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day);

      // On Sunday, studio is closed
      final sunStatus = repo.getSlotStaffingStatus(sunday, '10:00 AM');
      expect(sunStatus.isBlocked, isTrue);
      expect(sunStatus.onDutyCount, equals(0));
      expect(sunStatus.availableCapacity, equals(0));
      expect(sunStatus.offMemberIds, containsAll(['founder', 'tech_sam']));

      // On a regular business day (Wednesday), a midnight or late-night slot outside operating hours
      DateTime nextWed = DateTime.now();
      while (nextWed.weekday != DateTime.wednesday) {
        nextWed = nextWed.add(const Duration(days: 1));
      }
      final wednesday = DateTime(nextWed.year, nextWed.month, nextWed.day);

      final lateNightStatus = repo.getSlotStaffingStatus(wednesday, '11:00 PM');
      expect(lateNightStatus.isBlocked, isTrue);
      expect(lateNightStatus.onDutyCount, equals(0));
      expect(lateNightStatus.availableCapacity, equals(0));
    });

    test('ADV-6: ID overlap merge preserves local image bytes, lastDetailService, and custom schedule', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      final localPhotoBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x99]);
      final localVeh = UserVehicle(
        id: 'veh_shared_id_101',
        year: 2024,
        make: 'Audi',
        model: 'RS e-tron GT',
        colorName: 'Kemora Gray',
        paintCode: 'LX7H',
        imageUrl: '',
        localImageBytes: localPhotoBytes,
        lastDetailService: 'Ceramic Coating Stage 2',
        lastDetailDate: DateTime(2026, 4, 10),
      );
      repo.addVehicleToGarage(localVeh);

      final localAvatarBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01]);
      final localStaff = TeamMember(
        id: 'staff_shared_id_202',
        name: 'Kenji Sato',
        roleTitle: 'Master Polisher',
        avatarUrl: '',
        localAvatarBytes: localAvatarBytes,
        customWeeklySchedule: const [
          DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '07:30 AM', closeTime: '04:00 PM'),
        ],
      );
      repo.addTeamMember(localStaff);

      // Cloud returns the SAME IDs with updated top-level info, but null local bytes / lastDetailService
      _activeCloudProvider = (Uri uri, String method) {
        final path = uri.path;
        if (path.contains('profiles')) {
          return {
            'statusCode': 200,
            'body': {
              'id': repo.currentUser.id,
              'display_name': repo.currentUser.displayName,
              'business_name': repo.currentUser.businessName,
              'role': 'detailer',
              'email': 'detailer@craft.com',
              'service_packages': [],
            },
          };
        } else if (path.contains('vehicles')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'veh_shared_id_101',
                'user_id': repo.currentUser.id,
                'year': 2024,
                'make': 'Audi',
                'model': 'RS e-tron GT',
                'paint_color': 'Midnight Purple IV',
                'paint_code': 'LP4P',
                'image_url': 'https://example.com/purple_audi.jpg',
                // null last_detail_service in cloud
                'last_detail_service': null,
              }
            ],
          };
        } else if (path.contains('team_members')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'staff_shared_id_202',
                'studio_id': repo.currentUser.id,
                'name': 'Kenji Sato',
                'role_title': 'Chief Detailing Director',
                'avatar_url': 'https://example.com/kenji.jpg',
                // null custom_weekly_schedule in cloud
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': <dynamic>[]};
      };

      await repo.loginUser(repo.currentUser);

      // Verify merged vehicle: takes cloud paint color and cloud image URL,
      // but PRESERVES localImageBytes and lastDetailService!
      expect(repo.currentUser.myGarage.length, equals(1));
      final mergedVeh = repo.currentUser.myGarage.first;
      expect(mergedVeh.id, equals('veh_shared_id_101'));
      expect(mergedVeh.colorName, equals('Midnight Purple IV'));
      expect(mergedVeh.paintCode, equals('LP4P'));
      expect(mergedVeh.localImageBytes, equals(localPhotoBytes));
      expect(mergedVeh.lastDetailService, equals('Ceramic Coating Stage 2'));

      // Verify merged team member: takes cloud role title,
      // but PRESERVES localAvatarBytes and customWeeklySchedule!
      expect(repo.currentUser.teamMembers.length, equals(1));
      final mergedMember = repo.currentUser.teamMembers.first;
      expect(mergedMember.id, equals('staff_shared_id_202'));
      expect(mergedMember.roleTitle, equals('Chief Detailing Director'));
      expect(mergedMember.localAvatarBytes, equals(localAvatarBytes));
      expect(mergedMember.customWeeklySchedule, isNotNull);
      expect(mergedMember.customWeeklySchedule!.first.openTime, equals('07:30 AM'));
    });
  });
}

