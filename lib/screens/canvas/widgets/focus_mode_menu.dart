import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/font_fallback.dart';

/// The current focus-window header can host an action supplied by its child.
/// The child registers a builder so its action can live in the shared header
/// without moving its editing state out of the panel.
class FocusModeMenuController extends ChangeNotifier {
  WidgetBuilder? _headerMenuBuilder;

  WidgetBuilder? get headerMenuBuilder => _headerMenuBuilder;

  void setHeaderMenuBuilder(WidgetBuilder? builder) {
    if (identical(_headerMenuBuilder, builder)) return;
    _headerMenuBuilder = builder;
    notifyListeners();
  }
}

/// Exposes the shared header controller to the panel hosted inside the window.
class FocusModeMenuScope extends InheritedWidget {
  const FocusModeMenuScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final FocusModeMenuController controller;

  static FocusModeMenuController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FocusModeMenuScope>()?.controller;

  @override
  bool updateShouldNotify(FocusModeMenuScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

/// A movable, collapsible and resizable control surface used while the canvas
/// is in a focused editing mode.
///
/// It starts at the bottom-right of its available canvas viewport. A single
/// header row holds resize, minimize, the title/move grip, an optional panel
/// menu and close. The body stays mounted while minimized so live edits and
/// previews are preserved.
class FocusModeMenu extends StatefulWidget {
  const FocusModeMenu({
    super.key,
    required this.child,
    required this.collapseTooltip,
    required this.expandTooltip,
    this.title = '',
    this.onClose,
    this.closeTooltip,
    this.maxWidth = 360,
    this.fillWidth = false,
    this.scrollBodyOnResize = true,
  });

  final Widget child;
  final String collapseTooltip;
  final String expandTooltip;
  final String title;
  final VoidCallback? onClose;
  final String? closeTooltip;

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
  static const double _headerHeight = 48;
  static const double _minMenuWidth = 180;
  static const double _minMenuHeight = 124;
  static const double _maxMenuWidth = 640;

  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  double? _left;
  double _bottom = _edgeInset;
  double? _menuWidth;
  double? _menuHeight;
  bool _minimized = false;
  Offset? _moveStartPosition;
  Offset? _moveStartOffset;
  Offset? _resizeStartPosition;
  Size? _resizeStartSize;
  double? _resizeStartLeft;
  double? _resizeStartBottom;
  final FocusModeMenuController _menuController = FocusModeMenuController();

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

  void _startMoving(DragStartDetails details, {required double left}) {
    _moveStartPosition = details.globalPosition;
    _moveStartOffset = Offset(left, _bottom);
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

  void _startResizing(
    DragStartDetails details,
    Size expandedSize, {
    required double left,
  }) {
    _resizeStartPosition = details.globalPosition;
    // Read the live laid-out size at gesture start. The size calculated during
    // build may still be the provisional fallback on a first frame.
    final measured = _measuredSurfaceSize ?? expandedSize;
    _resizeStartSize = Size(
      _menuWidth ?? measured.width,
      _menuHeight ?? measured.height,
    );
    _resizeStartLeft = left;
    _resizeStartBottom = _bottom;
  }

  void _resizeBy(
    DragUpdateDetails details, {
    required double viewportHeight,
  }) {
    final startPosition = _resizeStartPosition;
    final startSize = _resizeStartSize;
    final startLeft = _resizeStartLeft;
    final startBottom = _resizeStartBottom;
    if (startPosition == null ||
        startSize == null ||
        startLeft == null ||
        startBottom == null) {
      return;
    }

    final pointerDelta = details.globalPosition - startPosition;
    // The top-left grip is mirrored: drag left/up to grow. The bottom-right
    // corner stays anchored, so the window's left/top edges move with the grip.
    final maxRight = startLeft + startSize.width;
    final maxWidth = math
        .max(0.0, math.min(_maxMenuWidth, maxRight - _edgeInset))
        .toDouble();
    final minWidth = math.min(_minMenuWidth, maxWidth).toDouble();
    final bottomScreen = viewportHeight - startBottom;
    final maxHeight = math.max(0.0, bottomScreen - _edgeInset).toDouble();
    final minHeight = math.min(_minMenuHeight, maxHeight).toDouble();

    final nextWidth = (startSize.width - pointerDelta.dx)
        .clamp(minWidth, maxWidth)
        .toDouble();
    final nextHeight = (startSize.height - pointerDelta.dy)
        .clamp(minHeight, maxHeight)
        .toDouble();
    final nextLeft = maxRight - nextWidth;

    setState(() {
      _menuWidth = nextWidth;
      _menuHeight = nextHeight;
      _left = nextLeft;
      _bottom = startBottom;
    });
  }

  Widget _buildMoveDragTarget({
    required Key key,
    required Widget child,
    required double left,
    required Size expandedSize,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _startMoving(details, left: left),
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
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FocusModeMenuScope(
      controller: _menuController,
      child: LayoutBuilder(
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
        // Keep the four edge actions inside the header even when the user
        // narrows the window to its minimum width.
        final headerControlWidth = menuWidth < 240
            ? 36.0
            : menuWidth < 300
            ? 42.0
            : _headerHeight;

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
        final initialLeft = math
            .max(_edgeInset, viewportWidth - expandedSize.width - _edgeInset)
            .toDouble();
        final left = (_left ?? initialLeft)
            .clamp(_edgeInset, maxLeft)
            .toDouble();
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
                        ListenableBuilder(
                          listenable: _menuController,
                          builder: (context, _) {
                            final headerMenuBuilder =
                                _menuController.headerMenuBuilder;
                            return SizedBox(
                              width: menuWidth,
                              height: _headerHeight,
                              child: Row(
                                children: [
                                  // Top-left resize handle: drag left/up to grow.
                                  SizedBox(
                                    width: headerControlWidth,
                                    height: _headerHeight,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.resizeUpLeft,
                                      child: GestureDetector(
                                        key: const ValueKey(
                                          'focus-mode-menu-resize-handle',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (details) => _startResizing(
                                          details,
                                          expandedSize,
                                          left: left,
                                        ),
                                        onPanUpdate: (details) => _resizeBy(
                                          details,
                                          viewportHeight: viewportHeight,
                                        ),
                                        onPanEnd: (_) {
                                          _resizeStartPosition = null;
                                          _resizeStartSize = null;
                                          _resizeStartLeft = null;
                                          _resizeStartBottom = null;
                                        },
                                        onPanCancel: () {
                                          _resizeStartPosition = null;
                                          _resizeStartSize = null;
                                          _resizeStartLeft = null;
                                          _resizeStartBottom = null;
                                        },
                                        child: Center(
                                          child: SvgPicture.string(
                                            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 19h6v-6"/><path d="M11 5H5v6"/><path d="M5 5 19 19"/></svg>',
                                            key: const ValueKey(
                                              'focus-mode-menu-resize-handle-icon',
                                            ),
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
                                  // Minimize/restore sits immediately beside resize.
                                  SizedBox(
                                    width: headerControlWidth,
                                    height: _headerHeight,
                                    child: IconButton(
                                      key: const ValueKey(
                                        'focus-mode-menu-toggle',
                                      ),
                                      tooltip: _minimized
                                          ? widget.expandTooltip
                                          : widget.collapseTooltip,
                                      visualDensity: VisualDensity.compact,
                                      constraints: BoxConstraints.tightFor(
                                        width: headerControlWidth,
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
                                  // The title is a wide drag target of its own.
                                  Expanded(
                                    child: _buildMoveDragTarget(
                                      key: const ValueKey(
                                        'focus-mode-menu-drag-handle',
                                      ),
                                      left: left,
                                      expandedSize: expandedSize,
                                      viewportWidth: viewportWidth,
                                      viewportHeight: viewportHeight,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          // Pointer input passes through the
                                          // title to the surrounding drag target.
                                          child: IgnorePointer(
                                            ignoring: true,
                                            child: Text(
                                              widget.title,
                                              key: const ValueKey(
                                                'focus-mode-menu-title',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: localizedHeadingStyle(
                                                context,
                                                TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Keep the move grip directly beside the
                                  // contextual menu, not in the title area.
                                  SizedBox(
                                    width: headerControlWidth,
                                    height: _headerHeight,
                                    child: _buildMoveDragTarget(
                                      key: const ValueKey(
                                        'focus-mode-menu-move-grip-handle',
                                      ),
                                      left: left,
                                      expandedSize: expandedSize,
                                      viewportWidth: viewportWidth,
                                      viewportHeight: viewportHeight,
                                      child: Center(
                                        child: Container(
                                          key: const ValueKey(
                                            'focus-mode-menu-move-grip',
                                          ),
                                          width: 32,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: scheme.onSurfaceVariant
                                                .withValues(alpha: 0.48),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Panels without contextual actions omit this
                                  // slot entirely, keeping the close button adjacent.
                                  if (headerMenuBuilder != null)
                                    SizedBox(
                                      width: headerControlWidth,
                                      height: _headerHeight,
                                      child: headerMenuBuilder(context),
                                    ),
                                  if (widget.onClose != null)
                                    SizedBox(
                                      width: headerControlWidth,
                                      height: _headerHeight,
                                      child: IconButton(
                                        key: const ValueKey(
                                          'focus-mode-menu-close',
                                        ),
                                        tooltip: widget.closeTooltip ?? '',
                                        visualDensity: VisualDensity.compact,
                                        constraints: BoxConstraints.tightFor(
                                          width: headerControlWidth,
                                          height: _headerHeight,
                                        ),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: widget.onClose,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
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
      ),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }
}