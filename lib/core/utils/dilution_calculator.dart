enum VolumeUnit { flOz, ml }

class DilutionResult {
  final double totalVolume;
  final double chemicalParts;
  final double waterParts;
  final double chemicalAmount;
  final double waterAmount;
  final VolumeUnit unit;

  const DilutionResult({
    required this.totalVolume,
    required this.chemicalParts,
    required this.waterParts,
    required this.chemicalAmount,
    required this.waterAmount,
    required this.unit,
  });

  String get chemicalDisplay {
    final unitStr = unit == VolumeUnit.flOz ? 'oz' : 'ml';
    return '${chemicalAmount.toStringAsFixed(1)} $unitStr';
  }

  String get waterDisplay {
    final unitStr = unit == VolumeUnit.flOz ? 'oz' : 'ml';
    return '${waterAmount.toStringAsFixed(1)} $unitStr';
  }
}

class DilutionCalculator {
  /// Calculates the exact chemical vs water amount given total volume and ratio (e.g. 1:10 -> chem: 1, water: 10)
  static DilutionResult calculate({
    required double totalVolume,
    required double chemicalParts,
    required double waterParts,
    required VolumeUnit unit,
  }) {
    if (totalVolume <= 0 || chemicalParts <= 0 || waterParts <= 0) {
      return DilutionResult(
        totalVolume: totalVolume,
        chemicalParts: chemicalParts,
        waterParts: waterParts,
        chemicalAmount: 0,
        waterAmount: 0,
        unit: unit,
      );
    }

    final totalParts = chemicalParts + waterParts;
    final chemicalAmount = (chemicalParts / totalParts) * totalVolume;
    final waterAmount = totalVolume - chemicalAmount;

    return DilutionResult(
      totalVolume: totalVolume,
      chemicalParts: chemicalParts,
      waterParts: waterParts,
      chemicalAmount: chemicalAmount,
      waterAmount: waterAmount,
      unit: unit,
    );
  }

  /// Parses a string ratio like '1:10' or '1:4' into parts
  static Map<String, double>? parseRatio(String ratioStr) {
    try {
      final clean = ratioStr.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = clean.split(':');
      if (parts.length == 2) {
        final chem = double.tryParse(parts[0]) ?? 1.0;
        final water = double.tryParse(parts[1]) ?? 10.0;
        return {'chemical': chem, 'water': water};
      }
    } catch (_) {}
    return null;
  }
}
