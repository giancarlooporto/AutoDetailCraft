import '../../models/detail_job.dart';

class PaintInspectionOption {
  final int severity;
  final String label;
  final String shortLabel;
  final String description;

  const PaintInspectionOption({
    required this.severity,
    required this.label,
    required this.shortLabel,
    required this.description,
  });
}

class PaintGaugeOption {
  final String id;
  final String label;
  final String rangeLabel;
  final double defaultInitialMicrons;
  final double defaultFinalMicrons;
  final String status;
  final String badgeColorHex;

  const PaintGaugeOption({
    required this.id,
    required this.label,
    required this.rangeLabel,
    required this.defaultInitialMicrons,
    required this.defaultFinalMicrons,
    required this.status,
    required this.badgeColorHex,
  });
}

class StudioRecipePreset {
  final String id;
  final String name;
  final String serviceType;
  final String description;
  final List<RecipeStage> stages;

  const StudioRecipePreset({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.description,
    required this.stages,
  });
}

class DetailingPresets {
  // Simplified Defect Severity Options (1-Tap)
  static const List<PaintInspectionOption> defectSeverities = [
    PaintInspectionOption(
      severity: 3,
      label: 'Light Swirls',
      shortLabel: 'Light Swirls',
      description: 'Minor wash marring, towel scratches, light hazing',
    ),
    PaintInspectionOption(
      severity: 6,
      label: 'Moderate Defects',
      shortLabel: 'Moderate Defects',
      description: 'Standard swirl halos, medium scratch marks, water spots',
    ),
    PaintInspectionOption(
      severity: 8,
      label: 'Heavy Oxidation / RIDS',
      shortLabel: 'Heavy Oxidation / RIDS',
      description: 'Deep random scratches, sun fading, bird etching',
    ),
    PaintInspectionOption(
      severity: 10,
      label: 'Clear Coat Failure / Sanding',
      shortLabel: 'Clear Coat Failure',
      description: 'Severe micro-cracking, crow’s feet, 1000-grit wet sanding',
    ),
  ];

  // Simplified Paint Gauge / Depth Health Options (1-Tap)
  static const List<PaintGaugeOption> paintGaugePresets = [
    PaintGaugeOption(
      id: 'factory_healthy',
      label: 'Factory Healthy',
      rangeLabel: '100 - 140 µm',
      defaultInitialMicrons: 122.0,
      defaultFinalMicrons: 119.0,
      status: 'Healthy clear coat ready for compounding & multi-stage correction',
      badgeColorHex: '0xFF00E676', // hardnessHard / Green
    ),
    PaintGaugeOption(
      id: 'thin_clear',
      label: 'Thin Clear Coat',
      rangeLabel: '75 - 100 µm',
      defaultInitialMicrons: 86.0,
      defaultFinalMicrons: 84.5,
      status: 'Caution: Prior polishing history. Fine jeweling / finishing polish only',
      badgeColorHex: '0xFFFFD600', // hardnessMedium / Yellow
    ),
    PaintGaugeOption(
      id: 'repainted',
      label: 'Repainted / Inconsistent',
      rangeLabel: '> 200 µm',
      defaultInitialMicrons: 235.0,
      defaultFinalMicrons: 230.5,
      status: 'Body shop repaint / high mil thickness. Inspect for soft enamel & solvent pop',
      badgeColorHex: '0xFFFF5252', // hardnessSoft / Red
    ),
  ];

  // Quick-select Chip Options for Recipe Builder
  static const List<String> toolOptions = [
    'Rupes LHR15 Mark III (15mm)',
    'Rupes LHR21 Mark III (21mm)',
    'Rupes iBrid Nano (30mm/50mm)',
    'Flex XFE 7-15 150',
    'Flex PE 14-2 Rotary',
    'Shinemate EX620',
    'Maxshine M15 Pro',
    'Steamer / Tornador Blowout',
  ];

  static const List<String> padOptions = [
    'Lake Country Microfiber Cutting Pad',
    'Lake Country HDO Blue Foam Cutting',
    'Lake Country HDO Orange Polishing',
    'Rupes Yellow Fine Foam Pad',
    'Rupes Wool Cutting Pad',
    'Koch Chemie Heavy Cut Pad',
    'Sonax Fine Padded Polishing Pad',
    'CarPro Gloss Finishing Pad',
  ];

  static const List<String> compoundOptions = [
    'Koch Chemie Heavy Cut H9.02',
    'Koch Chemie Micro Cut M3.02',
    'Sonax Perfect Finish 04-06',
    'Menzerna Heavy Cut 400',
    '3D ONE Hybrid Compound & Polish',
    'Jescar Correcting Compound',
    'Scholl Concepts S20 Black',
    'CarPro ClearCut Compound',
  ];

  static const List<String> protectionOptions = [
    'Gtechniq Crystal Serum Ultra (9H)',
    'CarPro CQuartz UK 3.0',
    'Modesta BC-04 Nano-Titanium',
    'Kamikaze Miyabi Coat',
    'Gyeon Q2 Syncro EVO',
    'IGL Kenzo Graphene 10H',
    'Koch Chemie Ceramic Allround C0.02',
    'Jescar Power Lock Plus Sealant',
  ];

