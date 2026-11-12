// =========================================================================
// File: lib/services/places_autocomplete_service.dart
// Description: Session-Token Address Autocomplete & Place Details Service
//              using Google Places API (New) and Geocoding API fallback.
// =========================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// Immutable address prediction returned by Google Places Autocomplete.
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacePrediction &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId &&
          description == other.description &&
          mainText == other.mainText &&
          secondaryText == other.secondaryText;

  @override
  int get hashCode =>
      placeId.hashCode ^
      description.hashCode ^
      mainText.hashCode ^
      secondaryText.hashCode;

  @override
  String toString() =>
      'PlacePrediction(placeId: $placeId, mainText: $mainText, secondaryText: $secondaryText)';
}

/// Structured address details and exact coordinates resolved for a selected place.
class ResolvedPlaceDetails {
  final String placeId;
  final String formattedAddress;
  final String streetAddress;
  final String unitOrApt;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const ResolvedPlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.streetAddress,
    this.unitOrApt = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  @override
  String toString() =>
      'ResolvedPlaceDetails(streetAddress: $streetAddress, city: $city, state: $state, postalCode: $postalCode, lat: $latitude, lng: $longitude)';
}

/// Service managing Google Places API (New) session-token autocomplete
/// (`https://places.googleapis.com/v1/places:autocomplete`) and place details
/// resolution (`https://places.googleapis.com/v1/places/{placeId}`), with automatic
/// fallback to Google Geocoding API (`https://maps.googleapis.com/maps/api/geocode/json`).
///
/// Strictly scoped to Profile Setup (`EditProfileDialog`) and Checkout Temporary
/// Location (`BookingFlowScreen`). Never attached to the Explore search bar ($0.00).
class PlacesAutocompleteService {
  static final math.Random _random = math.Random();

  /// Deterministic mock autocomplete provider for offline widget & unit tests.
  static Future<List<PlacePrediction>> Function(String input, String sessionToken)?
      _mockAutocompleteProvider;

  /// Deterministic mock place details provider for offline widget & unit tests.
  static Future<ResolvedPlaceDetails?> Function(String placeId, String sessionToken)?
      _mockPlaceDetailsProvider;

  /// Optional injectable HTTP client for testing raw JSON parsing and fallback paths.
  static http.Client? _mockHttpClient;

  /// In-memory cache of resolved place details keyed by placeId for fallback providers
  /// that return full address components and coordinates during autocomplete search.
  static final Map<String, ResolvedPlaceDetails> _cachedDetailsByPlaceId = {};
  static final Map<String, String> _inlineUnitByPlaceId = {};

  /// Sets mock providers so widget and unit tests run deterministically offline.
  static void setMockProviders({
    Future<List<PlacePrediction>> Function(String input, String sessionToken)?
        autocompleteProvider,
    Future<ResolvedPlaceDetails?> Function(String placeId, String sessionToken)?
        placeDetailsProvider,
    http.Client? httpClient,
  }) {
    _mockAutocompleteProvider = autocompleteProvider;
    _mockPlaceDetailsProvider = placeDetailsProvider;
    _mockHttpClient = httpClient;
    _cachedDetailsByPlaceId.clear();
    _geocodeSearchDetailsByPlaceId.clear();
    _inlineUnitByPlaceId.clear();
  }

  /// Resets all mock providers back to live production behavior.
  static void resetMockProviders() {
    _mockAutocompleteProvider = null;
    _mockPlaceDetailsProvider = null;
    _mockHttpClient = null;
    _cachedDetailsByPlaceId.clear();
    _geocodeSearchDetailsByPlaceId.clear();
    _inlineUnitByPlaceId.clear();
  }

