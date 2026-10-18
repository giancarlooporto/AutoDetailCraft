import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/detail_job.dart';
import '../models/message_model.dart';
import '../models/inventory_item.dart';
import '../models/calendar_availability_block.dart';
import '../models/user_vehicle.dart';
import '../models/team_member.dart';
import '../models/shift_request.dart';
import '../core/constants/detailing_presets.dart';

class LocalStorageService {
  static const String _userKeyPrefix = 'adc_user_state_v3_';
  static const String _lastActiveUserKey = 'adc_last_active_user_id_v1';
  static const String _servicePackagesKey = 'adc_service_packages_v1';
  static const String _garageVehiclesKey = 'adc_garage_vehicles_v1';
  static const String _teamMembersKey = 'adc_team_members_v1';
  static const String _shiftRequestsKey = 'adc_shift_requests_v1';
  static const String _activeTeamMemberIdKey = 'adc_active_team_member_id_v1';
  static const String _isStaffSessionKey = 'adc_is_staff_session_v1';
  static const String _inventoryKey = 'adc_inventory_items_v1';
  static const String _calendarBlocksKey = 'adc_calendar_blocks_v1';
  static const String _calendarPrefsKey = 'adc_calendar_prefs_v1';
  static const String _bookingsKey = 'adc_bookings_v1';
  static const String _legacyBookingsKey = 'adc_bookings_state_v3';
  static const String _jobCommentsKey = 'adc_job_comments_v1';
  static const String _mockJobOverridesKey = 'adc_mock_job_overrides_v1';
  static const String _customJobsKey = 'adc_custom_jobs_v1';
  static const String _customPresetsKey = 'adc_custom_presets_v1';
  static const String _savedJobsKey = 'adc_saved_jobs_v3';
  static const String _likedJobsKey = 'adc_liked_jobs_v1';
  static const String _legacyLikedJobsKey = 'adc_liked_jobs_v3';
  static const String _jobLikeCountsKey = 'adc_job_like_counts_v1';
  static const String _activeTabKey = 'adc_active_tab_index_v1';
  static const String _isGuestKey = 'adc_is_guest_mode_v1';
  static const String _siteAccessUnlockedKey = 'adc_site_access_unlocked_v1';
  static const String _conversationsKey = 'adc_conversations_v1';
  static const String _messagesKeyPrefix = 'adc_messages_v1_';
  static const String _workbenchModeKey = 'adc_workbench_mode_v1';
  static const String _studioHubSectionKey = 'adc_studio_hub_section_v1';
  static const String _inventoryCategoryFilterKey = 'adc_inventory_category_filter_v1';
  static const String _selectedInventoryIdKey = 'adc_selected_inventory_id_v1';
  static const String _ownerPinKey = 'adc_owner_pin_v1';
  static const String _isOwnerLockedKey = 'adc_is_owner_locked_v1';
  static const String _ownerAutoLockMinutesKey = 'adc_owner_auto_lock_minutes_v1';

