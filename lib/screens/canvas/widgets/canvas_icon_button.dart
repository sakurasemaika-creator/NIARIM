import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_service.dart';

/// キャンバスモード内の常設ボタン共通スタイル：
/// 背景は一切持たせず、キャンバス上にアイコンだけが浮かんでいる状態にした
/// うえで、そのアイコンの形にぴったり沿う縁取りを付ける。
/// アイコンの周囲を大きな円で囲う従来方式（IconButtonのデフォルト背景・
/// 円形ボーダー）は、マークの形に沿わず視認性が悪いという指摘を受けて
/// 廃止した。ここでは同じアイコンを縁取り色で8方向へわずかにずらして
/// 重ね描きすることで、アイコンの輪郭そのものに沿った縁取り（アウトライン
/// ストローク）を疑似的に作り、どんな背景色のキャンバス上でも視認できる
/// ようにしている。色は白・黒に固定せず、ユーザーが選んだテーマ・外観と
/// 連動させる（アイコン＝テーマの文字色、縁取り＝テーマのメニュー背景色）。
class CanvasIconButton extends StatelessWidget {
  final IconData? icon;
  // Material Iconsに適切なグリフがないツール（消しゴム等）向けに、
  // Canvas描画の自作アイコンを差し込めるようにする。指定時は[icon]より
  // 優先される。
  final Widget Function(Color color)? iconBuilder;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool selected;
  final double iconSize;

  const CanvasIconButton({
    super.key,
    this.icon,
    this.iconBuilder,
    required this.onPressed,
    required this.tooltip,
    this.selected = false,
    this.iconSize = 20,
  }) : assert(icon != null || iconBuilder != null, 'iconかiconBuilderのどちらかを指定してください');

  static const _offsets = [
    Offset(-1, -1), Offset(0, -1), Offset(1, -1),
    Offset(-1, 0), Offset(1, 0),
    Offset(-1, 1), Offset(0, 1), Offset(1, 1),
  ];

  Widget _renderIcon(Color color) =>
      iconBuilder != null ? iconBuilder!(color) : Icon(icon, size: iconSize, color: color);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // preset.textColor→colorScheme.onSurfaceの対応はtheme_service.dart側の
    // マッピングと同じ（アイコン＝テーマの文字色）。縁取りはcolorScheme上に
    // 対応する値が無いため、ThemeServiceからpreset.menuBgColorを直接参照する
    // （＝テーマのメニュー背景色）。
    final menuBg = context.watch<ThemeService>().current.menuBgColor;
    final iconColor = selected ? scheme.primary : scheme.onSurface;
    return Tooltip(
      message: tooltip,
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final o in _offsets)
                  Positioned(
                    left: o.dx,
                    top: o.dy,
                    child: _renderIcon(menuBg.withValues(alpha: 0.75)),
                  ),
                _renderIcon(iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
