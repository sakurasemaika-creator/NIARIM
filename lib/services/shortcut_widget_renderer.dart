import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../config/font_fallback.dart';
import 'home_widget_service.dart';

/// 「作品をつくる」「作品広場」のショートカットウィジェットの見た目を、
/// 起動画面（`splash_screen.dart`の`_SplashActionButton`）の2つの大きな
/// 導線ボタンと**同じデザイン**でPNGへ焼くレンダラー。
///
/// ## なぜネイティブのレイアウトではなく画像なのか
///
/// ホーム画面ウィジェットは`RemoteViews`で描画され、使えるのは
/// ImageView/TextView等の限られた部品だけで、
/// - 任意の2色グラデーション背景
/// - 角丸＋影
/// - アプリ同梱フォント（見出し用のKuramubon）
/// - Materialアイコンのグリフ
/// のいずれも指定できない（`GradientDrawable`はリソースとして静的に
/// 用意した色しか使えず、`setTypeface`はassetのフォントを受け付けない）。
/// 起動画面のボタンと**同じ**デザインにするには、アプリ側で1枚の画像として
/// 描いて渡すのが唯一の方法になる。ネイティブ側は受け取った画像を
/// `fitCenter`で表示するだけにしてある。
///
/// 画像が無い場合（アプリを一度も起動せずにウィジェットを置いた等）は、
/// ネイティブ側がアイコン＋ラベルの簡易表示へフォールバックする。
///
/// ## 起動画面と揃えている値
///
/// `_SplashActionButton`の実装と1対1で対応する。片方を変えたらもう片方も
/// 変えること。
/// - タイル幅150・最低高さ150、角丸24、内側余白 横14／縦16
/// - 背景はcolors[0]→colors[1]の左上→右下グラデーション
/// - 影はelevation 4相当（影色はcolors[0]の50%）
/// - アイコン60px、ラベル18px太字、サブラベル12px（どちらもKuramubon）
class ShortcutWidgetDesign {
  /// 起動画面のボタンと同じ論理サイズ。
  static const double tileSize = 150;
  static const double cornerRadius = 24;
  static const double horizontalPadding = 14;
  static const double verticalPadding = 16;
  static const double iconSize = 60;
  static const double labelSize = 18;
  static const double subLabelSize = 12;
  static const double gapAfterIcon = 12;

  /// 影がにじむぶんの余白（この幅だけ画像の外周を空ける）。
  static const double shadowMargin = 10;

  const ShortcutWidgetDesign._();
}

/// [kind]のショートカットウィジェット画像を描いてPNGのパスを返す。
///
/// [colors]はグラデーションの2色（起動画面と同じく`[primary,
/// primaryContainer]`・`[secondary, secondaryContainer]`、または
/// ユーザーが色を指定した場合はその色から作った2色）。
/// [foreground]はアイコン・文字の色。
///
/// 端末やランチャーによってはウィジェットが数百px四方で置かれるため、
/// 論理150pxの意匠を[scale]倍（既定3倍＝450px相当）で焼く。
Future<String?> saveShortcutWidgetImage({
  required HomeWidgetKind kind,
  required IconData icon,
  required String label,
  String? subLabel,
  required List<Color> colors,
  required Color foreground,
  double scale = 3,
}) async {
  final image = await renderShortcutWidgetImage(
    icon: icon,
    label: label,
    subLabel: subLabel,
    colors: colors,
    foreground: foreground,
    scale: scale,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final bytes = byteData?.buffer.asUint8List();
  if (bytes == null) return null;

  final dir = await getTemporaryDirectory();
  // 種類ごとに固定のファイル名へ上書きするので、古い画像が溜まらない。
  final file = File('${dir.path}/home_widget_shortcut_${kind.name}.png');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// [saveShortcutWidgetImage]の描画本体。テストから画素を直接検証できるよう
/// ファイル保存とは分けてある。
Future<ui.Image> renderShortcutWidgetImage({
  required IconData icon,
  required String label,
  String? subLabel,
  required List<Color> colors,
  required Color foreground,
  double scale = 3,
}) async {
  const d = ShortcutWidgetDesign.tileSize;
  const margin = ShortcutWidgetDesign.shadowMargin;
  final side = ((d + margin * 2) * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);

  final tile = Rect.fromLTWH(margin, margin, d, d);
  final rrect = RRect.fromRectAndRadius(
    tile,
    const Radius.circular(ShortcutWidgetDesign.cornerRadius),
  );

  // Material elevation 4相当の影（`_SplashActionButton`の
  // `Material(elevation: 4, shadowColor: colors.first * 0.5)`に相当）。
  canvas.drawRRect(
    rrect.shift(const Offset(0, 2)),
    Paint()
      ..color = colors.first.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );

  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = ui.Gradient.linear(tile.topLeft, tile.bottomRight, [
        colors.first,
        colors.last,
      ]),
  );

  // アイコン・ラベル・サブラベルを縦に積んで、タイルの中央へ置く。
  final iconPainter = _painter(
    String.fromCharCode(icon.codePoint),
    TextStyle(
      fontSize: ShortcutWidgetDesign.iconSize,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      color: foreground,
      height: 1,
    ),
  );
  final labelPainter = _painter(
    label,
    TextStyle(
      color: foreground,
      fontSize: ShortcutWidgetDesign.labelSize,
      fontWeight: FontWeight.bold,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    ),
    maxWidth: d - ShortcutWidgetDesign.horizontalPadding * 2,
    maxLines: subLabel == null ? 2 : 1,
  );
  final subPainter = subLabel == null
      ? null
      : _painter(
          subLabel,
          TextStyle(
            color: foreground,
            fontSize: ShortcutWidgetDesign.subLabelSize,
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
          maxWidth: d - ShortcutWidgetDesign.horizontalPadding * 2,
          maxLines: 1,
        );

  final totalHeight =
      iconPainter.height +
      ShortcutWidgetDesign.gapAfterIcon +
      labelPainter.height +
      (subPainter?.height ?? 0);
  var y = tile.top + (d - totalHeight) / 2;
  for (final painter in [iconPainter, labelPainter, subPainter]) {
    if (painter == null) continue;
    painter.paint(canvas, Offset(tile.left + (d - painter.width) / 2, y));
    y +=
        painter.height +
        (painter == iconPainter ? ShortcutWidgetDesign.gapAfterIcon : 0);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  return image;
}

TextPainter _painter(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
  return painter;
}
