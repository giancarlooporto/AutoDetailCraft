import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/user_vehicle.dart';
import '../models/team_member.dart';
import '../models/detail_job.dart';
import '../models/booking_models.dart';
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

      // Fetch user's service packages if present, otherwise default to standardPackages
      List<ServicePackage> packages = MockDataService.standardPackages;
      if (res['service_packages'] != null && res['service_packages'] is List) {
        try {
          final list = res['service_packages'] as List<dynamic>;
          if (list.isNotEmpty) {
            packages = list.map((p) => ServicePackage.fromJson(p as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }

      final subscriptionTierStr = res['subscription_tier'] as String?;
      final subscriptionTier = SubscriptionTier.values.firstWhere(
        (t) => t.name == subscriptionTierStr,
        orElse: () => SubscriptionTier.free,
      );

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
        servicePackages: packages,
        startingPrice: (res['starting_price'] as num?)?.toDouble() ?? 150.0,
        subscriptionTier: subscriptionTier,
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
        'starting_price': user.startingPrice,
        'subscription_tier': user.subscriptionTier.name,
        'service_packages': user.servicePackages.map((p) => p.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('[SupabaseDbService] Error saving profile: $e');
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
        bookings.add(BookingAppointment.fromJson(item as Map<String, dynamic>));
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
}

