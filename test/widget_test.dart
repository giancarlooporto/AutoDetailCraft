import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
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
import 'package:detail_craft/widgets/job_recipe_card.dart';
import 'package:detail_craft/screens/profile_screen.dart';

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
      subscriptionTier: SubscriptionTier.pro,
      servicePackages: [customPackage],
    );

    final json = profile.toJson();
    expect(json['startingPrice'], 350.0);
    expect(json['subscriptionTier'], 'pro');
    expect(json['servicePackages'], isList);
    expect((json['servicePackages'] as List).length, 1);

    final deserialized = UserProfile.fromJson(json);
    expect(deserialized.startingPrice, 350.0);
    expect(deserialized.subscriptionTier, SubscriptionTier.pro);
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
}

