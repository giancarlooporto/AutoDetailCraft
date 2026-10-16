import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M1 Adversarial Stress Tests: Persistence & Lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // =========================================================================
    // 1. Concurrent Initialization Stress Testing
    // =========================================================================
    group('1. Concurrent Initialization Stress Tests', () {
      test('1.1: 50 concurrent repo.init() calls strictly execute a single hydration without throwing or memory corruption', () async {
        final repo = JobRepository();
        expect(repo.isInitialized, isFalse);
        expect(repo.isInitializing, isFalse);

        int listenerNotifications = 0;
        repo.addListener(() {
          listenerNotifications++;
        });

        // Launch 50 concurrent init() calls simultaneously
        final futures = List<Future<void>>.generate(50, (_) => repo.init());
        expect(repo.isInitializing, isTrue);

        // Await all concurrent futures
        await Future.wait(futures);

        expect(repo.isInitialized, isTrue);
        expect(repo.isInitializing, isFalse);

        // Listener should be notified cleanly (not 50 separate times)
        expect(listenerNotifications, equals(1));

        // Memory integrity: list lengths should match standard base counts exactly, not multiplied 50x
        expect(repo.jobs.length, equals(MockDataService.getInitialJobs().length));
        expect(repo.publicDetailers.length, equals(MockDataService.publicDetailers.length));
        expect(repo.currentUser.servicePackages.length, equals(MockDataService.standardPackages.length));
      });

      test('1.2: Staggered interleaved init() calls while in-flight resolve smoothly', () async {
        final repo = JobRepository();
        final futures = <Future<void>>[];

        // Immediate
        futures.add(repo.init());
        // Staggered by microtasks / slight delays
        futures.add(Future.delayed(const Duration(milliseconds: 1), () => repo.init()));
        futures.add(Future.delayed(const Duration(milliseconds: 3), () => repo.init()));
        futures.add(Future.delayed(const Duration(milliseconds: 5), () => repo.init()));

        await Future.wait(futures);

        expect(repo.isInitialized, isTrue);
        expect(repo.isInitializing, isFalse);
        expect(repo.currentUser.servicePackages.isNotEmpty, isTrue);

        // Subsequent call when already initialized is a safe no-op
        await repo.init();
        expect(repo.isInitialized, isTrue);
      });
    });

    // =========================================================================
    // 2. Rapid Consecutive Mutations & Refresh Stress Testing
    // =========================================================================
    group('2. Rapid Consecutive Mutations & Refresh Simulation', () {
      test('2.1: Add 10 custom packages, update 5, delete 3, simulate refresh -> verify exact identity, ordering, prices, titles', () async {
        final repo1 = JobRepository();
        await repo1.init();

        final initialCount = repo1.currentUser.servicePackages.length;
        expect(initialCount, equals(4)); // 4 standard mock packages

        // --- Step A: Rapidly add 10 custom service packages ---
        final addedPackages = <ServicePackage>[];
        for (int i = 1; i <= 10; i++) {
          final pkg = ServicePackage(
            id: 'pkg_stress_$i',
            title: 'Bespoke Package $i',
            description: 'Description for bespoke package $i with specialized treatments',
            basePrice: 100.0 * i + 49.99, // 149.99, 249.99, ... 1049.99
            estimatedDuration: '${i + 1} hrs',
            includes: ['Decon Stage $i', 'Correction Level $i', 'Sealant $i'],
          );
          addedPackages.add(pkg);
          repo1.addServicePackage(pkg);
        }

        // Verify in-memory state before refresh
        expect(repo1.currentUser.servicePackages.length, equals(initialCount + 10));

        // --- Step B: Rapidly update 5 of them (indices 2, 4, 6, 8, 10) ---
        final updatedIndices = [2, 4, 6, 8, 10];
        final updatedMap = <String, ServicePackage>{};
        for (final idx in updatedIndices) {
          final orig = addedPackages[idx - 1];
          final updated = orig.copyWith(
            title: 'UPDATED Titanium Package $idx',
            basePrice: orig.basePrice + 500.0,
            estimatedDuration: '${idx + 3} hrs',
            includes: [...orig.includes, 'Bonus Ceramic Topcoat $idx'],
          );
          updatedMap[updated.id] = updated;
          repo1.updateServicePackage(updated);
        }

        // --- Step C: Rapidly delete 3 of them (indices 1, 5, 9) ---
        final deletedIndices = [1, 5, 9];
        final deletedIds = deletedIndices.map((i) => 'pkg_stress_$i').toSet();
        for (final delId in deletedIds) {
          repo1.removeServicePackage(delId);
        }

        // Compute Expected Final Package List:
        // 4 standard packages first, followed by the remaining 7 custom packages in insertion order
        final expectedPackages = <ServicePackage>[
          ...MockDataService.standardPackages,
        ];
        for (int i = 1; i <= 10; i++) {
          final id = 'pkg_stress_$i';
          if (deletedIds.contains(id)) {
            continue; // Skipped / deleted
          }
          if (updatedMap.containsKey(id)) {
            expectedPackages.add(updatedMap[id]!);
          } else {
            expectedPackages.add(addedPackages[i - 1]);
          }
        }

        expect(expectedPackages.length, equals(initialCount + 7)); // 4 + 7 = 11

        // Verify repo1 in-memory matches expected
        expect(repo1.currentUser.servicePackages.length, equals(expectedPackages.length));
        for (int i = 0; i < expectedPackages.length; i++) {
          expect(repo1.currentUser.servicePackages[i].id, equals(expectedPackages[i].id));
          expect(repo1.currentUser.servicePackages[i].title, equals(expectedPackages[i].title));
          expect(repo1.currentUser.servicePackages[i].basePrice, equals(expectedPackages[i].basePrice));
        }

        // --- Step D: Simulate Browser Refresh (Cmd+R) as specified in mission:
        // final repo2 = JobRepository(); await repo2.init();
        final repo2 = JobRepository();
        await repo2.init();

        // --- Step E: Verify Exact List Identity, Ordering, Prices, and Titles ---
        final refreshedPackages = repo2.currentUser.servicePackages;
        expect(refreshedPackages.length, equals(expectedPackages.length),
            reason: 'Total package count after browser refresh must equal 11 (4 standard + 7 custom)');

        for (int i = 0; i < expectedPackages.length; i++) {
          final expected = expectedPackages[i];
          final actual = refreshedPackages[i];

          expect(actual.id, equals(expected.id),
              reason: 'Package index $i ID mismatch: expected ${expected.id}, got ${actual.id}');
          expect(actual.title, equals(expected.title),
              reason: 'Package ${expected.id} title mismatch after refresh');
          expect(actual.basePrice, equals(expected.basePrice),
              reason: 'Package ${expected.id} price mismatch after refresh: expected ${expected.basePrice}, got ${actual.basePrice}');
          expect(actual.estimatedDuration, equals(expected.estimatedDuration),
              reason: 'Package ${expected.id} duration mismatch after refresh');
          expect(actual.includes, equals(expected.includes),
              reason: 'Package ${expected.id} includes mismatch after refresh');
        }

        // Ensure deleted packages are completely absent
        for (final delId in deletedIds) {
          expect(refreshedPackages.any((p) => p.id == delId), isFalse,
              reason: 'Deleted package $delId must NOT reappear after browser refresh');
        }

        // Verify dedicated storage matches refreshed repo
        final dedicatedStorage = await LocalStorageService.loadServicePackages();
        expect(dedicatedStorage.length, equals(expectedPackages.length));
      });

      test('2.2: Extreme rapid burst of 50 mutations followed immediately by refresh simulation', () async {
        final repo1 = JobRepository();
        await repo1.init();

        // 30 adds
        for (int i = 1; i <= 30; i++) {
          repo1.addServicePackage(ServicePackage(
            id: 'burst_$i',
            title: 'Burst $i',
            description: 'Desc $i',
            basePrice: 100.0 + i,
            estimatedDuration: '1 hr',
            includes: ['Step $i'],
          ));
        }

        // 10 updates
        for (int i = 1; i <= 10; i++) {
          repo1.updateServicePackage(ServicePackage(
            id: 'burst_$i',
            title: 'Burst $i UPDATED',
            description: 'Updated Desc $i',
            basePrice: 999.0 + i,
            estimatedDuration: '2 hrs',
            includes: ['Updated Step $i'],
          ));
        }

        // 10 deletes
        for (int i = 21; i <= 30; i++) {
          repo1.removeServicePackage('burst_$i');
        }

        // Immediate refresh simulation
        final repo2 = JobRepository();
        await repo2.init();

        // Expected: 4 standard + 20 remaining burst packages = 24
        expect(repo2.currentUser.servicePackages.length, equals(24));

        // Check updated packages
        for (int i = 1; i <= 10; i++) {
          final p = repo2.currentUser.servicePackages.firstWhere((pkg) => pkg.id == 'burst_$i');
          expect(p.title, equals('Burst $i UPDATED'));
          expect(p.basePrice, equals(999.0 + i));
        }

        // Check deleted packages
        for (int i = 21; i <= 30; i++) {
          expect(repo2.currentUser.servicePackages.any((pkg) => pkg.id == 'burst_$i'), isFalse);
        }
      });
    });

    // =========================================================================
    // 3. Indefinite Multi-Refresh Retention Stress Testing
    // =========================================================================
    group('3. Indefinite Multi-Refresh Retention (Refresh 1 -> 2 -> 3 -> 4 -> 5)', () {
      test('3.1: Successive simulated browser refreshes preserve custom packages indefinitely without resetting to default mocks', () async {
        // Initial session: Start and add 3 custom packages
        var currentRepo = JobRepository();
        await currentRepo.init();

        final custom1 = const ServicePackage(
          id: 'custom_alpha',
          title: 'Alpha Ceramic Pro',
          description: 'Alpha tier coating',
          basePrice: 899.0,
          estimatedDuration: '5 hrs',
          includes: ['Paint Correction', 'Alpha Coating'],
        );
        final custom2 = const ServicePackage(
          id: 'custom_beta',
          title: 'Beta Interior Shield',
          description: 'Beta interior steam and leather protection',
          basePrice: 450.0,
          estimatedDuration: '3 hrs',
          includes: ['Steam Decon', 'Leather Conditioning'],
        );
        final custom3 = const ServicePackage(
          id: 'custom_gamma',
          title: 'Gamma Wheel & Glass',
          description: 'Wheel face and glass repellent',
          basePrice: 299.0,
          estimatedDuration: '2 hrs',
          includes: ['Wheel Removal & Coat', 'Glass Sealant'],
        );

        currentRepo.addServicePackage(custom1);
        currentRepo.addServicePackage(custom2);
        currentRepo.addServicePackage(custom3);

        expect(currentRepo.currentUser.servicePackages.length, equals(7)); // 4 standard + 3 custom

        // ---------------------------------------------------------------------
        // REFRESH 1: Simulating first browser reload (Refresh 1)
        // ---------------------------------------------------------------------
        currentRepo = JobRepository();
        await currentRepo.init();

        expect(currentRepo.currentUser.servicePackages.length, equals(7),
            reason: 'Refresh 1: Must retain all 7 packages (4 standard + 3 custom)');
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_alpha'), isTrue);
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_beta'), isTrue);
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_gamma'), isTrue);

        // Mutate one package in Refresh 1
        final modifiedAlpha = custom1.copyWith(
          title: 'Alpha Ceramic Pro (Modified in R1)',
          basePrice: 950.0,
        );
        currentRepo.updateServicePackage(modifiedAlpha);

        // ---------------------------------------------------------------------
        // REFRESH 2: Simulating second browser reload (Refresh 2)
        // ---------------------------------------------------------------------
        currentRepo = JobRepository();
        await currentRepo.init();

        expect(currentRepo.currentUser.servicePackages.length, equals(7),
            reason: 'Refresh 2: Must retain all 7 packages');
        final r2Alpha = currentRepo.currentUser.servicePackages.firstWhere((p) => p.id == 'custom_alpha');
        expect(r2Alpha.title, equals('Alpha Ceramic Pro (Modified in R1)'),
            reason: 'Refresh 2: Modified package title must survive second refresh');
        expect(r2Alpha.basePrice, equals(950.0),
            reason: 'Refresh 2: Modified package price must survive second refresh');

        // Add a 4th custom package in Refresh 2
        final custom4 = const ServicePackage(
          id: 'custom_delta',
          title: 'Delta Engine Bay Detail',
          description: 'Full degreasing and dressing',
          basePrice: 175.0,
          estimatedDuration: '1 hr',
          includes: ['Steam Clean', 'Water-based Dressing'],
        );
        currentRepo.addServicePackage(custom4);
        expect(currentRepo.currentUser.servicePackages.length, equals(8));

        // ---------------------------------------------------------------------
        // REFRESH 3: Simulating third browser reload (Refresh 3)
        // ---------------------------------------------------------------------
        currentRepo = JobRepository();
        await currentRepo.init();

        expect(currentRepo.currentUser.servicePackages.length, equals(8),
            reason: 'Refresh 3: Must retain all 8 packages (4 standard + 4 custom)');
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_delta'), isTrue);
        expect(currentRepo.currentUser.servicePackages.firstWhere((p) => p.id == 'custom_delta').basePrice, equals(175.0));

        // Remove 1 custom package in Refresh 3
        currentRepo.removeServicePackage('custom_beta');
        expect(currentRepo.currentUser.servicePackages.length, equals(7));

        // ---------------------------------------------------------------------
        // REFRESH 4: Simulating fourth browser reload (Refresh 4)
        // ---------------------------------------------------------------------
        currentRepo = JobRepository();
        await currentRepo.init();

        expect(currentRepo.currentUser.servicePackages.length, equals(7),
            reason: 'Refresh 4: Must retain exactly 7 packages');
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_beta'), isFalse,
            reason: 'Refresh 4: Removed package custom_beta must NOT reappear');
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_alpha'), isTrue);
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_gamma'), isTrue);
        expect(currentRepo.currentUser.servicePackages.any((p) => p.id == 'custom_delta'), isTrue);

        // ---------------------------------------------------------------------
        // REFRESH 5: Pure idle refresh without any intermediate mutations (Refresh 5)
        // ---------------------------------------------------------------------
        currentRepo = JobRepository();
        await currentRepo.init();

        expect(currentRepo.currentUser.servicePackages.length, equals(7),
            reason: 'Refresh 5: Idempotent refresh must maintain exact state');
        
        final expectedIds = [
          ...MockDataService.standardPackages.map((p) => p.id),
          'custom_alpha',
          'custom_gamma',
          'custom_delta',
        ];
        expect(currentRepo.currentUser.servicePackages.map((p) => p.id).toList(), equals(expectedIds),
            reason: 'Refresh 5: Exact order and IDs preserved indefinitely');
      });

      test('3.2: Multi-refresh retention across Workbench Mode transitions (Studio <-> Garage)', () async {
        var repo = JobRepository();
        await repo.init();

        // Switch to Studio mode
        repo.toggleHostMode(targetRole: UserRole.detailer);
        expect(repo.isDetailerWorkbenchMode, isTrue);
        expect(repo.workbenchMode, equals('studio'));

        // Add custom package while in Studio mode
        const studioPkg = ServicePackage(
          id: 'pkg_studio_exclusive',
          title: 'Studio Exclusive Coating',
          description: 'Special studio package',
          basePrice: 1200.0,
          estimatedDuration: '8 hrs',
          includes: ['Paint Correction Level 3', 'Dual Layer Ceramic'],
        );
        repo.addServicePackage(studioPkg);

        // Reload 1: Check Studio mode and package retained
        repo = JobRepository();
        await repo.init();

        expect(repo.isDetailerWorkbenchMode, isTrue);
        expect(repo.workbenchMode, equals('studio'));
        expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_studio_exclusive'), isTrue);

        // Switch to Garage mode
        repo.toggleHostMode(targetRole: UserRole.client);
        expect(repo.isDetailerWorkbenchMode, isFalse);
        expect(repo.workbenchMode, equals('garage'));

        // Reload 2: Check Garage mode retained and package still intact in dedicated storage
        repo = JobRepository();
        await repo.init();

        expect(repo.isDetailerWorkbenchMode, isFalse);
        expect(repo.workbenchMode, equals('garage'));
        expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_studio_exclusive'), isTrue);

        // Reload 3: Switch back to Studio mode and check package
        repo.toggleHostMode(targetRole: UserRole.detailer);
        repo = JobRepository();
        await repo.init();

        expect(repo.isDetailerWorkbenchMode, isTrue);
        expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_studio_exclusive'), isTrue);
      });

      test('3.3: Verify browser refresh using TestHarness.simulateBrowserRefresh across successive cycles', () async {
        var harnessRepo = await TestHarness.createSession(isLoggedIn: true);
        const pkgX = ServicePackage(
          id: 'pkg_harness_x',
          title: 'Harness Ceramic Polish',
          description: 'Harness verified package',
          basePrice: 620.0,
          estimatedDuration: '4 hrs',
          includes: ['Polish', 'Seal'],
        );
        harnessRepo.addServicePackage(pkgX);

        // Successive refreshes via TestHarness
        harnessRepo = await TestHarness.simulateBrowserRefresh(harnessRepo);
        expect(harnessRepo.currentUser.servicePackages.any((p) => p.id == 'pkg_harness_x'), isTrue);

        harnessRepo = await TestHarness.simulateBrowserRefresh(harnessRepo);
        expect(harnessRepo.currentUser.servicePackages.any((p) => p.id == 'pkg_harness_x'), isTrue);

        harnessRepo = await TestHarness.simulateBrowserRefresh(harnessRepo);
        final found = harnessRepo.currentUser.servicePackages.firstWhere((p) => p.id == 'pkg_harness_x');
        expect(found.basePrice, equals(620.0));
      });
    });
  });
}
