// ブラシのショートカットの名前を、足したときのブラシの名前ではなく、
// そのブラシの今の名前と太さで作る（DISC230）。
//
// ブラシの割り当ての名前は、足したときのブラシの名前と太さ（「My liner 12px」）
// を保存したまま出していたので、ブラシの名前を変えても一覧・削除の確認は古い
// 名前のままだった。ブラシが無くなっていれば保存した名前を出す。組み込みの
// ブラシの名前が日本語なのはDISC107（所有者の判断待ち）で、ここでは変えない。
//
// 本物のショートカットの画面で、利用者のブラシ・組み込みのブラシ・消した
// ブラシの割り当てを並べ、ブラシの名前を変えると一覧と削除の確認の名前が
// 変わること、7言語で同じであること、保存が変わらないことを見る。
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

/// 一覧の行に出ている名前（キーのチップを除く、行の題の文）。
List<String> _shownNames(WidgetTester tester) => [
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('brush shortcut names follow the brush name', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    final saved = [
      ShortcutBinding(
        id: 'sc_brush_user',
        label: 'My liner 12px',
        keyId: LogicalKeyboardKey.keyL.keyId,
        alt: true,
        toolKey: 'pen',
        brushId: 'user_pen',
        sizeOverride: 12,
      ),
      ShortcutBinding(
        id: 'sc_brush_builtin',
        label: 'Gペン 6px',
        keyId: LogicalKeyboardKey.keyG.keyId,
        alt: true,
        toolKey: 'pen',
        brushId: 'Brush0002',
        sizeOverride: 6,
      ),
      ShortcutBinding(
        id: 'sc_brush_gone',
        label: 'Old brush 5px',
        keyId: LogicalKeyboardKey.keyO.keyId,
        alt: true,
        toolKey: 'pen',
        brushId: 'user_gone',
        sizeOverride: 5,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'shortcut_bindings': [for (final b in saved) jsonEncode(b.toJson())],
    });
    final shortcuts = ShortcutService();
    await tester.runAsync(shortcuts.init);
    final settings = SettingsService();
    await tester.runAsync(settings.init);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    final gPen = brushes.brushes.firstWhere((b) => b.id == 'Brush0002');
    brushes
      ..addBrush(gPen.copyWith(id: 'user_pen', name: 'My liner'))
      ..addBrush(gPen.copyWith(id: 'user_gone', name: 'Old brush'));
    brushes.deleteBrush('user_gone');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    final savedBefore = prefs.getStringList('shortcut_bindings');

    final language = ValueNotifier(const Locale('ja'));
    addTearDown(language.dispose);
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShortcutService>.value(value: shortcuts),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: RepaintBoundary(
          key: rootKey,
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

    Future<void> shoot(String name) async {
      if (shots == null) return;
      await tester.runAsync(() async {
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$shots/DISC230-$name.png',
        ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
        image.dispose();
      });
    }

    final problems = <String>[];
    // 画面を開いたままブラシの名前を変える。
    brushes.updateBrush(
      brushes.brushes
          .firstWhere((b) => b.id == 'user_pen')
          .copyWith(name: 'Inking pen'),
    );
    await tester.pumpAndSettle();
    await shoot('ja');
    for (final locale in AppLocalizations.supportedLocales) {
      language.value = locale;
      await tester.pumpAndSettle();
      final tag = locale.toLanguageTag();
      final names = _shownNames(tester);
      for (final expected in [
        // 名前を変えた利用者のブラシは、今の名前と決めた太さ。
        'Inking pen 12px',
        // 組み込みのブラシは、組み込みの名前（日本語、DISC107）と太さ。
        '${gPen.name} 6px',
        // 消したブラシは、保存した名前。
        'Old brush 5px',
      ]) {
        if (!names.contains(expected)) {
          problems.add('$tag: 「$expected」is not in the list $names');
        }
      }
      if (names.contains('My liner 12px')) {
        problems.add('$tag: the old brush name「My liner 12px」is still shown');
      }
    }
    // 削除の確認も今の名前で呼ぶ。
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('Inking pen 12px'),
      matching: find.byType(ListTile),
    );
    if (row.evaluate().isEmpty) {
      problems.add('en: no row named「Inking pen 12px」');
    } else {
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
      );
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final texts = [
        for (final element
            in find
                .descendant(of: dialog, matching: find.byType(RichText))
                .evaluate())
          (element.widget as RichText).text.toPlainText(),
      ].join(' ');
      if (!texts.contains('Inking pen 12px')) {
        problems.add('en: the delete question does not name the brush: $texts');
      }
      await shoot('en-delete');
      await tester.tap(
        find.text(lookupAppLocalizations(language.value).commonCancel).last,
      );
      await tester.pumpAndSettle();
    }
    // 保存は変えない（保存した名前も足したときのまま）。
    final savedAfter = (await tester.runAsync(
      SharedPreferences.getInstance,
    ))!.getStringList('shortcut_bindings');
    if (jsonEncode(savedAfter) != jsonEncode(savedBefore)) {
      problems.add('the saved shortcuts changed: $savedAfter');
    }
    for (final problem in problems) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
  });
}
