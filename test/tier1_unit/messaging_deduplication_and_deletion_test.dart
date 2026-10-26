import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/message_model.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/supabase_service.dart';

// ─── MOCK HTTP INFRASTRUCTURE FOR SUPABASE TESTING ──────────────────────────
typedef CloudResponseProvider = Map<String, dynamic> Function(Uri uri, String method);
CloudResponseProvider? _activeCloudProvider;

class MessagingMockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MessagingMockHttpClient();
  }
}

class _MessagingMockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MessagingMockHttpRequest(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
}

class _MessagingMockHttpRequest extends Fake implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;

  _MessagingMockHttpRequest(this.method, this.uri);

  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  @override
  void writeln([Object? obj = ""]) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future flush() async {}
  @override
  Future addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async {
    if (_activeCloudProvider != null) {
      final res = _activeCloudProvider!(uri, method);
      final body = res['body'];
      final statusCode = res['statusCode'] as int? ?? 200;
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      return _MessagingMockHttpResponse(statusCode, Uint8List.fromList(jsonBytes));
    }
    return _MessagingMockHttpResponse(200, Uint8List.fromList(utf8.encode('[]')));
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  String? value(String name) => _map[name.toLowerCase()]?.firstOrNull;
}

class _MessagingMockHttpResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final Uint8List bodyBytes;

  _MessagingMockHttpResponse(this.statusCode, this.bodyBytes);

  @override
  int get contentLength => bodyBytes.length;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => true;
  @override
  HttpHeaders get headers => _MockResponseHeaders();
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
    return Stream<List<int>>.value(bodyBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MockResponseHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers;

  _MockResponseHeaders([Map<String, List<String>>? headers])
      : _headers = headers ?? {
          'content-type': ['application/json; charset=utf-8'],
        };

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.firstOrNull;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = MessagingMockHttpOverrides();
    await SupabaseService.initialize();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    _activeCloudProvider = null;
  });

  group('Messaging Deduplication, Deletion & Authoritative Sync Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      _activeCloudProvider = null;
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

      final localTemp = DirectMessage(
        id: 'msg_${now.millisecondsSinceEpoch}',
        conversationId: convId!,
        senderId: repo.currentUser.id,
        text: 'Hi there!',
        createdAt: now,
      );

      await LocalStorageService.saveMessages(convId, [localTemp]);

      final msgsBefore = await repo.fetchMessages(convId);
      expect(msgsBefore.length, 1);
      expect(msgsBefore.first.id, localTemp.id);

      final remoteConfirmed = DirectMessage(
        id: 'uuid-1234-5678-90ab',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Hi there!',
        createdAt: now.add(const Duration(milliseconds: 200)),
      );

      await LocalStorageService.saveMessages(convId, [localTemp, remoteConfirmed]);

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

      final deleted = await repo.deleteMessage(convId, msg2!.id);
      expect(deleted, true);

      msgs = await repo.fetchMessages(convId);
      expect(msgs.length, 1);
      expect(msgs.first.id, msg1!.id);
      expect(repo.conversations.firstWhere((c) => c.id == convId).lastMessage?.text, 'First message');

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

      final deleted = await repo.deleteConversation(convId);
      expect(deleted, true);

      expect(repo.conversations.any((c) => c.id == convId), false);
      final storedMsgs = await LocalStorageService.loadMessages(convId);
      expect(storedMsgs.isEmpty, true);
    });

    test('Authoritative reconciliation prunes remotely deleted confirmed message and does NOT resurrect it', () async {
      repo.isLoggedIn = true;
      const convId = 'conv_auth_test_1';

      final msg1 = DirectMessage(
        id: 'uuid-confirmed-001',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Message 1 still alive',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final msg2DeletedRemotely = DirectMessage(
        id: 'uuid-confirmed-002',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Message 2 deleted on device A',
        createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
      );

      // Local storage on Device B initially holds both messages
      await LocalStorageService.saveMessages(convId, [msg1, msg2DeletedRemotely]);

      // Mock Supabase cloud returns ONLY msg1 (msg2 was deleted on Device A)
      _activeCloudProvider = (uri, method) {
        if (uri.path.contains('/rest/v1/messages')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': msg1.id,
                'conversation_id': convId,
                'sender_id': msg1.senderId,
                'text': msg1.text,
                'created_at': msg1.createdAt.toIso8601String(),
                'is_read': true,
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      // Device B fetches messages: authoritative reconciliation runs
      final reconciled = await repo.fetchMessages(convId);

      // Verifications:
      // 1. msg2DeletedRemotely is pruned
      expect(reconciled.length, 1);
      expect(reconciled.first.id, msg1.id);
      expect(reconciled.any((m) => m.id == msg2DeletedRemotely.id), false);

      // 2. Local storage is updated to prevent future resurrection
      final stored = await LocalStorageService.loadMessages(convId);
      expect(stored.length, 1);
      expect(stored.first.id, msg1.id);
    });

    test('Authoritative reconciliation preserves pending local temporary messages (msg_...)', () async {
      repo.isLoggedIn = true;
      const convId = 'conv_auth_test_2';

      final remoteMsg = DirectMessage(
        id: 'uuid-confirmed-100',
        conversationId: convId,
        senderId: 'usr_other',
        text: 'Confirmed from server',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      final localTempPending = DirectMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_local_draft',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Unconfirmed local draft',
        createdAt: DateTime.now(),
      );

      // Local storage holds both the confirmed remote message and the pending temp message
      await LocalStorageService.saveMessages(convId, [remoteMsg, localTempPending]);

      // Cloud response only has the remote message
      _activeCloudProvider = (uri, method) {
        if (uri.path.contains('/rest/v1/messages')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': remoteMsg.id,
                'conversation_id': convId,
                'sender_id': remoteMsg.senderId,
                'text': remoteMsg.text,
                'created_at': remoteMsg.createdAt.toIso8601String(),
                'is_read': true,
              }
            ],
          };
        }
        return {'statusCode': 200, 'body': []};
      };

      final reconciled = await repo.fetchMessages(convId);

      // Both the remote confirmed message and the pending temp message should be retained
      expect(reconciled.length, 2);
      expect(reconciled.any((m) => m.id == remoteMsg.id), true);
      expect(reconciled.any((m) => m.id == localTempPending.id), true);
    });

    test('Network failure preserves local storage messages as offline fallback', () async {
      repo.isLoggedIn = true;
      const convId = 'conv_offline_fallback';

      final cachedMsg = DirectMessage(
        id: 'uuid-cached-999',
        conversationId: convId,
        senderId: repo.currentUser.id,
        text: 'Cached offline message',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      await LocalStorageService.saveMessages(convId, [cachedMsg]);

      // Cloud failure (500 internal server error)
      _activeCloudProvider = (uri, method) {
        return {'statusCode': 500, 'body': {'message': 'Network error'}};
      };

      final result = await repo.fetchMessages(convId);

      // Offline cache should NOT be erased
      expect(result.length, 1);
      expect(result.first.id, cachedMsg.id);
      expect(result.first.text, 'Cached offline message');
    });

    test('logoutUser resets in-memory conversations and clears LocalStorageService', () async {
      const convId = 'conv_logout_test';
      final testConv = Conversation(
        id: convId,
        participantA: repo.currentUser.id,
        participantB: 'usr_detailer_test',
        updatedAt: DateTime.now(),
        otherUserName: 'Test Shop',
      );

      repo.conversations.add(testConv);
      await LocalStorageService.saveConversations(repo.conversations);

      expect(repo.conversations.isNotEmpty, true);
      final storedBefore = await LocalStorageService.loadConversations();
      expect(storedBefore.isNotEmpty, true);

      // Perform logout
      await repo.logoutUser();

      // Conversations must be completely cleared to prevent session leak
      expect(repo.conversations.isEmpty, true);
      final storedAfter = await LocalStorageService.loadConversations();
      expect(storedAfter.isEmpty, true);
    });

    test('Detailer role distinguishes studioConversations from clientConversations and computes totalUnreadMessages', () async {
      // Configure detailer user
      final detailerUser = repo.currentUser.copyWith(
        id: 'usr_detailer_main',
        role: UserRole.detailer,
        businessName: 'Main Studio',
      );
      await repo.loginUser(detailerUser);

      // 1. Client inquiry sent to this detailer (otherId is client 'usr_client_01', not in publicDetailers)
      final clientInquiryConv = Conversation(
        id: 'conv_inquiry_01',
        participantA: 'usr_client_01',
        participantB: detailerUser.id,
        updatedAt: DateTime.now(),
        otherUserName: 'Alice Client',
        unreadCount: 2,
      );

      final otherDetailer = UserProfile(
        id: 'usr_detailer_other',
        username: 'other_detailer',
        displayName: 'Other Detailer',
        role: UserRole.detailer,
        businessName: 'Other Studio',
      );
      repo.setPublicDetailersForTesting([otherDetailer]);
      final otherDetailerId = otherDetailer.id;
      final detailerToDetailerConv = Conversation(
        id: 'conv_b2b_01',
        participantA: detailerUser.id,
        participantB: otherDetailerId,
        updatedAt: DateTime.now(),
        otherUserName: 'Other Shop',
        unreadCount: 1,
      );

      repo.conversations.addAll([clientInquiryConv, detailerToDetailerConv]);

      // Studio conversations should strictly contain client inquiries
      expect(repo.studioConversations.length, 1);
      expect(repo.studioConversations.first.id, clientInquiryConv.id);
      expect(repo.studioUnreadMessages, 2);

      // Client conversations should contain the conversation with other detailers
      expect(repo.clientConversations.length, 1);
      expect(repo.clientConversations.first.id, detailerToDetailerConv.id);
      expect(repo.clientUnreadMessages, 1);

      // Total conversations contains both
      expect(repo.conversations.length, 2);
      expect(repo.totalUnreadMessages, 3);
    });

    test('resolveConversationId maps draft ID to existing canonical server conversation', () async {
      final canonicalConv = Conversation(
        id: 'uuid-server-conv-007',
        participantA: repo.currentUser.id,
        participantB: 'usr_detailer_target',
        updatedAt: DateTime.now(),
        otherUserName: 'Target Studio',
      );
      repo.conversations.add(canonicalConv);

      // Direct match
      expect(repo.resolveConversationId('uuid-server-conv-007'), 'uuid-server-conv-007');

      // Forward participant draft ID match
      final draftId1 = 'conv_${repo.currentUser.id}_usr_detailer_target';
      expect(repo.resolveConversationId(draftId1), 'uuid-server-conv-007');

      // Reverse participant draft ID match
      final draftId2 = 'conv_usr_detailer_target_${repo.currentUser.id}';
      expect(repo.resolveConversationId(draftId2), 'uuid-server-conv-007');

      // Unmatched ID returns as-is
      expect(repo.resolveConversationId('conv_unknown_user_123'), 'conv_unknown_user_123');
    });

    test('openOrCreateConversation reuses existing conversation between participants instead of duplicating', () async {
      final existingConv = Conversation(
        id: 'uuid-server-conv-existing',
        participantA: 'usr_detailer_existing',
        participantB: repo.currentUser.id,
        updatedAt: DateTime.now(),
        otherUserName: 'Existing Studio',
      );
      repo.conversations.add(existingConv);

      final returnedId = await repo.openOrCreateConversation('usr_detailer_existing');
      expect(returnedId, 'uuid-server-conv-existing');
      expect(repo.conversations.where((c) => c.otherUserName == 'Existing Studio').length, 1);
    });

    test('loadConversations deduplicates participant pairs and merges local draft messages into cloud conversation', () async {
      repo.isLoggedIn = true;
      const targetUserId = 'usr_detailer_sync';
      const cloudConvId = 'uuid-cloud-conv-sync';
      final draftConvId = 'conv_${repo.currentUser.id}_$targetUserId';

      // Local storage has an un-synced draft conversation and a local message
      final draftConv = Conversation(
        id: draftConvId,
        participantA: repo.currentUser.id,
        participantB: targetUserId,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        otherUserName: 'Sync Studio',
      );
      final draftMsg = DirectMessage(
        id: 'msg_temp_sync_draft',
        conversationId: draftConvId,
        senderId: repo.currentUser.id,
        text: 'Sent while offline',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      repo.conversations.add(draftConv);
      await LocalStorageService.saveConversations(repo.conversations);
      await LocalStorageService.saveMessages(draftConvId, [draftMsg]);

      // Cloud response returns the canonical conversation between these participants
      _activeCloudProvider = (uri, method) {
        if (uri.path.contains('/rest/v1/conversations')) {
          return {
            'statusCode': 200,
            'body': [
              {
                'id': cloudConvId,
                'participant_a': targetUserId,
                'participant_b': repo.currentUser.id,
                'updated_at': DateTime.now().toIso8601String(),
              }
            ],
          };
        }
        if (uri.path.contains('/rest/v1/profiles')) {
          return {
            'statusCode': 200,
            'body': {
              'display_name': 'Sync Studio Master',
              'business_name': 'Sync Studio Pro',
              'avatar_url': 'https://example.com/avatar.jpg',
            },
          };
        }
        if (uri.path.contains('/rest/v1/messages')) {
          return {'statusCode': 200, 'body': []};
        }
        return {'statusCode': 200, 'body': []};
      };

      await repo.loadConversations();

      // Only 1 conversation should exist (no duplicate draft Conv alongside cloud Conv)
      expect(repo.conversations.length, 1);
      expect(repo.conversations.first.id, cloudConvId);

      // Draft messages must be migrated into cloudConvId local cache
      final migratedMsgs = await LocalStorageService.loadMessages(cloudConvId);
      expect(migratedMsgs.length, 1);
      expect(migratedMsgs.first.id, draftMsg.id);
      expect(migratedMsgs.first.conversationId, cloudConvId);

      // Old draft key storage must be cleared
      final oldDraftStorage = await LocalStorageService.loadMessages(draftConvId);
      expect(oldDraftStorage.isEmpty, true);
    });

    test('fetchMessages queried with local draft ID resolves to cloud UUID and does not prune messages', () async {
      repo.isLoggedIn = true;
      const targetUserId = 'usr_detailer_safe';
      const cloudConvId = 'uuid-cloud-conv-safe';
      final draftConvId = 'conv_${repo.currentUser.id}_$targetUserId';

      final canonicalConv = Conversation(
        id: cloudConvId,
        participantA: repo.currentUser.id,
        participantB: targetUserId,
        updatedAt: DateTime.now(),
        otherUserName: 'Safe Studio',
      );
      repo.conversations.add(canonicalConv);

      final cloudMsg = DirectMessage(
        id: 'uuid-server-msg-safe',
        conversationId: cloudConvId,
        senderId: repo.currentUser.id,
        text: 'Synced to cloud',
        createdAt: DateTime.now(),
      );

      _activeCloudProvider = (uri, method) {
        if (uri.path.contains('/rest/v1/messages')) {
          // Cloud query matches on canonical cloudConvId
          if (uri.query.contains(cloudConvId)) {
            return {
              'statusCode': 200,
              'body': [
                {
                  'id': cloudMsg.id,
                  'conversation_id': cloudConvId,
                  'sender_id': cloudMsg.senderId,
                  'text': cloudMsg.text,
                  'created_at': cloudMsg.createdAt.toIso8601String(),
                  'is_read': true,
                }
              ],
            };
          }
        }
        return {'statusCode': 200, 'body': []};
      };

      // Caller invokes fetchMessages using the legacy/draft ID
      final msgs = await repo.fetchMessages(draftConvId);

      // Must resolve canonical ID, fetch the cloud message, and not wipe it
      expect(msgs.length, 1);
      expect(msgs.first.id, cloudMsg.id);
      expect(msgs.first.text, 'Synced to cloud');
    });
  });
}
