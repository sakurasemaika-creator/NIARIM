import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_service.dart';

/// キャンバスモード内の常設ボタン共通スタイル：
/// 背景は一切持たせず、キャンバス上にアイコンだけが浮かんでいる状態にした
/// うえで、そのアイコンの形にぴったり沿う縁取りを付ける。
/// IconButtonのデフォルト背景・円形ボーダーのようにアイコンの周囲を
/// 大きな円で囲う方式は、マークの形に沿わず視認性が悪い。
///
/// 縁取りは、アイコンを縁取り色で8方向へわずかにずらして重ねることで、
/// 輪郭そのものに沿ったアウトラインを疑似的に作っている。色は白・黒に
/// 固定せず、ユーザーが選んだテーマ・外観と連動させる
/// （アイコン＝テーマの文字色、縁取り＝テーマのメニュー背景色）。
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
      shadows: [
        for (final o in _offsets)
          Shadow(color: outlineColor, offset: o, blurRadius: 0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final menuBg = context.watch<ThemeService>().current.menuBgColor;
    final iconColor = selected ? scheme.primary : scheme.onSurface;
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
            child: _renderIcon(iconColor, menuBg.withValues(alpha: 0.75)),
          ),
        ),
      ),
    );
  }
}