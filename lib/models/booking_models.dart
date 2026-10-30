import 'dart:convert';
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
  final String? recipeId;
  final String? recipeName;
  final Map<String, double> vehicleSurcharges;

  final int? durationValue;
  final String? durationUnit; // 'minutes', 'hours', 'days'

  const ServicePackage({
    required this.id,
    required this.title,
    required this.description,
    required this.basePrice,
    required this.estimatedDuration,
    required this.includes,
    this.isPopular = false,
    this.recipeId,
    this.recipeName,
    this.vehicleSurcharges = const {},
    this.durationValue,
    this.durationUnit,
  });

  /// Robust total duration in minutes
  int get durationMinutes {
    if (durationValue != null && durationValue! > 0 && durationUnit != null) {
      final unit = durationUnit!.toLowerCase().trim();
      if (unit.contains('day')) return durationValue! * 24 * 60;
      if (unit.contains('hour') || unit.contains('hr')) return durationValue! * 60;
      if (unit.contains('min')) return durationValue!;
    }
    // Safe fallback parsing from estimatedDuration string
    final clean = estimatedDuration.toLowerCase().trim();
    if (clean.contains('day')) {
      final matches = RegExp(r'(\d+(?:\.\d+)?)')
          .allMatches(clean)
          .map((m) => double.tryParse(m.group(0)!))
          .whereType<double>()
          .toList();
      if (matches.isNotEmpty) {
        final maxDays = matches.reduce((a, b) => a > b ? a : b);
        return (maxDays * 24 * 60).round();
      }
      return 24 * 60;
    }
    // Handle compound strings like "1 hr 30 mins", "2 hours 45 mins", etc.
    final compoundMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)\s*(?:and\s*)?(\d+(?:\.\d+)?)\s*(?:mins?|minutes?)').firstMatch(clean);
    if (compoundMatch != null) {
      final h = double.tryParse(compoundMatch.group(1)!) ?? 0;
      final m = double.tryParse(compoundMatch.group(2)!) ?? 0;
      return (h * 60 + m).round();
    }
    if (clean.contains('hour') || clean.contains('hr')) {
      final matches = RegExp(r'(\d+(?:\.\d+)?)')
          .allMatches(clean)
          .map((m) => double.tryParse(m.group(0)!))
          .whereType<double>()
          .toList();
      if (matches.isNotEmpty) {
        final maxHours = matches.reduce((a, b) => a > b ? a : b);
        return (maxHours * 60).round();
      }
    }
    if (clean.contains('min')) {
      final matches = RegExp(r'(\d+(?:\.\d+)?)')
          .allMatches(clean)
          .map((m) => double.tryParse(m.group(0)!))
          .whereType<double>()
          .toList();
      if (matches.isNotEmpty) {
        final maxMins = matches.reduce((a, b) => a > b ? a : b);
        return maxMins.round();
      }
    }
    return 180;
  }

  /// Duration in hours as a decimal
  double get durationHours => durationMinutes / 60.0;

  /// Returns true if unit is 'days', text contains 'day', or duration >= 1440 mins
  bool get isMultiDay {
    if (durationUnit != null && durationUnit!.toLowerCase().contains('day')) {
      return true;
    }
    final clean = estimatedDuration.toLowerCase();
    if (clean.contains('day')) return true;
    return durationMinutes >= 1440;
  }

  /// Turnaround days for multi-day services (minimum 1 day if multi-day, 0 otherwise)
  int get turnaroundDays {
    if (!isMultiDay) return 0;
    if (durationValue != null &&
        durationValue! > 0 &&
        (durationUnit?.toLowerCase().contains('day') ?? false)) {
      return durationValue!.clamp(1, 30);
    }
    final clean = estimatedDuration.toLowerCase();
    if (clean.contains('day')) {
      final matches = RegExp(r'(\d+(?:\.\d+)?)')
          .allMatches(clean)
          .map((m) => double.tryParse(m.group(0)!))
          .whereType<double>()
          .toList();
      if (matches.isNotEmpty) {
        final maxDays = matches.reduce((a, b) => a > b ? a : b);
        return maxDays.ceil().clamp(1, 30);
      }
    }
    return (durationMinutes / 1440).ceil().clamp(1, 30);
  }

  /// User-facing duration badge text (e.g. "2 Days Turnaround", "3.5 hrs")
  String get durationBadge {
    if (isMultiDay) {
      final days = turnaroundDays;
      return days == 1 ? '1 Day Turnaround' : '$days Days Turnaround';
    }
    final mins = durationMinutes;
    if (mins < 60) return '$mins mins';
    final hrs = mins / 60.0;
    return (hrs % 1 == 0) ? '${hrs.toInt()} hrs' : '${hrs.toStringAsFixed(1)} hrs';
  }

  double getSurchargeForVehicleType(String? type) {
    if (type == null || type.isEmpty) return 0.0;
    // Check if detailer set explicit surcharge in vehicleSurcharges
    for (final entry in vehicleSurcharges.entries) {
      if (entry.key.toLowerCase().trim() == type.toLowerCase().trim()) {
        return entry.value;
      }
    }
    final lower = type.toLowerCase();
    if (lower.contains('truck')) {
      return vehicleSurcharges['Truck'] ?? (basePrice * (VehicleSize.truckVan.priceMultiplier - 1.0));
    }
    if (lower.contains('van') || lower.contains('minivan')) {
      return vehicleSurcharges['Minivan / Van'] ?? (basePrice * (VehicleSize.truckVan.priceMultiplier - 1.0));
    }
    if (lower.contains('suv') || lower.contains('crossover')) {
      return vehicleSurcharges['SUV / Crossover'] ?? (basePrice * (VehicleSize.suvCrossover.priceMultiplier - 1.0));
    }
    if (lower.contains('coupe') || lower.contains('sedan')) {
      return vehicleSurcharges['Coupe'] ?? vehicleSurcharges['Sedan'] ?? 0.0;
    }
    return vehicleSurcharges[type] ?? 0.0;
  }

  double calculatePriceForVehicleType(String? type) {
    return basePrice + getSurchargeForVehicleType(type);
  }

  double calculatePriceForVehicle(dynamic vehicle) {
    if (vehicle == null) return basePrice;
    final vehicleType = (vehicle.vehicleType as String?) ?? 'Sedan';
    return calculatePriceForVehicleType(vehicleType);
  }

  double calculatePriceForVehicleSize(VehicleSize size) {
    switch (size) {
      case VehicleSize.suvCrossover:
        return calculatePriceForVehicleType('SUV / Crossover');
      case VehicleSize.truckVan:
        return calculatePriceForVehicleType('Truck');
      case VehicleSize.coupeSedan:
        return calculatePriceForVehicleType('Sedan');
    }
  }

  ServicePackage copyWith({
    String? id,
    String? title,
    String? description,
    double? basePrice,
    String? estimatedDuration,
    List<String>? includes,
    bool? isPopular,
    String? recipeId,
    String? recipeName,
    Map<String, double>? vehicleSurcharges,
    int? durationValue,
    String? durationUnit,
  }) => ServicePackage(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    basePrice: basePrice ?? this.basePrice,
    estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    includes: includes ?? this.includes,
    isPopular: isPopular ?? this.isPopular,
    recipeId: recipeId ?? this.recipeId,
    recipeName: recipeName ?? this.recipeName,
    vehicleSurcharges: vehicleSurcharges ?? this.vehicleSurcharges,
    durationValue: durationValue ?? this.durationValue,
    durationUnit: durationUnit ?? this.durationUnit,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'basePrice': basePrice,
    'estimatedDuration': estimatedDuration,
    'includes': includes,
    'isPopular': isPopular,
    if (recipeId != null) 'recipeId': recipeId,
    if (recipeName != null) 'recipeName': recipeName,
    if (vehicleSurcharges.isNotEmpty) 'vehicleSurcharges': vehicleSurcharges,
    if (durationValue != null) 'durationValue': durationValue,
    if (durationUnit != null) 'durationUnit': durationUnit,
  };

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    final rawSurcharges = json['vehicleSurcharges'] ?? json['vehicle_surcharges'];
    Map<String, double> parsedSurcharges = {};
    if (rawSurcharges is Map) {
      rawSurcharges.forEach((k, v) {
        if (v is num) {
          parsedSurcharges[k.toString()] = v.toDouble();
        }
      });
    }

    return ServicePackage(
      id: json['id'] as String? ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 100.0,
      estimatedDuration: json['estimatedDuration'] as String? ?? '2-3 hrs',
      includes: (json['includes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isPopular: json['isPopular'] as bool? ?? false,
      recipeId: json['recipeId'] as String?,
      recipeName: json['recipeName'] as String?,
      vehicleSurcharges: parsedSurcharges,
      durationValue: () {
        final raw = json['durationValue'] ?? json['duration_value'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw);
        return null;
      }(),
      durationUnit: (json['durationUnit'] ?? json['duration_unit'])?.toString(),
    );
  }
}

