import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/core/utils/dilution_calculator.dart';

void main() {
  group('DilutionCalculator Tests', () {
    test('Calculates 1:10 ratio for 32 fl oz bottle correctly', () {
      // 1 part chemical + 10 parts water = 11 parts total
      // 32 oz / 11 = 2.909 oz chemical, 29.091 oz water
      final result = DilutionCalculator.calculate(
        totalVolume: 32.0,
        chemicalParts: 1.0,
        waterParts: 10.0,
        unit: VolumeUnit.flOz,
      );

      expect(result.chemicalAmount, closeTo(2.91, 0.05));
      expect(result.waterAmount, closeTo(29.09, 0.05));
      expect(result.chemicalAmount + result.waterAmount, closeTo(32.0, 0.001));
    });

    test('Calculates 1:4 ratio for 1000 ml bottle correctly', () {
      // 1 part chemical + 4 parts water = 5 parts total
      // 1000 ml / 5 = 200 ml chemical, 800 ml water
      final result = DilutionCalculator.calculate(
        totalVolume: 1000.0,
        chemicalParts: 1.0,
        waterParts: 4.0,
        unit: VolumeUnit.ml,
      );

      expect(result.chemicalAmount, equals(200.0));
      expect(result.waterAmount, equals(800.0));
    });

    test('Parses string ratios correctly', () {
      final parsed10 = DilutionCalculator.parseRatio('1:10');
      expect(parsed10?['chemical'], equals(1.0));
      expect(parsed10?['water'], equals(10.0));

      final parsed128 = DilutionCalculator.parseRatio('1:128 (Rinseless)');
      expect(parsed128?['chemical'], equals(1.0));
      expect(parsed128?['water'], equals(128.0));
    });
  });
}
