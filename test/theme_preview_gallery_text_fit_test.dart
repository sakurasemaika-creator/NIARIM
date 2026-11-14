// テーマ・外観の見本一覧の模型が、狭い幅・大きな文字・PCの窓で、文を
// 切らず・語の途中で折らず・はみ出さないことを見張る（DISC128）。
//
// 以前は、プロジェクト一覧の模型のタブが45px固定の行に名前をそのまま
// 置いて切れていた（仏「Enregis…」、西「Proyect」）。360px×文字2倍では
// 起動画面のタイル・タイムラインの行・書き出し完了の題が語の途中で折れ、
// 1280×800ではタイムラインの模型が215pxはみ出した。書き出しの模型の
// 形式の説明は見出しの書体で描かれていた。
//
// 決まり：
// - どの画面も例外（はみ出し）を出さない。
// - ラテン文字の語は、どの文でも途中で折らない。見出しの書体（くらむぼん：
//   題・ボタン・タブ・項目名）は韓国語の語も途中で折らない（本文の韓国語は
//   字の間で折り返してよい）。
// - 見出しの書体の文は「…」で切らず、箱からはみ出さない。本文の文も
//   「…」で切らず、箱からはみ出さない。見本のデータ（作品名・作者名・
//   ファイル名）だけは、本物の画面と同じく「…」で切ってよい。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

/// 見本のデータ（作品名・作者名・スタジオ名・プロジェクト名）。7言語の値。
final Set<String> _sampleNames = () {
  final out = <String>{};
  for (final file in Directory('lib/l10n').listSync()) {
    if (!file.path.endsWith('.arb')) continue;
    final json =
        jsonDecode(File(file.path).readAsStringSync()) as Map<String, dynamic>;
    for (final key in const [
      'themePreviewSampleProjectName',
      'themePreviewSampleWorkTitle1',
      'themePreviewSampleWorkTitle2',
      'themePreviewSampleWorkTitle3',
      'themePreviewSampleArtist',
      'themePreviewSampleStudio',
    ]) {
      out.add(json[key] as String);
    }
  }
  return out;
}();

/// 見本のデータ（ファイル名・作品名・作者名）で、本物の画面でも省略して
/// 出すもの。
bool _sampleData(String text) =>
    _sampleNames.contains(text) ||
    text.startsWith('sample.') ||
    text.startsWith('♪ sample') ||
    text == 'animation.mp4';

/// [p]の文が語の途中で折り返す・切れる・箱からはみ出すときの理由。
/// [data]が真なら、見本のデータ（タイムラインのクリップに出る素材の名前）
/// として、切れていても問わない。
List<String> _textProblems(RenderParagraph p, {bool data = false}) =>
    textFitProblems(
      p,
      data: data || _sampleData(p.text.toPlainText().replaceAll('\u2060', '')),
    );

/// 見本一覧を開き、下の操作の帯を隠して16画面を順に出し、[onPage]を呼ぶ
/// （文字の倍率つき）。例外（はみ出しを含む）は[problems]へ。
Future<void> _walkGallery(
  WidgetTester tester,
  Locale locale,
  Size size,
  double scale,
  List<String> problems,
  void Function(int index, String where) onPage,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  final themeService = ThemeService();
  await themeService.init();
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) =>
      errors.add(details.exceptionAsString().split('\n').first);
  try {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: themeService,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // 本物のアプリと同じ、表示言語のテーマ（中国語は本文の書体が違う）。
          theme: themeService.themeDataFor(locale),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ThemePreviewGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('themePreviewHideControls')));
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(
      find.byKey(const Key('themePreviewPager')),
    );
    for (var i = 0; i < themePreviewEntries.length; i++) {
      if (i > 0) {
        pager.controller!.jumpToPage(i);
        await tester.pumpAndSettle();
      }
      final where =
          '${locale.toLanguageTag()} ${size.width.round()}x'
          '${size.height.round()} ×$scale ${themePreviewEntries[i].id}';
      for (final e in errors) {
        problems.add('$where: $e');
      }
      errors.clear();
      onPage(i, where);
    }
  } finally {
    FlutterError.onError = previous;
  }
  themeService.dispose();
}

/// 画面に描かれた段落。本物の部品（書き出しのプリセットの選び方〔書き出しの
/// 画面と同じ部品〕のメニューの中身）は除く。
List<RenderParagraph> _paragraphs(WidgetTester tester) {
  final menus = find.byWidgetPredicate((w) => w is DropdownButton);
  final inMenus = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: menus, matching: find.byType(RichText)),
      )
      .toSet();
  return tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .where((p) => p.attached && p.hasSize && !inMenus.contains(p))
      .toList();
}

