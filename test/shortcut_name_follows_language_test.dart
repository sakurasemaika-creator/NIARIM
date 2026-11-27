// 足したショートカットの名前も、表示の言語に合わせて出す（DISC157）。
//
// 操作・ツールの割り当ての名前は、足したときの言語の文（「后退1帧（时间轴）」）を
// 保存し、一覧はそれをそのまま出していた（既定の割り当てだけを言語の名前に
// 置き換えていた）。中国語（簡体字）で足したショートカットは、繁体字や日本語に
// 切り替えても簡体字のまま出ていた。名前は保存した文ではなく、操作・ツールの
// 種類から表示のたびに今の言語で作る（前の版で保存した割り当ても）。ブラシの
// 割り当ての名前（ブラシの名前と太さ）は利用者のデータなので、保存したまま。
//
// 本物のショートカットの画面で、(1)前の版が簡体字で保存した割り当て（操作・
// 消しゴム・スポイト・バケツ・ブラシ）を読み、7言語を切り替えて一覧の名前と
// 削除の確認の名前を見る、(2)簡体字の画面で「追加」→キーを押す→「主要操作」→
// 「1フレーム進む」と足し、7言語を切り替えて見る、(3)保存と引き継ぎ
// （.niatra）で読むJSONの形が変わっていない（足したものも前の版で読める）こと
// を見張る。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

const _zh = Locale('zh');
final _shots = Platform.environment['NIARIM_SET1_SHOTS'];
final _rootKey = GlobalKey();

