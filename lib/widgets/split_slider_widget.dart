import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SplitSliderWidget extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String defectBadge;
  final double? height;
  final double? aspectRatio;
  final double initialPosition;
  final BoxFit fit;

  const SplitSliderWidget({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.defectBadge = '50/50 Paint Correction',
    this.height,
    this.aspectRatio = 16 / 10,
    this.initialPosition = 0.5,
    this.fit = BoxFit.cover,
  });

  @override
  State<SplitSliderWidget> createState() => _SplitSliderWidgetState();
}

class _SplitSliderWidgetState extends State<SplitSliderWidget> {
  late double _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  Widget _buildImage(String url, bool isBefore, double effectiveHeight) {
    Widget img;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        img = Image.memory(
          bytes,
          fit: widget.fit,
          width: double.infinity,
          height: effectiveHeight,
          alignment: Alignment.center,
        );
      } catch (_) {
        return _buildPlaceholder(isBefore, effectiveHeight);
      }
    } else {
      img = Image.network(
        url,
        fit: widget.fit,
        width: double.infinity,
        height: effectiveHeight,
        alignment: Alignment.center,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(isBefore, effectiveHeight, isLoading: true);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(isBefore, effectiveHeight);
        },
      );
    }

    return Container(
      color: const Color(0xFF0A0D14),
      width: double.infinity,
      height: effectiveHeight,
      child: img,
    );
  }

  Widget _buildPlaceholder(bool isBefore, double effectiveHeight, {bool isLoading = false}) {
    return Container(
      height: effectiveHeight,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final effectiveHeight = widget.height ?? (width / (widget.aspectRatio ?? (16 / 10)));

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: effectiveHeight,
            width: width,
            child: Stack(
              children: [
                // 1. Bottom Layer: AFTER Image (Full Width)
                Positioned.fill(
                  child: _buildImage(widget.afterImageUrl, false, effectiveHeight),
                ),

                // 2. Top Layer: BEFORE Image (Clipped dynamically by slider position)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: width * _position,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: width,
                      minWidth: width,
                      maxHeight: effectiveHeight,
                      minHeight: effectiveHeight,
                      child: _buildImage(widget.beforeImageUrl, true, effectiveHeight),
                    ),
                  ),
                ),

                // 3. Floating Indicator Labels
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.hardnessSoft.withAlpha(120), width: 1),
                    ),
                    child: const Text(
                      'BEFORE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.hardnessSoft,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.primary.withAlpha(120), width: 1),
                    ),
                    child: const Text(
                      'AFTER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),

                // 4. Defect Badge Overlay
                if (widget.defectBadge.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lens_blur_rounded, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            widget.defectBadge,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Divider Line with Handle
                Positioned(
                  left: (width * _position) - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.white,
                  ),
                ),

                // 6. Interactive Circular Handle
                Positioned(
                  left: (width * _position) - 18,
                  top: (effectiveHeight / 2) - 18,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _position = (_position + details.delta.dx / width).clamp(0.02, 0.98);
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(120),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_left, size: 14, color: Colors.black),
                            Icon(Icons.arrow_right, size: 14, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 7. Full-surface Drag Handler
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _position = (_position + details.delta.dx / width).clamp(0.02, 0.98);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
