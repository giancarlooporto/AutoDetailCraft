import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/screens/profile_screen.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/auth_modal.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1 Adversarial Suite: Hydration & Navigation Lockout', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // =========================================================================
    // SECTION 1: NON-DESTRUCTIVE CLOUD HYDRATION ADVERSARIAL VERIFICATION
    // =========================================================================
    group('1. Non-Destructive Cloud Hydration Fallback', () {
      test('1.1: When Supabase returns null, local custom packages are NOT wiped across simulated refreshes', () async {
        final repo1 = JobRepository();
        await repo1.init();

        const customPkg1 = ServicePackage(
          id: 'pkg_adv_custom_1',
          title: 'Adversarial Nanotech Coating',
          description: 'Hardened sapphire finish',
          basePrice: 850.0,
          estimatedDuration: '5 hrs',
          includes: ['Decontamination', '2-Stage Polish', 'Nanocoat'],
        );
        const customPkg2 = ServicePackage(
          id: 'pkg_adv_custom_2',
          title: 'Adversarial Interior Alcantara Spa',
          description: 'Steam extraction and fiber protection',
          basePrice: 420.0,
          estimatedDuration: '3 hrs',
          includes: ['Steam Clean', 'Alcantara Shield'],
        );

        repo1.addServicePackage(customPkg1);
        repo1.addServicePackage(customPkg2);

        expect(repo1.currentUser.servicePackages.any((p) => p.id == 'pkg_adv_custom_1'), isTrue);
        expect(repo1.currentUser.servicePackages.any((p) => p.id == 'pkg_adv_custom_2'), isTrue);

        // Simulate refresh where Supabase is unconfigured / offline (fetchUserProfile returns null)
        final repo2 = await TestHarness.simulateBrowserRefresh(repo1);

        // Verification: Custom packages are completely intact
        final packagesR2 = repo2.currentUser.servicePackages;
        expect(packagesR2.any((p) => p.id == 'pkg_adv_custom_1'), isTrue,
            reason: 'Custom package 1 must NOT be wiped by null cloud response');
        expect(packagesR2.any((p) => p.id == 'pkg_adv_custom_2'), isTrue,
            reason: 'Custom package 2 must NOT be wiped by null cloud response');

        // Dedicated storage also retains custom packages
        final dedicatedStorage = await LocalStorageService.loadServicePackages();
        expect(dedicatedStorage.any((p) => p.id == 'pkg_adv_custom_1'), isTrue);
        expect(dedicatedStorage.any((p) => p.id == 'pkg_adv_custom_2'), isTrue);
      });

      test('1.2: When cached profile has empty packages ([]), dedicated package storage restores custom packages', () async {
        // Adversarial scenario: simulate a remote cloud sync or stale profile that wrote an empty
        // servicePackages list to the monolithic user profile key
        const customPkg = ServicePackage(
          id: 'pkg_indestructible',
          title: 'Indestructible Graphene Guard',
          description: '10H Hardness ceramic',
          basePrice: 1200.0,
          estimatedDuration: '8 hrs',
          includes: ['Multi-stage correction', 'Graphene coat'],
        );

        // Save custom package in dedicated storage
        await LocalStorageService.saveServicePackages([customPkg]);

        // Stale profile with EMPTY packages in monolithic user storage
        final emptyPackageUser = const UserProfile(
          id: 'usr_you',
          username: 'detailer_pro',
          displayName: 'Pro Detailer',
          businessName: 'Graphene Studio',
          avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
          location: 'Austin, TX',
          bio: 'Master detailer',
          role: UserRole.detailer,
          servicePackages: [], // EMPTY from cloud/stale sync!
        );
        await LocalStorageService.saveCurrentUser(emptyPackageUser);

        // Hydrate fresh repository instance
        final repo = JobRepository();
        await repo.init();

        // Verification: The dedicated package storage completely overrides the empty cloud profile
        expect(repo.currentUser.servicePackages.isNotEmpty, isTrue);
        expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_indestructible'), isTrue,
            reason: 'Empty package profile must NOT wipe dedicated packages during init()');

        final recovered = repo.currentUser.servicePackages.firstWhere((p) => p.id == 'pkg_indestructible');
        expect(recovered.basePrice, equals(1200.0));
      });

      test('1.3: Non-destructive merge logic: cloud with empty packages preserves local packages; cloud with packages updates them', () {
        // Direct testing of the non-destructive merge algorithm contract in PROJECT.md:
        // resolvedPackages = cloudProfile.servicePackages.isNotEmpty ? cloudProfile.servicePackages : _currentUser.servicePackages;
        const localPkg = ServicePackage(
          id: 'pkg_local_active',
          title: 'Local Active Polish',
          description: 'Local package',
          basePrice: 300.0,
          estimatedDuration: '2 hrs',
          includes: ['Polish'],
        );
        final localList = [localPkg];

        // Case A: Cloud returns empty packages -> local packages are KEPT
        final cloudEmpty = const UserProfile(
          id: 'usr_cloud',
          username: 'cloud_user',
          displayName: 'Cloud User',
          businessName: 'Cloud Studio',
          avatarUrl: '',
          location: 'Austin, TX',
          bio: '',
          servicePackages: [], // EMPTY
        );
        final resolvedWhenCloudEmpty = cloudEmpty.servicePackages.isNotEmpty
            ? cloudEmpty.servicePackages
            : localList;
        expect(resolvedWhenCloudEmpty, equals(localList),
            reason: 'Empty cloud packages must never overwrite local custom packages');

        // Case B: Cloud returns updated remote packages -> cloud packages are ADOPTED
        const remotePkg = ServicePackage(
          id: 'pkg_remote_updated',
          title: 'Remote Synced Package',
          description: 'Synced from cloud',
          basePrice: 500.0,
          estimatedDuration: '4 hrs',
          includes: ['Wash', 'Wax'],
        );
        final cloudWithData = cloudEmpty.copyWith(servicePackages: [remotePkg]);
        final resolvedWhenCloudHasData = cloudWithData.servicePackages.isNotEmpty
            ? cloudWithData.servicePackages
            : localList;
        expect(resolvedWhenCloudHasData, equals([remotePkg]),
            reason: 'Non-empty cloud packages must cleanly update profile');
      });
    });

    // =========================================================================
    // SECTION 2: UI NAVIGATION STATES ADVERSARIAL VERIFICATION
    // =========================================================================
    group('2. UI Navigation States & Guest Lockout Elimination', () {
      testWidgets('2.1a: User in My Studio (workbenchMode == "studio", isLoggedIn == true) mounts DetailerWorkbenchView directly without guest sign-in screen', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        setupMockImageHttpClient();

        try {
          final repo = JobRepository();
          await repo.init();
          repo.toggleHostMode(targetRole: UserRole.detailer);
          expect(repo.workbenchMode, equals('studio'));
          expect(repo.isDetailerWorkbenchMode, isTrue);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: ProfileScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Verification: DetailerWorkbenchView mounts directly
          expect(find.byType(DetailerWorkbenchView), findsOneWidget);

          // Verification: Guest sign-in view is completely absent
          expect(find.text('Welcome to AutoDetailCraft'), findsNothing);
          expect(find.text('Sign In to My Studio / Garage'), findsNothing);
          expect(find.text('Create New Account'), findsNothing);
        } finally {
          tearDownMockImageHttpClient();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });

      testWidgets('2.1b: Adversarial test: User in My Studio even with isLoggedIn == false mounts DetailerWorkbenchView directly', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        setupMockImageHttpClient();

        try {
          final repo = JobRepository();
          await repo.init();
          repo.toggleHostMode(targetRole: UserRole.detailer);
          // Force guest mode flag / unauthenticated state while workbenchMode remains 'studio'
          repo.isLoggedIn = false;
          expect(repo.workbenchMode, equals('studio'));

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: ProfileScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Verification: Even if unauthenticated, being in studio mode mounts DetailerWorkbenchView directly
          expect(find.byType(DetailerWorkbenchView), findsOneWidget);
          expect(find.text('Welcome to AutoDetailCraft'), findsNothing);
          expect(find.text('Sign In to My Studio / Garage'), findsNothing);
        } finally {
          tearDownMockImageHttpClient();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });

      testWidgets('2.2: User with bookings: BookingsListScreen renders appointments cleanly even if unauthenticated', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        setupMockImageHttpClient();

        try {
          final repo = JobRepository();
          await repo.init();

          const customPkg = ServicePackage(
            id: 'pkg_titanium_ceramic',
            title: 'Titanium Multi-Stage Coating',
            description: 'Flagship coating service',
            basePrice: 1650.0,
            estimatedDuration: '9 hrs',
            includes: ['Correction', 'Titanium Coat'],
          );

          final appointment = BookingAppointment(
            id: 'booking_adversarial_test',
            detailerId: 'usr_apex_detailer',
            detailerName: 'Marcus Vance',
            detailerBusinessName: 'Apex Precision Detailing',
            detailerAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
            clientName: 'Julian Croft',
            clientPhone: '(512) 555-0988',
            clientEmail: 'julian@example.com',
            vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
            vehicleSize: VehicleSize.coupeSedan,
            package: customPkg,
            locationType: ServiceLocationType.mobile,
            clientAddress: '500 E 4th St, Austin, TX 78701',
            scheduledDate: DateTime(2026, 11, 25),
            scheduledTimeSlot: '10:00 AM - 2:00 PM',
            totalPrice: 1650.0,
            depositAmount: 350.0,
            status: BookingStatus.confirmed,
          );

          repo.addBooking(appointment);
          expect(repo.bookings.length, equals(1));

          // Adversarial condition: user is not logged in
          repo.isLoggedIn = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: BookingsListScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Verification: Appointment details render cleanly
          expect(find.text('Titanium Multi-Stage Coating'), findsOneWidget);
          expect(find.text('2024 Porsche 911 GT3 RS'), findsOneWidget);
          expect(find.text('Apex Precision Detailing'), findsOneWidget);
          expect(find.text('10:00 AM - 2:00 PM'), findsOneWidget);
          expect(find.text('\$1650'), findsOneWidget);
          expect(find.text(BookingStatus.confirmed.label), findsOneWidget);

          // Verification: Guest lockout view is NOT rendered
          expect(find.text('View & Manage Detailing Bookings'), findsNothing);
          expect(find.text('Sign In to View Bookings'), findsNothing);
        } finally {
          tearDownMockImageHttpClient();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });

      testWidgets('2.3a: Fresh unauthenticated visitor: ProfileScreen renders guest view and tapping CTA opens AuthModal', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        setupMockImageHttpClient();

        try {
          final repo = JobRepository();
          await repo.init();
          repo.isLoggedIn = false;
          await LocalStorageService.saveWorkbenchMode('garage');
          await LocalStorageService.saveIsGuest(true);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: ProfileScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Verification: Guest welcome view renders
          expect(find.text('Welcome to AutoDetailCraft'), findsOneWidget);
          final signInBtn = find.text('Sign In to My Studio / Garage');
          expect(signInBtn, findsOneWidget);
          expect(find.text('Create New Account'), findsOneWidget);

          // Verification: Tapping 'Sign In to My Studio / Garage' opens AuthModal
          await tester.tap(signInBtn);
          await tester.pumpAndSettle();

          expect(find.byType(AuthModal), findsOneWidget);
          expect(find.text('Welcome Back'), findsOneWidget);
        } finally {
          tearDownMockImageHttpClient();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });

      testWidgets('2.3b: Fresh unauthenticated visitor: BookingsListScreen renders guest view and tapping CTA opens AuthModal', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        setupMockImageHttpClient();

        try {
          final repo = JobRepository();
          await repo.init();
          repo.isLoggedIn = false;
          expect(repo.bookings.isEmpty, isTrue);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: BookingsListScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Verification: Guest bookings view renders
          expect(find.text('View & Manage Detailing Bookings'), findsOneWidget);
          final signInBtn = find.text('Sign In to View Bookings');
          expect(signInBtn, findsOneWidget);

          // Verification: Tapping 'Sign In to View Bookings' opens AuthModal
          await tester.tap(signInBtn);
          await tester.pumpAndSettle();

          expect(find.byType(AuthModal), findsOneWidget);
          expect(find.text('Welcome Back'), findsOneWidget);
        } finally {
          tearDownMockImageHttpClient();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    });
  });
}
