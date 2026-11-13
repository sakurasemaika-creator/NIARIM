// テーマ・外観の見本一覧（配色見本の模型）が、日本語以外の言語でも
// その言語で出ることを見張る（DISC106）。
//
// 以前は見本の文が「日本語か、それ以外は英語」の手書きの表で、韓国語・
// 繁体字・仏語等でも模型が全部英語だった。見本の文はARBから引き、本物の
// 画面と同じものは同じキーを使う。
//
// 判定：ある言語の見本に出る文字列のうち、英語または日本語の見本と同じ
// 文字列で、しかもその言語のARBの値でないものは「訳されていない」。
// （ARBの値と同じなら、その言語でも英語・日本語と同じ綴りの語〔仏語の
// 「Image」等〕なので許す。）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';

/// 文字（ラテン文字・かな・漢字・ハングル）を含むか（×・÷は記号）。
final RegExp _letters = RegExp(
  r'[A-Za-zÀ-ÖØ-öø-ÿ\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]',
);

/// どの言語でも同じに書く固有名詞・形式名と、本物の画面がどの言語でも同じに
/// 出すもの（見本はそれに合わせる）。
const Set<String> _sameInEveryLanguage = {
  'NIARIM', 'MP4', 'GIF', 'AVI', 'FPS',
  // 見本の素材のファイル名。
  'sample.png', 'sample.mp4', '♪ sample.wav',
  // 本物のシーンの既定の名前（Scene.displayName）。
  'Scene1',
};

/// 数と単位の記号だけのもの（本物の画面の表記：再生位置の「0.1s」、作品広場の
/// 「2400f」「24fps」「6h 40m」、容量の「0B」）。
final RegExp _numberWithUnit = RegExp(r'^\d+(\.\d+)?(s|f|fps|B)$|^\d+h \d+m$');

Set<String> _arbValues(String locale) {
  final json =
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      if (!key.startsWith('@') && value is String) value,
  };
}

/// 今の画面に出ている文字列（文・吹き出し・読み上げの名前）。
Set<String> _visibleStrings(WidgetTester tester) {
  final out = <String>{};
  void add(String? s) {
    if (s == null) return;
    final t = s.trim();
    if (t.isNotEmpty) out.add(t);
  }

  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      add(widget.data ?? widget.textSpan?.toPlainText());
    } else if (widget is RichText) {
      add(widget.text.toPlainText());
    } else if (widget is Tooltip) {
      add(widget.message ?? widget.richMessage?.toPlainText());
    } else if (widget is IconButton) {
      add(widget.tooltip);
    } else if (widget is Semantics) {
      add(widget.properties.label);
    }
  }
  return out;
}

