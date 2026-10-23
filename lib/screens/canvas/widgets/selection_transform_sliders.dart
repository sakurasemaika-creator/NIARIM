import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 選択範囲の変形を数値で指定する、画面下部のスライダー群。
///
/// 4本（X移動・Y移動・拡大縮小率・回転角度）とも**いまの状態が中央＝0**で、
/// 右へ動かすとプラス・左へ動かすとマイナスになる。指を離すとその時点の値が
/// 実画素へ確定し、スライダーは中央へ戻る（＝またそこが新しい0になる）。
///
/// ハンドルのドラッグだけだと細かい数値指定ができず、逆にスライダーだけだと
/// 感覚的な操作ができないため、両方を並立させている。
class SelectionTransformSliders extends StatelessWidget {
  const SelectionTransformSliders({
    super.key,
    required this.moveX,
    required this.moveY,
    required this.scale,
    required this.rotateDeg,
    required this.onChanged,
    required this.onCommit,
    required this.maxMove,
  });

  final double moveX;
  final double moveY;

  /// 倍率。1.0が等倍（＝変化なし）で、スライダーの中央にあたる。
  final double scale;
  final double rotateDeg;

  /// 4値のいずれかが動いたとき。確定はせずライブプレビューだけ更新する。
  final void Function({
    double? moveX,
    double? moveY,
    double? scale,
    double? rotateDeg,
  })
  onChanged;

  /// スライダーから指を離したとき（＝実画素へ確定してよいとき）。
  final VoidCallback onCommit;

  /// 移動量スライダーの端の値（キャンバスpx）。キャンバスの大きさに合わせる。
  final double maxMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget row({
      required String label,
      required String valueText,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onSlide,
    }) {
      // 1行目に項目名と値、2行目にスライダーだけを置き、スライダー本体を
      // 横幅いっぱいに広げる（項目名や値と同じ行に置くと、狭い画面では
      // そのぶんスライダーが縮む）。4本ぶんの縦幅は抑える。既定のSliderは
      // 1本48px近くあり、そのまま4本並べるとキャンバスを圧迫して画面下端から
      // はみ出す。
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  valueText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onSlide,
                onChangeEnd: (_) => onCommit(),
              ),
            ),
          ),
        ],
      );
    }

    String signed(double v) => '${v >= 0 ? '+' : ''}${v.round()}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            label: l10n.canvasSelectionSliderMoveX,
            valueText: signed(moveX),
            value: moveX,
            min: -maxMove,
            max: maxMove,
            onSlide: (v) => onChanged(moveX: v),
          ),
          row(
            label: l10n.canvasSelectionSliderMoveY,
            valueText: signed(moveY),
            value: moveY,
            min: -maxMove,
            max: maxMove,
            onSlide: (v) => onChanged(moveY: v),
          ),
          row(
            label: l10n.canvasSelectionSliderScale,
            valueText: '${scale.toStringAsFixed(2)}x',
            value: scale,
            min: 0.2,
            max: 3.0,
            onSlide: (v) => onChanged(scale: v),
          ),
          row(
            label: l10n.canvasSelectionSliderRotate,
            valueText: '${signed(rotateDeg)}°',
            value: rotateDeg,
            min: -180,
            max: 180,
            onSlide: (v) => onChanged(rotateDeg: v),
          ),
        ],
      ),
    );
  }
}
