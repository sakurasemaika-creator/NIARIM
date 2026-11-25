import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/screens/timeline/widgets/track_label.dart';
import 'package:niarim/utils/line_break.dart';

import 'helpers/load_app_fonts.dart';

/// タイムラインの行の名前（フレーム・カメラ・読み上げ・素材の種類・
/// エンドマーク・演出フィルターの種類）が、どの言語でも「…」で切れず、
/// 語の途中で折れず、2行までに入ることを見張る。
///
/// 以前は94dpの欄の1行に「…」で切っていて、読み上げの行が英語
/// 「Text to s…」・スペイン語「Texto a v…」・フランス語「Synthès…」だった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = [
    Locale('ja'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];
  final cjk = RegExp(r'[぀-ヿ㐀-鿿豈-﫿]');

  testWidgets('決まった行の名前はどの言語でも切れず、語の途中で折れない', (tester) async {
    await loadAppFonts(tester);
    for (final scale in const [1.0, 1.3]) {
      final scaler = TextScaler.linear(scale);
      for (final locale in locales) {
        final tag = '${locale.toLanguageTag()} x$scale';
        final labels = timelineFixedTrackLabels(lookupAppLocalizations(locale));
        final width = TrackLabelMetrics.columnWidth(
          locale: locale,
          textScaler: scaler,
          fixedLabels: labels,
        );
        if (scale == 1.0 && locale.languageCode == 'ja') {
          // 入る言語では今までの幅のまま。
          expect(width, TrackLabelMetrics.baseWidth, reason: tag);
        }
        expect(width, lessThanOrEqualTo(TrackLabelMetrics.maxWidth));
        for (final label in labels) {
          final text = keepKoreanWordsTogether(label);
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TrackLabelMetrics.style(locale, Colors.black),
            ),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout(maxWidth: width - TrackLabelMetrics.chrome);
          final lines = painter.computeLineMetrics();
          expect(lines.length, lessThanOrEqualTo(2), reason: '$tag 「$label」');
          for (final line in lines) {
            expect(
              line.width,
              lessThanOrEqualTo(width - TrackLabelMetrics.chrome + 0.5),
              reason: '$tag 「$label」がはみ出した',
            );
          }
          var offset = 0;
          for (var i = 0; i < lines.length - 1; i++) {
            final end = painter
                .getLineBoundary(TextPosition(offset: offset))
                .end;
            final before = text.substring(0, end).trimRight();
            final after = text.substring(end).trimLeft();
            final atSpace =
                text[end - 1].trim().isEmpty || text[end].trim().isEmpty;
            final betweenCjk =
                cjk.hasMatch(before.characters.last) ||
                cjk.hasMatch(after.characters.first);
            expect(
              atSpace || betweenCjk,
              isTrue,
              reason: '$tag 「$before｜$after」で語の途中で折れた',
            );
            offset = end;
          }
          painter.dispose();
        }
      }
    }
  });

  testWidgets('行の高さに入るだけ折り返し、入らなければ「…」', (tester) async {
    await loadAppFonts(tester);
    Future<int> linesIn(double height, String label) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: height,
                child: TrackLabel(
                  icon: Icons.record_voice_over,
                  label: label,
                  width: TrackLabelMetrics.baseWidth,
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.byWidgetPredicate((widget) => widget is Text),
      );
      return text.maxLines!;
    }

    expect(await linesIn(28, 'Text to speech'), 2);
    expect(await linesIn(32, 'Text to speech'), 2);
    expect(await linesIn(12, 'Text to speech'), 1);
    expect(tester.takeException(), isNull);
  });
}
