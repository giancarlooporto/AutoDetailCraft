import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/screens/vehicle_editor_dialog.dart';
import 'package:detail_craft/screens/add_team_member_dialog.dart';
import 'package:detail_craft/widgets/inventory_item_editor_dialog.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone M4: UI/UX Empty States, Validation & 390px Responsiveness', () {
    testWidgets('UI-1: DetailerWorkbenchView Services tab renders glassmorphic empty state card when no package is selected', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: DetailerWorkbenchView(repository: repo)),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Services tab
        await tester.tap(find.text('Services'));
        await tester.pumpAndSettle();

        // Verify dark glassmorphic empty state placeholder elements
        expect(find.text('Select or Create a Service Package'), findsOneWidget);
        expect(find.text('Create New Package'), findsWidgets);
        expect(find.byIcon(Icons.miscellaneous_services_outlined), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI-2: ServicePackageEditorDialog shows validation SnackBar on empty submission', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ServicePackageEditorDialog(
              onSave: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear title and tap Create Package
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Create Package'));
      await tester.pump();

      // Verify floating SnackBar alerting user to required fields
      expect(find.text('Please fill in all required package fields marked in red.'), findsOneWidget);
    });

    testWidgets('UI-3: PublicStudioScreen bottom docked bar renders without RenderFlex overflow on 390px mobile', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: PublicStudioScreen(
              detailer: repo.currentUser,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must not throw RenderFlex overflow
        expect(tester.takeException(), isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI-4: JobDetailScreen bottom docked action bar renders without RenderFlex overflow on 390px mobile', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();
        final job = repo.allJobs.isNotEmpty ? repo.allJobs.first : createTestJob();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: JobDetailScreen(job: job, repository: repo),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Must not throw RenderFlex overflow
        expect(tester.takeException(), isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI-5: BookingFlowScreen multi-step flow renders without RenderFlex overflow on 390px mobile', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();
        final pkg = repo.currentUser.servicePackages.first;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: repo.currentUser,
              initialPackage: pkg,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 0: Package Selection
        expect(tester.takeException(), isNull, reason: 'Step 0 (Package) must not overflow');

        // Advance to Step 1: Vehicle & Date
        final continueBtn = find.text('Continue');
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Step 1 (Vehicle & Date) must not overflow');

        // Advance to Step 2: Checkout & Review
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Step 2 (Checkout Review) must not overflow');

        // Back navigation
        final backBtn = find.text('Back');
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Back navigation to Step 1 must not overflow');
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI-6: Responsive dialogs action rows render cleanly on 390px mobile without overflow', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        // 1. VehicleEditorDialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: VehicleEditorDialog(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. AddTeamMemberDialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AddTeamMemberDialog(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. InventoryItemEditorDialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: InventoryItemEditorDialog(onSave: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final err = tester.takeException();
        if (err is FlutterError) {
          // ignore: avoid_print
          print(err.toStringDeep());
        }
        expect(err, isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
