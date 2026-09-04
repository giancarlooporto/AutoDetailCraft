import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/main.dart';
import 'package:detail_craft/services/job_repository.dart';

void main() {
  testWidgets('AutoDetailCraft app loads feed and navigation bar correctly', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('HTTP request failed')) return;
      FlutterError.presentError(details);
    };

    final repository = JobRepository();
    await tester.pumpWidget(DetailCraftApp(repository: repository));

    expect(find.text('AutoDetailCraft'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Post (+)'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('My Studio'), findsOneWidget);
  });
}
