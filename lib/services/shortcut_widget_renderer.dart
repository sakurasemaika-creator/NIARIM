import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../config/font_fallback.dart';
import '../utils/line_break.dart';
import '../widgets/action_beside_or_below.dart';
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
/// - アイコン60px、ラベル18px太字、サブラベル12px（どちらもKuramubon）。
///   文言が入らない言語では[ShortcutWidgetFit]がアイコン・文字を小さくする
///
/// ## 縦横比
///
/// ホーム画面のマス目は正方形とは限らないため、[ShortcutWidgetShape]の
/// 3通り（正方形・横長・縦長）を焼いておき、ネイティブ側が実際のマスに
/// 近いものを選ぶ。横長だけはアイコンと文字を横並びにする。
class ShortcutWidgetDesign {
  /// 起動画面のボタンと同じ論理サイズ（正方形のときの一辺）。
  static const double tileSize = 150;
  static const double cornerRadius = 24;
  static const double horizontalPadding = 14;
  static const double iconSize = 60;
  static const double labelSize = 18;
  static const double subLabelSize = 12;
  static const double gapAfterIcon = 12;

  /// 横長・縦長のときの長辺（短辺は[tileSize]のまま）。
  static const double longSide = 300;

  /// 影がにじむぶんの余白（この幅だけ画像の外周を空ける）。
  static const double shadowMargin = 10;

  const ShortcutWidgetDesign._();

  /// 上下の内側余白（起動画面のボタンの`_padding`の縦）。
  static const double verticalPadding = 16;

  /// 文言が入らないときに、アイコンをここまで小さくしてよい。
  static const double minIconSize = 40;

  /// アイコンを小さくしても入らないときに、文字をここまで小さくしてよい
  /// （元の大きさに対する割合）。
  static const double minTextScale = 0.6;

  /// [shape]のタイルの論理サイズ。
  static Size tileSizeOf(ShortcutWidgetShape shape) => switch (shape) {
    ShortcutWidgetShape.square => const Size(tileSize, tileSize),
    ShortcutWidgetShape.wide => const Size(longSide, tileSize),
    ShortcutWidgetShape.tall => const Size(tileSize, longSide),
  };
}

/// ショートカットウィジェットの文言の書式（見出しの書体、[size]の大きさ）。
TextStyle shortcutWidgetTextStyle({
  required Locale? locale,
  required Color color,
  required double size,
  required bool bold,
}) => TextStyle(
  color: color,
  fontSize: size,
  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  fontFamily: headingFontFamilyFor(locale),
  fontFamilyFallback: headingFontFallbackFor(locale),
);

/// ショートカットウィジェットの1枚に、アイコン・文言をどの大きさで並べるか。
///
/// ウィジェットの画像は大きさが決まっていて（ランチャーがマスの大きさを
/// 決める）、起動画面のボタンのように縦に伸ばせない。文言は省略記号で
/// 切らず、語の途中でも折らない（「Plaza de O…」「Browse posted …」、
/// 韓国語の「만들｜기」になっていた）。入らないときは、まずアイコンを
/// [ShortcutWidgetDesign.minIconSize]まで小さくし、それでも入らなければ
/// 文字を[ShortcutWidgetDesign.minTextScale]まで小さくする。
class ShortcutWidgetFit {
  /// 描く文言（韓国語は語の中を語結合子でつないだもの）。
  final String label;
  final String? subLabel;
  final double iconSize;
  final double labelSize;
  final double subLabelSize;

  const ShortcutWidgetFit._({
    required this.label,
    required this.subLabel,
    required this.iconSize,
    required this.labelSize,
    required this.subLabelSize,
  });

  /// アイコンの右に文言を置く形か（横長）。
  static bool sideBySide(ShortcutWidgetShape shape) =>
      shape == ShortcutWidgetShape.wide;

  /// アイコンが[iconSize]のとき、文言に使える幅。
  static double textWidthFor(ShortcutWidgetShape shape, double iconSize) {
    final size = ShortcutWidgetDesign.tileSizeOf(shape);
    final inner = size.width - ShortcutWidgetDesign.horizontalPadding * 2;
    return sideBySide(shape)
        ? inner - iconSize - ShortcutWidgetDesign.gapAfterIcon
        : inner;
  }

