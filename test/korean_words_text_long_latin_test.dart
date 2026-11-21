import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/korean_words_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longName = 'NIARIMSuperLongUnbrokenFolderName2026';
  const width = 96.0;

  for (final scale in const [1.0, 2.0]) {
    testWidgets(
      'long unbroken Latin folder name wraps at text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: const KoreanWordsText(
                      longName,
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
        expect(paragraph.text.semanticsLabel, longName);
        expect(paragraph.computeLineMetrics().length, greaterThan(1));
        expect(paragraph.size.width, lessThanOrEqualTo(width + 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short Latin folder names keep their original text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: width,
          child: const KoreanWordsText(
            'My Folder',
            breakLongLatinWords: true,
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.text.toPlainText(), 'My Folder');
    expect(paragraph.text.semanticsLabel, isNull);
  });
}
