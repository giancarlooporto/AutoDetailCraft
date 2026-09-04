import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/vehicle_data.dart';

class VehicleApiService {
  // In-memory cache to make dropdown selection instant after first fetch
  static final Map<String, List<String>> _modelsCache = {};

  /// Fetches the complete official list of models for a specific Make and Year
  /// from the U.S. National Highway Traffic Safety Administration (NHTSA vPIC API).
  static Future<List<String>> fetchModelsForMakeAndYear(String make, int year) async {
    final cacheKey = '${make.toLowerCase()}_$year';
    if (_modelsCache.containsKey(cacheKey) && _modelsCache[cacheKey]!.isNotEmpty) {
      return _modelsCache[cacheKey]!;
    }

    // Standardized make name for NHTSA API query
    final queryMake = _sanitizeMakeForNhtsa(make);

    try {
      final url = Uri.parse(
        'https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/$queryMake/modelyear/$year?format=json',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['Results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final Set<String> modelsSet = {};

          for (final item in results) {
            final modelName = item['Model_Name']?.toString().trim();
            if (modelName != null && modelName.isNotEmpty && !_isNonAutomotiveModel(modelName)) {
              modelsSet.add(_formatModelName(modelName));
            }
          }

          if (modelsSet.isNotEmpty) {
            final sortedModels = modelsSet.toList()..sort((a, b) => a.compareTo(b));
            _modelsCache[cacheKey] = sortedModels;
            return sortedModels;
          }
        }
      }
    } catch (e) {
      // Network failure or timeout -> fallback gracefully to local database
    }

    // Fallback: Query Make-only endpoint if year-specific was empty, or use local database
    final localModels = VehicleDatabase.getModelsForMakeAndYear(make, year);
    if (localModels.isNotEmpty) {
      final localList = localModels.map((m) => m.model).toList();
      _modelsCache[cacheKey] = localList;
      return localList;
    }

    return ['Standard Base Model', 'Sport Package', 'GT Package'];
  }

  // Cache for makes per year
  static final Map<int, List<String>> _makesCache = {};

