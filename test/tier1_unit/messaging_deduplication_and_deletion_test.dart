import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/message_model.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Messaging Deduplication & Deletion Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('sendMessage creates message and updates conversation lastMessage', () async {
      final convId = await repo.openOrCreateConversation('usr_detailer_01');
      expect(convId, isNotNull);

      final msg = await repo.sendMessage(convId!, 'Hello from client');
      expect(msg, isNotNull);
      expect(msg!.text, 'Hello from client');

      final msgs = await repo.fetchMessages(convId);
      expect(msgs.length, 1);
      expect(msgs.first.text, 'Hello from client');

      final conv = repo.conversations.firstWhere((c) => c.id == convId);
      expect(conv.lastMessage?.text, 'Hello from client');
    });

    test('fetchMessages deduplicates local temporary message and confirmed remote message', () async {
      final convId = await repo.openOrCreateConversation('usr_detailer_02');
      expect(convId, isNotNull);

      final now = DateTime.now();

      // Simulate a local temporary message (id starts with msg_...)
      final localTemp = DirectMessage(
        id: 'msg_${now.millisecondsSinceEpoch}',
        conversationId: convId!,
        senderId: repo.currentUser.id,
        text: 'Hi there!',
        createdAt: now,
      );

      // Save to local storage
      await LocalStorageService.saveMessages(convId, [localTemp]);

      // Verify that fetchMessages with only local storage returns 1 message
      final msgsBefore = await repo.fetchMessages(convId);
      expect(msgsBefore.length, 1);
      expect(msgsBefore.first.id, localTemp.id);

      // Now simulate what happens if local has the temp message, but a remote message arrives
      // with identical text & sender from Supabase UUID
      final remoteConfirmed = DirectMessage(
        id: 'uuid-1234-5678-90ab',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Hi there!',
        createdAt: now.add(const Duration(milliseconds: 200)),
      );

      // Store both in local storage cache (as would happen during a race or sync)
      await LocalStorageService.saveMessages(convId, [localTemp, remoteConfirmed]);

      // fetchMessages should intelligently deduplicate and retain only the confirmed message
      final msgsAfter = await repo.fetchMessages(convId);
      expect(msgsAfter.length, 1);
      expect(msgsAfter.first.id, remoteConfirmed.id);
      expect(msgsAfter.first.text, 'Hi there!');
    });

    test('deleteMessage removes individual message and updates lastMessage', () async {
      final convId = await repo.openOrCreateConversation('usr_detailer_03');
      expect(convId, isNotNull);

      final msg1 = await repo.sendMessage(convId!, 'First message');
      final msg2 = await repo.sendMessage(convId, 'Second message');

      var msgs = await repo.fetchMessages(convId);
      expect(msgs.length, 2);
      expect(repo.conversations.firstWhere((c) => c.id == convId).lastMessage?.text, 'Second message');

      // Delete the second message
      final deleted = await repo.deleteMessage(convId, msg2!.id);
      expect(deleted, true);

      msgs = await repo.fetchMessages(convId);
      expect(msgs.length, 1);
      expect(msgs.first.id, msg1!.id);
      expect(repo.conversations.firstWhere((c) => c.id == convId).lastMessage?.text, 'First message');

      // Delete the first message
      final deleted1 = await repo.deleteMessage(convId, msg1.id);
      expect(deleted1, true);

      msgs = await repo.fetchMessages(convId);
      expect(msgs.isEmpty, true);
      expect(repo.conversations.firstWhere((c) => c.id == convId).lastMessage, isNull);
    });

    test('deleteConversation removes conversation and clears all messages', () async {
      final convId = await repo.openOrCreateConversation('usr_detailer_04');
      expect(convId, isNotNull);

      await repo.sendMessage(convId!, 'Message 1');
      await repo.sendMessage(convId, 'Message 2');

      expect(repo.conversations.any((c) => c.id == convId), true);
      var msgs = await repo.fetchMessages(convId);
      expect(msgs.length, 2);

      // Delete entire conversation
      final deleted = await repo.deleteConversation(convId);
      expect(deleted, true);

      expect(repo.conversations.any((c) => c.id == convId), false);
      final storedMsgs = await LocalStorageService.loadMessages(convId);
      expect(storedMsgs.isEmpty, true);
    });
  });
}
