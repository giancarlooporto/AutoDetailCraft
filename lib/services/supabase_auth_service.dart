import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';

class SupabaseAuthService {
  static SupabaseClient? get _client {
    try {
      if (SupabaseService.isInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static User? get currentAuthUser => _client?.auth.currentUser;
  static bool get isLoggedIn => currentAuthUser != null;

  /// Sign Up with Email and Password
  static Future<({bool success, String? error, UserProfile? profile})> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) {
      return (success: false, error: 'Backend not ready. Please try again.', profile: null);
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'display_name': displayName.trim(),
          'phone': phone?.trim(),
        },
      );

      final user = response.user;
      if (user == null) {
        return (success: false, error: 'Registration failed. Please try again.', profile: null);
      }

      // Check if there was already locally saved profile data for this user ID
      final existingLocalProfile = await LocalStorageService.loadUserById(user.id);
      if (existingLocalProfile != null) {
        return (success: true, error: null, profile: existingLocalProfile);
      }

      final profile = UserProfile(
        id: user.id,
        role: UserRole.client,
        username: email.split('@').first,
        displayName: displayName.isNotEmpty ? displayName : email.split('@').first,
        businessName: '${displayName.isNotEmpty ? displayName : "My"} Detailing Studio',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
        location: 'Austin, Texas',
        bio: 'Car enthusiast & detailing craft connoisseur.',
        phone: phone ?? '',
        servicePackages: MockDataService.standardPackages,
        myGarage: const [],
        teamMembers: const [],
      );

      return (success: true, error: null, profile: profile);
    } on AuthException catch (e) {
      return (success: false, error: e.message, profile: null);
    } catch (e) {
      return (success: false, error: e.toString(), profile: null);
    }
  }

  /// Sign In with Email and Password
  static Future<({bool success, String? error, UserProfile? profile})> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return (success: false, error: 'Backend not ready. Please try again.', profile: null);
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = response.user;
      if (user == null) {
        return (success: false, error: 'User not found.', profile: null);
      }

      // First check if we have the user's saved garage, team, bio, location, etc.
      final existingLocalProfile = await LocalStorageService.loadUserById(user.id);
      if (existingLocalProfile != null) {
        return (success: true, error: null, profile: existingLocalProfile);
      }

      final displayName = (user.userMetadata?['display_name'] as String?) ?? email.split('@').first;
      final phone = (user.userMetadata?['phone'] as String?) ?? '';

      final profile = UserProfile(
        id: user.id,
        role: UserRole.client,
        username: email.split('@').first,
        displayName: displayName,
        businessName: '$displayName Detailing Studio',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
        location: 'Austin, Texas',
        bio: 'Car enthusiast & detailing craft connoisseur.',
        phone: phone,
        servicePackages: MockDataService.standardPackages,
        myGarage: const [],
        teamMembers: const [],
      );

      return (success: true, error: null, profile: profile);
    } on AuthException catch (e) {
      return (success: false, error: e.message, profile: null);
    } catch (e) {
      return (success: false, error: e.toString(), profile: null);
    }
  }

  /// Send password reset email
  static Future<({bool success, String? error})> sendPasswordReset(String email) async {
    final client = _client;
    if (client == null) return (success: false, error: 'Backend not ready.');
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Update password (called when arriving from recovery link)
  static Future<({bool success, String? error})> updateUserPassword(String newPassword) async {
    final client = _client;
    if (client == null) return (success: false, error: 'Backend not ready.');
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword.trim()));
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Sign Out
  static Future<void> signOut() async {
    try {
      final client = _client;
      if (client != null) {
        await client.auth.signOut();
      }
    } catch (e) {
      if (kDebugMode) print('[SupabaseAuthService] signOut error: $e');
    }
  }
}