Future<Map<String, Set<String>>> _galleryStrings(
  WidgetTester tester,
  Locale locale, {
  Size size = const Size(412, 900),
  bool checkLayout = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  final themeService = ThemeService();
  await themeService.init();
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final pages = <String, Set<String>>{};
  for (var i = 0; i < themePreviewEntries.length; i++) {
    if (i > 0) {
      await tester.tap(find.byKey(const Key('themePreviewNext')));
      await tester.pumpAndSettle();
    }
    final error = tester.takeException();
    if (checkLayout) {
      expect(
        error,
        isNull,
        reason: '$locale ${size.width}px: ${themePreviewEntries[i].id}',
      );
    }
    pages[themePreviewEntries[i].id] = _visibleStrings(tester);
  }
  // 縮小見本（テーマ・外観の画面に出るもの）の読み上げの名前も見る。
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const Scaffold(body: Center(child: ThemePreviewThumbnail())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (checkLayout) expect(tester.takeException(), isNull);
  tester.takeException();
  pages['thumbnail'] = _visibleStrings(tester);
  return pages;
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('見本一覧は日本語以外の言語でもその言語で出る（英語・日本語の'
      '書き残しが無い）', (tester) async {
    // はみ出しは別のテストで見る。ここでは文だけを比べる。
    final en = await _galleryStrings(
      tester,
      const Locale('en'),
      checkLayout: false,
    );
    final ja = await _galleryStrings(
      tester,
      const Locale('ja'),
      checkLayout: false,
    );
    final offenders = <String>[];
    for (final locale in const [
      Locale('ko'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('fr'),
      Locale('es'),
      Locale('zh'),
    ]) {
      final tag = locale.scriptCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.scriptCode}';
      final arb = _arbValues(tag);
      final pages = await _galleryStrings(tester, locale, checkLayout: false);
      for (final MapEntry(key: page, value: strings) in pages.entries) {
        for (final s in strings) {
          if (!_letters.hasMatch(s)) continue;
          // 1字だけのもの（アイコンの丸に入れる名前の頭文字）は、その言語の
          // 名前から取った字なので文ではない。
          if (s.characters.length < 2) continue;
          if (_sameInEveryLanguage.contains(s)) continue;
          if (_numberWithUnit.hasMatch(s)) continue;
          if (arb.contains(s)) continue;
          final leftover =
              (en[page]?.contains(s) ?? false) ||
              (ja[page]?.contains(s) ?? false);
          if (leftover) offenders.add('$tag $page: $s');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '見本の文が訳されていない（${offenders.length}件）:\n'
          '${offenders.join('\n')}',
    );
  });

  testWidgets('見本の作品名は検査用の名前（all-route-audit）ではなく、その言語の'
      '自然な名前', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final pages = await _galleryStrings(tester, locale, checkLayout: false);
      final all = pages.values.expand((s) => s).toSet();
      expect(
        all.where((s) => s.contains('all-route-audit')),
        isEmpty,
        reason: '$locale',
      );
    }
  });

  testWidgets('7言語・320pxと412pxで見本一覧のどの画面も例外・はみ出しを'
      '出さない', (tester) async {
    // 実際の字の幅で測る（テスト用の四角い字は欧文が実際の倍ほど広い）。
    await loadAppFonts(tester);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in const [Size(320, 720), Size(412, 900)]) {
        // _galleryStrings が各画面で takeException を確かめる。
        await _galleryStrings(tester, locale, size: size);
      }
    }
  });

  _testsForWidthsAndScales();
}

/// 見本一覧を開き、16画面を順に出して[onPage]を呼ぶ（文字の倍率つき）。
/// 例外（はみ出しを含む）は[problems]へ。
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
          theme: themeService.themeData,
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
    for (var i = 0; i < themePreviewEntries.length; i++) {
      if (i > 0) {
        await tester.tap(find.byKey(const Key('themePreviewNext')));
        await tester.pumpAndSettle();
      }
      final where =
          '${locale.toLanguageTag()} ${size.width.round()}px ×$scale '
          '${themePreviewEntries[i].id}';
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

/// 語を空白で区切る文字（ラテン文字・ハングル）。
final RegExp _wordLetter = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿœŒ가-힯]');

/// [p]の文が、語（空白で区切られた単位）の途中で折り返されているか。
bool _breaksInsideWord(RenderParagraph p) {
  final text = p.text.toPlainText();
  final painter = TextPainter(
    text: p.text,
    textDirection: TextDirection.ltr,
    textScaler: p.textScaler,
    maxLines: p.maxLines,
  )..layout(maxWidth: p.constraints.maxWidth);
  var broken = false;
  final lines = painter.computeLineMetrics();
  for (var i = 0; i < lines.length - 1; i++) {
    final end = painter
        .getLineBoundary(
          painter.getPositionForOffset(
            Offset(0, lines[i].baseline - lines[i].ascent + 1),
          ),
        )
        .end;
    String around(int from, int step) {
      for (var k = from; k >= 0 && k < text.length; k += step) {
        if (text[k] != '⁠') return text[k];
      }
      return '';
    }

    if (_wordLetter.hasMatch(around(end - 1, -1)) &&
        _wordLetter.hasMatch(around(end, 1))) {
      broken = true;
    }
  }
  painter.dispose();
  return broken;
}

/// 画面に描かれた段落（画面の外・隠れた形は除く）。
List<RenderParagraph> _paragraphs(WidgetTester tester) => tester
    .renderObjectList<RenderParagraph>(find.byType(RichText))
    .where((p) => p.attached && p.hasSize)
    .toList();

