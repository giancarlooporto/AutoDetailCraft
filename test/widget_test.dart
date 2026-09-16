import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/services/job_repository.dart';

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
}
