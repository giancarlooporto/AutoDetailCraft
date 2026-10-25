import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/screens/chat_screen.dart';
import 'package:detail_craft/screens/messages_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Messaging UI & Deletion Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    testWidgets('ChatScreen sends message without duplication and displays delete button', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repo.isLoggedIn = false; // Test local/offline message flow without Supabase network
        final convId = await repo.openOrCreateConversation('usr_test_client');
        expect(convId, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              conversationId: convId!,
              otherUserName: 'Apex Auto Studio',
              otherUserAvatar: '',
              repository: repo,
              enablePolling: false,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Find input field and type message
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        await tester.enterText(textField, 'Testing no duplicates');
        final sendBtn = find.byIcon(Icons.send_rounded);
        expect(sendBtn, findsOneWidget);

        await tester.tap(sendBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Verify the message text appears exactly ONCE in the chat screen
        final textFinder = find.text('Testing no duplicates');
        expect(textFinder, findsOneWidget);

        // Long press the message bubble to trigger deletion
        await tester.longPress(textFinder);
        await tester.pumpAndSettle();

        // Verify Delete Message confirmation dialog appears
        expect(find.text('Delete Message?'), findsOneWidget);

        // Tap Delete in dialog
        final deleteActionBtn = find.widgetWithText(ElevatedButton, 'Delete');
        expect(deleteActionBtn, findsOneWidget);
        await tester.tap(deleteActionBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Verify message is gone
        expect(find.text('Testing no duplicates'), findsNothing);
        expect(find.text('No messages yet'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('MessagesScreen allows deleting a conversation with confirmation dialog', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        repo.isLoggedIn = true;
        final detailerId = repo.publicDetailers.isNotEmpty ? repo.publicDetailers.first.id : 'usr_detailer_01';
        final convId = await repo.openOrCreateConversation(detailerId);
        expect(convId, isNotNull);
        await repo.sendMessage(convId!, 'Hello from client');
        await repo.loadConversations();

        await tester.pumpWidget(
          MaterialApp(
            home: MessagesScreen(repository: repo),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Check conversation is listed
        expect(find.text('You: Hello from client'), findsOneWidget);

        // Swipe left to reveal iOS delete button
        await tester.drag(find.text('You: Hello from client'), const Offset(-200, 0));
        await tester.pumpAndSettle();

        // Find delete button on conversation tile
        final deleteBtn = find.byTooltip('Delete conversation');
        expect(deleteBtn, findsOneWidget);

        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Verify confirmation dialog
        expect(find.text('Delete Conversation?'), findsOneWidget);

        // Confirm delete
        final confirmBtn = find.widgetWithText(ElevatedButton, 'Delete');
        await tester.tap(confirmBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Conversation should now be deleted
        expect(find.text('You: Hello from client'), findsNothing);
        expect(find.text('No conversations yet'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
