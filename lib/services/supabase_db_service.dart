import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/user_vehicle.dart';
import '../models/team_member.dart';
import '../models/shift_request.dart';
import '../models/detail_job.dart';
import '../models/booking_models.dart';
import '../models/calendar_availability_block.dart';
import '../models/inventory_item.dart';
import 'supabase_service.dart';
import 'mock_data_service.dart';

class SupabaseDbService {
  static SupabaseClient? get _client => SupabaseService.client;

  /// Fetch full user profile including vehicles and team from Supabase
  static Future<UserProfile?> fetchUserProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (res == null) return null;

      // Fetch user's garage vehicles
      final vehiclesRes = await client.from('vehicles').select().eq('user_id', userId);
      final List<UserVehicle> garage = (vehiclesRes as List<dynamic>).map<UserVehicle>((v) {
        final lastDateStr = (v['last_detail_date'] ?? v['lastDetailDate']) as String?;
        return UserVehicle(
          id: v['id'] as String,
          year: v['year'] as int,
          make: v['make'] as String,
          model: v['model'] as String,
          colorName: (v['paint_color'] ?? v['colorName']) as String? ?? '',
          paintCode: (v['paint_code'] ?? v['paintCode']) as String?,
          imageUrl: (v['image_url'] ?? v['imageUrl']) as String? ?? '',
          lastDetailService: (v['last_detail_service'] ?? v['lastDetailService']) as String?,
          lastDetailDate: lastDateStr != null ? DateTime.tryParse(lastDateStr) : null,
        );
      }).toList();

