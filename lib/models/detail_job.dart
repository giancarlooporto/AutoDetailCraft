import 'user_profile.dart';

enum PaintHardness {
  soft,        // e.g. Tesla Solid Black, Subaru, Mazda (very sticky, micro-mars easily)
  medium,      // e.g. Ford, Chevrolet, Toyota
  hard,        // e.g. BMW, Mercedes CeramiClear, Audi, Porsche
  singleStage, // Vintage / classic non-clear coated enamel or lacquer
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
}

class JobComment {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String text;
  final DateTime createdAt;
  final bool isVerifiedPro;

  const JobComment({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.createdAt,
    this.isVerifiedPro = false,
  });
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
  final int defectSeverity; // 1 to 10
  final String serviceType;
  
  // Recipe
  final List<RecipeStage> recipeStages;
  
  // Media for 50/50 Slider
  final String beforeImageUrl;
  final String afterImageUrl;
  final String defectBadge; // e.g. 'Heavy Swirls & Bird Etchings', '800-Grit Wet Sand Scratches'
  
  // Business metrics
  final double durationHours;
  final double? quotedPrice;
  
  // Social metrics
  final int likesCount;
  final bool isLiked;
  final int savesCount;
  final bool isSaved;
  final List<JobComment> comments;

  const DetailJob({
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
    required this.defectSeverity,
    required this.serviceType,
    required this.recipeStages,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.defectBadge = 'Swirl Marks & Micro-Marring',
    this.durationHours = 8.0,
    this.quotedPrice,
    this.likesCount = 0,
    this.isLiked = false,
    this.savesCount = 0,
    this.isSaved = false,
    this.comments = const [],
  });

  double get micronsRemoved => (initialPaintThicknessMicrons - finalPaintThicknessMicrons).clamp(0.0, 99.0);

  String get vehicleFullName => '$vehicleYear $vehicleMake $vehicleModel';

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
    int? defectSeverity,
    String? serviceType,
    List<RecipeStage>? recipeStages,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? defectBadge,
    double? durationHours,
    double? quotedPrice,
    int? likesCount,
    bool? isLiked,
    int? savesCount,
    bool? isSaved,
    List<JobComment>? comments,
  }) {
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
      defectSeverity: defectSeverity ?? this.defectSeverity,
      serviceType: serviceType ?? this.serviceType,
      recipeStages: recipeStages ?? this.recipeStages,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      defectBadge: defectBadge ?? this.defectBadge,
      durationHours: durationHours ?? this.durationHours,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      savesCount: savesCount ?? this.savesCount,
      isSaved: isSaved ?? this.isSaved,
      comments: comments ?? this.comments,
    );
  }
}
