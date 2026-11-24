import 'package:flutter/material.dart';

import '../../../widgets/action_beside_or_below.dart';
import '../../../widgets/keep_together_text.dart';

/// 書き出しの大きさの選択肢（チップ）の中身：比率の枠・名前（下に用途）・
/// 右端に画素数。新規作成の画面とテーマの見本一覧の模型で同じものを使う。
///
/// 選択肢を全幅にそろえて画素数の列を右端でそろえる（名前・用途・画素数を
/// 1つの文でつないだ長さばらばらのチップが折り返して並び、比べにくかった）。
/// 画素数が横に入らない幅・文字の倍率では名前の下へ回す。[text]が
/// 「名前 (用途)」「名前（用途）」の形なら、用途を下の行に小さく出す。
///
/// チップは名前を1行で描く（`DefaultTextStyle`の`maxLines: 1`）ので、
/// 呼び出し側でその決まりを置き換えてから包むこと。
class CanvasSizeChoiceLabel extends StatelessWidget {
  const CanvasSizeChoiceLabel({
    super.key,
    required this.text,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.width,
  });

  final String text;
  final int canvasWidth;
  final int canvasHeight;

  /// 中身の幅（チップの印・余白を引いた残り）。
  final double width;

  @override
  Widget build(BuildContext context) {
    final parts = RegExp(r'^(.*?)\s*[（(](.*)[）)]$').firstMatch(text);
    final title = parts?.group(1) ?? text;
    final note = parts?.group(2);
    final ink = DefaultTextStyle.of(context).style;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          CanvasAspectGlyph(
            width: canvasWidth,
            height: canvasHeight,
            color: ink.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ActionBesideOrBelow(
              gap: 8,
              text: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  messageText(
                    title,
                    keepLineStarts: true,
                    keepLastPhrase: true,
                    style: ink.copyWith(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note != null && note.isNotEmpty)
                    messageText(
                      note,
                      keepLineStarts: true,
                      keepLastPhrase: true,
                      // 「…投稿向 / け」と最後の1字だけを次の行へ送らない
                      // （ひらがなの境目の無い語は最後の語として見つからない）。
                      keep: _lastCjkRun(note),
                      style: ink.copyWith(
                        fontSize: 12,
                        height: 1.35,
                        color: ink.color?.withValues(alpha: 0.72),
                      ),
                    ),
                ],
              ),
              action: Text(
                '$canvasWidth×$canvasHeight',
                style: ink.copyWith(
                  fontSize: 12.5,
                  height: 1.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [text]の終わりの、日本語・中国語の字だけが続く4字（無ければ空）。
List<String> _lastCjkRun(String text) {
  if (text.length < 6) return const [];
  final tail = text.substring(text.length - 4);
  return RegExp(r'^[぀-ヿ㐀-鿿]{4}$').hasMatch(tail) &&
          text.indexOf(tail) == text.length - 4
      ? [tail]
      : const [];
}

/// 書き出しの大きさの比率を表す小さな枠（長い辺を18pxにそろえる）。
class CanvasAspectGlyph extends StatelessWidget {
  const CanvasAspectGlyph({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  });

  final int width;
  final int height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const longest = 18.0;
    final w = width >= height ? longest : longest * width / height;
    final h = height >= width ? longest : longest * height / width;
    return ExcludeSemantics(
      child: SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: color ?? Theme.of(context).colorScheme.onSurface,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
