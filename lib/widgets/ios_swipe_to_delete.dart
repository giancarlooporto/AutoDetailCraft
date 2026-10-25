import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Reusable iOS-style swipe-to-delete widget.
///
/// Wraps a list item or tile. Swiping horizontally to the left reveals
/// a red background action button with spring snap animation.
/// Tapping the delete button triggers [onDelete]. Tapping anywhere on the front
/// tile while swiped open springs it back closed.
class IosSwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double actionWidth;
  final String tooltip;
  final Color backgroundColor;
  final BorderRadius borderRadius;

  const IosSwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.actionWidth = 84.0,
    this.tooltip = 'Delete conversation',
    this.backgroundColor = AppTheme.error,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<IosSwipeToDelete> createState() => IosSwipeToDeleteState();
}

class IosSwipeToDeleteState extends State<IosSwipeToDelete>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    _controller.addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the swipe action revealing the delete button
  void open() {
    _animateTo(-widget.actionWidth);
  }

  /// Closes the swipe action
  void close() {
    _animateTo(0.0);
  }

  void _animateTo(double target) {
    _animation = _controller.drive(
      Tween<double>(begin: _dragExtent, end: target).chain(
        CurveTween(curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward(from: 0.0).orCancel.then((_) {
      if (mounted) {
        setState(() {
          _isOpen = target < -5;
          _dragExtent = target;
        });
      }
    }).catchError((_) {});
  }

  void _handleDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    double newExtent = _dragExtent + delta;
    if (newExtent > 0) {
      newExtent = 0;
    } else if (newExtent < -widget.actionWidth) {
      // Rubber-banding beyond the revealed action width
      final excess = -widget.actionWidth - newExtent;
      newExtent = -widget.actionWidth - (excess * 0.25);
    }
    setState(() {
      _dragExtent = newExtent;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      // Fling left: snap open revealing delete button
      _animateTo(-widget.actionWidth);
    } else if (velocity > 300) {
      // Fling right: snap back closed
      _animateTo(0.0);
    } else if (_dragExtent < -widget.actionWidth / 2) {
      // Dragged past halfway: snap open
      _animateTo(-widget.actionWidth);
    } else {
      // Snap back closed
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          // Background delete action container (iOS red)
          Positioned.fill(
            child: Container(
              color: widget.backgroundColor,
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: widget.actionWidth,
                height: double.infinity,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                    tooltip: widget.tooltip,
                    onPressed: () {
                      close();
                      widget.onDelete();
                    },
                  ),
                ),
              ),
            ),
          ),

          // Front sliding content layer
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: Stack(
                children: [
                  widget.child,
                  // When swiped open, absorb taps on the child to close instead of activating child action
                  if (_isOpen || _dragExtent < -5)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: close,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
