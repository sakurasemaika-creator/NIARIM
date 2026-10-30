import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bounds the artwork while keeping every action reachable on short screens.
class ExportedWorkPreviewLayout extends StatelessWidget {
  const ExportedWorkPreviewLayout({
    super.key,
    required this.content,
    required this.shareLabel,
    required this.closeLabel,
    required this.onShare,
    required this.onClose,
    this.contentAspectRatio = 16 / 9,
  });

  final Widget content;
  final String shareLabel;
  final String closeLabel;
  final VoidCallback onShare;
  final VoidCallback onClose;
  final double contentAspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(0.0, constraints.maxWidth - 24);
      final ratio = contentAspectRatio.isFinite && contentAspectRatio > 0
          ? contentAspectRatio
          : 16 / 9;
      final height = math.min(width / ratio, constraints.maxHeight * .6);
      final foreground =
          Theme.of(context).popupMenuTheme.textStyle?.color ??
          Theme.of(context).colorScheme.onSurface;
      return SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: width, height: height, child: content),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(shareLabel),
                    onPressed: onShare,
                  ),
                  TextButton(onPressed: onClose, child: Text(closeLabel)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
