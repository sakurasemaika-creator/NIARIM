import '../models/canvas_dock_panel.dart';

/// Transient fit for one column. Automatic folding never changes saved manual
/// collapse preferences or preferred window heights.
class DesktopDockLayout {
  const DesktopDockLayout({
    required this.automaticallyCollapsed,
    required this.bodyHeights,
  });

  final Set<CanvasDockPanel> automaticallyCollapsed;
  final Map<CanvasDockPanel, double> bodyHeights;

  bool isCollapsed(CanvasDockPanel panel, bool manuallyCollapsed) =>
      manuallyCollapsed || automaticallyCollapsed.contains(panel);
}

/// Fits open desktop dock windows into the usable canvas height.
///
/// This height comes from the same Expanded row as the canvas, so it already
/// excludes the timeline/frame strip. A column scrolls only if there isn't
/// enough room even for minimum-height tool bodies.
class DesktopDockColumnFit {
  const DesktopDockColumnFit._();

  static const double titleHeight = 34;
  static const double resizeGripHeight = 22;
  static const double collapsedHeight = 48;
  static const double gap = 8;
  static const double minimumBodyHeight = 80;

  /// Left-handed mode mirrors the visual sides without mutating saved
  /// logical dock orders. Drag/drop uses this mapping in reverse.
  static bool storedRightForPhysicalSide({
    required bool physicalRight,
    required bool leftHanded,
  }) => physicalRight != leftHanded;

  /// First shrink expanded bodies to their minimum, then temporarily fold the
  /// least recently used panels until everything fits. If even the folded
  /// icons cannot fit, the caller's existing column scroll remains available.
  ///
  /// The active panel is never folded automatically. Its remaining minimum
  /// body can instead scroll if there is literally no room for it.
  static DesktopDockLayout layout({
    required double availableHeight,
    required List<CanvasDockPanel> visible,
    required bool Function(CanvasDockPanel) isManuallyCollapsed,
    required double Function(CanvasDockPanel) preferredHeight,
    required bool autoCollapseEnabled,
    Map<CanvasDockPanel, int> lastUsed = const {},
    CanvasDockPanel? activePanel,
    double extraFixedHeight = 0,
  }) {
    final auto = <CanvasDockPanel>{};

    bool collapsed(CanvasDockPanel panel) =>
        isManuallyCollapsed(panel) || auto.contains(panel);

    double minimumRequiredHeight() {
      final expanded = visible.where((p) => !collapsed(p)).length;
      final folded = visible.length - expanded;
      final gaps = visible.length > 1 ? (visible.length - 1) * gap : 0.0;
      return expanded * (titleHeight + resizeGripHeight + minimumBodyHeight) +
          folded * collapsedHeight +
          gaps +
          extraFixedHeight;
    }

    if (autoCollapseEnabled &&
        availableHeight.isFinite &&
        availableHeight > 0) {
      // For equally unused windows, retain the earlier/top windows longer.
      // A deliberately opened/active window is protected regardless of age.
      final candidates = <({CanvasDockPanel panel, int index})>[
        for (var i = 0; i < visible.length; i++)
          if (!isManuallyCollapsed(visible[i]) && visible[i] != activePanel)
            (panel: visible[i], index: i),
      ];
      candidates.sort((a, b) {
        final age = (lastUsed[a.panel] ?? 0).compareTo(lastUsed[b.panel] ?? 0);
        return age != 0 ? age : b.index.compareTo(a.index);
      });
      for (final candidate in candidates) {
        if (minimumRequiredHeight() <= availableHeight) break;
        auto.add(candidate.panel);
      }
    }

    return DesktopDockLayout(
      automaticallyCollapsed: auto,
      bodyHeights: bodyHeights(
        availableHeight: availableHeight,
        visible: visible,
        isCollapsed: collapsed,
        preferredHeight: preferredHeight,
        extraFixedHeight: extraFixedHeight,
      ),
    );
  }

  /// Keeps both dock columns inside the viewport, preserving space for the
  /// vertical toolbar, resize grips and a usable canvas. A folded column
  /// keeps its 52px tab instead of being squeezed smaller than its buttons.
  static ({double left, double right}) columnWidths({
    required double availableWidth,
    required double leftDesired,
    required double rightDesired,
    required bool leftVisible,
    required bool rightVisible,
    double toolbarWidth = 60,
    double canvasWidth = 160,
  }) {
    var left = leftVisible ? leftDesired : 0.0;
    var right = rightVisible ? rightDesired : 0.0;
    final leftGrip = leftVisible && left > 52 ? 18.0 : 0.0;
    final rightGrip = rightVisible && right > 52 ? 18.0 : 0.0;
    final available =
        (availableWidth - toolbarWidth - canvasWidth - leftGrip - rightGrip)
            .clamp(0.0, double.infinity);

    if (left + right <= available) return (left: left, right: right);

    final leftFixed = leftVisible && left <= 52 ? left : 0.0;
    final rightFixed = rightVisible && right <= 52 ? right : 0.0;
    final variable = left + right - leftFixed - rightFixed;
    if (variable <= 0) return (left: left, right: right);
    final fraction = ((available - leftFixed - rightFixed) / variable).clamp(
      0.0,
      1.0,
    );
    left = leftFixed > 0 ? leftFixed : left * fraction;
    right = rightFixed > 0 ? rightFixed : right * fraction;
    return (left: left, right: right);
  }

  static Map<CanvasDockPanel, double> bodyHeights({
    required double availableHeight,
    required List<CanvasDockPanel> visible,
    required bool Function(CanvasDockPanel) isCollapsed,
    required double Function(CanvasDockPanel) preferredHeight,
    double extraFixedHeight = 0,
  }) {
    final expanded = visible.where((p) => !isCollapsed(p)).toList();
    if (expanded.isEmpty) return const {};
    final preferred = {for (final p in expanded) p: preferredHeight(p)};
    if (!availableHeight.isFinite || availableHeight <= 0) return preferred;

    final foldedCount = visible.length - expanded.length;
    final chrome =
        expanded.length * (titleHeight + resizeGripHeight) +
        foldedCount * collapsedHeight +
        (visible.length > 1 ? (visible.length - 1) * gap : 0) +
        extraFixedHeight;
    final budget = availableHeight - chrome;
    final minHeight = minimumBodyHeight
        .clamp(
          0.0,
          (availableHeight - titleHeight - resizeGripHeight).clamp(
            1.0,
            minimumBodyHeight,
          ),
        )
        .toDouble();
    if (budget < expanded.length * minHeight) {
      // If there are more windows than can physically fit, their outer column
      // stays clipped to the canvas and becomes scrollable.
      return {for (final p in expanded) p: minHeight};
    }

    final desiredTotal = preferred.values.fold<double>(0, (s, v) => s + v);
    if (desiredTotal <= budget) return preferred;

    final assigned = <CanvasDockPanel, double>{};
    final pending = expanded.toSet();
    var left = budget;
    while (pending.isNotEmpty) {
      final weight = pending.fold<double>(0, (s, p) => s + preferred[p]!);
      final undersized = pending
          .where((p) => preferred[p]! / weight * left < minHeight)
          .toList();
      if (undersized.isEmpty) {
        for (final p in pending) {
          assigned[p] = preferred[p]! / weight * left;
        }
        break;
      }
      for (final p in undersized) {
        assigned[p] = minHeight;
        left -= minHeight;
        pending.remove(p);
      }
    }
    return assigned;
  }
}
