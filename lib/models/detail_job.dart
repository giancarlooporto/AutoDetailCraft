import 'user_profile.dart';
import 'paint_gauge_point.dart';

enum DefectStage {
  stage1('Stage 1: Light', 'Wash Marring, Light Holograms/Spider-Webbing', 1),
  stage2('Stage 2: Moderate', 'Swirl Marks, Light Water Spot/Etching', 2),
  stage3('Stage 3: Severe RIDS', 'RIDS - Deep Scratches, Heavy Oxidation', 3),
  stage4('Stage 4: Paint Failure', 'Crow\'s Feet, Clear Coat Peeling / Strike-Through', 4);

  final String label;
  final String description;
  final int stageNumber;
  const DefectStage(this.label, this.description, this.stageNumber);

  String get shortLabel {
    switch (this) {
      case DefectStage.stage1:
        return 'Stage 1 Light';
      case DefectStage.stage2:
        return 'Stage 2 Moderate';
      case DefectStage.stage3:
        return 'Stage 3 Severe';
      case DefectStage.stage4:
        return 'Stage 4 Failure';
    }
  }

  static DefectStage fromStageNumber(int stage) {
    switch (stage) {
      case 1:
        return DefectStage.stage1;
      case 2:
        return DefectStage.stage2;
      case 3:
        return DefectStage.stage3;
      case 4:
        return DefectStage.stage4;
      default:
        if (stage <= 3) return DefectStage.stage1;
        if (stage <= 6) return DefectStage.stage2;
        if (stage <= 8) return DefectStage.stage3;
        return DefectStage.stage4;
    }
  }

  static DefectStage fromString(String? name) {
    if (name == null) return DefectStage.stage2;
    for (final val in DefectStage.values) {
      if (val.name.toLowerCase() == name.toLowerCase()) return val;
    }
    // Handle numeric strings e.g. "1", "2"
    final num = int.tryParse(name);
    if (num != null) return fromStageNumber(num);
    return DefectStage.stage2;
  }
}

enum PaintHardness {
  soft('Soft (Tesla, Subaru, Mazda)'),
  medium('Medium (Ford, Chevy, Toyota)'),
  hard('Hard (Porsche, BMW, Audi, Mercedes)'),
  singleStage('Single Stage Vintage Enamel');

  final String label;
  const PaintHardness(this.label);
}

class RecipeStage {
  final String stageName; // e.g. 'Chemical Decon', 'Compounding / Cut', 'Finishing Polish', 'Ceramic Protection'
  final String machine;   // e.g. 'Rupes LHR15 Mark III (15mm throw)'
  final String pad;       // e.g. 'Lake Country Microfiber Cutting Pad'
  final String chemical;  // e.g. 'Koch Chemie Heavy Cut H9.02'
  final String technique; // e.g. '4 crosshatch passes @ speed 4.5, moderate downward pressure'
  final String? dilution; // e.g. '1:10 dilution' or 'Neat'
  final String? notes;    // e.g. 'Wipe off with 400gsm edgeless microfiber + 15% IPA wipe'

  const RecipeStage({
    required this.stageName,
    this.machine = '',
    this.pad = '',
    required this.chemical,
    this.technique = '',
    this.dilution,
    this.notes,
  });

  RecipeStage copyWith({
    String? stageName,
    String? machine,
    String? pad,
    String? chemical,
    String? technique,
    String? dilution,
    String? notes,
  }) => RecipeStage(
    stageName: stageName ?? this.stageName,
    machine: machine ?? this.machine,
    pad: pad ?? this.pad,
    chemical: chemical ?? this.chemical,
    technique: technique ?? this.technique,
    dilution: dilution ?? this.dilution,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'stageName': stageName,
    'machine': machine,
    'pad': pad,
    'chemical': chemical,
    'technique': technique,
    'dilution': dilution,
    'notes': notes,
  };

  factory RecipeStage.fromJson(Map<String, dynamic> json) => RecipeStage(
    stageName: json['stageName'] as String? ?? 'Stage',
    machine: json['machine'] as String? ?? '',
    pad: json['pad'] as String? ?? '',
    chemical: json['chemical'] as String? ?? '',
    technique: json['technique'] as String? ?? '',
    dilution: json['dilution'] as String?,
    notes: json['notes'] as String?,
  );
}

class JobComment {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String text;
  final DateTime createdAt;
  final bool isVerifiedPro;
  final String? parentId;
  final String? replyToAuthorName;

