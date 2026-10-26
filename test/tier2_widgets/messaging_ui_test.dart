import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/message_model.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/chat_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/main_navigation_screen.dart';
import 'package:detail_craft/screens/messages_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
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

    testWidgets('Detailer message delivery: MessagesScreen displays client inquiries for detailer user', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_pro',
          role: UserRole.detailer,
          businessName: 'Apex Detail Studio',
        );
        await repo.loginUser(detailerUser);

        // Client inquiry sent to this detailer
        final inquiryConv = Conversation(
          id: 'conv_inquiry_client_1',
          participantA: 'usr_client_bob',
          participantB: detailerUser.id,
          updatedAt: DateTime.now(),
          otherUserName: 'Bob Customer',
          lastMessage: DirectMessage(
            id: 'msg_inquiry_1',
            conversationId: 'conv_inquiry_client_1',
            senderId: 'usr_client_bob',
            text: 'Can you detail my Porsche tomorrow?',
            createdAt: DateTime.now(),
          ),
          unreadCount: 1,
        );

        repo.conversations.add(inquiryConv);
        await LocalStorageService.saveConversations(repo.conversations);

        await tester.pumpWidget(
          MaterialApp(
            home: MessagesScreen(repository: repo),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // The detailer must see the incoming client inquiry
        expect(find.text('Bob Customer'), findsOneWidget);
        expect(find.text('Can you detail my Porsche tomorrow?'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('Detailer message delivery: DetailerWorkbenchView displays studio conversations with RefreshIndicator', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_pro_2',
          role: UserRole.detailer,
          businessName: 'Apex Detail Studio',
        );
        await repo.loginUser(detailerUser);

        final inquiryConv = Conversation(
          id: 'conv_inquiry_client_2',
          participantA: 'usr_client_carol',
          participantB: detailerUser.id,
          updatedAt: DateTime.now(),
          otherUserName: 'Carol Client',
          lastMessage: DirectMessage(
            id: 'msg_inquiry_2',
            conversationId: 'conv_inquiry_client_2',
            senderId: 'usr_client_carol',
            text: 'Requesting ceramic coating pricing',
            createdAt: DateTime.now(),
          ),
          unreadCount: 1,
        );

        repo.conversations.add(inquiryConv);
        await LocalStorageService.saveConversations(repo.conversations);
        await LocalStorageService.saveMessages(inquiryConv.id, [inquiryConv.lastMessage!]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DetailerWorkbenchView(repository: repo),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Select the Messages hub section in Pane 1
        final messagesHubFinder = find.widgetWithText(ListTile, 'Messages');
        expect(messagesHubFinder, findsOneWidget);
        await tester.tap(messagesHubFinder);
        await tester.pump();
        await tester.pumpAndSettle();

        // RefreshIndicator must be present
        expect(find.byType(RefreshIndicator), findsAtLeastNWidgets(1));

        // Customer conversation must be visible in the messages pane (found in conversation list and active chat view)
        expect(find.text('Carol Client'), findsAtLeastNWidgets(1));
        expect(find.text('Requesting ceramic coating pricing'), findsAtLeastNWidgets(1));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('MainNavigationScreen Tab 2 badge displays unread count for detailer with client inquiries', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_badge_test',
          role: UserRole.detailer,
          businessName: 'Apex Detail Studio',
        );
        await repo.loginUser(detailerUser);

        final inquiryConv = Conversation(
          id: 'conv_unread_test',
          participantA: 'usr_client_david',
          participantB: detailerUser.id,
          updatedAt: DateTime.now(),
          otherUserName: 'David Customer',
          unreadCount: 3,
        );

        repo.conversations.add(inquiryConv);
        await LocalStorageService.saveConversations(repo.conversations);

        await tester.pumpWidget(
          MaterialApp(
            home: MainNavigationScreen(repository: repo),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Expect badge showing 3 on Tab 2
        expect(find.text('3'), findsAtLeastNWidgets(1));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
