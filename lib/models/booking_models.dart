import 'package:flutter/material.dart';

enum VehicleSize {
  coupeSedan('Coupe / Sedan', 1.0, Icons.directions_car_rounded),
  suvCrossover('SUV / Crossover', 1.25, Icons.airport_shuttle_rounded),
  truckVan('Truck / Large Van', 1.45, Icons.local_shipping_rounded);

  final String label;
  final double priceMultiplier;
  final IconData icon;

  const VehicleSize(this.label, this.priceMultiplier, this.icon);
}

enum ServiceLocationType {
  mobile('Mobile (At Your Location)', Icons.home_repair_service_rounded),
  shop('Drop-off at Studio / Shop', Icons.storefront_rounded);

  final String label;
  final IconData icon;

  const ServiceLocationType(this.label, this.icon);
}

enum BookingStatus {
  pending('Pending Host Review', Color(0xFFFFA000)),
  confirmed('Confirmed & Reserved', Color(0xFF00E676)),
  inProgress('In Progress (On-Site)', Color(0xFF00E5FF)),
  completed('Completed & Verified', Color(0xFF2979FF)),
  cancelled('Cancelled', Color(0xFFFF5252));

  final String label;
  final Color statusColor;

  const BookingStatus(this.label, this.statusColor);
}

class ServicePackage {
  final String id;
  final String title;
  final String description;
  final double basePrice;
  final String estimatedDuration;
  final List<String> includes;
  final bool isPopular;

  const ServicePackage({
    required this.id,
    required this.title,
    required this.description,
    required this.basePrice,
    required this.estimatedDuration,
    required this.includes,
    this.isPopular = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'basePrice': basePrice,
    'estimatedDuration': estimatedDuration,
    'includes': includes,
    'isPopular': isPopular,
  };

  factory ServicePackage.fromJson(Map<String, dynamic> json) => ServicePackage(
    id: json['id'] as String? ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    basePrice: (json['basePrice'] as num?)?.toDouble() ?? 100.0,
    estimatedDuration: json['estimatedDuration'] as String? ?? '2-3 hrs',
    includes: (json['includes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    isPopular: json['isPopular'] as bool? ?? false,
  );
}

class BookingAppointment {
  final String id;
  final String detailerId;
  final String detailerName;
  final String detailerBusinessName;
  final String detailerAvatar;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String vehicleYearMakeModel;
  final VehicleSize vehicleSize;
  final ServicePackage package;
  final ServiceLocationType locationType;
  final String clientAddress;
  final DateTime scheduledDate;
  final String scheduledTimeSlot;
  final double totalPrice;
  final double depositAmount;
  final BookingStatus status;
  final String? clientNotes;
  final String? preInspectionSummary;
  final String? warrantyPassportId;

  const BookingAppointment({
    required this.id,
    required this.detailerId,
    required this.detailerName,
    required this.detailerBusinessName,
    required this.detailerAvatar,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.vehicleYearMakeModel,
    required this.vehicleSize,
    required this.package,
    required this.locationType,
    required this.clientAddress,
    required this.scheduledDate,
    required this.scheduledTimeSlot,
    required this.totalPrice,
    required this.depositAmount,
    this.status = BookingStatus.confirmed,
    this.clientNotes,
    this.preInspectionSummary,
    this.warrantyPassportId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'detailerId': detailerId,
    'detailerName': detailerName,
    'detailerBusinessName': detailerBusinessName,
    'detailerAvatar': detailerAvatar,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'clientEmail': clientEmail,
    'vehicleYearMakeModel': vehicleYearMakeModel,
    'vehicleSize': vehicleSize.name,
    'package': package.toJson(),
    'locationType': locationType.name,
    'clientAddress': clientAddress,
    'scheduledDate': scheduledDate.toIso8601String(),
    'scheduledTimeSlot': scheduledTimeSlot,
    'totalPrice': totalPrice,
    'depositAmount': depositAmount,
    'status': status.name,
    'clientNotes': clientNotes,
    'preInspectionSummary': preInspectionSummary,
    'warrantyPassportId': warrantyPassportId,
  };

  factory BookingAppointment.fromJson(Map<String, dynamic> json) => BookingAppointment(
    id: json['id'] as String? ?? 'bk_${DateTime.now().millisecondsSinceEpoch}',
    detailerId: json['detailerId'] as String? ?? '',
    detailerName: json['detailerName'] as String? ?? '',
    detailerBusinessName: json['detailerBusinessName'] as String? ?? '',
    detailerAvatar: json['detailerAvatar'] as String? ?? '',
    clientName: json['clientName'] as String? ?? '',
    clientPhone: json['clientPhone'] as String? ?? '',
    clientEmail: json['clientEmail'] as String? ?? '',
    vehicleYearMakeModel: json['vehicleYearMakeModel'] as String? ?? '',
    vehicleSize: VehicleSize.values.firstWhere(
      (v) => v.name == json['vehicleSize'],
      orElse: () => VehicleSize.coupeSedan,
    ),
    package: ServicePackage.fromJson(json['package'] as Map<String, dynamic>),
    locationType: ServiceLocationType.values.firstWhere(
      (l) => l.name == json['locationType'],
      orElse: () => ServiceLocationType.mobile,
    ),
    clientAddress: json['clientAddress'] as String? ?? '',
    scheduledDate: DateTime.tryParse(json['scheduledDate'] as String? ?? '') ?? DateTime.now(),
    scheduledTimeSlot: json['scheduledTimeSlot'] as String? ?? '9:00 AM',
    totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
    status: BookingStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => BookingStatus.confirmed,
    ),
    clientNotes: json['clientNotes'] as String?,
    preInspectionSummary: json['preInspectionSummary'] as String?,
    warrantyPassportId: json['warrantyPassportId'] as String?,
  );
}
