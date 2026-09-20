import '../../models/detail_job.dart';

class PaintInspectionOption {
  final int severity;
  final DefectStage stage;
  final String label;
  final String shortLabel;
  final String description;

  const PaintInspectionOption({
    required this.severity,
    required this.stage,
    required this.label,
    required this.shortLabel,
    required this.description,
  });
}

class CorrectionPercentageOption {
  final int percentage;
  final String label;
  final String processLabel;
  final String recommendation;

  const CorrectionPercentageOption({
    required this.percentage,
    required this.label,
    required this.processLabel,
    required this.recommendation,
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
  // Industry Standard Defect Stages (IDA / Rupes / Meguiar's / Sonax Standard)
  static const List<PaintInspectionOption> defectSeverities = [
    PaintInspectionOption(
      severity: 1,
      stage: DefectStage.stage1,
      label: 'Stage 1: Light',
      shortLabel: 'Stage 1 Light',
      description: 'Wash Marring, Light Holograms/Spider-Webbing',
    ),
    PaintInspectionOption(
      severity: 2,
      stage: DefectStage.stage2,
      label: 'Stage 2: Moderate',
      shortLabel: 'Stage 2 Moderate',
      description: 'Swirl Marks, Light Water Spot/Etching',
    ),
    PaintInspectionOption(
      severity: 3,
      stage: DefectStage.stage3,
      label: 'Stage 3: Severe RIDS',
      shortLabel: 'Stage 3 Severe',
      description: 'RIDS (Random Isolated Deep Scratches), Heavy Oxidation',
    ),
    PaintInspectionOption(
      severity: 4,
      stage: DefectStage.stage4,
      label: 'Stage 4: Paint Failure',
      shortLabel: 'Stage 4 Failure',
      description: 'Crow\'s Feet, Clear Coat Peeling / Strike-Through',
    ),
  ];

  // Industry Standard Correction Percentages (%) - Simplified 3 Selections
  static const List<CorrectionPercentageOption> correctionPercentages = [
    CorrectionPercentageOption(
      percentage: 75,
      label: '75% Correction',
      processLabel: '1-Stage Enhancement',
      recommendation: 'Daily driver refresh. Removes light marring and swirls while preserving clear coat.',
    ),
    CorrectionPercentageOption(
      percentage: 85,
      label: '85% Correction',
      processLabel: '2-Stage Correction',
      recommendation: 'Sweet spot. Compound cut + fine jeweling polish eliminating 85%+ swirls.',
    ),
    CorrectionPercentageOption(
      percentage: 95,
      label: '95%+ Correction',
      processLabel: 'Concours Restoration',
      recommendation: 'Show car restoration. Multi-stage near-perfection while preserving safe paint boundaries.',
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
      label: 'Re-spray / Heavy',
      rangeLabel: '> 200 µm',
      defaultInitialMicrons: 235.0,
      defaultFinalMicrons: 230.5,
      status: 'Body shop repaint / high mil thickness. Inspect for soft enamel & solvent pop',
      badgeColorHex: '0xFFFF5252', // hardnessSoft / Red
    ),
  ];

  // Quick-select Chip Options for Recipe Builder (General / Polishing)
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

  // Interior-specific Recipe Chips
  static const List<String> interiorToolOptions = [
    'Commercial Hot Water Extractor',
    'Tornador Black Blowout Tool',
    'Optima Steamer SE',
    'Drill Brush Set (Soft/Medium)',
    'Ozone Generator Machine',
    'HEPA Detail Vacuum',
  ];

  static const List<String> interiorPadOptions = [
    'Scrub Ninja Interior Pad',
    'Horsehair Leather Brush',
    'Microfiber Extraction Mitt',
    'Foam Applicator Sponge',
    'Ultra-Soft Boar Hair Detail Brush',
    'Melamine Eraser Pad',
  ];

  static const List<String> interiorChemicalOptions = [
    'P&S Carpet Bomber & Terminator',
    'Koch Chemie Pol Star Leather/Textile',
    'Colourlock Mild Leather Cleaner',
    'P&S Xpress Interior Cleaner',
    'CarPro MultiX All Purpose Cleaner',
    'Meguiar\'s D101 APC',
  ];

  static const List<String> interiorProtectionOptions = [
    'Gtechniq L1 Leather Guard',
    'Gtechniq I1 Smart Fabric Shield',
    'CarPro CQuartz Fabric 2.0',
    'Koch Chemie Top Star Interior Matte',
    'Colourlock Leather Shield',
    '303 Aerospace UV Protectant',
  ];

  // PPF & Clear Bra Recipe Chips
  static const List<String> ppfToolOptions = [
    'Graphtec FC9000 Plotter Cut',
    'Steamer for Film Stretching',
    'Heat Gun Digital Temp',
    'Olfa 30-Degree Stainless Blade',
    'Pressurized Slip Spray Tank',
    'Tack Solution Hand Sprayer',
  ];

  static const List<String> ppfPadOptions = [
    'Fusion Red Squeegee (Firm)',
    'Yellow Turbo Squeegee',
    'Soft Green Contour Squeegee',
    'Clay Towel Fine Decon',
    'Microfiber Installation Glove',
    'Hard Card Teflon Edger',
  ];

  static const List<String> ppfChemicalOptions = [
    'XPEL Slip Solution Gel',
    'STEK Fusion Installation Gel',
    'Isopropyl Alcohol (IPA 15%) Tack',
    'Johnson\'s Baby Shampoo Slip',
    'XPEL Film Sealant & Polish',
    'CarPro Eraser Pre-Install Wipe',
  ];

  static const List<String> ppfProtectionOptions = [
    'XPEL Ultimate Plus 8mil (Self-Healing)',
    'STEK DYNOshield Hydrophobic Film',
    'SunTek Reaction Ceramic PPF',
    '3M Scotchgard Pro Series',
    'Gtechniq HALO Ceramic PPF Coating',
    'CarPro Skin PPF Ceramic Topcoat',
  ];

  // Gloss & Decon Wash Recipe Chips
  static const List<String> washToolOptions = [
    'MTM Hydro PF22.2 Foam Cannon',
    'Kranzle K1122TST Pressure Washer',
    'Detail Factory Ultra Soft Brushes',
    'BigBoi BlowR Mini Pro Car Dryer',
    'Wheel Woolies 3-Piece Set',
    'Grit Guard Dual-Bucket System',
  ];

  static const List<String> washPadOptions = [
    'CarPro Merino Wool Wash Mitt',
    'The Rag Company Cyclone Microfiber Mitt',
    'Microfiber Madness Incredipad',
    'Synthetic Clay Mitt / Towel',
    'Wheel Barrel Microfiber Wand',
    'Gauntlet 70/30 Twist Loop Towel',
  ];

  static const List<String> washChemicalOptions = [
    'Koch Chemie Green Star APC',
    'CarPro IronX Fallout Remover',
    'CarPro TarX Adhesive Dissolver',
    'Bilt Hamber Auto-Foam Touchless',
    'Koch Chemie Gsf Gentle Snow Foam',
    'Optimum No Rinse (ONR) Clay Lube',
  ];

  static const List<String> washProtectionOptions = [
    'CarPro Reload 2.0 SiO2 Spray',
    'Koch Chemie S0.02 Hydro Foam Sealant',
    'Gyeon Q2M WetCoat Hydrophobic',
    'Turtle Wax Hybrid Solutions Ceramic Spray',
    'Sonax Ceramic Ultra Slick Detailer',
    'P&S Bead Maker Paint Gloss',
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
    StudioRecipePreset(
      id: 'preset_ppf',
      name: 'Full Front PPF & Ceramic Topcoat',
      serviceType: 'PPF & Clear Bra',
      description: 'Precision computer-cut self-healing film installation with ceramic PPF slick topcoat.',
      stages: [
        RecipeStage(
          stageName: '1. Film Edge Prep & Slip Setup',
          machine: 'Graphtec FC9000 Plotter Cut',
          pad: 'Clay Towel Fine Decon',
          chemical: 'XPEL Slip Solution Gel',
          technique: 'Thorough edge degrease with 15% IPA tack, lubricate hood and fenders with slip gel',
          dilution: '1 oz per 32 oz water',
          notes: 'Ensure zero dust particles under film during float alignment',
        ),
        RecipeStage(
          stageName: '2. Film Squeegee Floating & Tacking',
          machine: 'Heat Gun Digital Temp',
          pad: 'Yellow Turbo Squeegee',
          chemical: 'STEK DYNOshield Hydrophobic Film',
          technique: 'Lock center seam, squeegee outward at 45-degree angle with firm overlapping strokes',
          notes: 'Wrap all rolled edges into panel crevices for seamless invisible finish',
        ),
        RecipeStage(
          stageName: '3. Ceramic PPF Protection Topcoat',
          chemical: 'Gtechniq HALO Ceramic PPF Coating',
          technique: 'Even crosshatch wipe with microfiber applicator pad, buff off after 2 minutes',
          dilution: 'Neat',
          notes: 'Prevents film yellowing, enhances water beading, and protects against bug splatter etch',
        ),
      ],
    ),
    StudioRecipePreset(
      id: 'preset_wash',
      name: 'Gloss & Decon Wash Protocol',
      serviceType: 'Gloss & Decon Wash',
      description: 'Touchless snow foam, chemical iron/tar decontamination, and SiO2 ceramic spray sealant.',
      stages: [
        RecipeStage(
          stageName: '1. Touchless Foam & Fallout Decon',
          machine: 'MTM Hydro PF22.2 Foam Cannon',
          pad: 'Wheel Barrel Microfiber Wand',
          chemical: 'Bilt Hamber Auto-Foam Touchless + CarPro IronX',
          technique: 'Pre-foam soak dwell 5 minutes, rinse 1500 PSI, apply iron fallout dissolver to paint and wheels',
          notes: 'Dissolves road grime and brake dust before contact wash',
        ),
        RecipeStage(
          stageName: '2. Two-Bucket Contact Wash & Clay Towel',
          machine: 'Grit Guard Dual-Bucket System',
          pad: 'CarPro Merino Wool Wash Mitt',
          chemical: 'Koch Chemie Gsf Gentle Snow Foam',
          technique: 'Straight-line contact wash top to bottom, clay towel lubricated with ONR',
          notes: 'Eliminates embedded grit to restore silky smooth paint surface',
        ),
        RecipeStage(
          stageName: '3. SiO2 Ceramic Spray Sealant Cure',
          machine: 'BigBoi BlowR Mini Pro Car Dryer',
          pad: 'Gauntlet 70/30 Twist Loop Towel',
          chemical: 'CarPro Reload 2.0 SiO2 Spray',
          technique: 'Blow dry crevices, mist 2 sprays per panel and buff with 450gsm plush microfiber',
          dilution: 'Neat',
          notes: '6 months hydrophobic protection with extreme gloss enhancement',
        ),
      ],
    ),
  ];
}
