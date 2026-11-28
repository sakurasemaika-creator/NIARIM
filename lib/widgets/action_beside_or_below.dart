import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 字の間で折り返せる中国語・日本語の字（かな・漢字）。
final RegExp _cjk = RegExp(
  r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
);
final RegExp _breakableSpace = RegExp(r'[\s\u200B]');
const _noBreakSpaces = {'\u00A0', '\u202F'};

/// 自分で、中国語・日本語の字の間の折り返しも入れた最小の固有幅を答える文の
/// 描画（`KeepTogetherText`）。[ActionBesideOrBelow]は、この中の段落を測り
/// 直さない（中の段落は欄の幅ごとに描く文を変え、並べる前は無いので、測り
/// 直すと並べるたびに答えが変わる）。
abstract interface class ReportsWidestWord {}

/// 文を入れた[painter]の、折り返せないいちばん広いかたまり（語）の幅。
/// [reported]はFlutterの答え（幅の制限なしで並べた最小の固有幅）。
///
/// Flutter（SkParagraph）は、中国語・日本語の文が1つの書体で描けて途中に
/// 空白が無いと、字の間で折り返せることを最小の固有幅に入れず、文全体の幅を
/// 返す（中国語の本文の書体〔Noto Serif SC〕の文で起きた）。中国語・日本語の
/// 字を含む文は、折り返す前に組んだ段落から、折り返せない部分の幅を測る。
/// 極端に細い幅で並べ直すと「3px」も途中で切れて測定幅が足りなくなる。
double widestUnbreakableWidth(
  TextPainter painter, {
  required double reported,
  VoidCallback? onLayout,
}) {
  final text = painter.plainText;
  if (!_cjk.hasMatch(text)) return reported;
  painter.layout();
  onLayout?.call();
  var widest = 0.0;
  for (final (start, end) in _unbreakableRuns(text)) {
    var width = 0.0;
    for (final box in painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    )) {
      width += box.right - box.left;
    }
    widest = math.max(widest, width);
  }
  return widest > 0 ? widest : reported;
}

/// 中国語・日本語の字の間と空白で区切る。欧文の語・数と単位・語結合子や
/// 分割しない空白でつないだ部分はひとまとまりにする。
Iterable<(int, int)> _unbreakableRuns(String text) sync* {
  const wordJoiner = '\u2060';
  var offset = 0;
  int? start;
  var previousCjk = false;
  var joined = false;
  for (final char in text.characters) {
    if (char == wordJoiner) {
      joined = start != null;
      offset += char.length;
      continue;
    }
    final cjk = _cjk.hasMatch(char);
    final noBreakSpace = _noBreakSpaces.contains(char);
    final space = !noBreakSpace && _breakableSpace.hasMatch(char);
    if (start != null &&
        (space || (!joined && !noBreakSpace && (cjk || previousCjk)))) {
      yield (start, offset);
      start = null;
    }
    if (!space) start ??= offset;
    joined = noBreakSpace;
    previousCjk = cjk;
    offset += char.length;
  }
  if (start != null) yield (start, offset);
}

/// [ActionBesideOrBelow]の子の置き場所。
enum ActionBesideOrBelowSlot { text, action }

