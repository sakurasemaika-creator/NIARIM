part of 'home_matrix_harness.dart';

/// 続きのマトリクス（`home_matrix2_*_test.dart`）で、各セルに足す確かめ。
///
/// [HomeMatrix.extended]が真のときだけ働く（`home_display_matrix_test.dart`は
/// 今までどおりの確かめだけで、遅くならない）。
///
/// * 文の切れ：行の上限・1行に入らない文で切れた文（選択中の操作バーの、
///   長押し・ホバーで全文が読める語だけは所有者の決まりで許す）。
/// * 語の途中の折り返し：ラテン文字・ハングルの語の中で行が変わった所
///   （その語が1行に入る幅のときだけ。入らない長い語は折るしかない）と、
///   行の頭・終わりに来てはいけない字。
/// * 言語：見えている文（利用者が付けた名前を除く）に、その言語の文に無い
///   字（仮名・ハングル・その言語の文で使わない漢字）や、ほかの言語の文と
///   同じ文が無い。
/// * 読める色：文字・印の色と、その下の面の色の組を、アプリ自身の判定
///   （[isEssentialTextNearlyInvisible]：テーマの救済ボタンを出す目安）で
///   確かめる。
/// * 押せる大きさ：Androidの決まり（48×48）を、意味の木で確かめる
///   （[androidTapTargetGuideline]）。
/// * 一覧の一番下まで送ったとき、浮かぶボタンがカードの星・メニュー・絵・
///   名前に重ならない。
/// * 安全な領域：状態バー・ジェスチャー/ボタンの帯・切り欠きの下に、文字・
///   押す物が無い（縦に送る一覧の中は、左右だけ。一番下まで送ったときは
///   下の帯も）。
/// * フォーカスの順（[walkFocus]）：Tabで回すと、上部バー→一覧→浮かぶ
///   ボタンの順に、一覧の中は読む順に進み、止まった所がいつも見えて押せて、
///   最初の所へ戻って一巡する。引き出しを開いているときは引き出しの中だけを
///   回る。
extension HomeMatrixChecks on HomeMatrix {
  /// 今の画面（[drawer]なら引き出し）の続きの確かめ。
  List<String> _extendedProblems({required bool drawer, required bool atEnd}) {
    final scope = drawer ? find.byType(Drawer) : find.byType(HomeScreen);
    if (scope.evaluate().isEmpty) return const [];
    final shown = _shownTexts(scope);
    return [
      ..._cutTexts(shown),
      ..._wordBreaks(shown),
      ..._foreignTexts(shown),
      ..._unreadableTexts(shown),
      ..._safeAreaProblems(shown, scope, atEnd: atEnd),
      if (checkTapTargets) ..._tapTargetProblems(),
      if (atEnd && !drawer) ..._cardPartsUnderFab(),
    ];
  }

  // ─── 見えている文 ───────────────────────────────────────────────────

  /// [scope]の中で、画面と（あれば）スクロールの枠の中に少しでも描かれて
  /// いる段落（文字と、文字で描く印）。
  List<_Shown> _shownTexts(Finder scope) {
    final screen = Offset.zero & size;
    final out = <_Shown>[];
    for (final e
        in find
            .descendant(of: scope, matching: find.byType(RichText))
            .evaluate()) {
      final p = e.renderObject;
      if (p is! RenderParagraph ||
          !p.attached ||
          !p.hasSize ||
          p.size.isEmpty ||
          !_painted(p)) {
        continue;
      }
      final rect = HomeMatrix._globalRect(p);
      var visible = rect.intersect(screen);
      for (final s in HomeMatrix._scrollAncestors(e)) {
        visible = visible.intersect(
          HomeMatrix._globalRect(s.context.findRenderObject()! as RenderBox),
        );
      }
      if (visible.width <= 0.5 || visible.height <= 0.5) continue;
      out.add(
        _Shown(
          e,
          p,
          rect,
          whole:
              (visible.width - rect.width).abs() < 1 &&
              (visible.height - rect.height).abs() < 1,
        ),
      );
    }
    return out;
  }

  /// 描かれているか（隠す・透明にする親の下ではない）。
  static bool _painted(RenderObject ro) {
    RenderObject? node = ro;
    while (node != null) {
      if (node is RenderOffstage && node.offstage) return false;
      if (node is RenderOpacity && node.opacity == 0) return false;
      if (node is RenderAnimatedOpacity && node.opacity.value == 0) {
        return false;
      }
      node = node.parent;
    }
    return true;
  }

  /// 描いた文（幅の無い字〔語結合子・幅の無い空白・ソフトハイフン〕を除く）。
  static String _plain(RenderParagraph p) => p.text
      .toPlainText(includeSemanticsLabels: false)
      .replaceAll(RegExp('[⁠​­]'), '');

  /// 文字で描く印（Material Icons）の段落か。
  static bool _isGlyph(RenderParagraph p) {
    final family = p.text.style?.fontFamily ?? '';
    if (family.contains('MaterialIcons')) return true;
    final text = p.text.toPlainText(includeSemanticsLabels: false);
    return text.runes.length == 1 &&
        text.runes.single >= 0xE000 &&
        text.runes.single <= 0xF8FF;
  }

  /// 問題の文に添える、その部品の場所（近い目印の部品）。
  static String _placeOf(Element element) {
    String? found;
    element.visitAncestorElements((a) {
      final w = a.widget;
      final key = w.key;
      if (key is ValueKey<String>) {
        found = key.value;
        return false;
      }
      if (_landmarks.contains(w.runtimeType.toString())) {
        found = w.runtimeType.toString();
        return false;
      }
      return true;
    });
    return found == null ? '' : ' [$found]';
  }

