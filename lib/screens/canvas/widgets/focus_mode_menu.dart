import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A movable, collapsible and resizable control surface used while the canvas
/// is in a focused editing mode.
///
/// It starts at the bottom-left of its available canvas viewport. The header
/// has three separate hit targets: minimize at the left, move in the centre,
/// and resize at the right. The body stays mounted while minimized so live
/// edits and previews are preserved.
class FocusModeMenu extends StatefulWidget {
  const FocusModeMenu({
    super.key,
    required this.child,
    required this.collapseTooltip,
    required this.expandTooltip,
    this.maxWidth = 360,
    this.fillWidth = false,
    this.scrollBodyOnResize = true,
  });

  final Widget child;
  final String collapseTooltip;
  final String expandTooltip;

  /// Initial width. The resize handle can grow the menu up to the viewport.
  final double maxWidth;

  /// Kept for call-site clarity: bottom control bars start at [maxWidth].
  final bool fillWidth;

  /// Selection, filter and mesh controls can scroll when the user makes the
  /// window shorter. ColorAdjustSheet manages its own bounded inner scroll
  /// view and therefore leaves this false.
  final bool scrollBodyOnResize;

  @override
  State<FocusModeMenu> createState() => _FocusModeMenuState();
}

class _FocusModeMenuState extends State<FocusModeMenu> {
  static const double _edgeInset = 12;
  static const double _headerHeight = 44;
  static const double _minMenuWidth = 180;
  static const double _minMenuHeight = 124;
  static const double _maxMenuWidth = 640;

  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  double _left = _edgeInset;
  double _bottom = _edgeInset;
  double? _menuWidth;
  double? _menuHeight;
  bool _minimized = false;
  Offset? _moveStartPosition;
  Offset? _moveStartOffset;
  Offset? _resizeStartPosition;
  Size? _resizeStartSize;

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
        // Freeze the current natural size when the user first minimizes.
        // Restoring then returns to exactly the same dimensions.
        _menuWidth ??= measured.width;
        _menuHeight ??= measured.height;
      }
      _minimized = !_minimized;
    });
  }

  void _startMoving(DragStartDetails details) {
    _moveStartPosition = details.globalPosition;
    _moveStartOffset = Offset(_left, _bottom);
  }

  void _moveBy(
    DragUpdateDetails details, {
    required Size expandedSize,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final startPosition = _moveStartPosition;
    final startOffset = _moveStartOffset;
    if (startPosition == null || startOffset == null) return;
    // Use the full pointer displacement from pan start. DragUpdateDetails.delta
    // omits Flutter's initial touch-slop distance and made the menu lag behind.
    final delta = details.globalPosition - startPosition;
    final maxLeft = math
        .max(
          _edgeInset,
          viewportWidth - expandedSize.width - _edgeInset,
        )
        .toDouble();
    final maxBottom = math
        .max(
          _edgeInset,
          viewportHeight - expandedSize.height - _edgeInset,
        )
        .toDouble();

    setState(() {
      _left = (startOffset.dx + delta.dx)
          .clamp(_edgeInset, maxLeft)
          .toDouble();
      // Screen Y grows downward; a positive bottom offset moves the menu up.
      _bottom = (startOffset.dy - delta.dy)
          .clamp(_edgeInset, maxBottom)
          .toDouble();
    });
  }

  void _startResizing(DragStartDetails details, Size expandedSize) {
    _resizeStartPosition = details.globalPosition;
    // Read the live laid-out size at gesture start. The size calculated during
    // build may still be the provisional fallback on a first frame.
    final measured = _measuredSurfaceSize ?? expandedSize;
    _resizeStartSize = Size(
      _menuWidth ?? measured.width,
      _menuHeight ?? measured.height,
    );
  }

  void _resizeBy(
    DragUpdateDetails details, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final startPosition = _resizeStartPosition;
    final startSize = _resizeStartSize;
    if (startPosition == null || startSize == null) return;
    final pointerDelta = details.globalPosition - startPosition;
    // Full pointer displacement keeps resizing one-to-one after touch slop.
    final delta = Offset(pointerDelta.dx, -pointerDelta.dy);
    final maxWidth = math
        .max(
          0.0,
          math.min(_maxMenuWidth, viewportWidth - _edgeInset * 2),
        )
        .toDouble();
    final minWidth = math.min(_minMenuWidth, maxWidth).toDouble();
    final maxHeight = math
        .max(0.0, viewportHeight - _edgeInset * 2)
        .toDouble();
    final minHeight = math.min(_minMenuHeight, maxHeight).toDouble();

    final nextWidth = (startSize.width + delta.dx)
        .clamp(minWidth, maxWidth)
        .toDouble();
    // Dragging the top-right grip upward increases the window height.
    final nextHeight = (startSize.height + delta.dy)
        .clamp(minHeight, maxHeight)
        .toDouble();

    final maxLeft = math
        .max(
          _edgeInset,
          viewportWidth - nextWidth - _edgeInset,
        )
        .toDouble();
    final maxBottom = math
        .max(
          _edgeInset,
          viewportHeight - nextHeight - _edgeInset,
        )
        .toDouble();

    setState(() {
      _menuWidth = nextWidth;
      _menuHeight = nextHeight;
      // Resizing from the top-right keeps the bottom-left corner fixed unless
      // the viewport boundary requires the menu to move back inside.
      _left = _left.clamp(_edgeInset, maxLeft).toDouble();
      _bottom = _bottom.clamp(_edgeInset, maxBottom).toDouble();
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
        final maxWidth = math
            .max(
              0.0,
              math.min(_maxMenuWidth, viewportWidth - _edgeInset * 2),
            )
            .toDouble();
        final minWidth = math.min(_minMenuWidth, maxWidth).toDouble();
        final initialWidth = math.min(widget.maxWidth, maxWidth).toDouble();
        final menuWidth = (_menuWidth ?? initialWidth)
            .clamp(minWidth, maxWidth)
            .toDouble();

        final maxMenuHeight = math
            .max(0.0, viewportHeight - _edgeInset * 2)
            .toDouble();
        final minMenuHeight = math.min(_minMenuHeight, maxMenuHeight).toDouble();
        final bodyMaxHeight = math
            .max(0.0, maxMenuHeight - _headerHeight)
            .toDouble();
        final measured = _measuredSurfaceSize;
        final estimatedHeight = math.min(maxMenuHeight, 420).toDouble();
        final expandedHeight = (_menuHeight ?? measured?.height ?? estimatedHeight)
            .clamp(minMenuHeight, maxMenuHeight)
            .toDouble();
        final expandedSize = Size(menuWidth, expandedHeight);

        // While minimized, clamp against the restored size rather than the
        // small header pill so expanding can never happen off-screen.
        final maxLeft = math
            .max(
              _edgeInset,
              viewportWidth - expandedSize.width - _edgeInset,
            )
            .toDouble();
        final maxBottom = math
            .max(
              _edgeInset,
              viewportHeight - expandedSize.height - _edgeInset,
            )
            .toDouble();
        final left = _left.clamp(_edgeInset, maxLeft).toDouble();
        final bottom = _bottom.clamp(_edgeInset, maxBottom).toDouble();

        final bodyHeight = _menuHeight == null
            ? null
            : (_menuHeight! - _headerHeight)
                  .clamp(0.0, bodyMaxHeight)
                  .toDouble();

        // Keep the content subtree under a stable GlobalKey when the
        // resizable viewport adds/removes its scroll view. Stateful editors
        // (notably color adjustment and live filters) must not be recreated.
        final content = KeyedSubtree(
          key: _contentKey,
          child: SizedBox(width: menuWidth, child: widget.child),
        );
        final Widget body = SizedBox(
          width: menuWidth,
          height: bodyHeight,
          child: widget.scrollBodyOnResize
              ? (bodyHeight == null
                    ? content
                    : SingleChildScrollView(
                        primary: false,
                        child: content,
                      ))
              : Align(
                  alignment: Alignment.topLeft,
                  heightFactor: bodyHeight == null ? 1 : null,
                  child: content,
                ),
        );

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
                  surfaceTintColor: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
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
                          width: menuWidth,
                          height: _headerHeight,
                          child: Stack(
                            children: [
                              // Only the centred grip moves the window.
                              Positioned(
                                left: _headerHeight,
                                right: _headerHeight,
                                top: 0,
                                bottom: 0,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'focus-mode-menu-drag-handle',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: _startMoving,
                                    onPanUpdate: (details) => _moveBy(
                                      details,
                                      expandedSize: expandedSize,
                                      viewportWidth: viewportWidth,
                                      viewportHeight: viewportHeight,
                                    ),
                                    onPanEnd: (_) {
                                      _moveStartPosition = null;
                                      _moveStartOffset = null;
                                    },
                                    onPanCancel: () {
                                      _moveStartPosition = null;
                                      _moveStartOffset = null;
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
                              // Minimize/restore stays fixed at the top-left.
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: _headerHeight,
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
                              // Drag right/down to widen/shorten; drag left/up
                              // to narrow/tall. The bottom-left corner anchors.
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: _headerHeight,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpRight,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'focus-mode-menu-resize-handle',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (details) =>
                                        _startResizing(details, expandedSize),
                                    onPanUpdate: (details) => _resizeBy(
                                      details,
                                      viewportWidth: viewportWidth,
                                      viewportHeight: viewportHeight,
                                    ),
                                    onPanEnd: (_) {
                                      _resizeStartPosition = null;
                                      _resizeStartSize = null;
                                    },
                                    onPanCancel: () {
                                      _resizeStartPosition = null;
                                      _resizeStartSize = null;
                                    },
                                    child: Center(
                                      child: SvgPicture.string(
                                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 19H5v-6"/><path d="M13 5h6v6"/><path d="M19 5 5 19"/></svg>',
                                        width: 18,
                                        height: 18,
                                        colorFilter: ColorFilter.mode(
                                          scheme.onSurfaceVariant.withValues(
                                            alpha: 0.62,
                                          ),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
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
                            child: Visibility(
                              visible: !_minimized,
                              maintainState: true,
                              maintainAnimation: true,
                              child: body,
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
