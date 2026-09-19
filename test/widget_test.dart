import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/widgets/dilution_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/core/constants/detailing_presets.dart';
import 'package:detail_craft/widgets/fullscreen_image_viewer.dart';
import 'package:detail_craft/screens/create_job_screen.dart';

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
    expect(DetailingPresets.correctionPercentages.length, 5);
    expect(DetailingPresets.paintGaugePresets.length, 3);
    expect(DetailingPresets.recipePresets.length, 3);
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

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: CreateJobScreen(
          repository: repository,
          onJobCreated: () {},
        ),
      ),
    ));
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

    // Verify presence of Correction Percentage options
    expect(find.text('TARGET / ACHIEVED CORRECTION (%)'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);

    // Tap on Stage 3
    await tester.tap(find.text('Stage 3: Severe RIDS'));
    await tester.pumpAndSettle();

    // Tap on 90% correction
    await tester.tap(find.text('90%'));
    await tester.pumpAndSettle();

    expect(find.text('Stage 3: Severe RIDS • 90% Correction'), findsOneWidget);
  });
}
