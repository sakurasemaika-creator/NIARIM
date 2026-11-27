import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A movable, collapsible control surface used while the canvas is in a
/// distraction-free editing mode.
///
/// The panel starts in the bottom-left corner. Only its narrow header is a
/// drag target, so sliders and buttons keep their normal gestures. The body
/// remains mounted while collapsed to preserve in-progress edits and previews.
class FocusModeMenu extends StatefulWidget {
  const FocusModeMenu({
    super.key,
    required this.child,
    required this.collapseTooltip,
    required this.expandTooltip,
    this.maxWidth = 360,
    this.fillWidth = false,
  });

  final Widget child;
  final String collapseTooltip;
  final String expandTooltip;
  final double maxWidth;

  /// Fill the available menu width. Useful for bottom-bar content such as the
  /// filter editor; compact action bars can keep their natural width.
  final bool fillWidth;

  @override
  State<FocusModeMenu> createState() => _FocusModeMenuState();
}

class _FocusModeMenuState extends State<FocusModeMenu> {
  static const double _edgeInset = 12;
  static const double _headerHeight = 44;

  final GlobalKey _surfaceKey = GlobalKey();
  double _left = _edgeInset;
  double _bottom = _edgeInset;
  bool _minimized = false;
  Size? _lastExpandedSize;

  Size? get _measuredSurfaceSize {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return null;
  }

  void _toggleMinimized() {
    final measured = _measuredSurfaceSize;
    setState(() {
      if (!_minimized && measured != null) {
        _lastExpandedSize = measured;
      }
      _minimized = !_minimized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }

        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final menuWidth = math
            .max(
              0.0,
              math.min(
                widget.maxWidth,
                viewportWidth - _edgeInset * 2,
              ),
            )
            .toDouble();
        final maxMenuHeight = math
            .max(0.0, viewportHeight - _edgeInset * 2)
            .toDouble();
        final measured = _measuredSurfaceSize;
        final estimatedSize = Size(
          widget.fillWidth ? menuWidth : math.min(menuWidth, 320).toDouble(),
          _minimized
              ? _headerHeight
              : math.min(maxMenuHeight, 420).toDouble(),
        );
        // When minimized, keep the expanded dimensions for boundary checks.
        // This prevents a pill dragged to the edge from opening off-screen.
        final currentSize = _minimized
            ? (_lastExpandedSize ?? measured ?? estimatedSize)
            : (measured != null && measured.height > _headerHeight
                  ? measured
                  : (_lastExpandedSize ?? estimatedSize));

        final maxLeft = math
            .max(
              _edgeInset,
              viewportWidth - currentSize.width - _edgeInset,
            )
            .toDouble();
        final maxBottom = math
            .max(
              _edgeInset,
              viewportHeight - currentSize.height - _edgeInset,
            )
            .toDouble();
        final left = _left.clamp(_edgeInset, maxLeft).toDouble();
        final bottom = _bottom.clamp(_edgeInset, maxBottom).toDouble();
        final bodyMaxHeight = math
            .max(0.0, maxMenuHeight - _headerHeight)
            .toDouble();
        final headerWidth = widget.fillWidth
            ? menuWidth
            : math.min(menuWidth, 104).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              bottom: bottom,
              child: KeyedSubtree(
                key: const ValueKey('focus-mode-menu-surface'),
                child: Material(
                  key: _surfaceKey,
                  color: scheme.surface,
                  elevation: 6,
                  surfaceTintColor: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: headerWidth,
                          height: _headerHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'focus-mode-menu-drag-handle',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      final measuredForDrag =
                                          _measuredSurfaceSize;
                                      final size = _minimized
                                          ? (_lastExpandedSize ??
                                                measuredForDrag ??
                                                estimatedSize)
                                          : (measuredForDrag != null &&
                                                    measuredForDrag.height >
                                                        _headerHeight
                                                ? measuredForDrag
                                                : (_lastExpandedSize ??
                                                      estimatedSize));
                                      final dragMaxLeft = math
                                          .max(
                                            _edgeInset,
                                            viewportWidth -
                                                size.width -
                                                _edgeInset,
                                          )
                                          .toDouble();
                                      final dragMaxBottom = math
                                          .max(
                                            _edgeInset,
                                            viewportHeight -
                                                size.height -
                                                _edgeInset,
                                          )
                                          .toDouble();
                                      setState(() {
                                        _left = (_left + details.delta.dx)
                                            .clamp(_edgeInset, dragMaxLeft)
                                            .toDouble();
                                        // Screen Y grows downward; a positive
                                        // bottom offset moves the menu upward.
                                        _bottom =
                                            (_bottom - details.delta.dy)
                                                .clamp(
                                                  _edgeInset,
                                                  dragMaxBottom,
                                                )
                                                .toDouble();
                                      });
                                    },
                                    child: Center(
                                      child: Container(
                                        width: 38,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.48),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                child: IconButton(
                                  key: const ValueKey(
                                    'focus-mode-menu-toggle',
                                  ),
                                  tooltip: _minimized
                                      ? widget.expandTooltip
                                      : widget.collapseTooltip,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: _headerHeight,
                                    height: _headerHeight,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _minimized
                                        ? Icons.expand_more
                                        : Icons.expand_less,
                                    size: 20,
                                  ),
                                  onPressed: _toggleMinimized,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: menuWidth,
                            maxHeight: bodyMaxHeight,
                          ),
                          child: TickerMode(
                            enabled: !_minimized,
                            child: Offstage(
                              offstage: _minimized,
                              child: SizedBox(
                                width: widget.fillWidth ? menuWidth : null,
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
