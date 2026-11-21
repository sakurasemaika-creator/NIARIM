import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/korean_words_text.dart';

const _longName =
    'NIARIMÉcoleCafe\u0301AnimationStudioFolderNameWithoutSpaces'
    '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    'NIARIMAnimationStudioFolderNameWithoutSpaces';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in const [
    Locale('ja'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets(
      'long unbroken Latin folder names wrap safely (${locale.toLanguageTag()})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        for (final width in const [96.0, 180.0, 320.0]) {
          for (final scale in const [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 640);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 640),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        child: const KoreanWordsText(
                          _longName,
                          breakLongLatinWords: true,
                          keepJapaneseLineStarts: true,
                          style: TextStyle(fontSize: 16, height: 1.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            final paragraph = tester.renderObject<RenderParagraph>(
              find.byType(RichText),
            );
            final displayed = paragraph.text!.toPlainText(
              includeSemanticsLabels: false,
            );
            final where = '${locale.toLanguageTag()} ${width}px x$scale';
            expect(displayed, contains('\u200B'), reason: where);
            expect(paragraph.text!.semanticsLabel, _longName, reason: where);
            expect(
              paragraph.computeLineMetrics().length,
              greaterThan(1),
              reason: where,
            );
            expect(
              paragraph.size.width,
              lessThanOrEqualTo(width + 0.5),
              reason: where,
            );
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: displayed.length),
            );
            expect(boxes, isNotEmpty, reason: where);
            expect(
              boxes.every((box) => box.right <= paragraph.size.width + 0.5),
              isTrue,
              reason: '$where: $boxes',
            );
            expect(tester.takeException(), isNull, reason: where);
          }
        }
      },
    );
  }

  testWidgets('short Latin folder names keep their original text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          child: KoreanWordsText(
            'My Folder',
            breakLongLatinWords: true,
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(
      paragraph.text!.toPlainText(includeSemanticsLabels: false),
      'My Folder',
    );
    expect(paragraph.text!.semanticsLabel, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'DISC145 reproducer: Storyboards (2) stays within a narrow French row at 200%',
    (tester) async {
      const name = 'Storyboards (2)';
      const width = 160.0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              boldText: true,
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: const KoreanWordsText(
                  name,
                  breakLongLatinWords: true,
                  keepJapaneseLineStarts: true,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final displayed = paragraph.text!.toPlainText(
        includeSemanticsLabels: false,
      );
      expect(displayed, contains('\u200B'));
      expect(paragraph.text!.semanticsLabel, name);
      expect(paragraph.computeLineMetrics().length, greaterThan(1));
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: displayed.length),
      );
      expect(boxes, isNotEmpty);
      expect(
        boxes.every((box) => box.right <= paragraph.size.width + 0.5),
        isTrue,
      );
      expect(paragraph.size.width, lessThanOrEqualTo(width + 0.5));
      expect(tester.takeException(), isNull);
    },
  );
}
