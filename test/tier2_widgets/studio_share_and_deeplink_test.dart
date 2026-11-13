import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/widgets/studio_share_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile _makeStudio({
  String id = 'studio-qr-1',
  String businessName = 'Obsidian Auto Spa',
}) {
  return UserProfile(
    id: id,
    username: 'obsidian_auto_spa',
    displayName: 'Marcus Vance',
    businessName: businessName,
    role: UserRole.detailer,
    bio: 'Ceramic coating & paint correction specialists.',
    location: 'Scottsdale, AZ',
    isVerifiedHost: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'StudioShareDialog renders shareable URL, QR code, and copies link to Clipboard',
      (tester) async {
    final studio = _makeStudio();
    final expectedUrl = StudioShareDialog.buildStudioShareUrl(studio.id);
    expect(expectedUrl, 'https://www.autodetailcraft.com/?studio=studio-qr-1');

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  StudioShareDialog.show(context, detailer: studio),
              child: const Text('Open Share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Share'));
    await tester.pumpAndSettle();

    expect(find.byType(StudioShareDialog), findsOneWidget);
    expect(find.text('Obsidian Auto Spa'), findsOneWidget);
    expect(find.text('Your Detailing Website & Booking Link'), findsOneWidget);
    expect(find.text('Scan to Book & View Portfolio'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(expectedUrl), findsOneWidget);

    await tester.tap(find.text('Copy Website Link'));
    await tester.pumpAndSettle();

    expect(copiedText, expectedUrl);
    expect(find.text('Studio website link copied to clipboard'), findsOneWidget);
  });

  testWidgets('PublicStudioScreen Share button opens StudioShareDialog',
      (tester) async {
    final studio = _makeStudio();
    final repo = JobRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudioScreen(detailer: studio, repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    final shareButton = find.byIcon(Icons.share_outlined);
    expect(shareButton, findsOneWidget);

    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(find.byType(StudioShareDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets(
      'MainNavigationScreen with initialStudioId automatically opens PublicStudioScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = JobRepository();
    final targetId = repo.currentUser.id;

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          repository: repo,
          initialStudioId: targetId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicStudioScreen), findsOneWidget);
  });
}
