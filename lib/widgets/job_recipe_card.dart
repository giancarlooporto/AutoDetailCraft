import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';
import '../screens/job_detail_screen.dart';
import '../screens/booking_flow_screen.dart';
import '../screens/public_studio_screen.dart';
import '../services/job_repository.dart';
import 'split_slider_widget.dart';

class JobRecipeCard extends StatelessWidget {
  final DetailJob job;
  final JobRepository repository;
  final VoidCallback? onLike;
  final VoidCallback? onSave;

  const JobRecipeCard({
    super.key,
    required this.job,
    required this.repository,
    this.onLike,
    this.onSave,
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

  @override
  Widget build(BuildContext context) {
    final cutStage = job.recipeStages.isNotEmpty ? job.recipeStages.first : null;
    final finishStage = job.recipeStages.length > 1 ? job.recipeStages.last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                  tooltip: 'Book with this detailer',
                  onPressed: () => _openBookingFlow(context),
                ),
              ],
            ),
          ),

          // Interactive Transformation Image Slider
          SplitSliderWidget(
            beforeImageUrl: job.beforeImageUrl,
            afterImageUrl: job.afterImageUrl,
            defectBadge: job.defectBadge,
            zones: job.effectiveMediaZones,
            height: 250,
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
                            Text(cutStage.chemical, style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (cutStage.pad.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(cutStage.pad, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ),
                      if (finishStage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(finishStage.chemical, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                      children: [
                        IconButton(
                          icon: Icon(
                            job.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: job.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: onLike,
                        ),
                        Text('${job.likesCount}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppTheme.textSecondary),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(job: job, repository: repository),
                              ),
                            );
                          },
                        ),
                        Text('${job.comments.length}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            job.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: job.isSaved ? AppTheme.primary : AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: onSave,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      icon: const Text('View Recipe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      label: const Icon(Icons.arrow_forward_rounded, size: 14),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(job: job, repository: repository),
                          ),
                        );
                      },
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
