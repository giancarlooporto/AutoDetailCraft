// =========================================================================
// File: test/tier2_widgets/places_autocomplete_and_address_autofill_test.dart
// Description: Unit & Widget verification of Google Places API (New)
//              session-token autocomplete, Place Details parsing, Geocoding
//              fallback, EditProfileDialog auto-fill + coordinate persistence,
//              and BookingFlowScreen temporary location auto-fill + coordinates.
// =========================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/edit_profile_dialog.dart';
import 'package:detail_craft/services/places_autocomplete_service.dart';
import 'package:detail_craft/services/supabase_service.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacesAutocompleteService.resetMockProviders();
  });

  tearDown(() {
    PlacesAutocompleteService.resetMockProviders();
  });

  // =========================================================================
  // GROUP 1: PlacesAutocompleteService Unit Tests
  // =========================================================================
  group('1. PlacesAutocompleteService Unit Tests', () {
    test('1.1 SupabaseService.googleMapsApiKey is configured with Option A default', () {
      expect(SupabaseService.googleMapsApiKey, isNotEmpty);
      expect(SupabaseService.googleMapsApiKey, startsWith('AIzaSy'));
    });

    test('1.2 generateSessionToken generates valid RFC-4122 UUID v4 tokens', () {
      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final tokens = <String>{};
      for (int i = 0; i < 20; i++) {
        final token = PlacesAutocompleteService.generateSessionToken();
        expect(uuidV4Regex.hasMatch(token), isTrue, reason: 'Invalid UUID v4: $token');
        tokens.add(token);
      }
      expect(tokens.length, 20, reason: 'Session tokens must be unique');
    });

    test('1.3 Short queries (< 3 chars) or whitespace return empty list without making HTTP requests', () async {
      int httpCallCount = 0;
      PlacesAutocompleteService.setMockProviders(
        httpClient: MockClient((req) async {
          httpCallCount++;
          return http.Response('{}', 200);
        }),
      );

      final r1 = await PlacesAutocompleteService.fetchAutocompleteSuggestions('', sessionToken: 'tok-1');
      final r2 = await PlacesAutocompleteService.fetchAutocompleteSuggestions('  ', sessionToken: 'tok-1');
      final r3 = await PlacesAutocompleteService.fetchAutocompleteSuggestions('12', sessionToken: 'tok-1');

      expect(r1, isEmpty);
      expect(r2, isEmpty);
      expect(r3, isEmpty);
      expect(httpCallCount, 0);
    });

    test('1.4 Google Places API (New) autocomplete & place details JSON parsing', () async {
      Uri? capturedAutocompleteUri;
      Map<String, dynamic>? capturedAutocompleteBody;
      String? capturedApiKeyHeader;
      Uri? capturedDetailsUri;

      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('places:autocomplete')) {
          capturedAutocompleteUri = request.url;
          capturedApiKeyHeader = request.headers['X-Goog-Api-Key'];
          capturedAutocompleteBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'ChIJ_austin_congress_1200',
                    'text': {
                      'text': '1200 S Congress Ave, Austin, TX 78704, USA',
                    },
                    'structuredFormat': {
                      'mainText': {'text': '1200 S Congress Ave'},
                      'secondaryText': {'text': 'Austin, TX 78704, USA'},
                    },
                  },
                },
              ],
            }),
            200,
          );
        } else if (request.url.toString().contains('/v1/places/ChIJ_austin_congress_1200')) {
          capturedDetailsUri = request.url;
          return http.Response(
            jsonEncode({
              'id': 'ChIJ_austin_congress_1200',
              'formattedAddress': '1200 S Congress Ave, Austin, TX 78704, USA',
              'addressComponents': [
                {
                  'longText': '1200',
                  'shortText': '1200',
                  'types': ['street_number'],
                },
                {
                  'longText': 'South Congress Avenue',
                  'shortText': 'S Congress Ave',
                  'types': ['route'],
                },
                {
                  'longText': 'Suite 200',
                  'shortText': 'Ste 200',
                  'types': ['subpremise'],
                },
                {
                  'longText': 'Austin',
                  'shortText': 'Austin',
                  'types': ['locality', 'political'],
                },
                {
                  'longText': 'Texas',
                  'shortText': 'TX',
                  'types': ['administrative_area_level_1', 'political'],
                },
                {
                  'longText': '78704',
                  'shortText': '78704',
                  'types': ['postal_code'],
                },
              ],
              'location': {
                'latitude': 30.2512,
                'longitude': -97.7498,
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      PlacesAutocompleteService.setMockProviders(httpClient: mockClient);

      final sessionToken = PlacesAutocompleteService.generateSessionToken();
      final predictions = await PlacesAutocompleteService.fetchAutocompleteSuggestions(
        '1200 S Congress',
        sessionToken: sessionToken,
      );

      expect(capturedAutocompleteUri.toString(), 'https://places.googleapis.com/v1/places:autocomplete');
      expect(capturedApiKeyHeader, SupabaseService.googleMapsApiKey);
      expect(capturedAutocompleteBody?['input'], '1200 S Congress');
      expect(capturedAutocompleteBody?['sessionToken'], sessionToken);
      expect(predictions.length, 1);
      expect(predictions.first.placeId, 'ChIJ_austin_congress_1200');
      expect(predictions.first.mainText, '1200 S Congress Ave');
      expect(predictions.first.secondaryText, 'Austin, TX 78704, USA');

      final details = await PlacesAutocompleteService.fetchPlaceDetails(
        predictions.first.placeId,
        sessionToken: sessionToken,
      );

      expect(capturedDetailsUri.toString(), contains('sessionToken=$sessionToken'));
      expect(details, isNotNull);
      expect(details!.streetAddress, '1200 South Congress Avenue');
      expect(details.unitOrApt, 'Suite 200');
      expect(details.city, 'Austin');
      expect(details.state, 'TX');
      expect(details.postalCode, '78704');
      expect(details.latitude, closeTo(30.2512, 0.0001));
      expect(details.longitude, closeTo(-97.7498, 0.0001));
    });

    test('1.5 Automatic fallback to Geocoding API when Places API (New) returns non-200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'places.googleapis.com') {
          return http.Response('{"error": "Places API New not enabled"}', 403);
        }
        if (request.url.host == 'maps.googleapis.com' &&
            request.url.path.contains('/maps/api/geocode/json')) {
          if (request.url.queryParameters.containsKey('address')) {
            return http.Response(
              jsonEncode({
                'status': 'OK',
                'results': [
                  {
                    'place_id': 'geo_place_01',
                    'formatted_address': '500 E 4th St, Austin, TX 78701, USA',
                  },
                ],
              }),
              200,
            );
          } else if (request.url.queryParameters['place_id'] == 'geo_place_01') {
            return http.Response(
              jsonEncode({
                'status': 'OK',
                'results': [
                  {
                    'place_id': 'geo_place_01',
                    'formatted_address': '500 E 4th St, Austin, TX 78701, USA',
                    'address_components': [
                      {
                        'long_name': '500',
                        'short_name': '500',
                        'types': ['street_number'],
                      },
                      {
                        'long_name': 'East 4th Street',
                        'short_name': 'E 4th St',
                        'types': ['route'],
                      },
                      {
                        'long_name': 'Austin',
                        'short_name': 'Austin',
                        'types': ['locality'],
                      },
                      {
                        'long_name': 'Texas',
                        'short_name': 'TX',
                        'types': ['administrative_area_level_1'],
                      },
                      {
                        'long_name': '78701',
                        'short_name': '78701',
                        'types': ['postal_code'],
                      },
                    ],
                    'geometry': {
                      'location': {'lat': 30.2655, 'lng': -97.7398},
                    },
                  },
                ],
              }),
              200,
            );
          }
        }
        return http.Response('Error', 500);
      });

      PlacesAutocompleteService.setMockProviders(httpClient: mockClient);

      final preds = await PlacesAutocompleteService.fetchAutocompleteSuggestions(
        '500 E 4th St',
        sessionToken: 'tok-fallback',
      );
      expect(preds.length, 1);
      expect(preds.first.placeId, 'geo_place_01');
      expect(preds.first.mainText, '500 E 4th St');

      final details = await PlacesAutocompleteService.fetchPlaceDetails(
        'geo_place_01',
        sessionToken: 'tok-fallback',
      );
      expect(details, isNotNull);
      expect(details!.streetAddress, '500 East 4th Street');
      expect(details.city, 'Austin');
      expect(details.state, 'TX');
      expect(details.postalCode, '78701');
      expect(details.latitude, closeTo(30.2655, 0.0001));
      expect(details.longitude, closeTo(-97.7398, 0.0001));
    });

    test('1.6 Automatic fallback to Photon (with typo prefix retry & house number preservation) when Google returns API_KEY_HTTP_REFERRER_BLOCKED & REQUEST_DENIED', () async {
      final photonQueries = <String>[];

      final mockClient = MockClient((request) async {
        if (request.url.host == 'places.googleapis.com') {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'message': 'Requests from referer https://autodetailcraft.com/ are blocked.',
                'status': 'PERMISSION_DENIED',
              },
            }),
            403,
          );
        }
        if (request.url.host == 'maps.googleapis.com') {
          return http.Response(
            jsonEncode({
              'error_message': 'API keys with referer restrictions cannot be used with this API.',
              'results': [],
              'status': 'REQUEST_DENIED',
            }),
            200,
          );
        }
        if (request.url.host == 'photon.komoot.io') {
          final q = request.url.queryParameters['q'] ?? '';
          photonQueries.add(q);
          if (q == '800 enegy') {
            // Simulate exact typo returning 0 features
            return http.Response(
              jsonEncode({'type': 'FeatureCollection', 'features': []}),
              200,
            );
          }
          if (q == '800 ene') {
            // Prefix retry matches Energy Way
            return http.Response(
              jsonEncode({
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'geometry': {
                      'type': 'Point',
                      'coordinates': [-80.0684, 26.7153],
                    },
                    'properties': {
                      'osm_id': 987654,
                      'osm_type': 'W',
                      'name': 'Energy Way',
                      'city': 'West Palm Beach',
                      'state': 'Florida',
                      'postcode': '33409',
                    },
                  },
                ],
              }),
              200,
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      PlacesAutocompleteService.setMockProviders(httpClient: mockClient);

      final preds = await PlacesAutocompleteService.fetchAutocompleteSuggestions(
        '800 enegy',
        sessionToken: 'tok-photon-retry',
      );

      expect(photonQueries, ['800 enegy', '800 ene']);
      expect(preds.length, 1);
      expect(preds.first.mainText, '800 Energy Way');
      expect(preds.first.secondaryText, 'West Palm Beach, FL 33409');

      final details = await PlacesAutocompleteService.fetchPlaceDetails(
        preds.first.placeId,
        sessionToken: 'tok-photon-retry',
      );
      expect(details, isNotNull);
      expect(details!.streetAddress, '800 Energy Way');
      expect(details.city, 'West Palm Beach');
      expect(details.state, 'FL');
      expect(details.postalCode, '33409');
      expect(details.latitude, closeTo(26.7153, 0.0001));
      expect(details.longitude, closeTo(-80.0684, 0.0001));
    });

    test('1.7 Automatic fallback to Nominatim when Google and Photon are unavailable', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'places.googleapis.com') {
          throw Exception('CORS preflight failed');
        }
        if (request.url.host == 'maps.googleapis.com' ||
            request.url.host == 'photon.komoot.io') {
          return http.Response('Service Unavailable', 503);
        }
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode([
              {
                'place_id': 445566,
                'lat': '30.2672',
                'lon': '-97.7431',
                'display_name': '300, West 6th Street, Austin, Texas, 78701, USA',
                'address': {
                  'house_number': '300',
                  'road': 'West 6th Street',
                  'city': 'Austin',
                  'state': 'Texas',
                  'ISO3166-2-lvl4': 'US-TX',
                  'postcode': '78701',
                },
              },
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      PlacesAutocompleteService.setMockProviders(httpClient: mockClient);

      final preds = await PlacesAutocompleteService.fetchAutocompleteSuggestions(
        '300 W 6th St',
        sessionToken: 'tok-nominatim',
      );

      expect(preds.length, 1);
      expect(preds.first.mainText, '300 West 6th Street');
      expect(preds.first.secondaryText, 'Austin, TX 78701');

      final details = await PlacesAutocompleteService.fetchPlaceDetails(
        preds.first.placeId,
        sessionToken: 'tok-nominatim',
      );
      expect(details, isNotNull);
      expect(details!.streetAddress, '300 West 6th Street');
      expect(details.city, 'Austin');
      expect(details.state, 'TX');
      expect(details.postalCode, '78701');
      expect(details.latitude, closeTo(30.2672, 0.0001));
      expect(details.longitude, closeTo(-97.7431, 0.0001));
    });

    test('1.8 Photon & Nominatim ignore bare numeric/streetless features when user types a house number, and Nominatim performs 3-char typo prefix retry', () async {
      final nominatimQueries = <String>[];

      final mockClient = MockClient((request) async {
        if (request.url.host == 'places.googleapis.com' ||
            request.url.host == 'maps.googleapis.com') {
          return http.Response('Forbidden', 403);
        }
        if (request.url.host == 'photon.komoot.io') {
          // Return only a city-level feature with no street and a bare numeric name "800"
          // Both must be rejected when user typed "800 enegy"
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [-97.7431, 30.2672],
                  },
                  'properties': {
                    'osm_id': 111,
                    'osm_type': 'N',
                    'city': 'Austin',
                    'state': 'Texas',
                  },
                },
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [-97.7431, 30.2672],
                  },
                  'properties': {
                    'osm_id': 222,
                    'osm_type': 'N',
                    'name': '800',
                    'city': 'Austin',
                    'state': 'Texas',
                  },
                },
              ],
            }),
            200,
          );
        }
        if (request.url.host == 'nominatim.openstreetmap.org') {
          final q = request.url.queryParameters['q'] ?? '';
          nominatimQueries.add(q);
          if (q == '800 enegy') {
            return http.Response(jsonEncode([]), 200);
          }
          if (q == '800 ene') {
            return http.Response(
              jsonEncode([
                {
                  'place_id': 778899,
                  'name': '800',
                  'lat': '32.6177',
                  'lon': '-117.0570',
                  'display_name': '800, Energy Way, Chula Vista, California, 91911, USA',
                  'address': {
                    'house_number': '800',
                    'road': 'Energy Way',
                    'city': 'Chula Vista',
                    'state': 'California',
                    'ISO3166-2-lvl4': 'US-CA',
                    'postcode': '91911',
                  },
                },
              ]),
              200,
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      PlacesAutocompleteService.setMockProviders(httpClient: mockClient);

      final preds = await PlacesAutocompleteService.fetchAutocompleteSuggestions(
        '800 enegy',
        sessionToken: 'tok-nom-retry',
      );

      expect(nominatimQueries, ['800 enegy', '800 ene']);
      expect(preds.length, 1);
      expect(preds.first.mainText, '800 Energy Way');
      expect(preds.first.secondaryText, 'Chula Vista, CA 91911');
    });
  });

  // =========================================================================
  // GROUP 2: EditProfileDialog Session-Token Autocomplete & Coordinate Persistence
  // =========================================================================
  group('2. EditProfileDialog Address Autocomplete & Coordinate Persistence', () {
    testWidgets('2.1 Client profile setup: typing street address shows debounced predictions, clicking suggestion auto-fills fields & persists coordinates', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final observedSessionTokens = <String>[];
      String? detailsSessionToken;

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async {
          observedSessionTokens.add(token);
          return [
            const PlacePrediction(
              placeId: 'place_home_austin',
              description: '1200 S Congress Ave, Austin, TX 78704',
              mainText: '1200 S Congress Ave',
              secondaryText: 'Austin, TX 78704',
            ),
          ];
        },
        placeDetailsProvider: (placeId, token) async {
          detailsSessionToken = token;
          return const ResolvedPlaceDetails(
            placeId: 'place_home_austin',
            formattedAddress: '1200 S Congress Ave, Austin, TX 78704',
            streetAddress: '1200 S Congress Ave',
            city: 'Austin',
            state: 'TX',
            postalCode: '78704',
            latitude: 30.2505,
            longitude: -97.7495,
          );
        },
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: const UserProfile(
            id: 'usr_client_auto',
            username: 'client_auto',
            displayName: 'Alex Rivera',
            role: UserRole.client,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => EditProfileDialog.show(ctx, repository: repo),
                  child: const Text('Open Edit Profile'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Profile'));
        await tester.pumpAndSettle();

        final streetField = find.byKey(const Key('edit_profile_street_input'));
        expect(streetField, findsOneWidget);

        // Type rapidly to test 300ms debounce and session token bundling
        await tester.enterText(streetField, '1200 S');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.enterText(streetField, '1200 S Congress');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Only 1 debounced autocomplete call should have fired
        expect(observedSessionTokens.length, 1);
        expect(find.byKey(const Key('edit_profile_autocomplete_dropdown')), findsOneWidget);
        expect(find.text('1200 S Congress Ave'), findsOneWidget);

        // Tap the suggestion
        await tester.tap(find.byKey(const Key('edit_profile_prediction_item_0')));
        await tester.pumpAndSettle();

        // Verify details call used the exact same session token
        expect(detailsSessionToken, equals(observedSessionTokens.first));

        // Verify GPS Verified badge appears and fields are auto-filled
        expect(find.byKey(const Key('edit_profile_verified_coords_badge')), findsOneWidget);

        // Save profile
        await tester.tap(find.text('Save Profile'));
        await tester.pumpAndSettle();

        // Verify repository currentUser has structured address AND coordinates
        expect(repo.currentUser.streetAddress, '1200 S Congress Ave');
        expect(repo.currentUser.city, 'Austin');
        expect(repo.currentUser.state, 'TX');
        expect(repo.currentUser.postalCode, '78704');
        expect(repo.currentUser.latitude, closeTo(30.2505, 0.0001));
        expect(repo.currentUser.longitude, closeTo(-97.7495, 0.0001));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2.2 Studio profile setup: selecting studio autocomplete suggestion updates studioLatitude/studioLongitude without overwriting private home address', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async => [
          const PlacePrediction(
            placeId: 'place_studio_rr',
            description: '500 E Main St, Round Rock, TX 78664',
            mainText: '500 E Main St',
            secondaryText: 'Round Rock, TX 78664',
          ),
        ],
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_studio_rr',
          formattedAddress: '500 E Main St, Round Rock, TX 78664',
          streetAddress: '500 E Main St',
          city: 'Round Rock',
          state: 'TX',
          postalCode: '78664',
          latitude: 30.5083,
          longitude: -97.6789,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: const UserProfile(
            id: 'usr_det_auto',
            username: 'det_auto',
            displayName: 'Marcus Vance',
            businessName: 'Vance Auto Spa',
            role: UserRole.detailer,
            // Private residential home in South Austin
            streetAddress: '742 Private Home Ln',
            city: 'Austin',
            state: 'TX',
            postalCode: '78704',
            latitude: 30.2500,
            longitude: -97.7500,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => EditProfileDialog.show(
                    ctx,
                    repository: repo,
                    isStudioProfile: true,
                  ),
                  child: const Text('Open Studio Profile'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Studio Profile'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('edit_profile_street_input')), '500 E Main');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('edit_profile_prediction_item_0')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save Profile'));
        await tester.pumpAndSettle();

        // Commercial studio address & coordinates updated
        expect(repo.currentUser.studioStreetAddress, '500 E Main St');
        expect(repo.currentUser.studioCity, 'Round Rock');
        expect(repo.currentUser.studioState, 'TX');
        expect(repo.currentUser.studioPostalCode, '78664');
        expect(repo.currentUser.studioLatitude, closeTo(30.5083, 0.0001));
        expect(repo.currentUser.studioLongitude, closeTo(-97.6789, 0.0001));

        // Private residential home address & coordinates remain 100% untouched
        expect(repo.currentUser.streetAddress, '742 Private Home Ln');
        expect(repo.currentUser.city, 'Austin');
        expect(repo.currentUser.latitude, closeTo(30.2500, 0.0001));
        expect(repo.currentUser.longitude, closeTo(-97.7500, 0.0001));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('2.3 Subsequent typing after selecting a suggestion rotates session token immediately, and manual unverified edits clear stale coordinates while unit edits preserve them', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final autocompleteTokens = <String>[];

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async {
          autocompleteTokens.add(token);
          if (input.contains('1200')) {
            return [
              const PlacePrediction(
                placeId: 'place_1',
                description: '1200 S Congress Ave, Austin, TX 78704',
                mainText: '1200 S Congress Ave',
                secondaryText: 'Austin, TX 78704',
              ),
            ];
          }
          return const [];
        },
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_1',
          formattedAddress: '1200 S Congress Ave, Austin, TX 78704',
          streetAddress: '1200 S Congress Ave',
          city: 'Austin',
          state: 'TX',
          postalCode: '78704',
          latitude: 30.2505,
          longitude: -97.7495,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: const UserProfile(
            id: 'usr_client_stale_check',
            username: 'client_stale',
            displayName: 'Jordan Lee',
            role: UserRole.client,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => EditProfileDialog.show(ctx, repository: repo),
                  child: const Text('Open Edit Profile'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Profile'));
        await tester.pumpAndSettle();

        final streetField = find.byKey(const Key('edit_profile_street_input'));
        await tester.enterText(streetField, '1200 S Congress');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(autocompleteTokens.length, 1);
        final firstSessionToken = autocompleteTokens.first;

        // Tap suggestion -> populates coordinates & shows GPS Verified badge
        await tester.tap(find.byKey(const Key('edit_profile_prediction_item_0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('edit_profile_verified_coords_badge')), findsOneWidget);

        // Editing optional Apt/Unit/Gate Code preserves GPS Verified badge
        await tester.enterText(find.byKey(const Key('edit_profile_unit_input')), 'Apt 4B');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('edit_profile_verified_coords_badge')), findsOneWidget);

        // Now manually type a different street address without selecting a suggestion:
        // 1) Must NOT be swallowed by _suppressNextAutocomplete
        // 2) Must use a freshly rotated session token
        // 3) Must invalidate stale coordinates & hide GPS Verified badge
        await tester.enterText(streetField, '999 Manual Unverified Rd');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(autocompleteTokens.length, 2, reason: 'Next keystroke after selection must trigger autocomplete with rotated token');
        expect(autocompleteTokens.last, isNot(equals(firstSessionToken)), reason: 'Session token must rotate after Place Details call');
        expect(find.byKey(const Key('edit_profile_verified_coords_badge')), findsNothing);

        // Save manually edited address
        await tester.tap(find.text('Save Profile'));
        await tester.pumpAndSettle();

        expect(repo.currentUser.streetAddress, '999 Manual Unverified Rd');
        expect(repo.currentUser.unitOrApt, 'Apt 4B');
        expect(repo.currentUser.latitude, isNull, reason: 'Stale latitude must be cleared on manual street edit');
        expect(repo.currentUser.longitude, isNull, reason: 'Stale longitude must be cleared on manual street edit');
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });

  // =========================================================================
  // GROUP 3: BookingFlowScreen Temporary Location Autocomplete & Coordinates
  // =========================================================================
  group('3. BookingFlowScreen Temporary Location Autocomplete & Coordinates', () {
    const testStudioDetailer = UserProfile(
      id: 'usr_detailer_austin',
      username: 'marcus_apex',
      displayName: 'Marcus Vance',
      businessName: 'Apex Precision Detailing',
      location: 'Austin, TX',
      studioStreetAddress: '500 E 4th St',
      studioCity: 'Austin',
      studioState: 'TX',
      studioPostalCode: '78701',
      studioLatitude: 30.2655,
      studioLongitude: -97.7398,
      servicePackages: [
        ServicePackage(
          id: 'pkg_full_detail',
          title: 'Full Signature Detail',
          description: 'Comprehensive interior and exterior restoration',
          basePrice: 350.0,
          estimatedDuration: '4 hrs',
          includes: ['Hand wash', 'Clay bar', 'Interior deep clean'],
        ),
      ],
    );

    const testClientUser = UserProfile(
      id: 'usr_client_01',
      username: 'alex@example.com',
      displayName: 'Alex Client',
      phone: '(512) 555-0199',
      streetAddress: '1200 S Congress Ave',
      unitOrApt: 'Apt 304',
      city: 'Austin',
      state: 'TX',
      postalCode: '78704',
      latitude: 30.2505,
      longitude: -97.7495,
      myGarage: [
        UserVehicle(
          id: 'veh_01',
          make: 'Porsche',
          model: '911 GT3',
          year: 2024,
          colorName: 'Shark Blue',
          imageUrl: '',
          vehicleType: 'Coupe',
        ),
      ],
    );

    testWidgets('3.1 Selecting a temporary location suggestion at checkout auto-fills fields and saves exact temporary coordinates to BookingAppointment', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async => [
          const PlacePrediction(
            placeId: 'place_domain_office',
            description: '11601 Alterra Pkwy, Austin, TX 78758',
            mainText: '11601 Alterra Pkwy',
            secondaryText: 'Austin, TX 78758',
          ),
        ],
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_domain_office',
          formattedAddress: '11601 Alterra Pkwy, Austin, TX 78758',
          streetAddress: '11601 Alterra Pkwy',
          city: 'Austin',
          state: 'TX',
          postalCode: '78758',
          latitude: 30.4021,
          longitude: -97.7253,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance Step 0 -> Step 1 -> Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Switch to Temporary Location
        await tester.tap(find.byKey(const Key('checkout_location_temp_option')));
        await tester.pumpAndSettle();

        // Type in temporary street field
        final tempStreet = find.byKey(const Key('checkout_temp_street_field'));
        await tester.enterText(tempStreet, '11601 Alterra');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Dropdown appears
        expect(find.byKey(const Key('checkout_temp_autocomplete_dropdown')), findsOneWidget);
        expect(find.text('11601 Alterra Pkwy'), findsOneWidget);

        // Tap suggestion
        await tester.tap(find.byKey(const Key('checkout_temp_prediction_item_0')));
        await tester.pumpAndSettle();

        // Confirm booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;
        expect(booking.clientAddress, contains('11601 Alterra Pkwy'));
        expect(booking.clientAddress, contains('78758'));
        expect(booking.latitude, closeTo(30.4021, 0.0001));
        expect(booking.longitude, closeTo(-97.7253, 0.0001));

        // Client's saved home profile coordinates remain untouched
        expect(repo.currentUser.latitude, closeTo(30.2505, 0.0001));
        expect(repo.currentUser.longitude, closeTo(-97.7495, 0.0001));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3.2 Manually editing temporary address after selecting a suggestion invalidates stale temporary coordinates and rotates session token', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      final tempSessionTokens = <String>[];

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async {
          tempSessionTokens.add(token);
          if (input.contains('11601')) {
            return [
              const PlacePrediction(
                placeId: 'place_domain_office',
                description: '11601 Alterra Pkwy, Austin, TX 78758',
                mainText: '11601 Alterra Pkwy',
                secondaryText: 'Austin, TX 78758',
              ),
            ];
          }
          return const [];
        },
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_domain_office',
          formattedAddress: '11601 Alterra Pkwy, Austin, TX 78758',
          streetAddress: '11601 Alterra Pkwy',
          city: 'Austin',
          state: 'TX',
          postalCode: '78758',
          latitude: 30.4021,
          longitude: -97.7253,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance Step 0 -> Step 1 -> Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Switch to Temporary Location
        await tester.tap(find.byKey(const Key('checkout_location_temp_option')));
        await tester.pumpAndSettle();

        final tempStreet = find.byKey(const Key('checkout_temp_street_field'));
        await tester.enterText(tempStreet, '11601 Alterra');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(tempSessionTokens.length, 1);
        final firstToken = tempSessionTokens.first;

        // Select suggestion
        await tester.tap(find.byKey(const Key('checkout_temp_prediction_item_0')));
        await tester.pumpAndSettle();

        // Now manually overwrite temporary street to a different unverified address
        await tester.enterText(tempStreet, '800 Custom Ranch Rd');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(tempSessionTokens.length, 2);
        expect(tempSessionTokens.last, isNot(equals(firstToken)));

        // Confirm booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;
        expect(booking.clientAddress, contains('800 Custom Ranch Rd'));
        expect(booking.latitude, isNull, reason: 'Stale temporary latitude must be cleared on manual street edit');
        expect(booking.longitude, isNull, reason: 'Stale temporary longitude must be cleared on manual street edit');
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3.3 Typing into Step 1 mobile address field shows autocomplete dropdown and populates Step 2 location & coordinates', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async => [
          const PlacePrediction(
            placeId: 'place_step1_gym',
            description: '900 Barton Springs Rd, Austin, TX 78704',
            mainText: '900 Barton Springs Rd',
            secondaryText: 'Austin, TX 78704',
          ),
        ],
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_step1_gym',
          formattedAddress: '900 Barton Springs Rd, Austin, TX 78704',
          streetAddress: '900 Barton Springs Rd',
          city: 'Austin',
          state: 'TX',
          postalCode: '78704',
          latitude: 30.2610,
          longitude: -97.7560,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance Step 0 -> Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final step1AddressField = find.byKey(const Key('step1_mobile_address_field'));
        expect(step1AddressField, findsOneWidget);

        await tester.enterText(step1AddressField, '900 Barton');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('step1_address_autocomplete_dropdown')), findsOneWidget);
        expect(find.text('900 Barton Springs Rd'), findsOneWidget);

        await tester.tap(find.byKey(const Key('step1_prediction_item_0')));
        await tester.pumpAndSettle();

        // Advance Step 1 -> Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Confirm booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;
        expect(booking.clientAddress, contains('900 Barton Springs Rd'));
        expect(booking.latitude, closeTo(30.2610, 0.0001));
        expect(booking.longitude, closeTo(-97.7560, 0.0001));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3.4 Manually editing Step 1 mobile address field after selecting a Step 1 prediction clears stale coordinates and updates submitted address', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      setupMockImageHttpClient();

      PlacesAutocompleteService.setMockProviders(
        autocompleteProvider: (input, token) async {
          if (input.contains('900')) {
            return [
              const PlacePrediction(
                placeId: 'place_step1_gym',
                description: '900 Barton Springs Rd, Austin, TX 78704',
                mainText: '900 Barton Springs Rd',
                secondaryText: 'Austin, TX 78704',
              ),
            ];
          }
          return const [];
        },
        placeDetailsProvider: (placeId, token) async => const ResolvedPlaceDetails(
          placeId: 'place_step1_gym',
          formattedAddress: '900 Barton Springs Rd, Austin, TX 78704',
          streetAddress: '900 Barton Springs Rd',
          city: 'Austin',
          state: 'TX',
          postalCode: '78704',
          latitude: 30.2610,
          longitude: -97.7560,
        ),
      );

      try {
        final repo = await TestHarness.createSession(
          isLoggedIn: true,
          currentUser: testClientUser,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BookingFlowScreen(
                detailer: testStudioDetailer,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance Step 0 -> Step 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final step1AddressField = find.byKey(const Key('step1_mobile_address_field'));
        await tester.enterText(step1AddressField, '900 Barton');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('step1_prediction_item_0')));
        await tester.pumpAndSettle();

        // Now manually overwrite Step 1 address field without selecting a prediction
        await tester.enterText(step1AddressField, '777 Manual Override Way, Round Rock, TX 78664');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Advance Step 1 -> Step 2
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Confirm booking
        final confirmBtn = find.text('Reserve & Book').evaluate().isNotEmpty
            ? find.text('Reserve & Book')
            : find.text('Confirm & Request Booking');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(repo.bookings, isNotEmpty);
        final booking = repo.bookings.last;
        expect(booking.clientAddress, equals('777 Manual Override Way, Round Rock, TX 78664'));
        expect(booking.latitude, isNull, reason: 'Stale Step 1 coordinates must be cleared on manual Step 1 edit');
        expect(booking.longitude, isNull, reason: 'Stale Step 1 coordinates must be cleared on manual Step 1 edit');
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
