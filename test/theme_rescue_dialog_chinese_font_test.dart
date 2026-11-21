// 配色リセットの確認も、中国語の画面と同じ書体で描かれる。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/keep_together_text.dart';
import 'package:niarim/widgets/theme_rescue_button.dart';
import 'package:niarim/widgets/typing_dialog_inset.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// 文字も背景も同じ色＝何も読めないテーマ。
const _unreadable = AppThemePreset(
  id: 'unreadable_rescue_font',
  name: 'unreadable',
  accentColor: Color(0xFF336699),
  textColor: Color(0xFF336699),
  buttonTextColor: Color(0xFF336699),
  menuTextColor: Color(0xFF336699),
  selectionTextColor: Color(0xFF336699),
  panelBgColor: Color(0xFF336699),
  menuBgColor: Color(0xFF336699),
  selectionColor: Color(0xFF336699),
  updateMarkColor: Color(0xFF336699),
);

/// [span]（と、その中の文）の描く書体と代替の列（[inherited]は外の書式）。
void _collectFonts(InlineSpan span, TextStyle? inherited, Set<String> into) {
  final style = inherited?.merge(span.style) ?? span.style;
  if (span is TextSpan) {
    if (span.text?.isNotEmpty ?? false) {
      into.add('${style?.fontFamily} ${style?.fontFamilyFallback}');
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      _collectFonts(child, style, into);
    }
  }
}

/// ダイアログの中の文ごとの、描いた書体と代替の列。
List<String> _fontsIn(WidgetTester tester) => [
  for (final element
      in find
          .descendant(of: find.byType(Dialog), matching: find.byType(RichText))
          .evaluate())
    if ((element.renderObject! as RenderParagraph).text.style?.fontFamily !=
        'MaterialIcons')
      () {
        final paragraph = element.renderObject! as RenderParagraph;
        final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
        final fonts = <String>{};
        _collectFonts(paragraph.text, null, fonts);
        return '「${text.replaceAll('\u2060', '')}」: ${fonts.join(' + ')}';
      }(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales.where(
    (l) => l.languageCode == 'zh',
  )) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the theme rescue dialog draws with the fonts of the '
        '$tag screen', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await tester.runAsync(service.init);
      service.restoreCurrent(_unreadable);
      // その言語の画面で、標準のライトのテーマから作るテーマ（救済の配色と
      // 同じ色で、本文の書体だけ言語に合わせたもの）。
      final localeTheme = ThemeService().themeDataFor(locale);
      final rootKey = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: service,
          child: Builder(
            builder: (context) => RepaintBoundary(
              key: rootKey,
              child: MaterialApp(
                locale: locale,
                theme: context.watch<ThemeService>().themeDataFor(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        const ThemeRescueButton(),
                        // 同じ中身のダイアログを、言語のテーマで開く。
                        TextButton(
                          key: const Key('reference'),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => Theme(
                              data: localeTheme,
                              child: AlertDialog(
                                insetPadding: dialogInsetPadding(dialogContext),
                                title: messageText(l10n.themeResetConfirmTitle),
                                actions: [
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(l10n.commonCancel),
                                  ),
                                  FilledButton(
                                    onPressed: () {},
                                    child: Text(l10n.themeResetConfirmAction),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: const Text('reference'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<Uint8List> dialogPixels(String name) async {
        final surface = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first;
        final rect = tester.getRect(surface);
        late Uint8List pixels;
        await tester.runAsync(() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final all = data!.buffer.asUint8List();
          final out = BytesBuilder();
          for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
            final start = (y * image.width + rect.left.round()) * 4;
            out.add(all.sublist(start, start + rect.width.round() * 4));
          }
          pixels = out.toBytes();
          if (shots != null) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$shots/DISC231-$name-$tag.png',
            ).writeAsBytes(png!.buffer.asUint8List(), flush: true);
          }
          image.dispose();
        });
        return pixels;
      }

      await tester.tap(find.byType(ThemeRescueButton));
      await tester.pumpAndSettle();
      final rescueFonts = _fontsIn(tester);
      final rescuePixels = await dialogPixels('rescue');
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reference')));
      await tester.pumpAndSettle();
      final referenceFonts = _fontsIn(tester);
      final referencePixels = await dialogPixels('locale-theme');
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      for (final line in rescueFonts) {
        debugPrint('$tag rescue: $line');
      }
      for (final line in referenceFonts) {
        debugPrint('$tag $tag theme: $line');
      }
      var differing = 0;
      for (var i = 0; i < rescuePixels.length; i++) {
        if (rescuePixels[i] != referencePixels[i]) differing++;
      }
      debugPrint(
        '$tag: ${rescuePixels.length ~/ 4} dialog pixels, '
        '$differing channel values differ',
      );
      final rescueBody = ThemeService.rescueThemeDataFor(
        locale,
      ).textTheme.bodyMedium!;
      expect(rescueBody.fontFamily, 'NotoSerifSCSubset');
      expect(rescueFonts, isNotEmpty);
      expect(rescueFonts, referenceFonts);
      expect(rescuePixels.length, referencePixels.length);
      expect(differing, 0);
    });
  }
}
