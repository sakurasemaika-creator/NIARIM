import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/text_object.dart';

/// ルビ注釈の記法：`{漢字|かんじ}`。縦書き専用（横書きでは基底テキストのみを
/// 表示し、記法自体は取り除く。仕様書15にルビの横書き表示までは規定がなく、
/// 伝統的な縦書き用途を優先した範囲対応）。
final RegExp _rubyPattern = RegExp(r'\{([^{}|]+)\|([^{}|]+)\}');

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

/// 横書きでは{base|ruby}記法をそのまま表示せず、baseのみを残す（ルビ注釈は
/// 縦書き専用のため）。
String _stripRubyForHorizontal(String input) =>
    input.replaceAllMapped(_rubyPattern, (m) => m.group(1)!);

Future<Uint8List?> _rasterizeHorizontal(TextObject text, int canvasWidth, int canvasHeight) async {
  final fontStyle = text.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal;
  final fontWeight = text.isBold ? ui.FontWeight.bold : ui.FontWeight.normal;
  final plainText = _stripRubyForHorizontal(text.text);

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
    ..addText(plainText);
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
      ..addText(plainText);
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

// ─── 縦書き ───────────────────────────────────────────────────────────────

enum _VKind {
  upright,      // 全角文字・ルビ基底文字など、正立のまま縦に積む
  rotated,      // 半角英字・記号など、単独文字を90°回転して配置
  tateChuYoko,  // 半角数字2桁を1文字分の高さへ横並びで収める（縦中横）
}

/// 縦書きの1レイアウト単位（1文字〜ルビ基底文字列）。
class _VUnit {
  final String text;
  final _VKind kind;
  final String? ruby; // ルビ注釈（{base|ruby}のruby部分）。null=ルビなし
  const _VUnit({required this.text, required this.kind, this.ruby});

  /// この単位が占める「1文字分の高さ」の個数（upright/ルビ基底は文字数分、
  /// 回転・縦中横は常に1）。
  int get slotCount => kind == _VKind.upright ? text.characters.length : 1;
}

extension on String {
  /// 簡易的なUTF-16コードユニット単位の文字分割（絵文字等のサロゲートペアは
  /// 本アプリのテキストツールの想定利用範囲外として厳密対応しない）。
  List<String> get characters => split('');
}

bool _isHalfWidth(String ch) => ch.isNotEmpty && ch.codeUnitAt(0) <= 0x7F;
bool _isDigit(String ch) => RegExp(r'^[0-9]$').hasMatch(ch);

/// ルビ記法を含む1列分のテキストを、レイアウト単位の列へ分解する
/// （仕様書15：縦書き・ルビ・縦中横・半角英数字回転）。
List<_VUnit> _parseColumnUnits(String column) {
  final units = <_VUnit>[];
  int cursor = 0;
  for (final match in _rubyPattern.allMatches(column)) {
    if (match.start > cursor) {
      units.addAll(_parsePlainRun(column.substring(cursor, match.start)));
    }
    final base = match.group(1)!;
    final ruby = match.group(2)!;
    units.add(_VUnit(text: base, kind: _VKind.upright, ruby: ruby));
    cursor = match.end;
  }
  if (cursor < column.length) {
    units.addAll(_parsePlainRun(column.substring(cursor)));
  }
  return units;
}

/// ルビ記法を含まないプレーンな文字列を、半角/全角・数字連続を判定しながら
/// レイアウト単位へ分解する。
/// - 全角文字：そのまま正立で縦に積む
/// - 半角数字が2つ連続：縦中横として1文字分の高さへ横並びで収める
/// - それ以外の半角文字（英字・記号・単独の数字）：90°回転して配置
List<_VUnit> _parsePlainRun(String text) {
  final units = <_VUnit>[];
  final chars = text.characters;
  int i = 0;
  while (i < chars.length) {
    final ch = chars[i];
    if (!_isHalfWidth(ch)) {
      units.add(_VUnit(text: ch, kind: _VKind.upright));
      i++;
      continue;
    }
    if (_isDigit(ch) && i + 1 < chars.length && _isDigit(chars[i + 1])) {
      units.add(_VUnit(text: ch + chars[i + 1], kind: _VKind.tateChuYoko));
      i += 2;
      continue;
    }
    units.add(_VUnit(text: ch, kind: _VKind.rotated));
    i++;
  }
  return units;
}

/// 縦書きラスタライズ。FlutterのParagraphBuilder/TextPainterは縦書きを直接
/// サポートしないため、1レイアウト単位ずつ個別にレイアウトして上→下・列は
/// 右→左の順に配置する自前実装。半角英数字の回転・縦中横・ルビ注釈
/// （{base|ruby}記法）に対応する。手動改行（\n）は列の区切りとして扱う。
Future<Uint8List?> _rasterizeVertical(TextObject text, int canvasWidth, int canvasHeight) async {
  final fontStyle = text.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal;
  final fontWeight = text.isBold ? ui.FontWeight.bold : ui.FontWeight.normal;

  ui.TextStyle styleFor(ui.Color color, {double? size}) => ui.TextStyle(
        color: color,
        fontSize: size ?? text.fontSize,
        fontFamily: text.fontFamily,
        fontStyle: fontStyle,
        fontWeight: fontWeight,
      );

  // 手動改行で列を分割する（縦書きでは列は右から左へ進む）
  final rawColumns = text.text.split('\n');
  final columns = rawColumns.map(_parseColumnUnits).toList();
  final charAdvance = text.fontSize * text.lineHeight; // 1文字分の縦送り量
  final columnAdvance = text.fontSize * 1.15 + text.letterSpacing; // 列の間隔

  final slotsPerColumn =
      columns.map((units) => units.fold<int>(0, (sum, u) => sum + u.slotCount)).toList();
  final maxSlots = slotsPerColumn.isEmpty ? 0 : slotsPerColumn.reduce(math.max);
  if (maxSlots == 0) return null;

  final totalHeight = maxSlots * charAdvance;
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

  void drawUprightChars(String s, ui.TextStyle style, double columnX, double y) {
    final chars = s.characters;
    for (int i = 0; i < chars.length; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
        ..pushStyle(style)
        ..addText(chars[i]);
      final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: columnAdvance));
      canvas.drawParagraph(paragraph, ui.Offset(columnX, y + i * charAdvance));
    }
  }

  // 半角英数字の回転（仕様書15）：文字を90°回転し、1文字分の高さのマス内に収める。
  void drawRotatedChar(String ch, ui.TextStyle style, double columnX, double y) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(style)
      ..addText(ch);
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: charAdvance));
    canvas.save();
    canvas.translate(columnX + columnAdvance / 2, y + charAdvance / 2);
    canvas.rotate(math.pi / 2);
    canvas.translate(-charAdvance / 2, -charAdvance / 2);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    canvas.restore();
  }

  // 縦中横（仕様書15）：半角数字2桁を正立のまま横並びで1文字分の高さに収める。
  void drawTateChuYoko(String pair, ui.Color color, double columnX, double y) {
    final miniSize = text.fontSize * 0.55;
    final miniStyle = styleFor(color, size: miniSize);
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(miniStyle)
      ..addText(pair);
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: columnAdvance));
    final yOffset = (charAdvance - miniSize * text.lineHeight) / 2;
    canvas.drawParagraph(paragraph, ui.Offset(columnX, y + yOffset.clamp(0, charAdvance)));
  }

  // ルビ（{base|ruby}記法、仕様書15）：基底文字の右側（列の右隣＝既に描画済みの
  // 前の列側）へ、基底が占める高さへ均等配置した小さな縦書きで表示する。
  void drawRuby(String ruby, double columnX, double y, double slotHeight, ui.Color color) {
    final chars = ruby.characters;
    if (chars.isEmpty) return;
    final rubySize = text.fontSize * 0.48;
    final rubyStyle = styleFor(color, size: rubySize);
    final step = slotHeight / chars.length;
    for (int i = 0; i < chars.length; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
        ..pushStyle(rubyStyle)
        ..addText(chars[i]);
      final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: rubySize * 1.3));
      final ry = y + i * step + (step - rubySize) / 2;
      canvas.drawParagraph(paragraph, ui.Offset(columnX + columnAdvance * 0.6, ry.clamp(y, y + slotHeight)));
    }
  }

  void drawColumns(ui.TextStyle style, ui.Color color, ui.Offset extraOffset, {required bool withRuby}) {
    for (int colIdx = 0; colIdx < columns.length; colIdx++) {
      // 列は右から左へ進む（縦書きの伝統的な配置）
      final columnX = totalWidth - (colIdx + 1) * columnAdvance + extraOffset.dx;
      final units = columns[colIdx];
      final columnSlots = units.fold<int>(0, (sum, u) => sum + u.slotCount);
      final columnHeight = columnSlots * charAdvance;
      // 揃え（左/中央/右）は縦書きでは列全体の縦方向の開始位置に読み替える
      final startY = switch (text.align) {
        ui.TextAlign.center => (totalHeight - columnHeight) / 2,
        ui.TextAlign.right => totalHeight - columnHeight,
        _ => 0.0,
      } + extraOffset.dy;

      double y = startY;
      for (final unit in units) {
        final slotHeight = unit.slotCount * charAdvance;
        switch (unit.kind) {
          case _VKind.upright:
            drawUprightChars(unit.text, style, columnX, y);
          case _VKind.rotated:
            drawRotatedChar(unit.text, style, columnX, y);
          case _VKind.tateChuYoko:
            drawTateChuYoko(unit.text, color, columnX, y);
        }
        if (withRuby && unit.ruby != null) {
          drawRuby(unit.ruby!, columnX, y, slotHeight, color);
        }
        y += slotHeight;
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
      // ルビは縁取りせず、本文のみに縁取りを適用する
      drawColumns(outlineStyle, outline.color, ui.Offset(dx, dy), withRuby: false);
    }
  }
  final mainColor = text.color.withValues(alpha: text.color.a * text.opacity);
  drawColumns(styleFor(mainColor), mainColor, ui.Offset.zero, withRuby: true);

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
