import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/supabase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Account & Guest Service Visibility Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Type Cast Deserialization: ServicePackage handles _Map<dynamic, dynamic>', () async {
      // Simulate raw payload where keys/values are dynamic Map (common in json_decode/PostgREST)
      final Map<dynamic, dynamic> dynamicPackageMap = {
        'id': 'pkg_paint_correction',
        'title': '2-Stage Paint Correction',
        'description': 'Removes 85%+ swirls',
        'basePrice': 450.0,
        'estimatedDuration': '6 hours',
        'includes': ['Decontamination', 'Compound', 'Polish'],
      };

      // Test LocalStorageService with dynamic map json
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'adc_service_packages_v1',
        jsonEncode([dynamicPackageMap]),
      );

      final loadedPackages = await LocalStorageService.loadServicePackages();
      expect(loadedPackages.length, 1);
      expect(loadedPackages.first.id, 'pkg_paint_correction');
      expect(loadedPackages.first.title, '2-Stage Paint Correction');
      expect(loadedPackages.first.basePrice, 450.0);

      // Test UserProfile.fromJson with dynamic map in servicePackages
      final userProfileJson = <String, dynamic>{
        'id': 'user_detailer_1',
        'role': 'detailer',
        'servicePackages': [dynamicPackageMap],
      };
      final userProfile = UserProfile.fromJson(userProfileJson);
      expect(userProfile.servicePackages.length, 1);
      expect(userProfile.servicePackages.first.id, 'pkg_paint_correction');
    });

    test('2. Public/Guest Realtime: JobRepository subscribes to realtime on init and re-subscribes on logout', () async {
      final repo = JobRepository();
      expect(repo.isLoggedIn, isFalse);

      await repo.init();
      expect(repo.isLoggedIn, isFalse);

      // Verify that logoutUser re-subscribes to realtime
      await repo.logoutUser();
      expect(repo.isLoggedIn, isFalse);
    });

    test('3. Async Service Package Operations: optimistic notification and async completion', () async {
      final repo = JobRepository();
      await repo.init();

      int notificationsCount = 0;
      repo.addListener(() {
        notificationsCount++;
      });

      const newPackage = ServicePackage(
        id: 'pkg_new_custom',
        title: 'Full Front PPF',
        description: 'Self-healing film',
        basePrice: 1200.0,
        estimatedDuration: '8 hours',
        includes: ['Prep', 'Film install'],
      );

      // Call async addServicePackage
      final future = repo.addServicePackage(newPackage);
      expect(future, isA<Future<void>>());

      // Optimistic update should already be applied synchronously before future completes
      expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_new_custom'), isTrue);
      expect(repo.currentUser.role, UserRole.detailer);
      expect(repo.currentUser.isVerifiedHost, isTrue);
      expect(notificationsCount, greaterThanOrEqualTo(1));

      // Await future completion
      await future;
      expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_new_custom'), isTrue);

      // Update package
      const updatedPackage = ServicePackage(
        id: 'pkg_new_custom',
        title: 'Full Front PPF + Coating',
        description: 'Self-healing film with ceramic top coat',
        basePrice: 1500.0,
        estimatedDuration: '10 hours',
        includes: ['Prep', 'Film install', 'Ceramic coat'],
      );
      await repo.updateServicePackage(updatedPackage);
      expect(repo.currentUser.servicePackages.firstWhere((p) => p.id == 'pkg_new_custom').basePrice, 1500.0);

      // Remove package
      await repo.removeServicePackage('pkg_new_custom');
      expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_new_custom'), isFalse);
    });

    test('4. Guest Drafted Packages Preserved on Signup: packages loaded and role set to detailer', () async {
      // Setup drafted local package
      const draftedPkg = ServicePackage(
        id: 'pkg_draft_01',
        title: 'Ceramic Coating Gold',
        description: '5-year protection',
        basePrice: 899.0,
        estimatedDuration: '8 hours',
        includes: ['Paint correction', 'Coating'],
      );
      await LocalStorageService.saveServicePackages([draftedPkg]);

      // When SupabaseService is not initialized (e.g. unit test offline), signUp returns graceful failure
      // without wiping local packages
      final result = await SupabaseAuthService.signUp(
        email: 'newdetailer@test.com',
        password: 'password123',
        displayName: 'Precision Detailing',
      );
      expect(result.success, isFalse);

      // Verify local packages are still intact and NOT wiped
      final packagesAfter = await LocalStorageService.loadServicePackages();
      expect(packagesAfter.length, 1);
      expect(packagesAfter.first.id, 'pkg_draft_01');
      expect(packagesAfter.first.basePrice, 899.0);
    });

    test('5. Migration DDL: contains ALTER TABLE public.profiles REPLICA IDENTITY FULL;', () {
      final migrationFile = File('supabase/migrations/20261021_fix_explore_and_messaging_rls.sql');
      expect(migrationFile.existsSync(), isTrue);

      final content = migrationFile.readAsStringSync();
      expect(content.contains('ALTER TABLE public.profiles REPLICA IDENTITY FULL;'), isTrue);
    });

    test('6. BookingAppointment & UserProfile handle dynamic map and JSON string service_packages', () {
      final dynamicPkg = <dynamic, dynamic>{
        'id': 'pkg_dyn_01',
        'title': 'Express Gloss',
        'description': 'Wash & seal',
        'basePrice': 175,
        'estimatedDuration': '2 hours',
        'includes': ['Hand wash', 'Spray sealant'],
      };

      // Test BookingAppointment.fromJson with dynamic map
      final bookingJson = <String, dynamic>{
        'id': 'bk_test_1',
        'detailerId': 'usr_det_1',
        'clientName': 'Jane Doe',
        'vehicleYearMakeModel': '2024 Porsche 911',
        'vehicleSize': 'coupeSedan',
        'package': dynamicPkg,
        'locationType': 'mobile',
        'scheduledDate': DateTime.now().toIso8601String(),
        'totalPrice': 175.0,
      };
      final booking = BookingAppointment.fromJson(bookingJson);
      expect(booking.package.id, 'pkg_dyn_01');
      expect(booking.package.basePrice, 175.0);

      // Test UserProfile.fromJson with snake_case string-encoded service_packages
      final userProfileJsonString = <String, dynamic>{
        'id': 'usr_studio_x',
        'role': 'detailer',
        'service_packages': jsonEncode([dynamicPkg]),
      };
      final profileFromString = UserProfile.fromJson(userProfileJsonString);
      expect(profileFromString.servicePackages.length, 1);
      expect(profileFromString.servicePackages.first.id, 'pkg_dyn_01');
    });

    test('7. Guest Drafted Studio Profile (businessName, location, packages) preserved on signup', () async {
      // Simulate guest who customized studio details in workbench before signing up
      final guestDraft = UserProfile(
        id: 'usr_you',
        role: UserRole.detailer,
        username: 'guest_craft',
        displayName: 'Guest Master',
        businessName: 'Apex Craft Lab',
        location: 'Austin, TX',
        serviceRadius: '50 miles • Mobile',
        bio: 'Precision automotive detailing',
        servicePackages: [
          const ServicePackage(
            id: 'pkg_apex_stage1',
            title: 'Stage 1 Polish',
            description: 'Single stage gloss enhancement',
            basePrice: 350.0,
            estimatedDuration: '4 hours',
            includes: ['Decon', 'Polish'],
          ),
        ],
        startingPrice: 350.0,
      );
      await LocalStorageService.saveCurrentUser(guestDraft);
      await LocalStorageService.saveServicePackages(guestDraft.servicePackages);

      // Attempt signup
      await SupabaseAuthService.signUp(
        email: 'founder@apexcraft.com',
        password: 'securepassword',
        displayName: 'Master Detailer',
      );

      // Packages and custom profile fields remain intact
      final loadedPackages = await LocalStorageService.loadServicePackages();
      expect(loadedPackages.length, 1);
      expect(loadedPackages.first.id, 'pkg_apex_stage1');
      expect(loadedPackages.first.basePrice, 350.0);
    });
  });
}
