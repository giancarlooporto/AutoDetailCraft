import 'dart:convert';
import 'dart:typed_data';

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
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String? ?? 'tm_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '',
      roleTitle: json['roleTitle'] as String? ?? 'Detail Specialist',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      localAvatarBytes: json['localAvatarBytes'] != null ? base64Decode(json['localAvatarBytes'] as String) : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobsCount: json['completedJobsCount'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isFounder: json['isFounder'] as bool? ?? false,
    );
  }
}
