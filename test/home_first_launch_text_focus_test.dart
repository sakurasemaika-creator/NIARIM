import 'dart:async';
import 'dart:io';

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
import 'package:niarim/utils/line_break.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 「案内を見た」の保存だけを、断る・待たせることができる保存先。
class _FirstLaunchStore extends SharedPreferencesStorePlatform {
  _FirstLaunchStore(this.delegate);
  final SharedPreferencesStorePlatform delegate;
  bool reject = false;
  Completer<bool>? pending;
  int attempts = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (key != 'flutter.first_launch' || value != false) {
      return delegate.setValue(type, key, value);
    }
    attempts++;
    final waiting = pending;
    if (waiting != null) return waiting.future;
    if (reject) return Future.value(false);
    return delegate.setValue(type, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
}

const _sizes = [
  (Size(320, 568), 1.0),
  (Size(320, 568), 2.0),
  (Size(360, 800), 1.0),
  (Size(360, 800), 2.0),
  (Size(390, 844), 1.0),
  (Size(390, 844), 2.0),
  (Size(640, 360), 1.0),
  (Size(640, 360), 2.0),
  (Size(1280, 800), 1.0),
  (Size(1280, 800), 2.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({SettingsService settings, _FirstLaunchStore store})> open(
    WidgetTester tester, {
    required String language,
    bool pc = false,
    Size size = const Size(390, 844),
  }) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': true,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final delegate = SharedPreferencesStorePlatform.instance;
    final store = _FirstLaunchStore(delegate);
    SharedPreferencesStorePlatform.instance = store;
    final dir = Directory.systemTemp.createTempSync('first-launch-text-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = delegate;
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    return (settings: home.read<SettingsService>(), store: store);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;

  Future<void> show(
    WidgetTester tester,
    SettingsService settings, {
    required String language,
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    await tester.runAsync(() => settings.setLanguage(language));
    await tester.pumpAndSettle();
  }

  /// ダイアログの中で、語結合子を除いた文が[plain]の段落。
  RenderParagraph paragraphOf(WidgetTester tester, String plain) {
    final found = [
      for (final element
          in find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(RichText),
              )
              .evaluate())
        if ((element.renderObject! as RenderParagraph).text
                .toPlainText(includeSemanticsLabels: false)
                .replaceAll(wordJoiner, '') ==
            plain)
          element.renderObject! as RenderParagraph,
    ];
    expect(found, hasLength(1), reason: plain);
    return found.single;
  }

  /// 語（空白で区切った単位）の途中で行が替わっている所。
  List<String> midWordBreaks(ParagraphLines lines) {
    final breaks = <String>[];
    for (var i = 1; i < lines.visible.length; i++) {
      final before = lines.lineOf(i - 1);
      final after = lines.lineOf(i);
      if (before == null || after == null || before == after) continue;
      if (lines.visible[i - 1].trim().isEmpty ||
          lines.visible[i].trim().isEmpty) {
        continue;
      }
      breaks.add('${lines.visible[i - 1]}|${lines.visible[i]}');
    }
    return breaks;
  }

  bool startHasFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    var inside = context.widget is FilledButton;
    context.visitAncestorElements((element) {
      if (element.widget is FilledButton) inside = true;
      return !inside;
    });
    return inside;
  }

  // 韓国語は語（空白で区切った単位）の途中で折り返さない。案内の本文
  // 「손그림 애니메이션을 제작할 수 있습니다」が「…있습니／다」「제／작할」と
  // 語の途中で切れていた。
  testWidgets('the Korean welcome text wraps only between words', (
    tester,
  ) async {
    final c = await open(tester, language: 'ko');
    for (final (size, scale) in _sizes) {
      await show(tester, c.settings, language: 'ko', size: size, scale: scale);
      final message = l10nOf(tester).homeFirstLaunchMessage;
      final lines = ParagraphLines(paragraphOf(tester, message));
      expect(lines.visible, message);
      expect(
        midWordBreaks(lines),
        isEmpty,
        reason: '$size x$scale: ${lines.lines.join(' / ')}',
      );
      expect(lines.charsOutsideWidth(), isEmpty, reason: '$size x$scale');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 語結合子は表示の折り返しのためだけのもの。読み上げには元の文を渡す。
  testWidgets('screen readers get the Korean welcome text without word '
      'joiners', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, language: 'ko');
    final message = l10nOf(tester).homeFirstLaunchMessage;
    // 描く文には語結合子が入っているが、文そのもの（探す・読み上げる）は
    // ARBのまま。
    expect(
      paragraphOf(
        tester,
        message,
      ).text.toPlainText(includeSemanticsLabels: false),
      contains(wordJoiner),
    );
    expect(find.text(message), findsOneWidget);
    final labels = [
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        if (node.label.isNotEmpty) node.label,
    ];
    expect(
      labels.where((label) => label.contains(wordJoiner)).toList(),
      isEmpty,
      reason: '$labels',
    );
    expect(
      labels.any((label) => label.contains(message)),
      isTrue,
      reason: '$labels',
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 保存できなかったときの文は、押すボタンの名前を引用符ごと1行に保つ。
  // 日本語・中国語は字の間のどこでも折り返せるので、「「はじ／める」」
  // 「“开始使／用”」とボタンの名前の途中で切れていた。
  testWidgets('the save failure text keeps the quoted Start name on one line', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = await open(tester, language: 'ja');
    c.store.reject = true;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(c.store.attempts, 1);
    for (final language in ['ja', 'zh', 'zh_Hant', 'ko', 'en', 'es', 'fr']) {
      for (final (size, scale) in _sizes) {
        await show(
          tester,
          c.settings,
          language: language,
          size: size,
          scale: scale,
        );
        final l10n = l10nOf(tester);
        final message = l10n.homeFirstLaunchSaveFailed;
        final name = l10n.homeFirstLaunchStart;
        final lines = ParagraphLines(paragraphOf(tester, message));
        final at = message.indexOf(name);
        expect(at, greaterThan(0), reason: language);
        // 名前のすぐ外の引用符も名前と同じ行に置く。空白で語を区切る
        // 言語の名前（“Get Started”）が空白の所で折り返すのは数えない。
        final breaks = [
          for (final i in lines.breaksWithin(at - 1, at + name.length + 1))
            if (lines.visible[i - 1].trim().isNotEmpty) i,
        ];
        expect(
          breaks,
          isEmpty,
          reason: '$language $size x$scale: ${lines.lines.join(' / ')}',
        );
        expect(
          lines.charsOutsideWidth(),
          isEmpty,
          reason: '$language $size x$scale',
        );
      }
    }
    // 読み上げには語結合子を除いた元の文を渡す。
    await show(
      tester,
      c.settings,
      language: 'ja',
      size: const Size(390, 844),
      scale: 1,
    );
    final labels = [
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        if (node.label.isNotEmpty) node.label,
    ];
    expect(
      labels.where((label) => label.contains(wordJoiner)).toList(),
      isEmpty,
      reason: '$labels',
    );
    expect(
      labels.any(
        (label) => label.contains(l10nOf(tester).homeFirstLaunchSaveFailed),
      ),
      isTrue,
      reason: '$labels',
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 名前を囲む引用符は名前と同じ行に置く。フランス語は引用符と名前の間に
  // 空白を入れて書くので、普通の空白だと「« Commencer / » pour…」と閉じる
  // 引用符だけが次の行の頭に来ていた（356px・文字1倍、332px・2倍など）。
  testWidgets('the quotation marks around the Start name stay on the same line '
      'as the name at every width', (tester) async {
    final c = await open(tester, language: 'ja');
    c.store.reject = true;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(c.store.attempts, 1);
    final split = <String>[];
    for (final language in ['fr', 'es', 'en', 'ja', 'zh', 'zh_Hant', 'ko']) {
      await show(
        tester,
        c.settings,
        language: language,
        size: const Size(480, 844),
        scale: 1,
      );
      for (final scale in const [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (var width = 320.0; width <= 480; width += 4) {
          tester.view.physicalSize = Size(width, 844);
          await tester.pump();
          final l10n = l10nOf(tester);
          final message = l10n.homeFirstLaunchSaveFailed;
          final name = l10n.homeFirstLaunchStart;
          final lines = ParagraphLines(paragraphOf(tester, message));
          final first = lines.visible.indexOf(name);
          final last = first + name.length - 1;
          // 名前の前後の空白（ふつうの空白・改行しない空白）を飛ばした
          // 隣の字が引用符。
          var open = first - 1;
          while (open > 0 && lines.visible[open].trim().isEmpty) {
            open--;
          }
          var close = last + 1;
          while (close < lines.visible.length - 1 &&
              lines.visible[close].trim().isEmpty) {
            close++;
          }
          if (lines.lineOf(open) != lines.lineOf(first) ||
              lines.lineOf(close) != lines.lineOf(last)) {
            split.add(
              '$language ${width}px x$scale: ${lines.lines.join(' / ')}',
            );
          }
        }
      }
    }
    expect(split, isEmpty, reason: split.join('\n'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('keepPhraseTogether joins a CJK name and its quotation marks only', () {
    const ja = 'もう一度「はじめる」を押してください。';
    final joined = keepPhraseTogether(ja, 'はじめる');
    expect(joined, isNot(ja));
    expect(plainSemanticsLabel(joined), ja);
    // 引用符から引用符までの字の間すべてに語結合子が入る。
    expect(joined, contains(['「', 'は', 'じ', 'め', 'る', '」'].join(wordJoiner)));
    // 名前の外には入れない。
    expect(joined.split(wordJoiner), hasLength(6));
    const zh = '请再次点击“开始使用”。';
    expect(
      keepPhraseTogether(zh, '开始使用'),
      contains(['“', '开', '始', '使', '用', '”'].join(wordJoiner)),
    );
    // 空白で語を区切る言語の名前は語の途中で折り返されないので何もしない。
    const en = 'Press “Get Started” to try again.';
    expect(keepPhraseTogether(en, 'Get Started'), en);
    const es = 'Pulsa «Comenzar» para intentarlo de nuevo.';
    expect(keepPhraseTogether(es, 'Comenzar'), es);
    // 文に無い名前・空の名前。
    expect(keepPhraseTogether(ja, 'すすむ'), ja);
    expect(keepPhraseTogether(ja, ''), ja);
  });

  // PC（キーボード）：案内が開いたらEnterで「はじめる」を押せる。
  testWidgets('Enter presses Start as soon as the notice opens', (
    tester,
  ) async {
    final c = await open(
      tester,
      language: 'ja',
      pc: true,
      size: const Size(1280, 800),
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(startHasFocus(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.store.attempts, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(c.settings.isFirstLaunch, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 保存を待っている間はボタンが押せなくなりフォーカスが外れる。保存に
  // 失敗して押せるように戻ったら、フォーカスも戻してEnterでやり直せる。
  testWidgets('after a save that was waited on and failed, Enter retries', (
    tester,
  ) async {
    final c = await open(
      tester,
      language: 'ja',
      pc: true,
      size: const Size(1280, 800),
    );
    // 修正前は開いた時点でフォーカスが無いので、Tabで「はじめる」へ移す。
    for (var i = 0; i < 4 && !startHasFocus(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(startHasFocus(), isTrue);
    c.store.pending = Completer<bool>();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.store.attempts, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'Start is disabled while the save is pending',
    );
    final waiting = c.store.pending!;
    c.store.pending = null;
    c.store.reject = true;
    waiting.complete(false);
    await tester.pumpAndSettle();
    // 失敗の文が出ている。
    paragraphOf(tester, l10nOf(tester).homeFirstLaunchSaveFailed);
    expect(startHasFocus(), isTrue, reason: 'focus returns to Start');
    c.store.reject = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.store.attempts, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(c.settings.isFirstLaunch, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
