import 'package:flutter/material.dart';

/// Canvas-size inputs need room for translated labels and validation text.
class CanvasSizeFields extends StatelessWidget {
  const CanvasSizeFields({
    super.key,
    required this.availableWidth,
    required this.widthField,
    required this.heightField,
    this.separator = const SizedBox(width: 12),
  });

  final double availableWidth;
  final Widget widthField;
  final Widget heightField;
  final Widget separator;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (availableWidth < 280 * scale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [widthField, heightField],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: widthField),
        separator,
        Expanded(child: heightField),
      ],
    );
  }
}