  /// Generates a RFC-4122 compliant UUID v4 session token so all keystrokes
  /// during a single address entry bundle into one Google Places billing session.
  static String generateSessionToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  /// Fetches live street address predictions for [input] bundled under [sessionToken].
  /// Returns an empty list if [input] has fewer than 3 characters, or if offline/error.
  static Future<List<PlacePrediction>> fetchAutocompleteSuggestions(
    String input, {
    required String sessionToken,
  }) async {
    final trimmed = input.trim();
    if (trimmed.length < 3) {
      return const [];
    }

    // 1. Check deterministic mock override first
    if (_mockAutocompleteProvider != null) {
      try {
        return await _mockAutocompleteProvider!(trimmed, sessionToken);
      } catch (e) {
        if (kDebugMode) {
          print('[PlacesAutocompleteService] Mock autocomplete error: $e');
        }
        return const [];
      }
    }

    final apiKey = SupabaseService.googleMapsApiKey.trim();
    if (apiKey.isEmpty) {
      return const [];
    }

    final client = _mockHttpClient ?? http.Client();
    try {
      // 2. Primary (Tier 1): Google Places API (New) Autocomplete
      final placesNewResults = await _fetchGooglePlacesNewPredictions(
        trimmed,
        sessionToken: sessionToken,
        apiKey: apiKey,
        client: client,
      );
      if (placesNewResults.isNotEmpty) {
        return placesNewResults;
      }

      // 3. Secondary (Tier 2): Google Geocoding API
      final geocodeResults = await _fallbackGeocodePredictions(
        trimmed,
        apiKey,
        client,
      );
      if (geocodeResults.isNotEmpty) {
        return geocodeResults;
      }

      // 4. Tertiary (Tier 3): Zero-key CORS-enabled OpenStreetMap Photon / Nominatim fallback
      //    Ensures dropdown suggestions still appear when Google API key HTTP referrer
      //    restrictions block non-www, localhost, preview URLs, or native apps.
      final photonResults = await _fallbackPhotonPredictions(trimmed, client);
      if (photonResults.isNotEmpty) {
        return photonResults;
      }

      return await _fallbackNominatimPredictions(trimmed, client);
    } catch (e) {
      if (kDebugMode) {
        print('[PlacesAutocompleteService] Autocomplete fallback error: $e');
      }
      return const [];
    } finally {
      if (_mockHttpClient == null) {
        client.close();
      }
    }
  }

