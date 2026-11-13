import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';

/// 保存の画面の上部バーの画面名。入らないときは省略記号で切らずに出さない
/// （所有者の判断4：画面名が入らないときは書かなくてよい）。読み上げの名前は
/// 残す。入るときは普通の`Text`と同じ。
class SaveScreenTitle extends StatelessWidget {
  const SaveScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context);
        var textStyle = style.style;
        // `Text`と同じく、端末の「太字」の設定を足して測る。
        if (MediaQuery.boldTextOf(context)) {
          textStyle = textStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
          textWidthBasis: style.textWidthBasis,
          textHeightBehavior: style.textHeightBehavior,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        final lineHeight = painter.height;
        painter.dispose();
        if (fits) return Text(text);
        // 描かないが、読み上げでは画面名を読む。大きさの無い所は読み上げの
        // 木から外れるので、画面名の欄の幅と1行の高さを取る。
        return Semantics(
          label: text,
          child: SizedBox(
            width: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            height: lineHeight,
          ),
        );
      },
    );
  }
}

/// セーブツリーの上部バーの「保存」。文字のボタンが戻るボタンに重ならずに
/// （画面名の欄を幅0にせずに）入るときはそのまま出し、入らないとき（狭い画面・大きな文字・長い言語）は
/// アイコンだけのボタンにして、名前を長押し・ホバー（ツールチップ）と読み上げで
/// 出す（文字を縮めない・切らない。以前は上部バーの右がはみ出し、戻るボタンの
/// 上に「ヘルプ」が重なった）。上部バーの`actions`に直接置く（自分で
/// `Flexible`になり、ほかの操作の残りの幅に入る）。
class SaveTreeBarSaveButton extends StatefulWidget {
  const SaveTreeBarSaveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<SaveTreeBarSaveButton> createState() => _SaveTreeBarSaveButtonState();
}

class _SaveTreeBarSaveButtonState extends State<SaveTreeBarSaveButton> {
  /// 文字のボタンの幅（見えない写しで、この組み立ての中で先に測る）。
  double _labeledWidth = 0;

  /// 下のLayoutBuilderが決めたときに使った[_labeledWidth]。
  double? _decidedWith;

  /// 写しの幅を測った。下のLayoutBuilderがこの幅で決めていなければ、次の
  /// フレームで決め直す（開いたまま文字の大きさを変えると、写しは自分だけで
  /// 測り直されるので、LayoutBuilderが先に前の幅で決め、文字の「保存」が
  /// 戻るボタンの上まで広がったままになった）。
  void _measured(double width) {
    _labeledWidth = width;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _decidedWith != _labeledWidth) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.commonSave;
    // 文字の大きさ・テーマが変わったら測り直して決め直す（ボタンの中だけが
    // 作り直されると、下のLayoutBuilderは前の幅で決めたままになる）。
    MediaQuery.textScalerOf(context);
    Theme.of(context);
    Widget labeled() => FilledButton.icon(
      icon: const Icon(Icons.save, size: 16),
      label: Text(label),
      onPressed: widget.onPressed,
    );
    return Flexible(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 測るだけの写し：描かず、押せず、フォーカス・読み上げにも出ない。
          // 幅の制約を外して、文字のボタン本来の幅を測る。Stackは子を順に
          // 並べるので、下のLayoutBuilderはこの組み立ての測った幅で決める。
          Offstage(
            child: ExcludeFocus(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: TickerMode(
                    enabled: false,
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: double.infinity,
                      child: _WidthProbe(onLayout: _measured, child: labeled()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              _decidedWith = _labeledWidth;
              // 文字の「保存」は、画面名の欄（両側の間隔の内側）が0にならない
              // ときだけ（0になると、出さない画面名が読み上げの木からも外れる）。
              final titleRoom =
                  2 *
                      (AppBarTheme.of(context).titleSpacing ??
                          NavigationToolbar.kMiddleSpacing) +
                  1;
              if (_labeledWidth <=
                  constraints.maxWidth - _leadingWidth(context) - titleRoom) {
                return labeled();
              }
              return Tooltip(
                message: label,
                // 読み上げの名前はボタンそのものに付ける（ツールチップの名前は
                // ボタンでない別の節になり、押せる節に名前が無かった）。
                excludeFromSemantics: true,
                child: FilledButton(
                  onPressed: widget.onPressed,
                  child: Icon(Icons.save, size: 16, semanticLabel: label),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 上部バーの左の戻るボタン（引き出しのボタン）の幅。AppBarと同じ決まりで
/// 出すかどうかを決める。
double _leadingWidth(BuildContext context) {
  final hasLeading =
      (Scaffold.maybeOf(context)?.hasDrawer ?? false) ||
      (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
  if (!hasLeading) return 0;
  return AppBarTheme.of(context).leadingWidth ?? kToolbarHeight;
}

/// 子を並べた幅を[onLayout]へ渡す。
class _WidthProbe extends SingleChildRenderObjectWidget {
  const _WidthProbe({required this.onLayout, super.child});

  final ValueChanged<double> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWidthProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWidthProbe renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderWidthProbe extends RenderProxyBox {
  _RenderWidthProbe(this.onLayout);

  ValueChanged<double> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size.width);
  }
}
