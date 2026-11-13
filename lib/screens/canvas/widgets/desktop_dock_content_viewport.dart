import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/docked_panel_scope.dart';

/// The body of a desktop dock is resized in two deliberately different ways.
///
/// [DesktopDockContentMode.fit] is for complete visual objects (colour wheel,
/// canvas navigator, reference artwork). Width AND height determine the scale,
/// so the important visual object is never cropped by a narrow/short window.
///
/// [DesktopDockContentMode.scroll] is for collections (brushes, layers, tools).
/// Only width determines the scale. A smaller height reveals a scrollbar
/// instead of shrinking each row, and a larger height shows more rows.
enum DesktopDockContentMode { fit, scroll }

class DesktopDockContentViewport extends StatelessWidget {
  const DesktopDockContentViewport({
    super.key,
    required this.child,
    required this.mode,
    this.designWidth = 288,
    this.minimumContentHeight = 280,
  });

  final Widget child;
  final DesktopDockContentMode mode;
  final double designWidth;
  final double minimumContentHeight;

  @override
  Widget build(BuildContext context) {
    // Desktop dock content is laid out at its real column width. Scaling a
    // mobile-sized card left large blank margins and duplicated window chrome.
    if (DockedPanelScope.of(context)) {
      return SizedBox.expand(
        key: const ValueKey('desktopDockContentScale'),
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return child;
        }

        final widthScale = width / designWidth;
        // fit mode keeps the first, complete object (e.g. HSV wheel and its
        // heading) in view; further advanced controls can still scroll inside.
        final desiredScale = mode == DesktopDockContentMode.fit
            ? math.min(widthScale, height / minimumContentHeight)
            : widthScale;
        final scale = desiredScale.clamp(0.05, 3.0).toDouble();
        final contentHeight = math.max(height / scale, minimumContentHeight);
        final visualWidth = designWidth * scale;
        final visualHeight = contentHeight * scale;
        // Matching layout dimensions on both axes means BoxFit.fill applies
        // exactly the SAME scale in X and Y; the colour wheel stays circular,
        // pointer coordinates remain accurate and list rows keep their ratio.
        final scaledChild = SizedBox(
          width: visualWidth,
          height: visualHeight,
          child: FittedBox(
            key: const ValueKey('desktopDockContentScale'),
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: designWidth,
              height: contentHeight,
              child: child,
            ),
          ),
        );

        if (mode == DesktopDockContentMode.scroll) {
          return ClipRect(
            child: Scrollbar(
              child: SingleChildScrollView(
                key: const ValueKey('desktopDockVerticalScroll'),
                primary: false,
                child: Align(alignment: Alignment.topLeft, child: scaledChild),
              ),
            ),
          );
        }
        return ClipRect(
          child: Align(alignment: Alignment.topCenter, child: scaledChild),
        );
      },
    );
  }
}
