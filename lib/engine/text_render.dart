import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/text_object.dart';

/// テキストレイヤーのラスタライズ（仕様書15：テキストツール・フォント仕様）。
/// TextObjectをTextPainterで描画し、キャンバスサイズのRGBAバッファへ焼き込む。
/// 編集時のみ文字情報を保持し、表示・書き出し時はこの結果（キャッシュ画像）を
/// 使うというラスター専用アプリの方針に沿う。
///
/// 縦書き（TextWritingDirection.vertical）はFlutter標準のTextPainterでは
/// 直接サポートされないため、今回のスコープでは横書きへフォールバックする
/// （既知の未対応・将来対応）。
Future<Uint8List?> rasterizeTextObject(TextObject text, int canvasWidth, int canvasHeight) async {
  final fontStyle = text.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal;
  final fontWeight = text.isBold ? ui.FontWeight.bold : ui.FontWeight.normal;

  final style = ui.TextStyle(
    color: text.color.withValues(alpha: text.color.a * text.opacity),
    fontSize: text.fontSize,
    fontFamily: text.fontFamily,
    fontStyle: fontStyle,
    fontWeight: fontWeight,
    letterSpacing: text.letterSpacing,
    height: text.lineHeight,
  );

  final paragraphStyle = ui.ParagraphStyle(
    textAlign: text.align,
  );
  final builder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(style)
    ..addText(text.text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 2000));

  final textWidth = paragraph.longestLine;
  final textHeight = paragraph.height;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();
  // position（レイヤー上の配置基準点）を中心に回転・拡大を適用する
  final centerX = text.position.dx + textWidth / 2;
  final centerY = text.position.dy + textHeight / 2;
  canvas.translate(centerX, centerY);
  canvas.rotate(text.rotation * math.pi / 180);
  canvas.scale(text.scale);
  canvas.translate(-textWidth / 2, -textHeight / 2);

  // アウトライン（縁取り）：本文の下に少しずつずらしたコピーを重ねて縁取りを近似する
  // （Skiaのstroke-textはParagraphBuilderで直接指定できないための簡易実装）。
  final outline = text.outline;
  if (outline != null && outline.enabled && outline.width > 0) {
    final outlineStyle = ui.TextStyle(
      color: outline.color,
      fontSize: text.fontSize,
      fontFamily: text.fontFamily,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      letterSpacing: text.letterSpacing,
      height: text.lineHeight,
    );
    final outlineBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(outlineStyle)
      ..addText(text.text);
    final outlineParagraph = outlineBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 2000));
    const steps = 8;
    for (int i = 0; i < steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final dx = outline.width * math.cos(angle);
      final dy = outline.width * math.sin(angle);
      canvas.drawParagraph(outlineParagraph, ui.Offset(dx, dy));
    }
  }

  canvas.drawParagraph(paragraph, ui.Offset.zero);
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
