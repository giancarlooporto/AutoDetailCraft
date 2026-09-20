import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/widgets/dilution_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/core/constants/detailing_presets.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/widgets/fullscreen_image_viewer.dart';
import 'package:detail_craft/screens/create_job_screen.dart';
import 'package:detail_craft/models/paint_gauge_point.dart';
import 'package:detail_craft/widgets/paint_gauge_walkaround_widget.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentPixel = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentPixel.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPixel).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  testWidgets('Desktop view loads Turo-style top header and centered feed', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify top header brand and tabs
    expect(find.text('AutoDetailCraft'), findsWidgets);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Bookings'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);

    // Verify bottom navigation bar is null on desktop
    final scaffold = tester.firstWidget(find.byType(Scaffold)) as Scaffold;
    expect(scaffold.bottomNavigationBar, isNull);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Mobile view loads standard bottom navigation bar', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify mobile bottom navigation bar exists
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Bookings'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('PublicStudioScreen renders header, slivers, tabs, and content correctly', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    final detailer = repository.publicDetailers.first;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: PublicStudioScreen(
        detailer: detailer,
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PublicStudioScreen), findsOneWidget);
    expect(find.text('Transformations'), findsWidgets);
    expect(find.text('Services & Pricing'), findsOneWidget);
    expect(find.text('About & Studio'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Book Studio Service'), findsOneWidget);

    // Tap on Services & Pricing tab
    await tester.tap(find.text('Services & Pricing'));
    await tester.pumpAndSettle();

    // Tap on About & Studio tab
    await tester.tap(find.text('About & Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Studio Location & Service Coverage'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('iPhone 13 mini small screen: side-by-side dropdowns and collapsible featured detailers', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    // iPhone 13 mini screen dimensions: 375 x 812
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: FeedScreen(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify side-by-side dropdown buttons exist
    expect(find.byKey(const Key('location_dropdown_btn')), findsOneWidget);
    expect(find.byKey(const Key('service_dropdown_btn')), findsOneWidget);
    expect(find.text('All Locations'), findsOneWidget);
    expect(find.text('All Services'), findsOneWidget);

    // Verify featured detailers strip exists and starts collapsed on mobile
    expect(find.byKey(const Key('toggle_featured_detailers_btn')), findsOneWidget);
    // Detailer cards are not shown when collapsed
    expect(find.byKey(const Key('detailer_card_usr_marcus')), findsNothing);

    // Tap to expand featured detailers
    await tester.tap(find.byKey(const Key('toggle_featured_detailers_btn')));
    await tester.pumpAndSettle();

    // Detailer cards are now visible
    expect(find.byKey(const Key('detailer_card_usr_marcus')), findsOneWidget);

    // Tap again to collapse and save screen space
    await tester.tap(find.byKey(const Key('toggle_featured_detailers_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailer_card_usr_marcus')), findsNothing);

    // Tap location dropdown button to open menu
    await tester.tap(find.byKey(const Key('location_dropdown_btn')));
    await tester.pumpAndSettle();

    // Select Austin, Texas
    final austinItem = find.text('Austin, Texas');
    expect(austinItem, findsWidgets);
    await tester.tap(austinItem.last);
    await tester.pumpAndSettle();

    // Verify location is updated
    expect(repository.selectedLocationCity, 'Austin, Texas');

    // Verify quick reset filter button is now visible
    expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);

    // Tap quick reset filter button
    await tester.tap(find.byIcon(Icons.filter_alt_off_rounded));
    await tester.pumpAndSettle();

    // Verify filter is reset
    expect(repository.selectedLocationCity, 'All Locations');
    expect(repository.selectedServiceType, 'All Services');

    // Tap service dropdown button to open menu
    await tester.tap(find.byKey(const Key('service_dropdown_btn')));
    await tester.pumpAndSettle();

    // Select Ceramic Coating
    final ceramicItem = find.text('Ceramic Coating');
    expect(ceramicItem, findsWidgets);
    await tester.tap(ceramicItem.last);
    await tester.pumpAndSettle();

    // Verify service filter is updated
    expect(repository.selectedServiceType, 'Ceramic Coating');

    // Verify reset button appears again
    expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.filter_alt_off_rounded));
    await tester.pumpAndSettle();
    expect(repository.selectedServiceType, 'All Services');

    // Verify that scrolling the feed scrolls featured detailers off screen on small mobile screens
    expect(find.byKey(const Key('toggle_featured_detailers_btn')), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();

    // After scrolling down, the strip is scrolled out of the viewport, giving full screen to cards
    expect(find.byKey(const Key('toggle_featured_detailers_btn')), findsNothing);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Dilution Calculator dialog opens from AppBar calculator button on mobile', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedScreen(repository: repository),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap the calculate icon button
    final calcBtn = find.byIcon(Icons.calculate_outlined);
    expect(calcBtn, findsOneWidget);
    await tester.tap(calcBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify DilutionDialog is opened
    expect(find.byType(DilutionDialog), findsOneWidget);
    expect(find.text('Dilution Calculator'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobDetailScreen supports Twitter-style threaded replies and reply banner', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final sampleJob = repository.jobs.first.copyWith(
      comments: [
        JobComment(
          id: 'cmt_root_1',
          authorName: 'Alex Detailer',
          authorAvatar: '',
          text: 'What pad did you use on the hood?',
          createdAt: DateTime.now(),
          isVerifiedPro: true,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: JobDetailScreen(job: sampleJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Discussion section exists
    expect(find.textContaining('Discussion'), findsOneWidget);

    // Scroll until reply button is visible
    await tester.ensureVisible(find.text('Reply').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap first reply button to trigger Twitter-style reply mode
    await tester.tap(find.text('Reply').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify "Replying to @" banner appears
    expect(find.textContaining('Replying to @Alex Detailer'), findsOneWidget);

    // Type a reply into the comment box
    final textField = find.byType(TextField).last;
    await tester.ensureVisible(textField);
    await tester.pump();
    await tester.enterText(textField, 'Great info on this polish!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Send the reply
    final sendBtn = find.byIcon(Icons.send_rounded);
    await tester.ensureVisible(sendBtn);
    await tester.pump();
    await tester.tap(sendBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify comment is now visible in the discussion thread
    expect(find.text('Great info on this polish!'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobRepository updateBookingStatus updates booking state properly', (WidgetTester tester) async {
    final repository = JobRepository();
    final booking = BookingAppointment(
      id: 'bk_test_1',
      detailerId: 'usr_marcus',
      detailerName: 'Marcus Vance',
      detailerBusinessName: 'Apex Precision Detailing',
      detailerAvatar: '',
      clientName: 'Test Client',
      clientPhone: '(512) 555-0199',
      clientEmail: 'test@example.com',
      vehicleYearMakeModel: '2023 BMW M3',
      vehicleSize: VehicleSize.coupeSedan,
      package: repository.currentUser.servicePackages.first,
      locationType: ServiceLocationType.mobile,
      clientAddress: 'Austin, TX',
      scheduledDate: DateTime.now().add(const Duration(days: 2)),
      scheduledTimeSlot: '9:00 AM - 12:00 PM',
      totalPrice: 450,
      depositAmount: 100,
      status: BookingStatus.pending,
    );

    repository.addBooking(booking);
    expect(repository.bookings.first.status, BookingStatus.pending);

    repository.updateBookingStatus(booking.id, BookingStatus.completed);
    final updated = repository.bookings.firstWhere((b) => b.id == booking.id);
    expect(updated.status, BookingStatus.completed);
  });

  testWidgets('Desktop view renders single unified unlayered search bar with embedded dropdowns', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedScreen(repository: repository),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify search TextField exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search transformations, studios, cities...'), findsOneWidget);

    // Verify location & service dropdown buttons are embedded in the bar
    expect(find.byKey(const Key('location_dropdown_btn')), findsOneWidget);
    expect(find.byKey(const Key('service_dropdown_btn')), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Ceramic');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify reset button appears
    expect(find.byKey(const Key('reset_filters_btn')), findsOneWidget);

    // Tap reset button
    await tester.tap(find.byKey(const Key('reset_filters_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.searchQuery, isEmpty);
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('FullscreenImageViewer renders interactive viewer and controls', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FullscreenImageViewer(
          images: const [
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          ],
          initialIndex: 0,
          title: 'Defect Inspection',
        ),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FullscreenImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('Defect Inspection'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Verify detailing presets have required options
    expect(DetailingPresets.defectSeverities.length, 4);
    expect(DetailingPresets.correctionPercentages.length, 3);
    expect(DetailingPresets.paintGaugePresets.length, 3);
    expect(DetailingPresets.recipePresets.length, 5);
    expect(DetailingPresets.toolOptions.isNotEmpty, true);
    expect(DetailingPresets.padOptions.isNotEmpty, true);
    expect(DetailingPresets.compoundOptions.isNotEmpty, true);
    expect(DetailingPresets.protectionOptions.isNotEmpty, true);
  });

  test('DetailJob DefectStage & Correction Percentage industry standard mappings', () {
    expect(DefectStage.fromStageNumber(1), DefectStage.stage1);
    expect(DefectStage.fromStageNumber(2), DefectStage.stage2);
    expect(DefectStage.fromStageNumber(3), DefectStage.stage3);
    expect(DefectStage.fromStageNumber(4), DefectStage.stage4);
    // Backward compatibility for legacy 1-10 scores
    expect(DefectStage.fromStageNumber(7), DefectStage.stage3);
    expect(DefectStage.fromStageNumber(9), DefectStage.stage4);

    expect(DefectStage.fromString('stage1'), DefectStage.stage1);
    expect(DefectStage.fromString('stage3'), DefectStage.stage3);
    expect(DefectStage.fromString('2'), DefectStage.stage2);

    final job = DetailJob(
      id: 'test_job',
      author: JobRepository().currentUser,
      createdAt: DateTime.now(),
      title: 'Test Job',
      description: 'Testing stages',
      vehicleYear: 2024,
      vehicleMake: 'BMW',
      vehicleModel: 'M3',
      paintColorName: 'Isle of Man Green',
      paintCode: 'C4G',
      paintHardness: PaintHardness.hard,
      initialPaintThicknessMicrons: 130.0,
      finalPaintThicknessMicrons: 126.0,
      defectSeverity: 2,
      defectStage: DefectStage.stage2,
      correctionPercentage: 85,
      serviceType: 'Paint Correction',
      recipeStages: const [],
      beforeImageUrl: 'https://example.com/b.jpg',
      afterImageUrl: 'https://example.com/a.jpg',
    );

    expect(job.defectStage, DefectStage.stage2);
    expect(job.defectStageLabel, 'Stage 2: Moderate');
    expect(job.correctionPercentage, 85);
    expect(job.correctionPercentageLabel, '85% Correction');

    // Test JSON round trip
    final json = job.toJson();
    expect(json['defectStage'], 'stage2');
    expect(json['correctionPercentage'], 85);

    final fromJson = DetailJob.fromJson(json);
    expect(fromJson.defectStage, DefectStage.stage2);
    expect(fromJson.correctionPercentage, 85);
  });

  testWidgets('JobDetailScreen renders industry standard Defect Stage and Correction Achieved', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final sampleJob = repository.jobs.first;

    await tester.pumpWidget(MaterialApp(
      home: JobDetailScreen(job: sampleJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Defect Stage and Correction Achieved are rendered
    expect(find.text('Defect Stage:'), findsOneWidget);
    expect(find.text(sampleJob.defectStage.label), findsWidgets);
    expect(find.text('Correction Achieved:'), findsOneWidget);
    expect(find.text('${sampleJob.correctionPercentage}% Correction'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('CreateJobScreen allows selecting DefectStage and CorrectionPercentage', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CreateJobScreen(
            repository: repository,
            onJobCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to make defect stage section visible
    await tester.scrollUntilVisible(
      find.text('INITIAL DEFECT STAGE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify presence of Defect Stage options
    expect(find.text('INITIAL DEFECT STAGE'), findsOneWidget);
    expect(find.text('Stage 1: Light'), findsOneWidget);
    expect(find.text('Stage 2: Moderate'), findsOneWidget);
    expect(find.text('Stage 3: Severe RIDS'), findsOneWidget);
    expect(find.text('Stage 4: Paint Failure'), findsOneWidget);

    // Verify presence of Simplified 3 Correction Percentage options
    expect(find.text('TARGET / ACHIEVED CORRECTION (%)'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);

    // Tap on Stage 3
    await tester.tap(find.text('Stage 3: Severe RIDS'));
    await tester.pumpAndSettle();

    // Tap on 95% correction
    await tester.tap(find.text('95%'));
    await tester.pumpAndSettle();

    expect(find.text('Stage 3: Severe RIDS • 95% Correction'), findsOneWidget);

    // Scroll down to recipe builder
    await tester.scrollUntilVisible(
      find.text('Studio Detailing Recipe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio Detailing Recipe'), findsOneWidget);
    expect(find.text('Add Step'), findsOneWidget);

    // Tap Add Step
    await tester.tap(find.text('Add Step'));
    await tester.pumpAndSettle();

    // Verify active step indicator and newly added step exists
    expect(find.textContaining('ACTIVE STEP'), findsWidgets);

    // Scroll to Menzerna Heavy Cut 400 chip if needed and tap
    await tester.scrollUntilVisible(
      find.text('Menzerna Heavy Cut 400'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap a compound chip (Menzerna Heavy Cut 400)
    await tester.tap(find.text('Menzerna Heavy Cut 400'));
    await tester.pumpAndSettle();

    expect(find.text('Chemical: Menzerna Heavy Cut 400'), findsOneWidget);

    // Tap a tool chip and pad chip into active step
    await tester.tap(find.text('Rupes LHR15 Mark III (15mm)'));
    await tester.pumpAndSettle();
    expect(find.text('Tool: Rupes LHR15 Mark III (15mm)'), findsWidgets);

    await tester.tap(find.text('Lake Country Microfiber Cutting Pad'));
    await tester.pumpAndSettle();
    expect(find.text('Pad: Lake Country Microfiber Cutting Pad'), findsWidgets);

    // Tap a protection chip (creates dedicated ceramic protection step)
    final initialStepCount = find.byIcon(Icons.delete_outline_rounded).evaluate().length;
    await tester.tap(find.text('Gtechniq Crystal Serum Ultra (9H)'));
    await tester.pumpAndSettle();

    final newStepCount = find.byIcon(Icons.delete_outline_rounded).evaluate().length;
    expect(newStepCount, initialStepCount + 1);
    expect(find.text('Chemical: Gtechniq Crystal Serum Ultra (9H)'), findsOneWidget);

    // Delete a step (scroll to ensure visible in modal dialog)
    final lastDeleteFinder = find.byIcon(Icons.delete_outline_rounded).last;
    await tester.scrollUntilVisible(
      lastDeleteFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(lastDeleteFinder);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline_rounded).evaluate().length, initialStepCount);

    // Scroll up to presets and test 1-Tap preset switching
    await tester.scrollUntilVisible(
      find.text('1-Stage Gloss Enhancement'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-Stage Gloss Enhancement'));
    await tester.pumpAndSettle();
    expect(find.text('1. Chemical & Clay Decontamination'), findsOneWidget);
  });

  testWidgets('PaintGaugeWalkaroundWidget calculates Overall Vehicle Average and supports unit toggle & presets', (WidgetTester tester) async {
    List<PaintGaugePoint> points = PaintGaugePoint.default8Points(initial: 120.0, post: 115.0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return PaintGaugeWalkaroundWidget(
                  points: points,
                  onPointsChanged: (newPts) {
                    setState(() => points = newPts);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 8-point walkaround inspection renders
    expect(find.text('8-Point Paint Gauge Walkaround Body Check'), findsOneWidget);
    expect(find.text('Overall Vehicle Average'), findsOneWidget);

    // Initial avg should be 120 µm, post 115 µm, removed -5 µm
    expect(find.text('120 µm'), findsWidgets);
    expect(find.text('115 µm'), findsWidgets);
    expect(find.text('-5 µm'), findsOneWidget);

    // Verify 8 vehicle zones render
    expect(find.text('Hood'), findsWidgets);
    expect(find.text('Roof'), findsWidgets);
    expect(find.text('Trunk'), findsWidgets);

    // Tap on mil toggle
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    // Verify mil unit display (120 µm / 25.4 = ~4.7 mil)
    expect(find.text('4.7 mil'), findsWidgets);

    // Switch back to µm
    await tester.tap(find.text('µm'));
    await tester.pumpAndSettle();

    // Tap on a panel (Hood) to open dialog editor
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    expect(find.text('Hood Reading'), findsOneWidget);
    expect(find.text('Quick Presets (1-Tap):'), findsOneWidget);
    expect(find.text('Factory Healthy ~120µm'), findsOneWidget);
    expect(find.text('Thin ~80µm'), findsOneWidget);
    expect(find.text('Re-spray ~200µm'), findsOneWidget);

    // Tap Thin preset (sets initial to 82, post to 80)
    await tester.tap(find.text('Thin ~80µm'));
    await tester.pumpAndSettle();

    // Apply dialog
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Point was updated to 82 µm initial, 80 µm post. Overall initial average recalculated:
    // (7 * 120 + 82) / 8 = 115.25 -> 115 µm
    expect(find.text('115 µm'), findsWidgets);
  });

  testWidgets('CreateJobScreen adapts workflow dynamically based on selected Service Type', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();

    // 1. Verify Ceramic Coating / Exterior mode displays paint gauge & defect severity
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CreateJobScreen(
            repository: repository,
            onJobCreated: () {},
            initialServiceType: 'Ceramic Coating',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to defect stage & paint gauge
    await tester.scrollUntilVisible(
      find.text('INITIAL DEFECT STAGE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('INITIAL DEFECT STAGE'), findsOneWidget);
    expect(find.text('Paint Defect & Correction Assessment'), findsOneWidget);
    expect(find.text('8-Point Paint Gauge Walkaround Body Check'), findsOneWidget);

    // 2. Switch to Interior Deep Clean mode
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CreateJobScreen(
            repository: repository,
            onJobCreated: () {},
            initialServiceType: 'Interior Deep Clean',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Exterior paint gauge and defect severity should be hidden in Interior mode
    expect(find.text('Paint Defect & Correction Assessment'), findsNothing);
    expect(find.text('8-Point Paint Gauge Walkaround Body Check'), findsNothing);
    expect(find.text('INITIAL DEFECT STAGE'), findsNothing);

    // Scroll down to Studio Detailing Recipe
    await tester.scrollUntilVisible(
      find.text('Add Step'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap Add Step
    await tester.tap(find.text('Add Step'));
    await tester.pumpAndSettle();

    // Scroll to interior chips
    await tester.scrollUntilVisible(
      find.text('Commercial Hot Water Extractor'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify interior-specific chips appear
    expect(find.text('Commercial Hot Water Extractor'), findsWidgets);
    expect(find.text('Scrub Ninja Interior Pad'), findsWidgets);
    expect(find.text('P&S Carpet Bomber & Terminator'), findsWidgets);
  });
}
