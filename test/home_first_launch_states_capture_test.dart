import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// ホームの初回の案内（「手描きアニメーションを制作できます」）を、
/// 7言語 × 8画面 × 文字の大きさ1倍・2倍で開き、見たことの保存が通常に
/// 済む・断られる・例外になる・待たされる、の各状態を撮って確かめる。
/// 画面は320x568・360x800・横640x360・PCの1280x800と、実機のスマホの
/// 状態バー（上24）とジェスチャーの帯（下24）を持つ横640x360・横568x320、
/// 状態バーと3つのボタンの帯（下48）を持つ320x568、小さい浮かぶ窓の360x260。
///
/// 画像と一覧（manifest-<言語>.json）は build/home-first-launch へ出す。
/// 各状態で確かめること：
/// - 案内が画面の帯の内側に収まり、例外（はみ出し等）が出ない。「はじめる」は
///   画面と案内の中にあり、押せる（押せる大きさ48px以上）。文が案内の外へ
///   出ない。中身がスクロールするときは、上の端・下の端のどちらからでも、
///   文がスクロールで見える所まで来る。どの言語でも、スクロールする画面が
///   少なくとも1つあり、隠れた文をスクロールで見せる確かめが実際に走ること
///   （小さい横画面・浮かぶ窓で文字2倍）。
/// - 失敗の文はその言語の文で、日本語以外の言語の案内に仮名が混ざらない
///   （英・西・仏は漢字・ハングルも混ざらない）。
/// - 外側のタップ・Esc・戻る操作では閉じず（`barrierDismissible: false`・
///   `PopScope(canPop: false)`）、戻る操作はアプリを閉じずに受け止める。
///   保存も行わない。Escは、案内の中にフォーカスがあるとき（スマホでも
///   キーボードのTabで入れて）にも確かめる。
/// - 「はじめる」は保存に成功したときだけ閉じる。断られた・例外になった・
///   待っている間は開いたまま、待っている間は押せず進捗を出す。失敗は
///   エラーの記録に残る。間に画面を描かない二度押し（同じフレームの2回の
///   タップ・2回のEnter）でも保存は1回だけ。
/// - 断られた状態のまま画面を回す・大きさを変えても（360x800⇔800x360、
///   帯のある640x360⇔360x640、PCの1280x800⇔640x360）、案内は1つのままで、
///   失敗の文と「はじめる」が画面の中に残る。
/// PCの画面では「はじめる」をキーボードで押す：まずEnterだけを押し、
/// 押せなければ「はじめる」にフォーカスが来るまでTabを押してからEnter。
///
/// 不具合（Enterだけでは押せない・韓国語の語の途中の折り返し・失敗の文の
/// 中のボタンの名前が2行に割れる。種類は[_knownDefects]）は、既知の一覧
/// （[_expectedDefects]）とちょうど同じであることを確かめる。3つとも直して
/// あり一覧は空なので、1つでも見つかれば悪化としてテストが落ちる。英・西・
/// 仏でボタンの名前の語と語の間（空白）で折り返すのは普通の折り返しとして
/// 数えない。
///
/// 判定はしないが一覧に残すもの：角の丸みにかかる字
/// （`glyphsOutsideRoundedCorner`）、案内を閉じた後のホームの仮名（`homeKana`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in _languages) {
    testWidgets('first-launch notice: normal, rejected, failed, waiting and '
        'saved states at 8 sizes x text 1/2 ($language)', (tester) async {
      await loadAppFonts(tester);
      // テストの既定では影が黒い縁取りで描かれ、実機と違う画面になる。
      debugDisableShadows = false;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final report = <Map<String, Object?>>[];
      final problems = <String>[];
      final defects = <String>{};
      try {
        for (final screen in _screens) {
          for (final scale in const [1.0, 2.0]) {
            await _Cell(
              tester: tester,
              language: language,
              screen: screen,
              scale: scale,
              problems: problems,
              defects: defects,
            ).run(report);
          }
        }
        _out.createSync(recursive: true);
        File(
          '${_out.path}/manifest-$language.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      } finally {
        debugDisableShadows = true;
      }

      // スクロールの確かめが実際に走ったこと。
      final steps = [
        for (final cell in report)
          ...(cell['steps']! as List<Map<String, Object?>>),
      ];
      if (!steps.any((s) => ((s['scrollExtent'] as double?) ?? 0) > 0.5)) {
        problems.add('$language: the notice did not scroll in any cell');
      }
      if (!steps.any(
        (s) => (s['scrolledIntoView'] as List<String>?)?.isNotEmpty ?? false,
      )) {
        problems.add(
          '$language: no text had to be scrolled into view in any cell',
        );
      }

      // 不具合は既知の一覧とちょうど同じであること。
      final known = _expectedDefects(language);
      String about(String line) {
        final kind = line.split(' ')[1];
        return _knownDefects[kind] ?? '';
      }

      for (final line in defects.difference(known).toList()..sort()) {
        problems.add('new or changed defect: $line\n  (${about(line)})');
      }
      for (final line in known.difference(defects).toList()..sort()) {
        problems.add(
          'known defect no longer seen (fixed? remove it from '
          '_expectedDefects): $line\n  (${about(line)})',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

/// [turnTo]：断られた状態のまま回す・変える大きさ（回した後は元へ戻す）。
typedef _Screen = ({
  String name,
  Size size,
  bool pc,
  double top,
  double bottom,
  Size? turnTo,
});

const List<_Screen> _screens = [
  (
    name: '320x568',
    size: Size(320, 568),
    pc: false,
    top: 0,
    bottom: 0,
    turnTo: null,
  ),
  (
    name: '360x800',
    size: Size(360, 800),
    pc: false,
    top: 0,
    bottom: 0,
    turnTo: Size(800, 360),
  ),
  (
    name: '640x360',
    size: Size(640, 360),
    pc: false,
    top: 0,
    bottom: 0,
    turnTo: null,
  ),
  (
    name: '1280x800',
    size: Size(1280, 800),
    pc: true,
    top: 0,
    bottom: 0,
    turnTo: Size(640, 360),
  ),
  // 実機のスマホ：状態バー（上24）とジェスチャーの帯（下24）。
  (
    name: '640x360-bars',
    size: Size(640, 360),
    pc: false,
    top: 24,
    bottom: 24,
    turnTo: Size(360, 640),
  ),
  // 状態バーと3つのボタンの帯（下48）。
  (
    name: '320x568-bars',
    size: Size(320, 568),
    pc: false,
    top: 24,
    bottom: 48,
    turnTo: null,
  ),
  // 小さいスマホの横向き（状態バーとジェスチャーの帯）。
  (
    name: '568x320-bars',
    size: Size(568, 320),
    pc: false,
    top: 24,
    bottom: 24,
    turnTo: null,
  ),
  // 小さい浮かぶ窓（ポップアップ表示・フリーフォームの窓）。文の短い中国語・
  // 日本語でも、文字2倍で失敗を知らせると中身がスクロールする。
  (
    name: '360x260-popup',
    size: Size(360, 260),
    pc: false,
    top: 0,
    bottom: 0,
    turnTo: null,
  ),
];

/// 見張る不具合の種類。3つとも直してある（A003-2a・2b・2c、b9dc2697：
/// 「はじめる」へのフォーカス・歓迎の文の語結合子・失敗の文の中の名前を
/// 1行に保つkeepPhraseTogether）ので、見つかったら悪化。
const _knownDefects = <String, String>{
  'PC-ENTER-NEEDS-TAB':
      'PCで、案内が開いた直後か、待った末に断られた後に、Enterだけでは'
      '「はじめる」を押せない（「はじめる」にフォーカスが無く、Tabが要る）。'
      'home_screen.dartの_FirstLaunchDialogStateは開いたときに「はじめる」へ'
      'フォーカスを置き（autofocus）、保存に失敗したら次のフレームで'
      'フォーカスを戻すはず。',
  'KO-WORD-SPLIT':
      '韓国語の文が語の途中で折り返す。home_screen.dartの'
      '_FirstLaunchDialogState.buildは歓迎の文も失敗の文も'
      'keepKoreanWordsTogetherで包むはず。',
  'START-NAME-SPLIT':
      '失敗の文が押すボタンの名前（「はじめる」“开始使用”「開始使用」）を'
      '2行に割る。失敗の文はkeepPhraseTogetherで名前を引用符ごと1行に'
      '保つはず。',
};

/// [language]で見つかるはずの不具合の行（`<セル>: <種類> <中身>`）。
/// どれも直したので無い。
Set<String> _expectedDefects(String language) => const {};

final _out = Directory('build/home-first-launch');

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

// 仮名（日本語だけが使う字）。中国語・韓国語の案内にも出てはいけない。
final _kana = RegExp(r'[぀-ヿㇰ-ㇿｦ-ﾟ]');
// 英・西・仏の案内には漢字・仮名・ハングルのどれも出ない。
final _cjk = RegExp(r'[぀-ヿ㐀-䶿一-鿿豈-﫿가-힣]');
final _hangul = RegExp(r'[가-힣]');
final _letter = RegExp(r'\p{L}', unicode: true);
const _openQuotes = '「“«';
const _closeQuotes = '」”»';

enum _Save { succeed, reject, fail, wait }

/// `first_launch`をfalseにする書き込みだけを、成功・拒否（false）・例外・
/// 保留に切り替える保存先。ほかのキーはそのまま元の保存先へ渡す。
class _AcknowledgementStore extends SharedPreferencesStorePlatform {
  _AcknowledgementStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;
  _Save mode = _Save.succeed;
  int attempts = 0;
  final _waiting = <(Completer<bool>, String, String, Object)>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key != 'flutter.first_launch' || value != false) {
      return delegate.setValue(valueType, key, value);
    }
    attempts++;
    switch (mode) {
      case _Save.succeed:
        return delegate.setValue(valueType, key, value);
      case _Save.reject:
        return Future.value(false);
      case _Save.fail:
        return Future.error(
          PlatformException(code: 'audit-first-launch-write'),
        );
      case _Save.wait:
        final waiting = Completer<bool>();
        _waiting.add((waiting, valueType, key, value));
        return waiting.future;
    }
  }

  /// 保留していた書き込みをすべて終える。[saved]なら元の保存先へ書いて
  /// 成功を返す。
  Future<void> finishWaiting({required bool saved}) async {
    final all = [..._waiting];
    _waiting.clear();
    for (final (waiting, type, key, value) in all) {
      waiting.complete(
        saved ? await delegate.setValue(type, key, value) : false,
      );
    }
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
}

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// [b]が[a]と別の行にあるか。
bool _otherLine(TextBox a, TextBox b) =>
    b.top >= a.bottom - 1 || b.bottom <= a.top + 1;

/// 韓国語の語（空白で区切った単位）の途中で行が替わっている所。
List<String> _koreanMidWordBreaks(RenderParagraph paragraph) {
  // 字の位置は描く文（語結合子入り）で数える。読み上げの文（TextSpanの
  // semanticsLabel）は語結合子が無く、位置が描く文とずれる。
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final breaks = <String>[];
  TextBox? last;
  var previous = '';
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char.trim().isEmpty) {
      last = null;
      continue;
    }
    if (char == '⁠') continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final box = boxes.first;
    if (last != null &&
        _hangul.hasMatch(previous + char) &&
        _otherLine(last, box)) {
      breaks.add('$previous|$char');
    }
    last = box;
    previous = char;
  }
  return breaks;
}

/// [paragraph]の中で、かぎかっこ・引用符で囲んだ[name]（押すボタンの名前）が
/// 2行に割れていれば、割れ目に「|」を入れた囲みを返す。割れていなければ
/// null、名前が文に無ければ空の文字列。名前の中の語と語の間（空白）で
/// 行が替わるのは割れとしない（英語等の普通の折り返し）。かっこと名前の間・
/// 名前の字と字の間で替わるのは割れとする。
String? _splitQuotedName(RenderParagraph paragraph, String name) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  // 単語結合子を除いた文の位置 → 元の文の位置。
  final at = <int>[];
  final plain = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] == '⁠') continue;
    at.add(i);
    plain.write(raw[i]);
  }
  final text = plain.toString();
  var start = text.indexOf(name);
  if (start < 0) return '';
  var end = start + name.length;
  // 前後のかっこまで（間の空白も含めて）広げる。
  var s = start;
  while (s > 0 && text[s - 1].trim().isEmpty) {
    s--;
  }
  if (s > 0 && _openQuotes.contains(text[s - 1])) start = s - 1;
  var e = end;
  while (e < text.length && text[e].trim().isEmpty) {
    e++;
  }
  if (e < text.length && _closeQuotes.contains(text[e])) end = e + 1;

  final out = StringBuffer();
  TextBox? line;
  String? previous;
  var spaced = false;
  var split = false;
  for (var k = start; k < end; k++) {
    final char = text[k];
    if (char.trim().isEmpty) {
      spaced = true;
      out.write(char);
      continue;
    }
    final i = at[k];
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isNotEmpty) {
      final box = boxes.first;
      if (line != null && _otherLine(line, box)) {
        final betweenWords =
            spaced &&
            _letter.hasMatch(previous ?? '') &&
            _letter.hasMatch(char);
        if (!betweenWords) {
          out.write('|');
          split = true;
        }
      }
      line = box;
    }
    out.write(char);
    previous = char;
    spaced = false;
  }
  return split ? out.toString() : null;
}

