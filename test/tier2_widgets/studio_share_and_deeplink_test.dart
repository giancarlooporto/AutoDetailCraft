import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/edit_profile_dialog.dart';
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
      'StudioShareDialog renders @handle URL, QR code, downloads PNG, and copies link to Clipboard',
      (tester) async {
    final studio = _makeStudio();
    final expectedUrl = StudioShareDialog.buildStudioUrl(studio);
    expect(expectedUrl, 'https://www.autodetailcraft.com/@obsidian_auto_spa');

    Uint8List? downloadedBytes;
    String? downloadedFileName;

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
              onPressed: () => StudioShareDialog.show(
                context,
                detailer: studio,
                onDownloadQr: (bytes, fileName) async {
                  downloadedBytes = bytes;
                  downloadedFileName = fileName;
                },
              ),
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
    expect(find.text('Download QR Code (PNG)'), findsOneWidget);
    expect(
      find.text('Print for your van, shop counter, or business cards'),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Download QR Code (PNG)'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(downloadedBytes, isNotNull);
    expect(downloadedBytes!.isNotEmpty, isTrue);
    expect(downloadedFileName, 'autodetailcraft-obsidian_auto_spa-qr.png');
    expect(find.text('QR code PNG downloaded'), findsOneWidget);

    await tester.ensureVisible(find.text('Copy Website Link'));
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

  testWidgets(
      'MainNavigationScreen with initialStudioHandle resolves /@handle to PublicStudioScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    expect(
      MainNavigationScreen.extractHandleFromPath('/@obsidian_auto_spa/'),
      'obsidian_auto_spa',
    );
    expect(
      MainNavigationScreen.extractHandleFromPath('/explore'),
      isNull,
    );

    final repo = JobRepository();
    final targetHandle = repo.currentUser.handle;

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          repository: repo,
          initialStudioHandle: targetHandle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicStudioScreen), findsOneWidget);
  });

  testWidgets(
      'EditProfileDialog validates, saves unique @handle, and rejects duplicates',
      (tester) async {
    final repo = JobRepository();
    // Ensure currentUser is a detailer so the handle field is shown
    repo.updateCurrentUser(
      repo.currentUser.copyWith(role: UserRole.detailer),
    );
    final otherStudio = _makeStudio(
      id: 'other-studio-1',
      businessName: 'Taken Studio',
    );
    repo.setPublicDetailersForTesting([otherStudio]);
    final existingOtherHandle = otherStudio.handle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EditProfileDialog.show(
                context,
                repository: repo,
                isStudioProfile: true,
              ),
              child: const Text('Edit Profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    final handleField = find.widgetWithText(
      TextFormField,
      'Unique Website Handle (@username)',
    );
    expect(handleField, findsOneWidget);

    // Try duplicate handle
    await tester.enterText(handleField, existingOtherHandle);
    await tester.pump();
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    expect(
      find.text('That handle is already taken. Please choose another.'),
      findsOneWidget,
    );

    // Enter a unique handle and save
    await tester.enterText(handleField, 'apex_clean_studio');
    await tester.pump();
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    expect(repo.currentUser.username, 'apex_clean_studio');
    expect(repo.currentUser.handle, 'apex_clean_studio');
  });
}
