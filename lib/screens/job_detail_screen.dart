import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';
import '../widgets/paint_hardness_badge.dart';
import '../widgets/split_slider_widget.dart';

import '../services/job_repository.dart';

class JobDetailScreen extends StatefulWidget {
  final DetailJob job;
  final JobRepository? repository;

  const JobDetailScreen({super.key, required this.job, this.repository});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  late DetailJob _currentJob;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleAddComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final newComment = JobComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Marcus Vance',
      authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      text: text,
      createdAt: DateTime.now(),
      isVerifiedPro: true,
    );

    setState(() {
      _currentJob = _currentJob.copyWith(
        comments: [..._currentJob.comments, newComment],
      );
      _commentController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment posted to job recipe!'),
        backgroundColor: AppTheme.surfaceLight,
        duration: Duration(seconds: 2),
      ),
    );
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
              'Clients can view before/after 50/50 slider, paint thickness measurements, and coating warranty info without logging in.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Recipe & Inspection'),
        actions: [
          IconButton(
            onPressed: _showExportSuccess,
            icon: const Icon(Icons.share_outlined, color: AppTheme.primary),
            tooltip: 'Share Client Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Full Bleed 50/50 Comparative Slider
            Padding(
              padding: const EdgeInsets.all(16),
              child: SplitSliderWidget(
                beforeImageUrl: _currentJob.beforeImageUrl,
                afterImageUrl: _currentJob.afterImageUrl,
                defectBadge: _currentJob.defectBadge,
                height: 320,
              ),
            ),

            // 2. Vehicle & Author Card
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.surfaceLight,
                          backgroundImage: NetworkImage(_currentJob.author.avatarUrl),
                          onBackgroundImageError: (_, _) {},
                          child: Text(_currentJob.author.displayName[0]),
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

            // 3. Technical Inspection & Gauge Metrics
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
                        const Text('Defect Severity:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text('${_currentJob.defectSeverity} / 10', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.hardnessSoft, fontSize: 13)),
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

            // 4. Step-by-Step Detailing Recipe (The Core Innovation)
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

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentJob.recipeStages.length,
                    itemBuilder: (context, idx) {
                      final stage = _currentJob.recipeStages[idx];
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
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5. Verified Pro Comments & Community Discussion
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

                  // Comment Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Ask about compound, pad, or flash time...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

                  // Comments List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentJob.comments.length,
                    itemBuilder: (context, idx) {
                      final c = _currentJob.comments[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.surfaceLight,
                              backgroundImage: NetworkImage(c.authorAvatar),
                              onBackgroundImageError: (_, _) {},
                              child: Text(c.authorName[0], style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                                      ),
                                      if (c.isVerifiedPro) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 12),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.text,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildRecipeField(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text('$title: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
          Expanded(
            child: Text(content, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
