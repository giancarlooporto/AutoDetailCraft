import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';

class SplitSliderWidget extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String defectBadge;
  final double height;
  final double initialPosition;
  final List<JobMediaZone>? zones;

  const SplitSliderWidget({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.defectBadge = '50/50 Paint Correction',
    this.height = 320,
    this.initialPosition = 0.5,
    this.zones,
  });

  @override
  State<SplitSliderWidget> createState() => _SplitSliderWidgetState();
}

class _SplitSliderWidgetState extends State<SplitSliderWidget> {
  late double _position;
  int _selectedZoneIndex = 0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  JobMediaZone get _currentZone {
    if (widget.zones != null && widget.zones!.isNotEmpty) {
      final safeIndex = _selectedZoneIndex.clamp(0, widget.zones!.length - 1);
      return widget.zones![safeIndex];
    }
    return JobMediaZone(
      id: 'default',
      zoneName: 'Main',
      beforeImageUrl: widget.beforeImageUrl,
      afterImageUrl: widget.afterImageUrl,
      defectBadge: widget.defectBadge,
    );
  }

  String get _activeBeforeUrl => _currentZone.beforeImageUrl.isNotEmpty ? _currentZone.beforeImageUrl : widget.beforeImageUrl;
  String get _activeAfterUrl => _currentZone.afterImageUrl.isNotEmpty ? _currentZone.afterImageUrl : widget.afterImageUrl;
  String get _activeBadge => (_currentZone.defectBadge != null && _currentZone.defectBadge!.isNotEmpty)
      ? _currentZone.defectBadge!
      : widget.defectBadge;

  Widget _buildImage(String url, bool isBefore) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: widget.height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder(isBefore, isLoading: true);
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(isBefore);
      },
    );
  }

  Widget _buildPlaceholder(bool isBefore, {bool isLoading = false}) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBefore
              ? [const Color(0xFF2A1B1B), const Color(0xFF1E1414)]
              : [const Color(0xFF14242A), const Color(0xFF0E1A1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBefore ? Icons.blur_on_rounded : Icons.auto_awesome_rounded,
                    color: isBefore ? AppTheme.hardnessSoft : AppTheme.primary,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isBefore ? 'Defect / Swirl State' : 'Corrected Mirror Finish',
                    style: TextStyle(
                      color: isBefore ? AppTheme.hardnessSoft : AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.zones != null && widget.zones!.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.zones!.length, (idx) {
                  final z = widget.zones![idx];
                  final isSelected = idx == _selectedZoneIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.camera_alt_outlined,
                        size: 13,
                        color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                      ),
                      label: Text(
                        z.zoneName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedZoneIndex = idx;
                          });
                        }
                      },
                      selectedColor: AppTheme.primary.withAlpha(40),
                      backgroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final splitWidth = totalWidth * _position;

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // After Image (Full Background)
                  _buildImage(_activeAfterUrl, false),

                  // Before Image (Clipped to Slider Position)
                  ClipRect(
                    clipper: _SliderClipper(splitWidth),
                    child: _buildImage(_activeBeforeUrl, true),
                  ),

                  // Slider Divider Line & Glow Handle
                  Positioned(
                    left: splitWidth - 16,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _position = (_position + details.delta.dx / totalWidth).clamp(0.05, 0.95);
                        });
                      },
                      child: SizedBox(
                        width: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Vertical dividing line
                            Container(
                              width: 2.5,
                              color: Colors.white.withAlpha(230),
                            ),
                            // Handle Center Button
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.surface,
                                border: Border.all(color: AppTheme.primary, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withAlpha(100),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.code_rounded, // Code / Chevrons
                                color: AppTheme.primary,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Whole-Area Drag GestureDetector
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _position = (_position + details.delta.dx / totalWidth).clamp(0.05, 0.95);
                        });
                      },
                    ),
                  ),

                  // Top Labels: BEFORE vs AFTER
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(190),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.hardnessSoft.withAlpha(150), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.blur_on, color: AppTheme.hardnessSoft, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'BEFORE (DEFECTS)',
                            style: TextStyle(color: AppTheme.hardnessSoft, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(190),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withAlpha(150), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: AppTheme.primary, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'AFTER (CORRECTED)',
                            style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Defect Severity Badge Bottom Left
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withAlpha(220),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded, color: AppTheme.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _currentZone.initialMicrons != null && _currentZone.finalMicrons != null
                                ? '$_activeBadge • ${_currentZone.initialMicrons}µm ➔ ${_currentZone.finalMicrons}µm'
                                : _activeBadge,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Drag Hint Icon Bottom Right
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swipe_outlined, color: AppTheme.textSecondary, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Drag to compare',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double splitWidth;

  _SliderClipper(this.splitWidth);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, splitWidth, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.splitWidth != splitWidth;
}