  // Quick 1-Tap Studio Recipe Presets
  static const List<StudioRecipePreset> recipePresets = [
    StudioRecipePreset(
      id: 'preset_1_stage',
      name: '1-Stage Gloss Enhancement',
      serviceType: 'Paint Correction',
      description: 'Single-step cut & finish to eliminate light swirls and boost 50%+ gloss in one efficient pass.',
      stages: [
        RecipeStage(
          stageName: '1. Chemical & Clay Decontamination',
          chemical: 'CarPro IronX & TarX + Fine Clay Towel',
          technique: 'Foam pre-soak, iron dissolution dwell 4 mins, mechanical clay towel glide with ONR lube',
          dilution: 'Neat',
          notes: 'Ensure panel is 100% free of bonded industrial fallout before machine touching paint',
        ),
        RecipeStage(
          stageName: '2. All-in-One Enhancement Polish',
          machine: 'Rupes LHR15 Mark III (15mm)',
          pad: 'Lake Country HDO Orange Polishing',
          chemical: '3D ONE Hybrid Compound & Polish',
          technique: '4 slow crosshatch passes @ speed 4 with light-to-moderate downward pressure',
          notes: 'Clean pad with compressed air every cycle. Delivers 70% correction with mirror gloss',
        ),
        RecipeStage(
          stageName: '3. Express Ceramic Sealant',
          chemical: 'CarPro Reload 2.0 SiO2 Spray Sealant',
          technique: 'Mist 2 sprays per panel, buff immediately with plush 450gsm microfiber towel',
          dilution: 'Neat',
          notes: 'Provides slick hydrophobic barrier lasting up to 6 months',
        ),
      ],
    ),
    StudioRecipePreset(
      id: 'preset_2_stage',
      name: '2-Stage Correction & Ceramic',
      serviceType: 'Ceramic Coating',
      description: 'Heavy compound cut + ultra-fine jeweling polish + dual-layer 9H pro ceramic coating.',
      stages: [
        RecipeStage(
          stageName: '1. Decontamination & Stripping Wash',
          chemical: 'Koch Chemie Green Star APC + CarPro IronX',
          technique: 'Foam pre-wash strip, iron fallout decontamination, fine synthetic clay bar',
          dilution: '1:10 Green Star',
          notes: 'Strip away all prior waxes, silicones, and road grime to gauge true paint condition',
        ),
        RecipeStage(
          stageName: '2. Stage 1 Heavy Compounding Cut',
          machine: 'Rupes LHR15 Mark III (15mm)',
          pad: 'Lake Country Microfiber Cutting Pad',
          chemical: 'Koch Chemie Heavy Cut H9.02',
          technique: '4-5 slow crosshatch passes @ speed 4.5, slow arm speed, panel wipe with IPA inspect',
          notes: 'Removes 85-92% of deep swirl marks, scratch marring, and chemical etchings',
        ),
        RecipeStage(
          stageName: '3. Stage 2 Fine Finishing Jeweling',
          machine: 'Rupes Duetto (12mm) or Flex XFE',
          pad: 'Rupes Yellow Fine Foam Pad',
          chemical: 'Sonax Perfect Finish 04-06',
          technique: '3 passes @ speed 3 with minimal downward pressure to jewel clear coat to optical clarity',
          notes: 'Eliminates all micro-marring and compounding haze for deep reflection',
        ),
        RecipeStage(
          stageName: '4. Signature 9H Ceramic Coating',
          chemical: 'Gtechniq Crystal Serum Ultra (9H) + EXO Top Coat',
          technique: 'Apply cross-hatch with foam applicator block, flash 1-2 mins, dual-towel level and buff',
          notes: 'IR heat cure 15 mins per panel or 12 hrs indoor cure before water exposure',
        ),
      ],
    ),
    StudioRecipePreset(
      id: 'preset_interior',
      name: 'Interior Deep Clean & Leather Shield',
      serviceType: 'Interior Deep Clean',
      description: 'Full concours interior extraction, steam sanitation, and ceramic leather balm protection.',
      stages: [
        RecipeStage(
          stageName: '1. Blowout & Dry Extraction',
          machine: 'Steamer / Tornador Blowout',
          chemical: 'Compressed air vortex + Hepa vacuum',
          technique: 'Blow out seat tracks, dashboard crevices, and carpets from top down before vacuuming',
          notes: 'Dislodges trapped sand and debris from deep foam cushions',
        ),
        RecipeStage(
          stageName: '2. Steam Sanitation & Fabric Extraction',
          machine: 'Commercial Hot Water Extractor',
          chemical: 'P&S Carpet Bomber & Terminator Enzyme',
          technique: 'Agitate with soft drill brush, steam sanitize AC vents, hot water rinse extraction',
          dilution: '1:8 Carpet Bomber',
          notes: 'Neutralizes bacteria, sweat, and embedded spill stains without over-saturating foam',
        ),
        RecipeStage(
          stageName: '3. Matte Leather & Plastic Ceramic Shield',
          chemical: 'Gtechniq I1 Smart Fabric + L1 Leather Shield',
          technique: 'Even wipe with foam applicator, buff off transfer with low-pile microfiber',
          dilution: 'Neat',
          notes: 'Leaves 100% matte OEM non-greasy finish with UV50+ sun protection and anti-dye transfer',
        ),
      ],
    ),
  ];
}
