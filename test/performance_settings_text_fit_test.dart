// 品質の設定（パフォーマンス設定）の画面が、狭い幅・大きな文字でもはみ出さず、
// 語の途中で折らず、文を切らず、数を言語の書き方（複数形）で、オン・オフを
// その言語で出すことを見張る（DISC129）。
//
// 以前は、仏語360px×文字2倍で「Recommandé」の印が37px、「Mode de
// sauvegarde / Par emplacement」「Nombre d’emplacements / 5 emplacements」の
// 行が58・41pxはみ出し、「Nombre d’annulations」の見出しが「annulatio / ns」と
// 語の途中で折れ、「1 images」（複数形でない）と「OFF」（訳されていない）が
// 出ていた。画面名は「…」で切れていた（判断4：入らない画面名は出さない）。
//
// オン・オフは、日本語・英語・韓国語ではアプリのほかの所（筆圧ON/OFF・
// フェードのOFF・オニオンスキンのON（固定））と同じ「ON」「OFF」、仏・西・
// 中国語は訳す。仏・西では項目の名詞の性に合わせる（傾き検知・ゴミ箱の
// 自動削除は女性名詞：「Désactivée」「Desactivada」）。スイッチ・選択肢の
// 行はキーボードのTabで1行（選択肢はひとまとまり）に1か所だけ止まり、
// 値の行はボタンとして読み上げる。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/performance_settings_screen.dart';
import 'package:niarim/screens/settings/widgets/settings_value_tile.dart';
import 'package:niarim/services/performance_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

Future<List<SingleChildWidget>> _providers(
  WidgetTester tester, {
  Map<String, Object> overrides = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    // カスタム（全部の行が出る）・この端末のおすすめは「低」。
    'quality_level': 'custom',
    'default_preset': 'low',
    'custom_saved': true,
    'custom_tilt': false,
    'custom_show_prev': true,
    'custom_show_next': true,
    // 1枚（単数形）と5枚。
    'custom_onion_prev': 1,
    'custom_onion_next': 5,
    'custom_save_mode': 'slot',
    'custom_slot_count': 5,
    // ゴミ箱の自動削除はオフ。
    'trash_auto_delete': 0,
    ...overrides,
  });
  final dir = Directory.systemTemp.createTempSync('niarim_perf_fit_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => dir.path);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return (await tester.runAsync(buildAppProviders))!;
}

