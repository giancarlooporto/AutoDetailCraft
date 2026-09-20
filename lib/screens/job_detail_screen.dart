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

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    _selectedTabIndex = widget.initialTabIndex;
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

  Widget _buildPhotoContainerSection({
    required String title,
    required List<String> photos,
    required Color accentColor,
    required IconData icon,
    required String emptyMsg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentColor.withAlpha(80)),
                ),
                child: Text(
                  '${photos.length} photos',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Text(emptyMsg, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
          else
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, idx) {
                  final url = photos[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => FullscreenImageViewer.open(
                        context,
                        images: photos,
                        initialIndex: idx,
                        title: '$title (${idx + 1}/${photos.length})',
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: 130,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 130,
                                height: 110,
                                color: AppTheme.surfaceLight,
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(180),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

  List<Widget> _buildThreadedComments() {
    final rootComments = _currentJob.comments.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
    final allReplies = _currentJob.comments.where((c) => c.parentId != null && c.parentId!.isNotEmpty).toList();
    final List<Widget> items = [];

    for (final root in rootComments) {
      final childReplies = allReplies.where((r) => r.parentId == root.id).toList();

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
                        if (c.isVerifiedPro) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 13, color: AppTheme.primary),
                        ],
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
            IconButton(
              key: const Key('edit_recipe_appbar_button'),
              onPressed: _openEditRecipe,
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
              tooltip: 'Edit Recipe',
            ),
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
                } else if (val == 'share') {
                  _showExportSuccess();
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
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: Colors.white70),
                      SizedBox(width: 10),
                      Text('Share Client Report', style: TextStyle(fontSize: 13)),
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
          ] else ...[
            IconButton(
              key: const Key('share_recipe_appbar_button'),
              onPressed: _showExportSuccess,
              icon: const Icon(Icons.share_outlined, color: AppTheme.primary, size: 20),
              tooltip: 'Share Client Report',
            ),
          ],
          const SizedBox(width: 8),
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

            // 2. Inspection Photo Containers (View All Before & After)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildPhotoContainerSection(
                    title: 'Before Inspection Photos',
                    photos: beforeList,
                    accentColor: AppTheme.hardnessSoft,
                    icon: Icons.history_rounded,
                    emptyMsg: 'No additional before inspection photos.',
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoContainerSection(
                    title: 'After Transformation Photos',
                    photos: afterList,
                    accentColor: AppTheme.primary,
                    icon: Icons.auto_awesome_rounded,
                    emptyMsg: 'No additional after transformation photos.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
                          _buildGaugeMetric('Clear Removed', '-${_currentJob.micronsRemoved.toStringAsFixed(1)} µm', Icons.layers_clear_outlined, AppTheme.hardnessHard),
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

                    Column(
                      children: _currentJob.recipeStages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final stage = entry.value;
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
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(35),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primary, width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${idx + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      stage.stageName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (stage.dilution != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Text(
                                        stage.dilution!,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Stage Details
                              if (stage.machine.isNotEmpty)
                                _buildRecipeField('Machine', stage.machine, Icons.build_rounded),
                              if (stage.pad.isNotEmpty)
                                _buildRecipeField('Pad', stage.pad, Icons.circle_outlined),
                              _buildRecipeField('Chemical / Compound', stage.chemical, Icons.science_rounded),
                              if (stage.technique.isNotEmpty)
                                _buildRecipeField('Technique / Passes', stage.technique, Icons.tune_rounded),
                              if (stage.notes != null && stage.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Pro Note: ${stage.notes}',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                                  ),
                                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _showExportSuccess,
                    icon: const Icon(Icons.share_rounded, color: AppTheme.primary, size: 18),
                    label: const Text('Share Report', style: TextStyle(color: AppTheme.primary)),
                  ),
                  const Spacer(),
                  // Show Message and Book Service buttons for other detailers' recipes
                  if (widget.repository != null &&
                      widget.repository!.currentUser.id != _currentJob.author.id) ...[
                    ElevatedButton(
                      onPressed: _messagingLoading ? null : _messageDetailer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _messagingLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Message', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _openBookingFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.black),
                      label: const Text(
                        'Book Service',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
