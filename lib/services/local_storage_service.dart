import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';

class LocalStorageService {
  static const String _userKeyPrefix = 'adc_user_state_v3_';
  static const String _lastActiveUserKey = 'adc_last_active_user_id_v1';
  static const String _bookingsKey = 'adc_bookings_state_v3';
  static const String _savedJobsKey = 'adc_saved_jobs_v3';
  static const String _likedJobsKey = 'adc_liked_jobs_v3';
  static const String _activeTabKey = 'adc_active_tab_index_v1';
  static const String _isGuestKey = 'adc_is_guest_mode_v1';
  static const String _siteAccessUnlockedKey = 'adc_site_access_unlocked_v1';

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
        return loadUserById(lastId);
      }
    } catch (_) {}
    return null;
  }

  // Save bookings list
  static Future<void> saveBookings(List<BookingAppointment> bookings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = bookings.map((b) => b.toJson()).toList();
      await prefs.setString(_bookingsKey, jsonEncode(list));
    } catch (_) {}
  }

  // Load bookings list
  static Future<List<BookingAppointment>?> loadBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_bookingsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => BookingAppointment.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  // Save liked and saved job IDs
  static Future<void> saveInteractionState({
    required Set<String> likedJobIds,
    required Set<String> savedJobIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likedJobsKey, likedJobIds.toList());
      await prefs.setStringList(_savedJobsKey, savedJobIds.toList());
    } catch (_) {}
  }

  static Future<({Set<String> likedJobIds, Set<String> savedJobIds})> loadInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final liked = prefs.getStringList(_likedJobsKey)?.toSet() ?? {};
      final saved = prefs.getStringList(_savedJobsKey)?.toSet() ?? {};
      return (likedJobIds: liked, savedJobIds: saved);
    } catch (_) {
      return (likedJobIds: <String>{}, savedJobIds: <String>{});
    }
  }
}
