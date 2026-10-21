import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/screens/calendar_preferences_dialog.dart';
import 'package:detail_craft/services/job_repository.dart';
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

  const extremeStudioName =
      'Super Ultra Luxury High Precision Concierge Detailing & Ceramic Coatings Studio International LLC of Beverly Hills';
  const extremeLocation =
      '12345 Detailing Boulevard, Suite 900-B, Industrial Park District, Beverly Hills, CA 90210';
  const extremeBio =
      'Specializing in hypercars, multi-stage rotary paint correction, ultra-hydrophobic ceramic coatings, and concourse level surface preservation for discriminating automotive collectors worldwide.';
  const extremePackageTitle =
      'Ultimate Master-Craft Multi-Stage Paint Correction & Dual-Layer Graphene Matrix Quartz Ceramic Coating Package With Infrared Thermal Curing';
  const extremePackageDesc =
      'Comprehensive 48-hour ultra-deep surface decontamination, multi-stage rotary compounding, dual-action jewel polishing, 10H ceramic coating application with infrared curing and ultrasonic paint depth inspection.';

  final extremePackageStandardDuration = ServicePackage(
    id: 'adv_pkg_std_dur',
    title: extremePackageTitle,
    description: extremePackageDesc,
    basePrice: 14850.0,
    estimatedDuration: '48 Hours',
    isPopular: true,
    includes: [
      '24-micron ultrasonic paint thickness gauge mapping across 36 vehicle panels',
      'Full chemical iron decontamination and clay bar exfoliation pass',
      'Multi-stage rotary compound with Meguiar’s Pro Heavy Cut and wool pads',
      'Jeweling micro-polish finishing step to achieve 99% swirl elimination',
      'Dual-layer 10H Graphene Matrix Ceramic Shield with 7-year warranty guarantee',
    ],
  );

  final extremePackageDescriptiveDuration = ServicePackage(
    id: 'adv_pkg_desc_dur',
    title: extremePackageTitle,
    description: extremePackageDesc,
    basePrice: 14850.0,
    estimatedDuration: '48 Hours (3-Day Precision Process)',
    isPopular: true,
    includes: [
      '24-micron ultrasonic paint thickness gauge mapping across 36 vehicle panels',
      'Full chemical iron decontamination and clay bar exfoliation pass',
    ],
  );

  group('Milestone M4 Challenger: Long Strings on BookingFlowScreen', () {
    for (final size in extremeWidths) {
      testWidgets('BookingFlowScreen with extreme text on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          final adversarialProfile = repo.currentUser.copyWith(
            businessName: extremeStudioName,
            location: extremeLocation,
            bio: extremeBio,
            servicePackages: [extremePackageStandardDuration],
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
              home: BookingFlowScreen(
                detailer: adversarialProfile,
                initialPackage: extremePackageStandardDuration,
                repository: repo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(caughtError, isNull,
              reason: 'BookingFlowScreen Step 0 overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Advance to Step 1
          final continueBtn = find.text('Continue');
          expect(continueBtn, findsOneWidget);
          await tester.tap(continueBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull,
              reason: 'BookingFlowScreen Step 1 overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Advance to Step 2
          await tester.tap(continueBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull,
              reason: 'BookingFlowScreen Step 2 overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');

          // Back button
          final backBtn = find.text('Back');
          expect(backBtn, findsOneWidget);
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
          expect(caughtError, isNull,
              reason: 'BookingFlowScreen Back button overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Challenger: Long Strings on JobDetailScreen', () {
    for (final size in extremeWidths) {
      testWidgets('JobDetailScreen with extreme vehicle specs and comments on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          const longVehicleName =
              'Mercedes-Benz AMG GT 63 S E-Performance 4-Door Coupe V8 Bi-Turbo Hybrid Carbon Track Edition';
          final baseJob = repo.allJobs.isNotEmpty ? repo.allJobs.first : createTestJob();
          final adversarialJob = baseJob.copyWith(
            vehicleYear: 2024,
            vehicleMake: 'Mercedes-Benz',
            vehicleModel: longVehicleName,
            paintColorName: 'designo Selenite Grey Magno Matte Multi-Coat Metallic Finish With Self-Healing Clearcoat',
            title: 'Full Concourse Paint Leveling & Restoration on $longVehicleName',
            description:
                'Severe factory orange peel leveling, deep swirl extraction, and multi-stage rotary jeweling on delicate matte clearcoat followed by dual-layer ceramic quartz application.',
            comments: [
              JobComment(
                id: 'adv_c1',
                authorName: 'Master Detailer Wolfgang Von Hapsburg-Hohenzollern III',
                authorAvatar: '',
                text:
                    'Incredible gloss depth and clarity achieved on such notoriously sensitive matte pigment. What micro-abrasive compound and pad progression was utilized for the final jewel pass?',
                createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              ),
            ],
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
              home: JobDetailScreen(job: adversarialJob, repository: repo),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(caughtError, isNull,
              reason: 'JobDetailScreen overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Challenger: Long Strings on CalendarPreferencesDialog', () {
    for (final size in extremeWidths) {
      testWidgets('CalendarPreferencesDialog with long custom slots on ${size.width.toInt()}px', (tester) async {
        setupMockImageHttpClient();
        try {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final repo = JobRepository();
          await repo.init();

          final customPrefs = repo.calendarPreferences.copyWith(
            customTimeSlots: [
              '08:00 AM - 12:00 PM (Morning Concourse Paint Restoration & Ultrasonic Gauge Inspection)',
              '01:00 PM - 06:00 PM (Afternoon Dual-Action Jeweling Polish & Multi-Stage Decontamination)',
            ],
          );
          repo.updateCalendarPreferences(customPrefs);

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
          expect(caughtError, isNull,
              reason: 'CalendarPreferencesDialog overflowed with long slots on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Challenger: Long Strings on ServicePackageEditorDialog', () {
    for (final size in extremeWidths) {
      testWidgets('ServicePackageEditorDialog with extreme package on ${size.width.toInt()}px', (tester) async {
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
              home: Scaffold(
                body: ServicePackageEditorDialog(
                  package: extremePackageStandardDuration,
                  onSave: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(caughtError, isNull,
              reason: 'ServicePackageEditorDialog overflowed with long strings on ${size.width.toInt()}px: ${caughtError?.summary}');
        } finally {
          tearDownMockImageHttpClient();
        }
      });
    }
  });

  group('Milestone M4 Challenger: PublicStudioScreen Layout & Defect Oracle', () {
    testWidgets('PublicStudioScreen with standard durations passes on 390px', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        final adversarialProfile = repo.currentUser.copyWith(
          businessName: extremeStudioName,
          location: extremeLocation,
          bio: extremeBio,
          servicePackages: [extremePackageStandardDuration],
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

        // Tab 0
        expect(caughtError, isNull);

        // Tab 1: Services
        await tester.tap(find.text('Services & Pricing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(caughtError, isNull);

        // Tab 2: About
        await tester.tap(find.text('About & Studio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(caughtError, isNull);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('PublicStudioScreen Tab 1 no overflow on descriptive estimatedDuration', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = JobRepository();
        await repo.init();

        final adversarialProfile = repo.currentUser.copyWith(
          businessName: extremeStudioName,
          servicePackages: [extremePackageDescriptiveDuration],
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

        // Switch to Services & Pricing tab
        await tester.tap(find.text('Services & Pricing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(caughtError, isNull, reason: 'PublicStudioScreen Services & Pricing overflowed');
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
