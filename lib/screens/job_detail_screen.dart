import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';
import '../widgets/paint_hardness_badge.dart';
import '../widgets/split_slider_widget.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../services/job_repository.dart';
import 'chat_screen.dart';
import 'auth_modal.dart';
import 'public_studio_screen.dart';
import 'booking_flow_screen.dart';
import 'create_job_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final DetailJob job;
  final JobRepository? repository;
  final int initialTabIndex;
  final VoidCallback? onJobChanged;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.repository,
    this.initialTabIndex = 0,
    this.onJobChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required DetailJob job,
    JobRepository? repository,
    int initialTabIndex = 0,
    VoidCallback? onJobChanged,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          job: job,
          repository: repository,
          initialTabIndex: initialTabIndex,
          onJobChanged: onJobChanged,
        ),
      ),
    );
  }

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  JobComment? _replyingToComment;
  late DetailJob _currentJob;
  late int _selectedTabIndex;
  bool _messagingLoading = false;
  final Set<int> _expandedStageSpecs = {};
  bool _sortByNewest = true;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    _selectedTabIndex = widget.initialTabIndex;
    widget.repository?.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    final repo = widget.repository;
    if (repo == null || !mounted) return;
    final updated = repo.jobs.cast<DetailJob?>().firstWhere(
      (j) => j?.id == _currentJob.id,
      orElse: () => null,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentJob = updated;
      });
    }
  }

  @override
  void didUpdateWidget(JobDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_onRepositoryChanged);
      widget.repository?.addListener(_onRepositoryChanged);
    }
    if (oldWidget.job != widget.job) {
      _currentJob = widget.job;
      if (oldWidget.job.id != widget.job.id) {
        _expandedStageSpecs.clear();
      } else {
        _expandedStageSpecs.removeWhere((idx) => idx >= _currentJob.recipeStages.length);
      }
    }
  }

  bool get _isOwner {
    final repo = widget.repository;
    if (repo == null || repo.isGuestMode) return false;
    return _currentJob.detailerId == repo.currentUser.id;
  }

  void _openEditRecipe() {
    final repo = widget.repository;
    if (repo == null) return;
    CreateJobScreen.show(
      context,
      repository: repo,
      jobToEdit: _currentJob,
      onJobCreated: () {
        final updatedJob = repo.jobs.cast<DetailJob?>().firstWhere(
          (j) => j?.id == _currentJob.id,
          orElse: () => null,
        );
        if (updatedJob != null && mounted) {
          setState(() {
            _currentJob = updatedJob;
            _expandedStageSpecs.removeWhere((idx) => idx >= _currentJob.recipeStages.length);
          });
        }
        widget.onJobChanged?.call();
      },
    );
  }

  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Recipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this detailing recipe? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.repository?.deleteJob(_currentJob.id);
      widget.onJobChanged?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.repository?.removeListener(_onRepositoryChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _setReplyTo(JobComment comment) {
    setState(() {
      _replyingToComment = comment;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
    });
  }

  Future<void> _messageDetailer() async {
    final repo = widget.repository;
    if (repo == null) return;
    if (repo.isGuestMode) {
      AuthModal.show(context, repository: repo, onSuccess: () {
        if (mounted) _messageDetailer();
      });
      return;
    }
    setState(() => _messagingLoading = true);
    final convId = await repo.openOrCreateConversation(widget.job.author.id);
    if (!mounted) return;
    setState(() => _messagingLoading = false);

    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open conversation. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final otherUserName = widget.job.author.businessName.isNotEmpty
        ? widget.job.author.businessName
        : widget.job.author.displayName;
    final otherUserAvatar = widget.job.author.avatarUrl;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: convId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        repository: repo,
      ),
    ));
  }

  void _openPublicStudio() {
    if (widget.repository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicStudioScreen(
          detailer: _currentJob.author,
          repository: widget.repository!,
        ),
      ),
    );
  }

  void _openBookingFlow() {
    if (widget.repository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          detailer: _currentJob.author,
          repository: widget.repository!,
        ),
      ),
    );
  }

  void _toggleLike() {
    final repo = widget.repository;
    if (repo == null) return;
    if (repo.isGuestMode) {
      AuthModal.show(context, repository: repo, onSuccess: () {
        if (mounted) _toggleLike();
      });
      return;
    }
    repo.toggleLike(_currentJob.id);
    final updated = repo.jobs.cast<DetailJob?>().firstWhere(
      (j) => j?.id == _currentJob.id,
      orElse: () => null,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentJob = updated;
      });
    }
    widget.onJobChanged?.call();
  }

  void _toggleSave() {
    final repo = widget.repository;
    if (repo == null) return;
    if (repo.isGuestMode) {
      AuthModal.show(context, repository: repo, onSuccess: () {
        if (mounted) _toggleSave();
      });
      return;
    }
    repo.toggleSave(_currentJob.id);
    final updated = repo.jobs.cast<DetailJob?>().firstWhere(
      (j) => j?.id == _currentJob.id,
      orElse: () => null,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentJob = updated;
      });
    }
    widget.onJobChanged?.call();
  }

  Future<void> _handleAddComment() async {
    final repo = widget.repository;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (repo != null && repo.isGuestMode) {
      AuthModal.show(context, repository: repo, onSuccess: () {
        if (mounted) _handleAddComment();
      });
      return;
    }

    final user = repo?.currentUser;
    final authorName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Anonymous';
    final parentId = _replyingToComment?.parentId ?? _replyingToComment?.id;
    final replyToName = _replyingToComment != null ? '@${_replyingToComment!.authorName}' : null;

    final newComment = JobComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      authorAvatar: user?.avatarUrl ?? '',
      text: text,
      createdAt: DateTime.now(),
      isVerifiedPro: user?.isIdaCertified ?? false,
      parentId: parentId,
      replyToAuthorName: replyToName,
    );

    setState(() {
      _currentJob = _currentJob.copyWith(
        comments: [..._currentJob.comments, newComment],
      );
      _commentController.clear();
      _replyingToComment = null;
    });

    // Persist comment to Supabase
    repo?.addComment(_currentJob.id, newComment);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(replyToName != null ? 'Reply posted to $replyToName!' : 'Comment posted to discussion thread!'),
          backgroundColor: AppTheme.surfaceLight,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }





  void _showExportSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.share_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Client Inspection Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital inspection link generated for client review:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'https://detailcraft.app/report/${_currentJob.id}',
                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Clients can view before/after 50/50 slider, all inspection container photos, and coating warranty info without logging in.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client link copied to clipboard!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGalleryStrip({
    required List<String> beforePhotos,
    required List<String> afterPhotos,
  }) {
    if (beforePhotos.isEmpty && afterPhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Inspection Gallery',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                '•  Tap thumbnail for full HD zoom',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withAlpha(200)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Before Photos Section
                if (beforePhotos.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.hardnessSoft.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.hardnessSoft.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 11, color: AppTheme.hardnessSoft),
                        const SizedBox(width: 4),
                        Text(
                          'BEFORE (${beforePhotos.length})',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.hardnessSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...beforePhotos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final url = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => FullscreenImageViewer.open(
                          context,
                          images: beforePhotos,
                          initialIndex: idx,
                          title: 'Before Inspection (${idx + 1}/${beforePhotos.length})',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.hardnessSoft.withAlpha(120), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6.5),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.broken_image_rounded, size: 18, color: AppTheme.textMuted),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(200),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                // Divider if both exist
                if (beforePhotos.isNotEmpty && afterPhotos.isNotEmpty) ...[
                  Container(
                    height: 38,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: AppTheme.border.withAlpha(180),
                  ),
                  const SizedBox(width: 6),
                ],

                // After Photos Section
                if (afterPhotos.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withAlpha(80)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 11, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          'AFTER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...afterPhotos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final url = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => FullscreenImageViewer.open(
                          context,
                          images: afterPhotos,
                          initialIndex: idx,
                          title: 'After Transformation (${idx + 1}/${afterPhotos.length})',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withAlpha(120), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6.5),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.broken_image_rounded, size: 18, color: AppTheme.textMuted),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(200),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildRecipeField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white))),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      return '${(diff.inDays / 7).floor()}w';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m';
    } else {
      return 'just now';
    }
  }

  List<Widget> _buildThreadedComments() {
    final rootComments = _currentJob.comments.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
    final allReplies = _currentJob.comments.where((c) => c.parentId != null && c.parentId!.isNotEmpty).toList();

    // Map reply counts for Top sorting
    final Map<String, int> replyCounts = {};
    for (final r in allReplies) {
      if (r.parentId != null) {
        replyCounts[r.parentId!] = (replyCounts[r.parentId!] ?? 0) + 1;
      }
    }

    if (_sortByNewest) {
      // Newest discussion thread at top
      rootComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      // Top active discussions: most replies first, then verified pro comments, then newest
      rootComments.sort((a, b) {
        final aReplies = replyCounts[a.id] ?? 0;
        final bReplies = replyCounts[b.id] ?? 0;
        if (aReplies != bReplies) return bReplies.compareTo(aReplies);
        if (a.isVerifiedPro != b.isVerifiedPro) return a.isVerifiedPro ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    final List<Widget> items = [];

    for (final root in rootComments) {
      // Replies are always sequential (oldest first) so conversation flows naturally
      final childReplies = allReplies.where((r) => r.parentId == root.id).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommentCard(root, isReply: false),
              if (childReplies.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.border.withAlpha(140),
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(
                      children: childReplies.map((reply) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildCommentCard(reply, isReply: true),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final rootIds = rootComments.map((r) => r.id).toSet();
    final orphanReplies = allReplies.where((r) => !rootIds.contains(r.parentId)).toList();
    for (final orphan in orphanReplies) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCommentCard(orphan, isReply: false),
        ),
      );
    }

    return items;
  }

  Widget _buildCommentCard(JobComment c, {required bool isReply}) {
    final isSelectedForReply = _replyingToComment?.id == c.id;
    final isJobCreator = c.authorName == _currentJob.author.displayName ||
        c.authorName == _currentJob.author.businessName;

    return Container(
      padding: EdgeInsets.all(isReply ? 10 : 12),
      decoration: BoxDecoration(
        color: isReply ? AppTheme.surface.withAlpha(160) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelectedForReply ? AppTheme.primary : AppTheme.border,
          width: isSelectedForReply ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 16,
                backgroundColor: AppTheme.surfaceLight,
                backgroundImage: c.authorAvatar.isNotEmpty ? NetworkImage(c.authorAvatar) : null,
                onBackgroundImageError: c.authorAvatar.isNotEmpty ? (_, _) {} : null,
                child: Text(
                  c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: isReply ? 10 : 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.authorName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isReply ? 12 : 13,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isJobCreator) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(40),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.primary.withAlpha(120), width: 0.8),
                            ),
                            child: const Text(
                              'AUTHOR',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.primary),
                            ),
                          ),
                        ],
                        if (c.isVerifiedPro) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 13, color: AppTheme.primary),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '• ${_formatCommentTime(c.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    if (c.replyToAuthorName != null && c.replyToAuthorName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Replying to ${c.replyToAuthorName}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      c.text,
                      style: TextStyle(fontSize: isReply ? 12 : 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _setReplyTo(c),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 13,
                        color: isSelectedForReply ? AppTheme.primary : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelectedForReply ? AppTheme.primary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beforeList = _currentJob.allBeforePhotos;
    final afterList = _currentJob.allAfterPhotos;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentJob.vehicleFullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Transformation Recipe & Inspection Details',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_isOwner) ...[
            PopupMenuButton<String>(
              key: const Key('recipe_overflow_menu'),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              onSelected: (val) {
                if (val == 'edit') {
                  _openEditRecipe();
                } else if (val == 'delete') {
                  _showDeleteConfirmDialog();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Text('Edit Recipe', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text('Delete Recipe', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border.withAlpha(120)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Strictly ONE Single 50/50 Comparative Hero Slider with true resolution containment
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SplitSliderWidget(
                          beforeImageUrl: _currentJob.beforeImageUrl,
                          afterImageUrl: _currentJob.afterImageUrl,
                          defectBadge: _currentJob.defectBadge,
                          height: 420,
                          fit: BoxFit.contain,
                          zoomScale: 1.18,
                        ),
                      ),
                      const SizedBox(height: 16),

            // 2. Compact Amazon-Style Photo Gallery Strip (Before & After Thumbnails)
            if (beforeList.isNotEmpty || afterList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPhotoGalleryStrip(
                  beforePhotos: beforeList,
                  afterPhotos: afterList,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Vehicle & Author Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _openPublicStudio,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.surfaceLight,
                              backgroundImage: _currentJob.author.avatarUrl.isNotEmpty ? NetworkImage(_currentJob.author.avatarUrl) : null,
                              onBackgroundImageError: _currentJob.author.avatarUrl.isNotEmpty ? (_, _) {} : null,
                              child: Text(_currentJob.author.displayName.isNotEmpty ? _currentJob.author.displayName[0].toUpperCase() : '?'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _currentJob.author.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (_currentJob.author.isIdaCertified) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 14),
                                      ],
                                      const Spacer(),
                                      const Text(
                                        'Studio →',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_currentJob.author.businessName} • ${_currentJob.author.location}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentJob.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentJob.description,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Segmented Tabs Bar: Specs & Recipe vs Discussion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const Key('specs_tab_button'),
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 0 ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: _selectedTabIndex == 0 ? Colors.black : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Job Specs & Recipe',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 0 ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        key: const Key('discussion_tab_button'),
                        onTap: () => setState(() => _selectedTabIndex = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 1 ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 16,
                                color: _selectedTabIndex == 1 ? Colors.black : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Discussion (${_currentJob.comments.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 1 ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_selectedTabIndex == 0) ...[
              // 4. Technical Inspection & Gauge Metrics
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Paint Inspection & Gauge Data',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Paint Specs Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Vehicle:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text(_currentJob.vehicleFullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Paint Code & Color:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text('${_currentJob.paintColorName} (${_currentJob.paintCode})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Paint Hardness:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          PaintHardnessBadge(hardness: _currentJob.paintHardness, isCompact: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Defect Stage:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text(_currentJob.defectStage.label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.hardnessSoft, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Correction Achieved:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Text('${_currentJob.correctionPercentage}% Correction', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13)),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),

                      // Depth Comparison Grid
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGaugeMetric('Initial Depth', '${_currentJob.initialPaintThicknessMicrons} µm', Icons.speed_rounded, AppTheme.textSecondary),
                          _buildGaugeMetric('Final Depth', '${_currentJob.finalPaintThicknessMicrons} µm', Icons.check_circle_outline, AppTheme.primary),
                          Builder(
                            builder: (context) {
                              final formatted = _currentJob.micronsRemoved.toStringAsFixed(1);
                              final numVal = double.tryParse(formatted) ?? 0.0;
                              return _buildGaugeMetric(
                                'Clear Removed',
                                numVal == 0.0 ? '0.0 µm' : '-$formatted µm',
                                Icons.layers_clear_outlined,
                                AppTheme.hardnessHard,
                              );
                            },
                          ),
                          _buildGaugeMetric('Total Time', '${_currentJob.durationHours} hrs', Icons.timer_outlined, Colors.amberAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Step-by-Step Detailing Recipe
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science_outlined, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Step-by-Step Process Recipe',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_currentJob.recipeStages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No specific recipe stages logged for this transformation.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      )
                    else
                      Column(
                        children: _currentJob.recipeStages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final stage = entry.value;
                        final isExpanded = _expandedStageSpecs.contains(idx);
                        final hasSpecs = stage.machine.isNotEmpty ||
                            stage.pad.isNotEmpty ||
                            stage.technique.isNotEmpty ||
                            (stage.notes != null && stage.notes!.isNotEmpty);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Green checked circle
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676).withAlpha(28),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Color(0xFF00E676),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'STAGE ${idx + 1}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primary,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          stage.stageName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Pro completion status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676).withAlpha(22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00E676).withAlpha(80)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified_rounded, size: 12, color: Color(0xFF00E676)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00E676),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (stage.chemical.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.science_rounded, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Product: ',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                    ),
                                    Expanded(
                                      child: Text(
                                        stage.chemical,
                                        style: const TextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                    ),
                                    if (stage.dilution != null && stage.dilution!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceLight,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          stage.dilution!,
                                          style: const TextStyle(fontSize: 10.5, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (hasSpecs) ...[
                                const SizedBox(height: 10),
                                InkWell(
                                  key: Key('craft_specs_toggle_$idx'),
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedStageSpecs.remove(idx);
                                      } else {
                                        _expandedStageSpecs.add(idx);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isExpanded ? Icons.tune_rounded : Icons.build_outlined,
                                          size: 13,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          'Detailer Craft Specs',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppTheme.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.border.withAlpha(150)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (stage.machine.isNotEmpty)
                                          _buildRecipeField('Machine', stage.machine, Icons.build_rounded),
                                        if (stage.pad.isNotEmpty)
                                          _buildRecipeField('Pad', stage.pad, Icons.circle_outlined),
                                        if (stage.technique.isNotEmpty)
                                          _buildRecipeField('Technique / Passes', stage.technique, Icons.tune_rounded),
                                        if (stage.notes != null && stage.notes!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Pro Note: ${stage.notes}',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AppTheme.textMuted,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Digital Inspection & Warranty Report Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Digital Inspection & Warranty Report',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Verified paint thickness readings and ceramic coating warranty documentation for client handover.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showExportSuccess,
                        icon: const Icon(Icons.share_outlined, size: 16, color: AppTheme.primary),
                        label: const Text('Share', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 6. Verified Pro Comments & Community Discussion
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.forum_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Discussion (${_currentJob.comments.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        // Discussion Sort Hierarchy Selector (Social media pattern: Newest vs Top)
                        if (_currentJob.comments.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<bool>(
                                value: _sortByNewest,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primary),
                                isDense: true,
                                dropdownColor: AppTheme.surface,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Row(
                                      children: [
                                        Icon(Icons.schedule_rounded, size: 13, color: AppTheme.primary),
                                        SizedBox(width: 5),
                                        Text('Newest First'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Row(
                                      children: [
                                        Icon(Icons.trending_up_rounded, size: 13, color: AppTheme.primary),
                                        SizedBox(width: 5),
                                        Text('Top Threads'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _sortByNewest = val);
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Active Replying-To Banner (Twitter-style)
                    if (_replyingToComment != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 15, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to @${_replyingToComment!.authorName}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: _cancelReply,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Comment Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: _replyingToComment != null
                                  ? 'Write a reply to @${_replyingToComment!.authorName}...'
                                  : 'Ask about compound, pad, or flash time...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _handleAddComment,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Comments List (Twitter-style Threaded)
                    if (_currentJob.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No comments yet. Be the first to ask about the recipe!',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _buildThreadedComments(),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
              ),
            ),
          ),
        ),
      ),
      // Docked Bottom Action Bar (inside outer body Column, avoids web ScaffoldLayout bug)
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border.withAlpha(150), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Row(
                children: [
                  // Social interaction buttons (Like & Save)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _currentJob.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _currentJob.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                      size: 19,
                    ),
                    onPressed: _toggleLike,
                  ),
                  const SizedBox(width: 3),
                  Text('${_currentJob.likesCount}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _currentJob.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _currentJob.isSaved ? AppTheme.primary : AppTheme.textSecondary,
                      size: 19,
                    ),
                    onPressed: _toggleSave,
                  ),
                  const SizedBox(width: 3),
                  Text('${_currentJob.savesCount}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _showExportSuccess,
                    icon: const Icon(Icons.share_rounded, color: AppTheme.primary, size: 17),
                    label: const Text('Share Report', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                  ),
                  const Spacer(),
                  // Owner action button
                  if (_isOwner) ...[
                    ElevatedButton.icon(
                      key: const Key('job_detail_owner_edit_button'),
                      onPressed: _openEditRecipe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primary),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                  ] else if (widget.repository != null &&
                      widget.repository!.currentUser.id != _currentJob.author.id) ...[
                    // Show Message and Book Service buttons for other detailers' recipes
                    ElevatedButton(
                      onPressed: _messagingLoading ? null : _messageDetailer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _messagingLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_rounded, size: 15),
                                SizedBox(width: 4),
                                Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _openBookingFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 15, color: Colors.black),
                      label: const Text(
                        'Book Service',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
    );
  }
}