  static Future<List<PlacePrediction>> _fetchGooglePlacesNewPredictions(
    String trimmed, {
    required String sessionToken,
    required String apiKey,
    required http.Client client,
  }) async {
    final inline = extractInlineUnitOrApt(trimmed);
    final direct = await _queryGooglePlacesNewEndpoint(
      trimmed,
      extractedUnitOrApt: inline.unitOrApt,
      sessionToken: sessionToken,
      apiKey: apiKey,
      client: client,
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    if (inline.unitOrApt.isNotEmpty && inline.cleanedQuery != trimmed) {
      return await _queryGooglePlacesNewEndpoint(
        inline.cleanedQuery,
        extractedUnitOrApt: inline.unitOrApt,
        sessionToken: sessionToken,
        apiKey: apiKey,
        client: client,
      );
    }
    return const [];
  }

  static Future<List<PlacePrediction>> _queryGooglePlacesNewEndpoint(
    String queryText, {
    required String extractedUnitOrApt,
    required String sessionToken,
    required String apiKey,
    required http.Client client,
  }) async {
    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final response = await client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.placeId,suggestions.placePrediction.place,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
            },
            body: jsonEncode({
              'input': queryText,
              'sessionToken': sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final suggestions = decoded['suggestions'] as List<dynamic>?;
          if (suggestions != null && suggestions.isNotEmpty) {
            final results = <PlacePrediction>[];
            for (final item in suggestions) {
              if (item is! Map) continue;
              final pred = item['placePrediction'];
              if (pred is! Map) continue;

              final placeId = (pred['placeId'] ?? pred['place'] ?? '').toString().trim();
              if (placeId.isEmpty) continue;

              String fullText = '';
              final textMap = pred['text'];
              if (textMap is Map && textMap['text'] != null) {
                fullText = textMap['text'].toString().trim();
              }

              String mainText = '';
              String secondaryText = '';
              final structured = pred['structuredFormat'];
              if (structured is Map) {
                final mainMap = structured['mainText'];
                if (mainMap is Map && mainMap['text'] != null) {
                  mainText = mainMap['text'].toString().trim();
                }
                final secMap = structured['secondaryText'];
                if (secMap is Map && secMap['text'] != null) {
                  secondaryText = secMap['text'].toString().trim();
                }
              }

              if (fullText.isEmpty) {
                fullText = [
                  if (mainText.isNotEmpty) mainText,
                  if (secondaryText.isNotEmpty) secondaryText,
                ].join(', ');
              }
              if (mainText.isEmpty && fullText.isNotEmpty) {
                mainText = fullText.split(',').first.trim();
              }
              if (secondaryText.isEmpty && fullText.contains(',')) {
                secondaryText = fullText.split(',').skip(1).join(',').trim();
              }

              final cleanId = placeId.startsWith('places/')
                  ? placeId.substring('places/'.length)
                  : placeId;
              if (extractedUnitOrApt.isNotEmpty) {
                _inlineUnitByPlaceId[placeId] = extractedUnitOrApt;
                _inlineUnitByPlaceId[cleanId] = extractedUnitOrApt;
                if (!containsAddressSegment(fullText, extractedUnitOrApt)) {
                  fullText = [
                    if (mainText.isNotEmpty) mainText,
                    extractedUnitOrApt,
                    if (secondaryText.isNotEmpty) secondaryText,
                  ].join(', ');
                }
              } else {
                _inlineUnitByPlaceId.remove(placeId);
                _inlineUnitByPlaceId.remove(cleanId);
              }

              if (fullText.isNotEmpty) {
                results.add(
                  PlacePrediction(
                    placeId: placeId,
                    description: fullText,
                    mainText: mainText,
                    secondaryText: secondaryText,
                  ),
                );
              }
            }
            if (results.isNotEmpty) {
              return results;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PlacesAutocompleteService] Places API (New) autocomplete error: $e');
      }
    }
    return const [];
  }

  /// Resolves structured street, city, state, postal code, and exact lat/lng
  /// coordinates for [placeId] using the active [sessionToken].
  static Future<ResolvedPlaceDetails?> fetchPlaceDetails(
    String placeId, {
    required String sessionToken,
  }) async {
    final trimmedId = placeId.trim();
    if (trimmedId.isEmpty) return null;

    // 1. Check deterministic mock override first
    if (_mockPlaceDetailsProvider != null) {
      try {
        return await _mockPlaceDetailsProvider!(trimmedId, sessionToken);
      } catch (e) {
        if (kDebugMode) {
          print('[PlacesAutocompleteService] Mock place details error: $e');
        }
        return null;
      }
    }

    // 2. Check pre-resolved details cache (from Photon / Nominatim)
    final cached = _cachedDetailsByPlaceId[trimmedId];
    if (cached != null) {
      return cached;
    }

    final apiKey = SupabaseService.googleMapsApiKey.trim();
    if (apiKey.isEmpty) return null;

    final client = _mockHttpClient ?? http.Client();
    try {
      final cleanId = trimmedId.startsWith('places/')
          ? trimmedId.substring('places/'.length)
          : trimmedId;
      final inlineUnit = _inlineUnitByPlaceId[cleanId] ?? _inlineUnitByPlaceId[trimmedId] ?? '';

      try {
        final uri = Uri.parse(
          'https://places.googleapis.com/v1/places/${Uri.encodeComponent(cleanId)}'
          '?fields=id,formattedAddress,addressComponents,location'
          '&sessionToken=${Uri.encodeQueryComponent(sessionToken)}',
        );

        final response = await client
            .get(
              uri,
              headers: {
                'X-Goog-Api-Key': apiKey,
                'X-Goog-FieldMask': 'id,formattedAddress,addressComponents,location',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return parsePlacesNewDetailsJson(
              decoded,
              fallbackPlaceId: cleanId,
              fallbackUnitOrApt: inlineUnit,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[PlacesAutocompleteService] Places API (New) details error: $e');
        }
      }

      // Fallback to Geocoding API by place_id, or pre-parsed geocode search result
      final geocodeDetails = await _fallbackGeocodePlaceDetails(
        cleanId,
        apiKey,
        client,
        fallbackUnitOrApt: inlineUnit,
      );
      if (geocodeDetails != null) {
        return geocodeDetails;
      }
      return _geocodeSearchDetailsByPlaceId[cleanId] ?? _geocodeSearchDetailsByPlaceId[trimmedId];
    } catch (e) {
      if (kDebugMode) {
        print('[PlacesAutocompleteService] Place details error: $e');
      }
      return _geocodeSearchDetailsByPlaceId[trimmedId];
    } finally {
      if (_mockHttpClient == null) {
        client.close();
      }
    }
  }

  static final Map<String, ResolvedPlaceDetails> _geocodeSearchDetailsByPlaceId = {};

  /// Parses a Google Places API (New) Place Details JSON payload into [ResolvedPlaceDetails].
  static ResolvedPlaceDetails parsePlacesNewDetailsJson(
    Map<String, dynamic> json, {
    String fallbackPlaceId = '',
    String fallbackUnitOrApt = '',
  }) {
    final id = (json['id'] ?? fallbackPlaceId).toString();
    final formattedAddress = (json['formattedAddress'] ?? '').toString().trim();

    String streetNumber = '';
    String route = '';
    String subpremise = '';
    String city = '';
    String sublocality = '';
    String adminArea2 = '';
    String state = '';
    String postalCode = '';

    final components = json['addressComponents'];
    if (components is List) {
      for (final comp in components) {
        if (comp is! Map) continue;
        final typesRaw = comp['types'];
        final types = typesRaw is List
            ? typesRaw.map((e) => e.toString()).toList()
            : const <String>[];
        final longText = (comp['longText'] ?? comp['long_name'] ?? '').toString().trim();
        final shortText = (comp['shortText'] ?? comp['short_name'] ?? longText).toString().trim();

        if (types.contains('street_number')) {
          streetNumber = longText.isNotEmpty ? longText : shortText;
        } else if (types.contains('route')) {
          route = longText.isNotEmpty ? longText : shortText;
        } else if (types.contains('subpremise')) {
          subpremise = longText.isNotEmpty ? longText : shortText;
        } else if (types.contains('locality')) {
          city = longText.isNotEmpty ? longText : shortText;
        } else if (types.contains('sublocality') || types.contains('sublocality_level_1') || types.contains('neighborhood')) {
          if (sublocality.isEmpty) {
            sublocality = longText.isNotEmpty ? longText : shortText;
          }
        } else if (types.contains('administrative_area_level_2')) {
          adminArea2 = longText.isNotEmpty ? longText : shortText;
        } else if (types.contains('administrative_area_level_1')) {
          state = shortText.isNotEmpty ? shortText : longText;
        } else if (types.contains('postal_code')) {
          postalCode = longText.isNotEmpty ? longText : shortText;
        }
      }
    }

    if (city.isEmpty) {
      city = sublocality.isNotEmpty ? sublocality : adminArea2;
    }

    String streetAddress = [
      if (streetNumber.isNotEmpty) streetNumber,
      if (route.isNotEmpty) route,
    ].join(' ').trim();

    if (streetAddress.isEmpty && formattedAddress.isNotEmpty) {
      streetAddress = formattedAddress.split(',').first.trim();
    }

    double? latitude;
    double? longitude;
    final location = json['location'];
    if (location is Map) {
      final latVal = location['latitude'] ?? location['lat'];
      final lngVal = location['longitude'] ?? location['lng'];
      if (latVal is num) latitude = latVal.toDouble();
      if (lngVal is num) longitude = lngVal.toDouble();
    }

    final effectiveUnit = fallbackUnitOrApt.trim().isNotEmpty
        ? fallbackUnitOrApt.trim()
        : subpremise;

    return ResolvedPlaceDetails(
      placeId: id,
      formattedAddress: formattedAddress,
      streetAddress: streetAddress,
      unitOrApt: effectiveUnit,
      city: city,
      state: state,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static Future<List<PlacePrediction>> _fallbackGeocodePredictions(
    String query,
    String apiKey,
    http.Client client,
  ) async {
    try {
      final inline = extractInlineUnitOrApt(query);
      final effectiveQuery = inline.cleanedQuery;
      final extractedUnit = inline.unitOrApt;

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeQueryComponent(effectiveQuery)}'
        '&key=${Uri.encodeQueryComponent(apiKey)}',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final results = decoded['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return const [];

      final predictions = <PlacePrediction>[];
      for (final item in results.take(5)) {
        if (item is! Map) continue;
        final placeId = (item['place_id'] ?? '').toString().trim();
        final formatted = (item['formatted_address'] ?? '').toString().trim();
        if (placeId.isEmpty || formatted.isEmpty) continue;

        if (extractedUnit.isNotEmpty) {
          _inlineUnitByPlaceId[placeId] = extractedUnit;
        } else {
          _inlineUnitByPlaceId.remove(placeId);
        }

        final parts = formatted.split(',');
        final mainText = parts.first.trim();
        final secondaryText = parts.length > 1 ? parts.skip(1).join(',').trim() : '';
        final description = (extractedUnit.isNotEmpty && !containsAddressSegment(formatted, extractedUnit))
            ? [
                if (mainText.isNotEmpty) mainText,
                extractedUnit,
                if (secondaryText.isNotEmpty) secondaryText,
              ].join(', ')
            : formatted;

        final components = item['address_components'] as List<dynamic>?;
        final geometry = item['geometry'];
        if ((components != null && components.isNotEmpty) || geometry is Map) {
          double? lat;
          double? lng;
          if (geometry is Map) {
            final loc = geometry['location'];
            if (loc is Map) {
              if (loc['lat'] is num) lat = (loc['lat'] as num).toDouble();
              if (loc['lng'] is num) lng = (loc['lng'] as num).toDouble();
            }
          }
          _geocodeSearchDetailsByPlaceId[placeId] = parsePlacesNewDetailsJson(
            {
              'id': placeId,
              'formattedAddress': description,
              'addressComponents': components ?? const [],
              'location': {
                'latitude': lat,
                'longitude': lng,
              },
            },
            fallbackPlaceId: placeId,
            fallbackUnitOrApt: extractedUnit,
          );
        }

        predictions.add(
          PlacePrediction(
            placeId: placeId,
            description: description,
            mainText: mainText,
            secondaryText: secondaryText,
          ),
        );
      }
      return predictions;
    } catch (_) {
      return const [];
    }
  }

  static Future<ResolvedPlaceDetails?> _fallbackGeocodePlaceDetails(
    String placeId,
    String apiKey,
    http.Client client, {
    String fallbackUnitOrApt = '',
  }) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?place_id=${Uri.encodeQueryComponent(placeId)}'
        '&key=${Uri.encodeQueryComponent(apiKey)}',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final results = decoded['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;

      final formattedAddress = (first['formatted_address'] ?? '').toString().trim();
      final components = first['address_components'] as List<dynamic>? ?? const [];

      double? lat;
      double? lng;
      final geometry = first['geometry'];
      if (geometry is Map) {
        final loc = geometry['location'];
        if (loc is Map) {
          if (loc['lat'] is num) lat = (loc['lat'] as num).toDouble();
          if (loc['lng'] is num) lng = (loc['lng'] as num).toDouble();
        }
      }

      return parsePlacesNewDetailsJson(
        {
          'id': placeId,
          'formattedAddress': formattedAddress,
          'addressComponents': components,
          'location': {
            'latitude': lat,
            'longitude': lng,
          },
        },
        fallbackPlaceId: placeId,
        fallbackUnitOrApt: fallbackUnitOrApt,
      );
    } catch (_) {
      return null;
    }
  }

  static const String _singleUnitPatternStr =
      r'(?:(?:apt|apartment|unit|suite|ste|bldg|building|fl|floor|rm|room)\.?\s*#?\s*(?!(?:st|street|ave|avenue|rd|road|dr|drive|blvd|boulevard|ln|lane|way|ct|court|pl|place|cir|circle|pkwy|parkway|ter|terrace|trl|trail|hwy|highway)\b)[A-Za-z0-9\-]+|#\s*[A-Za-z0-9\-]+)';

  static const String _compoundUnitPatternStr =
      '$_singleUnitPatternStr(?:\\s*,?\\s*$_singleUnitPatternStr)*';

  static final RegExp _inlineUnitRegex = RegExp(
    '(?:,\\s*|\\s+)($_compoundUnitPatternStr)(?=\\s*(?:,|\$|\\s+[A-Za-z]))',
    caseSensitive: false,
  );

  static final RegExp _unitIdentifierRegex = RegExp(
    '^$_compoundUnitPatternStr\$',
    caseSensitive: false,
  );

  static final RegExp _leadingHouseNumRegex = RegExp(
    r'^(\d+(?:-[0-9A-Za-z]+|[A-Za-z])?)\s+',
  );

  /// Returns true if [address] already contains [segment] as a distinct token/segment
  /// outside of the leading street house number (preventing false positives like
  /// house number "1200" or "800" matching unit "200" or "80").
  static bool containsAddressSegment(String address, String segment) {
    final cleanAddr = address.trim();
    final cleanSeg = segment.trim();
    if (cleanAddr.isEmpty || cleanSeg.isEmpty) return false;
    final withoutLeadingNum = cleanAddr.replaceFirst(_leadingHouseNumRegex, '');
    final boundaryPattern = RegExp(
      '(?:^|[\\s,])${RegExp.escape(cleanSeg)}(?:\$|[\\s,])',
      caseSensitive: false,
    );
    return boundaryPattern.hasMatch(withoutLeadingNum);
  }

  /// Extracts an inline apartment/unit/suite/building/floor designator (e.g., "Apt 703",
  /// "Bldg 4 Apt 703", "Unit 4B", "Suite 200", "Fl 7", "#703") from a street or full
  /// address string, returning both the cleaned address query (without the unit) and
  /// the extracted unit string.
  static ({String cleanedQuery, String unitOrApt}) extractInlineUnitOrApt(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return (cleanedQuery: '', unitOrApt: '');
    }
    final match = _inlineUnitRegex.firstMatch(trimmed);
    if (match == null) {
      return (cleanedQuery: trimmed, unitOrApt: '');
    }
    final extractedUnit = (match.group(1) ?? '').trim();
    final before = trimmed.substring(0, match.start).trim();
    final after = trimmed.substring(match.end).trim();
    String cleaned;
    if (before.isNotEmpty && after.isNotEmpty) {
      cleaned = after.startsWith(',') ? '$before$after' : '$before, $after';
    } else {
      cleaned = '$before$after'.trim();
    }
    cleaned = cleaned
        .replaceAll(RegExp(r',\s*,+'), ',')
        .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
        .trim();
    return (
      cleanedQuery: cleaned.isNotEmpty ? cleaned : trimmed,
      unitOrApt: extractedUnit,
    );
  }

  /// Returns true if [value] is an apartment/unit/suite/building/floor identifier
  /// (e.g. "Apt 703", "Bldg 4 Apt 703", "Unit 4B", "Suite 100", "Fl 7", "#703")
  /// rather than multi-word gate/parking instructions.
  static bool isUnitOrAptIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _unitIdentifierRegex.hasMatch(trimmed);
  }

  /// Builds a 3-character prefix retry query when the last word has >= 4 alphabetic characters
  /// (e.g., "800 enegy" -> "800 ene") to recover from street name typos.
  static String? _buildTypoPrefixRetryQuery(String query) {
    final tokens = query.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;
    final lastToken = tokens.last;
    if (lastToken.length >= 4 && RegExp(r'^[A-Za-z]+$').hasMatch(lastToken)) {
      final shortenedTokens = [
        ...tokens.sublist(0, tokens.length - 1),
        lastToken.substring(0, 3),
      ];
      return shortenedTokens.join(' ');
    }
    return null;
  }

  /// Tertiary zero-key CORS-enabled autocomplete fallback using Photon (OpenStreetMap).
  /// Includes automatic prefix retry when a multi-letter word has a typo (e.g. "800 enegy" -> "800 ene").
  static Future<List<PlacePrediction>> _fallbackPhotonPredictions(
    String query,
    http.Client client,
  ) async {
    final inline = extractInlineUnitOrApt(query);
    final effectiveQuery = inline.cleanedQuery;

    final directResults = await _queryPhotonEndpoint(
      effectiveQuery,
      originalUserQuery: effectiveQuery,
      extractedUnitOrApt: inline.unitOrApt,
      client: client,
    );
    if (directResults.isNotEmpty) {
      return directResults;
    }

    final retryQuery = _buildTypoPrefixRetryQuery(effectiveQuery);
    if (retryQuery != null) {
      final prefixResults = await _queryPhotonEndpoint(
        retryQuery,
        originalUserQuery: effectiveQuery,
        extractedUnitOrApt: inline.unitOrApt,
        client: client,
      );
      if (prefixResults.isNotEmpty) {
        return prefixResults;
      }
    }

    return const [];
  }

  static String _stripLeadingHouseNumberFromRoute({
    required String rawRoute,
    required bool isFromFallbackName,
    required String userLeadingHouseNum,
    required String houseNumRaw,
  }) {
    final trimmed = rawRoute.trim();
    if (trimmed.isEmpty) return '';
    if (userLeadingHouseNum.isNotEmpty &&
        trimmed.toLowerCase().startsWith('${userLeadingHouseNum.toLowerCase()} ')) {
      return trimmed.substring(userLeadingHouseNum.length).trim();
    }
    if (houseNumRaw.isNotEmpty &&
        trimmed.toLowerCase().startsWith('${houseNumRaw.toLowerCase()} ')) {
      return trimmed.substring(houseNumRaw.length).trim();
    }
    if (isFromFallbackName && userLeadingHouseNum.isNotEmpty) {
      return trimmed.replaceFirst(_leadingHouseNumRegex, '').trim();
    }
    return trimmed;
  }

  static Future<List<PlacePrediction>> _queryPhotonEndpoint(
    String searchQuery, {
    required String originalUserQuery,
    String extractedUnitOrApt = '',
    required http.Client client,
  }) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeQueryComponent(searchQuery)}'
        '&limit=5&lang=en',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final features = decoded['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return const [];

      final leadingNumMatch = _leadingHouseNumRegex.firstMatch(originalUserQuery.trim());
      final userLeadingHouseNum = leadingNumMatch?.group(1) ?? '';

      final usPredictions = <PlacePrediction>[];
      final otherPredictions = <PlacePrediction>[];
      final seenDescriptions = <String>{};

      for (int i = 0; i < features.length; i++) {
        final feat = features[i];
        if (feat is! Map) continue;
        final props = feat['properties'];
        if (props is! Map) continue;

        final osmId = (props['osm_id'] ?? i).toString();
        final osmType = (props['osm_type'] ?? 'N').toString();
        final houseNumRaw = (props['housenumber'] ?? '').toString().trim();
        final streetRaw = (props['street'] ?? '').toString().trim();
        final nameRaw = (props['name'] ?? '').toString().trim();
        final safeName = RegExp(r'^\d+(?:-[0-9A-Za-z]+|[A-Za-z])?$').hasMatch(nameRaw) ? '' : nameRaw;

        final city = (props['city'] ??
                props['town'] ??
                props['locality'] ??
                props['district'] ??
                props['county'] ??
                '')
            .toString()
            .trim();
        final stateRaw = (props['state'] ?? '').toString().trim();
        final state = _normalizeUsState(stateRaw);
        final postalCode = (props['postcode'] ?? '').toString().trim();
        final countryCode = (props['countrycode'] ?? '').toString().trim().toUpperCase();

        // Always prioritize the user's explicitly typed leading house number (e.g. "800" or "41-05")
        // so Photon never overwrites it with a different mapped building number (e.g. "4105") on the same street.
        final effectiveHouseNum = userLeadingHouseNum.isNotEmpty ? userLeadingHouseNum : houseNumRaw;
        final rawRoute = streetRaw.isNotEmpty ? streetRaw : safeName;
        final effectiveRoute = _stripLeadingHouseNumberFromRoute(
          rawRoute: rawRoute,
          isFromFallbackName: streetRaw.isEmpty,
          userLeadingHouseNum: userLeadingHouseNum,
          houseNumRaw: houseNumRaw,
        );
        if (effectiveRoute.isEmpty && city.isEmpty) continue;
        // If user typed a street number (e.g. "800 enegy"), skip city-only features without a street/route name
        if (userLeadingHouseNum.isNotEmpty && effectiveRoute.isEmpty) continue;

        String streetAddress = '';
        if (effectiveHouseNum.isNotEmpty &&
            effectiveRoute.isNotEmpty &&
            !effectiveRoute.toLowerCase().startsWith('${effectiveHouseNum.toLowerCase()} ')) {
          streetAddress = '$effectiveHouseNum $effectiveRoute';
        } else if (effectiveRoute.isNotEmpty) {
          streetAddress = effectiveRoute;
        }

        final stateZip = [
          if (state.isNotEmpty) state,
          if (postalCode.isNotEmpty) postalCode,
        ].join(' ');
        final secondaryText = [
          if (city.isNotEmpty) city,
          if (stateZip.isNotEmpty) stateZip,
        ].join(', ');

        final mainText = streetAddress.isNotEmpty ? streetAddress : city;
        if (mainText.isEmpty) continue;

        final description = [
          mainText,
          if (extractedUnitOrApt.isNotEmpty) extractedUnitOrApt,
          if (secondaryText.isNotEmpty) secondaryText,
        ].join(', ');

        final dedupeKey = description.toLowerCase();
        if (!seenDescriptions.add(dedupeKey)) continue;

        double? lat;
        double? lng;
        final geom = feat['geometry'];
        if (geom is Map) {
          final coords = geom['coordinates'];
          if (coords is List && coords.length >= 2) {
            if (coords[0] is num) lng = (coords[0] as num).toDouble();
            if (coords[1] is num) lat = (coords[1] as num).toDouble();
          }
        }

        final placeId = 'photon:${osmType}_${osmId}_$i';
        _cachedDetailsByPlaceId[placeId] = ResolvedPlaceDetails(
          placeId: placeId,
          formattedAddress: description,
          streetAddress: streetAddress,
          unitOrApt: extractedUnitOrApt,
          city: city,
          state: state,
          postalCode: postalCode,
          latitude: lat,
          longitude: lng,
        );

        final prediction = PlacePrediction(
          placeId: placeId,
          description: description,
          mainText: mainText,
          secondaryText: secondaryText,
        );

        final isUs = countryCode == 'US' || (countryCode.isEmpty && state.length == 2);
        if (isUs) {
          usPredictions.add(prediction);
        } else {
          otherPredictions.add(prediction);
        }
      }

      return [...usPredictions, ...otherPredictions].take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Quaternary zero-key CORS-enabled fallback using OpenStreetMap Nominatim.
  /// Also supports 3-character prefix retry on last-word typos.
  static Future<List<PlacePrediction>> _fallbackNominatimPredictions(
    String query,
    http.Client client,
  ) async {
    final inline = extractInlineUnitOrApt(query);
    final effectiveQuery = inline.cleanedQuery;

    final directResults = await _queryNominatimEndpoint(
      effectiveQuery,
      originalUserQuery: effectiveQuery,
      extractedUnitOrApt: inline.unitOrApt,
      client: client,
    );
    if (directResults.isNotEmpty) {
      return directResults;
    }

    final retryQuery = _buildTypoPrefixRetryQuery(effectiveQuery);
    if (retryQuery != null) {
      return await _queryNominatimEndpoint(
        retryQuery,
        originalUserQuery: effectiveQuery,
        extractedUnitOrApt: inline.unitOrApt,
        client: client,
      );
    }

    return const [];
  }

  static Future<List<PlacePrediction>> _queryNominatimEndpoint(
    String searchQuery, {
    required String originalUserQuery,
    String extractedUnitOrApt = '',
    required http.Client client,
  }) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(searchQuery)}'
        '&format=jsonv2&addressdetails=1&limit=5',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final leadingNumMatch = _leadingHouseNumRegex.firstMatch(originalUserQuery.trim());
      final userLeadingHouseNum = leadingNumMatch?.group(1) ?? '';

      final predictions = <PlacePrediction>[];
      for (int i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) continue;

        final rawId = (item['place_id'] ?? i).toString();
        final address = item['address'] as Map? ?? const {};

        final houseNumRaw = (address['house_number'] ?? '').toString().trim();
        final rawItemName = (item['name'] ?? '').toString().trim();
        final safeItemName = RegExp(r'^\d+(?:-[0-9A-Za-z]+|[A-Za-z])?$').hasMatch(rawItemName) ? '' : rawItemName;
        final explicitRoad = (address['road'] ??
                address['pedestrian'] ??
                address['street'] ??
                '')
            .toString()
            .trim();
        final rawRoad = explicitRoad.isNotEmpty ? explicitRoad : safeItemName;
        final roadRaw = _stripLeadingHouseNumberFromRoute(
          rawRoute: rawRoad,
          isFromFallbackName: explicitRoad.isEmpty,
          userLeadingHouseNum: userLeadingHouseNum,
          houseNumRaw: houseNumRaw,
        );
        final city = (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['suburb'] ??
                address['county'] ??
                '')
            .toString()
            .trim();

        final isoState = (address['ISO3166-2-lvl4'] ?? '').toString().trim();
        final stateRaw = (address['state'] ?? '').toString().trim();
        final state = isoState.startsWith('US-') && isoState.length == 5
            ? isoState.substring(3)
            : _normalizeUsState(stateRaw);
        final postalCode = (address['postcode'] ?? '').toString().trim();

        final effectiveHouseNum = userLeadingHouseNum.isNotEmpty ? userLeadingHouseNum : houseNumRaw;
        String streetAddress = '';
        if (effectiveHouseNum.isNotEmpty &&
            roadRaw.isNotEmpty &&
            !roadRaw.toLowerCase().startsWith('${effectiveHouseNum.toLowerCase()} ')) {
          streetAddress = '$effectiveHouseNum $roadRaw';
        } else if (roadRaw.isNotEmpty) {
          streetAddress = roadRaw;
        } else {
          final displayName = (item['display_name'] ?? '').toString().trim();
          final firstPart = displayName.split(',').first.trim();
          if (!RegExp(r'^\d+(?:-[0-9A-Za-z]+|[A-Za-z])?$').hasMatch(firstPart)) {
            streetAddress = firstPart;
          }
        }
        if (streetAddress.isEmpty) continue;

        final stateZip = [
          if (state.isNotEmpty) state,
          if (postalCode.isNotEmpty) postalCode,
        ].join(' ');
        final secondaryText = [
          if (city.isNotEmpty) city,
          if (stateZip.isNotEmpty) stateZip,
        ].join(', ');

        final description = [
          streetAddress,
          if (extractedUnitOrApt.isNotEmpty) extractedUnitOrApt,
          if (secondaryText.isNotEmpty) secondaryText,
        ].join(', ');

        final lat = double.tryParse((item['lat'] ?? '').toString());
        final lng = double.tryParse((item['lon'] ?? '').toString());

        final placeId = 'nominatim:$rawId';
        _cachedDetailsByPlaceId[placeId] = ResolvedPlaceDetails(
          placeId: placeId,
          formattedAddress: description,
          streetAddress: streetAddress,
          unitOrApt: extractedUnitOrApt,
          city: city,
          state: state,
          postalCode: postalCode,
          latitude: lat,
          longitude: lng,
        );

        predictions.add(
          PlacePrediction(
            placeId: placeId,
            description: description,
            mainText: streetAddress,
            secondaryText: secondaryText,
          ),
        );
      }