class BookingAppointment {
  final String id;
  final String? clientId;
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
  final String? assignedTeamMemberId;
  final String? assignedTeamMemberName;
  final DateTime? completionDate;
  final String? startTime;
  final String? endTime;
  final int? durationMinutes;
  final bool isMultiDay;

  const BookingAppointment({
    required this.id,
    this.clientId,
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
    this.assignedTeamMemberId,
    this.assignedTeamMemberName,
    this.completionDate,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.isMultiDay = false,
  });

  BookingAppointment copyWith({
    String? id,
    String? clientId,
    String? detailerId,
    String? detailerName,
    String? detailerBusinessName,
    String? detailerAvatar,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? vehicleYearMakeModel,
    VehicleSize? vehicleSize,
    ServicePackage? package,
    ServiceLocationType? locationType,
    String? clientAddress,
    DateTime? scheduledDate,
    String? scheduledTimeSlot,
    double? totalPrice,
    double? depositAmount,
    BookingStatus? status,
    String? clientNotes,
    String? preInspectionSummary,
    String? warrantyPassportId,
    String? assignedTeamMemberId,
    String? assignedTeamMemberName,
    DateTime? completionDate,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    bool? isMultiDay,
  }) => BookingAppointment(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    detailerId: detailerId ?? this.detailerId,
    detailerName: detailerName ?? this.detailerName,
    detailerBusinessName: detailerBusinessName ?? this.detailerBusinessName,
    detailerAvatar: detailerAvatar ?? this.detailerAvatar,
    clientName: clientName ?? this.clientName,
    clientPhone: clientPhone ?? this.clientPhone,
    clientEmail: clientEmail ?? this.clientEmail,
    vehicleYearMakeModel: vehicleYearMakeModel ?? this.vehicleYearMakeModel,
    vehicleSize: vehicleSize ?? this.vehicleSize,
    package: package ?? this.package,
    locationType: locationType ?? this.locationType,
    clientAddress: clientAddress ?? this.clientAddress,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    scheduledTimeSlot: scheduledTimeSlot ?? this.scheduledTimeSlot,
    totalPrice: totalPrice ?? this.totalPrice,
    depositAmount: depositAmount ?? this.depositAmount,
    status: status ?? this.status,
    clientNotes: clientNotes ?? this.clientNotes,
    preInspectionSummary: preInspectionSummary ?? this.preInspectionSummary,
    warrantyPassportId: warrantyPassportId ?? this.warrantyPassportId,
    assignedTeamMemberId: assignedTeamMemberId ?? this.assignedTeamMemberId,
    assignedTeamMemberName: assignedTeamMemberName ?? this.assignedTeamMemberName,
    completionDate: completionDate ?? this.completionDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    isMultiDay: isMultiDay ?? this.isMultiDay,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
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
    if (assignedTeamMemberId != null) 'assignedTeamMemberId': assignedTeamMemberId,
    if (assignedTeamMemberName != null) 'assignedTeamMemberName': assignedTeamMemberName,
    if (completionDate != null) 'completionDate': completionDate!.toIso8601String(),
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    'isMultiDay': isMultiDay,
  };