/// 文（題・説明）と操作（受け取るボタン等）を並べる。
///
/// 操作を文の右に置くと、文が単語の途中で折り返すか、文の幅が全体の
/// [minTextFraction]より狭くなるときは、操作を文の下（行の終わりの側）へ
/// 回す。行の右端に操作を固定すると、言語や文字の大きさによってはボタンが
/// 行の大半を取り、文が数十pxの列に押し込まれて単語の途中や1文字ずつ
/// 折り返した（スペイン語・フランス語の「Reclamar」「Non atteint」等）。
///
/// [actionFirst]なら操作を文の前（左）に置き、横に並べられないときは文の
/// 上へ回す（行の先頭のチェックボックス等。文は行の幅いっぱいを使える）。
///
/// [minTextWidth]を渡すと、文の中身を見ずに、文に残る幅だけで決める（一覧の
/// カードのように、同じ幅・同じ操作の行が文の長さで並べ方を変えないように
/// するとき）。
class ActionBesideOrBelow
    extends
        SlottedMultiChildRenderObjectWidget<
          ActionBesideOrBelowSlot,
          RenderBox
        > {
  const ActionBesideOrBelow({
    super.key,
    required this.text,
    required this.action,
    this.gap = 12,
    this.spacing = 6,
    this.minTextFraction = 0.55,
    this.actionFirst = false,
    this.minTextWidth,
    this.besideActionPadding = EdgeInsets.zero,
    this.belowActionPadding = EdgeInsets.zero,
    this.actionAboveAtEnd = false,
  });

  /// 文。幅が足りなければ折り返してよいもの。
  final Widget text;

  /// 操作。自分の幅で描くもの（折り返さない）。
  final Widget action;

  /// 横に並べるときの文と操作の間。
  final double gap;

  /// 下に回すときの文と操作の間。
  final double spacing;

  /// 横に並べるとき、文に残す幅の下限（全体の幅に対する割合）。
  final double minTextFraction;

  /// 操作を文の前（横に並べないときは上）に置くか。
  final bool actionFirst;

  /// 横に並べるとき、文に残す幅の下限（論理px）。nullでなければ、横に並べる
  /// かをこの幅が残るかだけで決め、[minTextFraction]と文の折り返しは見ない
  /// （[double.infinity]ならいつも下へ回す）。
  final double? minTextWidth;

  /// 横に並べたときの、操作の周りの余白。
  final EdgeInsetsGeometry besideActionPadding;

  /// 下（[actionFirst]なら上）に回したときの、操作の周りの余白。
  final EdgeInsetsGeometry belowActionPadding;

  /// 横に並べられないとき、操作を文の下ではなく上の行の終わりの側に置くか
  /// （[actionFirst]でないとき）。題の右の閉じるボタン（×）のように、文の
  /// 後ろに並べるが、下へ回すと閉じるボタンに見えないもの。
  final bool actionAboveAtEnd;

  @override
  Iterable<ActionBesideOrBelowSlot> get slots => ActionBesideOrBelowSlot.values;

  @override
  Widget? childForSlot(ActionBesideOrBelowSlot slot) => switch (slot) {
    ActionBesideOrBelowSlot.text => text,
    ActionBesideOrBelowSlot.action => action,
  };

  @override
  RenderActionBesideOrBelow createRenderObject(BuildContext context) =>
      RenderActionBesideOrBelow(
        gap: gap,
        spacing: spacing,
        minTextFraction: minTextFraction,
        actionFirst: actionFirst,
        minTextWidth: minTextWidth,
        besideActionPadding: besideActionPadding,
        belowActionPadding: belowActionPadding,
        actionAboveAtEnd: actionAboveAtEnd,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderActionBesideOrBelow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..spacing = spacing
      ..minTextFraction = minTextFraction
      ..actionFirst = actionFirst
      ..minTextWidth = minTextWidth
      ..besideActionPadding = besideActionPadding
      ..belowActionPadding = belowActionPadding
      ..actionAboveAtEnd = actionAboveAtEnd
      ..textDirection = Directionality.of(context);
  }
}

