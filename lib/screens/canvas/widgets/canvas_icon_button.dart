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
///
/// この8方向の重ねは、以前は`Positioned`で`Icon`を8個並べた`Stack`
/// （本体と合わせて1ボタンあたりウィジェット9個）で実装していたが、
/// `Icon.shadows`（ぼかし半径0のShadowを8個）へ置き換えて**ウィジェット
/// 1個**にした。見た目は同じで、ボタン1つあたりのElement・RenderObjectが
/// 9分の1になる。ツールバーには常時20個前後のボタンが並ぶため、この差は
/// そのままキャンバス画面のビルド・レイアウト負荷に効く。
/// 副次的な利点として、テストの`find.byIcon`が1ボタンにつき9個ヒットして
/// `findsOneWidget`が使えない問題も解消される。
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

  /// 長押しでツールチップを出すかどうか。
  ///
  /// Materialの[Tooltip]は既定でタッチの長押しに反応する。このボタンを
  /// `GestureDetector(onLongPress: ...)`で包んで独自の長押しメニューを
  /// 付けている場合、**ジェスチャーアリーナで内側のTooltipが勝ってしまい、
  /// 外側の長押しが一度も発火しない**（ツールチップだけが出る）。
  /// そういう箇所ではfalseにして、長押しを外側へ譲る。
  /// falseでもマウスホバーでのツールチップ表示は従来どおり効くため、
  /// PC/DeXでのラベル確認手段は失われない。
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
  ///
  /// [icon]（Material Icons等のグリフ）の場合は`Icon.shadows`で1ウィジェット
  /// に収める。[iconBuilder]（Canvasで自前描画するアイコン。消しゴム等）は
  /// 任意の描画内容でシャドウを掛けられないため、従来どおり8方向へ
  /// 重ね描きする。現状[iconBuilder]の利用は1箇所だけなので、ここが
  /// 9ウィジェットのまま残っても全体への影響は小さい。
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
      // ぼかし半径0のShadowは「その位置へ同じ形をもう一度描く」ことと同じ。
      // 8方向ぶん指定することで、Positionedで重ねていたのと同じ縁取りになる。
      shadows: [
        for (final o in _offsets)
          Shadow(color: outlineColor, offset: o, blurRadius: 0),
      ],
    );
  }

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
