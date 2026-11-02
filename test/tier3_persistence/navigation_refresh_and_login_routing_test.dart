import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Navigation Persistence, Bookings Default & Login Routing Tests', () {
    // =========================================================================
    // SECTION 1: PAGE & VIEW PERSISTENCE ACROSS REFRESH
    // =========================================================================
    group('1. Page & View Persistence Across Simulated Browser Refresh', () {
      test('1.1: Client side: active navigation tab (Explore, Bookings, Messages, Garage) survives refresh', () async {
        final repo1 = JobRepository();
        await repo1.init();

        // Navigate to Bookings (tab 1)
        repo1.setActiveTab(1);
        expect(repo1.activeTabIndex, 1);
        expect(await LocalStorageService.loadActiveTab(), 1);

        // Simulate refresh
        final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
        expect(repo2.activeTabIndex, 1);

        // Navigate to Messages (tab 2) and refresh
        repo2.setActiveTab(2);
        expect(repo2.activeTabIndex, 2);
        final repo3 = await TestHarness.simulateBrowserRefresh(repo2);
        expect(repo3.activeTabIndex, 2);

        // Navigate to My Garage (tab 3) and refresh
        repo3.setActiveTab(3);
        expect(repo3.activeTabIndex, 3);
        final repo4 = await TestHarness.simulateBrowserRefresh(repo3);
        expect(repo4.activeTabIndex, 3);
      });

      test('1.2: Client side: BookingsListScreen subtab selection survives refresh', () async {
        final repo1 = JobRepository();
        await repo1.init();

        // User sets subtab to In Progress (2)
        repo1.setBookingsTabIndex(2);
        expect(repo1.bookingsTabIndex, 2);
        expect(await LocalStorageService.loadClientBookingsTab(), 2);

        // Refresh
        final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
        expect(repo2.bookingsTabIndex, 2);

        // User sets subtab to Completed (3)
        repo2.setBookingsTabIndex(3);
        final repo3 = await TestHarness.simulateBrowserRefresh(repo2);
        expect(repo3.bookingsTabIndex, 3);
      });

      test('1.3: Client side: My Garage vs Saved Recipes profile tab survives refresh', () async {
        await LocalStorageService.saveClientProfileTabIndex(1); // Saved Recipes
        expect(await LocalStorageService.loadClientProfileTabIndex(), 1);

        await LocalStorageService.saveClientProfileTabIndex(0); // My Garage
        expect(await LocalStorageService.loadClientProfileTabIndex(), 0);
      });

      test('1.4: Detailer side: workbenchMode (studio) and active StudioHubSection survive refresh', () async {
        final repo1 = JobRepository();
        await repo1.init();

        // Switch to detailer mode
        repo1.toggleHostMode(targetRole: UserRole.detailer);
        expect(repo1.isDetailerWorkbenchMode, isTrue);
        expect(repo1.workbenchMode, 'studio');
        expect(await LocalStorageService.loadWorkbenchMode(), 'studio');

        // Persist studio hub section to calendar
        await LocalStorageService.saveStudioHubSection(StudioHubSection.calendar.name);
        expect(await LocalStorageService.loadStudioHubSection(), 'calendar');

        // Refresh
        final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
        expect(repo2.isDetailerWorkbenchMode, isTrue);
        expect(repo2.workbenchMode, 'studio');
        expect(await LocalStorageService.loadStudioHubSection(), 'calendar');
      });

      test('1.5: Detailer side: sub-views and inspector selections survive refresh', () async {
        // Save selected items in LocalStorageService
        await LocalStorageService.saveStudioHubSection(StudioHubSection.services.name);
        await LocalStorageService.saveSelectedServicePackageId('pkg_test_ceramic');
        await LocalStorageService.saveSelectedStudioBookingId('bk_test_99');
        await LocalStorageService.saveSelectedStudioConversationId('conv_test_12');
        await LocalStorageService.saveSelectedPortfolioJobId('job_test_42');
        await LocalStorageService.saveSelectedTeamMemberSectionId('member_test_01');
        await LocalStorageService.saveSelectedSettingsCategory('STUDIO_PROFILE');
        await LocalStorageService.saveStudioBookingFilter('CONFIRMED');
        await LocalStorageService.saveSelectedCalendarTeamMemberId('member_test_01');

        // Verify restoration
        expect(await LocalStorageService.loadStudioHubSection(), 'services');
        expect(await LocalStorageService.loadSelectedServicePackageId(), 'pkg_test_ceramic');
        expect(await LocalStorageService.loadSelectedStudioBookingId(), 'bk_test_99');
        expect(await LocalStorageService.loadSelectedStudioConversationId(), 'conv_test_12');
        expect(await LocalStorageService.loadSelectedPortfolioJobId(), 'job_test_42');
        expect(await LocalStorageService.loadSelectedTeamMemberSectionId(), 'member_test_01');
        expect(await LocalStorageService.loadSelectedSettingsCategory(), 'STUDIO_PROFILE');
        expect(await LocalStorageService.loadStudioBookingFilter(), 'CONFIRMED');
        expect(await LocalStorageService.loadSelectedCalendarTeamMemberId(), 'member_test_01');
      });

      test('1.6: Detailer side: selected calendar date survives refresh', () async {
        final testDate = DateTime(2026, 12, 15);
        await LocalStorageService.saveSelectedCalendarDate(testDate);

        final loadedDate = await LocalStorageService.loadSelectedCalendarDate();
        expect(loadedDate, isNotNull);
        expect(loadedDate!.year, 2026);
        expect(loadedDate.month, 12);
        expect(loadedDate.day, 15);
      });
    });

    // =========================================================================
    // SECTION 2: CLIENT APPOINTMENTS & BOOKINGS DEFAULT TO ALL
    // =========================================================================
    group('2. Client Appointments & Bookings Tab Defaults to All', () {
      test('2.1: Clicking Bookings tab defaults bookingsTabIndex to 0 (All)', () async {
        final repo = JobRepository();
        await repo.init();

        // User previously had subtab 2 selected
        repo.setBookingsTabIndex(2);
        expect(repo.bookingsTabIndex, 2);

        // Clicking Bookings resets subtab to All (0)
        repo.setBookingsTabIndex(0);
        repo.setActiveTab(1);

        expect(repo.activeTabIndex, 1);
        expect(repo.bookingsTabIndex, 0);
        expect(await LocalStorageService.loadClientBookingsTab(), 0);
      });

      testWidgets('2.2: MainNavigationScreen navigation to Bookings opens All tab by default', (tester) async {
        setupMockImageHttpClient();
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        try {
          final repo = JobRepository();
          await repo.init();
          repo.isLoggedIn = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MainNavigationScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Start on Explore
          expect(repo.activeTabIndex, 0);

          // Tap Bookings in Desktop Navigation
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();

          expect(repo.activeTabIndex, 1);
          expect(repo.bookingsTabIndex, 0);

          // All tab is visible
          expect(find.text('All (0)'), findsOneWidget);
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('2.3: Mobile bottom navigation clicking Bookings resets bookingsTabIndex to 0 (All) even if already on Bookings', (tester) async {
        setupMockImageHttpClient();
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        try {
          final repo = JobRepository();
          await repo.init();
          repo.isLoggedIn = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MainNavigationScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Start on Explore, tap Bookings
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();
          expect(repo.activeTabIndex, 1);
          expect(repo.bookingsTabIndex, 0);

          // Change subtab to Completed (3)
          repo.setBookingsTabIndex(3);
          await tester.pumpAndSettle();
          expect(repo.bookingsTabIndex, 3);

          // Tap Bookings again on mobile navigation bar
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();

          // Must reset to 0 (All)
          expect(repo.bookingsTabIndex, 0);
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('2.4: DefaultTabController dynamically updates tab to All when bookingsTabIndex changes', (tester) async {
        setupMockImageHttpClient();
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        try {
          final repo = JobRepository();
          await repo.init();
          repo.isLoggedIn = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MainNavigationScreen(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          // Navigate to Bookings
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();

          // Switch subtab to Completed (3)
          await tester.tap(find.text('Completed (0)'));
          await tester.pumpAndSettle();
          expect(repo.bookingsTabIndex, 3);

          // Switch to Explore
          await tester.tap(find.text('Explore'));
          await tester.pumpAndSettle();
          expect(repo.activeTabIndex, 0);

          // Click Bookings again
          await tester.tap(find.text('Bookings'));
          await tester.pumpAndSettle();

          // Must be on All (0)
          expect(repo.bookingsTabIndex, 0);
          expect(find.text('No Bookings Found'), findsOneWidget);
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    });

    // =========================================================================
    // SECTION 3: LOGIN & GUEST NAVIGATION ROUTING DEFAULTS
    // =========================================================================
    group('3. Login & Guest Navigation Routing Defaults', () {
      test('3.1: Guest mode defaults landing screen to Explore (tab 0)', () async {
        final repo = JobRepository();
        await repo.init();

        expect(repo.isGuestMode, isTrue);
        expect(repo.activeTabIndex, 0);
      });

      test('3.2: Logging in as standard client account (no detailer mode) defaults to My Garage (tab 3, garage mode)', () async {
        final repo = JobRepository();
        await repo.init();

        final standardClient = UserProfile(
          id: 'usr_client_standard',
          username: 'johndoe',
          displayName: 'John Doe',
          role: UserRole.client,
          businessName: '',
          servicePackages: const [],
          isVerifiedHost: false,
        );

        await repo.loginUser(standardClient);

        // Land on My Garage (tab 3 in garage mode)
        expect(repo.isLoggedIn, isTrue);
        expect(repo.currentUser.role, UserRole.client);
        expect(repo.workbenchMode, 'garage');
        expect(repo.activeTabIndex, 3);
        expect(await LocalStorageService.loadActiveTab(), 3);
        expect(await LocalStorageService.loadWorkbenchMode(), 'garage');
        expect(await LocalStorageService.loadClientProfileTabIndex(), 0);
      });

      test('3.3: Logging in as detailer account (has detailer mode) defaults to My Studio (tab 3, studio mode)', () async {
        final repo = JobRepository();
        await repo.init();

        final detailerUser = UserProfile(
          id: 'usr_detailer_pro',
          username: 'apex_detailing',
          displayName: 'Apex Detailing Co',
          businessName: 'Apex Detailing Co',
          role: UserRole.detailer,
          isVerifiedHost: true,
          servicePackages: const [
            ServicePackage(
              id: 'pkg_apex_paint',
              title: 'Apex Multi-Stage Ceramic',
              description: 'Multi-stage paint correction and ceramic coating',
              basePrice: 999.0,
              estimatedDuration: '6 hours',
              includes: ['Paint Correction', 'Ceramic Coat'],
            ),
          ],
        );

        await repo.loginUser(detailerUser);

        // Land on My Studio (tab 3 in studio mode)
        expect(repo.isLoggedIn, isTrue);
        expect(repo.hasDetailerMode, isTrue);
        expect(repo.currentUser.role, UserRole.detailer);
        expect(repo.workbenchMode, 'studio');
        expect(repo.activeTabIndex, 3);
        expect(await LocalStorageService.loadActiveTab(), 3);
        expect(await LocalStorageService.loadWorkbenchMode(), 'studio');
      });

      test('3.3b: Logging in as detailer with empty business name still defaults to My Studio (tab 3, studio mode) without role demotion', () async {
        final repo = JobRepository();
        await repo.init();

        final detailerNoBizName = UserProfile(
          id: 'usr_detailer_individual',
          username: 'solo_pro',
          displayName: 'Solo Detailer',
          businessName: '', // empty business name
          role: UserRole.detailer,
          isVerifiedHost: true,
        );

        await repo.loginUser(detailerNoBizName);

        // Land on My Studio (tab 3 in studio mode) without being demoted to client!
        expect(repo.isLoggedIn, isTrue);
        expect(repo.hasDetailerMode, isTrue);
        expect(repo.currentUser.role, UserRole.detailer);
        expect(repo.workbenchMode, 'studio');
        expect(repo.activeTabIndex, 3);
        expect(await LocalStorageService.loadActiveTab(), 3);
        expect(await LocalStorageService.loadWorkbenchMode(), 'studio');
      });

      test('3.3c: Standard client with service packages (no detailer mode) defaults to My Garage on login', () async {
        final repo = JobRepository();
        await repo.init();

        const clientWithPackages = UserProfile(
          id: 'usr_client_packages',
          role: UserRole.client,
          username: 'alex_owner',
          displayName: 'Alex Vehicle Owner',
          businessName: '',
          servicePackages: [
            ServicePackage(
              id: 'pkg_express_wash',
              title: 'Express Exterior Wash',
              description: 'Foam wash and dry',
              basePrice: 75.0,
              estimatedDuration: '1.5 hrs',
              includes: ['Wash', 'Dry'],
            ),
          ],
        );

        await repo.loginUser(clientWithPackages);

        expect(repo.isLoggedIn, isTrue);
        expect(repo.hasDetailerMode, isFalse);
        expect(repo.currentUser.role, UserRole.client);
        expect(repo.workbenchMode, 'garage');
        expect(repo.activeTabIndex, 3);
        expect(await LocalStorageService.loadActiveTab(), 3);
        expect(await LocalStorageService.loadWorkbenchMode(), 'garage');
      });

      test('3.4: Staff member login defaults to My Studio (tab 3, studio mode)', () async {
        final repo = JobRepository();
        await repo.init();

        // Create a detailer with team member
        final detailer = UserProfile(
          id: 'usr_shop_owner',
          username: 'shop_owner',
          displayName: 'Shop Owner',
          businessName: 'Master Craft Studio',
          role: UserRole.detailer,
          teamMembers: [
            TeamMember(
              id: 'tm_specialist_1',
              name: 'Marcus Tech',
              roleTitle: 'Lead Paint Correction Specialist',
              avatarUrl: 'https://example.com/avatar.jpg',
              pin: '4488',
            ),
          ],
        );
        repo.updateCurrentUser(detailer);

        final result = await repo.loginStaffMember(pin: '4488');
        expect(result.success, isTrue);
        expect(repo.isStaffSession, isTrue);
        expect(repo.isLoggedIn, isTrue);
        expect(repo.activeTabIndex, 3);
        expect(repo.workbenchMode, 'studio');
        expect(await LocalStorageService.loadActiveTab(), 3);
        expect(await LocalStorageService.loadWorkbenchMode(), 'studio');
      });

      test('3.5: Logging out returns to Guest Mode with default Explore (tab 0)', () async {
        final repo = JobRepository();
        await repo.init();

        final client = UserProfile(
          id: 'usr_client_temp',
          username: 'temp_user',
          displayName: 'Temp User',
          role: UserRole.client,
        );
        await repo.loginUser(client);
        expect(repo.activeTabIndex, 3);

        await repo.logoutUser();

        expect(repo.isGuestMode, isTrue);
        expect(repo.activeTabIndex, 0);
        expect(repo.workbenchMode, 'garage');
        expect(await LocalStorageService.loadActiveTab(), 0);
        expect(await LocalStorageService.loadWorkbenchMode(), 'garage');
      });

      test('3.6: Delete account resets to Guest Mode with default Explore (tab 0)', () async {
        final repo = JobRepository();
        await repo.init();

        final client = UserProfile(
          id: 'usr_client_delete_me',
          username: 'delete_me',
          displayName: 'Delete Me',
          role: UserRole.client,
        );
        await repo.loginUser(client);
        expect(repo.activeTabIndex, 3);

        await repo.deleteAccount();

        expect(repo.isGuestMode, isTrue);
        expect(repo.activeTabIndex, 0);
        expect(repo.workbenchMode, 'garage');
        expect(await LocalStorageService.loadActiveTab(), 0);
        expect(await LocalStorageService.loadWorkbenchMode(), 'garage');
      });
    });
  });
}