  static const _landmarks = {
    'AppBar',
    'TabBar',
    'Drawer',
    'ListTile',
    'HomeSelectionToolbar',
    'EmptyStatePlaceholder',
    'ProjectsLoadFailureNotice',
    'SortModeControl',
    'FilterChip',
    'SegmentedButton<bool>',
    'ExportedWorkCard',
    'CollectionActionFrame',
    'FloatingActionButton',
    'AlertDialog',
  };

  // ─── 文の切れ・語の途中の折り返し ─────────────────────────────────────

  List<String> _cutTexts(List<_Shown> shown) {
    final out = <String>{};
    for (final s in shown) {
      final p = s.paragraph;
      final cut =
          p.didExceedMaxLines ||
          (!p.softWrap &&
              p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5);
      if (!cut || _designedCut(s.element, p)) continue;
      out.add('text cut: "${_plain(p)}"${_placeOf(s.element)}');
    }
    return out.toList();
  }

  /// 決まりで省略してよい文。
  ///
  /// * 選択中の操作バーの語（所有者の決まり。長押し・ホバーで全文が読める）。
  /// * カードの名前（所有者の判断5）の、名前の帯が上限を決めた幅
  ///   （[kCollectionTileNameReferenceWidth]、文字の倍率1倍）より狭いとき
  ///   （幅320pxの小・列が1つ増えたばかりの幅・文字の倍率が大きいとき）の
  ///   2行目の終わりの「…」（collection_tile_layout.dartに書かれた作り。
  ///   全部の名前は詳細表示と読み上げで分かる）。帯がその幅以上で切れたら
  ///   問題。
  bool _designedCut(Element element, RenderParagraph paragraph) {
    var inToolbar = false;
    var inTooltip = false;
    var cardName = false;
    final label = paragraph.text.toPlainText(includeSemanticsLabels: true);
    element.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Tooltip) {
        inTooltip = true;
        if (w.message == label) cardName = true;
      }
      if (w is HomeSelectionToolbar) {
        inToolbar = true;
        return false;
      }
      return !cardName;
    });
    if (inToolbar && inTooltip) return true;
    return cardName &&
        (textScale > 1 ||
            paragraph.size.width < kCollectionTileNameReferenceWidth - 0.5);
  }

  List<String> _wordBreaks(List<_Shown> shown) {
    final out = <String>{};
    for (final s in shown) {
      final p = s.paragraph;
      if (_isGlyph(p)) continue;
      final text = p.text.toPlainText(includeSemanticsLabels: false);
      if (text.length < 2) continue;
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      if (boxes.map((b) => b.top.round()).toSet().length < 2) continue;
      final lines = ParagraphLines(p);
      final v = lines.visible;
      for (var i = 1; i < v.length; i++) {
        final a = lines.lineOf(i - 1);
        final b = lines.lineOf(i);
        if (a == null || b == null || a == b) continue;
        if (!_wordChar(v[i - 1]) || !_wordChar(v[i])) continue;
        // 語が1行に入るときだけ（入らない長い語は折るしかない）。
        var start = i - 1;
        while (start > 0 && _wordChar(v[start - 1])) {
          start--;
        }
        var end = i + 1;
        while (end < v.length && _wordChar(v[end])) {
          end++;
        }
        var width = 0.0;
        for (final box in p.getBoxesForSelection(
          lines.sourceSelection(start, end),
        )) {
          width += box.right - box.left;
        }
        if (width > p.size.width + 0.5) continue;
        out.add(
          'word split: "${v.substring(start, end)}" in '
          '"${lines.lines.join(' / ')}"${_placeOf(s.element)}',
        );
      }
      // ファイル名は、区切りの記号（. _ -）の前で折り返す作り（幅の無い
      // 空白を入れてある）。行の頭の「.」は決まりどおり。
      if (text.contains('\u200B')) continue;
      for (final edge in lines.lineEdgeViolations()) {
        out.add('line edge: $edge${_placeOf(s.element)}');
      }
    }
    return out.toList();
  }

  /// 語の中の字（ラテン文字・数字・語の中の引用符、ハングル）。
  static bool _wordChar(String c) => _wordCharPattern.hasMatch(c);
  static final _wordCharPattern = RegExp(
    "[A-Za-z0-9À-ÖØ-öø-ɏ'’"
    '가-힣ᄀ-ᇿ㄰-㆏]',
  );

  // ─── 言語 ───────────────────────────────────────────────────────────

  List<String> _foreignTexts(List<_Shown> shown) {
    final user = _userStrings();
    final arb = _ArbStrings.instance;
    final out = <String>{};
    for (final s in shown) {
      final p = s.paragraph;
      if (_isGlyph(p)) continue;
      final drawn = _plain(p);
      final label = p.text
          .toPlainText(includeSemanticsLabels: true)
          .replaceAll(RegExp('[⁠​­]'), '');
      // 利用者が付けた名前（上限で切った名前は、読み上げの名前が全部）。
      if (user.contains(label) || user.contains(drawn)) continue;
      if (drawn.endsWith('…')) {
        final prefix = drawn.substring(0, drawn.length - 1).trimRight();
        if (prefix.isNotEmpty && user.any((u) => u.startsWith(prefix))) {
          continue;
        }
      }
      var rest = drawn;
      for (final u in user) {
        if (u.length >= 2) rest = rest.replaceAll(u, ' ');
      }
      final why = arb.foreign(rest, language);
      if (why != null) {
        out.add('not in $language ($why): "$drawn"${_placeOf(s.element)}');
      }
    }
    return out.toList();
  }

  /// 利用者が付けた名前（作品・フォルダ・共有・書き出したファイル）。
  /// 長い順（長い名前の中の短い名前を先に消さない）。
  List<String> _userStrings() {
    final names = <String>{
      for (final project in projects.projects) project.name,
      for (final project in projects.trash) project.name,
      for (final folder in projects.folders) folder.name,
      for (final folder in projects.sharedFolders) folder.name,
      for (final trashed in projects.trashedFolders) ...[
        trashed.folder.name,
        for (final sub in trashed.subfolders) sub.name,
      ],
      for (final share in projects.outgoingShares) share.name,
      for (final folder in workFolders.folders) folder.name,
    };
    try {
      if (_directory.existsSync()) {
        for (final entity in _directory.listSync(recursive: true)) {
          final name = entity.uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
          names.add(name);
          final dot = name.lastIndexOf('.');
          if (dot > 0) names.add(name.substring(0, dot));
        }
      }
    } on FileSystemException {
      // 読めない保存先（失敗のセル）。名前は無い。
    }
    names.removeWhere((n) => n.trim().isEmpty);
    return names.toList()..sort((a, b) => b.length.compareTo(a.length));
  }

  // ─── 読める色 ───────────────────────────────────────────────────────

  List<String> _unreadableTexts(List<_Shown> shown) {
    final out = <String>{};
    for (final s in shown) {
      // 幅の無い字だけの段落は何も描かない。
      if (_plain(s.paragraph).trim().isEmpty) continue;
      final behind = _backgroundBehind(s.element);
      if (behind == null) continue;
      final (:background, :opacity) = behind;
      final colours = <Color>{};
      void visit(InlineSpan span, Color? inherited) {
        final colour = span.style?.color ?? inherited;
        if (span is TextSpan) {
          final text = (span.text ?? '').replaceAll(
            RegExp('[\u2060\u200B\u00AD]'),
            '',
          );
          if (text.trim().isNotEmpty && colour != null) {
            colours.add(colour);
          }
          for (final child in span.children ?? const <InlineSpan>[]) {
            visit(child, colour);
          }
        }
      }

      visit(s.paragraph.text, null);
      for (final colour in colours) {
        final drawn = Color.alphaBlend(
          colour.withValues(alpha: colour.a * opacity),
          background,
        );
        if (isEssentialTextNearlyInvisible(drawn, background)) {
          out.add(
            'unreadable: "${_plain(s.paragraph)}" '
            '${_hex(drawn)} on ${_hex(background)} '
            '(Lc ${apcaContrast(drawn, background).toStringAsFixed(1)})'
            '${_placeOf(s.element)}',
          );
        }
      }
    }
    return out.toList();
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

  /// [element]の下の面の色（不透明にしたもの）と、その間の透明度。用紙の
  /// 見本（[FramePreviewBackground]）の上の印は、絵の代わりの飾りなので
  /// 見ない（null）。
  ({Color background, double opacity})? _backgroundBehind(Element element) {
    final fills = <Color>[];
    var opacity = 1.0;
    var decorative = false;
    element.visitAncestorElements((a) {
      final w = a.widget;
      if (w is FramePreviewBackground) {
        decorative = true;
        return false;
      }
      if (fills.isEmpty) {
        if (w is Opacity) opacity *= w.opacity;
        if (w is FadeTransition) opacity *= w.opacity.value;
      }
      final fill = _fillOf(a);
      if (fill != null && fill.a > 0) {
        fills.add(fill);
        if (fill.a >= 1) return false;
      }
      return true;
    });
    if (decorative || fills.isEmpty) return null;
    var background = fills.last.a >= 1
        ? fills.last
        : Color.alphaBlend(fills.last, const Color(0xFF000000));
    for (final fill in fills.reversed.skip(1)) {
      background = Color.alphaBlend(fill, background);
    }
    return (background: background, opacity: opacity);
  }

  /// 部品が自分の下に塗る色（塗らないならnull）。
  static Color? _fillOf(Element element) {
    final w = element.widget;
    Color? ofDecoration(Decoration? d) => switch (d) {
      BoxDecoration(:final color, gradient: null, image: null) => color,
      ShapeDecoration(:final color, gradient: null, image: null) => color,
      _ => null,
    };
    return switch (w) {
      Material(type: MaterialType.transparency) => null,
      Material(:final color?) => color,
      Material(type: MaterialType.card) => Theme.of(element).cardColor,
      Material(type: MaterialType.canvas) => Theme.of(element).canvasColor,
      ColoredBox(:final color) => color,
      DecoratedBox(
        :final decoration,
        position: DecorationPosition.background,
      ) =>
        ofDecoration(decoration),
      Ink(:final decoration) => ofDecoration(decoration),
      _ => null,
    };
  }

  // ─── 押せる大きさ ───────────────────────────────────────────────────

  List<String> _tapTargetProblems() {
    final result = androidTapTargetGuideline.evaluate(tester);
    if (result is! Evaluation || result.passed) return const [];
    // カードの丸い操作（星・メニュー、[CollectionActionFrame]の中）の名前。
    final cardButtons = <String>{
      for (final e
          in find
              .descendant(
                of: find.byType(CollectionActionFrame),
                matching: find.byWidgetPredicate(
                  (w) => w is IconButton || w is PopupMenuButton,
                ),
              )
              .evaluate())
        ?switch (e.widget) {
          IconButton(:final tooltip) => tooltip,
          PopupMenuButton(:final tooltip) => tooltip,
          _ => null,
        },
    };
    final out = <String>{};
    final found = RegExp(r'but found Size\(([\d.]+), ([\d.]+)\)');
    final label = RegExp(r'(?:label|tooltip): "([^"]*)"');
    for (final reason in result.reason!.split('See also:')) {
      final size = found.firstMatch(reason);
      if (size == null) continue;
      final w = double.parse(size.group(1)!).round();
      final h = double.parse(size.group(2)!).round();
      final names = label
          .allMatches(reason)
          .map((m) => m.group(1)!)
          .where((n) => n.isNotEmpty);
      final card = names.isNotEmpty && names.every(cardButtons.contains)
          ? ' (card)'
          : '';
      out.add('tap target ${w}x$h$card: "${names.join(' / ')}"');
    }
    return out.toList();
  }

  // ─── 浮かぶボタンの下 ───────────────────────────────────────────────

  /// 一番下まで送ったとき、浮かぶボタンの下にカードの星・メニュー・絵・
  /// 名前が無い。
  List<String> _cardPartsUnderFab() {
    final fabs = _fabRects();
    if (fabs.isEmpty) return const [];
    final screen = Offset.zero & size;
    final out = <String>{};
    final pages = find.byType(TabBarView);
    void check(Finder finder, String kind) {
      for (final e in find.descendant(of: pages, matching: finder).evaluate()) {
        final box = e.renderObject;
        if (box is! RenderBox ||
            !box.attached ||
            !box.hasSize ||
            box.size.isEmpty ||
            !_painted(box)) {
          continue;
        }
        final rect = HomeMatrix._globalRect(box);
        if (!HomeMatrix._contains(screen, rect)) continue;
        var visible = true;
        for (final s in HomeMatrix._scrollAncestors(e)) {
          final r = HomeMatrix._globalRect(
            s.context.findRenderObject()! as RenderBox,
          );
          if (!rect.overlaps(r)) visible = false;
        }
        if (!visible) continue;
        if (fabs.any((f) => f.overlaps(rect.deflate(1)))) {
          out.add('$kind under a floating button: $rect${_placeOf(e)}');
        }
      }
    }

    check(find.byType(CollectionFavoriteButton), 'star');
    check(find.byType(CollectionActionFrame), 'card button');
    check(find.byType(FramePreviewBackground), 'thumbnail');
    check(find.byType(FolderThumbnail), 'folder thumbnail');
    check(find.byType(RawImage), 'picture');
    return out.toList();
  }

  // ─── 安全な領域 ─────────────────────────────────────────────────────

  /// 状態バー・ボタンの帯・切り欠きを除いた所。
  Rect get safeArea {
    final p = tester.view.padding;
    final r = tester.view.devicePixelRatio;
    return Rect.fromLTRB(
      p.left / r,
      p.top / r,
      size.width - p.right / r,
      size.height - p.bottom / r,
    );
  }

  List<Rect> get _cutouts {
    final r = tester.view.devicePixelRatio;
    return [
      for (final feature in tester.view.displayFeatures)
        if (feature.type == ui.DisplayFeatureType.cutout)
          Rect.fromLTRB(
            feature.bounds.left / r,
            feature.bounds.top / r,
            feature.bounds.right / r,
            feature.bounds.bottom / r,
          ),
    ];
  }

  List<String> _safeAreaProblems(
    List<_Shown> shown,
    Finder scope, {
    required bool atEnd,
  }) {
    final safe = safeArea;
    final cutouts = _cutouts;
    if (safe == Offset.zero & size && cutouts.isEmpty) return const [];
    final out = <String>{};
    void check(Element e, Rect rect, String what) {
      final scrolled = HomeMatrix._scrollAncestors(
        e,
      ).any((s) => s.position.axis == Axis.vertical);
      final sides =
          rect.left < safe.left - 0.5 || rect.right > safe.right + 0.5;
      final ends =
          (!scrolled || atEnd) &&
          ((!scrolled && rect.top < safe.top - 0.5) ||
              rect.bottom > safe.bottom + 0.5);
      if (sides || ends) {
        out.add('$what outside the safe area $safe: $rect${_placeOf(e)}');
      }
      for (final c in cutouts) {
        if (c.overlaps(rect)) {
          out.add('$what under the display cutout $c: $rect${_placeOf(e)}');
        }
      }
    }

    for (final s in shown) {
      if (!s.whole) continue;
      check(s.element, s.rect, 'text "${_plain(s.paragraph)}"');
    }
    for (final e
        in find
            .descendant(
              of: scope,
              matching: find.byWidgetPredicate(HomeMatrix._isAction),
            )
            .evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty || !_painted(box)) continue;
      final rect = HomeMatrix._globalRect(box);
      var inView = true;
      for (final s in HomeMatrix._scrollAncestors(e)) {
        final r = HomeMatrix._globalRect(
          s.context.findRenderObject()! as RenderBox,
        );
        if (!HomeMatrix._contains(r, rect)) inView = false;
      }
      if (!inView) continue;
      check(e, rect, 'button ${HomeMatrix._describe(e)}');
    }
    return out.toList();
  }

  // ─── フォーカスの順 ─────────────────────────────────────────────────

  static const _maxFocusStops = 220;

  /// Tabでフォーカスを回して確かめる（[drawer]なら開いた引き出しの中）。
  /// 隠れた所・画面の外に止まったら、最初の1回をその場で撮る（[name]＋
  /// `_focusN`）。終わったらフォーカスを外し、一覧を先頭へ戻す。
  Future<List<String>> _focusProblems(
    String name, {
    bool drawer = false,
  }) async {
    final problems = <String>[];
    // ホームは、何にもフォーカスが無いところから（画面の最初の所へ進む）。
    // 開いた引き出しは、開いたときに引き出しのフォーカスの範囲へ移っている
    // （DrawerController）ので、そのまま回す。
    if (!drawer) {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    }
    final screen = Offset.zero & size;
    final stops = <_FocusStop>[];
    var cycled = false;
    for (var i = 1; i <= _maxFocusStops; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Focus may scroll again after layout to clear the floating buttons.
      await tester.pump();
      final node = FocusManager.instance.primaryFocus;
      final context = node?.context;
      if (node == null || context == null || !context.mounted) {
        problems.add('focus: Tab #$i focused nothing');
        cycled = true;
        break;
      }
      if (stops.isNotEmpty && identical(node, stops.first.node)) {
        cycled = true;
        break;
      }
      if (stops.any((s) => identical(s.node, node))) {
        problems.add(
          'focus: Tab #$i came back to ${_focusName(context)} '
          'before reaching the first stop again (stops: '
          '${[for (final s in stops) s.name].join(', ')})',
        );
        cycled = true;
        break;
      }
      final stop = _FocusStop(
        node,
        context,
        _focusRegion(context),
        node.rect,
        _focusName(context),
      );
      stops.add(stop);
      final found = _focusStopProblems(i, stop, screen, drawer: drawer);
      if (found.isNotEmpty && _evidence.isEmpty) {
        await capture('${name}_focus$i');
        _evidence.add('${name}_focus$i.png');
      }
      problems.addAll(found);
    }
    if (!cycled) {
      problems.add('focus: Tab did not cycle within $_maxFocusStops stops');
    }
    if (stops.isEmpty) problems.add('focus: Tab found nothing to focus');
    problems.addAll(_focusOrderProblems(stops, drawer: drawer));
    FocusManager.instance.primaryFocus?.unfocus();
    if (!drawer) _contentScrollable()?.position.jumpTo(0);
    await tester.pump();
    return problems;
  }

  static String _focusName(BuildContext context) {
    final element = context as Element;
    final label = HomeMatrix._firstText(element);
    String? tip;
    element.visitAncestorElements((a) {
      tip = switch (a.widget) {
        IconButton(:final tooltip) => tooltip,
        FloatingActionButton(:final tooltip) => tooltip,
        Tooltip(:final message) => message,
        _ => null,
      };
      return tip == null && a.widget is! ButtonStyleButton;
    });
    return '"${tip ?? label ?? element.widget.toStringShort()}"'
        '${_placeOf(element)}';
  }

  /// 止まった所が上部バー・一覧・浮かぶボタン・引き出しのどこか。
  static String _focusRegion(BuildContext context) {
    var region = 'bar';
    (context as Element).visitAncestorElements((a) {
      final w = a.widget;
      if (w is FloatingActionButton) {
        region = 'fab';
        return false;
      }
      if (w is Drawer) {
        region = 'drawer';
        return false;
      }
      if (w is TabBarView) {
        region = 'list';
        return false;
      }
      return w is! HomeScreen;
    });
    return region;
  }

  List<String> _focusStopProblems(
    int index,
    _FocusStop stop,
    Rect screen, {
    required bool drawer,
  }) {
    final name = stop.name;
    final rect = stop.rect;
    final problems = <String>[];
    if (drawer && stop.region != 'drawer') {
      problems.add('focus: Tab #$index left the open drawer for $name');
    }
    if (rect.isEmpty) {
      return [...problems, 'focus: Tab #$index stopped on nothing ($name)'];
    }
    // 一覧の縦の見える所より高い項目（文字2倍・幅320のゴミ箱のカード）は、
    // 全部を見える所に入れられない。上の端が見える所にあり、下は見える所の
    // 下の端まで続いていれば（見せられるだけ見せている）、見えていると
    // 数える。高いかは、囲む縦のスクロールのうち一番低い見える所と比べる
    // （外側のスクロールを送っても、内側の見える所より高い物は入らない）。
    final verticals = [
      for (final s in HomeMatrix._scrollAncestors(stop.context as Element))
        if (s.position.axis == Axis.vertical) s,
    ];
    var viewport = screen;
    var lowest = screen.height;
    for (final s in verticals) {
      final r = HomeMatrix._globalRect(
        s.context.findRenderObject()! as RenderBox,
      );
      viewport = viewport.intersect(r);
      lowest = math.min(lowest, r.height);
    }
    final tall = verticals.isNotEmpty && rect.height > lowest + 0.5;
    // 全体に近い大きさでも、高い項目そのもの（InkWell）に止まったなら、
    // その項目にフォーカスの色が塗られる。
    if (rect.width * rect.height > 0.6 * screen.width * screen.height &&
        !(tall && _paintsOwnFocusHighlight(stop))) {
      problems.add(
        'focus: Tab #$index stopped on a whole area $rect ($name), '
        'nothing visible lights up',
      );
    }
    if (tall) {
      final startShown =
          rect.top >= viewport.top - 0.5 && rect.top < viewport.bottom - 0.5;
      final filled = rect.bottom >= viewport.bottom - 0.5;
      if (!startShown ||
          !filled ||
          rect.left < screen.left - 0.5 ||
          rect.right > screen.right + 0.5) {
        problems.add(
          'focus: Tab #$index taller than the list $viewport but not '
          'shown from its start $rect ($name)',
        );
        return problems;
      }
    } else if (!HomeMatrix._contains(screen, rect)) {
      problems.add('focus: Tab #$index off screen $rect ($name)');
      return problems;
    }
    for (final s in HomeMatrix._scrollAncestors(stop.context as Element)) {
      if (tall && s.position.axis == Axis.vertical) continue;
      final r = HomeMatrix._globalRect(
        s.context.findRenderObject()! as RenderBox,
      );
      // 高い項目は、横に送る物（タブの本文のページ）の中では横だけを見る
      // （縦は上で見た）。
      final inside = tall
          ? rect.left >= r.left - 0.5 && rect.right <= r.right + 0.5
          : HomeMatrix._contains(r, rect);
      if (!inside) {
        problems.add(
          'focus: Tab #$index not scrolled into view $rect in $r ($name)',
        );
        return problems;
      }
    }
    final target = stop.context.findRenderObject();
    // 高い項目は、見えている所の真ん中を押す。
    final point = tall ? rect.intersect(viewport).center : rect.center;
    final path = tester.hitTestOnBinding(point).path;
    if (target != null && !path.any((entry) => _within(entry.target, target))) {
      // 何の下に隠れたか：浮かぶボタン・上部バー・それ以外。
      final fabs = [
        for (final e in find.byType(FloatingActionButton).evaluate())
          ?e.renderObject,
      ];
      final bars = [
        for (final e in find.byType(AppBar).evaluate()) ?e.renderObject,
      ];
      bool under(List<RenderObject> boxes) =>
          path.any((entry) => boxes.any((box) => _within(entry.target, box)));
      final by = under(fabs)
          ? 'a floating button'
          : under(bars)
          ? 'the app bar'
          : 'something else';
      problems.add('focus: Tab #$index is covered by $by at $rect ($name)');
    }
    return problems;
  }

  /// [stop]のフォーカスが、止まった所と同じ大きさのInkWell（InkResponse）の
  /// もので、そのInkWellが止まった所全体にフォーカスの色を塗るか。
  static bool _paintsOwnFocusHighlight(_FocusStop stop) {
    var found = false;
    var depth = 0;
    (stop.context as Element).visitAncestorElements((a) {
      if (++depth > 8) return false;
      if (a.widget is InkResponse) {
        final box = a.renderObject;
        final size = box is RenderBox && box.hasSize
            ? HomeMatrix._globalRect(box).size
            : null;
        found =
            size != null &&
            (size.width - stop.rect.width).abs() < 1 &&
            (size.height - stop.rect.height).abs() < 1;
        return false;
      }
      return true;
    });
    return found;
  }

  /// [candidate]が[target]か、その子孫の描画か。
  static bool _within(HitTestTarget candidate, RenderObject target) {
    if (candidate is! RenderObject) return false;
    RenderObject? node = candidate;
    while (node != null) {
      if (identical(node, target)) return true;
      node = node.parent;
    }
    return false;
  }

  /// 上部バー→一覧→浮かぶボタンの順で、一覧の中は読む順（上から下、
  /// 同じ行は左から右）。
  List<String> _focusOrderProblems(
    List<_FocusStop> stops, {
    required bool drawer,
  }) {
    const rank = {'bar': 0, 'list': 1, 'fab': 2, 'drawer': 0};
    final problems = <String>[];
    for (var i = 1; i < stops.length; i++) {
      final a = stops[i - 1];
      final b = stops[i];
      if (rank[b.region]! < rank[a.region]!) {
        problems.add(
          'focus order: ${b.region} ${b.name} after '
          '${a.region} ${a.name} (Tab #${i + 1})',
        );
        continue;
      }
      final sameScroll =
          b.contentTop != null &&
          a.contentTop != null &&
          identical(a.scrollable, b.scrollable);
      if (!sameScroll && (drawer || b.region != 'list')) {
        if (b.region == a.region && b.rect.top < a.rect.top - 1) {
          // 上部バー・引き出しの中は上から下（同じ行は左から右）。
          final sameRow =
              (b.rect.center.dy - a.rect.center.dy).abs() <
              math.min(a.rect.height, b.rect.height) / 2;
          if (!sameRow) {
            problems.add(
              'focus order: ${b.name} above ${a.name} (Tab #${i + 1})',
            );
          }
        }
        continue;
      }
      if (!sameScroll) continue;
      // 同じカード・行の中の操作（星とメニュー等）は、どの順でもよい。
      if (a.item != null && identical(a.item, b.item)) continue;
      final tolerance = math.min(a.orderRect.height, b.orderRect.height) / 2;
      final dy = b.contentTop! - a.contentTop!;
      if (dy < -tolerance) {
        problems.add(
          'focus order: back up the list to ${b.name} after ${a.name} '
          '(Tab #${i + 1})',
        );
      } else if (dy.abs() <= tolerance &&
          b.orderRect.left < a.orderRect.left - 1) {
        problems.add(
          'focus order: leftwards in a row to ${b.name} after ${a.name} '
          '(Tab #${i + 1})',
        );
      }
    }
    return problems;
  }

  /// 自作のテーマ[preset]を当てる（セルの名前には[name]を付ける）。
  Future<void> applyCustomTheme(String name, AppThemePreset preset) async {
    theme = name;
    themes.previewCurrent(preset);
    await frames(4);
  }

  /// 今の画面の画素（0.5倍、RGBA）。
  Future<Uint8List> pixels() async {
    final bytes = await tester.runAsync(() async {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 0.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  /// いま見えているタブの本文の縦スクロール（いちばん大きいもの）。
  ScrollableState? get contentScrollable => _contentScrollable();

  // ─── 起動し直す・読み込み中 ─────────────────────────────────────────

  /// アプリを閉じ、同じ保存先・同じ設定のまま起動し直してホームを開く
  /// （端末でアプリを開き直したとき）。[holdAfterStart]なら、起動し終えた
  /// 後の書類フォルダの問い合わせを止め、タブを開いてからの一覧の読み込みを
  /// 終わらせない。
  Future<void> restartApp({bool holdAfterStart = false}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await frames(2);
    ExportStorage.invalidate();
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: RepaintBoundary(key: _boundary, child: const NiarimApp()),
      ),
    );
    await frames(6);
    await settleIo();
    if (holdAfterStart) {
      holdDocuments = Completer<void>();
      ExportStorage.invalidate();
    }
    final home = tester.element(find.byType(HomeScreen));
    projects = home.read<ProjectService>();
    settings = home.read<SettingsService>();
    themes = home.read<ThemeService>();
    workFolders = home.read<WorkFolderService>();
    pc = settings.forcePcMode ?? false;
  }

  /// 起動し直した直後、ファイルの一覧（書き出した作品・作成した共有
  /// ファイル・ゴミ箱のファイル）をまだ読んでいる間の[view]を確かめて撮る。
  /// 端末の中に作品があるのに「ありません」と言わない。読み終わる前に
  /// 一部だけを出すなら、まだ読んでいることが分かる。
  Future<void> loadingCell(String group, HomeView view) async {
    final saved = contents;
    // 読み込みが終わるのを待たずに撮る。
    contents = HomeContents.loading;
    await show(view);
    contents = saved;
    bool any(Finder f) => f.evaluate().isNotEmpty;
    bool hasKey(String prefix) => any(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(prefix),
      ),
    );
    final spinner = any(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    final empty = any(find.byType(EmptyStatePlaceholder));
    // ゴミ箱の一覧の先頭の、控え（書き出した作品・作成した共有ファイル）を
    // 読み込み中の行（回らない砂時計の印と文）。
    final trashFilesLoading = any(find.byKey(const Key('trashFilesLoading')));
    final problems = <String>{
      ...switch (view) {
        HomeView.projects || HomeView.sharedReceived => _expectedContent(view),
        HomeView.works => [
          if (!spinner) 'works list has no loading sign while loading',
          if (empty) 'works list says there are none while loading',
        ],
        HomeView.sharedOutgoing => [
          if (empty)
            'created shares say there are none while they are still loading',
          if (!empty && !spinner && !hasKey('outgoingShareMenu_'))
            'created shares show neither the list nor a loading sign',
        ],
        HomeView.trash => [
          if (!hasKey('trash-restore-')) 'trashed projects not listed',
          if (!hasKey('trash-restore-local-') && !spinner && !trashFilesLoading)
            'trash lists only the trashed projects while the trashed files '
                'are still loading, with no loading sign',
          if (empty) 'trash says it is empty while loading',
        ],
      },
    };
    final observations = [..._observations(view), ..._titleCut()];
    final defects = _matchKnownDefects(view, observations);
    await _shoot(
      group,
      view.name,
      problems: {...problems, ...defects.problems},
      observations: observations,
      knownDefects: defects.ids,
    );
  }

  // ─── 撮る ───────────────────────────────────────────────────────────

  /// 今の画面をそのまま確かめて撮り、記録する（ダイアログ・知らせを開いた
  /// 画面など、[HomeMatrix.cell]のようにタブを開き直さないもの）。[scope]を
  /// 渡すと、その中（ダイアログ等）だけを続きの確かめにかける。
  Future<void> checkScreen(
    String group,
    String what, {
    List<String> problems = const [],
    Finder? scope,
    bool walk = false,
  }) async {
    final name = cellName(group, what);
    final found = <String>{...problems};
    final error = tester.takeException();
    if (error != null) found.add('exception: ${'$error'.split('\n').first}');
    found.addAll(_flexOverflows());
    final within = scope ?? find.byType(HomeScreen);
    if (within.evaluate().isNotEmpty) {
      final shown = _shownTexts(within);
      found
        ..addAll(_cutTexts(shown))
        ..addAll(_wordBreaks(shown))
        ..addAll(_foreignTexts(shown))
        ..addAll(_unreadableTexts(shown))
        ..addAll(_safeAreaProblems(shown, within, atEnd: false));
      if (checkTapTargets) found.addAll(_tapTargetProblems());
      found.addAll(
        _actionProblems(within, Offset.zero & size, fabRule: scope == null),
      );
    }
    await capture(name);
    if (walk) found.addAll(await _focusProblems(name));
    record(
      name,
      group,
      what,
      ['$name.png', ..._evidence],
      found.toList(),
      const [],
    );
    _evidence.clear();
  }

  /// [problems]のうち、[knownProblems]が見込んだもの（問題→不具合の番号）。
  Map<String, String> _knownIn(String what, List<String> problems) {
    final known = <String, String>{};
    for (final problem in problems) {
      for (final k in knownProblems) {
        if (!k.pattern.hasMatch(problem)) continue;
        if (k.where != null && !k.where!(this, what)) continue;
        known[problem] = k.id;
        break;
      }
    }
    // セルの数を数える（1つのセルに同じ不具合が何か所あっても1）。
    for (final id in known.values.toSet()) {
      run.knownProblemHits.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
    return known;
  }
}

/// 見えている段落。[whole]なら、枠に切られず全部見えている。
class _Shown {
  _Shown(this.element, this.paragraph, this.rect, {required this.whole});

  final Element element;
  final RenderParagraph paragraph;
  final Rect rect;
  final bool whole;
}

/// Tabで止まった所。
class _FocusStop {
  _FocusStop(this.node, this.context, this.region, this.rect, this.name) {
    final element = context as Element;
    final vertical = HomeMatrix._scrollAncestors(
      element,
    ).where((s) => s.position.axis == Axis.vertical).firstOrNull;
    scrollable = vertical;
    Element last = element;
    element.visitAncestorElements((a) {
      if (a is SliverMultiBoxAdaptorElement) {
        item = last;
        return false;
      }
      last = a;
      return true;
    });
    final itemBox = item?.renderObject;
    orderRect = itemBox is RenderBox && itemBox.attached && itemBox.hasSize
        ? HomeMatrix._globalRect(itemBox)
        : rect;
    if (vertical != null) {
      final top = HomeMatrix._globalRect(
        vertical.context.findRenderObject()! as RenderBox,
      ).top;
      contentTop = orderRect.top - top + vertical.position.pixels;
    }
  }

  final FocusNode node;
  final BuildContext context;
  final String region;
  final Rect rect;
  late final Rect orderRect;

  /// 止まった所の名前（止まったときの。後で一覧から外れても使える）。
  final String name;
  ScrollableState? scrollable;

  /// 一覧の中の、その止まり先を含む項目（カード・行）。
  Element? item;

  /// 一覧の中の縦の位置（スクロールしても変わらない）。
  double? contentTop;
}

/// 直していない既知の不具合を、問題の文で見込む（続きのマトリクス）。
/// 見込んだ問題は失敗にせず、記録の`knownProblems`に不具合の番号と
/// 一緒に残す。テストファイルの最後に、一度も出なかった見込みは
/// [HomeMatrixRun.expectKnownProblemsSeen]が失敗にする（直った・作りが
/// 変わったら表を直す）。
class HomeMatrixKnownProblem {
  const HomeMatrixKnownProblem(
    this.id,
    this.reason,
    this.pattern, {
    this.where,
  });

  /// 不具合の番号（台帳のDISC番号）。
  final String id;

  /// 何が・なぜ不具合か（記録に残す）。
  final String reason;

  /// 問題の文に当てる式。
  final RegExp pattern;

  /// 見込むセル（無ければどのセルでも）。
  final bool Function(HomeMatrix m, String what)? where;
}

/// 7言語のARBの文（言語の確かめに使う）。
class _ArbStrings {
  _ArbStrings._() {
    for (final language in kHomeMatrixLanguages) {
      final file = File('lib/l10n/app_$language.arb');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final values = <String>{};
      final chars = <int>{};
      for (final MapEntry(:key, :value) in json.entries) {
        if (key.startsWith('@') || value is! String) continue;
        chars.addAll(value.runes);
        if (!value.contains('{')) values.add(value.trim());
      }
      _values[language] = values;
      _chars[language] = chars;
    }
  }

  static final instance = _ArbStrings._();

  final _values = <String, Set<String>>{};
  final _chars = <String, Set<int>>{};

  static bool _kana(int r) =>
      (r >= 0x3041 && r <= 0x30FF && r != 0x30FB && r != 0x30FC) ||
      (r >= 0x31F0 && r <= 0x31FF) ||
      (r >= 0xFF66 && r <= 0xFF9F);
  static bool _hangul(int r) =>
      (r >= 0xAC00 && r <= 0xD7A3) ||
      (r >= 0x1100 && r <= 0x11FF) ||
      (r >= 0x3130 && r <= 0x318F);
  static bool _han(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0xF900 && r <= 0xFAFF);

  /// [text]がその言語の文でない理由（その言語の文ならnull）。
  String? foreign(String text, String language) {
    final own = _chars[language]!;
    final strange = <String>{};
    for (final r in text.runes) {
      final c = String.fromCharCode(r);
      if (_kana(r) && language != 'ja') {
        strange.add(c);
      } else if (_hangul(r) && language != 'ko') {
        strange.add(c);
      } else if (_han(r) && !own.contains(r)) {
        strange.add(c);
      }
    }
    if (strange.isNotEmpty) return 'letters ${strange.join()}';
    final trimmed = text.trim();
    if (trimmed.runes.where(_isLetter).length < 3) return null;
    if (_values[language]!.contains(trimmed)) return null;
    for (final other in kHomeMatrixLanguages) {
      if (other != language && _values[other]!.contains(trimmed)) {
        return 'the $other text';
      }
    }
    return null;
  }

  static bool _isLetter(int r) =>
      String.fromCharCode(r).toLowerCase() !=
          String.fromCharCode(r).toUpperCase() ||
      _kana(r) ||
      _hangul(r) ||
      _han(r);
}
