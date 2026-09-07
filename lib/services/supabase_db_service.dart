import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/user_vehicle.dart';
import '../models/team_member.dart';
import '../models/detail_job.dart';
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
        return UserVehicle(
          id: v['id'] as String,
          year: v['year'] as int,
          make: v['make'] as String,
          model: v['model'] as String,
          colorName: v['paint_color'] as String? ?? '',
          paintCode: v['paint_code'] as String?,
          imageUrl: v['image_url'] as String? ?? '',
        );
      }).toList();

      // Fetch user's team members
      final teamRes = await client.from('team_members').select().eq('studio_id', userId);
      final List<TeamMember> team = (teamRes as List<dynamic>).map<TeamMember>((t) {
        return TeamMember(
          id: t['id'] as String,
          name: t['name'] as String,
          roleTitle: t['role_title'] as String,
          avatarUrl: t['avatar_url'] as String? ?? '',
          rating: (t['rating'] as num?)?.toDouble() ?? 5.0,
          completedJobsCount: t['completed_jobs_count'] as int? ?? 0,
          isAvailable: t['is_available'] as bool? ?? true,
        );
      }).toList();

      return UserProfile(
        id: res['id'] as String,
        role: (res['role'] as String?) == 'detailer' ? UserRole.detailer : UserRole.client,
        username: (res['email'] as String?)?.split('@').first ?? 'user',
        displayName: res['display_name'] as String? ?? 'Vehicle Owner',
        businessName: res['business_name'] as String? ?? 'My Detailing Studio',
        avatarUrl: res['avatar_url'] as String? ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
        coverUrl: res['cover_url'] as String? ?? 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
        location: res['location'] as String? ?? 'Austin, Texas',
        serviceRadius: res['service_radius'] as String? ?? '25 miles • Mobile & Studio',
        bio: res['bio'] as String? ?? 'Car enthusiast & detailing craft connoisseur.',
        phone: res['phone'] as String? ?? '',
        instagramHandle: res['instagram_handle'] as String? ?? '@detailcraft',
        isVerifiedHost: res['is_verified_host'] as bool? ?? false,
        isIdaCertified: res['is_ida_certified'] as bool? ?? false,
        servicePackages: MockDataService.standardPackages,
        myGarage: garage,
        teamMembers: team,
        totalJobsCount: res['total_jobs_count'] as int? ?? 0,
        averageRating: (res['rating'] as num?)?.toDouble() ?? 5.0,
        reviewCount: res['review_count'] as int? ?? 0,
      );
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error fetching profile: $e');
      return null;
    }
  }

  /// Upsert full user profile to Supabase
  static Future<void> saveUserProfile(UserProfile user) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'display_name': user.displayName,
        'business_name': user.businessName,
        'role': user.role == UserRole.detailer ? 'detailer' : 'client',
        'avatar_url': user.avatarUrl,
        'cover_url': user.coverUrl,
        'location': user.location,
        'service_radius': user.serviceRadius,
        'bio': user.bio,
        'phone': user.phone,
        'instagram_handle': user.instagramHandle,
        'is_verified_host': user.isVerifiedHost,
        'is_ida_certified': user.isIdaCertified,
        'rating': user.averageRating,
        'review_count': user.reviewCount,
        'total_jobs_count': user.totalJobsCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (kDebugMode) print('[SupabaseDbService] Profile synced to Supabase for ${user.id}');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving profile to Supabase: $e');
    }
  }

  /// Upsert a vehicle to Supabase
  static Future<void> saveVehicle(String userId, UserVehicle v) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('vehicles').upsert({
        'id': v.id,
        'user_id': userId,
        'year': v.year,
        'make': v.make,
        'model': v.model,
        'paint_color': v.colorName,
        'paint_code': v.paintCode,
        'image_url': v.imageUrl,
      });
      if (kDebugMode) print('[SupabaseDbService] Vehicle synced to Supabase: ${v.fullName}');
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

  /// Upsert a team member to Supabase
  static Future<void> saveTeamMember(String studioId, TeamMember m) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('team_members').upsert({
        'id': m.id,
        'studio_id': studioId,
        'name': m.name,
        'role_title': m.roleTitle,
        'avatar_url': m.avatarUrl,
        'rating': m.rating,
        'completed_jobs_count': m.completedJobsCount,
        'is_available': m.isAvailable,
      });
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving team member: $e');
    }
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

  /// Upsert a transformation job record to Supabase
  static Future<void> saveJob(DetailJob job) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('jobs').upsert({
        'id': job.id,
        'author_id': job.author.id,
        'title': job.title,
        'description': job.description,
        'vehicle_year': job.vehicleYear,
        'vehicle_make': job.vehicleMake,
        'vehicle_model': job.vehicleModel,
        'paint_color': job.paintColorName,
        'service_type': job.serviceType,
        'before_image_url': job.beforeImageUrl,
        'after_image_url': job.afterImageUrl,
        'raw_data': job.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (kDebugMode) print('[SupabaseDbService] Job saved to Supabase: ${job.id}');
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving job to Supabase: $e');
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
}
