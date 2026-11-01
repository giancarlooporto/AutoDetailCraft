import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import '../core/mock_http_client.dart';
import '../core/multi_device_test_harness.dart';

typedef CloudProvider = Map<String, dynamic> Function(Uri uri, String method, String requestBody);
CloudProvider? _mockCloudProvider;
final Map<String, Map<String, dynamic>> _cloudBookingDb = {};

class _AdversarialHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _AdversarialHttpClient();
}

class _AdversarialHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _AdversarialHttpRequest(method, url);
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
  final List<int> _bodyBytes = [];

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
      return _AdversarialHttpResponse(statusCode, Uint8List.fromList(jsonBytes));
    }

    // Handle RPC claim_guest_bookings
    if (uri.path.contains('/rest/v1/rpc/claim_guest_bookings')) {
      int claimed = 0;
      try {
        final decoded = jsonDecode(bodyString) as Map<String, dynamic>;
        final targetEmail = (decoded['target_email'] as String?)?.trim().toLowerCase();
        if (targetEmail != null && targetEmail.isNotEmpty) {
          for (final entry in _cloudBookingDb.entries) {
            final email = (entry.value['client_email'] as String?)?.trim().toLowerCase();
            final cId = entry.value['client_id'];
            if (email == targetEmail && (cId == null || cId == '' || cId == 'usr_you')) {
              entry.value['client_id'] = 'usr_user_secondary';
              claimed++;
            }
          }
        }
      } catch (_) {}
      return _AdversarialHttpResponse(200, Uint8List.fromList(utf8.encode(jsonEncode(claimed))));
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
        return _AdversarialHttpResponse(201, Uint8List.fromList(jsonBytes));
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
        return _AdversarialHttpResponse(200, Uint8List.fromList(jsonBytes));
      } else if (method == 'DELETE') {
        final idMatch = RegExp(r'id=eq\.([a-zA-Z0-9_\-]+)').firstMatch(uri.query);
        final bId = idMatch?.group(1);
        if (bId != null) _cloudBookingDb.remove(bId);
        return _AdversarialHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
      } else {
        // GET
        final records = _cloudBookingDb.values.toList();
        final jsonBytes = utf8.encode(jsonEncode(records));
        return _AdversarialHttpResponse(200, Uint8List.fromList(jsonBytes));
      }
    }

    return _AdversarialHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
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

  group('Challenger 2 M1 Adversarial Stress Test Suite', () {
    late MultiDeviceTestHarness harness;

    const testPackage = ServicePackage(
      id: 'pkg_adv_stress_01',
      title: 'Full Diamond Ceramic Coating',
      description: 'Multi-stage paint correction and 5-year ceramic application',
      basePrice: 850.0,
      estimatedDuration: '5 hrs',
      includes: ['Paint Decontamination', '2-Stage Polish', 'Diamond 10H Ceramic'],
    );

    BookingAppointment createTestBooking({
      required String id,
      String? clientId = 'usr_client_01',
      String clientEmail = 'client1@test.com',
      String detailerId = 'usr_detailer_pro',
      BookingStatus status = BookingStatus.confirmed,
      DateTime? scheduledDate,
      String scheduledTimeSlot = '9:00 AM - 1:00 PM',
      String vehicleName = '2025 Porsche 911 GT3 RS',
    }) {
      return BookingAppointment(
        id: id,
        clientId: clientId,
        detailerId: detailerId,
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Precision Detailing',
        detailerAvatar: '',
        clientName: 'Alex Mercer',
        clientPhone: '(512) 555-0100',
        clientEmail: clientEmail,
        vehicleYearMakeModel: vehicleName,
        vehicleSize: VehicleSize.coupeSedan,
        package: testPackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way, Austin TX',
        scheduledDate: scheduledDate ?? DateTime(2026, 11, 15, 9, 0),
        scheduledTimeSlot: scheduledTimeSlot,
        totalPrice: 850.0,
        depositAmount: 200.0,
        status: status,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      _cloudBookingDb.clear();
      _mockCloudProvider = null;
      HttpOverrides.global = _AdversarialHttpOverrides();
      await SupabaseService.initialize();
      harness = MultiDeviceTestHarness();
    });

    tearDown(() {
      _mockCloudProvider = null;
      harness.dispose();
    });

    test('1. Cross-Device Privacy Isolation: 20 private bookings for Client 1 broadcast across bus produce 0 leaked bookings in Client 2 and Guest Device across all 4 categories', () async {
      // 1. Register 3 main sessions: Client 1, Client 2, and Detailer Studio
      final client1 = await harness.createClientDeviceSession(
        deviceId: 'dev_client_01',
        userId: 'usr_client_01',
        email: 'client1@test.com',
        displayName: 'Client One',
      );

      final client2 = await harness.createClientDeviceSession(
        deviceId: 'dev_client_02',
        userId: 'usr_client_02',
        email: 'client2@test.com',
        displayName: 'Client Two',
      );

      final detailer = await harness.createDetailerSession(
        detailerId: 'usr_detailer_pro',
        email: 'marcus@apexprecision.com',
        displayName: 'Marcus Vance',
        businessName: 'Apex Precision Detailing',
      );

      // Register an additional unauthenticated Guest session on Device 3
      final guestDevice = await harness.createDeviceSession(
        user: const UserProfile(
          id: 'usr_you',
          role: UserRole.client,
          username: 'guest',
          displayName: 'Guest User',
          businessName: '',
          avatarUrl: '',
          coverUrl: '',
          servicePackages: [],
        ),
        isLoggedIn: false,
      );

      // 2. Generate 20 private bookings for Client 1 across all 4 status categories:
      // - 5 Upcoming (confirmed or pending)
      // - 5 In-Progress
      // - 5 Completed
      // - 5 Cancelled
      final List<BookingAppointment> client1Bookings = [];
      for (var i = 1; i <= 20; i++) {
        BookingStatus status;
        if (i <= 3) {
          status = BookingStatus.confirmed;
        } else if (i <= 5) {
          status = BookingStatus.pending;
        } else if (i <= 10) {
          status = BookingStatus.inProgress;
        } else if (i <= 15) {
          status = BookingStatus.completed;
        } else {
          status = BookingStatus.cancelled;
        }

        final b = createTestBooking(
          id: 'bk_c1_private_${i.toString().padLeft(2, '0')}',
          clientId: 'usr_client_01',
          clientEmail: 'client1@test.com',
          detailerId: 'usr_detailer_pro',
          status: status,
          scheduledDate: DateTime(2026, 11, 10).add(Duration(days: i)),
          scheduledTimeSlot: '${8 + (i % 8)}:00 AM',
          vehicleName: 'Client 1 Vehicle #$i',
        );
        client1Bookings.add(b);
      }

      // Add each booking to Client 1 and broadcast it to the bus
      for (final b in client1Bookings) {
        client1.addBooking(b, allowOverbooking: true, syncToCloud: false);
        harness.syncBookingChange(client1, b);
      }

      // Concurrently simulate live modifications on some of Client 1's bookings
      // Reschedule booking 1
      client1.rescheduleBooking('bk_c1_private_01', DateTime(2026, 12, 1), '4:00 PM');
      final rescheduledB1 = client1.bookings.firstWhere((b) => b.id == 'bk_c1_private_01');
      harness.syncBookingChange(client1, rescheduledB1);

      // Cancel booking 2
      client1.cancelBooking('bk_c1_private_02');
      final cancelledB2 = client1.bookings.firstWhere((b) => b.id == 'bk_c1_private_02');
      harness.syncBookingChange(client1, cancelledB2);

      // 3. Verify Client 1 state
      expect(client1.bookings.length, equals(20));
      expect(client1.clientBookings.length, equals(20));

      // 4. Verify Detailer session DID receive all 20 bookings
      expect(detailer.bookings.length, equals(20));

      // 5. EMPIRICAL VERIFICATION: Verify Client 2 has 0 leaked bookings
      expect(client2.clientBookings.length, equals(0), reason: 'Client 2 clientBookings must be 0');
      expect(client2.bookings.length, equals(0), reason: 'Client 2 in-memory bookings must be 0');

      final c2Upcoming = client2.clientBookings.where((b) =>
          b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();
      final c2InProgress = client2.clientBookings.where((b) =>
          b.status == BookingStatus.inProgress).toList();
      final c2Completed = client2.clientBookings.where((b) =>
          b.status == BookingStatus.completed).toList();
      final c2Cancelled = client2.clientBookings.where((b) =>
          b.status == BookingStatus.cancelled).toList();

      expect(c2Upcoming, isEmpty, reason: 'Client 2 leaked upcoming bookings');
      expect(c2InProgress, isEmpty, reason: 'Client 2 leaked in-progress bookings');
      expect(c2Completed, isEmpty, reason: 'Client 2 leaked completed bookings');
      expect(c2Cancelled, isEmpty, reason: 'Client 2 leaked cancelled bookings');

      // 6. EMPIRICAL VERIFICATION: Verify unauthenticated Guest Device also received 0 leaked bookings
      expect(guestDevice.clientBookings, isEmpty, reason: 'Guest device clientBookings must be empty');
      expect(guestDevice.bookings, isEmpty, reason: 'Guest device in-memory bookings must be empty');
    });

    test('2. Guest Booking Claiming on Secondary Login: Guest bookings across all 4 categories created on Device 1 reconcile identically on Device 2 via dual-key matching and RPC claim', () async {
      const claimEmail = 'user@test.com';

      // 1. Device 1 is an unauthenticated guest session
      final device1 = await harness.createDeviceSession(
        user: const UserProfile(
          id: 'usr_you',
          role: UserRole.client,
          username: 'guest',
          displayName: 'Guest Device 1',
          businessName: '',
          avatarUrl: '',
          coverUrl: '',
          servicePackages: [],
        ),
        isLoggedIn: false,
      );

      // Create 4 guest bookings on Device 1 with email user@test.com across all 4 status categories:
      final guestUpcoming = createTestBooking(
        id: 'bk_guest_cat_upcoming',
        clientId: null,
        clientEmail: claimEmail,
        status: BookingStatus.confirmed,
        scheduledDate: DateTime(2026, 11, 20),
        vehicleName: 'Guest Tesla Model S',
      );
      final guestInProgress = createTestBooking(
        id: 'bk_guest_cat_inprogress',
        clientId: null,
        clientEmail: claimEmail,
        status: BookingStatus.inProgress,
        scheduledDate: DateTime(2026, 11, 21),
        vehicleName: 'Guest Tesla Model S',
      );
      final guestCompleted = createTestBooking(
        id: 'bk_guest_cat_completed',
        clientId: null,
        clientEmail: claimEmail,
        status: BookingStatus.completed,
        scheduledDate: DateTime(2026, 11, 10),
        vehicleName: 'Guest Tesla Model S',
      );
      final guestCancelled = createTestBooking(
        id: 'bk_guest_cat_cancelled',
        clientId: null,
        clientEmail: claimEmail,
        status: BookingStatus.cancelled,
        scheduledDate: DateTime(2026, 11, 12),
        vehicleName: 'Guest Tesla Model S',
      );

      final allGuestBookings = [guestUpcoming, guestInProgress, guestCompleted, guestCancelled];

      // Seed both Device 1 local memory and cloud database
      for (final b in allGuestBookings) {
        device1.addBooking(b, allowOverbooking: true, syncToCloud: false);
        _cloudBookingDb[b.id] = b.toSupabase();
      }

      // Verify Device 1 sees all 4 guest bookings
      expect(device1.clientBookings.length, equals(4));

      // 2. Spin up Device 2 for a secondary device login with user@test.com
      final device2User = const UserProfile(
        id: 'usr_user_secondary',
        role: UserRole.client,
        username: claimEmail,
        displayName: 'Registered User',
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        servicePackages: [],
      );

      final device2 = JobRepository();
      harness.bus.register(device2);
      await device2.loginUser(device2User);

      // Verify Device 2 reconciled all 4 claimed bookings from cloud via claim RPC and dual-key
      expect(device2.clientBookings.length, equals(4), reason: 'Device 2 should have reconciled 4 claimed bookings');

      // Verify all 4 status categories exist on Device 2 identically:
      final d2Upcoming = device2.clientBookings.where((b) =>
          b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();
      final d2InProgress = device2.clientBookings.where((b) =>
          b.status == BookingStatus.inProgress).toList();
      final d2Completed = device2.clientBookings.where((b) =>
          b.status == BookingStatus.completed).toList();
      final d2Cancelled = device2.clientBookings.where((b) =>
          b.status == BookingStatus.cancelled).toList();

      expect(d2Upcoming.map((b) => b.id), contains('bk_guest_cat_upcoming'));
      expect(d2InProgress.map((b) => b.id), contains('bk_guest_cat_inprogress'));
      expect(d2Completed.map((b) => b.id), contains('bk_guest_cat_completed'));
      expect(d2Cancelled.map((b) => b.id), contains('bk_guest_cat_cancelled'));

      // Verify dual-key matching on Device 2:
      for (final b in device2.clientBookings) {
        expect(b.clientEmail.toLowerCase(), equals(claimEmail));
        expect(b.clientId, equals('usr_user_secondary'));
      }

      // 3. Now log Device 1 into the same account
      await device1.loginUser(device2User);

      // 4. Verify 1:1 cross-device parity across all 4 categories between Device 1 and Device 2
      expect(device1.clientBookings.length, equals(device2.clientBookings.length));
      for (final d1b in device1.clientBookings) {
        final d2b = device2.clientBookings.firstWhere((b) => b.id == d1b.id);
        expect(d1b.status, equals(d2b.status));
        expect(d1b.scheduledDate, equals(d2b.scheduledDate));
        expect(d1b.vehicleYearMakeModel, equals(d2b.vehicleYearMakeModel));
        expect(d1b.clientId, equals(d2b.clientId));
      }
    });

    test('3. Offline-to-Online Transition with Deletions: Offline refreshes preserve local cache; cloud deletions & cancellations cleanly reconcile on reconnect without resurrection', () async {
      const userId = 'usr_offline_test';
      const userEmail = 'offline@test.com';

      final user = const UserProfile(
        id: userId,
        role: UserRole.client,
        username: userEmail,
        displayName: 'Offline Client',
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        servicePackages: [],
      );

      // Create Device 2 initially as a guest to register a pre-existing local guest booking
      final device2 = await harness.createDeviceSession(
        user: const UserProfile(
          id: 'usr_you',
          role: UserRole.client,
          username: 'guest',
          displayName: 'Guest Device',
          businessName: '',
          avatarUrl: '',
          coverUrl: '',
          servicePackages: [],
        ),
        isLoggedIn: false,
      );

      final localGuest = createTestBooking(
        id: 'bk_local_device_guest',
        clientId: null,
        clientEmail: 'localguest@test.com',
        detailerId: 'usr_you',
        status: BookingStatus.pending,
        scheduledDate: DateTime(2026, 12, 1),
      );
      device2.addBooking(localGuest, allowOverbooking: true, syncToCloud: false);

      // Populate cloud DB with 4 bookings for userId
      final bkDel = createTestBooking(
        id: 'bk_cloud_to_delete',
        clientId: userId,
        clientEmail: userEmail,
        status: BookingStatus.confirmed,
        scheduledDate: DateTime(2026, 11, 20),
      );
      final bkCancel = createTestBooking(
        id: 'bk_cloud_to_cancel',
        clientId: userId,
        clientEmail: userEmail,
        status: BookingStatus.inProgress,
        scheduledDate: DateTime(2026, 11, 22),
      );
      final bkKeep = createTestBooking(
        id: 'bk_cloud_to_keep',
        clientId: userId,
        clientEmail: userEmail,
        status: BookingStatus.confirmed,
        scheduledDate: DateTime(2026, 11, 25),
      );
      final bkComp = createTestBooking(
        id: 'bk_cloud_to_comp',
        clientId: userId,
        clientEmail: userEmail,
        status: BookingStatus.completed,
        scheduledDate: DateTime(2026, 11, 5),
      );

      _cloudBookingDb[bkDel.id] = bkDel.toSupabase();
      _cloudBookingDb[bkCancel.id] = bkCancel.toSupabase();
      _cloudBookingDb[bkKeep.id] = bkKeep.toSupabase();
      _cloudBookingDb[bkComp.id] = bkComp.toSupabase();

      // Device 2 logs in as userId
      await device2.loginUser(user);

      // Has 4 cloud bookings + 1 local guest booking = 5 bookings
      expect(device2.bookings.length, equals(5));

      // STEP A: Simulate Device 2 going OFFLINE
      _mockCloudProvider = (uri, method, body) {
        throw const SocketException('Network is unreachable (simulated offline)');
      };

      // Refreshing while offline must not crash and must NOT wipe out local cache
      await device2.refreshBookings();
      expect(device2.bookings.length, equals(5), reason: 'Local cache must survive offline refresh');
      expect(device2.bookings.any((b) => b.id == 'bk_cloud_to_delete'), isTrue);

      // STEP B: While Device 2 is offline, Detailer in cloud:
      // 1. Permanently deletes 'bk_cloud_to_delete'
      _cloudBookingDb.remove('bk_cloud_to_delete');
      // 2. Cancels 'bk_cloud_to_cancel'
      _cloudBookingDb['bk_cloud_to_cancel']!['status'] = 'cancelled';

      // STEP C: Reconnect Device 2 (network online)
      _mockCloudProvider = null; // restore normal network handling

      // Trigger cloud refresh
      await device2.refreshBookings();

      // STEP D: Verify Cloud Reconciliation
      // 1. Deleted booking must NOT resurrect!
      expect(
        device2.bookings.any((b) => b.id == 'bk_cloud_to_delete'),
        isFalse,
        reason: 'Deleted cloud booking was resurrected in local bookings',
      );
      expect(
        device2.clientBookings.any((b) => b.id == 'bk_cloud_to_delete'),
        isFalse,
        reason: 'Deleted cloud booking was resurrected in clientBookings',
      );

      // 2. Cancelled booking is cleanly updated to cancelled
      final reconciledCancel = device2.bookings.firstWhere((b) => b.id == 'bk_cloud_to_cancel');
      expect(reconciledCancel.status, equals(BookingStatus.cancelled));

      // 3. Untouched bookings are preserved
      expect(device2.bookings.any((b) => b.id == 'bk_cloud_to_keep'), isTrue);
      expect(device2.bookings.any((b) => b.id == 'bk_cloud_to_comp'), isTrue);

      // 4. Device-local guest booking is preserved
      expect(device2.bookings.any((b) => b.id == 'bk_local_device_guest'), isTrue);

      // 5. Total count is exactly 4
      expect(device2.bookings.length, equals(4));

      // 6. Local storage is updated without resurrecting deleted appointment
      final storedBookings = await LocalStorageService.loadBookings();
      expect(storedBookings?.any((b) => b.id == 'bk_cloud_to_delete') ?? false, isFalse);
    });

    testWidgets('4. Reactive Modal Concurrent Stress: Live Realtime cancellations, reschedules, and deletions while interacting with modal controls produce 0 crashes, 0 stale closures, and immediate UI reactivity', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final clientRepo = await harness.createClientDeviceSession(
          deviceId: 'dev_modal_stress',
          userId: 'usr_modal_client',
          email: 'modal.client@example.com',
          displayName: 'Jordan Lee',
        );

        final initialBooking = createTestBooking(
          id: 'bk_stress_modal_01',
          clientId: 'usr_modal_client',
          clientEmail: 'modal.client@example.com',
          status: BookingStatus.confirmed,
          scheduledDate: DateTime(2026, 11, 18),
          scheduledTimeSlot: '10:00 AM - 1:00 PM',
          vehicleName: '2024 BMW M3 Competition',
        );
        clientRepo.addBooking(initialBooking, syncToCloud: false);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: clientRepo),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open Booking Details Modal
        expect(find.text('2024 BMW M3 Competition'), findsOneWidget);
        await tester.tap(find.text('2024 BMW M3 Competition'));
        await tester.pumpAndSettle();

        // Verify initial state inside modal
        expect(find.text('Appointment Details'), findsOneWidget);
        expect(find.text('10:00 AM - 1:00 PM'), findsWidgets);
        expect(find.text('Cancel Reservation'), findsOneWidget);
        expect(find.text('Reschedule'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsNothing);

        // 2. CONCURRENT EVENT A: Live Realtime Reschedule broadcast arrives
        clientRepo.simulateRealtimeBookingPayload({
          'id': 'bk_stress_modal_01',
          'scheduled_time_slot': '2:30 PM - 5:30 PM',
          'scheduled_date': '2026-11-25',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump(); // trigger ListenableBuilder rebuild

        // Modal immediately reflects new scheduled time slot
        expect(find.text('2:30 PM - 5:30 PM'), findsWidgets);

        // 3. CONCURRENT EVENT B: Live Realtime Status progression to In-Progress
        clientRepo.simulateRealtimeBookingPayload({
          'id': 'bk_stress_modal_01',
          'status': 'in_progress',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump();

        expect(find.text('In Progress'), findsOneWidget);

        // 4. CONCURRENT EVENT C: Live Realtime Cancellation by Detailer
        clientRepo.simulateRealtimeBookingPayload({
          'id': 'bk_stress_modal_01',
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await tester.pump();

        // Modal immediately reflects cancellation
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('Status: Cancelled • Slot Released'), findsOneWidget);
        expect(find.text('This appointment was cancelled by the detailing studio. Your slot has been released.'), findsOneWidget);
        expect(find.text('Book Another Detailer'), findsOneWidget);
        expect(find.text('Cancel Reservation'), findsNothing);

        // 5. CONCURRENT EVENT D: User interacts with modal controls while in cancelled state
        expect(find.text('Call Studio'), findsOneWidget);
        await tester.tap(find.text('Call Studio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Directions / Map'), findsOneWidget);
        await tester.tap(find.text('Directions / Map'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 6. CONCURRENT EVENT E: Tap 'Book Another Detailer' button
        // Modal closes cleanly and navigates to explore/search (activeTabIndex = 0)
        expect(find.text('Book Another Detailer'), findsOneWidget);
        await tester.tap(find.text('Book Another Detailer'));
        await tester.pumpAndSettle();

        // Modal is dismissed
        expect(find.text('Appointment Details'), findsNothing);
        expect(clientRepo.activeTabIndex, equals(0));

        // 7. CONCURRENT EVENT F: Open a new modal and test incoming Realtime Deletion payload while open
        // Verifies orElse fallback prevents StateError: No element crash
        final secondBooking = createTestBooking(
          id: 'bk_stress_modal_02',
          clientId: 'usr_modal_client',
          clientEmail: 'modal.client@example.com',
          status: BookingStatus.confirmed,
          scheduledDate: DateTime(2026, 11, 28),
          vehicleName: '2024 Porsche 718 GT4',
        );
        clientRepo.addBooking(secondBooking, syncToCloud: false);
        await tester.pumpAndSettle();

        expect(find.text('2024 Porsche 718 GT4'), findsOneWidget);
        await tester.tap(find.text('2024 Porsche 718 GT4'));
        await tester.pumpAndSettle();

        expect(find.text('Appointment Details'), findsOneWidget);

        // Incoming Realtime Deletion payload arrives while modal is open
        clientRepo.simulateRealtimeBookingPayload({
          'id': 'bk_stress_modal_02',
        }, isDelete: true);
        await tester.pump();

        // Zero crash! Modal safely falls back to initialBooking via orElse
        expect(find.text('Appointment Details'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    test('5. Multi-User Session Switching & Cache Clearing Stress: Logging out clears private client bookings and logging in as new user isolates data completely', () async {
      // 1. Session A logs in
      final sessionA = await harness.createClientDeviceSession(
        deviceId: 'dev_multi_session',
        userId: 'usr_account_a',
        email: 'alice@example.com',
        displayName: 'Alice A',
      );

      final bookingA = createTestBooking(
        id: 'bk_alice_01',
        clientId: 'usr_account_a',
        clientEmail: 'alice@example.com',
        status: BookingStatus.confirmed,
        scheduledDate: DateTime(2026, 11, 15, 9, 0),
        scheduledTimeSlot: '9:00 AM - 1:00 PM',
      );
      sessionA.addBooking(bookingA, syncToCloud: false);
      expect(sessionA.clientBookings.length, equals(1));

      // 2. User A logs out
      await sessionA.logoutUser();
      expect(sessionA.isLoggedIn, isFalse);
      expect(sessionA.clientBookings, isEmpty, reason: 'Guest mode after logout must not reveal User A private bookings');

      // 3. User B logs into the same device
      final userB = const UserProfile(
        id: 'usr_account_b',
        role: UserRole.client,
        username: 'bob@example.com',
        displayName: 'Bob B',
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        servicePackages: [],
      );
      await sessionA.updateCurrentUser(userB);
      sessionA.isLoggedIn = true;

      // Verify User B does not see User A's booking
      expect(sessionA.clientBookings, isEmpty, reason: 'User B must not see User A bookings');

      // User B adds a booking on a different date and time slot
      final bookingB = createTestBooking(
        id: 'bk_bob_01',
        clientId: 'usr_account_b',
        clientEmail: 'bob@example.com',
        status: BookingStatus.confirmed,
        scheduledDate: DateTime(2026, 11, 16, 10, 0),
        scheduledTimeSlot: '10:00 AM - 2:00 PM',
      );
      sessionA.addBooking(bookingB, syncToCloud: false);
      expect(sessionA.clientBookings.length, equals(1));
      expect(sessionA.clientBookings.first.id, equals('bk_bob_01'));

      // 4. User B logs out, User A logs back in
      await sessionA.logoutUser();
      final userA = const UserProfile(
        id: 'usr_account_a',
        role: UserRole.client,
        username: 'alice@example.com',
        displayName: 'Alice A',
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        servicePackages: [],
      );
      await sessionA.updateCurrentUser(userA);
      sessionA.isLoggedIn = true;

      // Verify User A sees ONLY User A's booking and NOT User B's booking
      expect(sessionA.clientBookings.length, equals(1));
      expect(sessionA.clientBookings.first.id, equals('bk_alice_01'));
    });
  });
}
