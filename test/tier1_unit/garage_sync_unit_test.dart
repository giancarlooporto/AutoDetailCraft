import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import 'package:detail_craft/services/supabase_db_service.dart';
import '../core/test_harness.dart';

typedef CloudProvider = Map<String, dynamic> Function(Uri uri, String method);
CloudProvider? _mockCloudProvider;

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _TestHttpRequest(method, url);
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

class _TestHttpRequest extends Fake implements HttpClientRequest {
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

  _TestHttpRequest(this.method, this.uri);

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
    if (_mockCloudProvider != null) {
      final res = _mockCloudProvider!(uri, method);
      final body = res['body'];
      final statusCode = res['statusCode'] as int? ?? 200;
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      return _TestHttpResponse(statusCode, Uint8List.fromList(jsonBytes));
    }
    return _TestHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _TestHttpOverrides();
    await SupabaseService.initialize();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    _mockCloudProvider = null;
  });

  tearDown(() {
    _mockCloudProvider = null;
  });

  group('Garage Serialization & Schema Compatibility Tests', () {
    test('UserVehicle.fromJson correctly parses standard camelCase keys', () {
      final json = {
        'id': 'veh_camel_01',
        'year': 2024,
        'make': 'Porsche',
        'model': '911 GT3 RS',
        'colorName': 'Shark Blue',
        'paintCode': 'D5C',
        'imageUrl': 'https://example.com/gt3.jpg',
        'localImageBytes': base64Encode([0x01, 0x02, 0x03]),
        'lastDetailService': 'Full Ceramic Coating',
        'lastDetailDate': '2026-06-15T10:00:00.000Z',
      };

      final vehicle = UserVehicle.fromJson(json);

      expect(vehicle.id, 'veh_camel_01');
      expect(vehicle.year, 2024);
      expect(vehicle.make, 'Porsche');
      expect(vehicle.model, '911 GT3 RS');
      expect(vehicle.colorName, 'Shark Blue');
      expect(vehicle.paintCode, 'D5C');
      expect(vehicle.imageUrl, 'https://example.com/gt3.jpg');
      expect(vehicle.localImageBytes, equals([0x01, 0x02, 0x03]));
      expect(vehicle.lastDetailService, 'Full Ceramic Coating');
      expect(vehicle.lastDetailDate, equals(DateTime.parse('2026-06-15T10:00:00.000Z')));
    });

    test('UserVehicle.fromJson correctly parses Supabase snake_case database & realtime payloads', () {
      final json = {
        'id': 'veh_snake_02',
        'year': 2025,
        'make': 'Ferrari',
        'model': '296 GTB',
        'paint_color': 'Rosso Corsa',
        'paint_code': 'FER322',
        'image_url': 'https://example.com/296.jpg',
        'local_image_bytes': [0x04, 0x05, 0x06],
        'last_detail_service': 'Stage 2 Paint Correction',
        'last_detail_date': '2026-07-20T14:30:00.000Z',
      };

      final vehicle = UserVehicle.fromJson(json);

      expect(vehicle.id, 'veh_snake_02');
      expect(vehicle.year, 2025);
      expect(vehicle.make, 'Ferrari');
      expect(vehicle.model, '296 GTB');
      expect(vehicle.colorName, 'Rosso Corsa');
      expect(vehicle.paintCode, 'FER322');
      expect(vehicle.imageUrl, 'https://example.com/296.jpg');
      expect(vehicle.localImageBytes, equals([0x04, 0x05, 0x06]));
      expect(vehicle.lastDetailService, 'Stage 2 Paint Correction');
      expect(vehicle.lastDetailDate, equals(DateTime.parse('2026-07-20T14:30:00.000Z')));
    });

    test('UserVehicle.fromJson handles string years, alternate keys, num types, and epoch DateTime gracefully', () {
      final json = {
        'id': 'veh_alt_03',
        'year': '2023',
        'make': 'BMW',
        'model': 'M4 CSL',
        'color_name': 'Frozen Brooklyn Grey',
        'paint_code': 'C4P',
        'imageUrl': 'https://example.com/m4.jpg',
        'localImageBytes': Uint8List.fromList([0x07, 0x08]),
        'last_detail_service': 'Annual Inspection',
        'last_detail_date': 1718445600000,
      };

      final vehicle = UserVehicle.fromJson(json);

      expect(vehicle.id, 'veh_alt_03');
      expect(vehicle.year, 2023);
      expect(vehicle.make, 'BMW');
      expect(vehicle.model, 'M4 CSL');
      expect(vehicle.colorName, 'Frozen Brooklyn Grey');
      expect(vehicle.paintCode, 'C4P');
      expect(vehicle.imageUrl, 'https://example.com/m4.jpg');
      expect(vehicle.localImageBytes, equals([0x07, 0x08]));
      expect(vehicle.lastDetailService, 'Annual Inspection');
      expect(vehicle.lastDetailDate, equals(DateTime.fromMillisecondsSinceEpoch(1718445600000)));
    });

    test('UserVehicle.fromJson defaults safely for invalid year strings and empty IDs', () {
      final json = {
        'id': '',
        'year': 'not-a-number',
        'make': 'Tesla',
        'model': 'Model 3',
      };

      final vehicle = UserVehicle.fromJson(json);
      expect(vehicle.id.startsWith('veh_'), isTrue);
      expect(vehicle.year, 2024);
      expect(vehicle.make, 'Tesla');
      expect(vehicle.model, 'Model 3');
    });
  });

  group('SupabaseDbService Garage Guards & Defensive Tests', () {
    test('fetchVehicles returns empty list without network call for usr_you or empty userId', () async {
      expect(await SupabaseDbService.fetchVehicles('usr_you'), isEmpty);
      expect(await SupabaseDbService.fetchVehicles(''), isEmpty);
    });

    test('saveVehicle and deleteVehicle safely return without throwing for usr_you or empty', () async {
      const veh = UserVehicle(
        id: 'veh_guard_01',
        year: 2024,
        make: 'Audi',
        model: 'RS6',
        colorName: 'Nardo Grey',
        imageUrl: '',
      );

      // Must not throw UUID parse or uninitialized client errors
      await SupabaseDbService.saveVehicle('usr_you', veh);
      await SupabaseDbService.saveVehicle('', veh);
      await SupabaseDbService.saveVehicle('valid-id', const UserVehicle(id: '', year: 2024, make: '', model: '', colorName: '', imageUrl: ''));
      await SupabaseDbService.deleteVehicle('');
    });
  });

  group('JobRepository Multi-Device Garage Sync & Authoritative Reconciliation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _mockCloudProvider = null;
    });

    test('addVehicleToGarage persists locally and updates currentUser.myGarage', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);
      expect(repo.currentUser.myGarage, isEmpty);

      const v1 = UserVehicle(
        id: 'veh_local_01',
        year: 2024,
        make: 'Porsche',
        model: 'Taycan Turbo S',
        colorName: 'Carrara White',
        paintCode: '2Y',
        imageUrl: '',
      );

      repo.addVehicleToGarage(v1);

      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_local_01');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_local_01');
      expect(stored.first.make, 'Porsche');
      expect(stored.first.paintCode, '2Y');
    });

    test('updateVehicleInGarage updates in-memory and dedicated storage', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);
      const v1 = UserVehicle(
        id: 'veh_update_01',
        year: 2023,
        make: 'Tesla',
        model: 'Model S Plaid',
        colorName: 'Solid Black',
        imageUrl: '',
      );
      repo.addVehicleToGarage(v1);

      final updated = v1.copyWith(
        colorName: 'Ultra Red',
        paintCode: 'PR01',
        lastDetailService: 'Ceramic Pro Gold Package',
      );
      repo.updateVehicleInGarage(updated);

      expect(repo.currentUser.myGarage.first.colorName, 'Ultra Red');
      expect(repo.currentUser.myGarage.first.paintCode, 'PR01');
      expect(repo.currentUser.myGarage.first.lastDetailService, 'Ceramic Pro Gold Package');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.first.colorName, 'Ultra Red');
      expect(stored.first.paintCode, 'PR01');
    });

    test('removeVehicleFromGarage removes vehicle from memory and storage', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);
      const v1 = UserVehicle(id: 'v_del_1', year: 2022, make: 'Ford', model: 'GT', colorName: 'Liquid Blue', imageUrl: '');
      const v2 = UserVehicle(id: 'v_del_2', year: 2024, make: 'Chevrolet', model: 'Corvette Z06', colorName: 'Torch Red', imageUrl: '');
      repo.addVehicleToGarage(v1);
      repo.addVehicleToGarage(v2);
      expect(repo.currentUser.myGarage.length, 2);

      repo.removeVehicleFromGarage('v_del_1');

      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'v_del_2');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'v_del_2');
    });

    test('logoutUser completely wipes local garage vehicle storage to prevent cross-account leaks', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);
      const v1 = UserVehicle(id: 'veh_secret_01', year: 2025, make: 'Ferrari', model: 'Daytona SP3', colorName: 'Rosso Magma', imageUrl: '');
      repo.addVehicleToGarage(v1);
      expect(repo.currentUser.myGarage.length, 1);

      var stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);

      // Log out
      await repo.logoutUser();

      expect(repo.currentUser.myGarage, isEmpty);
      stored = await LocalStorageService.loadGarageVehicles();
      expect(stored, isEmpty);
    });

    test('refreshGarage authoritatively removes deleted vehicle without resurrecting it', () async {
      final user = MockDataService.youUser.copyWith(
        id: 'usr_authoritative_test',
        myGarage: [
          const UserVehicle(id: 'veh_kept_1', year: 2024, make: 'Porsche', model: '911', colorName: 'Black', imageUrl: ''),
          const UserVehicle(id: 'veh_deleted_2', year: 2023, make: 'BMW', model: 'M3', colorName: 'Green', imageUrl: ''),
        ],
      );
      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: user,
      );
      expect(repo.currentUser.myGarage.length, 2);

      // Cloud returns only veh_kept_1 (veh_deleted_2 was deleted on another device)
      _mockCloudProvider = (uri, method) {
        if (uri.path.contains('vehicles')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'veh_kept_1',
                'user_id': 'usr_authoritative_test',
                'year': 2024,
                'make': 'Porsche',
                'model': '911',
                'paint_color': 'Black',
                'image_url': '',
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      await repo.refreshGarage();

      // Assert veh_deleted_2 was authoritatively removed and NOT resurrected
      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_kept_1');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_kept_1');
    });

    test('refreshGarage preserves localImageBytes when vehicle exists in cloud', () async {
      final photoBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      final initialVehicle = UserVehicle(
        id: 'veh_photo_1',
        year: 2024,
        make: 'McLaren',
        model: '750S',
        colorName: 'Papaya Orange',
        imageUrl: 'https://example.com/750s.jpg',
        localImageBytes: photoBytes,
      );

      final user = MockDataService.youUser.copyWith(
        id: 'usr_photo_test',
        myGarage: [initialVehicle],
      );
      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: user,
      );

      // Cloud returns vehicle without raw localImageBytes
      _mockCloudProvider = (uri, method) {
        if (uri.path.contains('vehicles')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'veh_photo_1',
                'user_id': 'usr_photo_test',
                'year': 2024,
                'make': 'McLaren',
                'model': '750S',
                'paint_color': 'Papaya Orange',
                'image_url': 'https://example.com/750s.jpg',
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      await repo.refreshGarage();

      expect(repo.currentUser.myGarage.first.localImageBytes, equals(photoBytes));
    });

    test('refreshGarage preserves local vehicles and does not wipe cache on network error', () async {
      final initialVehicles = [
        const UserVehicle(id: 'veh_safe_1', year: 2024, make: 'Audi', model: 'RS6', colorName: 'Nardo', imageUrl: ''),
      ];
      final user = MockDataService.youUser.copyWith(
        id: 'usr_offline_test',
        myGarage: initialVehicles,
      );
      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: user,
      );

      // Simulate network / server 500 error
      _mockCloudProvider = (uri, method) {
        return {'statusCode': 500, 'body': {'error': 'Internal server error'}};
      };

      await repo.refreshGarage();

      // Local vehicle MUST still be present!
      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_safe_1');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_safe_1');
    });
  });
}
