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
    return UserVehicle(
      id: json['id'] as String? ?? 'veh_${DateTime.now().millisecondsSinceEpoch}',
      year: json['year'] as int? ?? 2024,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      colorName: json['colorName'] as String? ?? '',
      paintCode: json['paintCode'] as String?,
      imageUrl: json['imageUrl'] as String? ?? '',
      localImageBytes: json['localImageBytes'] != null
          ? base64Decode(json['localImageBytes'] as String)
          : null,
      lastDetailService: json['lastDetailService'] as String?,
      lastDetailDate: json['lastDetailDate'] != null
          ? DateTime.tryParse(json['lastDetailDate'] as String)
          : null,
    );
  }
}
