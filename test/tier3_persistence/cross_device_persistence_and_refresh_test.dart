import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/supabase_db_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import '../core/test_harness.dart';
import '../core/multi_device_test_harness.dart';

typedef CloudProvider = Map<String, dynamic> Function(Uri uri, String method, String requestBody);
CloudProvider? _mockCloudProvider;
final Map<String, Map<String, dynamic>> _cloudBookingDb = {};

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _TestHttpRequest(method, url);
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

class _TestHttpRequest extends Fake implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  final List<int> _bodyBytes = [];

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;

  _TestHttpRequest(this.method, this.uri);

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  void write(Object? obj) {
    if (obj != null) {
      _bodyBytes.addAll(utf8.encode(obj.toString()));
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator));
  }

  @override
  void writeln([Object? obj = ""]) {
    write('$obj\n');
  }

  @override
  void writeCharCode(int charCode) {
    _bodyBytes.add(charCode);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future flush() async {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final bodyString = utf8.decode(_bodyBytes, allowMalformed: true);
    if (_mockCloudProvider != null) {
      final res = _mockCloudProvider!(uri, method, bodyString);
      final body = res['body'];
      final statusCode = res['statusCode'] as int? ?? 200;
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      return _TestHttpResponse(statusCode, Uint8List.fromList(jsonBytes));
    }

    if (uri.path.contains('/rest/v1/bookings')) {
      if (method == 'POST') {
        try {
          final decoded = jsonDecode(bodyString);
          if (decoded is List) {
            for (final r in decoded) {
              if (r is Map && r['id'] != null) {
                _cloudBookingDb[r['id'] as String] = Map<String, dynamic>.from(r);
              }
            }
          } else if (decoded is Map && decoded['id'] != null) {
            _cloudBookingDb[decoded['id'] as String] = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
        final jsonBytes = utf8.encode(bodyString);
        return _TestHttpResponse(201, Uint8List.fromList(jsonBytes));
      } else if (method == 'PATCH') {
        try {
          final idMatch = RegExp(r'id=eq\.([a-zA-Z0-9_\-]+)').firstMatch(uri.query);
          final bId = idMatch?.group(1);
          final decoded = jsonDecode(bodyString) as Map<String, dynamic>;
          if (bId != null && _cloudBookingDb.containsKey(bId)) {
            _cloudBookingDb[bId] = {..._cloudBookingDb[bId]!, ...decoded};
          }
        } catch (_) {}
        final jsonBytes = utf8.encode(bodyString);
        return _TestHttpResponse(200, Uint8List.fromList(jsonBytes));
      } else if (method == 'DELETE') {
        final idMatch = RegExp(r'id=eq\.([a-zA-Z0-9_\-]+)').firstMatch(uri.query);
        final bId = idMatch?.group(1);
        if (bId != null) _cloudBookingDb.remove(bId);
        return _TestHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
      } else {
        // GET
        final records = _cloudBookingDb.values.toList();
        final jsonBytes = utf8.encode(jsonEncode(records));
        return _TestHttpResponse(200, Uint8List.fromList(jsonBytes));
      }
    }

    return _TestHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _map = {};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = [value.toString()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }
  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  String? value(String name) => _map[name.toLowerCase()]?.firstOrNull;
}

class _TestHttpResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final Uint8List bodyBytes;

  _TestHttpResponse(this.statusCode, this.bodyBytes);

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
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _MockResponseHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bodyBytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}

class _MockResponseHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Device Persistence & Refresh Tests (Tier 3)', () {
    late MultiDeviceTestHarness harness;

    const samplePackage = ServicePackage(
      id: 'pkg_persist_01',
      title: 'Full Paint Enhancement',
      description: 'Single-stage machine polish and sealant',
      basePrice: 350.0,
      estimatedDuration: '3 hrs',
      includes: ['Foam wash', 'Clay bar', 'Machine polish'],
    );

    BookingAppointment createTestBooking({
      required String id,
      BookingStatus status = BookingStatus.confirmed,
    }) {
      return BookingAppointment(
        id: id,
        clientId: 'usr_client_persist',
        detailerId: 'usr_detailer_pro',
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Precision Detailing',
        detailerAvatar: '',
        clientName: 'Alex Mercer',
        clientPhone: '(512) 555-9876',
        clientEmail: 'alex.mercer@example.com',
        vehicleYearMakeModel: '2024 Porsche Cayman GT4',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 350.0,
        depositAmount: 75.0,
        status: status,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      _cloudBookingDb.clear();
      _mockCloudProvider = null;
      HttpOverrides.global = _TestHttpOverrides();
      await SupabaseService.initialize();
      harness = MultiDeviceTestHarness();
    });

    tearDown(() {
      _mockCloudProvider = null;
      _cloudBookingDb.clear();
      harness.dispose();
    });

    test('1. Real-Time Status Changes Persist to Local Storage & Survive Browser Refresh', () async {
      final initialBooking = createTestBooking(
        id: 'bk_refresh_persist_01',
        status: BookingStatus.confirmed,
      );
      _cloudBookingDb[initialBooking.id] = initialBooking.toSupabase();

      final deviceA = await harness.createClientDeviceSession(
        deviceId: 'device_a',
        userId: 'usr_client_persist',
        email: 'alex.mercer@example.com',
        initialBookings: [initialBooking],
      );

      final deviceB = await harness.createClientDeviceSession(
        deviceId: 'device_b',
        userId: 'usr_client_persist',
        email: 'alex.mercer@example.com',
        initialBookings: [initialBooking],
      );

      // Device A transitions status to In Progress
      await deviceA.updateBookingStatus('bk_refresh_persist_01', BookingStatus.inProgress);
      harness.syncRawPayload(deviceA, {
        'id': 'bk_refresh_persist_01',
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Verify Device B in-memory state updated
      expect(deviceB.clientBookings.firstWhere((b) => b.id == 'bk_refresh_persist_01').status, equals(BookingStatus.inProgress));

      // Simulate browser refresh on Device B
      final refreshedDeviceB = await TestHarness.simulateBrowserRefresh(deviceB);

      // Verify state survived browser refresh directly from LocalStorageService
      expect(refreshedDeviceB.clientBookings.any((b) => b.id == 'bk_refresh_persist_01'), isTrue);
      final restored = refreshedDeviceB.clientBookings.firstWhere((b) => b.id == 'bk_refresh_persist_01');
      expect(restored.status, equals(BookingStatus.inProgress));
    });

    test('2. Pull-to-Refresh Cloud Synchronization on Secondary Device', () async {
      final deviceB = await harness.createClientDeviceSession(
        deviceId: 'device_b',
        userId: 'usr_client_persist',
        email: 'alex.mercer@example.com',
      );

      // Cloud mock returns updated booking that occurred while Device B was offline
      final cloudBooking = createTestBooking(
        id: 'bk_cloud_synced_01',
        status: BookingStatus.completed,
      );

      _mockCloudProvider = (uri, method, bodyString) {
        if (uri.path.contains('/rest/v1/bookings') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [cloudBooking.toSupabase()],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      // Initially Device B has 0 bookings
      expect(deviceB.clientBookings, isEmpty);

      // Trigger pull-to-refresh
      await deviceB.refreshBookings();

      // Device B successfully synchronizes from cloud
      expect(deviceB.clientBookings.length, equals(1));
      expect(deviceB.clientBookings.first.id, equals('bk_cloud_synced_01'));
      expect(deviceB.clientBookings.first.status, equals(BookingStatus.completed));
    });

    test('3. Cross-Device Account Log-out & Log-in Consistency', () async {
      final alexBooking = createTestBooking(
        id: 'bk_alex_session_01',
        status: BookingStatus.confirmed,
      );
      _cloudBookingDb[alexBooking.id] = alexBooking.toSupabase();

      final alexUser = UserProfile(
        id: 'usr_client_persist',
        role: UserRole.client,
        username: 'alex.mercer@example.com',
        displayName: 'Alex Mercer',
        businessName: '',
        servicePackages: const [],
      );

      final deviceB = await harness.createDeviceSession(
        user: alexUser,
        isLoggedIn: true,
        initialBookings: [alexBooking],
      );

      expect(deviceB.clientBookings.length, equals(1));

      // Alex logs out
      await deviceB.logoutUser();
      expect(deviceB.isLoggedIn, isFalse);

      // Alex logs back in
      await deviceB.loginUser(alexUser);
      expect(deviceB.isLoggedIn, isTrue);

      // Bookings cleanly restored
      expect(deviceB.clientBookings.any((b) => b.id == 'bk_alex_session_01'), isTrue);
    });

    test('4. Studio Workbench Authoritative Supabase Sync: Deleted Services, Portfolio Jobs, Team Members, Inventory, and Calendar Blocks Stay Deleted Across Devices', () async {
      const studioId = 'usr_studio_sync_01';
      const deletedPkg = ServicePackage(
        id: 'pkg_deleted_on_device_a',
        title: 'Deleted Paint Correction',
        description: 'Should stay deleted after cloud sync',
        basePrice: 499.0,
        estimatedDuration: '4 hrs',
        includes: ['Paint correction'],
      );
      const remainingPkg = ServicePackage(
        id: 'pkg_remaining_on_cloud',
        title: 'Ceramic Maintenance Wash',
        description: 'Active service package',
        basePrice: 120.0,
        estimatedDuration: '90 mins',
        includes: ['Foam wash'],
      );
      final initialUser = UserProfile(
        id: studioId,
        role: UserRole.detailer,
        username: 'apexstudio',
        displayName: 'Marcus Vance',
        businessName: 'Apex Precision Studio',
        servicePackages: const [deletedPkg, remainingPkg],
        teamMembers: const [
          TeamMember(
            id: 'tm_deleted_01',
            name: 'Removed Tech',
            roleTitle: 'Tech',
            avatarUrl: '',
          ),
          TeamMember(
            id: 'tm_active_02',
            name: 'Elena Tech',
            roleTitle: 'Lead Polisher',
            avatarUrl: '',
          ),
        ],
        ownerPinHash: 'salt:hash123',
      );

      final deletedJob = DetailJob(
        id: 'job_deleted_01',
        author: initialUser,
        createdAt: DateTime(2026, 11, 1),
        title: 'Deleted Portfolio Entry',
        description: 'Should be removed on Device B sync',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: '911',
        paintColorName: 'GT Silver',
        paintCode: 'M7Z',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 130,
        finalPaintThicknessMicrons: 125,
        defectSeverity: 2,
        serviceType: 'Correction',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/b.jpg',
        afterImageUrl: 'https://example.com/a.jpg',
      );

      final remainingJob = DetailJob(
        id: 'job_active_02',
        author: initialUser,
        createdAt: DateTime(2026, 11, 5),
        title: 'Active Portfolio Entry',
        description: 'Stays in Supabase',
        vehicleYear: 2025,
        vehicleMake: 'BMW',
        vehicleModel: 'M4',
        paintColorName: 'Isle of Man Green',
        paintCode: 'C4G',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 135,
        finalPaintThicknessMicrons: 131,
        defectSeverity: 2,
        serviceType: 'Ceramic',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/b2.jpg',
        afterImageUrl: 'https://example.com/a2.jpg',
      );

      const deletedInv = InventoryItem(
        id: 'inv_deleted_01',
        name: 'Old Compound',
        category: InventoryCategory.chemicals,
      );
      const remainingInv = InventoryItem(
        id: 'inv_active_02',
        name: 'Active Coating',
        category: InventoryCategory.chemicals,
      );

      final deletedBlock = CalendarAvailabilityBlock(
        id: 'blk_deleted_01',
        detailerId: studioId,
        date: DateTime(2026, 11, 20),
        isAllDay: true,
        createdAt: DateTime(2026, 11, 1),
      );
      final remainingBlock = CalendarAvailabilityBlock(
        id: 'blk_active_02',
        detailerId: studioId,
        date: DateTime(2026, 11, 25),
        isAllDay: true,
        createdAt: DateTime(2026, 11, 1),
      );

      // Verify saveUserProfile does NOT send owner_pin_hash and survives PGRST204 checks
      final capturedProfileUpserts = <Map<String, dynamic>>[];
      bool sawReuploadOfDeletedPackage = false;

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('/rest/v1/profiles') && method == 'POST') {
          final decoded = jsonDecode(requestBody);
          final map = decoded is List
              ? Map<String, dynamic>.from(decoded.first as Map)
              : Map<String, dynamic>.from(decoded as Map);
          capturedProfileUpserts.add(map);
          if (map.containsKey('owner_pin_hash')) {
            return {
              'statusCode': 400,
              'body': {
                'code': 'PGRST204',
                'message': "Could not find the 'owner_pin_hash' column of 'profiles' in the schema cache",
              },
            };
          }
          final pkgs = (map['service_packages'] as List<dynamic>?) ?? [];
          if (pkgs.any((p) => (p as Map)['id'] == deletedPkg.id)) {
            sawReuploadOfDeletedPackage = true;
          }
          return {'statusCode': 201, 'body': [map]};
        }
        return {'statusCode': 200, 'body': []};
      };

      await SupabaseDbService.saveUserProfile(
        initialUser.copyWith(servicePackages: const [remainingPkg]),
        inventoryItems: const [remainingInv],
      );
      expect(capturedProfileUpserts, isNotEmpty);
      expect(capturedProfileUpserts.first.containsKey('owner_pin_hash'), isFalse);

      // Seed Device B with stale local items before Device A deleted them
      await LocalStorageService.saveServicePackages([deletedPkg, remainingPkg]);
      await LocalStorageService.saveTeamMembers(initialUser.teamMembers);
      await LocalStorageService.saveInventoryItems([deletedInv, remainingInv]);
      await LocalStorageService.saveCalendarBlocks([deletedBlock, remainingBlock]);
      await LocalStorageService.saveCustomJobs([deletedJob, remainingJob]);

      final deviceB = await harness.createDeviceSession(
        user: initialUser,
        isLoggedIn: true,
      );
      deviceB.addJob(deletedJob);
      deviceB.addJob(remainingJob);
      deviceB.addInventoryItem(deletedInv);
      deviceB.addInventoryItem(remainingInv);
      deviceB.addAvailabilityBlock(deletedBlock);
      deviceB.addAvailabilityBlock(remainingBlock);
      // Confirm Device B starts with stale cached items before refresh
      expect(deviceB.currentUser.servicePackages.length, equals(2));
      expect(deviceB.currentUser.teamMembers.length, equals(2));
      expect(deviceB.jobs.any((j) => j.id == deletedJob.id), isTrue);

      // Flush in-flight background writes from Device B seeding before enabling deletion-reupload assertions
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sawReuploadOfDeletedPackage = false;

      // Cloud now reflects Device A deletions (even testing empty service_packages in step 2)
      List<Map<String, dynamic>> cloudPackages = [remainingPkg.toJson()];
      final teamJson = jsonEncode([initialUser.teamMembers[1].toJson()]);
      final teamB64 = base64Encode(utf8.encode(teamJson));
      final invJson = jsonEncode([remainingInv.toJson()]);
      final invB64 = base64Encode(utf8.encode(invJson));

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('/rest/v1/profiles') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': studioId,
                'username': 'apexstudio',
                'display_name': 'Marcus Vance',
                'business_name': 'Apex Precision Studio',
                'role': 'detailer',
                'service_radius': '25 miles||team:$teamB64||inv:$invB64',
                'service_packages': cloudPackages,
              }
            ],
          };
        }
        if (uri.path.contains('/rest/v1/profiles') && (method == 'POST' || method == 'PATCH')) {
          if (requestBody.contains(deletedPkg.id)) {
            sawReuploadOfDeletedPackage = true;
          }
          return {'statusCode': 200, 'body': []};
        }
        if (uri.path.contains('/rest/v1/team_members') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'tm_active_02',
                'studio_id': studioId,
                'name': 'Elena Tech',
                'role_title': 'Lead Polisher',
              }
            ],
          };
        }
        if (uri.path.contains('/rest/v1/jobs') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [
              {'id': remainingJob.id, 'raw_data': remainingJob.toJson()},
            ],
          };
        }
        if (uri.path.contains('/rest/v1/availability_blocks') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [remainingBlock.toSupabase()],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      // Refresh Studio Workbench on Device B
      await deviceB.refreshStudioWorkbench();

      // Services: deletedPkg removed, only remainingPkg present, never re-uploaded
      expect(deviceB.currentUser.servicePackages.map((p) => p.id), equals([remainingPkg.id]));
      expect(sawReuploadOfDeletedPackage, isFalse);
      final persistedPackages = await LocalStorageService.loadServicePackages();
      expect(persistedPackages.map((p) => p.id), equals([remainingPkg.id]));

      // Portfolio jobs: deletedJob removed
      expect(deviceB.jobs.any((j) => j.id == deletedJob.id), isFalse);
      expect(deviceB.jobs.any((j) => j.id == remainingJob.id), isTrue);

      // Team members: deleted member removed
      expect(deviceB.currentUser.teamMembers.map((m) => m.id), equals(['tm_active_02']));

      // Inventory: deletedInv removed
      expect(deviceB.inventoryItems.map((i) => i.id), equals([remainingInv.id]));

      // Calendar availability blocks: deletedBlock removed
      expect(deviceB.availabilityBlocks.map((b) => b.id), equals([remainingBlock.id]));

      // Edge case: even when ALL services are deleted in Supabase ([]), Device B clears them instead of resurrecting local cache
      cloudPackages = [];
      await deviceB.refreshStudioWorkbench();
      expect(deviceB.currentUser.servicePackages, isEmpty);
      expect(await LocalStorageService.loadServicePackages(), isEmpty);
      expect(sawReuploadOfDeletedPackage, isFalse);
    });

    test('5. Explore Feed Preserves Detailer Recipe Author Across Client Devices Sharing Default Username', () async {
      final detailerA = UserProfile(
        id: 'usr_detailer_creator_a',
        role: UserRole.detailer,
        username: 'user',
        displayName: 'Marco Rossi',
        businessName: 'Luxe Coat Studio',
        location: 'Austin, TX',
        isVerifiedHost: true,
        servicePackages: const [samplePackage],
      );

      final clientB = UserProfile(
        id: 'usr_client_phone_b',
        role: UserRole.client,
        username: 'user',
        displayName: 'Phone Client User',
        businessName: '',
        servicePackages: const [],
      );

      final publishedRecipe = DetailJob(
        id: 'job_recipe_creator_01',
        author: detailerA,
        createdAt: DateTime(2026, 11, 12),
        title: 'Two-Stage Ceramic Mirror Recipe',
        description: 'Wet sand + rotary cut + DA jeweling',
        vehicleYear: 2024,
        vehicleMake: 'Ferrari',
        vehicleModel: '296 GTB',
        paintColorName: 'Rosso Corsa',
        paintCode: '322',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 132,
        finalPaintThicknessMicrons: 127,
        defectSeverity: 3,
        serviceType: 'Paint Correction',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/ferrari_b.jpg',
        afterImageUrl: 'https://example.com/ferrari_a.jpg',
      );

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('/rest/v1/jobs') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': publishedRecipe.id,
                'author_id': detailerA.id,
                'raw_data': publishedRecipe.toJson(),
              },
            ],
          };
        }
        if (uri.path.contains('/rest/v1/profiles') && method == 'GET') {
          if (uri.query.contains('id=eq.${clientB.id}')) {
            return {
              'statusCode': 200,
              'body': [
                {
                  'id': clientB.id,
                  'username': 'user',
                  'display_name': 'Phone Client User',
                  'business_name': '',
                  'role': 'client',
                },
              ],
            };
          }
          return {
            'statusCode': 200,
            'body': [
              {
                'id': detailerA.id,
                'username': 'user',
                'display_name': 'Marco Rossi',
                'business_name': 'Luxe Coat Studio',
                'location': 'Austin, TX',
                'role': 'detailer',
                'is_verified_host': true,
                'service_packages': [samplePackage.toJson()],
              },
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      final clientDevice = await harness.createDeviceSession(
        user: clientB,
        isLoggedIn: true,
      );

      await clientDevice.refreshExploreFeed();

      final fetched = clientDevice.jobs.firstWhere((j) => j.id == publishedRecipe.id);
      expect(fetched.author.id, equals(detailerA.id));
      expect(fetched.author.businessName, equals('Luxe Coat Studio'));
      expect(fetched.author.displayName, equals('Marco Rossi'));
      expect(fetched.author.role, equals(UserRole.detailer));
      expect(fetched.author.id, isNot(equals(clientB.id)));
      expect(fetched.author.displayName, isNot(equals('Phone Client User')));
    });

    test('6. Pausing Studio Hides Studio & All Posted Recipes from Explore and Blocks Bookings', () async {
      var pausedInCloud = false;
      final studioUser = UserProfile(
        id: 'usr_pause_studio_01',
        role: UserRole.detailer,
        username: 'stealthcoat',
        displayName: 'Elena Vance',
        businessName: 'Stealth Coat Lab',
        location: 'Austin, TX',
        isVerifiedHost: true,
        isStudioPaused: false,
        servicePackages: const [samplePackage],
      );

      final clientUser = UserProfile(
        id: 'usr_client_viewer_01',
        role: UserRole.client,
        username: 'clientviewer',
        displayName: 'Sam Driver',
        businessName: '',
        servicePackages: const [],
      );

      final studioRecipe = DetailJob(
        id: 'job_stealth_recipe_01',
        author: studioUser,
        createdAt: DateTime(2026, 11, 13),
        title: 'Track Pack PPF + Ceramic',
        description: 'Full front PPF plus 5-year coating',
        vehicleYear: 2025,
        vehicleMake: 'Porsche',
        vehicleModel: 'GT3 RS',
        paintColorName: 'Ice Grey Metallic',
        paintCode: 'M7G',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 130,
        finalPaintThicknessMicrons: 126,
        defectSeverity: 2,
        serviceType: 'Ceramic Coating',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/gt3_b.jpg',
        afterImageUrl: 'https://example.com/gt3_a.jpg',
      );

      var cloudJob = studioRecipe;

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('/rest/v1/profiles') && (method == 'POST' || method == 'PATCH')) {
          final decoded = jsonDecode(requestBody);
          final map = decoded is List ? decoded.first as Map : decoded as Map;
          if (map.containsKey('is_studio_paused')) {
            pausedInCloud = map['is_studio_paused'] == true;
          }
          return {'statusCode': 200, 'body': []};
        }
        if (uri.path.contains('/rest/v1/jobs') && (method == 'POST' || method == 'PATCH')) {
          final decoded = jsonDecode(requestBody);
          final map = decoded is List ? decoded.first as Map : decoded as Map;
          if (map['raw_data'] != null) {
            cloudJob = DetailJob.fromJson(Map<String, dynamic>.from(map['raw_data'] as Map));
          }
          return {'statusCode': 200, 'body': []};
        }
        if (uri.path.contains('/rest/v1/jobs') && method == 'GET') {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': cloudJob.id,
                'author_id': studioUser.id,
                'raw_data': cloudJob.toJson(),
              },
            ],
          };
        }
        if (uri.path.contains('/rest/v1/profiles') && method == 'GET') {
          if (uri.query.contains('id=eq.${clientUser.id}')) {
            return {
              'statusCode': 200,
              'body': [
                {
                  'id': clientUser.id,
                  'username': 'clientviewer',
                  'display_name': 'Sam Driver',
                  'business_name': '',
                  'role': 'client',
                },
              ],
            };
          }
          return {
            'statusCode': 200,
            'body': [
              {
                'id': studioUser.id,
                'username': 'stealthcoat',
                'display_name': 'Elena Vance',
                'business_name': 'Stealth Coat Lab',
                'location': 'Austin, TX',
                'role': 'detailer',
                'is_verified_host': true,
                'is_studio_paused': pausedInCloud,
                'service_packages': [samplePackage.toJson()],
              },
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      final studioDevice = await harness.createDeviceSession(
        user: studioUser,
        isLoggedIn: true,
      );
      studioDevice.addJob(studioRecipe);

      final clientDevice = await harness.createDeviceSession(
        user: clientUser,
        isLoggedIn: true,
      );

      // Initially LIVE: visible to clients on Explore
      await clientDevice.refreshExploreFeed();
      expect(clientDevice.publicDetailers.any((d) => d.id == studioUser.id), isTrue);
      expect(clientDevice.filteredDetailers.any((d) => d.id == studioUser.id), isTrue);
      expect(clientDevice.filteredJobs.any((j) => j.id == studioRecipe.id), isTrue);

      // Detailer pauses studio
      final pauseResult = await studioDevice.setStudioPaused(true);
      expect(pauseResult.success, isTrue);

      // Studio own Explore hides paused studio & recipes, while Studio Workbench Portfolio keeps it
      expect(studioDevice.publicDetailers.any((d) => d.id == studioUser.id), isFalse);
      expect(studioDevice.filteredJobs.any((j) => j.id == studioRecipe.id), isFalse);
      expect(studioDevice.getJobsByDetailer(studioUser.id).any((j) => j.id == studioRecipe.id), isTrue);

      // Client refreshes Explore feed: studio and all its recipes are hidden
      await clientDevice.refreshExploreFeed();
      expect(clientDevice.publicDetailers.any((d) => d.id == studioUser.id), isFalse);
      expect(clientDevice.filteredDetailers.any((d) => d.id == studioUser.id), isFalse);
      expect(clientDevice.filteredJobs.any((j) => j.id == studioRecipe.id), isFalse);

      // Client booking against paused studio is blocked
      final blockedBooking = createTestBooking(id: 'bk_paused_block_01').copyWith(
        detailerId: studioUser.id,
        clientId: clientUser.id,
      );
      expect(clientDevice.addBooking(blockedBooking), isFalse);

      // Detailer resumes studio: studio & recipes reappear and booking succeeds
      final resumeResult = await studioDevice.setStudioPaused(false);
      expect(resumeResult.success, isTrue);

      await clientDevice.refreshExploreFeed();
      expect(clientDevice.publicDetailers.any((d) => d.id == studioUser.id), isTrue);
      expect(clientDevice.filteredDetailers.any((d) => d.id == studioUser.id), isTrue);
      expect(clientDevice.filteredJobs.any((j) => j.id == studioRecipe.id), isTrue);
      expect(
        clientDevice.addBooking(
          createTestBooking(id: 'bk_resumed_ok_01').copyWith(
            detailerId: studioUser.id,
            clientId: clientUser.id,
          ),
        ),
        isTrue,
      );
    });
  });
}
