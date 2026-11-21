import 'package:flutter/material.dart';

/// Refresh only when the pointer gesture starts at the top of this list.
///
/// The refresh does not rebuild a page through navigation and never activates
/// because a mid-list drag or programmatic jump happens to reach offset zero.
class CommunityTopEdgeRefresh extends StatefulWidget {
  const CommunityTopEdgeRefresh({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
  });

  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;

  @override
  State<CommunityTopEdgeRefresh> createState() =>
      _CommunityTopEdgeRefreshState();
}

class _CommunityTopEdgeRefreshState extends State<CommunityTopEdgeRefresh> {
  bool _gestureStartedAtTop = false;
  bool _refreshedInGesture = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return RefreshIndicator(
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      notificationPredicate: (notification) =>
          notification.depth == 0 &&
          notification.metrics.axis == Axis.vertical &&
          notification.metrics.extentBefore == 0 &&
          _gestureStartedAtTop &&
          !_refreshedInGesture,
      onRefresh: () {
        if (!_gestureStartedAtTop || _refreshedInGesture) {
          return Future<void>.value();
        }
        _refreshedInGesture = true;
        _gestureStartedAtTop = false;
        return widget.onRefresh();
      },
      child: Listener(
        onPointerDown: (_) {
          final controller = widget.controller;
          _gestureStartedAtTop =
              !controller.hasClients ||
              controller.position.pixels <=
                  controller.position.minScrollExtent + 0.5;
          _refreshedInGesture = false;
        },
        onPointerCancel: (_) => _gestureStartedAtTop = false,
        child: widget.child,
      ),
    );
  }
}