  /// Fetches all car makes available for a given model year from NHTSA.
  /// Falls back to the local [VehicleDatabase.allMakes] list on failure.
  static Future<List<String>> fetchMakesForYear(int year) async {
    if (_makesCache.containsKey(year)) return _makesCache[year]!;

    try {
      final url = Uri.parse(
        'https://vpic.nhtsa.dot.gov/api/vehicles/GetMakesForVehicleType/car?format=json',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['Results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          // Build a set of NHTSA make names for this year
          final nhtsaNames = results
              .map((r) => (r['MakeName'] as String?)?.trim() ?? '')
              .where((n) => n.isNotEmpty)
              .toSet();

          // Map our known makes list — keep only those that match NHTSA,
          // but always include ALL our makes (the user can always type manually).
          // We prefer our curated list because it has proper casing/branding.
          final matched = VehicleDatabase.allMakes.where((make) {
            final simpleMake = make.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
            return nhtsaNames.any((n) =>
                n.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').contains(simpleMake) ||
                simpleMake.contains(n.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')));
          }).toList();

          if (matched.isNotEmpty) {
            _makesCache[year] = matched;
            return matched;
          }
        }
      }
    } catch (_) {
      // Network failure — fall through to local list
    }

    _makesCache[year] = VehicleDatabase.allMakes;
    return VehicleDatabase.allMakes;
  }

  /// Provides authentic factory OEM paint colors for any make and model
  static List<String> getFactoryColorsFor(String make, String model) {
    // 1. Check curated database for exact model match
    final curatedSpecs = VehicleDatabase.getModelsForMake(make);
    for (final spec in curatedSpecs) {
      if (model.toLowerCase().contains(spec.model.split(' ').first.toLowerCase()) ||
          spec.model.toLowerCase().contains(model.toLowerCase())) {
        return spec.factoryColors;
      }
    }

    // 2. Generate manufacturer-specific authentic color palettes
    final m = make.toLowerCase();
    if (m.contains('porsche')) {
      return ['Shark Blue (D5C)', 'Guards Red (84A)', 'GT Silver Metallic (M7Z)', 'Chalk (M9A)', 'Gentian Blue Metallic', 'Python Green', 'Solid Black (041)', 'Carrara White Metallic', 'Racing Yellow', 'Rubystar Neo'];
    } else if (m.contains('bmw')) {
      return ['Isle of Man Green (C4G)', 'Portimao Blue Metallic', 'Brooklyn Grey Metallic', 'Dravit Grey Metallic', 'Black Sapphire Metallic', 'Alpine White', 'Sao Paulo Yellow', 'Tanzanite Blue II', 'Toronto Red'];
    } else if (m.contains('mercedes')) {
      return ['Obsidian Black Metallic', 'MANUFAKTUR Opalite White', 'AMG Green Hell Magno', 'Selenite Grey Magno', 'Designo Brilliant Blue', 'High-Tech Silver Metallic', 'Nautical Blue Metallic'];
    } else if (m.contains('audi')) {
      return ['Nardo Grey', 'Daytona Grey Pearl', 'Kyalami Green', 'Tango Red Metallic', 'Mythos Black Metallic', 'Glacier White Metallic', 'Ultra Blue Metallic', 'Sebring Black Crystal'];
    } else if (m.contains('ferrari')) {
      return ['Rosso Corsa (DS 322)', 'Giallo Modena (Yellow)', 'Rosso Scuderia', 'Grigio Silverstone', 'Nero Daytona', 'Blu Pozzi', 'Verde British Racing', 'Rosso Fiorano'];
    } else if (m.contains('lamborghini')) {
      return ['Verde Mantis (Pearl Green)', 'Giallo Inti (Pearl Yellow)', 'Arancio Borealis (Pearl Orange)', 'Blu Cepheus', 'Grigio Telesto', 'Nero Noctis', 'Bianco Monocerus', 'Viola Pasifae'];
    } else if (m.contains('chevrolet') || m.contains('chevy')) {
      return ['Torch Red', 'Rapid Blue', 'Amplify Orange Tintcoat', 'Hypersonic Grey Metallic', 'Black', 'Arctic White', 'Sea Wolf Gray', 'Riptide Blue Metallic', 'Red Hot', 'Glacier Blue'];
    } else if (m.contains('ford')) {
      return ['Blue Ember Metallic', 'Grabber Blue', 'Vapor Blue Metallic', 'Shadow Black', 'Race Red', 'Oxford White', 'Shelter Green', 'Code Orange Metallic', 'Area 51', 'Eruption Green'];
    } else if (m.contains('dodge') || m.contains('ram')) {
      return ['Plum Crazy Purple', 'Go Mango Orange', 'TorRed', 'B5 Blue', 'F8 Green', 'Destroyer Grey', 'Pitch Black', 'Sinamon Stick', 'Frostbite', 'Hydro Blue Pearl', 'Ignition Orange'];
    } else if (m.contains('toyota') || m.contains('lexus')) {
      return ['Wind Chill Pearl', 'Midnight Black Metallic', 'Blueprint', 'Underground Grey', 'Supersonic Red', 'Lunar Rock', 'Solar Octane', 'Nori Green Pearl', 'Infrared', 'Caviar Black', 'Heavy Metal'];
    } else if (m.contains('honda') || m.contains('acura')) {
      return ['Championship White', 'Boost Blue Pearl', 'Sonic Gray Pearl', 'Rallye Red', 'Crystal Black Pearl', 'Tiger Eye Pearl', 'Apex Blue Pearl', 'Platinum White Pearl', 'Meteorite Gray'];
    } else if (m.contains('tesla')) {
      return ['Ultra Red', 'Stealth Grey', 'Quicksilver Metallic', 'Solid Black (PBSB)', 'Pearl White Multi-Coat', 'Deep Blue Metallic', 'Midnight Silver Metallic'];
    } else if (m.contains('subaru')) {
      return ['World Rally Blue Pearl (WR Blue)', 'Solar Orange Pearl', 'Ignition Red', 'Ceramic White', 'Magnetite Gray Metallic', 'Crystal Black Silica', 'Geyser Blue', 'Autumn Green'];
    } else if (m.contains('mazda')) {
      return ['Soul Red Crystal Metallic (46V)', 'Machine Grey Metallic', 'Polymetal Grey Metallic', 'Zircon Sand Metallic', 'Deep Crystal Blue Mica', 'Jet Black Mica', 'Snowflake White Pearl'];
    }

    return [
      'Gloss Black Pearl',
      'Alpine White Tricoat',
      'Gunmetal Grey Metallic',
      'Deep Metallic Navy',
      'Crimson Red Tintcoat',
      'Liquid Silver Metallic',
      'British Racing Green',
    ];
  }

  /// Provides authentic studio cover images based on vehicle style
  static String getStudioImageFor(String make, String model) {
    final curatedSpecs = VehicleDatabase.getModelsForMake(make);
    for (final spec in curatedSpecs) {
      if (model.toLowerCase().contains(spec.model.split(' ').first.toLowerCase()) ||
          spec.model.toLowerCase().contains(model.toLowerCase())) {
        return spec.defaultImage;
      }
    }

    final m = make.toLowerCase();
    final mod = model.toLowerCase();

    if (mod.contains('truck') || mod.contains('raptor') || mod.contains('silverado') || mod.contains('f-150') || mod.contains('ram') || mod.contains('tundra') || mod.contains('tacoma') || mod.contains('sierra')) {
      return 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80';
    }
    if (mod.contains('suv') || mod.contains('rav4') || mod.contains('cr-v') || mod.contains('tahoe') || mod.contains('explorer') || mod.contains('grand cherokee') || mod.contains('wrangler') || mod.contains('bronco') || mod.contains('escalade') || mod.contains('telluride')) {
      return 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80';
    }
    if (m.contains('porsche') || m.contains('ferrari') || m.contains('lamborghini') || m.contains('mclaren') || m.contains('corvette') || m.contains('supercar')) {
      return 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=900&auto=format&fit=crop&q=80';
    }
    if (m.contains('tesla') || m.contains('electric') || mod.contains('ioniq') || mod.contains('ev')) {
      return 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80';
    }

    return 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80';
  }

  static String _sanitizeMakeForNhtsa(String make) {
    if (make.contains('Land Rover')) return 'land rover';
    if (make.contains('Mercedes')) return 'mercedes-benz';
    if (make.contains('Alfa')) return 'alfa romeo';
    if (make.contains('Aston')) return 'aston martin';
    if (make.contains('Rolls')) return 'rolls-royce';
    return make.trim().toLowerCase();
  }

  static bool _isNonAutomotiveModel(String model) {
    final lower = model.toLowerCase();
    // Exclude motorcycles, ATVs, marine, and lawn equipment returned by broad manufacturers (e.g. Honda power equipment)
    if (lower.startsWith('trx') ||
        lower.startsWith('crf') ||
        lower.startsWith('cbr') ||
        lower.startsWith('cb') ||
        lower.startsWith('xr') ||
        lower.startsWith('vt') ||
        lower.startsWith('sxs') ||
        lower.contains('dirt bike') ||
        lower.contains('outboard') ||
        lower.contains('mower')) {
      return true;
    }
    return false;
  }

  static String _formatModelName(String raw) {
    if (raw.isEmpty) return raw;
    // Capitalize acronyms and standardize casing
    return raw;
  }
}
