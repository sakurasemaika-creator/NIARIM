import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

class _FirstLaunchStore extends SharedPreferencesStorePlatform {
  _FirstLaunchStore(this.delegate);
  final SharedPreferencesStorePlatform delegate;
  String mode = 'off';
  int attempts = 0;
  Completer<bool>? pending;

  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (key != 'flutter.first_launch' || value != false) {
      return delegate.setValue(type, key, value);
    }
    attempts++;
    return switch (mode) {
      'reject' => Future.value(false),
      'throw' => Future.error(StateError('Audit first-launch write rejected')),
      'pending' => (pending ??= Completer<bool>()).future,
      _ => delegate.setValue(type, key, value),
    };
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 保存に失敗したときの知らせ（読み上げにも伝わる1行）の文の段落。
  // 韓国語では読み上げの文を別に渡すのでTextの下に読み上げの層が入る。
  // 段落（RichText）そのものを探す（先頭の印もRichTextで描かれるので、
  // Textの中のものに限る）。
  Finder saveFailureNotice() => find.descendant(
    of: find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      matching: find.byType(Text),
    ),
    matching: find.byType(RichText),
  );

  Future<
    ({SettingsService settings, AppLocalizations l10n, _FirstLaunchStore store})
  >
  open(
    WidgetTester tester, {
    String language = 'en',
    bool pc = false,
    Size size = const Size(390, 844),
    double scale = 1,
    AppThemePreset? theme,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': true,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      if (theme != null) ...{
        // 利用者が選んだテーマのまま開く（組み込みテーマを戻す初回の移行で
        // 置き換えられないようにする）。
        'theme_original_builtin_palette_restored_v1': true,
        'theme_current_json': jsonEncode(theme.toJson()),
      },
    });
    final delegate = SharedPreferencesStorePlatform.instance;
    final store = _FirstLaunchStore(delegate);
    SharedPreferencesStorePlatform.instance = store;
    final dir = Directory.systemTemp.createTempSync('first-launch-save-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = delegate;
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      dir.deleteSync(recursive: true);
    });
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    return (
      settings: home.read<SettingsService>(),
      l10n: AppLocalizations.of(home)!,
      store: store,
    );
  }

  testWidgets('first-use acknowledgement survives outside clicks and Back', (
    tester,
  ) async {
    final c = await open(tester);
    expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
    expect(c.settings.isFirstLaunch, isTrue);
    expect(c.store.attempts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in ['reject', 'throw']) {
    testWidgets('first-use acknowledgement can retry a $mode save', (
      tester,
    ) async {
      final c = await open(tester);
      c.store.mode = mode;
      await tester.tap(
        find.widgetWithText(FilledButton, c.l10n.homeFirstLaunchStart),
      );
      await tester.pumpAndSettle();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(saveFailureNotice(), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getBool('first_launch'), isTrue);
      expect(c.store.attempts, 1);
      c.store.mode = 'off';
      await tester.tap(
        find.widgetWithText(FilledButton, c.l10n.homeFirstLaunchStart),
      );
      await tester.pumpAndSettle();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsNothing);
      expect(c.settings.isFirstLaunch, isFalse);
      await prefs.reload();
      expect(prefs.getBool('first_launch'), isFalse);
      expect(c.store.attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'first-use acknowledgement waits for storage and prevents double activation',
    (tester) async {
      final c = await open(tester);
      c.store.mode = 'pending';
      final start = find.widgetWithText(
        FilledButton,
        c.l10n.homeFirstLaunchStart,
      );
      await tester.tap(start);
      await tester.pump();
      await tester.tap(start);
      await tester.pump();
      expect(c.store.attempts, 1);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      c.store.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(saveFailureNotice(), findsOneWidget);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('save failure remains readable and retryable in every locale', (
    tester,
  ) async {
    await loadAppFonts(tester);
    for (final language in ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es']) {
      for (final (pc, size, scale) in [
        (false, const Size(320, 844), 2.0),
        (false, const Size(640, 360), 2.0),
        (true, const Size(641, 360), 1.0),
        (true, const Size(1440, 900), 2.0),
      ]) {
        final c = await open(
          tester,
          language: language,
          pc: pc,
          size: size,
          scale: scale,
        );
        c.store.mode = 'reject';
        final start = find.widgetWithText(
          FilledButton,
          c.l10n.homeFirstLaunchStart,
        );
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final error = saveFailureNotice();
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
          isFalse,
          reason: '$language $pc $size $scale',
        );
        final bounds = tester.getRect(error);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(
          find.ancestor(
            of: error,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.liveRegion == true,
            ),
          ),
          findsOneWidget,
        );
        // 色ではなく先頭の印と文で知らせる。文字の色はダイアログの文字色。
        final scheme = Theme.of(tester.element(error)).colorScheme;
        expect(
          tester.renderObject<RenderParagraph>(error).text.style!.color,
          scheme.onSurface,
        );
        expect(
          find.descendant(
            of: find.ancestor(of: error, matching: find.byType(Row)).first,
            matching: find.byIcon(Icons.error_outline),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(start);
        expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
        c.store.mode = 'off';
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.text(c.l10n.homeFirstLaunchMessage), findsNothing);
        expect(c.settings.isFirstLaunch, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  // 韓国語は語（空白で区切った単位）の途中で折り返さない。Flutterは
  // ハングルをどの字の間でも折り返すので、押すボタンの名前「시작하기」まで
  // 2行に割れていた。
  testWidgets('the Korean save failure notice wraps only between words', (
    tester,
  ) async {
    await loadAppFonts(tester);
    for (final (size, scale) in [
      (const Size(320, 568), 2.0),
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(640, 360), 1.0),
      (const Size(640, 360), 2.0),
      (const Size(1280, 800), 1.0),
      (const Size(1280, 800), 2.0),
    ]) {
      final c = await open(tester, language: 'ko', size: size, scale: scale);
      c.store.mode = 'reject';
      final start = find.widgetWithText(
        FilledButton,
        c.l10n.homeFirstLaunchStart,
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      final notice = saveFailureNotice();
      expect(notice, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(notice);
      final text = paragraph.text.toPlainText();
      // 字の間の結合子を除けば、文はARBのまま。
      expect(text.replaceAll('\u2060', ''), c.l10n.homeFirstLaunchSaveFailed);
      // 語の中で隣り合う2字の字の箱が上下に重ならなければ、その間で
      // 行が替わっている（括弧・句点は別の書体で箱の高さが違うので、
      // 上端どうしではなく重なりで比べる）。
      final breaks = <String>[];
      TextBox? last;
      var previous = '';
      for (var i = 0; i < text.length; i++) {
        final char = text[i];
        if (char.trim().isEmpty) {
          last = null;
          continue;
        }
        if (char == '\u2060') continue;
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        if (boxes.isEmpty) continue;
        final box = boxes.first;
        if (last != null &&
            (box.top >= last.bottom - 1 || box.bottom <= last.top + 1)) {
          breaks.add('$previous|$char');
        }
        last = box;
        previous = char;
      }
      expect(breaks, isEmpty, reason: '$size x$scale');
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  // 語結合子は表示の折り返しのためだけのもの。読み上げ・点字には元の文を
  // 渡す（語結合子ごと渡すと、音節ごとに区切りが入る）。
  testWidgets('screen readers get the Korean save failure notice without '
      'word joiners', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await open(tester, language: 'ko');
    c.store.mode = 'reject';
    final start = find.widgetWithText(
      FilledButton,
      c.l10n.homeFirstLaunchStart,
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    final notice = saveFailureNotice();
    expect(notice, findsOneWidget);
    // 表示は語の途中で折り返さないよう語結合子を入れたまま。
    expect(
      tester.renderObject<RenderParagraph>(notice).text.toPlainText(),
      contains('\u2060'),
    );
    final labels = [
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        if (node.label.isNotEmpty) node.label,
    ];
    expect(
      labels.where((label) => label.contains('\u2060')).toList(),
      isEmpty,
      reason: '$labels',
    );
    expect(
      labels.any((label) => label.contains(c.l10n.homeFirstLaunchSaveFailed)),
      isTrue,
      reason: '$labels',
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 知らせの色は差し色から作られるcolorScheme.errorではなく、ダイアログの
  // 文字色（テーマ・外観で選ぶ色）。何を保存できなかったか・もう一度
  // 「はじめる」を押せばよいことを文で伝える。
  for (final language in ['ja', 'en', 'fr']) {
    testWidgets('save failure notice uses the dialog text colour and names '
        'the retry ($language)', (tester) async {
      final preset = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF16593A),
        menuTextColor: const Color(0xFF17325A),
        accentColor: const Color(0xFFB03A6E),
      );
      final c = await open(tester, language: language, theme: preset);
      c.store.mode = 'reject';
      await tester.tap(
        find.widgetWithText(FilledButton, c.l10n.homeFirstLaunchStart),
      );
      await tester.pumpAndSettle();
      final notice = saveFailureNotice();
      expect(notice, findsOneWidget);
      final message = tester.widget<RichText>(notice).text.toPlainText();
      expect(message, isNot(c.l10n.communityErrorGeneric));
      expect(message, contains(c.l10n.homeFirstLaunchStart));
      final scheme = Theme.of(tester.element(notice)).colorScheme;
      expect(preset.textColor, isNot(scheme.error));
      expect(
        tester.renderObject<RenderParagraph>(notice).text.style!.color,
        preset.textColor,
      );
      final icon = find.descendant(
        of: find.ancestor(of: notice, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.error_outline),
      );
      expect(icon, findsOneWidget);
      expect(tester.widget<Icon>(icon).color, preset.textColor);
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
