import 'package:detail_craft/screens/public_studio_screen.dart';
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

    print('Direct pump SliverAppBar count: ${find.byType(SliverAppBar).evaluate().length}');
    print('Direct pump TabBar count: ${find.byType(TabBar).evaluate().length}');
    print('Direct pump All texts in tree: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');

    expect(find.byType(PublicStudioScreen), findsOneWidget);
    expect(find.text('Transformations'), findsWidgets);
    expect(find.text('Services & Pricing'), findsOneWidget);
    expect(find.text('About & Studio'), findsOneWidget);
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
}
