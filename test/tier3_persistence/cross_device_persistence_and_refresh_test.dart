import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
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
  });
}