const _sizes = [
  Size(320, 672),
  Size(360, 756),
  Size(412, 866),
  Size(1280, 800),
];

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×320/360/412px・1280×800×文字1.0/1.3/2.0で、見本一覧の'
      'どの模型も、はみ出さず、文を切らず、語の途中で折らない', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in _sizes) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          await _walkGallery(tester, locale, size, scale, problems, (i, where) {
            // タイムラインのクリップに出る素材の名前（クリップの長さで
            // 切れる、本物と同じ）は、データとして切れていても問わない
            // （語の途中の折り返しは見る）。新規作成の大きさのチップは、
            // 本物と同じく「…」で切らずに全部出すので、切れていれば問う。
            final clips = tester
                .renderObjectList<RenderParagraph>(
                  find.descendant(
                    of: find.byWidgetPredicate(
                      (w) =>
                          w.key is ValueKey<String> &&
                          (w.key! as ValueKey<String>).value.startsWith(
                            'themePreviewTrackClip',
                          ),
                    ),
                    matching: find.byType(RichText),
                  ),
                )
                .toSet();
            for (final p in _paragraphs(tester)) {
              for (final problem in _textProblems(p, data: clips.contains(p))) {
                problems.add(
                  '$where: «${p.text.toPlainText().replaceAll('⁠', '')}» '
                  '$problem',
                );
              }
            }
            // プロジェクト詳細の題はプロジェクト名（画面名ではなくデータ）。
            // 本物の画面と同じく、入らなくても隠さない（切れるのは本物と同じ）。
            if (themePreviewEntries[i].id == 'detail' &&
                find
                    .descendant(
                      of: find.byType(NavigationToolbar),
                      matching: find.text(
                        lookupAppLocalizations(
                          locale,
                        ).themePreviewSampleProjectName,
                      ),
                    )
                    .evaluate()
                    .isEmpty) {
              problems.add('$where: 題のプロジェクト名が出ていない');
            }
          });
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  });

  testWidgets('プロジェクト一覧の模型のタブは本物のホームと同じ4つで、名前が'
      '全部入る幅では名前、入らなければアイコンだけ（名前は読み上げと'
      '吹き出し）', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    final seen = <bool>{};
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final names = [
        l.homeTabProjects,
        l.homeTabWorks,
        l.homeTabShared,
        l.homeTabTrash,
      ];
      for (final size in _sizes) {
        for (final scale in const [1.0, 2.0]) {
          await _walkGallery(tester, locale, size, scale, problems, (i, where) {
            if (themePreviewEntries[i].id != 'projects') return;
            final labelled = names.every(
              (n) => find
                  .descendant(
                    of: find.byKey(const Key('themePreviewHomeTabs')),
                    matching: find.text(n),
                  )
                  .evaluate()
                  .isNotEmpty,
            );
            final iconsOnly = names.every(
              (n) => find
                  .descendant(
                    of: find.byKey(const Key('themePreviewHomeTabs')),
                    matching: find.text(n),
                  )
                  .evaluate()
                  .isEmpty,
            );
            if (!labelled && !iconsOnly) {
              problems.add('$where: 名前のあるタブとないタブが混ざる');
            }
            seen.add(labelled);
            for (var t = 0; t < names.length; t++) {
              final tab = find.byKey(Key('themePreviewHomeTab$t'));
              if (tab.evaluate().isEmpty) {
                problems.add('$where: タブ$tが無い');
                continue;
              }
              final semantics = tester.widget<Semantics>(tab);
              if (semantics.properties.label != names[t]) {
                problems.add(
                  '$where: タブ$tの読み上げが「${semantics.properties.label}」',
                );
              }
              final tooltip = find.descendant(
                of: tab,
                matching: find.byType(Tooltip),
              );
              if (tooltip.evaluate().isEmpty ||
                  tester.widget<Tooltip>(tooltip.first).message != names[t]) {
                problems.add('$where: タブ$tの吹き出しが無い');
              }
            }
          });
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(seen, {true, false}, reason: '名前・アイコンだけの両方を通っていない');
  });

  testWidgets('書き出しの模型の形式の説明は本文の書体（白光明朝）、形式の名前は'
      '見出しの書体', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      await _walkGallery(tester, locale, const Size(412, 866), 1.0, problems, (
        i,
        where,
      ) {
        if (themePreviewEntries[i].id != 'export') return;
        for (final description in [
          l.exportFormatMp4Subtitle,
          l.exportFormatGifSubtitle,
          l.exportFormatWebmSubtitle,
          l.exportFormatAviSubtitle,
        ]) {
          final p = _paragraphs(
            tester,
          ).where((p) => p.text.toPlainText() == description).toList();
          if (p.isEmpty) {
            problems.add('$where: 「$description」が無い');
          } else if (p.first.text.style?.fontFamily == 'Kuramubon') {
            problems.add('$where: 「$description」が見出しの書体');
          }
        }
        for (final name in ['MP4', 'GIF', 'AVI']) {
          final p = _paragraphs(
            tester,
          ).where((p) => p.text.toPlainText() == name).toList();
          if (p.isEmpty || p.first.text.style?.fontFamily != 'Kuramubon') {
            problems.add('$where: 「$name」が見出しの書体でない');
          }
        }
      });
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
