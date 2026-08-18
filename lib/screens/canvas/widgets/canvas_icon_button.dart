import 'package:flutter/material.dart';

/// キャンバスモード内の常設ボタン共通スタイル（ユーザー指示）：
/// 背景は一切持たせず、キャンバス上にアイコンだけが浮かんでいる状態にした
/// うえで、そのアイコンの形にぴったり沿う半透明の黒い縁取りを付ける。
/// アイコンの周囲を大きな円で囲う従来方式（IconButtonのデフォルト背景・
/// 円形ボーダー）は、マークの形に沿わず視認性が悪いという指摘を受けて
/// 廃止した。ここでは同じアイコンを黒・半透明で8方向へわずかにずらして
/// 重ね描きすることで、アイコンの輪郭そのものに沿った縁取り（アウトライン
/// ストローク）を疑似的に作り、どんな背景色のキャンバス上でも視認できる
/// ようにしている。
class CanvasIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool selected;
  final double iconSize;

  const CanvasIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.selected = false,
    this.iconSize = 20,
  });

  static const _offsets = [
    Offset(-1, -1), Offset(0, -1), Offset(1, -1),
    Offset(-1, 0), Offset(1, 0),
    Offset(-1, 1), Offset(0, 1), Offset(1, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final iconColor = selected ? primary : Colors.white;
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
                    child: Icon(icon, size: iconSize, color: Colors.black.withValues(alpha: 0.55)),
                  ),
                Icon(icon, size: iconSize, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
