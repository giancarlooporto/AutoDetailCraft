import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/paint_gauge_point.dart';

class PaintGaugeWalkaroundWidget extends StatefulWidget {
  final List<PaintGaugePoint> points;
  final ValueChanged<List<PaintGaugePoint>> onPointsChanged;
  final bool readOnly;

  const PaintGaugeWalkaroundWidget({
    super.key,
    required this.points,
    required this.onPointsChanged,
    this.readOnly = false,
  });

  @override
  State<PaintGaugeWalkaroundWidget> createState() => _PaintGaugeWalkaroundWidgetState();
}

class _PaintGaugeWalkaroundWidgetState extends State<PaintGaugeWalkaroundWidget> {
  // Mode: 0 = Microns (µm), 1 = Mils (mil)
  bool _useMils = false;

  double get _overallInitialAvg {
    if (widget.points.isEmpty) return 0.0;
    final sum = widget.points.fold<double>(0.0, (acc, p) => acc + p.initialMicrons);
    return sum / widget.points.length;
  }

  double get _overallPostAvg {
    if (widget.points.isEmpty) return 0.0;
    final sum = widget.points.fold<double>(0.0, (acc, p) => acc + p.postPolishMicrons);
    return sum / widget.points.length;
  }

  double get _overallMicronsRemoved {
    return (_overallInitialAvg - _overallPostAvg).clamp(0.0, 999.0);
  }

  String _formatReading(double microns) {
    if (_useMils) {
      // 1 mil = 25.4 microns
      final mils = microns / 25.4;
      return '${mils.toStringAsFixed(1)} mil';
    }
    return '${microns.toStringAsFixed(0)} µm';
  }

  void _openPointEditor(int index) {
    if (widget.readOnly) return;
    final point = widget.points[index];

    final initialCtrl = TextEditingController(text: point.initialMicrons.toStringAsFixed(0));
    final postCtrl = TextEditingController(text: point.postPolishMicrons.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final curInitial = double.tryParse(initialCtrl.text) ?? point.initialMicrons;
            final curPost = double.tryParse(postCtrl.text) ?? point.postPolishMicrons;
            final diff = (curInitial - curPost).clamp(0.0, 999.0);

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.straighten_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${point.label} Reading',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Presets (1-Tap):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickSetButton(
                          label: 'Thin ~80µm',
                          color: const Color(0xFFFFD600),
                          onTap: () {
                            setDialogState(() {
                              initialCtrl.text = '82';
                              postCtrl.text = '80';
                            });
                          },
                        ),
                        _buildQuickSetButton(
                          label: 'Factory Healthy ~120µm',
                          color: const Color(0xFF00E676),
                          onTap: () {
                            setDialogState(() {
                              initialCtrl.text = '122';
                              postCtrl.text = '119';
                            });
                          },
                        ),
                        _buildQuickSetButton(
                          label: 'Re-spray ~200µm',
                          color: const Color(0xFFFF5252),
                          onTap: () {
                            setDialogState(() {
                              initialCtrl.text = '230';
                              postCtrl.text = '225';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 14),
                    const Text(
                      'Direct Numerical Entry (µm):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initialCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Initial (µm)',
                              prefixIcon: Icon(Icons.speed_rounded, size: 16),
                              isDense: true,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: postCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Post-Polish (µm)',
                              prefixIcon: Icon(Icons.check_circle_outline, size: 16),
                              isDense: true,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Clear Removed:', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                          Text(
                            '-${diff.toStringAsFixed(1)} µm',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final newInitial = double.tryParse(initialCtrl.text) ?? point.initialMicrons;
                    final newPost = double.tryParse(postCtrl.text) ?? point.postPolishMicrons;
                    final updatedPoints = List<PaintGaugePoint>.from(widget.points);
                    updatedPoints[index] = point.copyWith(
                      initialMicrons: newInitial,
                      postPolishMicrons: newPost,
                    );
                    widget.onPointsChanged(updatedPoints);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickSetButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Color _getPointStatusColor(double microns) {
    if (microns < 95) return const Color(0xFFFFD600); // Thin clear coat
    if (microns > 190) return const Color(0xFFFF5252); // Re-spray
    return const Color(0xFF00E676); // Healthy OEM
  }

  @override
  Widget build(BuildContext context) {
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
          // Header with Overall Vehicle Average & Unit Switcher
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '8-Point Paint Gauge Walkaround Body Check',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap any panel reading box for 1-tap presets or custom entry.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Unit toggle (µm vs mil)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _useMils = false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_useMils ? AppTheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                        ),
                        child: Text(
                          'µm',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_useMils ? Colors.black : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _useMils = true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _useMils ? AppTheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                        ),
                        child: Text(
                          'mils',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _useMils ? Colors.black : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Overall Vehicle Average Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(20),
                  AppTheme.surfaceLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Vehicle Average',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.points.length} Body Points Active',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOverallMetricTile(
                      label: 'Initial Average',
                      value: _formatReading(_overallInitialAvg),
                      color: Colors.white,
                      icon: Icons.speed_rounded,
                    ),
                    Container(width: 1, height: 26, color: AppTheme.border),
                    _buildOverallMetricTile(
                      label: 'Post-Polish Average',
                      value: _formatReading(_overallPostAvg),
                      color: AppTheme.primary,
                      icon: Icons.check_circle_outline,
                    ),
                    Container(width: 1, height: 26, color: AppTheme.border),
                    _buildOverallMetricTile(
                      label: 'Microns Removed',
                      value: '-${_formatReading(_overallMicronsRemoved)}',
                      color: const Color(0xFFFF5252),
                      icon: Icons.layers_clear_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 8-Point Visual Walkaround Body Check Layout
          const Text(
            '8-POINT VISUAL WALKAROUND BODY CHECK',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isNarrow ? 2 : 4;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.points.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 74,
                ),
                itemBuilder: (context, index) {
                  final point = widget.points[index];
                  final statusColor = _getPointStatusColor(point.initialMicrons);

                  return InkWell(
                    key: Key('paint_point_${point.id}'),
                    onTap: widget.readOnly ? null : () => _openPointEditor(index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withAlpha(80), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  point.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatReading(point.initialMicrons),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text('Initial', style: TextStyle(fontSize: 8.5, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(Icons.arrow_forward_rounded, size: 9, color: AppTheme.textMuted),
                              ),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatReading(point.postPolishMicrons),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text('Post', style: TextStyle(fontSize: 8.5, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