/// 画面を[locale]・[size]・文字の倍率[scale]で出し、上から下まで
/// スクロールしながら、見えた段落ごとに[onParagraphs]を呼ぶ。例外は[errors]へ。
Future<void> _walk(
  WidgetTester tester,
  List<SingleChildWidget> providers,
  Locale locale,
  Size size,
  double scale,
  List<String> errors,
  void Function(List<RenderParagraph> paragraphs) onParagraphs,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final previous = FlutterError.onError;
  FlutterError.onError = (details) =>
      errors.add(details.exceptionAsString().split('\n').first);
  try {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // 本物のアプリと同じ、表示言語のテーマ（中国語は本文の書体が違う）。
            theme: context.watch<ThemeService>().themeDataFor(locale),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const PerformanceSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable.first).position;
    while (true) {
      onParagraphs(
        tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))
            .where((p) => p.attached && p.hasSize)
            .toList(),
      );
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        (position.pixels + position.viewportDimension / 2).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
    }
  } finally {
    FlutterError.onError = previous;
  }
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×320/360px×文字1.0/1.3/2.0で、はみ出さず、語の途中で折らず、'
      '文を切らない（画面名は入らなければ出さない）', (tester) async {
    await loadAppFonts(tester);
    final providers = await _providers(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in const [Size(320, 700), Size(360, 760)]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          final where =
              '${locale.toLanguageTag()} ${size.width.round()}px ×$scale';
          final errors = <String>[];
          final seen = <String>{};
          await _walk(tester, providers, locale, size, scale, errors, (ps) {
            for (final p in ps) {
              for (final problem in textFitProblems(p)) {
                final line =
                    '$where: «${p.text.toPlainText().replaceAll('⁠', '')}» '
                    '$problem';
                if (seen.add(line)) problems.add(line);
              }
            }
          });
          for (final e in errors.toSet()) {
            problems.add('$where: $e');
          }
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  });

  testWidgets('数は言語の書き方（1は単数）', (tester) async {
    await loadAppFonts(tester);
    final providers = await _providers(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final shown = <String>{};
      await _walk(
        tester,
        providers,
        locale,
        const Size(412, 900),
        1.0,
        [],
        (ps) => shown.addAll(
          ps.map((p) => p.text.toPlainText().replaceAll('⁠', '').trim()),
        ),
      );
      final tag = locale.toLanguageTag();
      for (final s in shown) {
        // 「1 images」「1 frames」「1 fotogramas」のような複数形の1。
        if (RegExp(r'^1 \S+s$').hasMatch(s) && !const {'1 fps'}.contains(s)) {
          problems.add('$tag: 「$s」が複数形');
        }
      }
      final l = lookupAppLocalizations(locale);
      for (final value in [
        l.perfSettingsOnionFrameCountValue(1),
        l.perfSettingsOnionFrameCountValue(5),
        l.perfSettingsSlotCountValue(5),
      ]) {
        if (!shown.contains(value)) problems.add('$tag: 「$value」が出ていない');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('オン・オフは、その言語のアプリのほかの所と同じ書き方で、仏・西は項目の'
      '名詞の性に合わせる（ダイアログの選択肢も）', (tester) async {
    await loadAppFonts(tester);
    // 期待する「オフ」「オン」（項目の名詞が男性・女性のとき）。日・英・韓は
    // アプリのほかの所（筆圧ON/OFF・フェードのOFF・オニオンスキンのON（固定））と
    // 同じ「ON」「OFF」、中国語は訳す。
    const expected = <String, (String, String, String, String)>{
      // 言語: (男性のオフ, 女性のオフ, 男性のオン, 女性のオン)
      'ja': ('OFF', 'OFF', 'ON', 'ON'),
      'en': ('OFF', 'OFF', 'ON', 'ON'),
      'ko': ('OFF', 'OFF', 'ON', 'ON'),
      'es': ('Desactivado', 'Desactivada', 'Activado', 'Activada'),
      'fr': ('Désactivé', 'Désactivée', 'Activé', 'Activée'),
      'zh': ('关闭', '关闭', '开启', '开启'),
      'zh-Hant': ('關閉', '關閉', '開啟', '開啟'),
    };
    final problems = <String>[];
    for (final tilt in [false, true]) {
      final providers = await _providers(
        tester,
        overrides: {'custom_show_prev': false, 'custom_tilt': tilt},
      );
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        final (offM, offF, _, onF) = expected[tag]!;
        await _walk(
          tester,
          providers,
          locale,
          const Size(412, 1600),
          1.0,
          [],
          (_) {},
        );
        final l = lookupAppLocalizations(locale);
        // 項目名の文（韓国語は語結合子を挟んで描く。読み上げは元の文）。
        Finder labelText(String label) => find.byWidgetPredicate(
          (w) =>
              w is Text &&
              ((w.data ?? '').replaceAll('⁠', '') == label ||
                  w.semanticsLabel == label),
        );
        void expectValue(String label, String value) {
          final row = find.ancestor(
            of: labelText(label),
            matching: find.byType(ActionBesideOrBelow),
          );
          final texts = row.evaluate().isEmpty
              ? const <String>[]
              : tester
                    .widgetList<Text>(
                      find.descendant(
                        of: row.first,
                        matching: find.bySubtype<Text>(),
                      ),
                    )
                    .map((t) => (t.data ?? '').replaceAll('⁠', ''))
                    .toList();
          if (!texts.contains(value)) {
            problems.add('$tag 傾き$tilt «$label»：「$value」でなく $texts');
          }
        }

        expectValue(l.perfSettingsTiltLabel, tilt ? onF : offF);
        expectValue(l.perfSettingsTrashAutoDeleteTitle, offF);
        expectValue(l.perfSettingsOnionPrevLabel, offM);
        if (tilt) continue;
        // フェード（男性名詞）の「オフ」はオニオンスキンの「オフ」と同じ語。
        if (l.brushSettingsFadeOff != offM) {
          problems.add('$tag フェードのオフ「${l.brushSettingsFadeOff}」≠「$offM」');
        }
        // ゴミ箱の自動削除のダイアログの選択肢。
        await tester.tap(labelText(l.perfSettingsTrashAutoDeleteTitle));
        await tester.pumpAndSettle();
        final options = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.bySubtype<Text>(),
              ),
            )
            .map((t) => t.data)
            .toList();
        if (!options.contains(offF)) {
          problems.add('$tag ゴミ箱の自動削除のダイアログ：「$offF」でなく $options');
        }
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('キーボードのTabはスイッチの行に1か所・選択肢のまとまりに1か所だけ止まり、'
      '矢印で選び直せる。値の行はボタンとして読み上げる', (tester) async {
    final providers = await _providers(
      tester,
      overrides: {'custom_show_prev': false, 'custom_show_next': false},
    );
    await _walk(
      tester,
      providers,
      const Locale('en'),
      const Size(412, 3000),
      1.0,
      [],
      (_) {},
    );
    final l = lookupAppLocalizations(const Locale('en'));
    // 止まった所を、それを含む行（スイッチ・選択肢・値の行）の名前で書く。
    String rowOf(FocusNode node) {
      var row = 'other';
      (node.context as Element?)?.visitAncestorElements((a) {
        final type = a.widget.runtimeType.toString();
        if (a.widget case final SettingsValueTile tile) {
          row = 'SettingsValueTile ${tile.title}';
          return false;
        }
        if (type == '_SwitchRow') {
          row = '$type ${(a.widget as dynamic).title}';
          return false;
        }
        if (type.startsWith('_RadioRow<')) {
          row = type;
          return false;
        }
        return true;
      });
      return row;
    }

    final cycle = <FocusNode>[];
    for (var i = 0; i < 80; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final node = FocusManager.instance.primaryFocus!;
      if (cycle.contains(node)) break;
      cycle.add(node);
    }
    final stops = <String, int>{};
    for (final node in cycle) {
      stops.update(rowOf(node), (n) => n + 1, ifAbsent: () => 1);
    }
    final problems = <String>[
      for (final row in [
        '_SwitchRow ${l.perfSettingsTiltSwitchTitle}',
        '_SwitchRow ${l.perfSettingsShowPrevOnionTitle}',
        '_SwitchRow ${l.perfSettingsShowNextOnionTitle}',
        '_RadioRow<QualityLevel>',
        '_RadioRow<SaveMode>',
        'SettingsValueTile ${l.perfSettingsUndoLimitTitle}',
        'SettingsValueTile ${l.perfSettingsTrashAutoDeleteTitle}',
      ])
        if (stops[row] != 1) '«$row»で${stops[row] ?? 0}か所止まる',
    ];

    // 保存方式のまとまりに止まったら、下の矢印で次の選択肢（ツリー）を選ぶ。
    final saveMode = cycle.firstWhere(
      (node) => rowOf(node) == '_RadioRow<SaveMode>',
      orElse: () => cycle.first,
    );
    saveMode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final perf = tester
        .element(find.byType(PerformanceSettingsScreen))
        .read<PerformanceService>();
    if (perf.saveMode != SaveMode.tree) {
      problems.add('保存方式のまとまりで下の矢印を押しても選び直されない（${perf.saveMode}）');
    }

    final handle = tester.ensureSemantics();
    for (final title in [
      l.perfSettingsUndoLimitTitle,
      l.perfSettingsTrashAutoDeleteTitle,
    ]) {
      final data = tester
          .getSemantics(find.text(title, findRichText: true).first)
          .getSemanticsData();
      if (!data.flagsCollection.isButton) {
        problems.add('«$title»の行がボタンとして読み上げられない');
      }
    }
    handle.dispose();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('品質の4つの選択肢は、丸を名前の横か上のどちらかにそろえる。'
      '中国語は字の間で折り返せるので、ほかの言語と同じ幅で横に置く', (tester) async {
    await loadAppFonts(tester);
    final providers = await _providers(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final (size, scale, beside) in const [
        (Size(360, 760), 1.0, true),
        (Size(412, 900), 1.3, true),
        (Size(1280, 800), 1.0, true),
        (Size(1280, 800), 2.0, true),
        (Size(320, 700), 2.0, null),
        (Size(360, 760), 2.0, null),
      ]) {
        final where =
            '${locale.toLanguageTag()} ${size.width.round()}px ×$scale';
        await _walk(tester, providers, locale, size, scale, [], (_) {});
        // 選択肢は画面の一番上にある。
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final placements = <String, bool>{};
        for (final level in QualityLevel.values) {
          final name = switch (level) {
            QualityLevel.low => l.perfSettingsQualityLow,
            QualityLevel.medium => l.perfSettingsQualityMedium,
            QualityLevel.high => l.perfSettingsQualityHigh,
            QualityLevel.custom => l.perfSettingsQualityCustom,
          };
          final radio = find.byWidgetPredicate(
            (w) => w is Radio<QualityLevel> && w.value == level,
            skipOffstage: false,
          );
          final title = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.semanticsLabel == name ||
                    (w.data ?? '').replaceAll('⁠', '') == name),
            skipOffstage: false,
          );
          if (radio.evaluate().isEmpty || title.evaluate().isEmpty) {
            problems.add('$where «$name»: 行が見つからない');
            continue;
          }
          final r = tester.getRect(radio.first);
          final t = tester.getRect(title.first);
          // 横：丸が名前の前（左）で、縦に重なる。上：丸が名前より上。
          placements[name] = r.right <= t.left + 0.5 && r.bottom > t.top;
        }
        if (placements.values.toSet().length > 1) {
          problems.add('$where: 行によって丸の置き場所が違う $placements');
        } else if (beside != null &&
            placements.isNotEmpty &&
            placements.values.first != beside) {
          problems.add(
            '$where: 丸が名前の${placements.values.first ? '横' : '上'}'
            '（${beside ? '横' : '上'}のはず）',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
