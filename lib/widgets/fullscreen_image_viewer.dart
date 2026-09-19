import 'dart:convert';
import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;

  const FullscreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title = 'Photo Inspection',
  });

  /// Helper method to open the fullscreen lightbox viewer from any BuildContext.
  static Future<void> open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String title = 'Photo Inspection',
  }) {
    if (images.isEmpty) return Future.value();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withAlpha(235),
        barrierDismissible: true,
        pageBuilder: (ctx, anim, secAnim) => FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex,
          title: title,
        ),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
        SizedBox(height: 8),
        Text(
          'Unable to load high-resolution photo',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withAlpha(235),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Interactive PageView with InteractiveViewer for high-res zoom
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _resetZoom();
                });
              },
              itemBuilder: (context, index) {
                final url = widget.images[index];
                Widget imgWidget;

                if (url.startsWith('data:image')) {
                  try {
                    final base64String = url.split(',').last;
                    final bytes = base64Decode(base64String);
                    imgWidget = Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                    );
                  } catch (_) {
                    imgWidget = _buildErrorWidget();
                  }
                } else {
                  imgWidget = Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF00E5FF),
                        ),
                      );
                    },
                  );
                }

                return Center(
                  child: InteractiveViewer(
                    transformationController: index == _currentIndex ? _transformationController : null,
                    minScale: 0.8,
                    maxScale: 6.0,
                    clipBehavior: Clip.none,
                    child: imgWidget,
                  ),
                );
              },
            ),

            // Top Header Bar
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Counter pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(170),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 6),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.images.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_currentIndex + 1} / ${widget.images.length}',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions: Reset Zoom & Close
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Reset Zoom',
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: _resetZoom,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Arrows for Desktop / Multi-photo inspection
            if (widget.images.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 36, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
                ),
              if (_currentIndex < widget.images.length - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 36, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
                ),
            ],

            // Bottom inspection tip
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Pinch or scroll to zoom in up to 6x for micro-defect inspection',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
