import 'dart:convert';
import 'dart:typed_data';

class UserVehicle {
  final String id;
  final int year;
  final String make;
  final String model;
  final String colorName;
  final String? paintCode;
  final String imageUrl;
  final Uint8List? localImageBytes; // Stores user uploaded raw photo bytes
  final String? lastDetailService;
  final DateTime? lastDetailDate;

  const UserVehicle({
    required this.id,
    required this.year,
    required this.make,
    required this.model,
    required this.colorName,
    this.paintCode,
    required this.imageUrl,
    this.localImageBytes,
    this.lastDetailService,
    this.lastDetailDate,
  });

  String get fullName => '$year $make $model';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'make': make,
      'model': model,
      'colorName': colorName,
      'paintCode': paintCode,
      'imageUrl': imageUrl,
      'localImageBytes': localImageBytes != null ? base64Encode(localImageBytes!) : null,
      'lastDetailService': lastDetailService,
      'lastDetailDate': lastDetailDate?.toIso8601String(),
    };
  }

  factory UserVehicle.fromJson(Map<String, dynamic> json) {
    Uint8List? parsedBytes;
    final rawBytes = json['localImageBytes'] ?? json['local_image_bytes'];
    if (rawBytes is Uint8List) {
      parsedBytes = rawBytes;
    } else if (rawBytes is List<int>) {
      parsedBytes = Uint8List.fromList(rawBytes);
    } else if (rawBytes is List) {
      try {
        parsedBytes = Uint8List.fromList(rawBytes.map((e) => (e as num).toInt()).toList());
      } catch (_) {}
    } else if (rawBytes is String && rawBytes.isNotEmpty) {
      try {
        parsedBytes = base64Decode(rawBytes);
      } catch (_) {}
    }

    DateTime? parsedDate;
    final rawDate = json['lastDetailDate'] ?? json['last_detail_date'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    }

    int parsedYear = 2024;
    final rawYear = json['year'];
    if (rawYear is num) {
      parsedYear = rawYear.toInt();
    } else if (rawYear is String && rawYear.isNotEmpty) {
      parsedYear = int.tryParse(rawYear) ?? 2024;
    }

    final rawPaintCode = (json['paintCode'] ?? json['paint_code'])?.toString();
    final rawDetailService = (json['lastDetailService'] ?? json['last_detail_service'])?.toString();

    return UserVehicle(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : 'veh_${DateTime.now().millisecondsSinceEpoch}',
      year: parsedYear,
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      colorName: (json['colorName'] ?? json['paint_color'] ?? json['color_name'])?.toString() ?? '',
      paintCode: (rawPaintCode != null && rawPaintCode.isNotEmpty) ? rawPaintCode : null,
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString() ?? '',
      localImageBytes: parsedBytes,
      lastDetailService: (rawDetailService != null && rawDetailService.isNotEmpty) ? rawDetailService : null,
      lastDetailDate: parsedDate,
    );
  }

  UserVehicle copyWith({
    String? id,
    int? year,
    String? make,
    String? model,
    String? colorName,
    String? paintCode,
    String? imageUrl,
    Uint8List? localImageBytes,
    String? lastDetailService,
    DateTime? lastDetailDate,
  }) {
    return UserVehicle(
      id: id ?? this.id,
      year: year ?? this.year,
      make: make ?? this.make,
      model: model ?? this.model,
      colorName: colorName ?? this.colorName,
      paintCode: paintCode ?? this.paintCode,
      imageUrl: imageUrl ?? this.imageUrl,
      localImageBytes: localImageBytes ?? this.localImageBytes,
      lastDetailService: lastDetailService ?? this.lastDetailService,
      lastDetailDate: lastDetailDate ?? this.lastDetailDate,
    );
  }
}