      // Fetch user's team members
      final teamRes = await client.from('team_members').select().eq('studio_id', userId);
      final List<TeamMember> team = (teamRes as List<dynamic>).map<TeamMember>((t) {
        final schedRaw = t['custom_weekly_schedule'] ?? t['customWeeklySchedule'];
        List<DayBusinessHours>? schedule;
        if (schedRaw != null && schedRaw is List) {
          try {
            schedule = schedRaw
                .map((item) => DayBusinessHours.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          } catch (_) {}
        }

        final sectionsRaw = t['allowed_hub_sections'] ?? t['allowedHubSections'];
        List<String>? allowedSections;
        if (sectionsRaw != null && sectionsRaw is List) {
          try {
            allowedSections = sectionsRaw.map((e) => e.toString()).toList();
          } catch (_) {}
        }

        return TeamMember(
          id: t['id'] as String,
          name: t['name'] as String,
          roleTitle: (t['role_title'] ?? t['roleTitle']) as String? ?? 'Detail Specialist',
          avatarUrl: (t['avatar_url'] ?? t['avatarUrl']) as String? ?? '',
          rating: (t['rating'] as num?)?.toDouble() ?? 5.0,
          completedJobsCount: (t['completed_jobs_count'] ?? t['completedJobsCount']) as int? ?? 0,
          isAvailable: (t['is_available'] ?? t['isAvailable']) as bool? ?? true,
          isFounder: (t['is_founder'] ?? t['isFounder']) as bool? ?? false,
          customWeeklySchedule: schedule,
          allowedHubSections: allowedSections,
          canEditInventory: (t['can_edit_inventory'] ?? t['canEditInventory']) as bool? ?? true,
          canViewPricing: (t['can_view_pricing'] ?? t['canViewPricing']) as bool? ?? true,
          canManageTeam: (t['can_manage_team'] ?? t['canManageTeam']) as bool? ?? false,
          canViewAllTeamCalendar: (t['can_view_all_team_calendar'] ?? t['canViewAllTeamCalendar']) as bool? ?? true,
          email: t['email'] as String?,
          pin: t['pin'] as String?,
          password: t['password'] as String?,
          inviteToken: (t['invite_token'] ?? t['inviteToken']) as String?,
          inviteStatus: (t['invite_status'] ?? t['inviteStatus']) as String? ?? 'none',
          inviteSentAt: (t['invite_sent_at'] ?? t['inviteSentAt']) != null
              ? DateTime.tryParse((t['invite_sent_at'] ?? t['inviteSentAt']) as String)
              : null,
        );
      }).toList();


      // Build and return the clean UserProfile
      final profile = _buildUserProfileFromMap(res, garage: garage, team: team);
      if (profile != null) {
        // Automatically sync clean fields to Supabase DB if it previously had dummy data
        final cleanAvatar = profile.avatarUrl;
        final cleanCover = profile.coverUrl;
        final cleanBio = profile.bio;
        final cleanLocation = profile.location;
        final cleanBusiness = profile.businessName;
        final cleanInstagram = profile.instagramHandle;
        final rawAvatar = res['avatar_url'] as String? ?? '';
        final rawCover = res['cover_url'] as String? ?? '';
        final rawLocation = res['location'] as String? ?? '';
        final rawBio = res['bio'] as String? ?? '';
        final rawBusiness = res['business_name'] as String? ?? '';
        final rawInstagram = res['instagram_handle'] as String? ?? '';

        if (cleanAvatar != rawAvatar || cleanCover != rawCover || cleanBio != rawBio || cleanLocation != rawLocation || cleanBusiness != rawBusiness || cleanInstagram != rawInstagram) {
          client.from('profiles').update({
            'avatar_url': cleanAvatar,
            'cover_url': cleanCover,
            'location': cleanLocation,
            'bio': cleanBio,
            'business_name': cleanBusiness,
            'instagram_handle': cleanInstagram,
          }).eq('id', userId).then((_) {}, onError: (_) {});
        }
      }
      return profile;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching profile: $e');
      return null;
    }
  }

  static UserProfile? _buildUserProfileFromMap(
    Map<String, dynamic> res, {
    List<Vehicle> garage = const [],
    List<TeamMember> team = const [],
  }) {
    try {
      // Fetch user's service packages if present; if empty/null, return empty list
      List<ServicePackage> packages = [];
      if (res['service_packages'] != null && res['service_packages'] is List) {
        try {
          final list = res['service_packages'] as List<dynamic>;
          if (list.isNotEmpty) {
            packages = list
                .map((p) => ServicePackage.fromJson(p as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }

      final roleStr = res['role'] as String?;
      UserRole parsedRole = UserRole.client;
      if (roleStr == 'superAdmin' || roleStr == 'super_admin') {
        parsedRole = UserRole.superAdmin;
      } else if (roleStr == 'detailer' || packages.isNotEmpty) {
        parsedRole = UserRole.detailer;
      }

      String? ownerPinHash = res['owner_pin_hash'] as String?;
      List<TeamMember> backupTeam = [];
      if (res['service_radius'] is String) {
        final sr = res['service_radius'] as String;
        if ((ownerPinHash == null || ownerPinHash.isEmpty) && sr.contains('||pin:')) {
          final afterPin = sr.split('||pin:').last;
          ownerPinHash = afterPin.split('||team:').first.trim();
        }
        if (sr.contains('||team:')) {
          try {
            final teamB64 = sr.split('||team:').last.trim();
            final decodedJson = utf8.decode(base64Decode(teamB64));
            final list = jsonDecode(decodedJson) as List<dynamic>;
            backupTeam = list
                .map((item) => TeamMember.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          } catch (_) {}
        }
      }
      final cleanServiceRadius = ((res['service_radius'] as String?) ?? '25 miles • Mobile & Studio')
          .split('||pin:')
          .first
          .split('||team:')
          .first
          .trim();

      // Merge team_members table rows with backupTeam so no staff or PINs are lost across devices
      final mergedTeamMap = <String, TeamMember>{
        for (final bm in backupTeam) bm.id: bm,
      };
      for (final tm in team) {
        final existing = mergedTeamMap[tm.id];
        if (existing != null) {
          mergedTeamMap[tm.id] = tm.copyWith(
            pin: (tm.pin != null && tm.pin!.isNotEmpty) ? tm.pin : existing.pin,
            email: (tm.email != null && tm.email!.isNotEmpty) ? tm.email : existing.email,
            allowedHubSections: tm.allowedHubSections ?? existing.allowedHubSections,
            customWeeklySchedule: tm.customWeeklySchedule ?? existing.customWeeklySchedule,
          );
        } else {
          mergedTeamMap[tm.id] = tm;
        }
      }
      final resolvedTeamList = mergedTeamMap.values.toList();

      final rawAvatar = res['avatar_url'] as String? ?? '';
      final cleanAvatar = (rawAvatar.contains('unsplash.com') && rawAvatar.contains('1535713875002')) ? '' : rawAvatar;

      final rawCover = res['cover_url'] as String? ?? '';
      final cleanCover = (rawCover.contains('unsplash.com') && rawCover.contains('1617814076367')) ? '' : rawCover;

      final rawLocation = res['location'] as String? ?? '';
      final cleanLocation = (rawLocation == 'Austin, Texas' && parsedRole == UserRole.client) ? '' : rawLocation;

      final rawBio = res['bio'] as String? ?? '';
      final cleanBio = (rawBio == 'Car enthusiast & detailing craft connoisseur.' || rawBio == 'Automotive enthusiast. Keeping paint in showroom condition.') ? '' : rawBio;

      final rawBusiness = res['business_name'] as String? ?? '';
      final cleanBusiness = (rawBusiness == 'My Detailing Studio' && parsedRole == UserRole.client) ? '' : rawBusiness;

      final rawInstagram = res['instagram_handle'] as String? ?? '';
      final cleanInstagram = (rawInstagram == '@detailcraft') ? '' : rawInstagram;

      double startingPrice = (res['starting_price'] as num?)?.toDouble() ?? 0.0;
      if (startingPrice <= 0.0 && packages.isNotEmpty) {
        startingPrice = packages.map((p) => p.price).reduce((a, b) => a < b ? a : b);
      }

      return UserProfile(
        id: res['id'] as String,
        role: parsedRole,
        username: (res['email'] as String?)?.split('@').first ?? 'user',
        displayName: res['display_name'] as String? ?? 'Vehicle Owner',
        businessName: cleanBusiness,
        avatarUrl: cleanAvatar,
        coverUrl: cleanCover,
        location: cleanLocation,
        serviceRadius: cleanServiceRadius,
        bio: cleanBio,
        phone: res['phone'] as String? ?? '',
        instagramHandle: cleanInstagram,
        isVerifiedHost: res['is_verified_host'] as bool? ?? (parsedRole == UserRole.detailer),
        isIdaCertified: res['is_ida_certified'] as bool? ?? false,
        isInsuranceVerified: res['is_insurance_verified'] as bool? ?? false,
        insurancePolicyNumber: res['insurance_policy_number'] as String? ?? '',
        servicePackages: packages,
        startingPrice: startingPrice,
        myGarage: garage,
        teamMembers: resolvedTeamList,
        totalJobsCount: res['total_jobs_count'] as int? ?? 0,
        averageRating: (res['rating'] as num?)?.toDouble() ?? 5.0,
        reviewCount: res['review_count'] as int? ?? 0,
        ownerPinHash: ownerPinHash,
      );
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error parsing UserProfile: $e');
      return null;
    }
  }

  /// Fetches all public registered detailers and studios from Supabase profiles in a single query.
  static Future<List<UserProfile>> fetchPublicDetailers() async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.from('profiles').select();
      final list = res as List<dynamic>;
      final profiles = <UserProfile>[];
      for (final item in list) {
        final profileMap = Map<String, dynamic>.from(item as Map);
        final role = profileMap['role'] as String?;
        final hasPackages = profileMap['service_packages'] is List &&
            (profileMap['service_packages'] as List).isNotEmpty;
        final isDetailer = role == 'detailer' ||
            role == 'super_admin' ||
            role == 'superAdmin' ||
            hasPackages;
        if (isDetailer) {
          final p = _buildUserProfileFromMap(profileMap);
          if (p != null) {
            profiles.add(p);
          }
        }
      }
      return profiles;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching public detailers: $e');
      return [];
    }
  }

  /// Upsert full user profile to Supabase
  static Future<void> saveUserProfile(UserProfile user) async {
    final client = _client;
    if (client == null) return;
    if (user.id == 'usr_you') return; // Mock guest user is not persisted to cloud DB

    try {
      String roleStr = 'client';
      if (user.role == UserRole.superAdmin) {
        roleStr = 'super_admin';
      } else if (user.role == UserRole.detailer) {
        roleStr = 'detailer';
      }

      final cleanRadius = user.serviceRadius
          .split('||pin:')
          .first
          .split('||team:')
          .first
          .trim();
      final StringBuffer radiusBuf = StringBuffer(cleanRadius);
      if (user.ownerPinHash != null && user.ownerPinHash!.isNotEmpty) {
        radiusBuf.write('||pin:${user.ownerPinHash}');
      }
      if (user.teamMembers.isNotEmpty) {
        try {
          final teamJson = jsonEncode(user.teamMembers.map((m) => m.toJson()).toList());
          final teamB64 = base64Encode(utf8.encode(teamJson));
          radiusBuf.write('||team:$teamB64');
        } catch (_) {}
      }
      final encodedRadius = radiusBuf.toString();

      await client.from('profiles').upsert({
        'id': user.id,
        'display_name': user.displayName,
        'business_name': user.businessName,
        'role': roleStr,
        'avatar_url': user.avatarUrl,
        'cover_url': user.coverUrl,
        'location': user.location,
        'service_radius': encodedRadius,
        'owner_pin_hash': user.ownerPinHash,
        'bio': user.bio,
        'phone': user.phone,
        'instagram_handle': user.instagramHandle,
        'is_verified_host': user.isVerifiedHost,
        'is_ida_certified': user.isIdaCertified,
        'is_insurance_verified': user.isInsuranceVerified,
        'insurance_policy_number': user.insurancePolicyNumber,
        'rating': user.averageRating,
        'review_count': user.reviewCount,
        'total_jobs_count': user.totalJobsCount,
        'starting_price': user.startingPrice,
        'service_packages': user.servicePackages.map((p) => p.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (user.myGarage.isNotEmpty) {
        for (final v in user.myGarage) {
          await saveVehicle(user.id, v);
        }
      }
      if (user.teamMembers.isNotEmpty) {
        for (final m in user.teamMembers) {
          await saveTeamMember(user.id, m);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving profile: $e');
    }
  }

  /// Permanently deletes the user's account and all associated cloud data from Supabase.
  static Future<void> deleteAccountFromCloud(String userId) async {
    final client = _client;
    if (client == null) return;
    if (userId == 'usr_you') return;

    try {
      // 1. Attempt server-side Postgres RPC function (purges auth.users & cascades)
      await client.rpc('delete_user_account');
      if (kDebugMode) print('[SupabaseDbService] Account permanently purged via RPC delete_user_account');
      return;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] RPC delete_user_account error (falling back to direct deletes): $e');
    }

    // 2. Direct table deletion fallback:
    try {
      await client.from('vehicles').delete().eq('user_id', userId);
    } catch (_) {}

    try {
      await client.from('team_members').delete().eq('studio_id', userId);
    } catch (_) {}

    try {
      await client.from('jobs').delete().eq('author_id', userId);
    } catch (_) {}

    try {
      await client.from('inventory_items').delete().eq('user_id', userId);
    } catch (_) {}

    try {
      await client.from('availability_blocks').delete().or('user_id.eq.$userId,detailer_id.eq.$userId');
    } catch (_) {}

    try {
      await client.from('profiles').delete().eq('id', userId);
      if (kDebugMode) print('[SupabaseDbService] Profile row deleted directly for $userId');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting profile row directly: $e');
    }
  }

  /// Submit a verification request (Insurance or IDA cert)
  static Future<void> submitVerificationRequest(VerificationRequest req) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('verification_requests').upsert(req.toJson());
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error submitting verification: $e');
    }
  }

  /// Fetch all verification requests (For Back Office Admins)
  static Future<List<VerificationRequest>> fetchVerificationRequests() async {
    final client = _client;
    if (client == null) return [];
    try {
      final res = await client.from('verification_requests').select().order('submitted_at', ascending: false);
      return (res as List<dynamic>).map((json) => VerificationRequest.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching verifications: $e');
      return [];
    }
  }

  /// Review (Approve or Reject) a verification request and update the detailer's profile badge
  static Future<void> reviewVerificationRequest({
    required String requestId,
    required String detailerUserId,
    required String docType,
    required VerificationStatus newStatus,
    required String reviewerNotes,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('verification_requests').update({
        'status': newStatus.name,
        'reviewer_notes': reviewerNotes,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      if (newStatus == VerificationStatus.approved) {
        if (docType == 'insurance') {
          await client.from('profiles').update({
            'is_insurance_verified': true,
          }).eq('id', detailerUserId);
        } else if (docType == 'ida_certification') {
          await client.from('profiles').update({
            'is_ida_certified': true,
          }).eq('id', detailerUserId);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error reviewing verification: $e');
    }
  }

  /// Upsert a vehicle to Supabase
  static Future<void> saveVehicle(String userId, UserVehicle v) async {
    final client = _client;
    if (client == null) return;

    try {
      final payload = <String, dynamic>{
        'id': v.id,
        'user_id': userId,
        'year': v.year,
        'make': v.make,
        'model': v.model,
        'paint_color': v.colorName,
        'paint_code': v.paintCode,
        'image_url': v.imageUrl,
      };
      if (v.lastDetailService != null) {
        payload['last_detail_service'] = v.lastDetailService;
      }
      if (v.lastDetailDate != null) {
        payload['last_detail_date'] = v.lastDetailDate!.toIso8601String();
      }
      await client.from('vehicles').upsert(payload);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving vehicle: $e');
    }
  }

  /// Delete a vehicle from Supabase
  static Future<void> deleteVehicle(String vehicleId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('vehicles').delete().eq('id', vehicleId);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting vehicle: $e');
    }
  }

  /// Upsert a team member to Supabase and sync hashed PIN/invite token via SECURITY DEFINER RPC
  static Future<void> saveTeamMember(String studioId, TeamMember m) async {
    final client = _client;
    if (client == null || studioId.isEmpty || studioId == 'usr_you') return;

    try {
      // Ensure parent studio profile row exists so the foreign key constraint on studio_id never fails
      final existingProfile =
          await client.from('profiles').select('id').eq('id', studioId).maybeSingle();
      if (existingProfile == null) {
        final authUser = client.auth.currentUser;
        await client.from('profiles').upsert({
          'id': studioId,
          'display_name': (authUser?.userMetadata?['display_name'] as String?) ??
              authUser?.email?.split('@').first ??
              'Studio Owner',
          'business_name': '',
          'role': 'detailer',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}

    final basePayload = <String, dynamic>{
      'id': m.id,
      'studio_id': studioId,
      'name': m.name,
      'role_title': m.roleTitle,
      'avatar_url': m.avatarUrl,
      'rating': m.rating,
      'completed_jobs_count': m.completedJobsCount,
      'is_available': m.isAvailable,
    };

    try {
      final fullPayload = <String, dynamic>{
        ...basePayload,
        'is_founder': m.isFounder,
        'can_edit_inventory': m.canEditInventory,
        'can_view_pricing': m.canViewPricing,
        'can_manage_team': m.canManageTeam,
        'can_view_all_team_calendar': m.canViewAllTeamCalendar,
        'invite_status': m.inviteStatus,
      };
      if (m.pin != null && m.pin!.trim().isNotEmpty) {
        fullPayload['pin'] = m.pin!.trim();
      }
      if (m.email != null) fullPayload['email'] = m.email;
      if (m.inviteSentAt != null) {
        fullPayload['invite_sent_at'] = m.inviteSentAt!.toIso8601String();
      }
      if (m.allowedHubSections != null) {
        fullPayload['allowed_hub_sections'] = m.allowedHubSections;
      }
      if (m.customWeeklySchedule != null) {
        fullPayload['custom_weekly_schedule'] =
            m.customWeeklySchedule!.map((h) => h.toJson()).toList();
      }
      await client.from('team_members').upsert(fullPayload);
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseDbService] Extended team_members upsert failed, falling back to base columns: $e');
      }
      try {
        await client.from('team_members').upsert(basePayload);
      } catch (fallbackErr) {
        if (kDebugMode) {
          print('[SupabaseDbService] Base team_members upsert failed: $fallbackErr');
        }
      }
    }

    // Sync PIN and invite token to server-side staff_security table (hashed via bcrypt/sha256)
    try {
      if ((m.pin != null && m.pin!.trim().isNotEmpty) ||
          (m.inviteToken != null && m.inviteToken!.trim().isNotEmpty)) {
        await client.rpc('upsert_staff_security', params: {
          'p_member_id': m.id,
          'p_studio_id': studioId,
          'p_pin': (m.pin != null && m.pin!.trim().isNotEmpty) ? m.pin!.trim() : null,
          'p_invite_token': (m.inviteToken != null && m.inviteToken!.trim().isNotEmpty && m.inviteStatus == 'pending')
              ? m.inviteToken!.trim()
              : null,
        });
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error syncing staff_security RPC: $e');
    }
  }

  static TeamMember _parseTeamMemberMap(Map<String, dynamic> t) {
    List<DayBusinessHours>? schedule;
    final schedRaw = t['custom_weekly_schedule'] ?? t['customWeeklySchedule'];
    if (schedRaw != null && schedRaw is List) {
      try {
        schedule = schedRaw
            .map((item) => DayBusinessHours.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {}
    }

    final sectionsRaw = t['allowed_hub_sections'] ?? t['allowedHubSections'];
    List<String>? allowedSections;
    if (sectionsRaw != null && sectionsRaw is List) {
      try {
        allowedSections = sectionsRaw.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return TeamMember(
      id: t['id'] as String,
      name: t['name'] as String,
      roleTitle: (t['role_title'] ?? t['roleTitle']) as String? ?? 'Detail Specialist',
      avatarUrl: (t['avatar_url'] ?? t['avatarUrl']) as String? ?? '',
      rating: (t['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobsCount: (t['completed_jobs_count'] ?? t['completedJobsCount']) as int? ?? 0,
      isAvailable: (t['is_available'] ?? t['isAvailable']) as bool? ?? true,
      isFounder: (t['is_founder'] ?? t['isFounder']) as bool? ?? false,
      customWeeklySchedule: schedule,
      allowedHubSections: allowedSections,
      canEditInventory: (t['can_edit_inventory'] ?? t['canEditInventory']) as bool? ?? true,
      canViewPricing: (t['can_view_pricing'] ?? t['canViewPricing']) as bool? ?? true,
      canManageTeam: (t['can_manage_team'] ?? t['canManageTeam']) as bool? ?? false,
      canViewAllTeamCalendar: (t['can_view_all_team_calendar'] ?? t['canViewAllTeamCalendar']) as bool? ?? true,
      email: t['email'] as String?,
      inviteStatus: (t['invite_status'] ?? t['inviteStatus']) as String? ?? 'none',
      inviteSentAt: (t['invite_sent_at'] ?? t['inviteSentAt']) != null
          ? DateTime.tryParse((t['invite_sent_at'] ?? t['inviteSentAt']) as String)
          : null,
    );
  }

  /// Verify staff Email + Password on Supabase server via verify_staff_login_rpc
  static Future<({TeamMember member, String studioId})?> findStaffMember({
    String? pin,
    String? email,
    String? password,
    String? memberId,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      if (pin != null && pin.trim().isNotEmpty && memberId != null && memberId.isNotEmpty) {
        final res = await client.rpc('verify_staff_pin_rpc', params: {
          'p_member_id': memberId,
          'p_pin': pin.trim(),
        });
        if (res is Map && res['ok'] == true && res['member'] != null && res['studio_id'] != null) {
          final member = _parseTeamMemberMap(Map<String, dynamic>.from(res['member'] as Map));
          return (member: member, studioId: res['studio_id'].toString());
        }
        return null;
      }

      if (email != null && email.trim().isNotEmpty && password != null && password.trim().isNotEmpty) {
        final res = await client.rpc('verify_staff_login_rpc', params: {
          'p_email': email.trim(),
          'p_password': password.trim(),
        });
        if (res is Map && res['ok'] == true && res['member'] != null && res['studio_id'] != null) {
          final member = _parseTeamMemberMap(Map<String, dynamic>.from(res['member'] as Map));
          return (member: member, studioId: res['studio_id'].toString());
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error verifying staff member via RPC: $e');
    }
    return null;
  }

  /// Accept a staff invite token and set password on the server via accept_staff_invite_rpc
  static Future<({TeamMember member, String studioId})?> acceptStaffInviteOnServer({
    required String token,
    required String newPassword,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('accept_staff_invite_rpc', params: {
        'p_token': token.trim(),
        'p_new_password': newPassword.trim(),
      });
      if (res is Map && res['ok'] == true && res['member'] != null && res['studio_id'] != null) {
        final member = _parseTeamMemberMap(Map<String, dynamic>.from(res['member'] as Map));
        return (member: member, studioId: res['studio_id'].toString());
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error in acceptStaffInviteOnServer: $e');
    }
    return null;
  }

  /// Delete a team member from Supabase
  static Future<void> deleteTeamMember(String memberId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('team_members').delete().eq('id', memberId);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting team member: $e');
    }
  }

  /// Upsert a shift request to Supabase
  static Future<void> saveShiftRequest(ShiftRequest req) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('shift_requests').upsert(req.toJson());
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving shift request: $e');
    }
  }

  /// Update shift request status
  static Future<void> updateShiftRequestStatus(String reqId, String status, {DateTime? reviewedAt, String? reviewerNotes}) async {
    final client = _client;
    if (client == null) return;

    try {
      final payload = <String, dynamic>{
        'status': status,
      };
      if (reviewedAt != null) payload['reviewed_at'] = reviewedAt.toIso8601String();
      if (reviewerNotes != null) payload['reviewer_notes'] = reviewerNotes;
      await client.from('shift_requests').update(payload).eq('id', reqId);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error updating shift request: $e');
    }
  }

  /// Fetch shift requests for a studio
  static Future<List<ShiftRequest>> fetchShiftRequests(String studioId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.from('shift_requests').select().eq('detailer_id', studioId);
      return (res as List<dynamic>).map((r) => ShiftRequest.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching shift requests: $e');
    }
    return [];
  }

  /// Upsert a transformation job record to Supabase
  static Future<void> saveJob(DetailJob job) async {
    final client = _client;
    if (client == null) return;

    try {
      final effectiveAuthorId = client.auth.currentUser?.id ?? job.author.id;
      final jobToSave = job.author.id != effectiveAuthorId
          ? job.copyWith(author: job.author.copyWith(id: effectiveAuthorId))
          : job;

      await client.from('jobs').upsert({
        'id': jobToSave.id,
        'author_id': effectiveAuthorId,
        'title': jobToSave.title,
        'description': jobToSave.description,
        'vehicle_year': jobToSave.vehicleYear,
        'vehicle_make': jobToSave.vehicleMake,
        'vehicle_model': jobToSave.vehicleModel,
        'paint_color': jobToSave.paintColorName,
        'service_type': jobToSave.serviceType,
        'before_image_url': jobToSave.beforeImageUrl,
        'after_image_url': jobToSave.afterImageUrl,
        'raw_data': jobToSave.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (kDebugMode) print('[SupabaseDbService] Job saved to Supabase: ${jobToSave.id} (author: $effectiveAuthorId)');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving job to Supabase: $e');
    }
  }

  /// Delete a transformation job from Supabase
  static Future<void> deleteJob(String jobId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('jobs').delete().eq('id', jobId);
      if (kDebugMode) print('[SupabaseDbService] Job deleted from Supabase: $jobId');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting job from Supabase: $e');
    }
  }

  /// Fetch jobs from Supabase
  static Future<List<DetailJob>> fetchJobs() async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.from('jobs').select().order('created_at', ascending: false);
      final List<dynamic> list = res as List<dynamic>;
      final jobs = <DetailJob>[];
      for (final item in list) {
        if (item['raw_data'] != null) {
          jobs.add(DetailJob.fromJson(item['raw_data'] as Map<String, dynamic>));
        }
      }
      return jobs;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching jobs: $e');
      return [];
    }
  }

  /// Save a job comment in Supabase
  static Future<void> saveJobComment(String jobId, JobComment comment, {DetailJob? currentJob}) async {
    final client = _client;
    if (client == null) return;

    try {
      if (currentJob != null) {
        await saveJob(currentJob);
        return;
      }
      final res = await client.from('jobs').select('raw_data').eq('id', jobId).maybeSingle();
      if (res != null && res['raw_data'] != null) {
        final raw = Map<String, dynamic>.from(res['raw_data'] as Map);
        final comments = List<dynamic>.from((raw['comments'] as List<dynamic>?) ?? []);
        comments.add(comment.toJson());
        raw['comments'] = comments;
        await client.from('jobs').update({
          'raw_data': raw,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', jobId);
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving job comment: $e');
    }
  }

  /// Fetch comments for a specific job from Supabase
  static Future<List<JobComment>> fetchJobComments(String jobId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.from('jobs').select('raw_data').eq('id', jobId).maybeSingle();
      if (res != null && res['raw_data'] != null) {
        final raw = res['raw_data'] as Map<String, dynamic>;
        final list = (raw['comments'] as List<dynamic>?) ?? [];
        return list.map((c) => JobComment.fromJson(c as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching job comments: $e');
    }
    return [];
  }

  /// Contract alias for saveJob
  static Future<void> saveCustomJob(DetailJob job) => saveJob(job);

  /// Fetch custom jobs optionally filtered by author
  static Future<List<DetailJob>> fetchCustomJobs({String? authorId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('jobs').select();
      if (authorId != null) {
        query = query.eq('author_id', authorId);
      }
      final res = await query.order('created_at', ascending: false);
      final jobs = <DetailJob>[];
      for (final item in (res as List<dynamic>)) {
        if (item['raw_data'] != null) {
          jobs.add(DetailJob.fromJson(item['raw_data'] as Map<String, dynamic>));
        }
      }
      return jobs;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching custom jobs: $e');
      return [];
    }
  }

  // ─── MESSAGING ────────────────────────────────────────────────────────────

  /// Returns or creates a conversation between two users.
  static Future<String?> createOrGetConversation(String userId, String otherUserId) async {
    final client = _client;
    if (client == null) return null;
    try {
      // Check both orderings since participant_a/b aren't ordered
      final existing = await client
          .from('conversations')
          .select('id')
          .or('and(participant_a.eq.$userId,participant_b.eq.$otherUserId),and(participant_a.eq.$otherUserId,participant_b.eq.$userId)')
          .maybeSingle();
      if (existing != null) return existing['id'] as String;

      // Create new conversation
      final res = await client.from('conversations').insert({
        'participant_a': userId,
        'participant_b': otherUserId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      return res['id'] as String;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] createOrGetConversation error: $e');
      return null;
    }
  }

  /// Fetches all conversations for a user, enriched with the other user's profile info.
  static Future<List<Conversation>> fetchConversations(String userId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final res = await client
          .from('conversations')
          .select()
          .or('participant_a.eq.$userId,participant_b.eq.$userId')
          .order('updated_at', ascending: false);

      final List<dynamic> rows = res as List<dynamic>;
      final conversations = <Conversation>[];

      for (final row in rows) {
        var conv = Conversation.fromJson(row as Map<String, dynamic>);
        final otherId = conv.participantA == userId ? conv.participantB : conv.participantA;

        // Fetch the other participant's profile
        try {
          final profile = await client.from('profiles').select('display_name, business_name, avatar_url, role').eq('id', otherId).maybeSingle();
          if (profile != null) {
            final isDetailer = (profile['role'] as String?) == 'detailer';
            final name = isDetailer
                ? (profile['business_name'] as String? ?? profile['display_name'] as String? ?? 'User')
                : (profile['display_name'] as String? ?? 'User');
            conv = conv.copyWith(
              otherUserName: name,
              otherUserAvatar: profile['avatar_url'] as String? ?? '',
            );
          }
        } catch (_) {}

        // Fallback to public detailers if not in Supabase profiles (e.g. mock detailers)
        if (conv.otherUserName.isEmpty || conv.otherUserName == 'User') {
          final match = MockDataService.publicDetailers.where((d) => d.id == otherId);
          if (match.isNotEmpty) {
            final d = match.first;
            conv = conv.copyWith(
              otherUserName: d.businessName.isNotEmpty ? d.businessName : d.displayName,
              otherUserAvatar: d.avatarUrl,
            );
          }
        }

        // Fetch last message
        try {
          final lastMsg = await client
              .from('messages')
              .select()
              .eq('conversation_id', conv.id)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (lastMsg != null) {
            conv = conv.copyWith(lastMessage: DirectMessage.fromJson(lastMsg));
          }
        } catch (_) {}

        // Fetch unread count
        try {
          final unreadRes = await client
              .from('messages')
              .select()
              .eq('conversation_id', conv.id)
              .eq('is_read', false)
              .neq('sender_id', userId);
          conv = conv.copyWith(unreadCount: (unreadRes as List).length);
        } catch (_) {}

        conversations.add(conv);
      }

      return conversations;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] fetchConversations error: $e');
      return [];
    }
  }

  /// Fetches all messages for a conversation.
  static Future<List<DirectMessage>> fetchMessages(String conversationId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final res = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return (res as List<dynamic>)
          .map((m) => DirectMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] fetchMessages error: $e');
      return [];
    }
  }

  /// Sends a message and bumps the conversation updated_at.
  static Future<DirectMessage?> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      }).select().single();

      // Bump conversation updated_at for sorting
      await client.from('conversations').update({
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversationId);

      return DirectMessage.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] sendMessage error: $e');
      return null;
    }
  }

  /// Marks all received messages in a conversation as read.
  static Future<void> markMessagesAsRead(String conversationId, String userId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] markMessagesAsRead error: $e');
    }
  }

  // ─── BOOKINGS ─────────────────────────────────────────────────────────────

  /// Upsert a booking appointment to Supabase
  static Future<void> saveBooking(BookingAppointment booking) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('bookings').upsert({
        'id': booking.id,
        'client_id': booking.clientId,
        'detailer_id': booking.detailerId,
        'detailer_name': booking.detailerName,
        'detailer_business_name': booking.detailerBusinessName,
        'detailer_avatar': booking.detailerAvatar,
        'client_name': booking.clientName,
        'client_phone': booking.clientPhone,
        'client_email': booking.clientEmail,
        'vehicle_year_make_model': booking.vehicleYearMakeModel,
        'vehicle_size': booking.vehicleSize.name,
        'package': booking.package.toJson(),
        'location_type': booking.locationType.name,
        'client_address': booking.clientAddress,
        'scheduled_date': booking.scheduledDate.toIso8601String(),
        'scheduled_time_slot': booking.scheduledTimeSlot,
        'total_price': booking.totalPrice,
        'deposit_amount': booking.depositAmount,
        'status': booking.status.name,
        'client_notes': booking.clientNotes,
        'pre_inspection_summary': booking.preInspectionSummary,
        'warranty_passport_id': booking.warrantyPassportId,
        if (booking.assignedTeamMemberId != null)
          'assigned_team_member_id': booking.assignedTeamMemberId,
        if (booking.assignedTeamMemberName != null)
          'assigned_team_member_name': booking.assignedTeamMemberName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (kDebugMode) print('[SupabaseDbService] Booking saved to Supabase: ${booking.id}');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving booking: $e');
    }
  }

  /// Fetches bookings related to a user (either as client or as detailer)
  static Future<List<BookingAppointment>> fetchBookings(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client
          .from('bookings')
          .select()
          .or('client_id.eq.$userId,detailer_id.eq.$userId')
          .order('scheduled_date', ascending: false);

      final List<dynamic> list = res as List<dynamic>;
      final bookings = <BookingAppointment>[];
      for (final item in list) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['assignedTeamMemberId'] == null && map['assigned_team_member_id'] != null) {
          map['assignedTeamMemberId'] = map['assigned_team_member_id'];
        }
        if (map['assignedTeamMemberName'] == null && map['assigned_team_member_name'] != null) {
          map['assignedTeamMemberName'] = map['assigned_team_member_name'];
        }
        bookings.add(BookingAppointment.fromJson(map));
      }
      return bookings;
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching bookings: $e');
      return [];
    }
  }

  /// Updates the status of a booking appointment in Supabase
  static Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('bookings').update({
        'status': newStatus.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);
      if (kDebugMode) print('[SupabaseDbService] Updated booking status: $bookingId -> ${newStatus.name}');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error updating booking status: $e');
    }
  }

  // ─── USER INTERACTIONS (LIKES & SAVES) ────────────────────────────────────

  /// Upsert user's liked and saved job interactions
  static Future<void> saveUserInteractions({
    required String userId,
    required Set<String> likedJobIds,
    required Set<String> savedJobIds,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('user_interactions').upsert({
        'user_id': userId,
        'liked_job_ids': likedJobIds.toList(),
        'saved_job_ids': savedJobIds.toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving user interactions: $e');
    }
  }

  /// Fetches user's liked and saved job interactions from Supabase
  static Future<({Set<String> likedJobIds, Set<String> savedJobIds})?> fetchUserInteractions(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.from('user_interactions').select().eq('user_id', userId).maybeSingle();
      if (res == null) return null;

      final likedList = res['liked_job_ids'] as List<dynamic>?;
      final savedList = res['saved_job_ids'] as List<dynamic>?;

      final liked = likedList?.map((e) => e.toString()).toSet() ?? <String>{};
      final saved = savedList?.map((e) => e.toString()).toSet() ?? <String>{};

      return (likedJobIds: liked, savedJobIds: saved);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching user interactions: $e');
      return null;
    }
  }

  // ─── INVENTORY ITEMS ──────────────────────────────────────────────────────

  /// Fetch user's inventory items from Supabase
  static Future<List<InventoryItem>> fetchInventoryItems(String studioId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.from('inventory_items').select().eq('studio_id', studioId);
      final List<dynamic> list = res as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['raw_data'] != null && map['raw_data'] is Map) {
          return InventoryItem.fromJson(Map<String, dynamic>.from(map['raw_data'] as Map));
        }
        return InventoryItem.fromJson(map);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching inventory items: $e');
      return [];
    }
  }

  /// Upsert an inventory item to Supabase
  static Future<void> saveInventoryItem(String studioId, InventoryItem item) async {
    final client = _client;
    if (client == null) return;

    try {
      final payload = <String, dynamic>{
        'id': item.id,
        'studio_id': studioId,
        'name': item.name,
        'category': item.category.name,
        'brand': item.brand,
        'sub_category': item.subCategory,
        'status': item.status,
        'location': item.location,
        'raw_data': item.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await client.from('inventory_items').upsert(payload);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving inventory item: $e');
    }
  }

  /// Delete an inventory item from Supabase
  static Future<void> deleteInventoryItem(String itemId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('inventory_items').delete().eq('id', itemId);
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting inventory item: $e');
    }
  }

  // ─── CALENDAR PREFERENCES & AVAILABILITY BLOCKS ──────────────────────────

  /// Upsert detailer calendar operating hours and booking preferences
  static Future<void> saveCalendarPreferences(String detailerId, DetailerCalendarPreferences preferences) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('profiles').update({
        'calendar_preferences': preferences.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', detailerId);
      if (kDebugMode) print('[SupabaseDbService] Calendar preferences saved for: $detailerId');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Note: calendar_preferences column not yet in profiles or offline: $e');
    }
  }

  /// Upsert a calendar availability block (Day or Slot block)
  static Future<void> saveAvailabilityBlock(CalendarAvailabilityBlock block) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('availability_blocks').upsert(block.toJson());
      if (kDebugMode) print('[SupabaseDbService] Availability block saved: ${block.id}');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Note: availability_blocks table not yet configured or offline: $e');
    }
  }

  /// Delete an availability block
  static Future<void> deleteAvailabilityBlock(String blockId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('availability_blocks').delete().eq('id', blockId);
      if (kDebugMode) print('[SupabaseDbService] Availability block deleted: $blockId');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error deleting availability block: $e');
    }
  }

  // --- OWNER MASTER PIN (server-authoritative, bcrypt-hashed) ---

  /// Returns the RPC JSON map, or null when offline / not authenticated / not deployed.
  static Future<Map<String, dynamic>?> _ownerPinRpc(String fn, [Map<String, dynamic>? params]) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return null;
    try {
      final res = await client.rpc(fn, params: params);
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['error'] == 'not_authenticated') return null;
        return map;
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Owner PIN RPC $fn unavailable: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> ownerPinStatus() => _ownerPinRpc('owner_pin_status');

  static Future<Map<String, dynamic>?> setOwnerPin({String? currentPin, required String newPin}) =>
      _ownerPinRpc('set_owner_pin', {'p_current': currentPin, 'p_new': newPin});

  static Future<Map<String, dynamic>?> verifyOwnerPin(String pin) =>
      _ownerPinRpc('verify_owner_pin', {'p_pin': pin});
}

