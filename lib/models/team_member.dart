import 'dart:convert';
import 'dart:typed_data';
import 'calendar_availability_block.dart';

class TeamMember {
  final String id;
  final String name;
  final String roleTitle; // e.g. "Senior Detail Specialist", "PPF & Ceramic Lead"
  final String avatarUrl;
  final Uint8List? localAvatarBytes;
  final double rating;
  final int completedJobsCount;
  final bool isAvailable;
  final bool isFounder; // Owner / Founder badge
  final List<DayBusinessHours>? customWeeklySchedule; // Custom shifts & recurring days off (null = inherits studio schedule)

  const TeamMember({
    required this.id,
    required this.name,
    required this.roleTitle,
    required this.avatarUrl,
    this.localAvatarBytes,
    this.rating = 5.0,
    this.completedJobsCount = 0,
    this.isAvailable = true,
    this.isFounder = false,
    this.customWeeklySchedule,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roleTitle': roleTitle,
      'avatarUrl': avatarUrl,
      'localAvatarBytes': localAvatarBytes != null ? base64Encode(localAvatarBytes!) : null,
      'rating': rating,
      'completedJobsCount': completedJobsCount,
      'isAvailable': isAvailable,
      'isFounder': isFounder,
      if (customWeeklySchedule != null)
        'customWeeklySchedule': customWeeklySchedule!.map((h) => h.toJson()).toList(),
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final schedList = json['customWeeklySchedule'] as List<dynamic>?;
    final schedule = schedList
        ?.map((item) => DayBusinessHours.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    final avatarBytesStr = json['localAvatarBytes'] as String?;

    return TeamMember(
      id: json['id'] as String? ?? 'tm_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '',
      roleTitle: json['roleTitle'] as String? ?? 'Detail Specialist',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      localAvatarBytes: avatarBytesStr != null && avatarBytesStr.trim().isNotEmpty
          ? base64Decode(avatarBytesStr.trim())
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobsCount: json['completedJobsCount'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isFounder: json['isFounder'] as bool? ?? false,
      customWeeklySchedule: schedule,
    );
  }

  String get statusLabel => isAvailable ? 'Available' : 'On Job';

  TeamMember copyWith({
    String? id,
    String? name,
    String? roleTitle,
    String? avatarUrl,
    Uint8List? localAvatarBytes,
    double? rating,
    int? completedJobsCount,
    bool? isAvailable,
    bool? isFounder,
    List<DayBusinessHours>? customWeeklySchedule,
  }) {
    return TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      roleTitle: roleTitle ?? this.roleTitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarBytes: localAvatarBytes ?? this.localAvatarBytes,
      rating: rating ?? this.rating,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      isAvailable: isAvailable ?? this.isAvailable,
      isFounder: isFounder ?? this.isFounder,
      customWeeklySchedule: customWeeklySchedule ?? this.customWeeklySchedule,
    );
  }
}
