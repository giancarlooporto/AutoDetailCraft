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

  // Granular Access Permissions (Step 2)
  final List<String>? allowedHubSections; // null = all sections allowed. Specific section keys: 'portfolio', 'services', 'inventory', 'calendar', 'teams', 'savedRecipes'
  final bool canEditInventory; // false = view-only for chemicals & hardware
  final bool canViewPricing; // false = hide sensitive package prices & revenue
  final bool canManageTeam; // false = cannot add/remove other team members
  final bool canViewAllTeamCalendar; // false = can only view own schedule/bookings

  // Authentication & Credentials (Step 3)
  final String? email; // Staff member email
  final String? pin; // 4-digit quick staff PIN (e.g. "1234")
  final String? password; // Staff password (optional fallback)
  final String? inviteToken; // Secure invitation link token
  final String inviteStatus; // 'none', 'pending', 'accepted'
  final DateTime? inviteSentAt; // Dispatched timestamp

  static const List<String> allHubSections = [
    'portfolio',
    'services',
    'inventory',
    'calendar',
    'teams',
    'savedRecipes',
  ];

  static const List<String> defaultStaffHubSections = [
    'portfolio',
    'inventory',
    'calendar',
    'savedRecipes',
  ];

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
    this.allowedHubSections,
    this.canEditInventory = true,
    this.canViewPricing = true,
    this.canManageTeam = false,
    this.canViewAllTeamCalendar = true,
    this.email,
    this.pin,
    this.password,
    this.inviteToken,
    this.inviteStatus = 'none',
    this.inviteSentAt,
  });

  bool authenticateWithPin(String inputPin) {
    if (pin == null || pin!.trim().isEmpty) return false;
    return pin!.trim() == inputPin.trim();
  }

  bool authenticateWithPassword(String inputEmail, String inputPassword) {
    if (email == null || email!.trim().isEmpty) return false;
    if (email!.trim().toLowerCase() != inputEmail.trim().toLowerCase()) return false;
    final cleanInput = inputPassword.trim();
    if (password != null && password!.trim().isNotEmpty && password!.trim() == cleanInput) {
      return true;
    }
    if (pin != null && pin!.trim().isNotEmpty && pin!.trim() == cleanInput) {
      return true;
    }
    return false;
  }

  bool isSectionAllowed(String sectionName) {
    if (isFounder) return true;
    if (allowedHubSections == null) return true;
    return allowedHubSections!.contains(sectionName);
  }

  bool get allowsInventoryEdit => isFounder || canEditInventory;
  bool get allowsPricingView => isFounder || canViewPricing;
  bool get allowsTeamManagement => isFounder || canManageTeam;
  bool get allowsAllCalendarView => isFounder || canViewAllTeamCalendar;

  bool get isInvitePending =>
      email != null &&
      email!.trim().isNotEmpty &&
      (inviteStatus == 'pending' || (password == null && inviteStatus != 'accepted'));

  bool get isStaffAccountActive =>
      (password != null && password!.trim().isNotEmpty) || inviteStatus == 'accepted';

  String getInviteLink({String? studioId}) =>
      'https://www.autodetailcraft.com/?token=${inviteToken ?? id}&email=${Uri.encodeComponent(email ?? '')}';

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
      if (allowedHubSections != null)
        'allowedHubSections': allowedHubSections,
      'canEditInventory': canEditInventory,
      'canViewPricing': canViewPricing,
      'canManageTeam': canManageTeam,
      'canViewAllTeamCalendar': canViewAllTeamCalendar,
      if (email != null) 'email': email,
      if (pin != null) 'pin': pin,
      if (password != null) 'password': password,
      if (inviteToken != null) 'inviteToken': inviteToken,
      'inviteStatus': inviteStatus,
      if (inviteSentAt != null) 'inviteSentAt': inviteSentAt!.toIso8601String(),
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final schedList = json['customWeeklySchedule'] as List<dynamic>?;
    final schedule = schedList
        ?.map((item) => DayBusinessHours.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    final avatarBytesStr = json['localAvatarBytes'] as String?;

    final sectionsRaw = json['allowedHubSections'] as List<dynamic>?;
    final allowedSections = sectionsRaw?.map((e) => e.toString()).toList();

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
      allowedHubSections: allowedSections,
      canEditInventory: json['canEditInventory'] as bool? ?? true,
      canViewPricing: json['canViewPricing'] as bool? ?? true,
      canManageTeam: json['canManageTeam'] as bool? ?? false,
      canViewAllTeamCalendar: json['canViewAllTeamCalendar'] as bool? ?? true,
      email: json['email'] as String?,
      pin: json['pin'] as String?,
      password: json['password'] as String?,
      inviteToken: (json['inviteToken'] ?? json['invite_token']) as String?,
      inviteStatus: (json['inviteStatus'] ?? json['invite_status']) as String? ??
          (json['password'] != null ? 'accepted' : (json['email'] != null ? 'pending' : 'none')),
      inviteSentAt: (json['inviteSentAt'] ?? json['invite_sent_at']) != null
          ? DateTime.tryParse((json['inviteSentAt'] ?? json['invite_sent_at']) as String)
          : null,
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
    List<String>? allowedHubSections,
    bool? canEditInventory,
    bool? canViewPricing,
    bool? canManageTeam,
    bool? canViewAllTeamCalendar,
    String? email,
    String? pin,
    String? password,
    String? inviteToken,
    String? inviteStatus,
    DateTime? inviteSentAt,
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
      allowedHubSections: allowedHubSections ?? this.allowedHubSections,
      canEditInventory: canEditInventory ?? this.canEditInventory,
      canViewPricing: canViewPricing ?? this.canViewPricing,
      canManageTeam: canManageTeam ?? this.canManageTeam,
      canViewAllTeamCalendar: canViewAllTeamCalendar ?? this.canViewAllTeamCalendar,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      password: password ?? this.password,
      inviteToken: inviteToken ?? this.inviteToken,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      inviteSentAt: inviteSentAt ?? this.inviteSentAt,
    );
  }
}
