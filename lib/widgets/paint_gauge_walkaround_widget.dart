import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/paint_gauge_point.dart';

String _formatDialogInput(double microns, {required bool isMil}) {
  final safeMicrons = microns <= 0.0 ? 0.0 : microns;
  if (isMil) {
    final mils = safeMicrons / 25.4;
    if ((safeMicrons - safeMicrons.roundToDouble()).abs() < 0.0001) {
      final s = mils.toStringAsFixed(1);
      return (s == '-0.0' || s == '-0') ? '0.0' : s;
    }
    final s = mils.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    if (!s.contains('.')) {
      return '$s.0';
    }
    return (s == '-0.0' || s == '-0') ? '0.0' : s;
  } else {
    if ((safeMicrons - safeMicrons.roundToDouble()).abs() < 0.0001) {
      final s = safeMicrons.toStringAsFixed(0);
      return s == '-0' ? '0' : s;
    }
    final s = safeMicrons.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s == '-0' ? '0' : s;
  }
}

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
      final mils = microns <= 0.0 ? 0.0 : microns / 25.4;
      final s = mils.toStringAsFixed(1);
      return '${(s == "-0.0" || s == "-0") ? "0.0" : s} mil';
    }
    final safeMicrons = microns <= 0.0 ? 0.0 : microns;
    final s = safeMicrons.toStringAsFixed(0);
    return '${(s == "-0.0" || s == "-0") ? "0" : s} µm';
  }

  void _openPointEditor(int index) {
    if (widget.readOnly) return;
    if (index < 0 || index >= widget.points.length) return;
    final point = widget.points[index];

    showDialog(
      context: context,
      builder: (ctx) => _PointEditorDialog(
        point: point,
        useMils: _useMils,
        onApply: (updatedPoint) {
          final updatedPoints = List<PaintGaugePoint>.from(widget.points);
          updatedPoints[index] = updatedPoint;
          widget.onPointsChanged(updatedPoints);
        },
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
                      label: _useMils ? 'Clear Removed' : 'Microns Removed',
                      value: () {
                        final reading = _formatReading(_overallMicronsRemoved);
                        final numVal = double.tryParse(reading.split(' ').first) ?? 0.0;
                        return numVal == 0.0 ? _formatReading(0.0) : '-$reading';
                      }(),
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
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatReading(point.initialMicrons),
                                      style: TextStyle(
                                        fontSize: 11,
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
                                padding: EdgeInsets.symmetric(horizontal: 1),
                                child: Icon(Icons.arrow_forward_rounded, size: 8, color: AppTheme.textMuted),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatReading(point.postPolishMicrons),
                                      style: const TextStyle(
                                        fontSize: 11,
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

class _PointEditorDialog extends StatefulWidget {
  final PaintGaugePoint point;
  final bool useMils;
  final ValueChanged<PaintGaugePoint> onApply;

  const _PointEditorDialog({
    required this.point,
    required this.useMils,
    required this.onApply,
  });

  @override
  State<_PointEditorDialog> createState() => _PointEditorDialogState();
}

class _PointEditorDialogState extends State<_PointEditorDialog> {
  late final String _initialStr;
  late final String _postStr;
  late final TextEditingController _initialCtrl;
  late final TextEditingController _postCtrl;

  @override
  void initState() {
    super.initState();
    _initialStr = _formatDialogInput(widget.point.initialMicrons, isMil: widget.useMils);
    _postStr = _formatDialogInput(widget.point.postPolishMicrons, isMil: widget.useMils);
    _initialCtrl = TextEditingController(text: _initialStr);
    _postCtrl = TextEditingController(text: _postStr);
  }

  @override
  void dispose() {
    _initialCtrl.dispose();
    _postCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final parsedInitial = double.tryParse(_initialCtrl.text.trim().replaceAll(',', '.'));
    final parsedPost = double.tryParse(_postCtrl.text.trim().replaceAll(',', '.'));
    final double diff;
    if (parsedInitial != null && parsedPost != null) {
      final curInitial = parsedInitial.clamp(0.0, 9999.0);
      final curPost = parsedPost.clamp(0.0, 9999.0);
      diff = (curInitial - curPost).clamp(0.0, 999.0);
    } else {
      diff = 0.0;
    }

    final diffFormatted = diff.toStringAsFixed(1);
    final numDiff = double.tryParse(diffFormatted) ?? 0.0;
    final unit = widget.useMils ? 'mil' : 'µm';
    final diffDisplay = numDiff == 0.0 ? '0.0 $unit' : '-$diffFormatted $unit';

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
              '${widget.point.label} Reading',
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
              children: widget.useMils
                  ? [
                      _buildQuickSetButton(
                        label: 'Thin ~3.1 mil',
                        color: const Color(0xFFFFD600),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '3.2';
                            _postCtrl.text = '3.1';
                          });
                        },
                      ),
                      _buildQuickSetButton(
                        label: 'Factory Healthy ~4.8 mil',
                        color: const Color(0xFF00E676),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '4.8';
                            _postCtrl.text = '4.7';
                          });
                        },
                      ),
                      _buildQuickSetButton(
                        label: 'Re-spray ~9.0 mil',
                        color: const Color(0xFFFF5252),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '9.1';
                            _postCtrl.text = '8.9';
                          });
                        },
                      ),
                    ]
                  : [
                      _buildQuickSetButton(
                        label: 'Thin ~80µm',
                        color: const Color(0xFFFFD600),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '82';
                            _postCtrl.text = '80';
                          });
                        },
                      ),
                      _buildQuickSetButton(
                        label: 'Factory Healthy ~120µm',
                        color: const Color(0xFF00E676),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '122';
                            _postCtrl.text = '119';
                          });
                        },
                      ),
                      _buildQuickSetButton(
                        label: 'Re-spray ~200µm',
                        color: const Color(0xFFFF5252),
                        onTap: () {
                          setState(() {
                            _initialCtrl.text = '230';
                            _postCtrl.text = '225';
                          });
                        },
                      ),
                    ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 14),
            Text(
              widget.useMils ? 'Direct Numerical Entry (mil):' : 'Direct Numerical Entry (µm):',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _initialCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: widget.useMils ? 'Initial (mil)' : 'Initial (µm)',
                      prefixIcon: const Icon(Icons.speed_rounded, size: 16),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _postCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: widget.useMils ? 'Post-Polish (mil)' : 'Post-Polish (µm)',
                      prefixIcon: const Icon(Icons.check_circle_outline, size: 16),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
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
                    diffDisplay,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final rawInitial = double.tryParse(_initialCtrl.text.trim().replaceAll(',', '.'));
            final rawPost = double.tryParse(_postCtrl.text.trim().replaceAll(',', '.'));
            final newInitialInput = rawInitial?.clamp(0.0, 9999.0);
            final newPostInput = rawPost?.clamp(0.0, 9999.0);

            final normalizedInitial = _initialCtrl.text.trim().replaceAll(',', '.');
            final normalizedPost = _postCtrl.text.trim().replaceAll(',', '.');
            final normalizedInitialStr = _initialStr.trim().replaceAll(',', '.');
            final normalizedPostStr = _postStr.trim().replaceAll(',', '.');

            final double newInitial;
            final double newPost;

            if (widget.useMils) {
              if (newInitialInput != null) {
                if (normalizedInitial == normalizedInitialStr) {
                  newInitial = widget.point.initialMicrons;
                } else {
                  newInitial = newInitialInput * 25.4;
                }
              } else {
                newInitial = widget.point.initialMicrons;
              }

              if (newPostInput != null) {
                if (normalizedPost == normalizedPostStr) {
                  newPost = widget.point.postPolishMicrons;
                } else {
                  newPost = newPostInput * 25.4;
                }
              } else {
                newPost = widget.point.postPolishMicrons;
              }
            } else {
              if (newInitialInput != null) {
                if (normalizedInitial == normalizedInitialStr) {
                  newInitial = widget.point.initialMicrons;
                } else {
                  newInitial = newInitialInput;
                }
              } else {
                newInitial = widget.point.initialMicrons;
              }

              if (newPostInput != null) {
                if (normalizedPost == normalizedPostStr) {
                  newPost = widget.point.postPolishMicrons;
                } else {
                  newPost = newPostInput;
                }
              } else {
                newPost = widget.point.postPolishMicrons;
              }
            }

            widget.onApply(widget.point.copyWith(
              initialMicrons: newInitial,
              postPolishMicrons: newPost,
            ));
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