  factory ShortcutWidgetFit.of({
    required String label,
    String? subLabel,
    Locale? locale,
    ShortcutWidgetShape shape = ShortcutWidgetShape.square,
  }) {
    final korean = locale?.languageCode == 'ko';
    final shownLabel = korean ? keepKoreanWordsTogether(label) : label;
    final shownSub = subLabel == null || !korean
        ? subLabel
        : keepKoreanWordsTogether(subLabel);
    final size = ShortcutWidgetDesign.tileSizeOf(shape);
    final height = size.height - ShortcutWidgetDesign.verticalPadding * 2;

    // 文言の高さ。語がその幅に入らないときはnull。
    double? textHeight(String text, double fontSize, bool bold, double width) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: shortcutWidgetTextStyle(
            locale: locale,
            color: const Color(0xFF000000),
            size: fontSize,
            bold: bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: width);
      final widest = widestUnbreakableWidth(
        painter,
        reported: painter.minIntrinsicWidth,
      );
      painter.layout(maxWidth: width);
      final result = widest <= width + 0.01 ? painter.height : null;
      painter.dispose();
      return result;
    }

    bool fits(double icon, double scale) {
      final width = textWidthFor(shape, icon);
      final labelHeight = textHeight(
        shownLabel,
        ShortcutWidgetDesign.labelSize * scale,
        true,
        width,
      );
      if (labelHeight == null) return false;
      var text = labelHeight;
      if (shownSub != null) {
        final subHeight = textHeight(
          shownSub,
          ShortcutWidgetDesign.subLabelSize * scale,
          false,
          width,
        );
        if (subHeight == null) return false;
        text += subHeight;
      }
      final needed = sideBySide(shape)
          ? math.max(icon, text)
          : icon + ShortcutWidgetDesign.gapAfterIcon + text;
      return needed <= height + 0.01;
    }

    ShortcutWidgetFit result(double icon, double scale) => ShortcutWidgetFit._(
      label: shownLabel,
      subLabel: shownSub,
      iconSize: icon,
      labelSize: ShortcutWidgetDesign.labelSize * scale,
      subLabelSize: ShortcutWidgetDesign.subLabelSize * scale,
    );

