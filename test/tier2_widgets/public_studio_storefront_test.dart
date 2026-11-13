import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/map_launcher_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late JobRepository repo;
  late UserProfile detailer;

  setUp(() {
    repo = JobRepository();
    detailer = UserProfile(
      id: 'detailer-storefront-1',
      role: UserRole.detailer,
      username: 'apex_studio',
      displayName: 'Apex Auto Spa',
      businessName: 'Apex Luxury Detailing',
      location: 'San Diego, CA',
      serviceRadius: '25 miles • Mobile & Studio',
      bio: 'Concours-grade paint correction and ceramic protection.',
      isVerifiedHost: true,
      isIdaCertified: true,
      isInsuranceVerified: true,
      averageRating: 4.9,
      reviewCount: 42,
      totalJobsCount: 120,
      studioStreetAddress: '1234 Harbor Dr',
      studioCity: 'San Diego',
      studioState: 'CA',
      studioPostalCode: '92101',
      studioLatitude: 32.7157,
      studioLongitude: -117.1611,
      instagramHandle: 'apexluxurydetail',
      phone: '619-555-0199',
      servicePackages: const [
        ServicePackage(
          id: 'pkg-1',
          title: '2-Step Paint Correction',
          description: 'Removes 85-90% of swirls and oxidation.',
          basePrice: 650,
          estimatedDuration: '6-8 hrs',
          includes: ['Foam & Decon', '2-Stage Machine Polish', 'IPA Wipe'],
          isPopular: true,
        ),
        ServicePackage(
          id: 'pkg-2',
          title: '5-Year Ceramic Coating',
          description: 'Full exterior ceramic protection.',
          basePrice: 950,
          estimatedDuration: '1-2 days',
          includes: ['Single-Stage Polish', '9H Ceramic Layer'],
        ),
      ],
    );

    repo.jobs.addAll([
      DetailJob(
        id: 'job-sf-1',
        title: 'Porsche 911 GT3 Correction',
        description: 'Full 2-step paint correction.',
        vehicleMake: 'Porsche',
        vehicleModel: '911 GT3',
        vehicleYear: 2023,
        paintColorName: 'Guards Red',
        paintCode: '84A',
        paintHardness: PaintHardness.medium,
        defectSeverity: 3,
        initialPaintThicknessMicrons: 120,
        finalPaintThicknessMicrons: 114,
        recipeStages: const [],
        serviceType: 'Paint Correction',
        beforeImageUrl: '',
        afterImageUrl: '',
        author: detailer,
        createdAt: DateTime(2026, 1, 10),
      ),
      DetailJob(
        id: 'job-sf-2',
        title: 'BMW M3 Ceramic Coat',
        description: '5-year ceramic coating.',
        vehicleMake: 'BMW',
        vehicleModel: 'M3',
        vehicleYear: 2024,
        paintColorName: 'Isle of Man Green',
        paintCode: 'C4G',
        paintHardness: PaintHardness.hard,
        defectSeverity: 2,
        initialPaintThicknessMicrons: 130,
        finalPaintThicknessMicrons: 127,
        recipeStages: const [],
        serviceType: 'Ceramic Coating',
        beforeImageUrl: '',
        afterImageUrl: '',
        author: detailer,
        createdAt: DateTime(2026, 1, 12),
      ),
    ]);
  });

  tearDown(() {
    MapLauncherService.resetMockLauncher();
  });

  Widget buildHarness({required Size size}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: PublicStudioScreen(
          detailer: detailer,
          repository: repo,
        ),
      ),
    );
  }

  for (final viewport in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'renders all 4 tabs and sticky CTA bar without overflow at ${viewport.width}x${viewport.height}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildHarness(size: viewport));
        await tester.pumpAndSettle();

        // Authority badges & Directions
        expect(find.text('Verified Pro'), findsOneWidget);
        expect(find.text('IDA Certified'), findsOneWidget);
        expect(find.text('Insured'), findsOneWidget);
        expect(find.text('Directions'), findsOneWidget);

        // Sticky bottom bar
        expect(find.text('From \$650'), findsOneWidget);
        expect(find.text('Book Appointment'), findsOneWidget);

        // Scroll down so TabBar & TabBarView content are visible on small viewports
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();

        // Tab 1: Services (default)
        expect(find.text('Most Popular'), findsOneWidget);
        expect(find.text('2-Step Paint Correction'), findsOneWidget);
        expect(find.text('Book This Service'), findsAtLeastNWidgets(1));

        // Tab 2: Portfolio
        await tester.tap(find.text('Portfolio'));
        await tester.pumpAndSettle();
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Paint Correction'), findsAtLeastNWidgets(1));

        // Tab 3: Reviews
        await tester.tap(find.text('Reviews'));
        await tester.pumpAndSettle();
        expect(find.text('42 verified reviews'), findsOneWidget);
        expect(find.text('Verified Client Reviews'), findsOneWidget);

        // Tab 4: About & Studio
        await tester.ensureVisible(find.text('About & Studio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('About & Studio'));
        await tester.pumpAndSettle();
        expect(find.text('Get Directions'), findsOneWidget);
        expect(find.textContaining('apexluxurydetail'), findsOneWidget);
      },
    );
  }

  testWidgets('Portfolio service-type filter chips filter DetailJob cards',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();

    expect(find.text('Porsche 911 GT3 Correction'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Ceramic Coating'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ceramic Coating'));
    await tester.pumpAndSettle();

    expect(find.text('Porsche 911 GT3 Correction'), findsNothing);
    expect(find.text('BMW M3 Ceramic Coat'), findsOneWidget);
  });

  testWidgets('Directions button invokes MapLauncherService', (tester) async {
    String? launchedUrl;
    MapLauncherService.setMockLauncher((url) async {
      launchedUrl = url;
      return true;
    });

    await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Directions'));
    await tester.pumpAndSettle();

    expect(launchedUrl, isNotNull);
    expect(launchedUrl, contains('1234%20Harbor%20Dr'));
  });

  testWidgets(
      'Book Appointment and Book This Service navigate to BookingFlowScreen when logged in with vehicle',
      (tester) async {
    repo.isLoggedIn = true;
    repo.addVehicleToGarage(
      const UserVehicle(
        id: 'v1',
        year: 2023,
        make: 'Porsche',
        model: '911',
        colorName: 'Guards Red',
        imageUrl: '',
      ),
    );
    await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book Appointment'));
    await tester.pumpAndSettle();

    expect(find.byType(BookingFlowScreen), findsOneWidget);
  });

  testWidgets(
      'Book This Service navigates to BookingFlowScreen with initialPackage',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    repo.isLoggedIn = true;
    repo.addVehicleToGarage(
      const UserVehicle(
        id: 'v1',
        year: 2023,
        make: 'Porsche',
        model: '911',
        colorName: 'Guards Red',
        imageUrl: '',
      ),
    );
    await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    final bookServiceBtn = find.text('Book This Service').first;
    await tester.ensureVisible(bookServiceBtn);
    await tester.pumpAndSettle();
    await tester.tap(bookServiceBtn);
    await tester.pumpAndSettle();

    final bookingScreen =
        tester.widget<BookingFlowScreen>(find.byType(BookingFlowScreen));
    expect(bookingScreen.initialPackage?.id, 'pkg-1');
  });

  testWidgets(
      'Handles empty servicePackages, empty studioJobs, and no studio address without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    repo.jobs.clear();
    detailer = UserProfile(
      id: 'detailer-empty',
      role: UserRole.detailer,
      username: 'mobile_only',
      displayName: 'Mobile Detailer',
      businessName: 'Mobile Detailer',
      location: 'Austin, TX',
      serviceRadius: '30 miles',
      servicePackages: const [],
    );

    await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(find.text('Custom Quote'), findsOneWidget);
    expect(find.text('Directions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
