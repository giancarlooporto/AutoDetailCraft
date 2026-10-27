import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'booking_models.dart';

class VehicleBodyType {
  static const String coupe = 'Coupe';
  static const String sedan = 'Sedan';
  static const String suv = 'SUV / Crossover';
  static const String truck = 'Truck';
  static const String minivan = 'Minivan / Van';

  static const List<String> all = [
    coupe,
    sedan,
    suv,
    truck,
    minivan,
  ];

  static IconData getIcon(String? type) {
    if (type == null) return Icons.directions_car_rounded;
    switch (type) {
      case coupe:
        return Icons.directions_car_rounded;
      case sedan:
        return Icons.directions_car_filled_rounded;
      case suv:
        return Icons.airport_shuttle_rounded;
      case truck:
        return Icons.local_shipping_rounded;
      case minivan:
        return Icons.airport_shuttle_outlined;
      default:
        final lower = type.toLowerCase();
        if (lower.contains('truck')) return Icons.local_shipping_rounded;
        if (lower.contains('van')) return Icons.airport_shuttle_outlined;
        if (lower.contains('suv') || lower.contains('crossover')) return Icons.airport_shuttle_rounded;
        return Icons.directions_car_rounded;
    }
  }

  static VehicleSize toVehicleSize(String? type) {
    if (type == null) return VehicleSize.coupeSedan;
    final lower = type.toLowerCase();
    if (lower.contains('truck') || lower.contains('van') || lower.contains('minivan')) {
      return VehicleSize.truckVan;
    }
    if (lower.contains('suv') || lower.contains('crossover')) {
      return VehicleSize.suvCrossover;
    }
    return VehicleSize.coupeSedan;
  }
}

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
  final String vehicleType; // Coupe, Sedan, SUV / Crossover, Truck, Minivan / Van

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
    this.vehicleType = 'Sedan',
  });

  String get fullName => '$year $make $model';

  VehicleSize get resolvedVehicleSize => VehicleBodyType.toVehicleSize(vehicleType);

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
      'vehicleType': vehicleType,
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
    final rawType = (json['vehicleType'] ?? json['vehicle_type'] ?? json['bodyType'] ?? json['body_type'])?.toString();
    final vehicleType = (rawType != null && rawType.isNotEmpty) ? rawType : 'Sedan';

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
      vehicleType: vehicleType,
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
    String? vehicleType,
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
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserVehicle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
