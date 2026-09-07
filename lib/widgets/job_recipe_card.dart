import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';
import '../screens/job_detail_screen.dart';
import '../screens/booking_flow_screen.dart';
import '../screens/public_studio_screen.dart';
import '../screens/create_job_screen.dart';
import '../services/job_repository.dart';
import 'split_slider_widget.dart';

class JobRecipeCard extends StatelessWidget {
  final DetailJob job;
  final JobRepository repository;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final bool showDetailerManagement;
  final VoidCallback? onJobChanged;

  const JobRecipeCard({
    super.key,
    required this.job,
    required this.repository,
    this.onLike,
    this.onSave,
    this.showDetailerManagement = false,
    this.onJobChanged,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openBookingFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          detailer: job.author,
          repository: repository,
        ),
      ),
    );
  }

  void _openPublicStudio(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicStudioScreen(
          detailer: job.author,
          repository: repository,
        ),
      ),
    );
  }

  void _editJob(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          repository: repository,
          jobToEdit: job,
          onJobCreated: () {
            if (onJobChanged != null) onJobChanged!();
          },
        ),
      ),
    );
  }

  void _showImageGalleryModal(BuildContext context, String title, List<String> imageUrls, Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
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
                                child: Icon(Icons.photo_library_rounded, color: accentColor, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: accentColor.withAlpha(60)),
                                ),
                                child: Text(
                                  '${imageUrls.length} photos',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 600;
                            final isWide = constraints.maxWidth >= 850;
                            final cols = isWide ? 4 : (isDesktop ? 3 : 2);

                            return GridView.builder(
                              controller: scrollController,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: imageUrls.length,
                              itemBuilder: (context, idx) {
                                final url = imageUrls[idx];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: AppTheme.surfaceLight,
                                          child: const Center(
                                            child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
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
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutStage = job.recipeStages.isNotEmpty ? job.recipeStages.first : null;
    final finishStage = job.recipeStages.length > 1 ? job.recipeStages.last : null;

    final beforeList = job.allBeforePhotos;
    final afterList = job.allAfterPhotos;
    final isAuthor = repository.currentUser.id == job.author.id;
    final canManage = showDetailerManagement || isAuthor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Detailer profile & verified tag (Tappable to view Studio)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _openPublicStudio(context),
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(job.author.avatarUrl),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _openPublicStudio(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job.author.businessName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (job.author.isVerifiedHost) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 15, color: AppTheme.primary),
                            ],
                          ],
                        ),
                        Text(
                          '${job.author.location} • ${_formatTimeAgo(job.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

                // Management or Booking actions
                if (canManage) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 19),
                    tooltip: 'Edit Transformation',
                    onPressed: () => _editJob(context),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                    tooltip: 'Book with this detailer',
                    onPressed: () => _openBookingFlow(context),
                  ),
              ],
            ),
          ),

          // Strictly ONE single 50/50 hero comparison slider
          SplitSliderWidget(
            beforeImageUrl: job.beforeImageUrl,
            afterImageUrl: job.afterImageUrl,
            defectBadge: job.defectBadge,
            aspectRatio: 16 / 10,
          ),

          // Container Bar: View all Before & After inspection photos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showImageGalleryModal(
                      context,
                      'Before Inspection Photos',
                      beforeList,
                      AppTheme.hardnessSoft,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.hardnessSoft.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 14, color: AppTheme.hardnessSoft),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Before (${beforeList.length})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.hardnessSoft,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showImageGalleryModal(
                      context,
                      'After Transformation Photos',
                      afterList,
                      AppTheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'After (${afterList.length})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
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

          // Vehicle & Recipe Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job.vehicleFullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        job.paintColorName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  job.title,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),

                // Recipe Pills: Compound, Pad, Ceramic
                if (cutStage != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cutStage.chemical,
                                style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cutStage.pad.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cutStage.pad,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (finishStage != null)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            finishStage.chemical,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 8),

                // Actions: Likes, Comments, View Details, Book
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            job.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: job.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: onLike,
                        ),
                        const SizedBox(width: 2),
                        Text('${job.likesCount}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(width: 6),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppTheme.textSecondary),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(job: job, repository: repository),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 2),
                        Text('${job.comments.length}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(width: 6),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            job.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: job.isSaved ? AppTheme.primary : AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: onSave,
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(job: job, repository: repository),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Recipe', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded, size: 13),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
