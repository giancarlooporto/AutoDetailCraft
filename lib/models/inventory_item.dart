import 'detail_job.dart';

enum InventoryCategory {
  hardware('HARDWARE', 'Polishers, pads, lights, meters'),
  chemicals('CHEMICALS', 'Compounds, coatings, prep sprays, APC'),
  recipe('RECIPE', 'Paint correction formulas & steps');

  final String label;
  final String description;
  const InventoryCategory(this.label, this.description);
}

class InventoryItem {
  final String id;
  final String name;
  final InventoryCategory category;
  final String brand;
  final String subCategory;
  final Map<String, String> specs;
  final String maintenance;
  final String assignedPadOrChemical;
  final String dilutionSpecs;
  final String? dilutionRatio;
  final String? cureTimeOrFlashTime;
  final String? safetyNotes;
  final List<RecipeStage> recipeStages;
  final String status;
  final String location;
  final String? imageUrl;
  final String? notes;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand = '',
    this.subCategory = '',
    this.specs = const {},
    this.maintenance = '',
    this.assignedPadOrChemical = '',
    this.dilutionSpecs = '',
    this.dilutionRatio,
    this.cureTimeOrFlashTime,
    this.safetyNotes,
    this.recipeStages = const [],
    this.status = 'In Service',
    this.location = '',
    this.imageUrl,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'brand': brand,
    'subCategory': subCategory,
    'specs': specs,
    'maintenance': maintenance,
    'assignedPadOrChemical': assignedPadOrChemical,
    'dilutionSpecs': dilutionSpecs,
    'dilutionRatio': dilutionRatio,
    'cureTimeOrFlashTime': cureTimeOrFlashTime,
    'safetyNotes': safetyNotes,
    'recipeStages': recipeStages.map((s) => s.toJson()).toList(),
    'status': status,
    'location': location,
    'imageUrl': imageUrl,
    'notes': notes,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String? ?? 'inv_${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? '',
    category: InventoryCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => InventoryCategory.hardware,
    ),
    brand: json['brand'] as String? ?? '',
    subCategory: json['subCategory'] as String? ?? '',
    specs: (json['specs'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {},
    maintenance: json['maintenance'] as String? ?? '',
    assignedPadOrChemical: json['assignedPadOrChemical'] as String? ?? '',
    dilutionSpecs: json['dilutionSpecs'] as String? ?? '',
    dilutionRatio: json['dilutionRatio'] as String?,
    cureTimeOrFlashTime: json['cureTimeOrFlashTime'] as String?,
    safetyNotes: json['safetyNotes'] as String?,
    recipeStages: (json['recipeStages'] as List<dynamic>?)
            ?.map((s) => RecipeStage.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
    status: json['status'] as String? ?? 'In Service',
    location: json['location'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    notes: json['notes'] as String?,
  );

  InventoryItem copyWith({
    String? id,
    String? name,
    InventoryCategory? category,
    String? brand,
    String? subCategory,
    Map<String, String>? specs,
    String? maintenance,
    String? assignedPadOrChemical,
    String? dilutionSpecs,
    String? dilutionRatio,
    String? cureTimeOrFlashTime,
    String? safetyNotes,
    List<RecipeStage>? recipeStages,
    String? status,
    String? location,
    String? imageUrl,
    String? notes,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      subCategory: subCategory ?? this.subCategory,
      specs: specs ?? this.specs,
      maintenance: maintenance ?? this.maintenance,
      assignedPadOrChemical: assignedPadOrChemical ?? this.assignedPadOrChemical,
      dilutionSpecs: dilutionSpecs ?? this.dilutionSpecs,
      dilutionRatio: dilutionRatio ?? this.dilutionRatio,
      cureTimeOrFlashTime: cureTimeOrFlashTime ?? this.cureTimeOrFlashTime,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      recipeStages: recipeStages ?? this.recipeStages,
      status: status ?? this.status,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
    );
  }
}
