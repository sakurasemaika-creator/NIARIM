import 'dart:ui';

class TextObject {
  final String id;
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final bool isBold;
  final bool isItalic;
  final double lineHeight;
  final double letterSpacing;
  final TextWritingDirection direction;
  final TextAlign align;
  final Offset position;
  final double rotation;
  final double scale;
  final double opacity;
  final TextOutline? outline;

  const TextObject({
    required this.id,
    required this.text,
    this.fontFamily = 'Roboto',
    this.fontSize = 24,
    this.color = const Color(0xFF000000),
    this.isBold = false,
    this.isItalic = false,
    this.lineHeight = 1.2,
    this.letterSpacing = 0,
    this.direction = TextWritingDirection.horizontal,
    this.align = TextAlign.left,
    this.position = Offset.zero,
    this.rotation = 0,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.outline,
  });
}

class TextOutline {
  final bool enabled;
  final Color color;
  final double width;

  const TextOutline({
    this.enabled = false,
    this.color = const Color(0xFF000000),
    this.width = 3,
  });
}

enum TextWritingDirection { horizontal, vertical }