  factory BookingAppointment.fromJson(Map<String, dynamic> json) {
    final rawPackage = json['package'] ?? json['package_data'];
    final packageMap = rawPackage is Map
        ? Map<String, dynamic>.from(rawPackage)
        : (rawPackage is String ? Map<String, dynamic>.from(jsonDecode(rawPackage) as Map) : <String, dynamic>{});

    final locRaw = json['locationType'] ?? json['location_type'] ?? json['service_location_type'];
    final vehicleSizeRaw = json['vehicleSize'] ?? json['vehicle_size'];
    final statusRaw = json['status'];
    final rawCompDate = json['completionDate'] ?? json['completion_date'];
    final parsedCompDate = rawCompDate != null ? DateTime.tryParse(rawCompDate as String) : null;
    final parsedPackage = packageMap.isNotEmpty
        ? ServicePackage.fromJson(packageMap)
        : ServicePackage(
            id: 'pkg_fallback',
            title: 'Standard Service',
            description: 'Professional detailing package',
            basePrice: ((json['totalPrice'] ?? json['total_price']) as num?)?.toDouble() ?? 0.0,
            estimatedDuration: '2 hours',
            includes: const ['Full detail service'],
          );

    final rawIsMulti = json['isMultiDay'] ?? json['is_multi_day'];
    final bool? parsedIsMulti = rawIsMulti is bool
        ? rawIsMulti
        : (rawIsMulti is String ? (rawIsMulti.toLowerCase() == 'true') : null);
    final resolvedIsMulti = parsedIsMulti ?? parsedPackage.isMultiDay;

    return BookingAppointment(
      id: (json['id'] as String?) ?? 'bk_${DateTime.now().millisecondsSinceEpoch}',
      clientId: (json['clientId'] ?? json['client_id']) as String?,
      detailerId: (json['detailerId'] ?? json['detailer_id']) as String? ?? '',
      detailerName: (json['detailerName'] ?? json['detailer_name']) as String? ?? '',
      detailerBusinessName: (json['detailerBusinessName'] ?? json['detailer_business_name']) as String? ?? '',
      detailerAvatar: (json['detailerAvatar'] ?? json['detailer_avatar']) as String? ?? '',
      clientName: (json['clientName'] ?? json['client_name']) as String? ?? '',
      clientPhone: (json['clientPhone'] ?? json['client_phone']) as String? ?? '',
      clientEmail: (json['clientEmail'] ?? json['client_email']) as String? ?? '',
      vehicleYearMakeModel: (json['vehicleYearMakeModel'] ?? json['vehicle_year_make_model']) as String? ?? '',
      vehicleSize: VehicleSize.values.firstWhere(
        (v) => v.name == vehicleSizeRaw,
        orElse: () => VehicleSize.coupeSedan,
      ),
      package: parsedPackage,
      locationType: ServiceLocationType.values.firstWhere(
        (l) => l.name == locRaw,
        orElse: () => ServiceLocationType.mobile,
      ),
      clientAddress: (json['clientAddress'] ?? json['client_address']) as String? ?? '',
      scheduledDate: DateTime.tryParse((json['scheduledDate'] ?? json['scheduled_date']) as String? ?? '') ?? DateTime.now(),
      scheduledTimeSlot: (json['scheduledTimeSlot'] ?? json['scheduled_time_slot']) as String? ?? '9:00 AM',
      totalPrice: ((json['totalPrice'] ?? json['total_price']) as num?)?.toDouble() ?? 0.0,
      depositAmount: ((json['depositAmount'] ?? json['deposit_amount']) as num?)?.toDouble() ?? 0.0,
      status: BookingStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => BookingStatus.confirmed,
      ),
      clientNotes: (json['clientNotes'] ?? json['client_notes']) as String?,
      preInspectionSummary: (json['preInspectionSummary'] ?? json['pre_inspection_summary']) as String?,
      warrantyPassportId: (json['warrantyPassportId'] ?? json['warranty_passport_id']) as String?,
      assignedTeamMemberId: (json['assignedTeamMemberId'] ?? json['assigned_team_member_id']) as String?,
      assignedTeamMemberName: (json['assignedTeamMemberName'] ?? json['assigned_team_member_name']) as String?,
      completionDate: parsedCompDate,
      startTime: (json['startTime'] ?? json['start_time']) as String?,
      endTime: (json['endTime'] ?? json['end_time']) as String?,
      durationMinutes: () {
        final raw = json['durationMinutes'] ?? json['duration_minutes'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw);
        return null;
      }(),
      isMultiDay: resolvedIsMulti,
    );
  }
}
