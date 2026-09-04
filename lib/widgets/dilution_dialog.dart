import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dilution_calculator.dart';

class DilutionDialog extends StatefulWidget {
  const DilutionDialog({super.key});

  @override
  State<DilutionDialog> createState() => _DilutionDialogState();
}

class _DilutionDialogState extends State<DilutionDialog> {
  VolumeUnit _unit = VolumeUnit.flOz;
  double _totalVolume = 32.0; // 32 oz spray bottle default
  final double _chemicalParts = 1.0;
  double _waterParts = 10.0; // 1:10 default

  final List<double> _ozPresets = [16.0, 32.0, 64.0, 128.0];
  final List<double> _mlPresets = [500.0, 750.0, 1000.0, 3785.0];

  final Map<String, double> _ratioPresets = {
    '1:4 (Engine / Degrease)': 4.0,
    '1:10 (Wheels / Tires)': 10.0,
    '1:15 (Medium Interior)': 15.0,
    '1:20 (Delicate Leather)': 20.0,
    '1:30 (Light Dust Wipe)': 30.0,
    '1:128 (Rinseless / Clay)': 128.0,
    '1:256 (High Concentrate)': 256.0,
  };

  @override
  Widget build(BuildContext context) {
    final result = DilutionCalculator.calculate(
      totalVolume: _totalVolume,
      chemicalParts: _chemicalParts,
      waterParts: _waterParts,
      unit: _unit,
    );

    final chemPercentage = (result.chemicalAmount / result.totalVolume).clamp(0.0, 1.0);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dilution Calculator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Precision chemical mixing cheat sheet',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Unit Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Volume Unit',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13),
                  ),
                  SegmentedButton<VolumeUnit>(
                    segments: const [
                      ButtonSegment(value: VolumeUnit.flOz, label: Text('Fluid Oz (oz)')),
                      ButtonSegment(value: VolumeUnit.ml, label: Text('Milliliters (ml)')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (set) {
                      setState(() {
                        _unit = set.first;
                        _totalVolume = _unit == VolumeUnit.flOz ? 32.0 : 1000.0;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primary.withAlpha(40);
                        }
                        return AppTheme.surfaceLight;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primary;
                        }
                        return AppTheme.textSecondary;
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Bottle Volume Presets
              Text(
                'Target Bottle Size: ${_totalVolume.toStringAsFixed(0)} ${_unit == VolumeUnit.flOz ? 'oz' : 'ml'}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (_unit == VolumeUnit.flOz ? _ozPresets : _mlPresets).map((val) {
                  final isSelected = _totalVolume == val;
                  return ChoiceChip(
                    label: Text('${val.toStringAsFixed(0)} ${_unit == VolumeUnit.flOz ? 'oz' : 'ml'}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _totalVolume = val);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Ratio Preset Selector
              const Text(
                'Ratio (Chemical : Water)',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<double>(
                initialValue: _waterParts,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                dropdownColor: AppTheme.surfaceLight,
                items: _ratioPresets.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.value,
                    child: Text(e.key, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _waterParts = val);
                },
              ),

              const SizedBox(height: 18),

              // Visual Bottle Result Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withAlpha(100), width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Visual Bottle Meter
                        Container(
                          width: 44,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border, width: 2),
                            color: AppTheme.surfaceLight,
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Water portion (Blue)
                              Container(
                                width: double.infinity,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1976D2),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                                ),
                              ),
                              // Chemical portion (Neon Cyan/Amber at bottom)
                              Container(
                                width: double.infinity,
                                height: (100 * chemPercentage).clamp(6.0, 100.0),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Result Measurements
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chemical Amount
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Chemical Concentrate:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 18),
                                child: Text(
                                  result.chemicalDisplay,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Water Amount
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1976D2),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Water / Distilled:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 18),
                                child: Text(
                                  result.waterDisplay,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64B5F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tip: Always pour water into bottle first, then add concentrate to prevent excessive foaming.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