/// 字の箱（上下15%・左右5%内側。行の高さの余白を除いたおよその字の形）の
/// 角が[outline]（案内の面の角丸の形）の外へ出ている字と、その位置。
List<String> _glyphsOutside(RenderParagraph paragraph, Path outline) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final transform = paragraph.getTransformTo(null);
  final outside = <String>[];
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char.trim().isEmpty || char == '⁠') continue;
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    )) {
      final r = MatrixUtils.transformRect(transform, box.toRect());
      final ink = Rect.fromLTRB(
        r.left + r.width * 0.05,
        r.top + r.height * 0.15,
        r.right - r.width * 0.05,
        r.bottom - r.height * 0.15,
      );
      final corners = [
        ink.topLeft,
        ink.topRight,
        ink.bottomLeft,
        ink.bottomRight,
      ];
      if (!corners.every(outline.contains)) {
        outside.add('$char@${r.left.round()},${r.top.round()}');
      }
    }
  }
  return outside;
}

/// 文が何行に折り返されているか（字の箱が上下に重ならない所で数える）。
int _lineCount(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  )..sort((a, b) => a.top.compareTo(b.top));
  var lines = 0;
  double? bottom;
  for (final box in boxes) {
    if (bottom == null || box.top >= bottom - 1) {
      lines++;
      bottom = box.bottom;
    } else if (box.bottom > bottom) {
      bottom = box.bottom;
    }
  }
  return lines;
}

