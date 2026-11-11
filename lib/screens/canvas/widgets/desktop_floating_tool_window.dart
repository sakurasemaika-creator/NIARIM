import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/material.dart';

import '../../../utils/desktop_window_snap.dart';

/// Optional detachable PC/DeX tool window. Undetached windows stay in the
/// existing dock columns; detached ones may overlap, separate and snap near
/// each other's edges without joining or losing their independently saved
/// positions. The plain 1px outline is intentional (never a black shadow).
class DesktopFloatingToolWindow extends StatefulWidget {
  const DesktopFloatingToolWindow({
    super.key,
    required this.id,
    required this.title,
    required this.position,
    required this.size,
    required this.bounds,
    required this.neighbours,
    required this.onMoved,
    required this.onBringToFront,
    required this.onRedock,
    required this.onClose,
    required this.child,
  });

  final String id;
  final String title;
  final Offset position;
  final Size size;
  final Size bounds;
  final List<Rect> neighbours;
  final ValueChanged<Offset> onMoved;
  final VoidCallback onBringToFront;
  final VoidCallback onRedock;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<DesktopFloatingToolWindow> createState() =>
      _DesktopFloatingToolWindowState();
}

class _DesktopFloatingToolWindowState
    extends State<DesktopFloatingToolWindow> {
  Offset? _livePosition;
  Offset? _dragStart;
  Offset? _pointerStart;

  Offset _bounded(Offset raw) => Offset(
    raw.dx.clamp(0.0, math.max(0.0, widget.bounds.width - widget.size.width)),
    raw.dy.clamp(0.0, math.max(0.0, widget.bounds.height - widget.size.height)),
  );

  @override
  Widget build(BuildContext context) {
    final location = _bounded(_livePosition ?? widget.position);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey('desktopFloating-${widget.id}'),
      left: location.dx,
      top: location.dy,
      width: widget.size.width,
      height: widget.size.height,
      child: Material(
        color: scheme.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            GestureDetector(
              key: ValueKey('desktopFloatingDrag-${widget.id}'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _dragStart = location;
                _pointerStart = details.globalPosition;
                widget.onBringToFront();
              },
              onPanUpdate: (details) {
                final start = _dragStart ?? location;
                final pointer = _pointerStart ?? details.globalPosition;
                final desired = start + details.globalPosition - pointer;
                final snapped = snapDesktopWindow(
                  desired, widget.size, widget.neighbours,
                );
                setState(() => _livePosition = _bounded(snapped));
              },
              onPanEnd: (_) {
                final position = _livePosition;
                _dragStart = null;
                _pointerStart = null;
                if (position != null) widget.onMoved(position);
                setState(() => _livePosition = null);
              },
              onPanCancel: () {
                _dragStart = null;
                _pointerStart = null;
                setState(() => _livePosition = null);
              },
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    const SizedBox(width: 7),
                    Icon(Icons.drag_indicator, size: 18,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(widget.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      key: ValueKey('desktopFloatingRedock-${widget.id}'),
                      tooltip: 'ドックに戻す',
                      icon: const Icon(Icons.vertical_align_center, size: 18),
                      onPressed: widget.onRedock,
                    ),
                    IconButton(
                      key: ValueKey('desktopFloatingClose-${widget.id}'),
                      tooltip: '閉じる',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
