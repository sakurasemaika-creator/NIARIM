import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/text_object.dart';

/// テキストレイヤーのラスタライズ（仕様書15：テキストツール・フォント仕様）。
/// TextObjectをキャンバスサイズのRGBAバッファへ焼き込む。編集時のみ文字情報を
/// 保持し、表示・書き出し時はこの結果（キャッシュ画像）を使うというラスター専用
/// アプリの方針に沿う。横書き・縦書きの両方に対応する（仕様書15：横書き・縦書き
/// 切替）。
Future<Uint8List?> rasterizeTextObject(TextObject text, int canvasWidth, int canvasHeight) async {
  if (text.direction == TextWritingDirection.vertical) {
    return _rasterizeVertical(text, canvasWidth, canvasHeight);
  }
  return _rasterizeHorizontal(text, canvasWidth, canvasHeight);
}

Future<Uint8List?> _rasterizeHorizontal(TextObject text, int canvasWidth, int canvasHeight) async {
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

/// 縦書きラスタライズ。FlutterのParagraphBuilder/TextPainterは縦書きを直接
/// サポートしないため、1文字ずつ個別にレイアウトして上→下・列は右→左の順に
/// 配置する自前実装。半角英数字の回転・ルビ・縦中横などの高度な組版は初期実装の
/// スコープ外とし、各文字は正立のまま配置する（既知の簡略化）。
/// 手動改行（\n）は列の区切りとして扱う。
Future<Uint8List?> _rasterizeVertical(TextObject text, int canvasWidth, int canvasHeight) async {
  final fontStyle = text.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal;
  final fontWeight = text.isBold ? ui.FontWeight.bold : ui.FontWeight.normal;

  ui.TextStyle styleFor(ui.Color color) => ui.TextStyle(
        color: color,
        fontSize: text.fontSize,
        fontFamily: text.fontFamily,
        fontStyle: fontStyle,
        fontWeight: fontWeight,
      );

  // 手動改行で列を分割する（縦書きでは列は右から左へ進む）
  final columns = text.text.split('\n');
  final charAdvance = text.fontSize * text.lineHeight; // 1文字分の縦送り量
  final columnAdvance = text.fontSize * 1.15 + text.letterSpacing; // 列の間隔

  final charsPerColumn = columns.map((c) => c.split('').length).toList();
  final maxChars = charsPerColumn.isEmpty ? 0 : charsPerColumn.reduce(math.max);
  if (maxChars == 0) return null;

  final totalHeight = maxChars * charAdvance;
  final totalWidth = columns.length * columnAdvance;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();
  final centerX = text.position.dx + totalWidth / 2;
  final centerY = text.position.dy + totalHeight / 2;
  canvas.translate(centerX, centerY);
  canvas.rotate(text.rotation * math.pi / 180);
  canvas.scale(text.scale);
  canvas.translate(-totalWidth / 2, -totalHeight / 2);

  final outline = text.outline;
  final hasOutline = outline != null && outline.enabled && outline.width > 0;

  void drawColumns(ui.TextStyle style, ui.Offset extraOffset) {
    for (int colIdx = 0; colIdx < columns.length; colIdx++) {
      // 列は右から左へ進む（縦書きの伝統的な配置）
      final columnX = totalWidth - (colIdx + 1) * columnAdvance + extraOffset.dx;
      // 揃え（左/中央/右）は縦書きでは列全体の縦方向の開始位置に読み替える
      final chars = columns[colIdx].split('');
      final columnHeight = chars.length * charAdvance;
      final startY = switch (text.align) {
        ui.TextAlign.center => (totalHeight - columnHeight) / 2,
        ui.TextAlign.right => totalHeight - columnHeight,
        _ => 0.0,
      } + extraOffset.dy;
      for (int i = 0; i < chars.length; i++) {
        final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
          ..pushStyle(style)
          ..addText(chars[i]);
        final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: columnAdvance));
        canvas.drawParagraph(paragraph, ui.Offset(columnX, startY + i * charAdvance));
      }
    }
  }

  if (hasOutline) {
    final outlineStyle = styleFor(outline.color);
    const steps = 8;
    for (int i = 0; i < steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final dx = outline.width * math.cos(angle);
      final dy = outline.width * math.sin(angle);
      drawColumns(outlineStyle, ui.Offset(dx, dy));
    }
  }
  drawColumns(styleFor(text.color.withValues(alpha: text.color.a * text.opacity)), ui.Offset.zero);

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
