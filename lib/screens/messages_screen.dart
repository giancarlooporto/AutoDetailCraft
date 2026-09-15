import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/message_model.dart';
import '../services/job_repository.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  final JobRepository repository;
  const MessagesScreen({super.key, required this.repository});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.repository.loadConversations();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openChat(Conversation conv) async {
    final myId = widget.repository.currentUser.id;
    final otherId = conv.participantA == myId ? conv.participantB : conv.participantA;
    await ChatScreen.open(
      context,
      conversationId: conv.id,
      otherUserName: conv.otherUserName.isNotEmpty ? conv.otherUserName : 'User',
      otherUserAvatar: conv.otherUserAvatar,
      repository: widget.repository,
    );
    // Refresh on return to update unread badges
    widget.repository.loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final conversations = widget.repository.conversations;
        final isGuest = widget.repository.isGuestMode;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chat_rounded, color: AppTheme.primary, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Messages',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: isGuest
                        ? _buildGuestEmpty()
                        : _loading
                            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                            : conversations.isEmpty
                                ? _buildEmpty()
                                : RefreshIndicator(
                                    color: AppTheme.primary,
                                    onRefresh: _load,
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: conversations.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1, color: AppTheme.border),
                                      itemBuilder: (ctx, i) =>
                                          _buildConvTile(conversations[i]),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConvTile(Conversation conv) {
    final myId = widget.repository.currentUser.id;
    final lastMsg = conv.lastMessage;
    final isFromMe = lastMsg?.senderId == myId;
    final preview = lastMsg == null
        ? 'No messages yet'
        : '${isFromMe ? 'You: ' : ''}${lastMsg.text}';
    final timeLabel = lastMsg == null ? '' : _formatTime(lastMsg.createdAt);

    return InkWell(
      onTap: () => _openChat(conv),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: conv.otherUserAvatar.isNotEmpty
                      ? NetworkImage(conv.otherUserAvatar)
                      : null,
                  backgroundColor: AppTheme.surfaceLight,
                  child: conv.otherUserAvatar.isEmpty
                      ? const Icon(Icons.storefront_rounded, size: 26, color: AppTheme.textMuted)
                      : null,
                ),
                if (conv.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        conv.unreadCount > 9 ? '9+' : '${conv.unreadCount}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.otherUserName.isNotEmpty ? conv.otherUserName : 'Unknown User',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: conv.unreadCount > 0 ? AppTheme.primary : AppTheme.textMuted,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 13,
                      color: conv.unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: conv.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('No conversations yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Message a detailer from their Public Storefront to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Sign in to message detailers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Create a free account to chat with detailers before and after your booking.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (now.difference(local).inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(local).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    } else {
      return '${local.month}/${local.day}';
    }
  }
}
