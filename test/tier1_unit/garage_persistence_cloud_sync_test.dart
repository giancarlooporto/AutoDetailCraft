import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import 'package:detail_craft/services/supabase_db_service.dart';
import 'package:detail_craft/services/supabase_auth_service.dart';
import '../core/test_harness.dart';

typedef CloudProvider = Map<String, dynamic> Function(Uri uri, String method, String requestBody);
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

  group('Garage Persistence & Supabase Cloud Sync Tests', () {
    test('1. Migration SQL and schema.sql define vehicle_type, body_type, auto profile trigger, and RLS', () {
      final migrationFile = File('supabase/migrations/20261030_garage_vehicle_type_and_persistence.sql');
      expect(migrationFile.existsSync(), isTrue);
      final migrationSql = migrationFile.readAsStringSync();
      expect(migrationSql.contains('vehicle_type text DEFAULT \'Sedan\''), isTrue);
      expect(migrationSql.contains('body_type text DEFAULT \'Sedan\''), isTrue);
      expect(migrationSql.contains('handle_new_user()'), isTrue);
      expect(migrationSql.contains('on_auth_user_created'), isTrue);
      expect(migrationSql.contains('Allow read on vehicles'), isTrue);

      final schemaFile = File('supabase/schema.sql');
      expect(schemaFile.existsSync(), isTrue);
      final schemaSql = schemaFile.readAsStringSync();
      expect(schemaSql.contains('vehicle_type text default \'Sedan\''), isTrue);
      expect(schemaSql.contains('body_type text default \'Sedan\''), isTrue);
      expect(schemaSql.contains('handle_new_user()'), isTrue);
      expect(schemaSql.contains('on_auth_user_created'), isTrue);
    });

    test('2. SupabaseDbService.saveVehicle handles PGRST204 schema mismatch with fallback retry stripped of vehicle_type/body_type', () async {
      int requestCount = 0;
      final capturedPayloads = <dynamic>[];

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('profiles')) {
          return {'statusCode': 200, 'body': {'id': 'usr_fallback_test'}};
        }
        if (uri.path.contains('vehicles')) {
          requestCount++;
          if (requestBody.isNotEmpty) {
            try {
              capturedPayloads.add(jsonDecode(requestBody));
            } catch (_) {}
          }
          if (requestCount == 1) {
            // First attempt throws PGRST204 column missing error
            return {
              'statusCode': 400,
              'body': {
                'code': 'PGRST204',
                'message': 'Could not find the vehicle_type column of vehicles in the schema cache',
              },
            };
          }
          // Second attempt (fallback) succeeds
          return {'statusCode': 201, 'body': {'id': 'veh_fallback_1'}};
        }
        return {'statusCode': 200, 'body': []};
      };

      const vehicle = UserVehicle(
        id: 'veh_fallback_1',
        year: 2024,
        make: 'Porsche',
        model: '911 GT3 RS',
        colorName: 'Lizard Green',
        imageUrl: '',
        vehicleType: 'Coupe',
        paintCode: 'M6B',
        lastDetailService: 'Ceramic Coating',
      );

      await SupabaseDbService.saveVehicle('usr_fallback_test', vehicle);

      expect(requestCount, 2, reason: 'Should retry fallback upsert upon PGRST204');
      expect(capturedPayloads.length, 2);

      // Verify the fallback payload stripped out extended fields so unmigrated schemas succeed
      final fallbackPayload = capturedPayloads[1];
      final Map<String, dynamic> fallbackMap = fallbackPayload is List
          ? Map<String, dynamic>.from(fallbackPayload.first as Map)
          : Map<String, dynamic>.from(fallbackPayload as Map);

      expect(fallbackMap.containsKey('vehicle_type'), isFalse);
      expect(fallbackMap.containsKey('body_type'), isFalse);
      expect(fallbackMap.containsKey('paint_code'), isFalse);
      expect(fallbackMap.containsKey('last_detail_service'), isFalse);
      // Core fields remain intact
      expect(fallbackMap['id'], 'veh_fallback_1');
      expect(fallbackMap['make'], 'Porsche');
      expect(fallbackMap['model'], '911 GT3 RS');
      expect(fallbackMap['year'], 2024);
    });

    test('3. SupabaseDbService.saveVehicle verifies profiles row exists before inserting vehicle to prevent FK 23503 error', () async {
      bool profileChecked = false;
      bool profileCreated = false;
      bool vehicleUpserted = false;

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            profileChecked = true;
            // Profile does NOT exist yet
            return {'statusCode': 200, 'body': null};
          } else if (method == 'POST') {
            profileCreated = true;
            return {'statusCode': 201, 'body': {'id': 'usr_fk_test'}};
          }
        }
        if (uri.path.contains('vehicles')) {
          vehicleUpserted = true;
          return {'statusCode': 201, 'body': {'id': 'veh_fk_1'}};
        }
        return {'statusCode': 200, 'body': []};
      };

      const vehicle = UserVehicle(
        id: 'veh_fk_1',
        year: 2023,
        make: 'BMW',
        model: 'M4 Competition',
        colorName: 'Isle of Man Green',
        imageUrl: '',
      );

      await SupabaseDbService.saveVehicle('usr_fk_test', vehicle);

      expect(profileChecked, isTrue);
      expect(profileCreated, isTrue);
      expect(vehicleUpserted, isTrue);
    });

    test('4. JobRepository.loginUser claims guest vehicles from local storage and uploads them under auth user ID', () async {
      SharedPreferences.setMockInitialValues({});
      const guestVehicle = UserVehicle(
        id: 'veh_guest_claim_1',
        year: 2025,
        make: 'Ferrari',
        model: '296 GTB',
        colorName: 'Rosso Corsa',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      final repo = await TestHarness.createSession(isLoggedIn: false);
      repo.addVehicleToGarage(guestVehicle);
      expect(repo.currentUser.myGarage.length, 1);

      final uploadedVehicles = <Map<String, dynamic>>[];
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            return {
              'statusCode': 200,
              'body': {
                'id': 'usr_claimed_123',
                'email': 'client@autodetail.com',
                'role': 'client',
                'service_packages': [],
              },
            };
          }
          return {'statusCode': 200, 'body': {'id': 'usr_claimed_123'}};
        }
        if (uri.path.contains('vehicles')) {
          if (method == 'POST') {
            if (requestBody.isNotEmpty) {
              try {
                final decoded = jsonDecode(requestBody);
                if (decoded is List) {
                  uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
                } else if (decoded is Map) {
                  uploadedVehicles.add(Map<String, dynamic>.from(decoded));
                }
              } catch (_) {}
            }
            return {'statusCode': 201, 'body': {'id': 'veh_guest_claim_1'}};
          }
          return {'statusCode': 200, 'body': []};
        }
        return {'statusCode': 200, 'body': []};
      };

      final authUser = UserProfile(
        id: 'usr_claimed_123',
        role: UserRole.client,
        username: 'client',
        displayName: 'Registered Client',
        myGarage: const [], // Cloud profile returned empty garage initially
      );

      await repo.loginUser(authUser);

      // Vehicle was uploaded to Supabase under the authenticated user's ID
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_guest_claim_1' && v['user_id'] == 'usr_claimed_123'), isTrue);

      // Local storage and repo state preserve the claimed garage vehicle
      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_guest_claim_1');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_guest_claim_1');
    });

    test('5. SupabaseAuthService.signUp preserves guest garage vehicles and uploads to cloud', () async {
      SharedPreferences.setMockInitialValues({});
      const guestVehicle = UserVehicle(
        id: 'veh_signup_1',
        year: 2024,
        make: 'Mercedes-AMG',
        model: 'GT Black Series',
        colorName: 'Magno Grey',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      await LocalStorageService.saveGarageVehicles([guestVehicle]);

      final uploadedVehicles = <Map<String, dynamic>>[];
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('signup')) {
          return {
            'statusCode': 200,
            'body': {
              'id': 'usr_signup_new',
              'email': 'newuser@example.com',
              'user_metadata': {'display_name': 'New User'},
            },
          };
        }
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            return {'statusCode': 200, 'body': null};
          }
          return {'statusCode': 200, 'body': {'id': 'usr_signup_new'}};
        }
        if (uri.path.contains('vehicles')) {
          if (method == 'POST' && requestBody.isNotEmpty) {
            try {
              final decoded = jsonDecode(requestBody);
              if (decoded is List) {
                uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
              } else if (decoded is Map) {
                uploadedVehicles.add(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
          return {'statusCode': 201, 'body': {'id': 'veh_signup_1'}};
        }
        return {'statusCode': 200, 'body': []};
      };

      final result = await SupabaseAuthService.signUp(
        email: 'newuser@example.com',
        password: 'password123',
        displayName: 'New User',
      );

      expect(result.success, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile!.myGarage.length, 1);
      expect(result.profile!.myGarage.first.id, 'veh_signup_1');

      // Verify guest vehicle was uploaded to Supabase under the new user ID
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_signup_1' && v['user_id'] == 'usr_signup_new'), isTrue);

      // Verify local storage is preserved
      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_signup_1');
    });

    test('6. SupabaseAuthService.signIn preserves guest vehicles, merges with cloud, and uploads missing to cloud', () async {
      SharedPreferences.setMockInitialValues({});
      const guestVehicle = UserVehicle(
        id: 'veh_guest_sign_in_1',
        year: 2023,
        make: 'Rivian',
        model: 'R1T',
        colorName: 'Rivian Blue',
        vehicleType: 'Truck',
        imageUrl: '',
      );
      await LocalStorageService.saveGarageVehicles([guestVehicle]);

      final uploadedVehicles = <Map<String, dynamic>>[];
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('token')) {
          return {
            'statusCode': 200,
            'body': {
              'access_token': 'fake_token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'fake_refresh',
              'user': {
                'id': 'usr_signin_user',
                'email': 'existing@example.com',
                'user_metadata': {'display_name': 'Existing User'},
              },
            },
          };
        }
        if (uri.path.contains('profiles')) {
          return {
            'statusCode': 200,
            'body': {
              'id': 'usr_signin_user',
              'email': 'existing@example.com',
              'role': 'client',
            },
          };
        }
        if (uri.path.contains('vehicles')) {
          if (method == 'GET') {
            // Cloud has 1 vehicle already
            return {
              'statusCode': 200,
              'body': [
                {
                  'id': 'veh_cloud_existing',
                  'user_id': 'usr_signin_user',
                  'year': 2022,
                  'make': 'Tesla',
                  'model': 'Model S Plaid',
                  'paint_color': 'Midnight Silver',
                  'vehicle_type': 'Sedan',
                }
              ],
            };
          }
          if (method == 'POST') {
            if (requestBody.isNotEmpty) {
              try {
                final decoded = jsonDecode(requestBody);
                if (decoded is List) {
                  uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
                } else if (decoded is Map) {
                  uploadedVehicles.add(Map<String, dynamic>.from(decoded));
                }
              } catch (_) {}
            }
            return {'statusCode': 201, 'body': {'id': 'veh_guest_sign_in_1'}};
          }
        }
        return {'statusCode': 200, 'body': []};
      };

      final result = await SupabaseAuthService.signIn(
        email: 'existing@example.com',
        password: 'password123',
      );

      expect(result.success, isTrue);
      expect(result.profile, isNotNull);

      // Reconciled list contains BOTH cloud vehicle and guest vehicle
      expect(result.profile!.myGarage.length, 2);
      expect(result.profile!.myGarage.any((v) => v.id == 'veh_cloud_existing'), isTrue);
      expect(result.profile!.myGarage.any((v) => v.id == 'veh_guest_sign_in_1'), isTrue);

      // Guest vehicle was pushed to Supabase for the authenticated user
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_guest_sign_in_1' && v['user_id'] == 'usr_signin_user'), isTrue);

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 2);
    });

    test('7. Window refresh persistence: refreshGarage preserves created vehicles from Supabase without wiping', () async {
      final user = MockDataService.youUser.copyWith(
        id: 'usr_refresh_test',
        myGarage: [
          const UserVehicle(
            id: 'veh_persisted_1',
            year: 2024,
            make: 'Porsche',
            model: '911 Carrera',
            colorName: 'Chalk',
            vehicleType: 'Coupe',
            imageUrl: '',
          ),
        ],
      );

      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: user,
      );

      // Supabase returns the persisted vehicle on refresh
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('vehicles')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': 'veh_persisted_1',
                'user_id': 'usr_refresh_test',
                'year': 2024,
                'make': 'Porsche',
                'model': '911 Carrera',
                'paint_color': 'Chalk',
                'vehicle_type': 'Coupe',
                'image_url': '',
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      // Simulate refreshGarage called on window / private tab refresh
      await repo.refreshGarage();

      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_persisted_1');
      expect(repo.currentUser.myGarage.first.vehicleType, 'Coupe');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_persisted_1');
    });

    test('8. _refreshProfileFromCloud pushes locally added vehicles missing from cloud up to Supabase', () async {
      SharedPreferences.setMockInitialValues({});
      const localVehicle = UserVehicle(
        id: 'veh_local_unpushed',
        year: 2024,
        make: 'Lamborghini',
        model: 'Revuelto',
        colorName: 'Arancio Apodis',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: MockDataService.youUser.copyWith(
          id: 'usr_cloud_sync_test',
          myGarage: [localVehicle],
        ),
      );

      final uploadedVehicles = <Map<String, dynamic>>[];
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            return {
              'statusCode': 200,
              'body': {
                'id': 'usr_cloud_sync_test',
                'email': 'sync@example.com',
                'role': 'client',
                'service_packages': [],
              },
            };
          }
          return {'statusCode': 200, 'body': {'id': 'usr_cloud_sync_test'}};
        }
        if (uri.path.contains('vehicles')) {
          if (method == 'GET') {
            // Cloud has 0 vehicles
            return {'statusCode': 200, 'body': []};
          }
          if (method == 'POST' && requestBody.isNotEmpty) {
            try {
              final decoded = jsonDecode(requestBody);
              if (decoded is List) {
                uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
              } else if (decoded is Map) {
                uploadedVehicles.add(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
            return {'statusCode': 201, 'body': {'id': 'veh_local_unpushed'}};
          }
        }
        return {'statusCode': 200, 'body': []};
      };

      // Call loginUser which triggers _refreshProfileFromCloud
      await repo.loginUser(repo.currentUser);

      // Verify that local vehicle missing from cloud was pushed up to Supabase
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_local_unpushed' && v['user_id'] == 'usr_cloud_sync_test'), isTrue);
      expect(repo.currentUser.myGarage.any((v) => v.id == 'veh_local_unpushed'), isTrue);
    });

    test('9. Window refresh resilience: refreshGarage does NOT wipe local vehicles when Supabase returns [] and pushes them to cloud', () async {
      SharedPreferences.setMockInitialValues({});
      const localVehicle = UserVehicle(
        id: 'veh_protected_on_refresh',
        year: 2023,
        make: 'BMW',
        model: 'M4 Competition',
        colorName: 'Isle of Man Green',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      final user = MockDataService.youUser.copyWith(
        id: 'usr_refresh_protect_test',
        myGarage: [localVehicle],
      );

      final repo = await TestHarness.createSession(
        isLoggedIn: true,
        currentUser: user,
      );

      final uploadedVehicles = <Map<String, dynamic>>[];
      // Cloud returns empty list [] (e.g. before cloud replication or temporary query delay)
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('vehicles')) {
          if (method == 'GET') {
            return {'statusCode': 200, 'body': []};
          }
          if (method == 'POST' && requestBody.isNotEmpty) {
            try {
              final decoded = jsonDecode(requestBody);
              if (decoded is List) {
                uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
              } else if (decoded is Map) {
                uploadedVehicles.add(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
            return {'statusCode': 201, 'body': {'id': 'veh_protected_on_refresh'}};
          }
        }
        return {'statusCode': 200, 'body': []};
      };

      // Call refreshGarage (which happens in ProfileScreen.initState)
      await repo.refreshGarage();

      // Crucial assertion: vehicle was NOT wiped from in-memory state or local storage!
      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.id, 'veh_protected_on_refresh');

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 1);
      expect(stored.first.id, 'veh_protected_on_refresh');

      // Crucial assertion: missing vehicle was pushed up to Supabase
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_protected_on_refresh' && v['user_id'] == 'usr_refresh_protect_test'), isTrue);
    });

    test('10. SupabaseAuthService.signInWithEmail preserves guest vehicles and uploads to cloud', () async {
      SharedPreferences.setMockInitialValues({});
      const guestVehicle = UserVehicle(
        id: 'veh_guest_sign_in_email',
        year: 2021,
        make: 'Toyota',
        model: 'GR Supra',
        colorName: 'Nitro Yellow',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      // Pre-seed local storage with guest vehicle
      await LocalStorageService.saveGarageVehicles([guestVehicle]);

      final uploadedVehicles = <Map<String, dynamic>>[];
      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('token')) {
          return {
            'statusCode': 200,
            'body': {
              'access_token': 'fake_access_token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'fake_refresh_token',
              'user': {
                'id': 'usr_signin_email_user',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'email_signin@example.com',
                'created_at': DateTime.now().toIso8601String(),
              },
            },
          };
        }
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            return {
              'statusCode': 200,
              'body': {
                'id': 'usr_signin_email_user',
                'email': 'email_signin@example.com',
                'role': 'client',
                'display_name': 'Sign In Email User',
                'service_packages': [],
              },
            };
          }
          return {'statusCode': 200, 'body': {'id': 'usr_signin_email_user'}};
        }
        if (uri.path.contains('vehicles')) {
          if (method == 'GET') {
            return {
              'statusCode': 200,
              'body': [
                {
                  'id': 'veh_cloud_existing_email',
                  'user_id': 'usr_signin_email_user',
                  'year': 2020,
                  'make': 'Tesla',
                  'model': 'Model 3',
                  'paint_color': 'Pearl White',
                  'vehicle_type': 'Sedan',
                  'image_url': '',
                }
              ],
            };
          }
          if (method == 'POST' && requestBody.isNotEmpty) {
            try {
              final decoded = jsonDecode(requestBody);
              if (decoded is List) {
                uploadedVehicles.addAll(decoded.cast<Map<String, dynamic>>());
              } else if (decoded is Map) {
                uploadedVehicles.add(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
            return {'statusCode': 201, 'body': {'id': 'veh_guest_sign_in_email'}};
          }
        }
        return {'statusCode': 200, 'body': []};
      };

      final result = await SupabaseAuthService.signInWithEmail(
        email: 'email_signin@example.com',
        password: 'Password123!',
      );

      expect(result.success, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile!.myGarage.length, 2);
      expect(result.profile!.myGarage.any((v) => v.id == 'veh_cloud_existing_email'), isTrue);
      expect(result.profile!.myGarage.any((v) => v.id == 'veh_guest_sign_in_email'), isTrue);

      // Guest vehicle was pushed to Supabase for the authenticated user
      expect(uploadedVehicles.any((v) => v['id'] == 'veh_guest_sign_in_email' && v['user_id'] == 'usr_signin_email_user'), isTrue);

      final stored = await LocalStorageService.loadGarageVehicles();
      expect(stored.length, 2);
    });

    test('11. SupabaseDbService.saveVehicle recovers from PostgREST FK 23503 error by seeding profile and retrying', () async {
      int vehicleAttempts = 0;
      bool profileSeeded = false;

      _mockCloudProvider = (uri, method, requestBody) {
        if (uri.path.contains('profiles')) {
          if (method == 'GET') {
            return {'statusCode': 200, 'body': {'id': 'usr_fk_test'}};
          }
          if (method == 'POST') {
            profileSeeded = true;
            return {'statusCode': 201, 'body': {'id': 'usr_fk_test'}};
          }
        }
        if (uri.path.contains('vehicles')) {
          vehicleAttempts++;
          if (vehicleAttempts == 1) {
            // First attempt fails with FK 23503
            return {
              'statusCode': 409,
              'body': {
                'code': '23503',
                'message': 'insert or update on table "vehicles" violates foreign key constraint "vehicles_user_id_fkey"',
              },
            };
          }
          // Second attempt succeeds after seeding profile
          return {'statusCode': 201, 'body': {'id': 'veh_fk_test_1'}};
        }
        return {'statusCode': 200, 'body': []};
      };

      const vehicle = UserVehicle(
        id: 'veh_fk_test_1',
        year: 2024,
        make: 'Ferrari',
        model: '296 GTB',
        colorName: 'Rosso Corsa',
        vehicleType: 'Coupe',
        imageUrl: '',
      );

      await SupabaseDbService.saveVehicle('usr_fk_test', vehicle);

      expect(vehicleAttempts, 2, reason: 'saveVehicle should retry after FK 23503');
      expect(profileSeeded, isTrue, reason: 'saveVehicle should seed profile before retrying');
    });
  });
}
