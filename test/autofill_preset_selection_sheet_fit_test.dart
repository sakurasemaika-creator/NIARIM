// 「使う自動塗りの設定を選ぶ」シートが、スマホの狭い幅・大きな文字でも
// はみ出さず、題を語の途中で折らず、一覧が見えて選べることを見張る。
//
// 以前は高さ480px固定のシートの見出しの1行に、題（Expanded）と「すべて選択」
// 「すべて解除」の2つの文字のボタンを並べていた。仏語360px×文字1.0で題が
// 1文字ずつ縦に並び、「BOTTOM OVERFLOWED BY 414 PIXELS」、「Tout
// désélectionner」が切れて一覧が見えなかった（英語360px×文字2倍でも659px）。
// 題は1行を使い、2つのボタンは入らなければアイコン（名前は吹き出しと
// 読み上げ）にする（判断3：字を縮めない）。横向きのスマホ（高さ320・360px）×
// 文字2倍では、見出しと説明だけで高さを使い切って一覧が見えず、はみ出した
// ので、見出し・説明・一覧を1つにスクロールする（OKは下に残す）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/autofill_preset_selection_sheet.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×320/360/412/1280px・横向き640×320/740×360×文字1.0/2.0で、'
      'はみ出さず、題を語の途中で折らず、一覧と「すべて選択」「すべて解除」に届く', (tester) async {
    await loadAppFonts(tester);
    final presets = [
      for (var i = 1; i <= 6; i++)
        AutofillPreset(id: 'p$i', name: 'Preset $i', parts: const []),
    ];
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final theme = ThemeService().themeDataFor(locale);
      for (final size in const [
        Size(320, 640),
        Size(360, 740),
        Size(412, 900),
        Size(1280, 800),
        Size(640, 320),
        Size(740, 360),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          final where =
              '${locale.toLanguageTag()} ${size.width.round()}px ×$scale';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString().split('\n').first);
          try {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => showAutofillPresetSelectionSheet(
                          context,
                          allPresets: presets,
                          initiallyEnabledIds: null,
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            final sheet = find.byType(BottomSheet);
            final sheetRect = tester.getRect(sheet);
            if (sheetRect.top < 0 || sheetRect.bottom > size.height + 0.5) {
              problems.add('$where: シートが画面からはみ出す $sheetRect');
            }
            for (final p in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: sheet, matching: find.byType(RichText)),
            )) {
              if (!p.attached || !p.hasSize) continue;
              if (p.text.style?.fontFamily == 'MaterialIcons') continue;
              for (final problem in textFitProblems(p)) {
                problems.add(
                  '$where: «${p.text.toPlainText().replaceAll('⁠', '')}» '
                  '$problem',
                );
              }
            }
            // 「すべて選択」「すべて解除」は文字か、名前を吹き出しに持つアイコン。
            for (final name in [
              l.homeSelectionAllSelect,
              l.homeSelectionAllDeselect,
            ]) {
              final asText = find.descendant(
                of: sheet,
                matching: find.text(name),
              );
              final asIcon = find.descendant(
                of: sheet,
                matching: find.byTooltip(name),
              );
              if (asText.hitTestable().evaluate().isEmpty &&
                  asIcon.hitTestable().evaluate().isEmpty) {
                problems.add('$where: «$name»に届かない');
              }
            }
            // 「すべて解除」で何も選ばれていない状態になる（ボタンが働く）。
            final deselect = [
              find.descendant(
                of: sheet,
                matching: find.text(l.homeSelectionAllDeselect),
              ),
              find.descendant(
                of: sheet,
                matching: find.byTooltip(l.homeSelectionAllDeselect),
              ),
            ].map((f) => f.hitTestable()).where((f) => f.evaluate().isNotEmpty);
            if (deselect.isNotEmpty) {
              await tester.tap(deselect.first.first);
              await tester.pump();
              final checked = tester
                  .widgetList<CheckboxListTile>(
                    find.descendant(
                      of: sheet,
                      matching: find.byType(CheckboxListTile),
                    ),
                  )
                  .where((t) => t.value ?? false);
              if (checked.isNotEmpty) {
                problems.add('$where: 「すべて解除」で外れない');
              }
            }
            // 一覧の最初の行へスクロールで届き、見えて、押せる（見出しと説明で
            // 高さを使い切る横向きでは、スクロールして届く）。「すべて解除」の
            // 後なので、外れている。
            final firstRow = find.descendant(
              of: sheet,
              matching: find.byType(CheckboxListTile),
            );
            final list = find.descendant(
              of: sheet,
              matching: find.byType(Scrollable),
            );
            final position = tester.state<ScrollableState>(list.first).position;
            while (firstRow.evaluate().isEmpty &&
                position.pixels < position.maxScrollExtent) {
              position.jumpTo(
                (position.pixels + 40).clamp(0, position.maxScrollExtent),
              );
              await tester.pump();
            }
            try {
              await tester.ensureVisible(firstRow.first);
              await tester.pumpAndSettle();
              final row = tester.getRect(firstRow.first);
              final view = tester.getRect(list.first);
              if (firstRow.first.hitTestable().evaluate().isEmpty ||
                  row.height < 40 ||
                  row.top < view.top - 0.5 ||
                  row.bottom > view.bottom + 0.5) {
                problems.add('$where: 一覧の行が見えない・押せない（$row／$view）');
              } else if (tester
                      .widget<CheckboxListTile>(firstRow.first)
                      .value ??
                  false) {
                problems.add('$where: 「すべて解除」で外れない（一覧の最初の行）');
              }
            } on StateError catch (e) {
              problems.add('$where: 一覧の行に届かない（$e）');
            }
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = previous;
          }
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
}