    const icons = [
      ShortcutWidgetDesign.iconSize,
      52.0,
      46.0,
      ShortcutWidgetDesign.minIconSize,
    ];
    for (final icon in icons) {
      if (fits(icon, 1)) return result(icon, 1);
    }
    for (
      var scale = 0.95;
      scale > ShortcutWidgetDesign.minTextScale - 0.001;
      scale -= 0.05
    ) {
      if (fits(ShortcutWidgetDesign.minIconSize, scale)) {
        return result(ShortcutWidgetDesign.minIconSize, scale);
      }
    }
    return result(
      ShortcutWidgetDesign.minIconSize,
      ShortcutWidgetDesign.minTextScale,
    );
  }
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
  Locale? locale,
  required List<Color> colors,
  required Color foreground,
  ShortcutWidgetShape shape = ShortcutWidgetShape.square,
  double scale = 3,
}) async {
  final image = await renderShortcutWidgetImage(
    icon: icon,
    label: label,
    subLabel: subLabel,
    locale: locale,
    colors: colors,
    foreground: foreground,
    shape: shape,
    scale: scale,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final bytes = byteData?.buffer.asUint8List();
  if (bytes == null) return null;

  final dir = await getTemporaryDirectory();
  // 種類・縦横比ごとに固定のファイル名へ上書きするので、古い画像が
  // 溜まらない。
  final file = File(
    '${dir.path}/home_widget_shortcut_${kind.name}_${shape.name}.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// [saveShortcutWidgetImage]の描画本体。テストから画素を直接検証できるよう
/// ファイル保存とは分けてある。
Future<ui.Image> renderShortcutWidgetImage({
  required IconData icon,
  required String label,
  String? subLabel,
  Locale? locale,
  required List<Color> colors,
  required Color foreground,
  ShortcutWidgetShape shape = ShortcutWidgetShape.square,
  double scale = 3,
}) async {
  const margin = ShortcutWidgetDesign.shadowMargin;
  final size = ShortcutWidgetDesign.tileSizeOf(shape);
  final horizontal = shape == ShortcutWidgetShape.wide;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);

  final tile = Rect.fromLTWH(margin, margin, size.width, size.height);
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

  final fit = ShortcutWidgetFit.of(
    label: label,
    subLabel: subLabel,
    locale: locale,
    shape: shape,
  );
  final iconPainter = _painter(
    String.fromCharCode(icon.codePoint),
    TextStyle(
      fontSize: fit.iconSize,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      color: foreground,
      height: 1,
    ),
  );

  // 横並びのときは、アイコンと余白を引いた残りが文字の使える幅になる。
  final textWidth = ShortcutWidgetFit.textWidthFor(shape, fit.iconSize);

  final labelPainter = _painter(
    fit.label,
    shortcutWidgetTextStyle(
      locale: locale,
      color: foreground,
      size: fit.labelSize,
      bold: true,
    ),
    maxWidth: textWidth,
  );
  final subPainter = fit.subLabel == null
      ? null
      : _painter(
          fit.subLabel!,
          shortcutWidgetTextStyle(
            locale: locale,
            color: foreground,
            size: fit.subLabelSize,
            bold: false,
          ),
          maxWidth: textWidth,
        );

  final textPainters = [labelPainter, ?subPainter];
  final textHeight = textPainters.fold<double>(0, (a, p) => a + p.height);

  if (horizontal) {
    // アイコン｜文字（縦積み）を横に並べ、まとめてタイルの中央へ置く。
    // **折り返した行の`TextPainter.width`は`maxWidth`そのもの**になるため、
    // それを文字の幅として使うと（実際の字面より広いぶん）アイコンが左へ
    // 押し出され、アイコンと文字の間に大きな隙間が空く。実際に描かれる
    // 行の幅（`computeLineMetrics`）で測る。
    final textBlockWidth = textPainters.fold<double>(
      0,
      (a, p) => math.max(a, _inkWidth(p)),
    );
    final groupWidth =
        iconPainter.width + ShortcutWidgetDesign.gapAfterIcon + textBlockWidth;
    final left = tile.left + (size.width - groupWidth) / 2;
    iconPainter.paint(
      canvas,
      Offset(left, tile.top + (size.height - iconPainter.height) / 2),
    );
    final textLeft =
        left + iconPainter.width + ShortcutWidgetDesign.gapAfterIcon;
    var y = tile.top + (size.height - textHeight) / 2;
    for (final painter in textPainters) {
      painter.paint(
        canvas,
        Offset(textLeft + (textBlockWidth - painter.width) / 2, y),
      );
      y += painter.height;
    }
  } else {
    // アイコン・ラベル・サブラベルを縦に積んで、タイルの中央へ置く。
    final totalHeight =
        iconPainter.height + ShortcutWidgetDesign.gapAfterIcon + textHeight;
    var y = tile.top + (size.height - totalHeight) / 2;
    for (final painter in [iconPainter, ...textPainters]) {
      painter.paint(
        canvas,
        Offset(tile.left + (size.width - painter.width) / 2, y),
      );
      y +=
          painter.height +
          (painter == iconPainter ? ShortcutWidgetDesign.gapAfterIcon : 0);
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    ((size.width + margin * 2) * scale).round(),
    ((size.height + margin * 2) * scale).round(),
  );
  picture.dispose();
  return image;
}

/// [painter]が実際に描く行のうち、いちばん広い行の幅。
///
/// 折り返しが起きると`TextPainter.width`は`layout`へ渡した`maxWidth`を
/// そのまま返すので、字面の幅を知りたいときはこちらを使う。
double _inkWidth(TextPainter painter) {
  final lines = painter.computeLineMetrics();
  if (lines.isEmpty) return painter.width;
  return lines.fold<double>(0, (a, l) => math.max(a, l.width));
}

TextPainter _painter(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: maxWidth);
  return painter;
}
