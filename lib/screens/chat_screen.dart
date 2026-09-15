import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/message_model.dart';
import '../services/job_repository.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserAvatar;
  final JobRepository repository;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.repository,
  });

  static Future<void> open(
    BuildContext context, {
    required String conversationId,
    required String otherUserName,
    required String otherUserAvatar,
    required JobRepository repository,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: conversationId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        repository: repository,
      ),
    ));
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<DirectMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Poll every 5s as realtime fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(scroll: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool scroll = true}) async {
    final msgs = await widget.repository.fetchMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      if (scroll) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textController.clear();

    final msg = await widget.repository.sendMessage(widget.conversationId, text);
    if (msg != null && mounted) {
      setState(() {
        _messages.add(msg);
        _sending = false;
      });
      _scrollToBottom();
    } else {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.repository.currentUser.id;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserAvatar.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar)
                  : null,
              backgroundColor: AppTheme.surfaceLight,
              child: widget.otherUserAvatar.isEmpty
                  ? const Icon(Icons.person_rounded, size: 18, color: AppTheme.textMuted)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // Message list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMuted.withAlpha(80)),
                                const SizedBox(height: 12),
                                const Text('No messages yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                                const SizedBox(height: 6),
                                Text('Say hello to ${widget.otherUserName}!',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) {
                              final msg = _messages[i];
                              final isMine = msg.senderId == myId;
                              final showDate = i == 0 ||
                                  _messages[i].createdAt.day != _messages[i - 1].createdAt.day;
                              return Column(
                                children: [
                                  if (showDate) _buildDateDivider(msg.createdAt),
                                  _buildBubble(msg, isMine),
                                ],
                              );
                            },
                          ),
              ),

              // Input bar
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: const Border(top: BorderSide(color: AppTheme.border)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Message ${widget.otherUserName}…',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppTheme.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sending
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              ),
                            )
                          : IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(10),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              onPressed: _send,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime dt) {
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${dt.month}/${dt.day}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ]),
    );
  }

  Widget _buildBubble(DirectMessage msg, bool isMine) {
    final time =
        '${msg.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${msg.createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.black : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.black54 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