class _Cell {
  _Cell({
    required this.tester,
    required this.language,
    required this.screen,
    required this.scale,
    required this.problems,
    required this.defects,
  }) : expected = lookupAppLocalizations(localeFromLanguageCode(language)),
       _size = screen.size;

  final WidgetTester tester;
  final String language;
  final _Screen screen;
  final double scale;
  final List<String> problems;
  final Set<String> defects;
  final AppLocalizations expected;
  final _boundary = GlobalKey();
  final _steps = <Map<String, Object?>>[];
  final _cellDefects = <String>[];
  late final _AcknowledgementStore _store;
  late final SettingsService _settings;
  Size _size;

  String get name => '${language}_${screen.name}_x${scale.round()}';

  /// 不具合の行で使うセルの名前（回した・変えた大きさなら`@幅x高さ`を付ける）。
  String get _where => _size == screen.size
      ? name
      : '$name@${_size.width.round()}x${_size.height.round()}';
  bool get _latin => const {'en', 'es', 'fr'}.contains(language);

  /// 画面のうち、状態バー・ナビゲーションの帯を除いた所。
  Rect get _safeRect =>
      Rect.fromLTRB(0, screen.top, _size.width, _size.height - screen.bottom);

  final Finder _dialog = find.byType(AlertDialog);
  Finder _inDialog(Finder finder) =>
      find.descendant(of: _dialog, matching: finder);
  // 案内の面（AlertDialogの中で最初のMaterial）。
  Finder get _surface => _inDialog(find.byType(Material)).first;
  // 文は単語結合子（韓国語の語を折り返さない印）を除いて比べる。歓迎の文は
  // 描く文にだけ語結合子を入れたText.richなので、描く文（読み上げの文では
  // なく）を見る。
  Finder _text(String text) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data ??
                    widget.textSpan?.toPlainText(includeSemanticsLabels: false))
                ?.replaceAll('\u2060', '') ==
            text,
  );
  Finder get _start => _inDialog(
    find.ancestor(
      of: _text(expected.homeFirstLaunchStart),
      matching: find.byType(FilledButton),
    ),
  );
  Finder get _message => _inDialog(_text(expected.homeFirstLaunchMessage));
  // 保存に失敗したときの知らせ（読み上げにも伝わる1行）の文。
  Finder get _notice => _inDialog(
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      matching: find.byType(Text),
    ),
  );
  Finder get _progress => _inDialog(find.byType(LinearProgressIndicator));
  Finder get _scroll => _inDialog(find.byType(Scrollable));

  void _problem(String step, String what) => problems.add('$name $step: $what');

  void _defect(String what) {
    final line = '$_where: $what';
    defects.add(line);
    if (!_cellDefects.contains(line)) _cellDefects.add(line);
  }

  /// キーボードのフォーカスが案内の中の部品にあるか。
  bool _focusInDialog() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        context.findAncestorWidgetOfExactType<AlertDialog>() != null;
  }

  bool _startFocused() {
    final label = find.descendant(of: _start, matching: find.byType(Text));
    if (label.evaluate().isEmpty) return false;
    return Focus.maybeOf(tester.element(label.first))?.hasPrimaryFocus ?? false;
  }

  void _resize(Size size) {
    _size = size;
    tester.view.physicalSize = size;
  }

  Future<void> run(List<Map<String, Object?>> report) async {
    report.add({
      'cell': name,
      'screen': screen.name,
      'language': language,
      'width': screen.size.width,
      'height': screen.size.height,
      'insetTop': screen.top,
      'insetBottom': screen.bottom,
      'textScale': scale,
      'pc': screen.pc,
      'steps': _steps,
      'defects': _cellDefects,
    });
    SharedPreferences.setMockInitialValues({
      'first_launch': true,
      'language': language,
      'force_pc_mode': screen.pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    _store = _AcknowledgementStore(SharedPreferencesStorePlatform.instance);
    SharedPreferencesStorePlatform.instance = _store;
    final dir = Directory.systemTemp.createTempSync('home-first-launch-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathChannel, (_) async => dir.path);
    addTearDown(() {
      // 外したアプリのサービスがまだ書いている途中だと「空でない」で消せない
      // ことがあるので、3回まで試し、それでも消せなければ残す
      // （OSの一時フォルダの中）。
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screen.size;
    final insets = FakeViewPadding(top: screen.top, bottom: screen.bottom);
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    try {
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers!,
          child: RepaintBoundary(key: _boundary, child: const NiarimApp()),
        ),
      );
      await tester.pumpAndSettle();
      _settings = tester
          .element(find.byType(HomeScreen))
          .read<SettingsService>();
      await _flow();
    } catch (error, stack) {
      _problem(
        'flow',
        'stopped: $error\n${stack.toString().split('\n').take(6).join('\n')}',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.takeException();
      // 二度押しを止めない作りだと保留の書き込みが残るので、終えておく。
      await _store.finishWaiting(saved: false);
      SharedPreferencesStorePlatform.instance = _store.delegate;
      messenger.setMockMethodCallHandler(_pathChannel, null);
      _resize(screen.size);
    }
  }

  Future<void> _flow() async {
    // 1. 開いたところ。外側のタップ・Esc・戻る操作では閉じない。
    if (!await _look('1-normal', failed: false, waiting: false)) return;
    if (!await _tryToDismiss('1-normal', waiting: false)) return;
    if (_store.attempts != 0) {
      _problem('1-normal', 'saved ${_store.attempts}x before Start');
    }

    // 2. 保存を断られた（setBoolがfalse）。開いたまま、その言語の文で知らせる。
    // PCでは、案内を見てすぐEnterを押す人の操作から始める。
    await _pressAndFail('2-rejected', _Save.reject, 1, 'was not saved');
    if (!await _look('2-rejected', failed: true, waiting: false)) return;
    // キーボードのTabで案内の中へフォーカスを入れてからEscも押す。
    if (!await _tryToDismiss('2-rejected', waiting: false, focusInside: true)) {
      return;
    }

    // 2t. 開いたまま画面を回す・大きさを変える。案内は1つのままで、
    // 失敗の文と「はじめる」が画面の中に残り、保存もしない。
    final turnTo = screen.turnTo;
    if (turnTo != null) {
      for (final size in [turnTo, screen.size]) {
        _resize(size);
        await tester.pumpAndSettle();
        final step = size == screen.size
            ? '2-turned-back'
            : '2-turned-${size.width.round()}x${size.height.round()}';
        if (!await _look(step, failed: true, waiting: false)) return;
        if (_store.attempts != 1) {
          _problem(step, 'attempts ${_store.attempts} != 1');
        }
        if (!_settings.isFirstLaunch) {
          _problem(step, 'isFirstLaunch became false');
        }
      }
    }

    // 3. 保存が例外になった。
    await _pressAndFail('3-threw', _Save.fail, 2, 'audit-first-launch-write');
    if (!await _look('3-threw', failed: true, waiting: false)) return;

    // 4. 保存を待っている間は押せず、進捗を出し、前の失敗の文は消える。
    // 外側のタップ・Esc・戻る操作でも閉じない。
    _store.mode = _Save.wait;
    // 間に画面を描かない二度押し（ダブルタップ・Enterの2回）でも保存は1回。
    await _press('4-waiting', twice: true);
    if (_store.attempts != 3) {
      _problem(
        '4-waiting',
        'a second press in the same frame saved again '
            '(attempts ${_store.attempts} != 3)',
      );
    }
    await _settle(waiting: true);
    if (_store.attempts != 3) {
      _problem('4-waiting', 'attempts ${_store.attempts} != 3');
    }
    if (!await _look('4-waiting', failed: false, waiting: true)) return;
    if (!await _tryToDismiss('4-waiting', waiting: true)) return;
    // 押せなくなった後でもう一度押しても、保存は1回だけ。
    if (screen.pc) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    } else {
      await tester.tap(_start, warnIfMissed: false);
    }
    await _settle(waiting: true);
    if (_store.attempts != 3) {
      _problem('4-waiting', 'second press saved again (${_store.attempts})');
    }
    // 待った末に断られた：開いたまま知らせる。
    await _store.finishWaiting(saved: false);
    await tester.pumpAndSettle();
    if (!await _look(
      '4b-waited-rejected',
      failed: true,
      waiting: false,
      capture: false,
    )) {
      return;
    }
    if (!_settings.isFirstLaunch) {
      _problem('4b-waited-rejected', 'isFirstLaunch became false');
    }

    // 5. 待った末に保存できた：そのときだけ閉じる。
    _store.mode = _Save.wait;
    await _press('5-saved');
    await _settle(waiting: true);
    if (_dialog.evaluate().isEmpty) {
      _problem('5-saved', 'closed before the save finished');
      return;
    }
    await _store.finishWaiting(saved: true);
    await tester.pumpAndSettle();
    final record = <String, Object?>{'step': '5-saved'};
    _steps.add(record);
    final error = tester.takeException();
    if (error != null) _problem('5-saved', 'exception: $error');
    if (_dialog.evaluate().isNotEmpty) {
      _problem('5-saved', 'still open after a successful save');
    }
    if (_settings.isFirstLaunch) {
      _problem('5-saved', 'isFirstLaunch still true');
    }
    if (_store.attempts != 4) {
      _problem('5-saved', 'attempts ${_store.attempts} != 4');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool('first_launch') != false) {
      _problem('5-saved', 'first_launch not stored as false');
    }
    final home = tester.element(find.byType(HomeScreen));
    if (ModalRoute.of(home)?.isCurrent != true) {
      _problem('5-saved', 'Home is not the current route after closing');
    }
    // 案内を閉じた後のホームにも、他の言語で仮名が出ていないか（記録のみ）。
    if (language != 'ja') {
      final kana = <String>{
        for (final e in find.byType(RichText).evaluate())
          if (_kana.hasMatch(
            (e.renderObject! as RenderParagraph).text.toPlainText(),
          ))
            (e.renderObject! as RenderParagraph).text.toPlainText(),
      };
      record['homeKana'] = kana.toList();
    }
    record['png'] = await _capture('5-saved');
  }

  Future<void> _pressAndFail(
    String step,
    _Save mode,
    int attempts,
    String recorded,
  ) async {
    _store.mode = mode;
    final before = AppErrorReporter.recentErrors.isEmpty
        ? null
        : AppErrorReporter.recentErrors.first;
    await _press(step);
    await tester.pumpAndSettle();
    if (_store.attempts != attempts) {
      _problem(step, 'attempts ${_store.attempts} != $attempts');
    }
    if (!_settings.isFirstLaunch) _problem(step, 'isFirstLaunch became false');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool('first_launch') != true) {
      _problem(step, 'first_launch stored although the save failed');
    }
    final latest = AppErrorReporter.recentErrors.isEmpty
        ? null
        : AppErrorReporter.recentErrors.first;
    if (identical(latest, before) || !(latest ?? '').contains(recorded)) {
      _problem(step, 'failure not recorded in the error log');
    }
  }

  /// 「はじめる」を押す。スマホではタップ。PCではキーボードで、まずEnter
  /// だけを押し（案内を見てすぐEnterを押す人）、押せなければ「はじめる」に
  /// フォーカスが来るまでTabを押してからEnter（Tabが要ったことは不具合
  /// `PC-ENTER-NEEDS-TAB`として記録する）。[twice]なら、間に画面を描かずに
  /// もう一度押す（同じフレームの2回目のタップ・Enter）。
  Future<void> _press(String step, {bool twice = false}) async {
    if (!screen.pc) {
      await tester.ensureVisible(_start);
      await tester.tap(_start);
      if (twice) await tester.tap(_start, warnIfMissed: false);
      return;
    }
    final before = _store.attempts;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    var tabs = 0;
    if (_store.attempts == before) {
      // Enterでは何も起きなかった。後ろのホームにも届いていないこと。
      await tester.pump();
      final error = tester.takeException();
      if (error != null) _problem(step, 'exception after Enter: $error');
      if (_dialog.evaluate().length != 1 ||
          ModalRoute.of(tester.element(_surface))?.isCurrent != true) {
        _problem(step, 'Enter without focus changed the screen');
        return;
      }
      while (!_startFocused() && tabs < 4) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        tabs++;
      }
      if (!_startFocused()) {
        _problem(step, 'Tab does not reach the Start button');
        await tester.tap(_start);
        return;
      }
      _defect('PC-ENTER-NEEDS-TAB $step ($tabs Tab)');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    }
    if (twice) await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    _steps.add({'step': '$step-press', 'tabsBeforeEnter': tabs});
  }

  Future<void> _settle({required bool waiting}) async {
    if (!waiting) {
      await tester.pumpAndSettle();
      return;
    }
    // 進捗の表示は止まらないので、決まった時間だけ進める。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<String> _capture(String step) async {
    final file = '${name}_$step.png';
    await tester.runAsync(() async {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      _out.createSync(recursive: true);
      File('${_out.path}/$file').writeAsBytesSync(png!.buffer.asUint8List());
    });
    return file;
  }

  String _which(String text) {
    if (text == expected.homeFirstLaunchMessage) return 'welcome';
    if (text == expected.homeFirstLaunchSaveFailed) return 'failure';
    if (text == expected.homeFirstLaunchStart) return 'start';
    return '"$text"';
  }

  /// 案内の状態を確かめて撮る。案内がちょうど1つ開いていなければfalse。
  Future<bool> _look(
    String step, {
    required bool failed,
    required bool waiting,
    bool capture = true,
  }) async {
    final record = <String, Object?>{
      'step': step,
      'size': [_size.width, _size.height],
    };
    _steps.add(record);
    final error = tester.takeException();
    if (error != null) _problem(step, 'exception: $error');
    final open = _dialog.evaluate().length;
    if (open != 1) {
      _problem(
        step,
        open == 0 ? 'notice is not open' : '$open notices open (expected 1)',
      );
      if (capture) record['png'] = await _capture(step);
      return false;
    }
    final box = tester.getRect(_surface);
    record['dialog'] = [box.left, box.top, box.width, box.height];
    if (!_inside(box, _safeRect)) {
      _problem(step, 'notice $box leaves the screen or covers its bars');
    }
    if (box.width > 560.5) _problem(step, 'notice wider than 560: $box');

    final context = tester.element(_surface);
    if (Localizations.localeOf(context) != localeFromLanguageCode(language)) {
      _problem(step, 'locale ${Localizations.localeOf(context)}');
    }
    final applied = MediaQuery.textScalerOf(context).scale(10) / 10;
    if ((applied - scale).abs() > 0.01) {
      _problem(step, 'text scale $applied instead of $scale');
    }

    if (_message.evaluate().length != 1) {
      _problem(step, 'welcome text is not the $language text');
    }

    // 案内の中の文：行の上限で切れず、案内の外へ横にはみ出さず、
    // 他の言語なら仮名（英・西・仏は漢字・ハングルも）が混ざらない。
    final texts = <String>[];
    // 文字の大きさ2倍ではAlertDialogが余白を8pxまで詰めるため、字が角の
    // 丸みにかかる所を記録する（見た目の記録のみで、判定はしない）。
    final outline = tester.widget<Material>(_surface).shape?.getOuterPath(box);
    for (final element in _inDialog(find.byType(RichText)).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text
          .toPlainText(includeSemanticsLabels: false)
          .replaceAll('⁠', '');
      texts.add(text);
      if (paragraph.didExceedMaxLines) _problem(step, 'text cut: "$text"');
      final rect = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        Offset.zero & paragraph.size,
      );
      if (rect.left < box.left - 0.5 || rect.right > box.right + 0.5) {
        _problem(step, 'text leaves the notice sideways: "$text" $rect');
      }
      if (language != 'ja' && _kana.hasMatch(text)) {
        _problem(step, 'Japanese kana in $language: "$text"');
      }
      if (_latin && _cjk.hasMatch(text)) {
        _problem(step, 'CJK characters in $language: "$text"');
      }
      // 韓国語は、どの文も語の途中で折り返さない。
      if (language == 'ko') {
        final breaks = _koreanMidWordBreaks(paragraph);
        if (breaks.isNotEmpty) {
          _defect('KO-WORD-SPLIT ${_which(text)} ${breaks.join(' ')}');
        }
      }
      // 失敗の文の中の押すボタンの名前は、どの言語でも1行に収まる。
      if (text == expected.homeFirstLaunchSaveFailed) {
        final split = _splitQuotedName(
          paragraph,
          expected.homeFirstLaunchStart,
        );
        if (split == '') {
          _problem(step, 'the failure text does not name the Start button');
        } else if (split != null) {
          _defect('START-NAME-SPLIT $split');
        }
      }
      if (outline != null) {
        final outside = _glyphsOutside(paragraph, outline);
        if (outside.isNotEmpty) {
          final list =
              record.putIfAbsent('glyphsOutsideRoundedCorner', () => <String>[])
                  as List<String>;
          list.addAll(outside);
        }
      }
    }
    record['texts'] = texts;

    final notices = _notice.evaluate().length;
    if (failed) {
      if (notices != 1) {
        _problem(step, 'failure notice count $notices');
      } else {
        final shown = tester.widget<Text>(_notice).data!.replaceAll('⁠', '');
        if (shown != expected.homeFirstLaunchSaveFailed) {
          _problem(step, 'failure text "$shown" is not the $language text');
        }
        if (_inDialog(find.byIcon(Icons.error_outline)).evaluate().length !=
            1) {
          _problem(step, 'failure notice without its mark');
        }
      }
    } else if (notices != 0) {
      _problem(step, 'failure notice shown ($notices)');
    }
    if (waiting != _progress.evaluate().isNotEmpty) {
      _problem(step, waiting ? 'no progress while saving' : 'progress shown');
    }

    if (_start.evaluate().length != 1) {
      _problem(step, 'Start button missing');
    } else {
      final button = tester.getRect(_start);
      record['start'] = [button.left, button.top, button.width, button.height];
      if (!_inside(button, _safeRect) || !_inside(button, box)) {
        _problem(step, 'Start button $button outside the notice or screen');
      }
      if (button.height < 47.5) {
        _problem(step, 'Start button only ${button.height}px tall');
      }
      if (_start.hitTestable().evaluate().isEmpty) {
        _problem(step, 'Start button is covered');
      }
      final enabled = tester.widget<FilledButton>(_start).onPressed != null;
      if (enabled == waiting) {
        _problem(step, waiting ? 'Start enabled while saving' : 'Start off');
      }
      final label = find.descendant(of: _start, matching: find.byType(Text));
      final lines = _lineCount(tester.renderObject<RenderParagraph>(label));
      record['startLines'] = lines;
      if (lines != 1) _problem(step, 'Start label wraps to $lines lines');
    }

    var extent = 0.0;
    if (_scroll.evaluate().isNotEmpty) {
      extent = tester
          .state<ScrollableState>(_scroll.first)
          .position
          .maxScrollExtent;
    }
    record['scrollExtent'] = extent;
    if (capture) record['png'] = await _capture(step);

    // 中身がスクロールするときは、上の端・下の端のどちらから始めても、
    // 文がスクロールで見える所まで来ること（上の端では失敗の文、下の端では
    // 歓迎の文が隠れうる）。
    if (extent > 0.5) {
      ScrollPosition position() =>
          tester.state<ScrollableState>(_scroll.first).position;
      Rect viewport() => tester.getRect(_scroll.first).intersect(_safeRect);
      final reached = <String>[];
      for (final (end, at) in [('top', 0.0), ('bottom', extent)]) {
        for (final (what, finder) in [
          ('welcome', _message),
          if (failed) ('failure', _notice),
        ]) {
          if (finder.evaluate().length != 1) continue;
          position().jumpTo(at);
          await _settle(waiting: waiting);
          if (_inside(tester.getRect(finder), viewport())) continue;
          // 見える所より高い文は、上の端と下の端をそれぞれ見せられること。
          var ok = true;
          for (final alignment in const [0.0, 1.0]) {
            await Scrollable.ensureVisible(
              tester.element(finder),
              alignment: alignment,
            );
            await _settle(waiting: waiting);
            final text = tester.getRect(finder);
            final view = viewport();
            if (_inside(text, view)) break;
            if (text.height <= view.height + 0.5) {
              ok = false;
              break;
            }
            record['${what}TallerThanView'] = true;
            if (alignment == 0
                ? (text.top - view.top).abs() > 0.5
                : (text.bottom - view.bottom).abs() > 0.5) {
              ok = false;
            }
          }
          if (!ok) {
            _problem(step, '$what cannot be scrolled into view from the $end');
          } else {
            reached.add('$what from the $end');
          }
        }
      }
      record['scrolledIntoView'] = reached;
      if (capture && reached.isNotEmpty) {
        record['pngScrolled'] = await _capture('$step-scrolled');
      }
    }
    return true;
  }

  /// 外側のタップ・Esc・戻る操作で閉じず、保存もしないこと。閉じたらfalse。
  /// [focusInside]なら、EscはTabで案内の中へフォーカスを入れてから押す。
  Future<bool> _tryToDismiss(
    String step, {
    required bool waiting,
    bool focusInside = false,
  }) async {
    final attempts = _store.attempts;
    final box = tester.getRect(_surface);
    final outside = Offset(box.left / 2, (box.top + _safeRect.top) / 2);
    final results = <String, bool>{};
    await tester.tapAt(outside);
    await _settle(waiting: waiting);
    results['outsideTap'] = _dialog.evaluate().isNotEmpty;
    var tabs = 0;
    if (focusInside && _dialog.evaluate().isNotEmpty) {
      while (!_focusInDialog() && tabs < 4) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        tabs++;
      }
      if (!_focusInDialog()) {
        _problem(step, 'Tab does not move the focus into the notice');
      }
    }
    final focusedForEscape = _focusInDialog();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(waiting: waiting);
    results['escape'] = _dialog.evaluate().isNotEmpty;
    final handled = await tester.binding.handlePopRoute();
    await _settle(waiting: waiting);
    results['back'] = _dialog.evaluate().isNotEmpty;
    _steps.add({
      'step': '$step-dismiss',
      'stillOpen': results,
      'backHandled': handled,
      'focusInsideForEscape': focusedForEscape,
      'tabsForEscape': tabs,
    });
    final error = tester.takeException();
    if (error != null) _problem(step, 'exception while dismissing: $error');
    for (final entry in results.entries) {
      if (!entry.value) _problem(step, '${entry.key} closed the notice');
    }
    if (!handled) _problem(step, 'Back was not handled (the app would close)');
    if (_store.attempts != attempts) {
      _problem(step, 'dismissing saved the flag');
    }
    if (!_settings.isFirstLaunch) {
      _problem(step, 'dismissing marked the notice as seen');
    }
    if (find.byType(Drawer).evaluate().isNotEmpty) {
      _problem(step, 'the outside tap reached Home (drawer open)');
    }
    if (_dialog.evaluate().isEmpty) return false;
    final route = ModalRoute.of(tester.element(_surface));
    if (route?.popDisposition != RoutePopDisposition.doNotPop) {
      _problem(step, 'route would pop (${route?.popDisposition})');
    }
    if (route?.barrierDismissible != false) {
      _problem(step, 'barrier is dismissible');
    }
    return true;
  }
}