/// 前の版が簡体字の画面で足して保存した割り当て（足したときの言語の名前つき）。
List<ShortcutBinding> _savedInSimplifiedChinese() {
  final zh = lookupAppLocalizations(_zh);
  return [
    ShortcutBinding(
      id: 'sc_1700000000001',
      label: zh.shortcutCommandPreviousFrame,
      keyId: LogicalKeyboardKey.keyQ.keyId,
      alt: true,
      command: ShortcutCommand.previousFrame,
    ),
    ShortcutBinding(
      id: 'sc_1700000000002',
      label: zh.quickToolEraser,
      keyId: LogicalKeyboardKey.keyE.keyId,
      alt: true,
      toolKey: 'eraser',
    ),
    ShortcutBinding(
      id: 'sc_1700000000003',
      label: zh.quickToolEyedropper,
      keyId: LogicalKeyboardKey.keyI.keyId,
      alt: true,
      toolKey: 'eyedropper',
    ),
    ShortcutBinding(
      id: 'sc_1700000000004',
      label: zh.quickToolBucket,
      keyId: LogicalKeyboardKey.keyB.keyId,
      alt: true,
      toolKey: 'bucket',
    ),
    const ShortcutBinding(
      id: 'sc_1700000000005',
      label: 'G pen 12px',
      keyId: 0x00000067, // g
      alt: true,
      toolKey: 'pen',
      brushId: 'g_pen',
      sizeOverride: 12,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  /// 画像を撮る（NIARIM_SET1_SHOTSを渡したときだけ）。
  Future<void> shot(WidgetTester tester, String name) async {
    final dir = _shots;
    if (dir == null) return;
    await tester.runAsync(() async {
      final boundary =
          _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$dir/DISC157-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
      image.dispose();
    });
  }

  Future<(ShortcutService, ValueNotifier<Locale>)> open(
    WidgetTester tester, {
    required Locale locale,
    List<ShortcutBinding> saved = const [],
  }) async {
    if (_shots != null) await loadAppFonts(tester);
    tester.view.physicalSize = Size(412, _shots == null ? 1800 : 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      if (saved.isNotEmpty)
        'shortcut_bindings': [for (final b in saved) jsonEncode(b.toJson())],
    });
    final shortcuts = ShortcutService();
    await tester.runAsync(shortcuts.init);
    final settings = SettingsService();
    await tester.runAsync(settings.init);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    final language = ValueNotifier(locale);
    addTearDown(language.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShortcutService>.value(value: shortcuts),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: RepaintBoundary(
          key: _rootKey,
          child: ValueListenableBuilder<Locale>(
            valueListenable: language,
            builder: (context, locale, _) => MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ShortcutSettingsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (shortcuts, language);
  }

  /// 一覧の行に出ている名前（キーのチップを除く、行の題の文）。名前は
  /// 韓国語の語・数をつなぐ`KeepTogetherText`（`Text`の仲間）でも描く。
  List<String> shownNames(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      ...find
          .descendant(
            of: find.byWidget(tile),
            matching: find.byWidgetPredicate((w) => w is Text),
          )
          .evaluate()
          .map((e) => e.widget as Text)
          // キーのチップ（読み上げに元のキーの組を添えている）は除く。
          .where((t) => t.semanticsLabel == null)
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => t.isNotEmpty),
  ];

  testWidgets('shortcuts saved in Simplified Chinese show their names in the '
      'language on screen', (tester) async {
    final saved = _savedInSimplifiedChinese();
    final (service, language) = await open(tester, locale: _zh, saved: saved);
    expect(
      service.bindings.map((b) => b.id),
      containsAll(saved.map((b) => b.id)),
    );
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      language.value = locale;
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      final names = shownNames(tester);
      if (locale.languageCode != 'en') await shot(tester, 'saved_$tag');
      for (final expected in [
        l10n.shortcutCommandPreviousFrame,
        l10n.quickToolEraser,
        l10n.quickToolEyedropper,
        l10n.quickToolBucket,
        // ブラシの割り当ては、保存した名前（ブラシの名前と太さ）のまま。
        'G pen 12px',
      ]) {
        if (!names.contains(expected)) {
          problems.add('$tag: 「$expected」is not in the list $names');
        }
      }
      // 簡体字の名前が、ほかの言語の画面に残っていない。
      if (locale != _zh) {
        for (final binding in saved.take(4)) {
          final own = shortcutDisplayLabel(l10n, binding);
          if (binding.label != own && names.contains(binding.label)) {
            problems.add('$tag: the saved name「${binding.label}」is shown');
          }
        }
      }
      // 削除の確認も、今の言語の名前で尋ねる。
      if (find.text(l10n.shortcutCommandPreviousFrame).evaluate().isEmpty) {
        continue;
      }
      final row = find.ancestor(
        of: find.text(l10n.shortcutCommandPreviousFrame),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
      );
      await tester.pumpAndSettle();
      final body = l10n.confirmDeleteNamedBody(
        l10n.shortcutCommandPreviousFrame,
      );
      if (find.text(body).evaluate().isEmpty) {
        problems.add('$tag: the delete confirmation does not say「$body」');
      }
      await tester.tap(find.text(l10n.commonCancel).last);
      await tester.pumpAndSettle();
    }
    for (final problem in problems) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
    // 前の版の保存は書き換えない（読むだけ）。
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getStringList('shortcut_bindings')!;
    for (final binding in saved) {
      expect(kept, contains(jsonEncode(binding.toJson())));
    }
  });

  testWidgets('a shortcut added in Simplified Chinese follows the language '
      'switched to', (tester) async {
    final (service, language) = await open(tester, locale: _zh);
    final zh = lookupAppLocalizations(_zh);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text(zh.shortcutCaptureTitle), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.shortcutActionTypeCommand));
    await tester.pumpAndSettle();
    // The choice in the sheet (the list behind it has the default → key for
    // the same command since 2026-11-27).
    await tester.tap(find.text(zh.shortcutCommandNextFrame).last);
    await tester.pumpAndSettle();
    final added = service.bindings.singleWhere(
      (b) => b.keyId == LogicalKeyboardKey.keyW.keyId,
    );
    expect(added.command, ShortcutCommand.nextFrame);
    expect(added.id.startsWith('default_'), isFalse);

    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      language.value = locale;
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      final names = shownNames(tester);
      if (locale.languageCode != 'en') await shot(tester, 'added_$tag');
      if (!names.contains(l10n.shortcutCommandNextFrame)) {
        problems.add(
          '$tag: 「${l10n.shortcutCommandNextFrame}」is not in the list $names',
        );
      }
      if (locale != _zh && names.contains(zh.shortcutCommandNextFrame)) {
        problems.add(
          '$tag: the Chinese name「${zh.shortcutCommandNextFrame}」'
          'is shown',
        );
      }
    }
    for (final problem in problems) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');

    // 保存・引き継ぎで読むJSONの形は今までどおり（前の版でも読める）。
    final prefs = await SharedPreferences.getInstance();
    final stored = [
      for (final raw in prefs.getStringList('shortcut_bindings')!)
        jsonDecode(raw) as Map<String, dynamic>,
    ].singleWhere((json) => json['keyId'] == LogicalKeyboardKey.keyW.keyId);
    expect(stored.keys.toSet(), added.toJson().keys.toSet());
    expect(stored['label'], isA<String>());
    expect(stored['command'], 'nextFrame');
    expect(ShortcutBinding.fromJson(stored).command, ShortcutCommand.nextFrame);
  });
}
