import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';

/// Central test harness for initializing isolated sessions and simulating
/// browser refreshes across AutoDetailCraft tests.
class TestHarness {
  /// Initializes a new isolated testing session.
  ///
  /// - [initialPreferences]: Optional seed data for [SharedPreferences].
  /// - [isLoggedIn]: Whether the user starts in logged-in host mode or guest mode.
  /// - [currentUser]: Optional custom [UserProfile] to preload into local storage.
  static Future<JobRepository> createSession({
    Map<String, Object>? initialPreferences,
    bool isLoggedIn = false,
    UserProfile? currentUser,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize mock SharedPreferences storage
    SharedPreferences.setMockInitialValues(initialPreferences ?? <String, Object>{});

    // Seed user profile and guest mode flag before initializing repository
    if (currentUser != null) {
      await LocalStorageService.saveCurrentUser(currentUser);
    }
    await LocalStorageService.saveIsGuest(!isLoggedIn);

    // Create fresh repository and await asynchronous hydration
    final repository = JobRepository();
    await repository.init();

    if (currentUser != null && repository.currentUser.id != currentUser.id) {
      // Ensure exact user object if local hydration did not replace default
      await repository.loginUser(currentUser);
    }

    if (repository.isLoggedIn != isLoggedIn) {
      repository.isLoggedIn = isLoggedIn;
    }

    return repository;
  }

  /// Simulates a browser refresh (Cmd+R / F5).
  ///
  /// Disposes the current in-memory [JobRepository], constructs a fresh
  /// instance, and executes hydration from [LocalStorageService] / [SharedPreferences]
  /// to verify that all persisted state survives reload.
  static Future<JobRepository> simulateBrowserRefresh(JobRepository current) async {
    // 1. Dispose previous session
    current.dispose();

    // 2. Instantiate new repository reading the same mock storage
    final refreshedRepo = JobRepository();
    await refreshedRepo.init();

    return refreshedRepo;
  }
}

/// Convenience top-level function matching [TestHarness.createSession].
Future<JobRepository> createSession({
  Map<String, Object>? initialPreferences,
  bool isLoggedIn = false,
  UserProfile? currentUser,
}) =>
    TestHarness.createSession(
      initialPreferences: initialPreferences,
      isLoggedIn: isLoggedIn,
      currentUser: currentUser,
    );

/// Convenience top-level function matching [TestHarness.simulateBrowserRefresh].
Future<JobRepository> simulateBrowserRefresh(JobRepository current) =>
    TestHarness.simulateBrowserRefresh(current);