      return predictions;
    } catch (_) {
      return const [];
    }
  }

  static String _normalizeUsState(String rawState) {
    final trimmed = rawState.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length == 2) return trimmed.toUpperCase();
    const map = <String, String>{
      'alabama': 'AL',
      'alaska': 'AK',
      'arizona': 'AZ',
      'arkansas': 'AR',
      'california': 'CA',
      'colorado': 'CO',
      'connecticut': 'CT',
      'delaware': 'DE',
      'district of columbia': 'DC',
      'florida': 'FL',
      'georgia': 'GA',
      'hawaii': 'HI',
      'idaho': 'ID',
      'illinois': 'IL',
      'indiana': 'IN',
      'iowa': 'IA',
      'kansas': 'KS',
      'kentucky': 'KY',
      'louisiana': 'LA',
      'maine': 'ME',
      'maryland': 'MD',
      'massachusetts': 'MA',
      'michigan': 'MI',
      'minnesota': 'MN',
      'mississippi': 'MS',
      'missouri': 'MO',
      'montana': 'MT',
      'nebraska': 'NE',
      'nevada': 'NV',
      'new hampshire': 'NH',
      'new jersey': 'NJ',
      'new mexico': 'NM',
      'new york': 'NY',
      'north carolina': 'NC',
      'north dakota': 'ND',
      'ohio': 'OH',
      'oklahoma': 'OK',
      'oregon': 'OR',
      'pennsylvania': 'PA',
      'rhode island': 'RI',
      'south carolina': 'SC',
      'south dakota': 'SD',
      'tennessee': 'TN',
      'texas': 'TX',
      'utah': 'UT',
      'vermont': 'VT',
      'virginia': 'VA',
      'washington': 'WA',
      'west virginia': 'WV',
      'wisconsin': 'WI',
      'wyoming': 'WY',
    };
    return map[trimmed.toLowerCase()] ?? trimmed;
  }
}