/// [ActionBesideOrBelow]の描画。
class RenderActionBesideOrBelow extends RenderBox
    with SlottedContainerRenderObjectMixin<ActionBesideOrBelowSlot, RenderBox> {
  RenderActionBesideOrBelow({
    required this._gap,
    required this._spacing,
    required this._minTextFraction,
    required this._textDirection,
    this._actionFirst = false,
    this._minTextWidth,
    this._besideActionPadding = EdgeInsets.zero,
    this._belowActionPadding = EdgeInsets.zero,
    this._actionAboveAtEnd = false,
  });

  bool get actionAboveAtEnd => _actionAboveAtEnd;
  bool _actionAboveAtEnd;
  set actionAboveAtEnd(bool value) {
    if (_actionAboveAtEnd == value) return;
    _actionAboveAtEnd = value;
    markNeedsLayout();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get minTextFraction => _minTextFraction;
  double _minTextFraction;
  set minTextFraction(double value) {
    if (_minTextFraction == value) return;
    _minTextFraction = value;
    markNeedsLayout();
  }

  bool get actionFirst => _actionFirst;
  bool _actionFirst;
  set actionFirst(bool value) {
    if (_actionFirst == value) return;
    _actionFirst = value;
    markNeedsLayout();
  }

  double? get minTextWidth => _minTextWidth;
  double? _minTextWidth;
  set minTextWidth(double? value) {
    if (_minTextWidth == value) return;
    _minTextWidth = value;
    markNeedsLayout();
  }

  EdgeInsetsGeometry get besideActionPadding => _besideActionPadding;
  EdgeInsetsGeometry _besideActionPadding;
  set besideActionPadding(EdgeInsetsGeometry value) {
    if (_besideActionPadding == value) return;
    _besideActionPadding = value;
    markNeedsLayout();
  }

  EdgeInsetsGeometry get belowActionPadding => _belowActionPadding;
  EdgeInsetsGeometry _belowActionPadding;
  set belowActionPadding(EdgeInsetsGeometry value) {
    if (_belowActionPadding == value) return;
    _belowActionPadding = value;
    markNeedsLayout();
  }

  EdgeInsets get _besidePadding => _besideActionPadding.resolve(_textDirection);
  EdgeInsets get _belowPadding => _belowActionPadding.resolve(_textDirection);

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _text => childForSlot(ActionBesideOrBelowSlot.text);
  RenderBox? get _action => childForSlot(ActionBesideOrBelowSlot.action);

  /// 幅[width]のとき、操作を文の右に置くか。
  bool _beside(double width) {
    final text = _text;
    final action = _action;
    if (text == null || action == null || !width.isFinite) return true;
    final textWidth =
        width -
        gap -
        action.getMaxIntrinsicWidth(double.infinity) -
        _besidePadding.horizontal;
    final minTextWidth = this.minTextWidth;
    if (minTextWidth != null) return textWidth >= minTextWidth;
    if (textWidth <= 0) return false;
    // 文が1行に収まるなら横に並べる。
    if (text.getMaxIntrinsicWidth(double.infinity) <= textWidth) return true;
    // 折り返すなら、十分な幅が残り、どの単語も途中で切れないときだけ。
    return textWidth >= width * minTextFraction &&
        _widestWord(text) <= textWidth;
  }

  /// 文[text]の中で、折り返せないいちばん広いかたまり（語）の幅。
  ///
  /// 文の最小の固有幅で数える。ただしFlutter（SkParagraph）は、中国語・日本語の
  /// 文が1つの書体で描けて途中に空白が無いと、字の間で折り返せることを最小の
  /// 固有幅に入れず、文全体の幅を返す（中国語の本文の書体〔Noto Serif SC〕の
  /// 文で起きた）。中国語・日本語は字の間で折り返してよいので、文の中の段落を
  /// 折り返す幅で並べ直して、離せないかたまりの幅を測る
  /// （[widestUnbreakableWidth]）。Flutterの測定幅より大きいかたまりも
  /// 入る場合にだけ、操作と文を横に並べる。
  /// 自分で数え直した幅を答える文（[ReportsWidestWord]）の中は測り直さない。
  double _widestWord(RenderBox text) {
    final reported = text.getMinIntrinsicWidth(double.infinity);
    var widestReported = 0.0;
    var widestActual = 0.0;
    void visit(RenderObject child) {
      if (child is ReportsWidestWord) return;
      if (child is RenderParagraph) {
        widestReported = math.max(
          widestReported,
          child.getMinIntrinsicWidth(double.infinity),
        );
        widestActual = math.max(widestActual, _paragraphWidestWord(child));
        return;
      }
      child.visitChildren(visit);
    }

    visit(text);
    if (widestActual == widestReported) return reported;
    final overestimate = math.max(0.0, widestReported - widestActual);
    return math.max(widestActual, reported - overestimate);
  }

  /// 段落[p]の、折り返せないいちばん広いかたまりの幅（[_widestWord]）。
  static double _paragraphWidestWord(RenderParagraph p) {
    final reported = p.getMinIntrinsicWidth(double.infinity);
    final text = p.text.toPlainText(includePlaceholders: false);
    var placeholders = false;
    p.text.visitChildren((span) {
      if (span is PlaceholderSpan) placeholders = true;
      return !placeholders;
    });
    // 測り違えるのは中国語・日本語の字を含む文だけ。折り返さない段落・部品を
    // 挟む段落は、測り直さない。
    if (!_cjk.hasMatch(text) || !p.softWrap || placeholders) return reported;
    final painter = TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textAlign: p.textAlign,
      textScaler: p.textScaler,
      locale: p.locale,
      strutStyle: p.strutStyle,
      textWidthBasis: p.textWidthBasis,
      textHeightBehavior: p.textHeightBehavior,
    );
    final actual = widestUnbreakableWidth(painter, reported: reported);
    painter.dispose();
    return actual;
  }

  /// 子の大きさと位置を決める。[place]がnullなら大きさだけを求める
  /// （dry layout）。戻り値は全体の大きさと文の上端。
  ({Size size, double textTop}) _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) measure, {
    void Function(RenderBox child, Offset offset)? place,
  }) {
    final text = _text;
    final action = _action;
    final width = constraints.maxWidth;
    final ltr = textDirection == TextDirection.ltr;
    if (text == null || action == null) {
      final only = text ?? action;
      if (only == null) return (size: constraints.smallest, textTop: 0);
      final size = measure(only, constraints.loosen());
      place?.call(only, Offset.zero);
      return (size: constraints.constrain(size), textTop: 0);
    }
    if (_beside(width)) {
      final pad = _besidePadding;
      // 操作の大きさは、周りの余白を含めて数える。
      final actionSize = pad.inflateSize(
        measure(
          action,
          BoxConstraints(maxWidth: math.max(0.0, width - pad.horizontal)),
        ),
      );
      final textMax = math.max(0.0, width - gap - actionSize.width);
      final textSize = measure(text, BoxConstraints(maxWidth: textMax));
      final fullWidth = width.isFinite
          ? width
          : textSize.width + gap + actionSize.width;
      final height = math.max(textSize.height, actionSize.height);
      final textTop = (height - textSize.height) / 2;
      // 先に置く方は行の始まり（左から書く言語なら左端）、後の方は行の終わり。
      // 文は行の始まりの側に寄せる（操作が先ならその後ろ）。
      final before = actionFirst ? actionSize.width + gap : 0.0;
      final textLeft = ltr ? before : fullWidth - textSize.width - before;
      place?.call(text, Offset(textLeft, textTop));
      place?.call(
        action,
        Offset(
              actionFirst == ltr ? 0 : fullWidth - actionSize.width,
              (height - actionSize.height) / 2,
            ) +
            pad.topLeft,
      );
      return (
        size: constraints.constrain(Size(fullWidth, height)),
        textTop: textTop,
      );
    }
    final pad = _belowPadding;
    final textSize = measure(text, BoxConstraints(maxWidth: width));
    final actionSize = pad.inflateSize(
      measure(
        action,
        BoxConstraints(maxWidth: math.max(0.0, width - pad.horizontal)),
      ),
    );
    final size = constraints.constrain(
      Size(width, textSize.height + spacing + actionSize.height),
    );
    if (actionFirst) {
      // 操作を上の行の始まりに、文をその下に行の幅いっぱいで。
      final textTop = actionSize.height + spacing;
      place?.call(
        action,
        Offset(ltr ? 0 : width - actionSize.width, 0) + pad.topLeft,
      );
      place?.call(text, Offset(ltr ? 0 : width - textSize.width, textTop));
      return (size: size, textTop: textTop);
    }
    if (actionAboveAtEnd) {
      // 操作を上の行の終わりに、文をその下に行の幅いっぱいで。
      final textTop = actionSize.height + spacing;
      place?.call(
        action,
        Offset(ltr ? width - actionSize.width : 0, 0) + pad.topLeft,
      );
      place?.call(text, Offset(ltr ? 0 : width - textSize.width, textTop));
      return (size: size, textTop: textTop);
    }
    place?.call(text, Offset(ltr ? 0 : width - textSize.width, 0));
    place?.call(
      action,
      Offset(ltr ? width - actionSize.width : 0, textSize.height + spacing) +
          pad.topLeft,
    );
    return (size: size, textTop: 0);
  }

  @override
  void performLayout() {
    size = _arrange(
      constraints,
      (child, c) => (child..layout(c, parentUsesSize: true)).size,
      place: (child, offset) =>
          (child.parentData! as BoxParentData).offset = offset,
    ).size;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, (child, c) => child.getDryLayout(c)).size;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final text = _text;
    if (text == null) return null;
    final distance = text.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return distance + (text.parentData! as BoxParentData).offset.dy;
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final text = _text;
    if (text == null) return null;
    BoxConstraints? textConstraints;
    final arranged = _arrange(constraints, (child, c) {
      if (identical(child, text)) textConstraints = c;
      return child.getDryLayout(c);
    });
    final distance = text.getDryBaseline(textConstraints!, baseline);
    return distance == null ? null : distance + arranged.textTop;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _text?.getMinIntrinsicWidth(double.infinity) ?? 0,
    _action == null
        ? 0
        : _action!.getMinIntrinsicWidth(double.infinity) +
              _belowPadding.horizontal,
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final text = _text?.getMaxIntrinsicWidth(double.infinity) ?? 0;
    final action = _action?.getMaxIntrinsicWidth(double.infinity) ?? 0;
    return _text != null && _action != null
        ? text + gap + action + _besidePadding.horizontal
        : text + action;
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) height,
  ) {
    final text = _text;
    final action = _action;
    if (text == null || action == null) {
      final only = text ?? action;
      return only == null ? 0 : height(only, width);
    }
    final actionWidth = action.getMaxIntrinsicWidth(double.infinity);
    if (_beside(width)) {
      final pad = _besidePadding;
      return math.max(
        height(text, math.max(0, width - gap - actionWidth - pad.horizontal)),
        height(action, actionWidth) + pad.vertical,
      );
    }
    final pad = _belowPadding;
    return height(text, width) +
        spacing +
        height(action, math.max(0, width - pad.horizontal)) +
        pad.vertical;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [_text, _action]) {
      if (child == null) continue;
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_action, _text]) {
      if (child == null) continue;
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