  // Site Access Gate
  static Future<bool> isSiteUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_siteAccessUnlockedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveSiteUnlocked(bool unlocked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_siteAccessUnlockedKey, unlocked);
    } catch (_) {}
  }

  // Guest mode flag
  static Future<void> saveIsGuest(bool isGuest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isGuestKey, isGuest);
    } catch (_) {}
  }

  static Future<bool> loadIsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isGuestKey) ?? true; // First visit is Guest by default!
    } catch (_) {
      return true;
    }
  }

  // Logout only sets guest mode to true; it does NOT wipe your profile!
  static Future<void> logoutSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isGuestKey, true);
      await prefs.remove(_activeTeamMemberIdKey);
      await prefs.remove(_isStaffSessionKey);
      await prefs.remove(_isOwnerLockedKey);
    } catch (_) {}
  }

  // Permanent account deletion wipes stored data for that user
  static Future<void> deleteAccountData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_userKeyPrefix$userId');
      await prefs.remove(_bookingsKey);
      await prefs.remove(_lastActiveUserKey);
      await prefs.setBool(_isGuestKey, true);
    } catch (_) {}
  }

  // Save active navigation tab index
  static Future<void> saveActiveTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_activeTabKey, index);
    } catch (_) {}
  }

  static Future<int> loadActiveTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_activeTabKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Save user profile keyed by userId
  static Future<bool> saveCurrentUser(UserProfile user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_userKeyPrefix${user.id}';
      final jsonStr = jsonEncode(user.toJson());
      await prefs.setString(_lastActiveUserKey, user.id);
      final success = await prefs.setString(key, jsonStr);
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved user to $key: success=$success');
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] CRITICAL Error saving user: $e');
      }
      return false;
    }
  }

  // Load user profile for a specific user ID, or the last active user
  static Future<UserProfile?> loadUserById(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_userKeyPrefix$userId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading user $userId: $e');
      }
    }
    return null;
  }

  static Future<UserProfile?> loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastActiveUserKey);
      if (lastId != null && lastId.isNotEmpty) {
        return await loadUserById(lastId);
      }
    } catch (_) {}
    return null;
  }

  // Save bookings list
  static Future<void> saveBookings(List<BookingAppointment> bookings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = bookings.map((b) => b.toJson()).toList();
      final encoded = jsonEncode(list);
      await prefs.setString(_bookingsKey, encoded);
      await prefs.setString(_legacyBookingsKey, encoded);
    } catch (_) {}
  }

  // Load bookings list with smooth legacy migration
  static Future<List<BookingAppointment>?> loadBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var jsonStr = prefs.getString(_bookingsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        final legacyStr = prefs.getString(_legacyBookingsKey);
        if (legacyStr != null && legacyStr.isNotEmpty) {
          jsonStr = legacyStr;
          // Smooth migration: persist into dedicated _bookingsKey
          await prefs.setString(_bookingsKey, legacyStr);
        }
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => BookingAppointment.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    } catch (_) {}
    return null;
  }

  // Save liked and saved job IDs with dual-key synchronization (adc_liked_jobs_v1 and adc_liked_jobs_v3)
  static Future<void> saveInteractionState({
    required Set<String> likedJobIds,
    required Set<String> savedJobIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedList = likedJobIds.toList();
      await prefs.setStringList(_likedJobsKey, likedList);
      await prefs.setStringList(_legacyLikedJobsKey, likedList);
      await prefs.setStringList(_savedJobsKey, savedJobIds.toList());
    } catch (_) {}
  }

  static Future<({Set<String> likedJobIds, Set<String> savedJobIds})> loadInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var likedList = prefs.getStringList(_likedJobsKey);
      if (likedList == null || likedList.isEmpty) {
        likedList = prefs.getStringList(_legacyLikedJobsKey);
      }
      final liked = likedList?.toSet() ?? {};
      final saved = prefs.getStringList(_savedJobsKey)?.toSet() ?? {};
      return (likedJobIds: liked, savedJobIds: saved);
    } catch (_) {
      return (likedJobIds: <String>{}, savedJobIds: <String>{});
    }
  }

  // Save Job Like Counts Map (adc_job_like_counts_v1)
  static Future<void> saveJobLikeCounts(Map<String, int> counts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(counts);
      await prefs.setString(_jobLikeCountsKey, encoded);
    } catch (_) {}
  }

  // Load Job Like Counts Map (adc_job_like_counts_v1)
  static Future<Map<String, int>> loadJobLikeCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_jobLikeCountsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }

  // Save custom user-created jobs
  static Future<void> saveCustomJobs(List<DetailJob> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = jobs.map((j) => j.toJson()).toList();
      await prefs.setString(_customJobsKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${jobs.length} custom jobs.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving custom jobs: $e');
      }
    }
  }

  // Load custom user-created jobs
  static Future<List<DetailJob>> loadCustomJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_customJobsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => DetailJob.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading custom jobs: $e');
      }
    }
    return [];
  }

  // Save conversations list locally
  static Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = conversations.map((c) => c.toJson()).toList();
      await prefs.setString(_conversationsKey, jsonEncode(list));
    } catch (_) {}
  }

  // Load conversations list locally
  static Future<List<Conversation>> loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_conversationsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => Conversation.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Save messages for a conversation locally
  static Future<void> saveMessages(String conversationId, List<DirectMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = messages.map((m) => m.toJson()).toList();
      await prefs.setString('$_messagesKeyPrefix$conversationId', jsonEncode(list));
    } catch (_) {}
  }

  // Load messages for a conversation locally
  static Future<List<DirectMessage>> loadMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_messagesKeyPrefix$conversationId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => DirectMessage.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Save custom studio recipe presets
  static Future<void> saveCustomPresets(List<StudioRecipePreset> presets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = presets.map((p) => p.toJson()).toList();
      await prefs.setString(_customPresetsKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${presets.length} custom presets.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving custom presets: $e');
      }
    }
  }

  // Load custom studio recipe presets
  static Future<List<StudioRecipePreset>> loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_customPresetsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => StudioRecipePreset.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading custom presets: $e');
      }
    }
    return [];
  }

  // Save Inventory Items (Hardware, Chemicals, Recipes)
  static Future<void> saveInventoryItems(List<InventoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = items.map((i) => i.toJson()).toList();
      await prefs.setString(_inventoryKey, jsonEncode(list));
    } catch (_) {}
  }

  // Load Inventory Items
  static Future<List<InventoryItem>?> loadInventoryItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_inventoryKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => InventoryItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  // Save Calendar Availability Blocks
  static Future<void> saveAvailabilityBlocks(List<CalendarAvailabilityBlock> blocks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = blocks.map((b) => b.toJson()).toList();
      await prefs.setString(_calendarBlocksKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${blocks.length} calendar availability blocks.');
      }
    } catch (_) {}
  }

  // Load Calendar Availability Blocks
  static Future<List<CalendarAvailabilityBlock>?> loadAvailabilityBlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_calendarBlocksKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => CalendarAvailabilityBlock.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  // Save Calendar Preferences
  static Future<void> saveCalendarPreferences(DetailerCalendarPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_calendarPrefsKey, jsonEncode(preferences.toJson()));
    } catch (_) {}
  }

  // Load Calendar Preferences
  static Future<DetailerCalendarPreferences?> loadCalendarPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_calendarPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return DetailerCalendarPreferences.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // Active Workbench Mode ('studio' vs 'garage')
  static Future<void> saveWorkbenchMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_workbenchModeKey, mode);
    } catch (_) {}
  }

  static Future<String?> loadWorkbenchMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_workbenchModeKey);
    } catch (_) {
      return null;
    }
  }

  // Active Studio Hub Section (e.g. 'portfolio', 'calendar', 'services', etc.)
  static Future<void> saveStudioHubSection(String sectionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_studioHubSectionKey, sectionName);
    } catch (_) {}
  }

  static Future<String?> loadStudioHubSection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_studioHubSectionKey);
    } catch (_) {
      return null;
    }
  }

  // Active Inventory Category Filter ('HARDWARE', 'CHEMICALS', 'RECIPE')
  static Future<void> saveInventoryCategoryFilter(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_inventoryCategoryFilterKey, category);
    } catch (_) {}
  }

  static Future<String?> loadInventoryCategoryFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_inventoryCategoryFilterKey);
    } catch (_) {
      return null;
    }
  }

  // Active Selected Inventory Item ID
  static Future<void> saveSelectedInventoryId(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedInventoryIdKey, itemId);
    } catch (_) {}
  }

  static Future<String?> loadSelectedInventoryId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedInventoryIdKey);
    } catch (_) {
      return null;
    }
  }

  // Save Service Packages (adc_service_packages_v1)
  static Future<void> saveServicePackages(List<ServicePackage> packages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = packages.map((p) => p.toJson()).toList();
      await prefs.setString(_servicePackagesKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${packages.length} service packages.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving service packages: $e');
      }
    }
  }

  // Load Service Packages (adc_service_packages_v1)
  static Future<List<ServicePackage>> loadServicePackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_servicePackagesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => ServicePackage.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading service packages: $e');
      }
    }
    return [];
  }

  // Save Garage Vehicles (adc_garage_vehicles_v1)
  static Future<void> saveGarageVehicles(List<UserVehicle> vehicles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = vehicles.map((v) => v.toJson()).toList();
      await prefs.setString(_garageVehiclesKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${vehicles.length} garage vehicles.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving garage vehicles: $e');
      }
    }
  }

  // Load Garage Vehicles (adc_garage_vehicles_v1)
  static Future<List<UserVehicle>> loadGarageVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_garageVehiclesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => UserVehicle.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading garage vehicles: $e');
      }
    }
    return [];
  }

  // Save Team Members (adc_team_members_v1)
  static Future<void> saveTeamMembers(List<TeamMember> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = members.map((m) => m.toJson()).toList();
      await prefs.setString(_teamMembersKey, jsonEncode(list));
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${members.length} team members.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving team members: $e');
      }
    }
  }

  // Load Team Members (adc_team_members_v1)
  static Future<List<TeamMember>> loadTeamMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_teamMembersKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => TeamMember.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading team members: $e');
      }
    }
    return [];
  }

  // Shift Requests (adc_shift_requests_v1)
  static Future<void> saveShiftRequests(List<ShiftRequest> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(requests.map((r) => r.toJson()).toList());
      await prefs.setString(_shiftRequestsKey, encoded);
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved ${requests.length} shift requests.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving shift requests: $e');
      }
    }
  }

  static Future<List<ShiftRequest>> loadShiftRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_shiftRequestsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => ShiftRequest.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading shift requests: $e');
      }
    }
    return [];
  }

  // Active Team Member Session Switcher (adc_active_team_member_id_v1)
  static Future<void> saveActiveTeamMemberId(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null || id.isEmpty || id == 'founder') {
        await prefs.remove(_activeTeamMemberIdKey);
      } else {
        await prefs.setString(_activeTeamMemberIdKey, id);
      }
    } catch (_) {}
  }

  static Future<String?> loadActiveTeamMemberId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeTeamMemberIdKey);
    } catch (_) {
      return null;
    }
  }

  // Staff Member Direct Session Flag (adc_is_staff_session_v1)
  static Future<void> saveIsStaffSession(bool isStaffSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isStaffSession) {
        await prefs.remove(_isStaffSessionKey);
      } else {
        await prefs.setBool(_isStaffSessionKey, true);
      }
    } catch (_) {}
  }

  static Future<bool> loadIsStaffSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isStaffSessionKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  // Owner Master PIN & Security Lock
  static Future<void> saveOwnerPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ownerPinKey, pin);
    } catch (_) {}
  }

  static Future<String?> loadOwnerPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ownerPinKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveIsOwnerLocked(bool isLocked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isLocked) {
        await prefs.remove(_isOwnerLockedKey);
      } else {
        await prefs.setBool(_isOwnerLockedKey, true);
      }
    } catch (_) {}
  }

  static Future<bool> loadIsOwnerLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isOwnerLockedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveOwnerAutoLockMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ownerAutoLockMinutesKey, minutes);
    } catch (_) {}
  }

  static Future<int> loadOwnerAutoLockMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_ownerAutoLockMinutesKey) ?? 5; // Default 5 minutes auto-lock
    } catch (_) {
      return 5;
    }
  }

  // Save Job Comments Override with dual-key synchronization (adc_job_comments_v1 and adc_mock_job_overrides_v1)
  static Future<void> saveJobCommentsOverride(String jobId, List<JobComment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentMap = await loadJobCommentsOverrides();
      currentMap[jobId] = comments;
      final encoded = jsonEncode(currentMap.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())));
      await prefs.setString(_jobCommentsKey, encoded);
      await prefs.setString(_mockJobOverridesKey, encoded);
      if (kDebugMode) {
        print('[LocalStorageService] Saved comment override for job $jobId (${comments.length} comments).');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error saving job comments override: $e');
      }
    }
  }

  // Load Job Comments Overrides (reading adc_job_comments_v1 with fallback to adc_mock_job_overrides_v1)
  static Future<Map<String, List<JobComment>>> loadJobCommentsOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var jsonStr = prefs.getString(_jobCommentsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = prefs.getString(_mockJobOverridesKey);
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((k, v) {
          final list = (v as List<dynamic>).map((c) => JobComment.fromJson(c as Map<String, dynamic>)).toList();
          return MapEntry(k, list);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LocalStorageService] Error loading job comments overrides: $e');
      }
    }
    return {};
  }

  // Convenience helper to load comments for a single job
  static Future<List<JobComment>?> loadJobComments(String jobId) async {
    final overrides = await loadJobCommentsOverrides();
    return overrides[jobId];
  }

  // Calendar Blocks Contract Aliases
  static Future<void> saveCalendarBlocks(List<CalendarAvailabilityBlock> blocks) => saveAvailabilityBlocks(blocks);
  static Future<List<CalendarAvailabilityBlock>> loadCalendarBlocks() async => (await loadAvailabilityBlocks()) ?? [];

  // Detailer Calendar Preferences with dual-key synchronization and detailerId support
  static Future<void> saveDetailerCalendarPreferences(DetailerCalendarPreferences preferences, {String? detailerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(preferences.toJson());
      if (detailerId != null) {
        await prefs.setString('${_calendarPrefsKey}_$detailerId', jsonStr);
      }
      await prefs.setString(_calendarPrefsKey, jsonStr);
      if (kDebugMode) {
        print('[LocalStorageService] Successfully saved calendar preferences.');
      }
    } catch (_) {}
  }

  static Future<DetailerCalendarPreferences?> loadDetailerCalendarPreferences({String? detailerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (detailerId != null) {
        final detailerKey = '${_calendarPrefsKey}_$detailerId';
        final detailerJson = prefs.getString(detailerKey);
        if (detailerJson != null && detailerJson.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(detailerJson);
          return DetailerCalendarPreferences.fromJson(Map<String, dynamic>.from(data));
        }
      }
      final jsonStr = prefs.getString(_calendarPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return DetailerCalendarPreferences.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }
}
