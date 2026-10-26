import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_service.dart';
import '../../../utils/color_contrast.dart';

/// キャンバスモード内の常設ボタン共通スタイル：
/// 背景は一切持たせず、キャンバス上にアイコンだけが浮かんでいる状態にした
/// うえで、そのアイコンの形にぴったり沿う縁取りを付ける。
/// IconButtonのデフォルト背景・円形ボーダーのようにアイコンの周囲を
/// 大きな円で囲う方式は、マークの形に沿わず視認性が悪い。
///
/// 縁取りは、アイコンを縁取り色で8方向へわずかにずらして重ねる。
/// アイコン本体はユーザー設定のテーマ色のままとし、縁取りは現在の
/// ColorScheme.surface / onSurface のうち本体との明暗差が大きい色を使う。
/// 白や黒への固定はせず、背景なしのデザインも維持する。
class CanvasIconButton extends StatelessWidget {
  final IconData? icon;
  // Material Iconsに適切なグリフがないツール（消しゴム等）や、
  // モード切替のように複数グリフを1つのボタンとして見せたい箇所向け。
  // 指定時は[icon]より優先される。
  final Widget Function(Color color)? iconBuilder;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool selected;
  final double iconSize;

  /// 長押しでツールチップを出すかどうか。
  final bool longPressTooltip;

  const CanvasIconButton({
    super.key,
    this.icon,
    this.iconBuilder,
    required this.onPressed,
    required this.tooltip,
    this.selected = false,
    this.iconSize = 20,
    this.longPressTooltip = true,
  }) : assert(
         icon != null || iconBuilder != null,
         'iconかiconBuilderのどちらかを指定してください',
       );

  /// 縁取りを作るための8方向のずらし量（上下左右＋斜め、1px）。
  static const _offsets = [
    Offset(-1, -1),
    Offset(0, -1),
    Offset(1, -1),
    Offset(-1, 0),
    Offset(1, 0),
    Offset(-1, 1),
    Offset(0, 1),
    Offset(1, 1),
  ];

  /// [color]の1px縁取り（文字やアイコンの`shadows`に渡す）。キャンバスの
  /// 上へ背景なしで浮かべる文字・アイコンを、絵柄に関係なく読めるようにする。
  static List<Shadow> outlineShadows(Color color) => [
    for (final o in _offsets) Shadow(color: color, offset: o, blurRadius: 0),
  ];

  /// Readable on either light or dark artwork: draw an opaque outline
  /// chosen from the currently selected theme (never a hard-coded UI color).
  /// The foreground itself remains exactly the user-configured theme color.
  static Color outlineColor(Color foreground, ColorScheme scheme) {
    final surface = scheme.surface;
    final ink = scheme.onSurface;
    return contrastRatio(foreground, surface) >=
            contrastRatio(foreground, ink)
        ? surface
        : ink;
  }

  /// Shared by free-floating text, indicators and handles as well as icons.
  static List<Shadow> foregroundShadows(
    Color foreground,
    ColorScheme scheme,
  ) => outlineShadows(outlineColor(foreground, scheme));

  /// Ordinary action buttons sit on a known theme background, unlike the
  /// tools floating over arbitrary canvas artwork. A permanent 1px dark
  /// outline visually turns small Kuramubon accent labels burgundy even
  /// though their actual fill is the chosen pink. Keep the true accent
  /// appearance when it is already distinguishable; use the same theme-
  /// derived outline only if the chosen colors nearly merge.
  ///
  /// This does not change the button's foreground or the saved theme colors.
  static List<Shadow>? actionShadows(
    Color foreground,
    Color background,
    ColorScheme scheme,
  ) {
    if (contrastRatio(foreground, background) >= 2.5) return null;
    return foregroundShadows(foreground, scheme);
  }

  /// アイコン本体＋縁取りを描く。
  Widget _renderIcon(Color iconColor, Color outlineColor) {
    if (iconBuilder != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final o in _offsets)
            Positioned(
              left: o.dx,
              top: o.dy,
              child: iconBuilder!(outlineColor),
            ),
          iconBuilder!(iconColor),
        ],
      );
    }
    return Icon(
      icon,
      size: iconSize,
      color: iconColor,
      shadows: outlineShadows(outlineColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Subscribe so changing the appearance preset repaints the outline.
    context.watch<ThemeService>();
    final iconColor = selected ? scheme.primary : scheme.onSurface;
    final outline = outlineColor(iconColor, scheme);
    return Tooltip(
      message: tooltip,
      triggerMode: longPressTooltip
          ? TooltipTriggerMode.longPress
          : TooltipTriggerMode.manual,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        containedInkWell: false,
        highlightShape: BoxShape.circle,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: _renderIcon(iconColor, outline),
          ),
        ),
      ),
    );
  }
}
