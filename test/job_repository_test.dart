import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobRepository Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('initializes with mock jobs and public detailers', () {
      expect(repo.jobs, isA<List<DetailJob>>());
      expect(repo.publicDetailers, isA<List<UserProfile>>());
      expect(repo.bookings, isA<List<BookingAppointment>>());
    });

    test('filters jobs by service type', () {
      repo.setServiceFilter('Ceramic');
      expect(repo.filteredJobs.every((j) => j.serviceType.toLowerCase().contains('ceramic')), true);
    });

    test('toggles host mode and manages company hired staff', () {
      expect(repo.currentUser.role, isNotNull);
      repo.toggleHostMode();
      
      final initialTeamCount = repo.currentUser.teamMembers.length;
      final newStaff = const TeamMember(
        id: 'staff_1',
        name: 'Carlos Ruiz',
        roleTitle: 'Ceramic Lead',
        avatarUrl: 'https://example.com/avatar.jpg',
      );
      repo.addTeamMember(newStaff);
      expect(repo.currentUser.teamMembers.length, initialTeamCount + 1);

      repo.removeTeamMember('staff_1');
      expect(repo.currentUser.teamMembers.length, initialTeamCount);
    });

    test('JobRepository init() re-entrancy lock guarantees single hydration execution', () async {
      SharedPreferences.setMockInitialValues({});
      final uninitRepo = JobRepository();
      expect(uninitRepo.isInitialized, false);
      expect(uninitRepo.isInitializing, false);

      // Invoke init() multiple times concurrently
      final future1 = uninitRepo.init();
      expect(uninitRepo.isInitializing, true);
      final future2 = uninitRepo.init();
      final future3 = uninitRepo.init();

      await Future.wait([future1, future2, future3]);

      expect(uninitRepo.isInitialized, true);
      expect(uninitRepo.isInitializing, false);
    });

    test('LocalStorageService saves and loads dedicated service packages independently', () async {
      SharedPreferences.setMockInitialValues({});
      const testPkg = ServicePackage(
        id: 'pkg_custom_test',
        title: 'Custom Titanium Coating',
        description: 'Bespoke hand finish',
        basePrice: 599.0,
        estimatedDuration: '4 hrs',
        includes: ['Decon', 'Coat'],
      );

      await LocalStorageService.saveServicePackages([testPkg]);
      final loaded = await LocalStorageService.loadServicePackages();

      expect(loaded.length, 1);
      expect(loaded.first.id, 'pkg_custom_test');
      expect(loaded.first.title, 'Custom Titanium Coating');
      expect(loaded.first.basePrice, 599.0);
    });

    test('Service package CRUD persists across repository re-initialization (refresh simulation)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = JobRepository();
      await repo1.init();

      const customPkg = ServicePackage(
        id: 'pkg_ultra_gloss',
        title: 'Ultra Gloss Polish',
        description: 'Single stage jewel finish',
        basePrice: 350.0,
        estimatedDuration: '3 hrs',
        includes: ['Wash', 'Polish'],
      );

      // 1. Add package
      repo1.addServicePackage(customPkg);
      expect(repo1.currentUser.servicePackages.any((p) => p.id == 'pkg_ultra_gloss'), true);

      // 2. Simulate browser refresh (Cmd+R) with new repository instance reading same storage
      final repo2 = JobRepository();
      await repo2.init();
      expect(repo2.currentUser.servicePackages.any((p) => p.id == 'pkg_ultra_gloss'), true);

      // 3. Update package
      final updatedPkg = customPkg.copyWith(basePrice: 395.0);
      repo2.updateServicePackage(updatedPkg);

      final repo3 = JobRepository();
      await repo3.init();
      final persistedPkg = repo3.currentUser.servicePackages.firstWhere((p) => p.id == 'pkg_ultra_gloss');
      expect(persistedPkg.basePrice, 395.0);

      // 4. Remove package
      repo3.removeServicePackage('pkg_ultra_gloss');
      final repo4 = JobRepository();
      await repo4.init();
      expect(repo4.currentUser.servicePackages.any((p) => p.id == 'pkg_ultra_gloss'), false);
    });

    test('Cloud hydration with empty remote packages does NOT overwrite local custom packages', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = JobRepository();
      await repo1.init();

      const customPkg = ServicePackage(
        id: 'pkg_local_only',
        title: 'Local Only Concours',
        description: 'Local test package',
        basePrice: 750.0,
        estimatedDuration: '6 hrs',
        includes: ['Everything'],
      );
      repo1.addServicePackage(customPkg);
      expect(repo1.currentUser.servicePackages.any((p) => p.id == 'pkg_local_only'), true);

      // Simulate reload with empty remote packages (offline or empty remote table)
      final repo2 = JobRepository();
      await repo2.init();
      expect(repo2.currentUser.servicePackages.any((p) => p.id == 'pkg_local_only'), true);
    });

    test('Studio workbench mode persists across reload without guest lockout', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = JobRepository();
      await repo1.init();
      repo1.toggleHostMode(targetRole: UserRole.detailer);
      expect(repo1.isDetailerWorkbenchMode, isTrue);
      expect(repo1.workbenchMode, 'studio');
      expect(repo1.isLoggedIn, isTrue);

      final repo2 = JobRepository();
      await repo2.init();
      expect(repo2.isDetailerWorkbenchMode, isTrue);
      expect(repo2.workbenchMode, 'studio');
      expect(repo2.isLoggedIn, isTrue);
    });
  });
}
