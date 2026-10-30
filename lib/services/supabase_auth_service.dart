import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/team_member.dart';
import '../models/user_vehicle.dart';
import 'mock_data_service.dart';
import 'supabase_service.dart';
import 'supabase_db_service.dart';
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

      // If Supabase created the user in auth.users but session is null (email confirmation enabled),
      // attempt an immediate sign-in in case auto-confirm is enabled, or establish session.
      if (response.session == null) {
        try {
          await client.auth.signInWithPassword(
            email: email.trim(),
            password: password.trim(),
          );
        } on AuthException catch (ae) {
          if (kDebugMode) {
            print('[SupabaseAuthService] User created in Supabase auth.users; session pending email confirmation: ${ae.message}');
          }
        } catch (_) {}
      }

      // 1. Load existing local assets and draft profile (e.g. drafted by guest before signup)
      final existingLocalProfile = await LocalStorageService.loadUserById(user.id);
      final guestProfile = await LocalStorageService.loadUserById('usr_you');
      final localPackages = await LocalStorageService.loadServicePackages();
      final localTeam = await LocalStorageService.loadTeamMembers();
      final localGarage = await LocalStorageService.loadGarageVehicles();
      final guestVehicles = <String, UserVehicle>{
        if (guestProfile != null)
          for (final v in guestProfile.myGarage) v.id: v,
        for (final v in localGarage) v.id: v,
      };

      // 2. First check if there is an existing cloud profile in Supabase Database
      final cloudProfile = await SupabaseDbService.fetchUserProfile(user.id);
      if (cloudProfile != null) {
        final localPinHash = await LocalStorageService.loadOwnerPinHash() ?? existingLocalProfile?.ownerPinHash;
        final teamMap = <String, TeamMember>{
          if (existingLocalProfile != null)
            for (final m in existingLocalProfile.teamMembers) m.id: m,
          for (final m in localTeam) m.id: m,
          for (final m in cloudProfile.teamMembers) m.id: m,
        };
        final garageMap = <String, UserVehicle>{
          if (existingLocalProfile != null)
            for (final v in existingLocalProfile.myGarage) v.id: v,
          for (final v in guestVehicles.values) v.id: v,
        };
        for (final cv in cloudProfile.myGarage) {
          final local = garageMap[cv.id];
          if (local != null) {
            garageMap[cv.id] = cv.copyWith(
              localImageBytes: cv.localImageBytes ?? local.localImageBytes,
              lastDetailService: cv.lastDetailService ?? local.lastDetailService,
              lastDetailDate: cv.lastDetailDate ?? local.lastDetailDate,
            );
          } else {
            garageMap[cv.id] = cv;
          }
        }
        final mergedGarage = garageMap.values.toList();
        final mergedPackages = cloudProfile.servicePackages.isNotEmpty
            ? cloudProfile.servicePackages
            : localPackages;
        final hasPackages = mergedPackages.isNotEmpty;
        final startingPrice = hasPackages
            ? mergedPackages.map((p) => p.basePrice).reduce((a, b) => a < b ? a : b)
            : cloudProfile.startingPrice;
        final merged = cloudProfile.copyWith(
          role: (cloudProfile.role == UserRole.detailer || hasPackages)
              ? UserRole.detailer
              : cloudProfile.role,
          servicePackages: mergedPackages,
          startingPrice: startingPrice,
          isVerifiedHost: hasPackages || cloudProfile.isVerifiedHost,
          myGarage: mergedGarage,
          teamMembers: teamMap.values.toList(),
          ownerPinHash: (cloudProfile.ownerPinHash != null && cloudProfile.ownerPinHash!.isNotEmpty)
              ? cloudProfile.ownerPinHash
              : localPinHash,
        );
        await LocalStorageService.saveGarageVehicles(mergedGarage);
        await SupabaseDbService.saveUserProfile(merged);
        final cloudVehicleIds = cloudProfile.myGarage.map((v) => v.id).toSet();
        for (final v in mergedGarage) {
          if (!cloudVehicleIds.contains(v.id)) {
            await SupabaseDbService.saveVehicle(user.id, v);
          }
        }
        await LocalStorageService.saveCurrentUser(merged);
        return (success: true, error: null, profile: merged);
      }

      // 3. Check if there was already locally saved profile data for this user ID
      if (existingLocalProfile != null) {
        final mergedPackages = existingLocalProfile.servicePackages.isNotEmpty
            ? existingLocalProfile.servicePackages
            : localPackages;
        final hasPackages = mergedPackages.isNotEmpty;
        final startingPrice = hasPackages
            ? mergedPackages.map((p) => p.basePrice).reduce((a, b) => a < b ? a : b)
            : existingLocalProfile.startingPrice;
        final garageMap = <String, UserVehicle>{
          for (final v in existingLocalProfile.myGarage) v.id: v,
          for (final v in guestVehicles.values) v.id: v,
        };
        final mergedGarage = garageMap.values.toList();
        final merged = existingLocalProfile.copyWith(
          role: (existingLocalProfile.role == UserRole.detailer || hasPackages)
              ? UserRole.detailer
              : existingLocalProfile.role,
          servicePackages: mergedPackages,
          startingPrice: startingPrice,
          isVerifiedHost: hasPackages || existingLocalProfile.isVerifiedHost,
          myGarage: mergedGarage,
        );
        await LocalStorageService.saveGarageVehicles(mergedGarage);
        await SupabaseDbService.saveUserProfile(merged);
        for (final v in mergedGarage) {
          await SupabaseDbService.saveVehicle(user.id, v);
        }
        await LocalStorageService.saveCurrentUser(merged);
        return (success: true, error: null, profile: merged);
      }

      // 4. Load existing local service packages and draft profile (e.g. drafted by guest before signup)
      final hasPackages = localPackages.isNotEmpty;
      final startingPrice = hasPackages
          ? localPackages.map((p) => p.basePrice).reduce((a, b) => a < b ? a : b)
          : 150.0;
      final mergedGarage = guestVehicles.values.toList();

      final profile = UserProfile(
        id: user.id,
        role: hasPackages ? UserRole.detailer : UserRole.client,
        username: email.split('@').first,
        displayName: displayName.isNotEmpty
            ? displayName
            : ((guestProfile != null && guestProfile.displayName.isNotEmpty && guestProfile.displayName != 'Vehicle Owner')
                ? guestProfile.displayName
                : email.split('@').first),
        businessName: guestProfile?.businessName ?? '',
        avatarUrl: guestProfile?.avatarUrl ?? '',
        coverUrl: guestProfile?.coverUrl ?? '',
        location: guestProfile?.location ?? '',
        serviceRadius: (guestProfile?.serviceRadius.isNotEmpty == true)
            ? guestProfile!.serviceRadius
            : '25 miles • Mobile & Studio',
        bio: guestProfile?.bio ?? '',
        phone: phone ?? (guestProfile?.phone ?? ''),
        instagramHandle: guestProfile?.instagramHandle ?? '',
        servicePackages: localPackages,
        startingPrice: startingPrice,
        isVerifiedHost: hasPackages,
        myGarage: mergedGarage,
        teamMembers: const [],
      );

      // Seed profile in Supabase so the profile row exists
      await LocalStorageService.saveGarageVehicles(mergedGarage);
      await SupabaseDbService.saveUserProfile(profile);
      for (final v in mergedGarage) {
        await SupabaseDbService.saveVehicle(user.id, v);
      }
      await LocalStorageService.saveCurrentUser(profile);

      return (success: true, error: null, profile: profile);
    } on AuthException catch (e) {
      final msg = e.message;
      if (msg.toLowerCase().contains('email not confirmed')) {
        return (
          success: false,
          error: 'Email confirmation is pending. Please verify your email, or turn OFF "Confirm email" in Supabase Auth settings to sign in immediately.',
          profile: null,
        );
      }
      if (msg.toLowerCase().contains('already registered') || msg.toLowerCase().contains('already exists')) {
        // Self-healing recovery for accounts previously deleted but not yet purged from auth.users:
        try {
          final loginRes = await client.auth.signInWithPassword(
            email: email.trim(),
            password: password.trim(),
          );
          final existingUser = loginRes.user;
          if (existingUser != null) {
            final meta = existingUser.userMetadata ?? {};
            final wasDeleted = meta['is_deleted'] == true || meta['account_status'] == 'deleted';
            final cloudProfile = await SupabaseDbService.fetchUserProfile(existingUser.id);

            // If the account was previously deleted OR had its profile deleted from public schema:
            if (wasDeleted || cloudProfile == null) {
              // 1. Try server-side deletion via RPC if available
              try {
                await client.rpc('delete_user_account');
                // Retrying fresh sign-up now that auth.users is cleared
                return await signUp(
                  email: email,
                  password: password,
                  displayName: displayName,
                  phone: phone,
                );
              } catch (_) {}

              // 2. Fallback reactivation: reset metadata to active and create a fresh profile
              await client.auth.updateUser(
                UserAttributes(data: {
                  'account_status': 'active',
                  'is_deleted': false,
                  'display_name': displayName.trim(),
                }),
              );

              final localGarage = await LocalStorageService.loadGarageVehicles();
              final guestProfile = await LocalStorageService.loadUserById('usr_you');
              final guestVehicles = <String, UserVehicle>{
                if (guestProfile != null)
                  for (final v in guestProfile.myGarage) v.id: v,
                for (final v in localGarage) v.id: v,
              };
              final mergedGarage = guestVehicles.values.toList();

              final freshProfile = UserProfile(
                id: existingUser.id,
                role: UserRole.client,
                username: email.split('@').first,
                displayName: displayName.trim().isNotEmpty ? displayName.trim() : email.split('@').first,
                phone: phone ?? '',
                myGarage: mergedGarage,
                servicePackages: const [],
                teamMembers: const [],
              );
              await LocalStorageService.saveGarageVehicles(mergedGarage);
              await SupabaseDbService.saveUserProfile(freshProfile);
              for (final v in mergedGarage) {
                await SupabaseDbService.saveVehicle(existingUser.id, v);
              }
              await LocalStorageService.saveCurrentUser(freshProfile);
              return (success: true, error: null, profile: freshProfile);
            }
          }
        } catch (_) {}

        return (
          success: false,
          error: 'This email is already registered in Supabase. If you previously deleted this account, please delete the user row in your Supabase Dashboard under Authentication > Users to recreate it, or enter your previous password.',
          profile: null,
        );
      }
      return (success: false, error: e.message, profile: null);
    } catch (e) {
      return (success: false, error: e.toString(), profile: null);
    }
  }

  /// Sign In with Email and Password
  static Future<({bool success, String? error, UserProfile? profile})> signInWithEmail({
    required String email,
    required String password,
  }) => signIn(email: email, password: password);

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

      // Reject sign-in if account was previously marked deleted
      final meta = user.userMetadata ?? {};
      if (meta['is_deleted'] == true || meta['account_status'] == 'deleted') {
        // Attempt to purge lingering auth.users record via RPC on server
        try {
          await client.rpc('delete_user_account');
          await client.auth.signOut();
          return (
            success: false,
            error: 'This account was deleted and has now been permanently removed from Supabase. You can now register for a new account with this email address.',
            profile: null,
          );
        } catch (_) {}

        await client.auth.signOut();
        return (
          success: false,
          error: 'This account was deleted. To register again with this email, delete the user in your Supabase Dashboard under Authentication > Users or run the deletion migration SQL.',
          profile: null,
        );
      }

      // 1. Query SupabaseDbService.fetchUserProfile(user.id) FIRST on sign-in before falling back
      final cloudProfile = await SupabaseDbService.fetchUserProfile(user.id);
      final existingLocalProfile = await LocalStorageService.loadUserById(user.id);
      final guestProfile = await LocalStorageService.loadUserById('usr_you');
      final localTeam = await LocalStorageService.loadTeamMembers();
      final localGarage = await LocalStorageService.loadGarageVehicles();
      final guestVehicles = <String, UserVehicle>{
        if (guestProfile != null)
          for (final v in guestProfile.myGarage) v.id: v,
        for (final v in localGarage) v.id: v,
      };
      final localPinHash = await LocalStorageService.loadOwnerPinHash() ?? existingLocalProfile?.ownerPinHash;

      if (cloudProfile != null) {
        final localPackages = await LocalStorageService.loadServicePackages();
        final mergedPackages = cloudProfile.servicePackages.isNotEmpty
            ? cloudProfile.servicePackages
            : (localPackages.isNotEmpty
                ? localPackages
                : (existingLocalProfile?.servicePackages ?? MockDataService.standardPackages));

        // Non-destructive union merge of teamMembers across local profile, dedicated storage, and cloud
        final teamMap = <String, TeamMember>{
          if (existingLocalProfile != null)
            for (final m in existingLocalProfile.teamMembers) m.id: m,
          for (final m in localTeam) m.id: m,
        };
        for (final cm in cloudProfile.teamMembers) {
          final local = teamMap[cm.id];
          if (local != null) {
            teamMap[cm.id] = cm.copyWith(
              customWeeklySchedule: cm.customWeeklySchedule ?? local.customWeeklySchedule,
              localAvatarBytes: cm.localAvatarBytes ?? local.localAvatarBytes,
              isFounder: cm.isFounder || local.isFounder,
            );
          } else {
            teamMap[cm.id] = cm;
          }
        }

        // Reconcile garage vehicles from cloud and local guest additions
        final garageMap = <String, UserVehicle>{
          if (existingLocalProfile != null)
            for (final v in existingLocalProfile.myGarage) v.id: v,
          for (final v in guestVehicles.values) v.id: v,
        };
        for (final cv in cloudProfile.myGarage) {
          final local = garageMap[cv.id];
          if (local != null) {
            garageMap[cv.id] = cv.copyWith(
              localImageBytes: cv.localImageBytes ?? local.localImageBytes,
              lastDetailService: cv.lastDetailService ?? local.lastDetailService,
              lastDetailDate: cv.lastDetailDate ?? local.lastDetailDate,
            );
          } else {
            garageMap[cv.id] = cv;
          }
        }
        final reconciledGarage = garageMap.values.toList();
        await LocalStorageService.saveGarageVehicles(reconciledGarage);
        final cloudVehicleIds = cloudProfile.myGarage.map((v) => v.id).toSet();
        for (final v in reconciledGarage) {
          if (!cloudVehicleIds.contains(v.id)) {
            await SupabaseDbService.saveVehicle(user.id, v);
          }
        }

        final resolvedPinHash = (cloudProfile.ownerPinHash != null && cloudProfile.ownerPinHash!.isNotEmpty)
            ? cloudProfile.ownerPinHash
            : localPinHash;

        final merged = cloudProfile.copyWith(
          servicePackages: mergedPackages,
          teamMembers: teamMap.values.toList(),
          myGarage: reconciledGarage,
          ownerPinHash: resolvedPinHash,
        );
        if (resolvedPinHash != null && resolvedPinHash.isNotEmpty) {
          await LocalStorageService.saveOwnerPinHash(resolvedPinHash);
        }
        await LocalStorageService.saveCurrentUser(merged);
        return (success: true, error: null, profile: merged);
      }

      // 2. Check if we have the user's saved garage, team, bio, location, etc. in local storage
      if (existingLocalProfile != null) {
        final teamMap = <String, TeamMember>{
          for (final m in existingLocalProfile.teamMembers) m.id: m,
          for (final m in localTeam) m.id: m,
        };
        final garageMap = <String, UserVehicle>{
          for (final v in existingLocalProfile.myGarage) v.id: v,
          for (final v in guestVehicles.values) v.id: v,
        };
        final reconciledGarage = garageMap.values.toList();
        await LocalStorageService.saveGarageVehicles(reconciledGarage);
        for (final v in reconciledGarage) {
          await SupabaseDbService.saveVehicle(user.id, v);
        }
        final mergedLocal = existingLocalProfile.copyWith(
          teamMembers: teamMap.values.toList(),
          myGarage: reconciledGarage,
        );
        await LocalStorageService.saveCurrentUser(mergedLocal);
        return (success: true, error: null, profile: mergedLocal);
      }

      final displayName = (user.userMetadata?['display_name'] as String?) ?? email.split('@').first;
      final phone = (user.userMetadata?['phone'] as String?) ?? '';
      final reconciledGarage = guestVehicles.values.toList();
      await LocalStorageService.saveGarageVehicles(reconciledGarage);
      for (final v in reconciledGarage) {
        await SupabaseDbService.saveVehicle(user.id, v);
      }

      final profile = UserProfile(
        id: user.id,
        role: UserRole.client,
        username: email.split('@').first,
        displayName: displayName,
        businessName: '',
        avatarUrl: '',
        coverUrl: '',
        location: '',
        serviceRadius: '',
        bio: '',
        phone: phone,
        instagramHandle: '',
        servicePackages: const [],
        myGarage: reconciledGarage,
        teamMembers: const [],
      );

      await LocalStorageService.saveCurrentUser(profile);
      return (success: true, error: null, profile: profile);
    } on AuthException catch (e) {
      final msg = e.message;
      if (msg.toLowerCase().contains('email not confirmed')) {
        return (
          success: false,
          error: 'Email confirmation is pending. Please verify your email, or turn OFF "Confirm email" in Supabase Auth settings to sign in immediately.',
          profile: null,
        );
      }
      return (success: false, error: e.message, profile: null);
    } catch (e) {
      return (success: false, error: e.toString(), profile: null);
    }
  }

  /// Verify 6-digit email signup OTP code
  static Future<({bool success, String? error, UserProfile? profile})> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final client = _client;
    if (client == null) {
      return (success: false, error: 'Backend not ready. Please try again.', profile: null);
    }

    try {
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.signup,
      );

      final user = response.user;
      if (user == null) {
        return (success: false, error: 'Verification failed. Please check the code and try again.', profile: null);
      }

      // 1. Fetch or create verified cloud profile
      var profile = await SupabaseDbService.fetchUserProfile(user.id);
      final guestProfile = await LocalStorageService.loadUserById('usr_you');
      final localGarage = await LocalStorageService.loadGarageVehicles();
      final guestVehicles = <String, UserVehicle>{
        if (guestProfile != null)
          for (final v in guestProfile.myGarage) v.id: v,
        for (final v in localGarage) v.id: v,
      };

      if (profile == null) {
        final localPackages = await LocalStorageService.loadServicePackages();
        final hasPackages = localPackages.isNotEmpty;
        final startingPrice = hasPackages
            ? localPackages.map((p) => p.basePrice).reduce((a, b) => a < b ? a : b)
            : 150.0;
        final mergedGarage = guestVehicles.values.toList();

        profile = UserProfile(
          id: user.id,
          role: hasPackages ? UserRole.detailer : UserRole.client,
          username: email.split('@').first,
          displayName: (user.userMetadata?['display_name'] as String?) ??
              ((guestProfile != null && guestProfile.displayName.isNotEmpty && guestProfile.displayName != 'Vehicle Owner')
                  ? guestProfile.displayName
                  : email.split('@').first),
          businessName: guestProfile?.businessName ?? '',
          avatarUrl: guestProfile?.avatarUrl ?? '',
          coverUrl: guestProfile?.coverUrl ?? '',
          location: guestProfile?.location ?? '',
          serviceRadius: (guestProfile?.serviceRadius.isNotEmpty == true)
              ? guestProfile!.serviceRadius
              : '25 miles • Mobile & Studio',
          bio: guestProfile?.bio ?? '',
          phone: (user.userMetadata?['phone'] as String?) ?? (guestProfile?.phone ?? ''),
          instagramHandle: guestProfile?.instagramHandle ?? '',
          servicePackages: localPackages,
          startingPrice: startingPrice,
          isVerifiedHost: hasPackages,
          myGarage: mergedGarage,
          teamMembers: const [],
        );
        await LocalStorageService.saveGarageVehicles(mergedGarage);
        await SupabaseDbService.saveUserProfile(profile);
        for (final v in mergedGarage) {
          await SupabaseDbService.saveVehicle(user.id, v);
        }
      } else {
        if (guestVehicles.isNotEmpty) {
          final cloudVehicleIds = profile.myGarage.map((v) => v.id).toSet();
          final garageMap = <String, UserVehicle>{
            for (final v in guestVehicles.values) v.id: v,
          };
          for (final cv in profile.myGarage) {
            garageMap[cv.id] = cv;
          }
          final mergedGarage = garageMap.values.toList();
          profile = profile.copyWith(myGarage: mergedGarage);
          await LocalStorageService.saveGarageVehicles(mergedGarage);
          for (final v in mergedGarage) {
            if (!cloudVehicleIds.contains(v.id)) {
              await SupabaseDbService.saveVehicle(user.id, v);
            }
          }
        }
      }

      await LocalStorageService.saveCurrentUser(profile);
      return (success: true, error: null, profile: profile);
    } on AuthException catch (e) {
      return (success: false, error: e.message, profile: null);
    } catch (e) {
      return (success: false, error: e.toString(), profile: null);
    }
  }

  /// Resend 6-digit signup confirmation code
  static Future<({bool success, String? error})> resendSignupOtp(String email) async {
    final client = _client;
    if (client == null) return (success: false, error: 'Backend not ready.');
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
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

  /// Send Staff Invitation & Password Setup Email via Supabase Built-in Auth Emailer
  static Future<({bool success, String? error})> sendStaffInvitationEmail({
    required String email,
    required String staffName,
    required String studioName,
    required String inviteToken,
    required String inviteUrl,
  }) async {
    final client = _client;
    if (client == null) {
      return (success: false, error: 'Backend not ready.');
    }
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return (success: false, error: 'Email is empty.');
    }

    try {
      await client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: true,
        emailRedirectTo: inviteUrl,
        data: {
          'display_name': staffName.trim(),
          'staff_invite_token': inviteToken,
          'studio_name': studioName.trim(),
          'role': 'staff',
        },
      );
      if (kDebugMode) {
        print('[SupabaseAuthService] Dispatched staff invitation email to $cleanEmail -> $inviteUrl');
      }
      return (success: true, error: null);
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('[SupabaseAuthService] sendStaffInvitationEmail AuthException: ${e.message}');
      }
      return (success: false, error: e.message);
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseAuthService] sendStaffInvitationEmail error: $e');
      }
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