  const JobComment({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.createdAt,
    this.isVerifiedPro = false,
    this.parentId,
    this.replyToAuthorName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'isVerifiedPro': isVerifiedPro,
    if (parentId != null) 'parentId': parentId,
    if (replyToAuthorName != null) 'replyToAuthorName': replyToAuthorName,
  };

  factory JobComment.fromJson(Map<String, dynamic> json) => JobComment(
    id: json['id'] as String? ?? 'cmt_${DateTime.now().millisecondsSinceEpoch}',
    authorName: json['authorName'] as String? ?? 'Anonymous',
    authorAvatar: json['authorAvatar'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isVerifiedPro: json['isVerifiedPro'] as bool? ?? false,
    parentId: json['parentId'] as String?,
    replyToAuthorName: json['replyToAuthorName'] as String?,
  );
}

class JobMediaZone {
  final String id;
  final String zoneName; // e.g. 'Front / Hood', 'Driver Side / Doors', 'Rear / Bumper', 'Wheels & Calipers', 'Interior / Leather'
  final String beforeImageUrl;
  final String afterImageUrl;
  final String? defectBadge;
  final double? initialMicrons;
  final double? finalMicrons;

  const JobMediaZone({
    required this.id,
    required this.zoneName,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.defectBadge,
    this.initialMicrons,
    this.finalMicrons,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'zoneName': zoneName,
    'beforeImageUrl': beforeImageUrl,
    'afterImageUrl': afterImageUrl,
    'defectBadge': defectBadge,
    'initialMicrons': initialMicrons,
    'finalMicrons': finalMicrons,
  };

  factory JobMediaZone.fromJson(Map<String, dynamic> json) => JobMediaZone(
    id: json['id'] as String? ?? 'zone_1',
    zoneName: json['zoneName'] as String? ?? 'Front / Hood',
    beforeImageUrl: json['beforeImageUrl'] as String? ?? '',
    afterImageUrl: json['afterImageUrl'] as String? ?? '',
    defectBadge: json['defectBadge'] as String?,
    initialMicrons: (json['initialMicrons'] as num?)?.toDouble(),
    finalMicrons: (json['finalMicrons'] as num?)?.toDouble(),
  );
}

class DetailJob {
  final String id;
  final UserProfile author;
  final DateTime createdAt;
  final String title;
  final String description;
  
  // Vehicle details
  final int vehicleYear;
  final String vehicleMake;
  final String vehicleModel;
  final String paintColorName;
  final String paintCode;
  final PaintHardness paintHardness;
  
  // Paint inspection metrics
  final double initialPaintThicknessMicrons;
  final double finalPaintThicknessMicrons;
  final List<PaintGaugePoint> paintGaugePoints;
  final int defectSeverity; // Legacy numeric stage (1 to 4)
  final DefectStage defectStage; // Industry standard defect stage
  final int correctionPercentage; // e.g. 70%, 80%, 85%, 90%, 95%
  final String serviceType;
  
  // Recipe
  final List<RecipeStage> recipeStages;
  
  // Media for 50/50 Slider (Primary Hero Pair)
  final String beforeImageUrl;
  final String afterImageUrl;
  final String defectBadge; // e.g. 'Stage 2 Moderate Defects', 'Stage 3 Severe RIDS'

  // Full Inspection Photo Containers
  final List<String> beforePhotos;
  final List<String> afterPhotos;

  // Multi-Zone Guided Before & After Media (Backward compatibility)
  final List<JobMediaZone> mediaZones;
  
  // Business metrics
  final double durationHours;
  final double? quotedPrice;
  
  // Social metrics
  final int likesCount;
  final bool isLiked;
  final int savesCount;
  final bool isSaved;
  final List<JobComment> comments;

  DetailJob({
    required this.id,
    required this.author,
    required this.createdAt,
    required this.title,
    required this.description,
    required this.vehicleYear,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.paintColorName,
    required this.paintCode,
    required this.paintHardness,
    required this.initialPaintThicknessMicrons,
    required this.finalPaintThicknessMicrons,
    List<PaintGaugePoint>? paintGaugePoints,
    required this.defectSeverity,
    DefectStage? defectStage,
    this.correctionPercentage = 85,
    required this.serviceType,
    required this.recipeStages,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.defectBadge = 'Stage 2: Moderate (Swirl Marks)',
    this.beforePhotos = const [],
    this.afterPhotos = const [],
    this.mediaZones = const [],
    this.durationHours = 8.0,
    this.quotedPrice,
    this.likesCount = 0,
    this.isLiked = false,
    this.savesCount = 0,
    this.isSaved = false,
    this.comments = const [],
  }) : paintGaugePoints = paintGaugePoints != null && paintGaugePoints.isNotEmpty
            ? paintGaugePoints
            : PaintGaugePoint.default8Points(initial: initialPaintThicknessMicrons, post: finalPaintThicknessMicrons),
       defectStage = defectStage ??
            (defectSeverity <= 1
                ? DefectStage.stage1
                : defectSeverity == 2
                    ? DefectStage.stage2
                    : defectSeverity == 3
                        ? DefectStage.stage3
                        : defectSeverity == 4
                            ? DefectStage.stage4
                            : defectSeverity <= 6
                                ? DefectStage.stage2
                                : defectSeverity <= 8
                                    ? DefectStage.stage3
                                    : DefectStage.stage4);

  double get overallInitialAverage => paintGaugePoints.isNotEmpty
      ? paintGaugePoints.map((p) => p.initialMicrons).reduce((a, b) => a + b) / paintGaugePoints.length
      : initialPaintThicknessMicrons;

  double get overallPostPolishAverage => paintGaugePoints.isNotEmpty
      ? paintGaugePoints.map((p) => p.postPolishMicrons).reduce((a, b) => a + b) / paintGaugePoints.length
      : finalPaintThicknessMicrons;

  double get micronsRemoved => (overallInitialAverage - overallPostPolishAverage).clamp(0.0, 99.0);

  String get vehicleFullName => '$vehicleYear $vehicleMake $vehicleModel';

  /// Formatted defect summary string according to detailing industry standard
  String get defectStageLabel => defectStage.label;

  /// Correction achieved percentage badge string e.g. '85% Correction'
  String get correctionPercentageLabel => '$correctionPercentage% Correction';

  /// All before photos, guaranteeing at least the hero before image is included.
  List<String> get allBeforePhotos {
    if (beforePhotos.isNotEmpty) return beforePhotos;
    if (beforeImageUrl.isNotEmpty) return [beforeImageUrl];
    return const [];
  }

  /// All after photos, guaranteeing at least the hero after image is included.
  List<String> get allAfterPhotos {
    if (afterPhotos.isNotEmpty) return afterPhotos;
    if (afterImageUrl.isNotEmpty) return [afterImageUrl];
    return const [];
  }

  /// Returns media zones, falling back to a default zone from before/after URLs if mediaZones is empty.
  List<JobMediaZone> get effectiveMediaZones {
    if (mediaZones.isNotEmpty) return mediaZones;
    if (beforeImageUrl.isNotEmpty || afterImageUrl.isNotEmpty) {
      return [
        JobMediaZone(
          id: 'hero_zone',
          zoneName: 'Main',
          beforeImageUrl: beforeImageUrl,
          afterImageUrl: afterImageUrl,
          defectBadge: defectBadge,
          initialMicrons: initialPaintThicknessMicrons,
          finalMicrons: finalPaintThicknessMicrons,
        ),
      ];
    }
    return const [];
  }

  DetailJob copyWith({
    String? id,
    UserProfile? author,
    DateTime? createdAt,
    String? title,
    String? description,
    int? vehicleYear,
    String? vehicleMake,
    String? vehicleModel,
    String? paintColorName,
    String? paintCode,
    PaintHardness? paintHardness,
    double? initialPaintThicknessMicrons,
    double? finalPaintThicknessMicrons,
    List<PaintGaugePoint>? paintGaugePoints,
    int? defectSeverity,
    DefectStage? defectStage,
    int? correctionPercentage,
    String? serviceType,
    List<RecipeStage>? recipeStages,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? defectBadge,
    List<String>? beforePhotos,
    List<String>? afterPhotos,
    List<JobMediaZone>? mediaZones,
    double? durationHours,
    double? quotedPrice,
    int? likesCount,
    bool? isLiked,
    int? savesCount,
    bool? isSaved,
    List<JobComment>? comments,
  }) {
    final newDefectStage = defectStage ?? (defectSeverity != null ? DefectStage.fromStageNumber(defectSeverity) : this.defectStage);
    return DetailJob(
      id: id ?? this.id,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      paintColorName: paintColorName ?? this.paintColorName,
      paintCode: paintCode ?? this.paintCode,
      paintHardness: paintHardness ?? this.paintHardness,
      initialPaintThicknessMicrons: initialPaintThicknessMicrons ?? this.initialPaintThicknessMicrons,
      finalPaintThicknessMicrons: finalPaintThicknessMicrons ?? this.finalPaintThicknessMicrons,
      paintGaugePoints: paintGaugePoints ?? this.paintGaugePoints,
      defectSeverity: defectSeverity ?? newDefectStage.stageNumber,
      defectStage: newDefectStage,
      correctionPercentage: correctionPercentage ?? this.correctionPercentage,
      serviceType: serviceType ?? this.serviceType,
      recipeStages: recipeStages ?? this.recipeStages,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      defectBadge: defectBadge ?? this.defectBadge,
      beforePhotos: beforePhotos ?? this.beforePhotos,
      afterPhotos: afterPhotos ?? this.afterPhotos,
      mediaZones: mediaZones ?? this.mediaZones,
      durationHours: durationHours ?? this.durationHours,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      savesCount: savesCount ?? this.savesCount,
      isSaved: isSaved ?? this.isSaved,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'title': title,
    'description': description,
    'vehicleYear': vehicleYear,
    'vehicleMake': vehicleMake,
    'vehicleModel': vehicleModel,
    'paintColorName': paintColorName,
    'paintCode': paintCode,
    'paintHardness': paintHardness.name,
    'initialPaintThicknessMicrons': initialPaintThicknessMicrons,
    'finalPaintThicknessMicrons': finalPaintThicknessMicrons,
    'paintGaugePoints': paintGaugePoints.map((p) => p.toJson()).toList(),
    'defectSeverity': defectSeverity,
    'defectStage': defectStage.name,
    'correctionPercentage': correctionPercentage,
    'serviceType': serviceType,
    'recipeStages': recipeStages.map((s) => s.toJson()).toList(),
    'beforeImageUrl': beforeImageUrl,
    'afterImageUrl': afterImageUrl,
    'defectBadge': defectBadge,
    'beforePhotos': beforePhotos,
    'afterPhotos': afterPhotos,
    'mediaZones': mediaZones.map((z) => z.toJson()).toList(),
    'durationHours': durationHours,
    'quotedPrice': quotedPrice,
    'likesCount': likesCount,
    'isLiked': isLiked,
    'savesCount': savesCount,
    'isSaved': isSaved,
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory DetailJob.fromJson(Map<String, dynamic> json) {
    final rawSeverity = json['defectSeverity'] as int? ?? 2;
    final stageStr = json['defectStage'] as String?;
    final resolvedStage = stageStr != null
        ? DefectStage.fromString(stageStr)
        : DefectStage.fromStageNumber(rawSeverity);
    final resolvedSeverity = resolvedStage.stageNumber;
    final initialMicrons = (json['initialPaintThicknessMicrons'] as num?)?.toDouble() ?? 120.0;
    final finalMicrons = (json['finalPaintThicknessMicrons'] as num?)?.toDouble() ?? 116.0;

    return DetailJob(
      id: json['id'] as String? ?? 'job_${DateTime.now().millisecondsSinceEpoch}',
      author: json['author'] != null ? UserProfile.fromJson(json['author'] as Map<String, dynamic>) : UserProfile(
        id: 'usr_anon',
        username: 'detailer',
        displayName: 'Master Detailer',
        businessName: 'Craft Studio',
        avatarUrl: '',
        location: 'United States',
        bio: '',
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      vehicleYear: json['vehicleYear'] as int? ?? DateTime.now().year,
      vehicleMake: json['vehicleMake'] as String? ?? '',
      vehicleModel: json['vehicleModel'] as String? ?? '',
      paintColorName: json['paintColorName'] as String? ?? '',
      paintCode: json['paintCode'] as String? ?? '',
      paintHardness: PaintHardness.values.firstWhere(
        (h) => h.name == (json['paintHardness'] as String?),
        orElse: () => PaintHardness.medium,
      ),
      initialPaintThicknessMicrons: initialMicrons,
      finalPaintThicknessMicrons: finalMicrons,
      paintGaugePoints: (json['paintGaugePoints'] as List<dynamic>?)
          ?.map((p) => PaintGaugePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      defectSeverity: resolvedSeverity,
      defectStage: resolvedStage,
      correctionPercentage: (json['correctionPercentage'] as int?) ?? 85,
      serviceType: json['serviceType'] as String? ?? 'Paint Correction',
      recipeStages: (json['recipeStages'] as List<dynamic>?)
          ?.map((s) => RecipeStage.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      beforeImageUrl: json['beforeImageUrl'] as String? ?? '',
      afterImageUrl: json['afterImageUrl'] as String? ?? '',
      defectBadge: json['defectBadge'] as String? ?? 'Stage 2: Moderate (Swirl Marks)',
      beforePhotos: (json['beforePhotos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      afterPhotos: (json['afterPhotos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mediaZones: (json['mediaZones'] as List<dynamic>?)
          ?.map((z) => JobMediaZone.fromJson(z as Map<String, dynamic>))
          .toList() ?? [],
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 8.0,
      quotedPrice: (json['quotedPrice'] as num?)?.toDouble(),
      likesCount: json['likesCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      savesCount: json['savesCount'] as int? ?? 0,
      isSaved: json['isSaved'] as bool? ?? false,
      comments: (json['comments'] as List<dynamic>?)
          ?.map((c) => JobComment.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
