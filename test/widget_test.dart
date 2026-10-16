import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/widgets/dilution_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/core/constants/detailing_presets.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/widgets/fullscreen_image_viewer.dart';
import 'package:detail_craft/screens/create_job_screen.dart';
import 'package:detail_craft/models/paint_gauge_point.dart';
import 'package:detail_craft/widgets/paint_gauge_walkaround_widget.dart';
import 'package:detail_craft/widgets/job_recipe_card.dart';
import 'package:detail_craft/screens/profile_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/screens/calendar_preferences_dialog.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/team_member.dart';

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

  testWidgets('Dilution Calculator dialog opens from Studio Workbench Quick Utilities', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap the calculate icon button / listtile in Pane 1 Quick Utilities
    final calcBtn = find.text('Dilution Calculator');
    expect(calcBtn, findsOneWidget);
    await tester.tap(calcBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify DilutionDialog is opened
    expect(find.byType(DilutionDialog), findsOneWidget);
    expect(find.text('Precision chemical mixing cheat sheet'), findsOneWidget);

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

    // Verify Discussion tab exists and tap it to reveal comments
    expect(find.textContaining('Discussion'), findsWidgets);
    await tester.tap(find.byKey(const Key('discussion_tab_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

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

  testWidgets('JobDetailScreen Segmented Tabs switch between Specs & Recipe and Discussion', (WidgetTester tester) async {
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
          id: 'cmt_tab_1',
          authorName: 'Chris Porter',
          authorAvatar: '',
          text: 'What was the pad compression on this curve?',
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

    // Both tab buttons should exist
    expect(find.byKey(const Key('specs_tab_button')), findsOneWidget);
    expect(find.byKey(const Key('discussion_tab_button')), findsOneWidget);

    // Default tab 0: Specs & Recipe should be displayed
    expect(find.text('Paint Inspection & Gauge Data'), findsOneWidget);
    expect(find.text('Step-by-Step Process Recipe'), findsOneWidget);
    expect(find.text('What was the pad compression on this curve?'), findsNothing);

    // Tap Discussion tab
    await tester.tap(find.byKey(const Key('discussion_tab_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now Discussion should be displayed, and Specs hidden
    expect(find.text('Paint Inspection & Gauge Data'), findsNothing);
    expect(find.text('Step-by-Step Process Recipe'), findsNothing);
    expect(find.text('What was the pad compression on this curve?'), findsOneWidget);

    // Tap Specs tab to switch back
    await tester.tap(find.byKey(const Key('specs_tab_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Specs & Recipe should be visible again
    expect(find.text('Paint Inspection & Gauge Data'), findsOneWidget);
    expect(find.text('Step-by-Step Process Recipe'), findsOneWidget);
    expect(find.text('What was the pad compression on this curve?'), findsNothing);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobDetailScreen renders Owner Edit action for author and opens CreateJobScreen', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    repository.isLoggedIn = true;
    final ownedJob = repository.jobs.first.copyWith(
      author: repository.currentUser,
    );

    await tester.pumpWidget(MaterialApp(
      home: JobDetailScreen(job: ownedJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Owner should see only the 3-dots overflow menu (no standalone edit or share button)
    expect(find.byKey(const Key('edit_recipe_appbar_button')), findsNothing);
    expect(find.byKey(const Key('recipe_overflow_menu')), findsOneWidget);
    expect(find.byKey(const Key('share_recipe_appbar_button')), findsNothing);

    // Opening overflow menu shows Edit Recipe and Delete Recipe, but no Share Client Report
    await tester.tap(find.byKey(const Key('recipe_overflow_menu')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Delete Recipe'), findsOneWidget);
    expect(find.text('Share Client Report'), findsNothing);

    // Tapping Edit Recipe in overflow menu opens CreateJobScreen
    await tester.tap(find.text('Edit Recipe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CreateJobScreen), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobDetailScreen hides edit actions for visitors and preserves bottom Share Report', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final visitorJob = repository.jobs.first.copyWith(
      author: repository.currentUser.copyWith(
        id: 'usr_different_detailer',
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: JobDetailScreen(job: visitorJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Visitor should NOT see edit button, overflow menu, or redundant share button in AppBar
    expect(find.byKey(const Key('share_recipe_appbar_button')), findsNothing);
    expect(find.byKey(const Key('edit_recipe_appbar_button')), findsNothing);
    expect(find.byKey(const Key('recipe_overflow_menu')), findsNothing);

    // Bottom action bar still contains Share Report
    expect(find.text('Share Report'), findsOneWidget);

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

  test('BookingAppointment serializes and deserializes clientId correctly', () {
    final bookingWithClient = BookingAppointment(
      id: 'bk_client_1',
      clientId: 'usr_client_123',
      detailerId: 'usr_marcus',
      detailerName: 'Marcus Vance',
      detailerBusinessName: 'Apex Precision Detailing',
      detailerAvatar: '',
      clientName: 'Jane Doe',
      clientPhone: '555-1234',
      clientEmail: 'jane@example.com',
      vehicleYearMakeModel: '2024 Porsche 911 GT3',
      vehicleSize: VehicleSize.coupeSedan,
      package: const ServicePackage(
        id: 'pkg_1',
        title: 'Paint Correction',
        description: 'Multi-stage correction',
        basePrice: 800,
        estimatedDuration: '8 hrs',
        includes: ['Wash', 'Decon', 'Compound', 'Polish'],
      ),
      locationType: ServiceLocationType.shop,
      clientAddress: '123 Speed Way',
      scheduledDate: DateTime(2026, 10, 1),
      scheduledTimeSlot: '10:00 AM',
      totalPrice: 800,
      depositAmount: 200,
      status: BookingStatus.confirmed,
    );

    final json = bookingWithClient.toJson();
    expect(json['clientId'], 'usr_client_123');

    final deserialized = BookingAppointment.fromJson(json);
    expect(deserialized.clientId, 'usr_client_123');
    expect(deserialized.id, 'bk_client_1');
    expect(deserialized.totalPrice, 800);
  });

  test('BookingAppointment supports null clientId for guest bookings', () {
    final guestBooking = BookingAppointment(
      id: 'bk_guest_1',
      detailerId: 'usr_marcus',
      detailerName: 'Marcus Vance',
      detailerBusinessName: 'Apex Precision Detailing',
      detailerAvatar: '',
      clientName: 'Guest User',
      clientPhone: '555-0000',
      clientEmail: 'guest@example.com',
      vehicleYearMakeModel: '2022 Ford F-150',
      vehicleSize: VehicleSize.truckVan,
      package: const ServicePackage(
        id: 'pkg_2',
        title: 'Basic Wash',
        description: 'Hand wash and dry',
        basePrice: 100,
        estimatedDuration: '2 hrs',
        includes: ['Hand wash'],
      ),
      locationType: ServiceLocationType.mobile,
      clientAddress: '456 Farm Rd',
      scheduledDate: DateTime(2026, 10, 2),
      scheduledTimeSlot: '1:00 PM',
      totalPrice: 100,
      depositAmount: 0,
      status: BookingStatus.pending,
    );

    final json = guestBooking.toJson();
    expect(json['clientId'], isNull);

    final deserialized = BookingAppointment.fromJson(json);
    expect(deserialized.clientId, isNull);
    expect(deserialized.id, 'bk_guest_1');
  });

  testWidgets('JobRepository interaction state toggle and persistence', (WidgetTester tester) async {
    final repository = JobRepository();
    final firstJobId = repository.jobs.first.id;

    // Initial state check
    final wasLiked = repository.jobs.firstWhere((j) => j.id == firstJobId).isLiked;
    final wasSaved = repository.jobs.firstWhere((j) => j.id == firstJobId).isSaved;

    // Toggle like
    repository.toggleLike(firstJobId);
    expect(repository.jobs.firstWhere((j) => j.id == firstJobId).isLiked, !wasLiked);

    // Toggle save
    repository.toggleSave(firstJobId);
    expect(repository.jobs.firstWhere((j) => j.id == firstJobId).isSaved, !wasSaved);

    // Toggle back
    repository.toggleLike(firstJobId);
    repository.toggleSave(firstJobId);
    expect(repository.jobs.firstWhere((j) => j.id == firstJobId).isLiked, wasLiked);
    expect(repository.jobs.firstWhere((j) => j.id == firstJobId).isSaved, wasSaved);
  });

  test('UserProfile serializes and deserializes startingPrice, subscriptionTier, and servicePackages', () {
    const customPackage = ServicePackage(
      id: 'pkg_custom_99',
      title: 'Ultimate Ceramic & Correction',
      description: '2-step correction with 5-year ceramic coating',
      basePrice: 1250,
      estimatedDuration: '12 hrs',
      includes: ['Paint Decon', 'Stage 2 Polish', '9H Ceramic'],
    );

    final profile = UserProfile(
      id: 'usr_detailer_42',
      role: UserRole.detailer,
      username: 'apexpro',
      displayName: 'Alex Apex',
      businessName: 'Apex Ceramic Lab',
      avatarUrl: 'https://example.com/avatar.jpg',
      location: 'Dallas, Texas',
      bio: 'High-end paint correction and ceramic specialist.',
      startingPrice: 350.0,
      servicePackages: [customPackage],
    );

    final json = profile.toJson();
    expect(json['startingPrice'], 350.0);
    expect(json['servicePackages'], isList);
    expect((json['servicePackages'] as List).length, 1);

    final deserialized = UserProfile.fromJson(json);
    expect(deserialized.startingPrice, 350.0);
    expect(deserialized.servicePackages.length, 1);
    expect(deserialized.servicePackages.first.id, 'pkg_custom_99');
    expect(deserialized.servicePackages.first.basePrice, 1250);
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

  testWidgets('PaintGaugeWalkaroundWidget dialog adapts dynamically to mil unit mode, presets, and conversions', (WidgetTester tester) async {
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

    // Tap on mils toggle
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    // Tap Hood panel to open dialog in mil mode
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    // Dialog title & presets in mils
    expect(find.text('Hood Reading'), findsOneWidget);
    expect(find.text('Quick Presets (1-Tap):'), findsOneWidget);
    expect(find.text('Thin ~3.1 mil'), findsOneWidget);
    expect(find.text('Factory Healthy ~4.8 mil'), findsOneWidget);
    expect(find.text('Re-spray ~9.0 mil'), findsOneWidget);

    // Entry header and field labels in mils
    expect(find.text('Direct Numerical Entry (mil):'), findsOneWidget);
    expect(find.text('Initial (mil)'), findsOneWidget);
    expect(find.text('Post-Polish (mil)'), findsOneWidget);

    // Tap Thin preset in mils (sets initial: 3.2, post: 3.1)
    await tester.tap(find.text('Thin ~3.1 mil'));
    await tester.pumpAndSettle();

    // Estimated Clear Removed in mils (3.2 - 3.1 = 0.1 mil)
    expect(find.text('-0.1 mil'), findsOneWidget);

    // Apply dialog
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Hood should now display in mils: 3.2 mil initial, 3.1 mil post
    expect(find.text('3.2 mil'), findsWidgets);
    expect(find.text('3.1 mil'), findsWidgets);

    // Switch back to µm mode and verify conversion stored properly (3.2 mil * 25.4 = 81.28 -> 81 µm)
    await tester.tap(find.text('µm'));
    await tester.pumpAndSettle();

    expect(find.text('81 µm'), findsWidgets);
    expect(find.text('79 µm'), findsWidgets);
  });

  testWidgets('JobDetailScreen customer-focused recipe view displays completed checkmarks and collapses tool specs', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final job = repository.jobs.first;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: job, repository: repository),
    ));
    await tester.pumpAndSettle();

    // Verify recipe section header
    expect(find.text('Step-by-Step Process Recipe'), findsOneWidget);

    // Verify customer-facing stage indicators
    expect(find.text('STAGE 1'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(find.text(job.recipeStages.first.stageName), findsOneWidget);

    // Verify internal tool specs are collapsed by default
    expect(find.text('Technique / Passes: '), findsNothing);
    expect(find.text('Machine: '), findsNothing);
    expect(find.text('Pad: '), findsNothing);

    // Verify "Detailer Craft Specs" toggle exists
    expect(find.byKey(const Key('craft_specs_toggle_0')), findsOneWidget);
    expect(find.byKey(const Key('craft_specs_toggle_1')), findsOneWidget);
    expect(find.text('Detailer Craft Specs'), findsWidgets);

    // Tap toggle for stage 0 (chemical decon) to expand technique
    await tester.tap(find.byKey(const Key('craft_specs_toggle_0')));
    await tester.pumpAndSettle();

    expect(find.text('Technique / Passes: '), findsOneWidget);

    // Tap toggle 0 again to collapse
    await tester.tap(find.byKey(const Key('craft_specs_toggle_0')));
    await tester.pumpAndSettle();

    expect(find.text('Technique / Passes: '), findsNothing);

    // Tap toggle for stage 1 (compounding) to expand machine and pad
    await tester.tap(find.byKey(const Key('craft_specs_toggle_1')));
    await tester.pumpAndSettle();

    expect(find.text('Machine: '), findsWidgets);
    expect(find.text('Pad: '), findsWidgets);

    // Tap toggle 1 again to collapse
    await tester.tap(find.byKey(const Key('craft_specs_toggle_1')));
    await tester.pumpAndSettle();

    expect(find.text('Machine: '), findsNothing);
    expect(find.text('Pad: '), findsNothing);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('PaintGaugeWalkaroundWidget supports multi-decimal mil precision, comma decimals, and non-destructive µm/mil roundtrips', (WidgetTester tester) async {
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

    // In µm mode, metric tile says 'Microns Removed'
    expect(find.text('Microns Removed'), findsOneWidget);

    // Toggle to mils mode
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    // In mils mode, metric tile adapts to 'Clear Removed' (not 'Microns Removed')
    expect(find.text('Clear Removed'), findsOneWidget);
    expect(find.text('Microns Removed'), findsNothing);

    // Open Hood dialog
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    // Enter multi-decimal precision (3.1415 mil and 3.0 mil)
    final initialField = find.widgetWithText(TextField, 'Initial (mil)');
    final postField = find.widgetWithText(TextField, 'Post-Polish (mil)');

    await tester.enterText(initialField, '3.1415');
    await tester.enterText(postField, '3.0');
    await tester.pumpAndSettle();

    // Verify estimated clear removed displays active unit
    expect(find.text('-0.1 mil'), findsOneWidget);

    // Apply changes
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Verify point stored without losing precision: 3.1415 * 25.4 = 79.7941 µm
    final hoodPoint = points.firstWhere((p) => p.id == 'hood');
    expect((hoodPoint.initialMicrons - 79.7941).abs() < 0.001, isTrue);

    // Reopen dialog in mils mode: must preserve 3.1415 in text controller without premature rounding
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    expect(find.text('3.1415'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Open Roof dialog and test comma decimal input (e.g. 4,2 mil and 4,0 mil)
    await tester.tap(find.text('Roof').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Initial (mil)'), '4,2');
    await tester.enterText(find.widgetWithText(TextField, 'Post-Polish (mil)'), '4,0');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final roofPoint = points.firstWhere((p) => p.id == 'roof');
    expect((roofPoint.initialMicrons - 106.68).abs() < 0.001, isTrue);

    // Switch to µm mode
    await tester.tap(find.text('µm'));
    await tester.pumpAndSettle();

    expect(find.text('Microns Removed'), findsOneWidget);

    // Open Hood dialog in µm mode: non-integer microns should not be lost when applying without editing
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    expect(find.text('79.79'), findsOneWidget);
    // Tap Apply without editing initial text
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final hoodAfterUmApply = points.firstWhere((p) => p.id == 'hood');
    expect((hoodAfterUmApply.initialMicrons - 79.7941).abs() < 0.001, isTrue);
  });

  testWidgets('JobDetailScreen Delete Recipe flow prompts confirmation and deletes job', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
    });

    final repository = JobRepository();
    repository.isLoggedIn = true;
    final initialCount = repository.jobs.length;
    final jobToDelete = repository.jobs.first.copyWith(
      author: repository.currentUser,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: jobToDelete, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open overflow menu
    await tester.tap(find.byKey(const Key('recipe_overflow_menu')));
    await tester.pumpAndSettle();

    // Tap Delete Recipe
    await tester.tap(find.text('Delete Recipe'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Are you sure you want to delete this detailing recipe? This action cannot be undone.'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.jobs.length, equals(initialCount));

    // Open overflow menu again and confirm delete
    await tester.tap(find.byKey(const Key('recipe_overflow_menu')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Recipe'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.jobs.length, equals(initialCount - 1));
    expect(repository.jobs.any((j) => j.id == jobToDelete.id), isFalse);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('PaintGaugeWalkaroundWidget avoids negative zero display when 0 clear is removed in µm and mils modes', (WidgetTester tester) async {
    List<PaintGaugePoint> points = PaintGaugePoint.default8Points(initial: 120.0, post: 120.0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return PaintGaugeWalkaroundWidget(
                  points: points,
                  onPointsChanged: (newPts) => setState(() => points = newPts),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In µm mode with 0 difference: should display '0 µm', not '-0 µm'
    expect(find.text('-0 µm'), findsNothing);
    expect(find.text('0 µm'), findsWidgets);

    // Toggle to mils mode
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    // In mils mode with 0 difference: should display '0.0 mil', not '-0.0 mil'
    expect(find.text('-0.0 mil'), findsNothing);
    expect(find.text('0.0 mil'), findsWidgets);
  });

  testWidgets('PaintGaugeWalkaroundWidget clamps negative numerical entries to 0.0 and closes dialog safely', (WidgetTester tester) async {
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
                  onPointsChanged: (newPts) => setState(() => points = newPts),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Hood dialog
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    // Enter negative values
    await tester.enterText(find.widgetWithText(TextField, 'Initial (µm)'), '-25');
    await tester.enterText(find.widgetWithText(TextField, 'Post-Polish (µm)'), '-10');
    await tester.pumpAndSettle();

    // Estimated Clear Removed should clamp to 0.0 µm
    expect(find.text('0.0 µm'), findsOneWidget);

    // Tap Apply
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Verify values were clamped to 0.0 and not negative
    final hoodPoint = points.firstWhere((p) => p.id == 'hood');
    expect(hoodPoint.initialMicrons, equals(0.0));
    expect(hoodPoint.postPolishMicrons, equals(0.0));
  });

  testWidgets('JobDetailScreen avoids negative zero in depth grid and resets expanded specs on job change', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final jobZeroRemoved = repository.jobs.first.copyWith(
      id: 'job_zero_removed',
      initialPaintThicknessMicrons: 120.0,
      finalPaintThicknessMicrons: 120.0,
      paintGaugePoints: PaintGaugePoint.default8Points(initial: 120.0, post: 120.0),
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: jobZeroRemoved, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Depth comparison grid should show 0.0 µm, not -0.0 µm
    expect(find.text('-0.0 µm'), findsNothing);
    expect(find.text('0.0 µm'), findsOneWidget);

    // Expand stage 0 craft specs
    expect(find.byKey(const Key('craft_specs_toggle_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('craft_specs_toggle_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Technique / Passes: '), findsOneWidget);

    // Switch to a different job
    final secondJob = repository.jobs.length > 1 ? repository.jobs[1] : repository.jobs.first.copyWith(id: 'job_second');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: secondJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Specs should be collapsed on the new job
    expect(find.text('Technique / Passes: '), findsNothing);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('PaintGaugeWalkaroundWidget prevents negative zero on fractional clear removed rounding down in µm and mils modes', (WidgetTester tester) async {
    // 0.3 µm difference: rounds to 0 µm in µm mode
    List<PaintGaugePoint> points = PaintGaugePoint.default8Points(initial: 120.3, post: 120.0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return PaintGaugeWalkaroundWidget(
                  points: points,
                  onPointsChanged: (newPts) => setState(() => points = newPts),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In µm mode with 0.3 µm removed: should display '0 µm', never '-0 µm'
    expect(find.text('-0 µm'), findsNothing);
    expect(find.text('0 µm'), findsWidgets);

    // Toggle to mils mode with 0.8 µm removed (0.8 / 25.4 = 0.0315 mil, rounds to 0.0 mil)
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    expect(find.text('-0.0 mil'), findsNothing);
    expect(find.text('0.0 mil'), findsWidgets);
  });

  testWidgets('PaintGaugeWalkaroundWidget editor dialog prevents negative zero on fractional difference and handles empty inputs safely', (WidgetTester tester) async {
    List<PaintGaugePoint> points = PaintGaugePoint.default8Points(initial: 120.0, post: 119.0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return PaintGaugeWalkaroundWidget(
                  points: points,
                  onPointsChanged: (newPts) => setState(() => points = newPts),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to mils mode
    await tester.tap(find.text('mils'));
    await tester.pumpAndSettle();

    // Open Hood dialog
    await tester.tap(find.text('Hood').first);
    await tester.pumpAndSettle();

    // Enter values with 0.02 mil difference (rounds to 0.0)
    await tester.enterText(find.widgetWithText(TextField, 'Initial (mil)'), '4.8');
    await tester.enterText(find.widgetWithText(TextField, 'Post-Polish (mil)'), '4.78');
    await tester.pumpAndSettle();

    // Should display '0.0 mil', never '-0.0 mil' in the dialog
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('-0.0 mil')), findsNothing);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('0.0 mil')), findsOneWidget);

    // Clear both text fields
    await tester.enterText(find.widgetWithText(TextField, 'Initial (mil)'), '');
    await tester.enterText(find.widgetWithText(TextField, 'Post-Polish (mil)'), '');
    await tester.pumpAndSettle();

    // Should safely display '0.0 mil' in the dialog
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('0.0 mil')), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('JobDetailScreen handles fractional micronsRemoved without negative zero and shows fallback when recipeStages is empty', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final jobFractional = repository.jobs.first.copyWith(
      id: 'job_fractional',
      initialPaintThicknessMicrons: 120.04,
      finalPaintThicknessMicrons: 120.0,
      paintGaugePoints: PaintGaugePoint.default8Points(initial: 120.04, post: 120.0),
      recipeStages: [],
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: jobFractional, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Clear Removed metric should show 0.0 µm, never -0.0 µm
    expect(find.text('-0.0 µm'), findsNothing);
    expect(find.text('0.0 µm'), findsOneWidget);

    // Empty recipe stages fallback message should appear
    expect(find.text('No specific recipe stages logged for this transformation.'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobRecipeCard renders like, comment, and save counts and handles actions', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final testJob = repository.jobs.first.copyWith(
      likesCount: 42,
      savesCount: 17,
      comments: [
        JobComment(
          id: 'c1',
          authorName: 'Commenter',
          authorAvatar: '',
          text: 'Nice work!',
          createdAt: DateTime.now(),
        ),
      ],
    );

    bool likePressed = false;
    bool savePressed = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: JobRecipeCard(
          job: testJob,
          repository: repository,
          showDetailerManagement: true,
          onLike: () => likePressed = true,
          onSave: () => savePressed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify like count (42), comment count (1), and save count (17)
    expect(find.text('42'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    // Verify "Edit Recipe" management button for author
    expect(find.text('Edit Recipe'), findsOneWidget);

    // Verify tapping like and save invokes callbacks
    await tester.tap(find.byIcon(testJob.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded));
    await tester.pump();
    expect(likePressed, isTrue);

    await tester.tap(find.byIcon(testJob.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded));
    await tester.pump();
    expect(savePressed, isTrue);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobDetailScreen bottom docked bar renders Like, Save, and Owner Edit button', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    repository.isLoggedIn = true;
    final ownedJob = repository.jobs.first.copyWith(
      author: repository.currentUser,
      likesCount: 15,
      savesCount: 8,
    );
    repository.jobs[0] = ownedJob;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: JobDetailScreen(job: ownedJob, repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify bottom docked bar social counts
    expect(find.text('15'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Share Report'), findsOneWidget);

    // Verify owner bottom action button
    final ownerEditBtn = find.byKey(const Key('job_detail_owner_edit_button'));
    expect(ownerEditBtn, findsOneWidget);

    // Tap like in detail screen
    final initialLiked = ownedJob.isLiked;
    await tester.tap(find.byIcon(initialLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap save in detail screen
    final initialSaved = ownedJob.isSaved;
    await tester.tap(find.byIcon(initialSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tapping bottom owner Edit button opens CreateJobScreen
    await tester.tap(ownerEditBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CreateJobScreen), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('JobRecipeCard message icon navigates directly to Discussion tab (initialTabIndex: 1)', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final testJob = repository.jobs.first;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: JobRecipeCard(
          job: testJob,
          repository: repository,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap comment bubble icon
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify JobDetailScreen is opened and Discussion tab is selected
    expect(find.byType(JobDetailScreen), findsOneWidget);
    expect(find.text('Paint Inspection & Gauge Data'), findsNothing);
    expect(find.text('Step-by-Step Process Recipe'), findsNothing);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('ProfileScreen renders Saved Recipes tab in both Detailer and Client modes', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    repository.isLoggedIn = true;

    // 1. Client Mode (default for youUser is client)
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: ProfileScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My Garage'), findsOneWidget);
    expect(find.text('Saved Recipes'), findsOneWidget);
    await tester.tap(find.text('Saved Recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Saved Recipes Yet'), findsOneWidget);
    expect(
      find.text('Bookmark transformations from the feed to reference for your vehicle.'),
      findsOneWidget,
    );

    // 2. Detailer Mode
    repository.toggleHostMode(); // Switches to Detailer mode
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: ProfileScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Saved Recipes'), findsOneWidget);
    await tester.tap(find.text('Saved Recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Saved Recipes Yet'), findsOneWidget);
    expect(
      find.text('Bookmark recipes from the community feed to build your technical paint correction playbook.'),
      findsOneWidget,
    );

    // 3. Real-time updates when saving
    repository.toggleSave(repository.jobs.first.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Saved Recipes Yet'), findsNothing);
    expect(find.byType(JobRecipeCard), findsWidgets);

    // 4. Real-time updates when unsaving
    repository.toggleSave(repository.jobs.first.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Saved Recipes Yet'), findsOneWidget);

    // 5. Switch back to Client Mode and verify Saved Recipes persists
    repository.toggleSave(repository.jobs.first.id); // Save again
    repository.toggleHostMode(); // Switch back to Client mode
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: ProfileScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Saved Recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No Saved Recipes Yet'), findsNothing);
    expect(find.byType(JobRecipeCard), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Studio Detailing Recipe allows renaming steps, free-text typing, appending samples, and saving/loading custom presets', (WidgetTester tester) async {
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

    // 1. Scroll to Studio Detailing Recipe section
    await tester.scrollUntilVisible(
      find.text('Studio Detailing Recipe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio Detailing Recipe'), findsOneWidget);
    expect(find.text('Save Preset'), findsOneWidget);
    expect(find.text('Add Step'), findsOneWidget);

    // 2. Tap Add Step
    await tester.tap(find.text('Add Step'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ACTIVE STEP'), findsWidgets);

    // 3. Rename step title via the rename dialog icon
    final renameButtonFinder = find.byTooltip('Rename Step').first;
    await tester.tap(renameButtonFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Edit Title - Step 1'), findsOneWidget);
    final titleDialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(titleDialogField, 'Heavy Rotary Correction');
    await tester.tap(find.text('Save Title'));
    await tester.pumpAndSettle();

    expect(find.text('Heavy Rotary Correction'), findsWidgets);

    // 4. Test free-text typing directly into fields
    final toolInputFinder = find.widgetWithText(TextFormField, 'Machines / Tools (comma separated)').first;
    await tester.enterText(toolInputFinder, 'Custom Rotary Buffer, Mini Air Polisher');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Custom Rotary Buffer, Mini Air Polisher'), findsWidgets);

    // 5. Test sample chip appending without replacing typed text
    // Menzerna Heavy Cut 400 sample chip
    await tester.scrollUntilVisible(
      find.text('Menzerna Heavy Cut 400'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menzerna Heavy Cut 400'));
    await tester.pumpAndSettle();

    expect(find.text('Chemical: Menzerna Heavy Cut 400'), findsOneWidget);

    // 6. Test Save Custom Preset
    await tester.scrollUntilVisible(
      find.text('Save Preset'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Preset'));
    await tester.pumpAndSettle();

    expect(find.text('Save Studio Preset'), findsOneWidget);
    final presetNameField = find.widgetWithText(TextField, 'Preset Name');
    await tester.enterText(presetNameField, 'Heavy Cut Custom Preset');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Preset'));
    await tester.pumpAndSettle();

    // Verify preset chip appears in the presets row
    expect(find.text('Heavy Cut Custom Preset'), findsWidgets);
    expect(repository.allRecipePresets.any((p) => p.name == 'Heavy Cut Custom Preset' && p.isCustom), isTrue);

    // 7. Test 1-click loading of custom preset
    final customChipFinder = find.text('Heavy Cut Custom Preset').first;
    final horizontalScrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
    );
    if (horizontalScrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        customChipFinder,
        100,
        scrollable: horizontalScrollable.first,
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(customChipFinder);
    await tester.pumpAndSettle();

    expect(find.text('Heavy Rotary Correction'), findsWidgets);

    // 8. Test Step Deletion and active stage index adjustment
    final initialStepCount = find.byTooltip('Rename Step').evaluate().length;
    final firstDeleteButton = find.byIcon(Icons.delete_outline_rounded).first;
    await tester.tap(firstDeleteButton);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rename Step').evaluate().length, equals(initialStepCount - 1));

    // 9. Test Preset Options Sheet: Rename custom preset
    final customPresetChip = find.widgetWithText(InputChip, 'Heavy Cut Custom Preset');
    await tester.ensureVisible(customPresetChip);
    await tester.pumpAndSettle();
    final moreOptionsFinder = find.descendant(
      of: customPresetChip,
      matching: find.byIcon(Icons.more_vert_rounded),
    );
    await tester.tap(moreOptionsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Rename Preset'), findsOneWidget);
    await tester.tap(find.text('Rename Preset'));
    await tester.pumpAndSettle();

    final renameField = find.widgetWithText(TextField, 'Preset Name');
    await tester.enterText(renameField, 'Renamed Heavy Cut Preset');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Heavy Cut Preset'), findsWidgets);
    expect(repository.allRecipePresets.any((p) => p.name == 'Renamed Heavy Cut Preset'), isTrue);

    // 10. Test Preset Options Sheet: Delete custom preset
    final renamedPresetChip = find.widgetWithText(InputChip, 'Renamed Heavy Cut Preset');
    await tester.ensureVisible(renamedPresetChip);
    await tester.pumpAndSettle();
    final moreOptionsAfterRename = find.descendant(
      of: renamedPresetChip,
      matching: find.byIcon(Icons.more_vert_rounded),
    );
    await tester.tap(moreOptionsAfterRename);
    await tester.pumpAndSettle();

    expect(find.text('Delete Custom Preset'), findsOneWidget);
    await tester.tap(find.text('Delete Custom Preset'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Heavy Cut Preset'), findsNothing);
    expect(repository.allRecipePresets.any((p) => p.name == 'Renamed Heavy Cut Preset'), isFalse);
  });

  testWidgets('Detailer Workbench View renders 3 panes on desktop, supports Focus Mode, subcategory filtering, and mobile drill-down', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    repository.isLoggedIn = true;
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    // --- 1. DESKTOP VIEW (1200 x 800) ---
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Pane 1 (Studio Hub) sections exist
    expect(find.text('STUDIO WORKBENCH HUB'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Saved Recipes'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('My Teams'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);

    // Verify Focus Mode toggle button in Pane 3
    expect(find.text('Focus Mode'), findsOneWidget);

    // 2. Test INVENTORY Pane 2 & Subcategory Filtering
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    // Verify Pane 2 header for Inventory
    expect(find.text('INVENTORY'), findsWidgets);
    expect(find.text('[ + ADD ]'), findsOneWidget);
    expect(find.text('HARDWARE'), findsWidgets);
    expect(find.text('CHEMICALS'), findsWidgets);
    expect(find.text('RECIPE'), findsWidgets);

    // Initial items include Hardware (default category is HARDWARE)
    expect(find.text('Rupes LHR15 Mark III (15mm)'), findsWidgets);

    // Filter by CHEMICALS
    await tester.tap(find.text('CHEMICALS'));
    await tester.pumpAndSettle();

    // Hardware should be filtered out, Chemical present
    expect(find.text('Rupes LHR15 Mark III (15mm)'), findsNothing);
    expect(find.text('Koch Chemie H9.02 Heavy Cut'), findsWidgets);

    // Filter by RECIPE
    await tester.ensureVisible(find.text('RECIPE'));
    await tester.tap(find.text('RECIPE'));
    await tester.pumpAndSettle();
    expect(find.text('German Ceramic Clear 2-Stage Formula'), findsWidgets);

    // Return to HARDWARE
    await tester.ensureVisible(find.text('HARDWARE'));
    await tester.tap(find.text('HARDWARE'));
    await tester.pumpAndSettle();
    expect(find.text('Rupes LHR15 Mark III (15mm)'), findsWidgets);

    // 3. Test Focus Mode Toggle (Collapse Panes 1 & 2)
    await tester.tap(find.text('Focus Mode'));
    await tester.pumpAndSettle();

    // Panes 1 and 2 collapsed: Studio Hub title no longer visible
    expect(find.text('STUDIO WORKBENCH HUB'), findsNothing);
    expect(find.text('Exit Focus'), findsOneWidget);

    // Exit Focus Mode -> Panes restored
    await tester.tap(find.text('Exit Focus'));
    await tester.pumpAndSettle();
    expect(find.text('STUDIO WORKBENCH HUB'), findsOneWidget);
    expect(find.text('Focus Mode'), findsOneWidget);

    // 4. Test MY TEAMS hub section
    await tester.tap(find.text('My Teams'));
    await tester.pumpAndSettle();
    expect(find.text('MY TEAMS'), findsWidgets);
    expect(find.text('FOUNDER'), findsOneWidget);

    // 5. Test SERVICES hub section
    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('SERVICES'), findsWidgets);
    expect(find.text('Stage 2 Paint Correction & Enhancement'), findsWidgets);

    // 6. Test Inventory Repository Mutators (Add item)
    final newItem = InventoryItem(
      id: 'inv_test_001',
      name: 'Flex XFE 7-15 150',
      category: InventoryCategory.hardware,
      subCategory: 'Dual Action Polisher',
      brand: 'Flex Tools',
      status: 'AVAILABLE',
      specs: {'Throw': '15mm', 'OPM': '2900-8600'},
      maintenance: 'Checked brushes and grease',
    );
    repository.addInventoryItem(newItem);
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Flex XFE 7-15 150'), findsOneWidget);

    // --- 7. MOBILE DRILL-DOWN STACK (400 x 800) ---
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // In mobile step 0: Studio Hub is shown
    expect(find.text('STUDIO WORKBENCH HUB'), findsOneWidget);

    // Tap Inventory -> drill down to Step 1 (Categories)
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Polishers, chemicals, formulas'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Tap HARDWARE category -> drill down to Step 2 (Pane 3 items list)
    await tester.tap(find.text('HARDWARE'));
    await tester.pumpAndSettle();
    expect(find.text('HARDWARE INVENTORY'), findsOneWidget);
    expect(find.text('Flex XFE 7-15 150'), findsOneWidget);

    // Tap back button -> back to Step 1 (Categories)
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Polishers, chemicals, formulas'), findsOneWidget);

    // Tap back button again -> back to Step 0 (Hub)
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('STUDIO WORKBENCH HUB'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Detailer Workbench View handles item deletion, fallback selection, specs preservation, and mobile delete step-back safely', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    repository.isLoggedIn = true;
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    // 1. DESKTOP VIEW
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Select Inventory in Pane 1
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    // Verify Pane 3 shows HARDWARE items line by line with status dropdown and [EDIT]
    expect(find.text('HARDWARE INVENTORY'), findsOneWidget);
    expect(find.text('Rupes LHR15 Mark III (15mm)'), findsWidgets);
    expect(find.text('In Service'), findsWidgets);
    expect(find.text('[EDIT]'), findsWidgets);

    // Verify Delete action exists on the item line in Pane 3
    final deleteFinder = find.byTooltip('Delete Item');
    expect(deleteFinder, findsWidgets);

    // Tap Delete -> Confirmation Dialog
    await tester.tap(deleteFinder.first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Deletion'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to remove "Rupes LHR15 Mark III (15mm)"?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify Rupes is deleted from repository and Pane 3
    expect(repository.inventoryItems.any((i) => i.name.contains('Rupes LHR15 Mark III')), isFalse);
    expect(find.text('Rupes LHR15 Mark III (15mm)'), findsNothing);
    expect(find.text('Flex PXE 80 10.8-EC'), findsWidgets);

    // 2. Test specs preservation in InventoryItemEditorDialog
    final customItem = const InventoryItem(
      id: 'inv_preserve_test',
      name: 'Custom Coating X',
      category: InventoryCategory.chemicals,
      subCategory: 'Ceramic Coating',
      specs: {
        'SiO2 Concentration': '85%',
        'Hardness': '9H Pencil',
        'Stock Volume': '50 ml',
      },
    );
    repository.addInventoryItem(customItem);
    await tester.pumpAndSettle();

    // Tap to select CHEMICALS category
    await tester.tap(find.text('CHEMICALS'));
    await tester.pumpAndSettle();

    // Custom Coating X is listed in Pane 3
    expect(find.text('Custom Coating X'), findsWidgets);

    // Open [EDIT] on Custom Coating X
    final editButtonFinder = find.widgetWithText(ElevatedButton, '[EDIT]').first;
    await tester.tap(editButtonFinder);
    await tester.pumpAndSettle();
    expect(find.text('Edit CHEMICALS'), findsOneWidget);

    // Save changes without editing specs
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tester.pumpAndSettle();

    // Verify original specs map was preserved
    final savedItem = repository.inventoryItems.firstWhere((i) => i.id == 'inv_preserve_test');
    expect(savedItem.specs['SiO2 Concentration'], equals('85%'));
    expect(savedItem.specs['Hardness'], equals('9H Pencil'));

    // 3. Test Mobile Drill-Down Delete Step-Back
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Mobile Step 0: Tap Inventory -> Step 1 (Categories)
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Polishers, chemicals, formulas'), findsOneWidget);

    // Tap CHEMICALS category on mobile -> Step 2 (Pane 3 items list)
    await tester.tap(find.text('CHEMICALS'));
    await tester.pumpAndSettle();
    expect(find.text('CHEMICALS INVENTORY'), findsOneWidget);
    expect(find.text('Custom Coating X'), findsWidgets);

    // Step 2: Delete item from Pane 3
    final mobileDeleteFinder = find.byTooltip('Delete Item');
    await tester.tap(mobileDeleteFinder.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify item is removed from view and repo
    expect(find.text('Custom Coating X'), findsNothing);

    // Step back to Step 1 (Categories)
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Polishers, chemicals, formulas'), findsOneWidget);

    // Verify SafeArea exists in tree for mobile view
    expect(find.byType(SafeArea), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Detailer Workbench mixes hardware & chemical ingredients in recipe stages and supports chemical Full/Half/Empty status', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    repository.isLoggedIn = true;
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Go to Inventory -> CHEMICALS
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CHEMICALS'));
    await tester.pumpAndSettle();

    // Verify Chemical statuses: Full and Half
    expect(find.text('Full'), findsWidgets);
    expect(find.text('Half'), findsWidgets);

    // Open [EDIT] on first chemical
    await tester.tap(find.widgetWithText(ElevatedButton, '[EDIT]').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit CHEMICALS'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    // Dilution specs should be removed
    expect(find.text('Dilution Specs'), findsNothing);

    // Cancel chemical modal
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Go to RECIPE category
    await tester.tap(find.text('RECIPE'));
    await tester.pumpAndSettle();

    expect(find.text('RECIPE INVENTORY'), findsOneWidget);
    expect(find.text('German Ceramic Clear 2-Stage Formula'), findsOneWidget);
    expect(find.textContaining('Formula Steps'), findsWidgets);

    // Open [EDIT] on recipe
    await tester.tap(find.widgetWithText(ElevatedButton, '[EDIT]').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit RECIPE'), findsOneWidget);
    expect(find.text('Formula / Recipe Name *'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    // Redundant fields removed from Recipe modal
    expect(find.text('Brand / Manufacturer'), findsNothing);
    expect(find.text('Subcategory / Type'), findsNothing);
    expect(find.text('Studio Location / Wall Bay'), findsNothing);

    // Open step editor to add step
    await tester.tap(find.text('+ Add Step'));
    await tester.pumpAndSettle();

    expect(find.text('Add Formula Step'), findsOneWidget);
    expect(find.text('Machine / Tool(s)'), findsOneWidget);
    expect(find.text('Chemical / Product(s)'), findsOneWidget);

    // Close step editor & close recipe dialog
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('Recipes link to Service Packages, import stages into treatments, and load in CreateJobScreen', (WidgetTester tester) async {
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    repository.isLoggedIn = true;
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;

    // 1. Test ServicePackageEditorDialog importing from Studio Recipe
    ServicePackage? savedPackage;
    final testRecipe = repository.recipeItems.first;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              ServicePackageEditorDialog.show(
                context,
                availableRecipes: repository.recipeItems,
                onSave: (pkg) {
                  savedPackage = pkg;
                },
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Select template title while visible at top of dialog
    await tester.tap(find.text('Full Detail (In & Out)').first);
    await tester.pumpAndSettle();

    // Drag down to reveal Import Recipe
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Import Recipe'), findsOneWidget);

    // Tap Import Recipe popup menu button
    await tester.tap(find.text('Import Recipe'));
    await tester.pumpAndSettle();

    // Select the first recipe from the popup menu
    expect(find.text(testRecipe.name), findsOneWidget);
    await tester.tap(find.text(testRecipe.name));
    await tester.pumpAndSettle();

    // Verify linked recipe banner is displayed
    expect(find.textContaining('Linked Studio Recipe: ${testRecipe.name}'), findsOneWidget);

    await tester.tap(find.text('Create Package'));
    await tester.pumpAndSettle();

    expect(savedPackage, isNotNull);
    expect(savedPackage!.recipeId, equals(testRecipe.id));
    expect(savedPackage!.recipeName, equals(testRecipe.name));
    expect(savedPackage!.includes.isNotEmpty, isTrue);

    // Add this saved package to repository to test workbench inspection
    repository.addServicePackage(savedPackage!);

    // 2. Test DetailerWorkbenchView Service Package inspector shows linked recipe banner and view recipe button
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Tap Services tab in Studio Hub
    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();

    // Select our new package
    await tester.tap(find.text('Full Detail (In & Out)').first);
    await tester.pumpAndSettle();

    expect(find.text('LINKED STUDIO RECIPE'), findsOneWidget);
    expect(find.text(testRecipe.name), findsWidgets);
    expect(find.text('View Recipe'), findsOneWidget);

    // Tapping 'View Recipe' opens the Recipe Preview Modal
    await tester.tap(find.text('View Recipe'));
    await tester.pumpAndSettle();

    // Verify modal preview is shown with recipe details and action buttons
    expect(find.text('Back to Services'), findsOneWidget);
    expect(find.text('Open in Workbench'), findsOneWidget);

    // Tapping 'Open in Workbench' takes detailer directly to Inventory Recipes with return banner
    await tester.tap(find.text('Open in Workbench'));
    await tester.pumpAndSettle();

    expect(find.text('RECIPE INVENTORY'), findsOneWidget);
    expect(find.text('Back to Package'), findsOneWidget);

    // Tapping 'Back to Package' returns smoothly to Services
    await tester.tap(find.text('Back to Package'));
    await tester.pumpAndSettle();
    expect(find.text('LINKED STUDIO RECIPE'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('CreateJobScreen loads stages directly from Studio Recipes', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final testRecipe = repository.recipeItems.first;

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

    // Scroll to Studio Detailing Recipe
    await tester.scrollUntilVisible(
      find.text('Studio Detailing Recipe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio Recipe'), findsOneWidget);

    // Tap Studio Recipe button
    await tester.tap(find.text('Studio Recipe'));
    await tester.pumpAndSettle();

    expect(find.text(testRecipe.name), findsOneWidget);
    await tester.tap(find.text(testRecipe.name));
    await tester.pumpAndSettle();

    // Verify first stage from testRecipe is loaded into CreateJobScreen
    if (testRecipe.recipeStages.isNotEmpty) {
      expect(find.textContaining(testRecipe.recipeStages.first.stageName), findsWidgets);
    }
  });

  testWidgets('ServicePackageEditorDialog pre-fills complete template info and handles recipe title chip', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final testRecipe = repository.recipeItems.first;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ServicePackageEditorDialog.show(
              context,
              availableRecipes: [testRecipe],
              onSave: (_) {},
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Tap '1-Stage Paint Correction' quick template
    await tester.tap(find.text('1-Stage Paint Correction').first);
    await tester.pumpAndSettle();

    // Verify Title and Price are populated
    expect(find.text('1-Stage Paint Correction'), findsWidgets);
    expect(find.text('450'), findsOneWidget);

    // Scroll down to verify Description and Includes are populated
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.textContaining('Precision single-step machine polish'), findsOneWidget);
    expect(find.textContaining('Ultrasonic digital paint depth gauge inspection'), findsOneWidget);

    // 2. Test recipe import title suggestion chip when title already exists
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Import Recipe'), findsOneWidget);
    await tester.tap(find.text('Import Recipe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(testRecipe.name));
    await tester.pumpAndSettle();

    // Scroll back up to Title
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    // Verify title suggestion chip appears
    expect(find.text('Use Recipe Title: "${testRecipe.name}"'), findsOneWidget);

    // Tap suggestion chip to apply title
    await tester.tap(find.text('Use Recipe Title: "${testRecipe.name}"'));
    await tester.pumpAndSettle();

    // Verify title is now updated to the recipe name
    expect(find.text(testRecipe.name), findsWidgets);
  });

  testWidgets('Detailer Workbench Calendar section renders month grid, allows toggling day block and hourly slots', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
    });

    final repository = JobRepository();
    // Ensure detailer mode and open business schedule
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }
    final openSchedule = repository.calendarPreferences.weeklySchedule.map((d) => d.copyWith(isOpen: true)).toList();
    repository.updateCalendarPreferences(repository.calendarPreferences.copyWith(weeklySchedule: openSchedule));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Select Calendar from Studio Hub Pane 1
    final calendarTile = find.text('Calendar');
    expect(calendarTile, findsOneWidget);
    await tester.tap(calendarTile);
    await tester.pumpAndSettle();

    // 2. Verify Pane 2 Month Grid & Pane 3 Day Inspector rendered
    expect(find.text('CALENDAR INSPECTOR'), findsOneWidget);
    expect(find.text('Operating Hours & Preferences'), findsWidgets);
    expect(find.text('HOURLY SLOT AVAILABILITY'), findsOneWidget);
    expect(find.text('Block Full Day'), findsOneWidget);

    // 3. Toggle Full Day Block on currently selected date
    await tester.tap(find.text('Block Full Day'));
    await tester.pumpAndSettle();

    expect(find.text('DAY BLOCKED'), findsOneWidget);
    expect(find.text('Unblock Full Day'), findsOneWidget);

    // Unblock the full day
    await tester.tap(find.text('Unblock Full Day'));
    await tester.pumpAndSettle();
    expect(find.text('Block Full Day'), findsOneWidget);

    // 4. Toggle Hourly Slot Block on a specific window
    final blockSlotButtons = find.text('Block Slot');
    expect(blockSlotButtons, findsWidgets);
    await tester.tap(blockSlotButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Blocked by Detailer'), findsWidgets);
    expect(find.text('Reopen'), findsWidgets);

    // Reopen the blocked slot
    await tester.tap(find.text('Reopen').first);
    await tester.pumpAndSettle();
    expect(find.text('Available for Booking'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('CalendarPreferencesDialog allows configuring weekly schedule and booking preferences', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CalendarPreferencesDialog.show(context, repository: repository),
            child: const Text('Open Calendar Preferences'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Calendar Preferences'));
    await tester.pumpAndSettle();

    // Verify dialog opened with operating hours and settings
    expect(find.text('Calendar & Operating Preferences'), findsOneWidget);
    expect(find.text('RECURRING WEEKLY SCHEDULE & DAYS OFF'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);

    // Scroll down to reveal Sunday and booking rules
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('BOOKING LEAD TIME & TURNAROUND RULES'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Minimum Advance Notice'), 100.0);
    await tester.pumpAndSettle();
    expect(find.text('Minimum Advance Notice'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Turnaround Buffer Between Jobs'), 100.0);
    await tester.pumpAndSettle();
    expect(find.text('Turnaround Buffer Between Jobs'), findsOneWidget);

    // Tap Save Preferences
    await tester.tap(find.text('Save Schedule Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar & Operating Preferences'), findsNothing);
  });

  testWidgets('BookingFlowScreen shields detailer by respecting blocked slots', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();
    final detailer = repository.currentUser;

    // Pick an open business day
    DateTime openDate = DateTime.now().add(const Duration(days: 1));
    while (!repository.calendarPreferences.getHoursForWeekday(openDate.weekday).isOpen) {
      openDate = openDate.add(const Duration(days: 1));
    }
    // Block the first slot on this open date
    final availableSlots = repository.getTimeSlotsForDate(openDate, detailerId: detailer.id);
    final slotToBlock = availableSlots.isNotEmpty ? availableSlots.first : '9:00 AM - 12:00 PM';
    repository.toggleBlockSlot(openDate, slotToBlock);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: BookingFlowScreen(
        detailer: detailer,
        repository: repository,
        initialDate: openDate,
      ),
    ));
    await tester.pumpAndSettle();

    // Step 0: Package Selection -> Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 1: Vehicle & Schedule
    expect(find.text('Select Date & Time Window'), findsOneWidget);

    // Verify BLOCKED badge is visible for the blocked slot
    final hasClosedOrBlocked = find.text('CLOSED').evaluate().isNotEmpty ||
        find.text('BLOCKED').evaluate().isNotEmpty;
    expect(hasClosedOrBlocked, isTrue);
  });

  testWidgets('Changing opening time to 6am allows clients to book 6am slot dynamically', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;

    final repository = JobRepository();

    // Configure Monday-Friday to open at 6:00 AM
    final updatedSchedule = repository.calendarPreferences.weeklySchedule.map((day) {
      if (day.weekday < 6) {
        return day.copyWith(isOpen: true, openTime: '06:00 AM', closeTime: '06:00 PM');
      }
      return day;
    }).toList();

    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(weeklySchedule: updatedSchedule),
    );

    // Pick an open weekday (Monday through Friday)
    DateTime testDate = DateTime.now().add(const Duration(days: 1));
    while (testDate.weekday >= 6) {
      testDate = testDate.add(const Duration(days: 1));
    }

    // Verify getTimeSlotsForDate includes 6:00 AM slot
    final slots = repository.getTimeSlotsForDate(testDate);
    expect(slots.any((s) => s.startsWith('6:00 AM') || s.startsWith('06:00 AM')), isTrue);
    expect(repository.isSlotWithinOperatingHours(testDate, '6:00 AM - 9:00 AM'), isTrue);

    // Launch BookingFlowScreen and verify 6:00 AM is selectable and bookable
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: BookingFlowScreen(
        detailer: repository.currentUser,
        repository: repository,
        initialDate: testDate,
      ),
    ));
    await tester.pumpAndSettle();

    // Step 0: Continue to step 1
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify 6:00 AM slot chip is present in booking flow
    expect(find.textContaining('6:00 AM'), findsWidgets);
  });

  testWidgets('Detailer can add, edit, and remove custom slots and auto-generate from hours', (tester) async {
    final repository = JobRepository();

    // 1. Add a custom early bird slot
    repository.addCustomTimeSlot('6:00 AM - 8:00 AM');
    expect(repository.calendarPreferences.customTimeSlots.contains('6:00 AM - 8:00 AM'), isTrue);

    // 2. Edit the custom slot
    repository.updateCustomTimeSlot('6:00 AM - 8:00 AM', '6:30 AM - 8:30 AM');
    expect(repository.calendarPreferences.customTimeSlots.contains('6:30 AM - 8:30 AM'), isTrue);
    expect(repository.calendarPreferences.customTimeSlots.contains('6:00 AM - 8:00 AM'), isFalse);

    // 3. Remove the custom slot
    repository.removeCustomTimeSlot('6:30 AM - 8:30 AM');
    expect(repository.calendarPreferences.customTimeSlots.contains('6:30 AM - 8:30 AM'), isFalse);

    // 4. Auto-generate slots for 6:00 AM to 6:00 PM
    repository.autoGenerateTimeSlots(
      openTime: '06:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 3,
    );
    final genSlots = repository.calendarPreferences.customTimeSlots;
    expect(genSlots.first, '6:00 AM - 9:00 AM');
    expect(genSlots.contains('9:00 AM - 12:00 PM'), isTrue);
    expect(genSlots.contains('3:00 PM - 6:00 PM'), isTrue);
  });

  testWidgets('Booked appointments prevent schedule conflicts on both customer and detailer calendars', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    // Configure open business schedule with 30 min buffer
    final openSchedule = repository.calendarPreferences.weeklySchedule.map((d) {
      return d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '08:00 PM');
    }).toList();
    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(
        weeklySchedule: openSchedule,
        bufferMinutesBetweenJobs: 30,
        customTimeSlots: [
          '8:00 AM - 11:00 AM',
          '9:00 AM - 12:00 PM',
          '1:00 PM - 4:00 PM',
          '4:00 PM - 7:00 PM',
        ],
      ),
    );

    // Pick an open weekday
    DateTime testDate = DateTime.now().add(const Duration(days: 2));
    while (testDate.weekday >= 7) {
      testDate = testDate.add(const Duration(days: 1));
    }

    final detailer = repository.currentUser;

    // 1. Add a confirmed booking from 8:00 AM - 11:00 AM
    final booking = BookingAppointment(
      id: 'book_test_conflict',
      detailerId: detailer.id,
      detailerName: detailer.displayName,
      detailerBusinessName: detailer.businessName,
      detailerAvatar: detailer.avatarUrl,
      clientName: 'Alex Rivera',
      clientPhone: '555-0199',
      clientEmail: 'alex@example.com',
      vehicleYearMakeModel: '2023 BMW M3 Competition',
      vehicleSize: VehicleSize.coupeSedan,
      package: const ServicePackage(
        id: 'pkg_test_1',
        title: 'Paint Correction & Ceramic',
        description: 'Multi-stage swirl removal',
        basePrice: 500.0,
        estimatedDuration: '3 hours',
        includes: ['Decon wash', 'Machine polish'],
      ),
      locationType: ServiceLocationType.shop,
      clientAddress: 'Detail Studio',
      scheduledDate: testDate,
      scheduledTimeSlot: '8:00 AM - 11:00 AM',
      totalPrice: 500.0,
      depositAmount: 100.0,
      status: BookingStatus.confirmed,
    );
    repository.addBooking(booking);

    // 2. Unit check: interval math identifies direct and overlapping conflicts
    expect(repository.isSlotConflictedByBooking(testDate, '8:00 AM - 11:00 AM', detailerId: detailer.id), isTrue);
    expect(repository.isSlotConflictedByBooking(testDate, '9:00 AM - 12:00 PM', detailerId: detailer.id), isTrue);
    expect(repository.isSlotConflictedByBooking(testDate, '1:00 PM - 4:00 PM', detailerId: detailer.id), isFalse);
    expect(repository.isSlotConflictedByBooking(testDate, '4:00 PM - 7:00 PM', detailerId: detailer.id), isFalse);

    // 3. Customer Perspective: Test BookingFlowScreen
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: BookingFlowScreen(
        detailer: detailer,
        repository: repository,
        initialDate: testDate,
      ),
    ));
    await tester.pumpAndSettle();

    // Proceed to Step 1 (Vehicle & Schedule)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify Customer sees live interactive calendar month view
    expect(find.text('Select Date & Time Window'), findsOneWidget);
    expect(find.textContaining('Live availability direct from'), findsOneWidget);

    // Verify booked and overlapping slots are marked BOOKED
    final bookedBadges = find.text('BOOKED');
    expect(bookedBadges, findsWidgets);

    // 4. Detailer Perspective: Test DetailerWorkbenchView
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(
          repository: repository,
          initialCalendarDate: testDate,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Select Calendar
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Verify Day Inspector shows exact booking and overlap conflict shield
    expect(find.textContaining('Booked by Alex Rivera'), findsOneWidget);
    expect(find.textContaining('Reserved • Overlaps with Alex Rivera'), findsOneWidget);
    expect(find.text('Available for Booking'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Closed operating days and full day blocks immediately strike off availability and prevent booking', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    // Pick a test date 2 days ahead
    DateTime testDate = DateTime.now().add(const Duration(days: 2));

    // Initially configure this weekday as closed from operating hours
    final scheduleWithClosedDay = repository.calendarPreferences.weeklySchedule.map((d) {
      if (d.weekday == testDate.weekday) {
        return d.copyWith(isOpen: false);
      }
      return d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '08:00 PM');
    }).toList();
    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(weeklySchedule: scheduleWithClosedDay),
    );

    // 1. Detailer workbench view on a closed day:
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(
          repository: repository,
          initialCalendarDate: testDate,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Select Calendar
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Slots should show Studio Closed (Day Off), and NOT Available for Booking
    expect(find.text('Studio Closed (Day Off)'), findsWidgets);
    expect(find.text('Available for Booking'), findsNothing);

    // 2. Open this weekday for booking
    final openSchedule = repository.calendarPreferences.weeklySchedule.map((d) {
      return d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '08:00 PM');
    }).toList();
    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(weeklySchedule: openSchedule),
    );
    await tester.pumpAndSettle();

    // Slots are now open and Available for Booking
    expect(find.text('Available for Booking'), findsWidgets);
    expect(find.text('Studio Closed (Day Off)'), findsNothing);

    // 3. Block full day
    await tester.tap(find.text('Block Full Day'));
    await tester.pumpAndSettle();

    // Immediately strikes off Available for Booking and shows Day Blocked by Detailer
    expect(find.text('Day Blocked by Detailer'), findsWidgets);
    expect(find.text('Available for Booking'), findsNothing);
    expect(find.text('Unblock Full Day'), findsOneWidget);

    // 4. Unblock full day
    await tester.tap(find.text('Unblock Full Day'));
    await tester.pumpAndSettle();

    // Re-enables Available for Booking
    expect(find.text('Available for Booking'), findsWidgets);
    expect(find.text('Day Blocked by Detailer'), findsNothing);

    // 5. Turn off this day in schedule again
    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(weeklySchedule: scheduleWithClosedDay),
    );
    await tester.pumpAndSettle();

    // Striking off Available for Booking right away
    expect(find.text('Studio Closed (Day Off)'), findsWidgets);
    expect(find.text('Available for Booking'), findsNothing);

    // 6. Customer Perspective: verify slots are struck off and cannot be booked
    final detailer = repository.currentUser;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: BookingFlowScreen(
        detailer: detailer,
        repository: repository,
        initialDate: testDate,
      ),
    ));
    await tester.pumpAndSettle();

    // Advance to Step 1 (Schedule)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Closed day banner and strikes
    expect(find.text('CLOSED'), findsWidgets);

    // Attempting to advance while closed slot is selected triggers warning snackbar
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Closed'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('JobRepository slot deletion, clear slots (0 slots), unblock all, and reset to defaults', () {
    final repository = JobRepository();
    final user = repository.currentUser;
    final now = DateTime.now();
    // Use an upcoming Monday
    int daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    final mondayDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilMonday));
    final nextMondayDate = mondayDate.add(const Duration(days: 7));

    // Initial slots
    final initialSlots = repository.getTimeSlotsForDate(mondayDate);
    expect(initialSlots.contains('8:00 AM - 11:00 AM'), isTrue);

    // 1. Delete slot for "This Date Only"
    repository.removeCustomTimeSlot(
      '8:00 AM - 11:00 AM',
      specificDate: mondayDate,
      applyAllDays: false,
    );
    final mondaySlotsAfterSingleDateDelete = repository.getTimeSlotsForDate(mondayDate);
    expect(mondaySlotsAfterSingleDateDelete.contains('8:00 AM - 11:00 AM'), isFalse);
    // Other Monday still has the slot
    final nextMondaySlots = repository.getTimeSlotsForDate(nextMondayDate);
    expect(nextMondaySlots.contains('8:00 AM - 11:00 AM'), isTrue);

    // 2. Delete slot for "All Operating Days"
    repository.removeCustomTimeSlot(
      '9:00 AM - 12:00 PM',
      specificDate: mondayDate,
      applyAllDays: true,
    );
    expect(repository.getTimeSlotsForDate(mondayDate).contains('9:00 AM - 12:00 PM'), isFalse);
    expect(repository.getTimeSlotsForDate(nextMondayDate).contains('9:00 AM - 12:00 PM'), isFalse);

    // 3. Clear all slots for date -> must return 0 slots, NOT defaulting to 2 open slots!
    repository.clearTimeSlotsForDate(mondayDate);
    final clearedSlots = repository.getTimeSlotsForDate(mondayDate);
    expect(clearedSlots.isEmpty, isTrue);

    // 4. Reset date to schedule defaults
    repository.resetTimeSlotsForDateToDefaults(mondayDate);
    final resetSlots = repository.getTimeSlotsForDate(mondayDate);
    expect(resetSlots.isNotEmpty, isTrue);
    expect(resetSlots.contains('8:00 AM - 11:00 AM'), isTrue);

    // 5. Unblock all without erasing custom slots
    repository.addCustomTimeSlot('6:00 AM - 8:00 AM', specificDate: mondayDate);
    repository.toggleBlockSlot(mondayDate, '8:00 AM - 11:00 AM');
    expect(repository.isSlotExplicitlyBlocked(user.id, mondayDate, '8:00 AM - 11:00 AM'), isTrue);

    repository.clearBlockedSlotsForDate(mondayDate);
    expect(repository.isSlotExplicitlyBlocked(user.id, mondayDate, '8:00 AM - 11:00 AM'), isFalse);
    // Custom slot is preserved after unblocking
    expect(repository.getTimeSlotsForDate(mondayDate).contains('6:00 AM - 8:00 AM'), isTrue);
  });

  testWidgets('Detailer Workbench UI slot delete confirmation, clear slots (empty state), and unblock buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Navigate to Calendar
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Verify Clear Slots button exists when slots are present
    expect(find.text('Clear Slots'), findsWidgets);

    // Tap Clear Slots
    await tester.tap(find.text('Clear Slots').first);
    await tester.pumpAndSettle();

    // Dialog pops up
    expect(find.text('Clear All Time Slots'), findsOneWidget);
    // Confirm Clear Slots in dialog
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Clear Slots')));
    await tester.pumpAndSettle();

    // Empty state container must now be rendered (0 slots defined for this day!)
    expect(find.text('No slots defined for this day.'), findsOneWidget);
    expect(find.text('Reset to Schedule Defaults'), findsOneWidget);

    // Tap Reset to Schedule Defaults
    await tester.tap(find.text('Reset to Schedule Defaults'));
    await tester.pumpAndSettle();

    // Slots are back
    expect(find.text('No slots defined for this day.'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

    // Tap Delete on first slot
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    // Confirmation dialog pops up
    expect(find.text('Delete Time Slot'), findsOneWidget);
    expect(find.text('This Date Only'), findsOneWidget);
    expect(find.text('All Operating Days'), findsOneWidget);

    // Tap This Date Only
    await tester.tap(find.text('This Date Only'));
    await tester.pumpAndSettle();

    // Dialog is dismissed
    expect(find.text('Delete Time Slot'), findsNothing);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('JobRepository autoGenerateTimeSlots across other hour durations (1h, 2h, 4h, 5h, 6h, 8h) and overrides clearance', () {
    final repository = JobRepository();

    final mondayDate = DateTime(2026, 10, 12); // Monday
    final tuesdayDate = DateTime(2026, 10, 13); // Tuesday

    // 1. Test 4-hour slot generation on 8:00 AM - 6:00 PM
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 4,
    );
    final slots4h = repository.getTimeSlotsForDate(mondayDate);
    expect(slots4h, equals(['8:00 AM - 12:00 PM', '12:00 PM - 4:00 PM']));
    expect(repository.calendarPreferences.slotDurationHours, equals(4));

    // 2. Test 2-hour slot generation
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 2,
    );
    final slots2h = repository.getTimeSlotsForDate(mondayDate);
    expect(slots2h.length, equals(5));
    expect(slots2h.first, equals('8:00 AM - 10:00 AM'));
    expect(slots2h.last, equals('4:00 PM - 6:00 PM'));

    // 3. Test 1-hour slot generation
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 1,
    );
    final slots1h = repository.getTimeSlotsForDate(mondayDate);
    expect(slots1h.length, equals(10));
    expect(slots1h.first, equals('8:00 AM - 9:00 AM'));
    expect(slots1h.last, equals('5:00 PM - 6:00 PM'));

    // 4. Test 6-hour slot generation
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 6,
    );
    final slots6h = repository.getTimeSlotsForDate(mondayDate);
    expect(slots6h, equals(['8:00 AM - 2:00 PM']));

    // 5. Test 8-hour slot generation
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 8,
    );
    final slots8h = repository.getTimeSlotsForDate(mondayDate);
    expect(slots8h, equals(['8:00 AM - 4:00 PM']));

    // 6. Test that auto-generating for "All Operating Days" clears date overrides
    // Create a date override on Monday by clearing slots
    repository.clearTimeSlotsForDate(mondayDate);
    expect(repository.getTimeSlotsForDate(mondayDate).isEmpty, isTrue);

    // Auto-generate 4h slots globally (specificDate == null)
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 4,
    );
    // Monday MUST immediately adopt the newly generated 4h slots, not stay empty!
    final refreshedMonday = repository.getTimeSlotsForDate(mondayDate);
    expect(refreshedMonday, equals(['8:00 AM - 12:00 PM', '12:00 PM - 4:00 PM']));

    // 7. Test single-date auto-generation (specificDate != null)
    repository.autoGenerateTimeSlots(
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      slotDurationHours: 2,
      specificDate: tuesdayDate,
    );
    // Tuesday has 2h slots (date override)
    expect(repository.getTimeSlotsForDate(tuesdayDate).length, equals(5));
    // Monday retains global 4h slots
    expect(repository.getTimeSlotsForDate(mondayDate).length, equals(2));
  });

  testWidgets('Detailer Workbench UI auto-generate slots dialog with duration chips and live preview', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Navigate to Calendar
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Tap Auto-Gen button in calendar inspector
    expect(find.text('Auto-Gen'), findsWidgets);
    await tester.tap(find.text('Auto-Gen').first);
    await tester.pumpAndSettle();

    // Auto-Gen dialog is visible
    expect(find.text('Auto-Generate Slots'), findsOneWidget);
    expect(find.text('Slot Duration / Interval'), findsOneWidget);

    // Verify all duration chips are rendered
    expect(find.text('1 Hour'), findsOneWidget);
    expect(find.text('2 Hours'), findsOneWidget);
    expect(find.text('3 Hours'), findsOneWidget);
    expect(find.text('4 Hours'), findsOneWidget);
    expect(find.text('5 Hours'), findsOneWidget);
    expect(find.text('6 Hours'), findsOneWidget);
    expect(find.text('8 Hours'), findsOneWidget);

    // Tap 4 Hours chip
    await tester.tap(find.text('4 Hours'));
    await tester.pumpAndSettle();

    // Verify live preview shows 4h windows
    expect(find.text('4h windows'), findsOneWidget);
    expect(find.text('8:00 AM - 12:00 PM'), findsWidgets);

    // Tap 2 Hours chip
    await tester.tap(find.text('2 Hours'));
    await tester.pumpAndSettle();

    // Verify live preview shows 2h windows
    expect(find.text('2h windows'), findsOneWidget);
    expect(find.text('8:00 AM - 10:00 AM'), findsWidgets);

    // Confirm Generate Slots
    await tester.tap(find.text('Generate Slots'));
    await tester.pumpAndSettle();

    // Dialog is dismissed
    expect(find.text('Auto-Generate Slots'), findsNothing);

    // Verify slots are generated and visible in workbench
    expect(find.text('8:00 AM - 10:00 AM'), findsWidgets);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Detailer Workbench Pane 1 hardcoded arrangement B sequence', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Pane 1 items are in exact order B:
    // Portfolio -> Services -> Inventory -> Calendar -> My Teams -> Saved Recipes
    final expectedTitles = [
      'Portfolio',
      'Services',
      'Inventory',
      'Calendar',
      'My Teams',
      'Saved Recipes',
    ];

    for (final title in expectedTitles) {
      expect(find.text(title), findsWidgets);
    }

    // Verify vertical order in Pane 1 list
    final portfolioTop = tester.getTopLeft(find.text('Portfolio').first).dy;
    final servicesTop = tester.getTopLeft(find.text('Services').first).dy;
    final inventoryTop = tester.getTopLeft(find.text('Inventory').first).dy;
    final calendarTop = tester.getTopLeft(find.text('Calendar').first).dy;
    final teamsTop = tester.getTopLeft(find.text('My Teams').first).dy;
    final savedRecipesTop = tester.getTopLeft(find.text('Saved Recipes').first).dy;

    expect(portfolioTop < servicesTop, isTrue);
    expect(servicesTop < inventoryTop, isTrue);
    expect(inventoryTop < calendarTop, isTrue);
    expect(calendarTop < teamsTop, isTrue);
    expect(teamsTop < savedRecipesTop, isTrue);

    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('My Teams is linked to Calendar with personal schedules, multi-tech slot capacity, and synced customer booking flow', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = JobRepository();
    if (repository.currentUser.role != UserRole.detailer) {
      repository.toggleHostMode();
    }

    final testDate = DateTime.now().add(const Duration(days: 3));

    // Ensure test date is open
    final openSchedule = repository.calendarPreferences.weeklySchedule.map((d) {
      return d.copyWith(isOpen: true, openTime: '08:00 AM', closeTime: '08:00 PM');
    }).toList();
    repository.updateCalendarPreferences(
      repository.calendarPreferences.copyWith(weeklySchedule: openSchedule),
    );

    // Add Tyler Reed to team roster
    const tech = TeamMember(
      id: 'tm_tyler',
      name: 'Tyler Reed',
      roleTitle: 'Senior Correction Tech',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      rating: 5.0,
      completedJobsCount: 42,
    );
    repository.addTeamMember(tech);

    final staff = repository.getStudioStaff(detailerId: repository.currentUser.id);
    expect(staff.length, 2);

    // 1. Mount DetailerWorkbenchView
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(
          repository: repository,
          initialCalendarDate: testDate,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 2. Navigate to My Teams in Pane 1
    await tester.tap(find.text('My Teams'));
    await tester.pumpAndSettle();

    // Select Tyler Reed in team list
    final tylerItem = find.text('Tyler Reed');
    expect(tylerItem, findsWidgets);
    await tester.tap(tylerItem.first);
    await tester.pumpAndSettle();

    // Verify "View Tyler's Calendar" button is present and tap it
    final viewCalendarBtn = find.text("View Tyler's Calendar");
    expect(viewCalendarBtn, findsOneWidget);
    await tester.tap(viewCalendarBtn);
    await tester.pumpAndSettle();

    // Verify switched to Calendar showing Tyler's personal schedule banner
    expect(find.textContaining('Viewing Personal Schedule: Tyler Reed'), findsOneWidget);
    expect(find.text('Back to All Team'), findsOneWidget);

    // 3. Switch back to All Team (Studio) master calendar
    await tester.tap(find.text('Back to All Team'));
    await tester.pumpAndSettle();

    expect(find.text('DAILY STAFF ROSTER'), findsOneWidget);
    expect(find.textContaining('Tyler Reed'), findsWidgets);

    // 4. Toggle Tyler to Off today using the Roster toggle
    final giveDayOffBtn = find.widgetWithText(OutlinedButton, 'Give Day Off');
    expect(giveDayOffBtn, findsWidgets);
    await tester.tap(giveDayOffBtn.last); // Tyler is the second member in staff roster
    await tester.pumpAndSettle();

    // Tyler is now off today; on duty count is 1 (the founder)
    expect(repository.isMemberOnDutyOnDate('tm_tyler', testDate, detailerId: repository.currentUser.id), isFalse);
    final testSlot = repository.getTimeSlotsForDate(testDate, detailerId: repository.currentUser.id).first;
    final statusWhenOneOff = repository.getSlotStaffingStatus(testDate, testSlot, detailerId: repository.currentUser.id);
    expect(statusWhenOneOff.onDutyCount, 1);
    expect(statusWhenOneOff.availableCapacity, 1);

    // 5. Book the slot: 1 booking uses up the sole on-duty tech's capacity
    final appt = BookingAppointment(
      id: 'appt_multi_test',
      clientId: 'usr_alex',
      clientName: 'Alex Rivera',
      detailerId: repository.currentUser.id,
      detailerName: repository.currentUser.displayName,
      detailerBusinessName: repository.currentUser.businessName,
      detailerAvatar: repository.currentUser.avatarUrl,
      clientPhone: '555-0199',
      clientEmail: 'alex@example.com',
      vehicleYearMakeModel: '2023 Porsche 911 GT3',
      vehicleSize: VehicleSize.coupeSedan,
      package: repository.currentUser.servicePackages.first,
      locationType: ServiceLocationType.shop,
      clientAddress: 'Detail Studio',
      scheduledDate: testDate,
      scheduledTimeSlot: testSlot,
      totalPrice: 280.0,
      depositAmount: 50.0,
      status: BookingStatus.confirmed,
    );
    repository.addBooking(appt);
    await tester.pumpAndSettle();

    final statusFull = repository.getSlotStaffingStatus(testDate, testSlot, detailerId: repository.currentUser.id);
    expect(statusFull.isFullyBooked, isTrue);

    // 6. Customer Perspective: verify slot is fully booked for customers
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: BookingFlowScreen(
        repository: repository,
        detailer: repository.currentUser,
        initialDate: testDate,
      ),
    ));
    await tester.pumpAndSettle();

    // Proceed to Step 1 (Vehicle & Schedule)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // In BookingFlowScreen, the slot is struck off / booked
    expect(find.text(testSlot), findsWidgets);
    expect(find.text('BOOKED'), findsWidgets);

    // 7. Put Tyler back on duty
    repository.toggleBlockDay(testDate, teamMemberId: 'tm_tyler', detailerId: repository.currentUser.id);
    final statusTwoTechs = repository.getSlotStaffingStatus(testDate, testSlot, detailerId: repository.currentUser.id);
    expect(statusTwoTechs.onDutyCount, 2);
    expect(statusTwoTechs.activeBookingsCount, 1);
    expect(statusTwoTechs.availableCapacity, 1);
    expect(statusTwoTechs.isFullyBooked, isFalse);

    // Customer can now book the slot because 2 techs - 1 booking = 1 capacity available
    expect(repository.isSlotConflictedByBooking(testDate, testSlot, detailerId: repository.currentUser.id), isFalse);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('ProfileScreen Become a Detailer button is placed directly below profile name and switches mode on single click', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    SharedPreferences.setMockInitialValues({});

    final repository = JobRepository();
    await repository.init();
    repository.isLoggedIn = true;

    // Test Case 1: Initial role is superAdmin (as with platform owner Gian Oporto)
    repository.updateCurrentUser(repository.currentUser.copyWith(
      role: UserRole.superAdmin,
      displayName: 'Gian Oporto',
      location: 'Austin, Texas',
      bio: 'Car enthusiast & detailing craft connoisseur.',
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: ProfileScreen(repository: repository),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Profile header shows profile name and 'Vehicle Owner' badge
    expect(find.text('Gian Oporto'), findsOneWidget);
    expect(find.text('Vehicle Owner'), findsOneWidget);

    // Verify 'Become a Detailer' button is present
    final becomeDetailerFinder = find.widgetWithText(ElevatedButton, 'Become a Detailer');
    expect(becomeDetailerFinder, findsOneWidget);

    // SINGLE TAP must immediately activate detailer mode
    await tester.tap(becomeDetailerFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // DetailerWorkbenchView is rendered immediately on the first tap!
    expect(repository.currentUser.role, UserRole.detailer);
    expect(find.byType(DetailerWorkbenchView), findsOneWidget);

    // Switch back to Client Mode
    final switchBackFinder = find.text('Switch to Client Mode');
    expect(switchBackFinder, findsOneWidget);
    await tester.tap(switchBackFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Back to Client Mode on single click
    expect(repository.currentUser.role, UserRole.client);
    expect(find.byType(DetailerWorkbenchView), findsNothing);
    expect(find.text('Become a Detailer'), findsOneWidget);

    // Test Case 2: From client role, single tap switches to detailer mode
    await tester.tap(find.widgetWithText(ElevatedButton, 'Become a Detailer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.currentUser.role, UserRole.detailer);
    expect(find.byType(DetailerWorkbenchView), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Detailer Workbench Calendar renders team member dropdown in Pane 2 & 3 and switches schedule view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    debugNetworkImageHttpClientProvider = () => _MockHttpClient();
    SharedPreferences.setMockInitialValues({});

    final repository = JobRepository();
    await repository.init();
    repository.isLoggedIn = true;
    repository.toggleHostMode(targetRole: UserRole.detailer);

    // Add team member so staff.length > 1
    const tech = TeamMember(
      id: 'tm_tyler',
      name: 'Tyler Reed',
      roleTitle: 'Lead Paint Correction Specialist',
      avatarUrl: 'https://example.com/tyler.jpg',
      rating: 4.9,
      completedJobsCount: 42,
    );
    repository.addTeamMember(tech);

    final testDate = DateTime(2026, 10, 20); // Tuesday

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: DetailerWorkbenchView(
          repository: repository,
          initialCalendarDate: testDate,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Navigate to Calendar in Pane 1
    await tester.tap(find.text('Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 2. Verify Team Dropdown is present in Pane 2 and Pane 3
    final dropdownPane2 = find.byKey(const Key('calendar_team_dropdown_pane2'));
    final dropdownPane3 = find.byKey(const Key('calendar_team_dropdown_pane3'));
    expect(dropdownPane2, findsOneWidget);
    expect(dropdownPane3, findsOneWidget);

    // Verify initially selected value is 'all' (All Team)
    expect(find.text('All Team (Entire Studio)'), findsWidgets);

    // 3. Tap Dropdown in Pane 2 to switch to Tyler Reed
    await tester.tap(dropdownPane2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tyler Reed option in the opened dropdown menu
    final tylerOption = find.text('Tyler Reed').last;
    await tester.tap(tylerOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Verify both Panes updated to Tyler Reed's personal schedule
    expect(find.textContaining('Viewing Personal Schedule: Tyler Reed'), findsOneWidget);

    // 5. Switch back to All Team from Pane 3 dropdown
    await tester.tap(dropdownPane3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final allTeamOption = find.text('All Team (Entire Studio)').last;
    await tester.tap(allTeamOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify master calendar restored
    expect(find.text('DAILY STAFF ROSTER'), findsOneWidget);

    debugNetworkImageHttpClientProvider = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}


