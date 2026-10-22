import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/screens/vehicle_editor_dialog.dart';
import 'package:detail_craft/screens/add_team_member_dialog.dart';
import 'package:detail_craft/screens/calendar_preferences_dialog.dart';
import 'package:detail_craft/widgets/inventory_item_editor_dialog.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const extremeWidths = [
    Size(320, 667), // iPhone SE 1st gen / extreme narrow
    Size(360, 740), // Compact Android (Galaxy S / Pixel compact)
    Size(390, 844), // Standard iPhone 12/13/14
    Size(414, 896), // iPhone Plus / Max standard mobile
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone M4 Adversarial Viewport Stress: PublicStudioScreen', () {
    for (final size in extremeWidths) {
      testWidgets('PublicStudioScreen on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: PublicStudioScreen(
                detailer: repo.currentUser,
                repository: repo,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Tab 0: Transformations
          expect(caughtError, isNull, reason: 'PublicStudioScreen Transformations Tab overflow on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Switch to Tab 1: Services & Pricing
          await tester.tap(find.text('Services & Pricing'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(caughtError, isNull, reason: 'PublicStudioScreen Services Tab overflow on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Switch to Tab 2: About & Studio
          await tester.tap(find.text('About & Studio'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(caughtError, isNull, reason: 'PublicStudioScreen About & Studio Tab overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Adversarial Viewport Stress: JobDetailScreen', () {
    for (final size in extremeWidths) {
      testWidgets('JobDetailScreen on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();
          final job = repo.allJobs.isNotEmpty ? repo.allJobs.first : createTestJob();

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: JobDetailScreen(job: job, repository: repo),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(caughtError, isNull, reason: 'JobDetailScreen Specs Tab / Docked Bar overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Adversarial Viewport Stress: BookingFlowScreen', () {
    for (final size in extremeWidths) {
      testWidgets('BookingFlowScreen on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();
          final pkg = repo.currentUser.servicePackages.isNotEmpty
              ? repo.currentUser.servicePackages.first
              : MockDataService.standardPackages.first;

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

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
          expect(caughtError, isNull, reason: 'BookingFlowScreen Step 0 (Package) overflow on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Advance to Step 1: Vehicle & Date
          final continueBtn = find.text('Continue');
          expect(continueBtn, findsOneWidget);
          await tester.tap(continueBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'BookingFlowScreen Step 1 (Vehicle & Date) overflow on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Advance to Step 2: Checkout & Review
          await tester.tap(continueBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'BookingFlowScreen Step 2 (Checkout Review) overflow on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Back button
          final backBtn = find.text('Back');
          expect(backBtn, findsOneWidget);
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'BookingFlowScreen Back navigation overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Adversarial Viewport Stress: Dialogs', () {
    for (final size in extremeWidths) {
      testWidgets('VehicleEditorDialog on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: VehicleEditorDialog(repository: repo)),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'VehicleEditorDialog overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('ServicePackageEditorDialog on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: ServicePackageEditorDialog(onSave: (_) {})),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'ServicePackageEditorDialog overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('AddTeamMemberDialog on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: AddTeamMemberDialog(repository: repo)),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'AddTeamMemberDialog overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('InventoryItemEditorDialog on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: InventoryItemEditorDialog(onSave: (_) {})),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'InventoryItemEditorDialog overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });

      testWidgets('CalendarPreferencesDialog on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          FlutterErrorDetails? caughtError;
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtError ??= details;
            originalOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: CalendarPreferencesDialog(repository: repo)),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull, reason: 'CalendarPreferencesDialog overflow on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Adversarial Text & Long Input Stress', () {
    testWidgets('PublicStudioScreen with extreme studio title and long package on 320px', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(320, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        const longStudioName = 'Super Ultra Luxury High Precision Concierge Detailing & Ceramic Coatings Studio International LLC of Beverly Hills';
        const longLocation = '12345 Detailing Boulevard, Suite 900-B, Industrial Park, Beverly Hills, CA 90210';
        const longBio = 'Specializing in hypercars, multi-stage rotary paint correction, ultra-hydrophobic ceramic coatings, and concourse level surface preservation for discriminating automotive collectors worldwide.';
        const longPackageTitle = 'Ultimate Master-Craft Multi-Stage Paint Correction & Dual-Layer Graphene Matrix Quartz Ceramic Coating Package';
        const longPackageDesc = 'Comprehensive 48-hour ultra-deep surface decontamination, multi-stage rotary compounding, dual-action jewel polishing, 10H ceramic coating application with infrared curing and ultrasonic paint depth inspection.';

        final adversarialPackage = ServicePackage(
          id: 'adv_pkg_1',
          title: longPackageTitle,
          description: longPackageDesc,
          basePrice: 4850.0,
          estimatedDuration: '48 Hours (3-Day Precision Process)',
          isPopular: true,
          includes: [
            '24-micron ultrasonic paint thickness gauge mapping across 36 vehicle panels',
            'Full chemical iron decontamination and clay bar exfoliation pass',
            'Multi-stage rotary compound with Meguiar’s Pro Heavy Cut and wool pads',
            'Jeweling micro-polish finishing step to achieve 99% swirl elimination',
            'Dual-layer 10H Graphene Matrix Ceramic Shield with 7-year warranty guarantee',
          ],
        );

        final adversarialProfile = repo.currentUser.copyWith(
          businessName: longStudioName,
          location: longLocation,
          bio: longBio,
          servicePackages: [adversarialPackage],
        );

        FlutterErrorDetails? caughtError;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError ??= details;
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: PublicStudioScreen(
              detailer: adversarialProfile,
              repository: repo,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(caughtError, isNull, reason: 'PublicStudioScreen with long text overflowed on 320px: ${caughtError?.summary}');

        // Scroll so TabBar is pinned and clear of bottom dock bar on 320px viewport
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
        await tester.pump();

        await tester.tap(find.text('Services & Pricing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(caughtError, isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('JobDetailScreen with extremely long vehicle name on 320px', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(320, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        const longVehicleName = 'Mercedes-Benz AMG GT 63 S E-Performance 4-Door Coupe V8 Bi-Turbo Hybrid Carbon Edition';
        final baseJob = repo.allJobs.isNotEmpty ? repo.allJobs.first : createTestJob();
        final adversarialJob = baseJob.copyWith(
          vehicleYear: 2024,
          vehicleMake: 'Mercedes-Benz',
          vehicleModel: 'AMG GT 63 S E-Performance 4-Door Coupe V8 Bi-Turbo Hybrid Carbon Edition',
          paintColorName: 'designo Selenite Grey Magno Matte',
          title: 'Concourse Paint Restoration on $longVehicleName',
          description: 'Severe factory orange peel leveling and deep swirl extraction on matte finish paintwork requiring specialized matte ceramic coatings.',
        );

        FlutterErrorDetails? caughtError;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError ??= details;
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: JobDetailScreen(
              job: adversarialJob,
              repository: repo,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(caughtError, isNull, reason: 'JobDetailScreen with long vehicle name overflowed on 320px: ${caughtError?.summary}');
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
