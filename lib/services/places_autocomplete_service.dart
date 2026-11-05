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
  }

  /// Resets all mock providers back to live production behavior.
  static void resetMockProviders() {
    _mockAutocompleteProvider = null;
    _mockPlaceDetailsProvider = null;
    _mockHttpClient = null;
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
      // 2. Primary: Google Places API (New) Autocomplete
      final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final response = await client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
            },
            body: jsonEncode({
              'input': trimmed,
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

      // 3. Fallback: Google Geocoding API
      return await _fallbackGeocodePredictions(trimmed, apiKey, client);
    } catch (e) {
      if (kDebugMode) {
        print('[PlacesAutocompleteService] Autocomplete network fallback: $e');
      }
      return const [];
    } finally {
      if (_mockHttpClient == null) {
        client.close();
      }
    }
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

    final apiKey = SupabaseService.googleMapsApiKey.trim();
    if (apiKey.isEmpty) return null;

    final client = _mockHttpClient ?? http.Client();
    try {
      final cleanId = trimmedId.startsWith('places/')
          ? trimmedId.substring('places/'.length)
          : trimmedId;

      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places/${Uri.encodeComponent(cleanId)}'
        '?fields=id,formattedAddress,addressComponents,location'
        '&sessionToken=${Uri.encodeQueryComponent(sessionToken)}',
      );

      final response = await client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'id,formattedAddress,addressComponents,location',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return parsePlacesNewDetailsJson(decoded, fallbackPlaceId: cleanId);
        }
      }

      // Fallback to Geocoding API by place_id
      return await _fallbackGeocodePlaceDetails(cleanId, apiKey, client);
    } catch (e) {
      if (kDebugMode) {
        print('[PlacesAutocompleteService] Place details error: $e');
      }
      return null;
    } finally {
      if (_mockHttpClient == null) {
        client.close();
      }
    }
  }

  /// Parses a Google Places API (New) Place Details JSON payload into [ResolvedPlaceDetails].
  static ResolvedPlaceDetails parsePlacesNewDetailsJson(
    Map<String, dynamic> json, {
    String fallbackPlaceId = '',
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

    return ResolvedPlaceDetails(
      placeId: id,
      formattedAddress: formattedAddress,
      streetAddress: streetAddress,
      unitOrApt: subpremise,
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
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeQueryComponent(query)}'
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

        final parts = formatted.split(',');
        final mainText = parts.first.trim();
        final secondaryText = parts.length > 1 ? parts.skip(1).join(',').trim() : '';

        predictions.add(
          PlacePrediction(
            placeId: placeId,
            description: formatted,
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
    http.Client client,
  ) async {
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
      );
    } catch (_) {
      return null;
    }
  }
}
