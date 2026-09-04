import 'dart:convert';
import 'dart:typed_data';
import 'booking_models.dart';
import 'team_member.dart';
import 'user_vehicle.dart';

enum UserRole {
  client('Vehicle Owner (Client)'),
  detailer('Detailer (Pro Host / Business)');

  final String label;
  const UserRole(this.label);
}

class UserCertification {
  final String title;
  final String issuer;
  final String badgeIcon;
  final bool isVerified;

  const UserCertification({
    required this.title,
    required this.issuer,
    this.badgeIcon = 'shield',
    this.isVerified = true,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'issuer': issuer,
    'badgeIcon': badgeIcon,
    'isVerified': isVerified,
  };

  factory UserCertification.fromJson(Map<String, dynamic> json) => UserCertification(
    title: json['title'] as String? ?? '',
    issuer: json['issuer'] as String? ?? '',
    badgeIcon: json['badgeIcon'] as String? ?? 'shield',
    isVerified: json['isVerified'] as bool? ?? true,
  );
}

class UserProfile {
  final String id;
  final UserRole role;
  final String username;
  final String displayName;
  final String businessName;
  final String avatarUrl;
  final Uint8List? localAvatarBytes; // Fast offline preview & fallback
  final String coverUrl;
  final Uint8List? localCoverBytes;
  final String location;
  final String serviceRadius; // e.g. "25 miles • Mobile & Studio"
  final String bio;
  final String phone;
  final String instagramHandle;
  final bool isIdaCertified;
  final bool isVerifiedHost;
  final List<UserCertification> certifications;
  final List<ServicePackage> servicePackages;
  final List<TeamMember> teamMembers; // Hired team members under this company
  final List<UserVehicle> myGarage; // User's registered vehicles/cars
  final int totalJobsCount;
  final double averageRating;
  final int reviewCount;
  final int followersCount;
  final int followingCount;
  final double startingPrice;

  const UserProfile({
    required this.id,
    this.role = UserRole.client,
    required this.username,
    required this.displayName,
    required this.businessName,
    required this.avatarUrl,
    this.localAvatarBytes,
    this.coverUrl = 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
    this.localCoverBytes,
    required this.location,
    this.serviceRadius = '25 miles • Mobile & Studio',
    required this.bio,
    this.phone = '',
    this.instagramHandle = '@detailcraft',
    this.isIdaCertified = false,
    this.isVerifiedHost = false,
    this.certifications = const [],
    this.servicePackages = const [],
    this.teamMembers = const [],
    this.myGarage = const [],
    this.totalJobsCount = 0,
    this.averageRating = 5.0,
    this.reviewCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.startingPrice = 150.0,
  });

  UserProfile copyWith({
    String? id,
    UserRole? role,
    String? username,
    String? displayName,
    String? businessName,
    String? avatarUrl,
    Uint8List? localAvatarBytes,
    String? coverUrl,
    Uint8List? localCoverBytes,
    String? location,
    String? serviceRadius,
    String? bio,
    String? phone,
    String? instagramHandle,
    bool? isIdaCertified,
    bool? isVerifiedHost,
    List<UserCertification>? certifications,
    List<ServicePackage>? servicePackages,
    List<TeamMember>? teamMembers,
    List<UserVehicle>? myGarage,
    int? totalJobsCount,
    double? averageRating,
    int? reviewCount,
    int? followersCount,
    int? followingCount,
    double? startingPrice,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      businessName: businessName ?? this.businessName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarBytes: localAvatarBytes ?? this.localAvatarBytes,
      coverUrl: coverUrl ?? this.coverUrl,
      localCoverBytes: localCoverBytes ?? this.localCoverBytes,
      location: location ?? this.location,
      serviceRadius: serviceRadius ?? this.serviceRadius,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      isIdaCertified: isIdaCertified ?? this.isIdaCertified,
      isVerifiedHost: isVerifiedHost ?? this.isVerifiedHost,
      certifications: certifications ?? this.certifications,
      servicePackages: servicePackages ?? this.servicePackages,
      teamMembers: teamMembers ?? this.teamMembers,
      myGarage: myGarage ?? this.myGarage,
      totalJobsCount: totalJobsCount ?? this.totalJobsCount,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      startingPrice: startingPrice ?? this.startingPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'username': username,
      'displayName': displayName,
      'businessName': businessName,
      'avatarUrl': avatarUrl,
      'localAvatarBytes': localAvatarBytes != null ? base64Encode(localAvatarBytes!) : null,
      'coverUrl': coverUrl,
      'localCoverBytes': localCoverBytes != null ? base64Encode(localCoverBytes!) : null,
      'location': location,
      'serviceRadius': serviceRadius,
      'bio': bio,
      'phone': phone,
      'instagramHandle': instagramHandle,
      'isIdaCertified': isIdaCertified,
      'isVerifiedHost': isVerifiedHost,
      'certifications': certifications.map((c) => c.toJson()).toList(),
      'servicePackages': servicePackages.map((s) => s.toJson()).toList(),
      'teamMembers': teamMembers.map((t) => t.toJson()).toList(),
      'myGarage': myGarage.map((v) => v.toJson()).toList(),
      'totalJobsCount': totalJobsCount,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'startingPrice': startingPrice,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? 'usr_you',
      role: (json['role'] as String?) == 'detailer' ? UserRole.detailer : UserRole.client,
      username: json['username'] as String? ?? 'user',
      displayName: json['displayName'] as String? ?? 'Vehicle Owner',
      businessName: json['businessName'] as String? ?? 'My Detailing Studio',
      avatarUrl: json['avatarUrl'] as String? ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
      localAvatarBytes: json['localAvatarBytes'] != null ? base64Decode(json['localAvatarBytes'] as String) : null,
      coverUrl: json['coverUrl'] as String? ?? 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
      localCoverBytes: json['localCoverBytes'] != null ? base64Decode(json['localCoverBytes'] as String) : null,
      location: json['location'] as String? ?? 'Austin, Texas',
      serviceRadius: json['serviceRadius'] as String? ?? '25 miles • Mobile & Studio',
      bio: json['bio'] as String? ?? 'Car enthusiast & detailing craft connoisseur.',
      phone: json['phone'] as String? ?? '',
      instagramHandle: json['instagramHandle'] as String? ?? '@detailcraft',
      isIdaCertified: json['isIdaCertified'] as bool? ?? false,
      isVerifiedHost: json['isVerifiedHost'] as bool? ?? false,
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((c) => UserCertification.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      servicePackages: (json['servicePackages'] as List<dynamic>?)
              ?.map((s) => ServicePackage.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      teamMembers: (json['teamMembers'] as List<dynamic>?)
              ?.map((t) => TeamMember.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      myGarage: (json['myGarage'] as List<dynamic>?)
              ?.map((v) => UserVehicle.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      totalJobsCount: json['totalJobsCount'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      startingPrice: (json['startingPrice'] as num?)?.toDouble() ?? 150.0,
    );
  }
}