void _testsForWidthsAndScales() {
  testWidgets('7言語×320/360/412px×文字1.0/1.3/2.0で、見本一覧のどの画面も'
      '例外・はみ出しを出さず、画面名を「…」で切らず（入らなければ出さず、'
      '番号の吹き出しと読み上げに名前）、作品広場の見出しも切れない', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    var hidden = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final width in const [320.0, 360.0, 412.0]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          await _walkGallery(
            tester,
            locale,
            Size(width, width * 2.1),
            scale,
            problems,
            (i, where) {
              final entry = themePreviewEntries[i];
              final names = {entry.label(l), ?entry.shortLabel(l)};
              final title = find.byKey(const Key('themePreviewTitle'));
              if (title.evaluate().isEmpty) {
                hidden++;
                final position = tester.widget<Tooltip>(
                  find.byKey(const Key('themePreviewPosition')),
                );
                if (position.message != entry.label(l)) {
                  problems.add(
                    '$where: 名前を出さないときの番号の吹き出しが'
                    '「${position.message}」',
                  );
                }
              } else {
                final p = tester.renderObject<RenderParagraph>(
                  find.descendant(of: title, matching: find.byType(RichText)),
                );
                final shown = p.text.toPlainText().replaceAll('⁠', '');
                if (!names.contains(shown)) {
                  problems.add('$where: 画面名が「$shown」');
                }
                if (p.didExceedMaxLines) {
                  problems.add('$where: 画面名「$shown」が切れている');
                }
                if (_breaksInsideWord(p)) {
                  problems.add('$where: 画面名「$shown」が語の途中で折り返す');
                }
              }
              // 本物の画面と同じく、見出しは何行になっても切らない。
              if (entry.id == 'community') {
                final heading = _paragraphs(tester).where(
                  (p) =>
                      p.text.toPlainText().replaceAll('⁠', '') ==
                      l.communityScreenTitle,
                );
                if (heading.isEmpty) {
                  problems.add('$where: 作品広場の見出しが無い');
                }
                for (final p in heading) {
                  if (p.didExceedMaxLines || p.debugHasOverflowShader) {
                    problems.add('$where: 作品広場の見出しが切れている');
                  }
                  final painter = TextPainter(
                    text: p.text,
                    textDirection: TextDirection.ltr,
                    textScaler: p.textScaler,
                    maxLines: p.maxLines,
                  )..layout(maxWidth: p.constraints.maxWidth);
                  if (painter.height > p.size.height + 0.5 ||
                      p.size.height > p.constraints.maxHeight + 0.5) {
                    problems.add('$where: 作品広場の見出しが箱に入らない');
                  }
                  painter.dispose();
                  if (_breaksInsideWord(p)) {
                    problems.add('$where: 作品広場の見出しが語の途中で折り返す');
                  }
                }
              }
            },
          );
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
    expect(hidden, greaterThan(0), reason: '狭い所で名前を出さない場合を通っていない');
  });

  testWidgets('見出し（くらむぼん）の字は見出し用の代替（ゴシック）で描き、'
      '本文の明朝へ落とさない（韓国語・中国語の1語の中で太さが混ざらない）', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      await _walkGallery(tester, locale, const Size(412, 900), 1.0, problems, (
        i,
        where,
      ) {
        for (final p in _paragraphs(tester)) {
          void visit(InlineSpan span, TextStyle? inherited) {
            final style = inherited?.merge(span.style) ?? span.style;
            if (span is TextSpan &&
                span.text != null &&
                span.text!.trim().isNotEmpty &&
                style?.fontFamily == 'Kuramubon' &&
                !listEquals(style?.fontFamilyFallback, kHeadingFontFallback)) {
              problems.add(
                '$where: «${span.text}» の代替 '
                '${style?.fontFamilyFallback}',
              );
            }
            if (span is TextSpan) {
              for (final child in span.children ?? const <InlineSpan>[]) {
                visit(child, style);
              }
            }
          }

          visit(p.text, null);
        }
      });
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(problems, isEmpty, reason: problems.toSet().join('\n'));
  });
}
