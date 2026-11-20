import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tip_capture_data.dart';
import 'package:niarim/screens/tips/tip_diagram.dart';
import 'package:niarim/screens/tips/tip_diagram_data.dart';
import 'package:niarim/screens/tips/tip_screen_capture.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

void main() {
  const japanese = Locale('ja');
  final l10n = lookupAppLocalizations(japanese);
  final dialog = find.byType(Dialog);
  final diagram = find.descendant(
    of: dialog,
    matching: find.byType(TipDiagram),
  );

  Future<void> mount(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    Locale locale = japanese,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeService().themeDataFor(locale),
        home: const TipsScreen(),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextField), title);
    await tester.pumpAndSettle();
    final tile = find
        .descendant(of: find.byType(ListView), matching: find.text(title))
        .first;
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: dialog, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the final Japanese word wraps as a unit', (tester) async {
    await loadAppFonts(tester);
    await mount(tester, const Size(390, 844));
    await open(tester, l10n.tipsClipDuplicateTitle);
    final title = find.descendant(
      of: dialog,
      matching: find.text(l10n.tipsClipDuplicateTitle),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title, matching: find.byType(RichText)),
    );
    expect(ParagraphLines(paragraph).lines.last, endsWith('できる'));
  });

  testWidgets('a long Tips title has room above the diagram at 200%', (
    tester,
  ) async {
    const french = Locale('fr');
    final words = lookupAppLocalizations(french);
    await loadAppFonts(tester);
    await mount(tester, const Size(320, 720), scale: 2, locale: french);
    await open(tester, words.tipsClipDuplicateTitle);
    final title = find.descendant(
      of: dialog,
      matching: find.text(words.tipsClipDuplicateTitle),
    );
    expect(tester.getRect(title).bottom, lessThan(tester.getRect(diagram).top));
    final illustration = find.descendant(
      of: diagram,
      matching: find.byType(Image),
    );
    expect(tester.getRect(illustration).width, greaterThan(112));

    // A swipe starting on the title should move the whole content.
    final before = tester.getTopLeft(diagram).dy;
    await tester.dragFrom(
      tester.getTopLeft(title) + const Offset(25, 35),
      const Offset(0, -130),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(diagram).dy, lessThan(before - 80));
  });

  test(
    'every tip page has bundled screenshots with valid annotations',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      const image = Rect.fromLTWH(0, 0, 1, 1);
      for (final topic in TipTopic.values) {
        for (
          var page = 0;
          page < (topic.illustrateByParagraph ? 4 : 1);
          page++
        ) {
          final captures = tipCaptures(topic, page, l10n);
          expect(captures, isNotEmpty, reason: '$topic page ${page + 1}');
          for (final capture in captures) {
            expect(assets, contains(capture.asset));
            expect(capture.size.isEmpty, isFalse);
            for (final focus in capture.focus) {
              expect(focus.isEmpty, isFalse);
              expect(image.intersect(focus), focus, reason: capture.asset);
            }
          }
        }
      }
    },
  );

  testWidgets('save captures follow the workflow and open full-screen', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    await open(tester, l10n.tipsSaveSlotAutoSaveTitle);
    final viewer = find.byType(TipScreenCaptures);
    final frames = tester.widget<TipScreenCaptures>(viewer).frames;
    expect(frames.map((frame) => frame.label), [
      l10n.saveDataManualTab,
      l10n.helpAutoSaveTitle,
      l10n.saveTreeRestoreAction,
      l10n.timelinePreviewPlaceholder,
    ]);
    final next = find.byKey(const ValueKey('tipNextCapture'));
    final previous = find.byKey(const ValueKey('tipPreviousCapture'));
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    final viewport = find.byKey(const ValueKey('tipCaptureViewport'));
    final imageRect = tester.getRect(viewport);
    for (final (index, frame) in frames.indexed) {
      expect(
        find.descendant(of: viewer, matching: find.text(frame.label)),
        findsOneWidget,
      );
      final image = find.descendant(of: viewer, matching: find.byType(Image));
      expect(tester.getRect(viewport), imageRect);
      expect(tester.getRect(image), imageRect);
      final picture = tester.widget<Image>(image);
      expect((picture.image as AssetImage).assetName, frame.asset);
      if (index < frames.length - 1) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
    }
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(find.byTooltip(l10n.canvasViewZoomIn));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final zoom = find.byType(Dialog).last;
    expect(
      find.descendant(of: zoom, matching: find.text(frames.last.label)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: zoom, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(viewer, findsOneWidget);
    expect(find.text(frames.last.label), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'all tips use the same illustrated detail layout at ${size.width}px',
      (tester) async {
        await loadAppFonts(tester);
        await mount(tester, size);
        (double, Rect, double, Rect)? reference;
        final entries = allTipEntries(l10n);
        expect(entries, hasLength(TipTopic.values.length));
        for (final (title, description) in entries) {
          await open(tester, title);
          final titleFinder = find.descendant(
            of: dialog,
            matching: find.text(title),
          );
          final body = find.descendant(
            of: dialog,
            matching: find.text(description.split('\n').first),
          );
          expect(diagram, findsOneWidget, reason: title);
          final figure = tester.getRect(diagram);
          expect(figure.height, greaterThan(350), reason: title);
          expect(
            tester.widget<TipDiagram>(diagram).steps,
            hasLength(3),
            reason: title,
          );

          // Multi-page tips put the first translated paragraph below this figure.
          // Single-page tips can keep multiple paragraphs together.
          final visibleBody = body.evaluate().isEmpty
              ? find.descendant(of: dialog, matching: find.text(description))
              : body;
          expect(visibleBody, findsOneWidget, reason: title);
          final bodyTop = tester.getTopLeft(visibleBody).dy;
          expect(bodyTop - figure.bottom, closeTo(12, .01), reason: title);
          final captureBounds = tester.getRect(
            find.byKey(const ValueKey('tipCaptureViewport')),
          );
          final layout = (
            tester.getTopLeft(titleFinder).dy,
            figure,
            bodyTop,
            captureBounds,
          );
          if (reference == null) {
            reference = layout;
          } else {
            expect(layout, reference, reason: title);
          }
          await close(tester);
        }
      },
    );
  }

  testWidgets(
    'translated diagram labels fit a narrow screen at large text size',
    (tester) async {
      const width = 264.0; // Dialog content at a 320dp screen width.
      const height = 470.0;
      final overflowing = <String>{};
      await loadAppFonts(tester);
      for (final locale in AppLocalizations.supportedLocales) {
        final words = lookupAppLocalizations(locale);
        final theme = ThemeService().themeDataFor(locale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final topic in TipTopic.values)
                        for (
                          var page = 0;
                          page < (topic.illustrateByParagraph ? 4 : 1);
                          page++
                        )
                          SizedBox(
                            width: width,
                            child: TipDiagram(
                              steps: topic.steps(words, page),
                              height: height,
                              isComparison: topic.isComparison,
                              captures: tipCaptures(topic, page, words),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
        final diagrams = find.byType(TipDiagram, skipOffstage: false);
        expect(diagrams, findsNWidgets(TipTopic.values.length + 3));
        for (final element in diagrams.evaluate()) {
          final paragraphs = <RenderParagraph>[];
          void collect(Element child) {
            final render = child is RenderObjectElement
                ? child.renderObject
                : null;
            if (render is RenderParagraph) paragraphs.add(render);
            child.visitChildren(collect);
          }

          element.visitChildren(collect);
          for (final paragraph in paragraphs.toSet()) {
            final painter = TextPainter(
              text: paragraph.text,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
            )..layout(maxWidth: paragraph.constraints.maxWidth);
            if (painter.height > paragraph.size.height + .1) {
              overflowing.add(
                '${locale.toLanguageTag()}: ${paragraph.text.toPlainText()}'
                ' (${painter.height} > ${paragraph.size.height})',
              );
            }
            painter.dispose();
          }
        }
      }
      expect(overflowing, isEmpty);
    },
  );

  testWidgets(
    'every autofill page has a diagram and the body scrolls on a short screen',
    (tester) async {
      await mount(tester, const Size(320, 480), scale: 2);
      await open(tester, l10n.tipsAutofillManualPartColorTitle);
      final next = find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('tipNextTextPage')),
      );
      final paragraphs = l10n.tipsAutofillManualPartColorDesc.split('\n');
      expect(paragraphs, hasLength(4));
      for (var page = 0; page < paragraphs.length; page++) {
        final steps = tester.widget<TipDiagram>(diagram).steps;
        expect(steps, TipTopic.autofillManualPartColor.steps(l10n, page));
        final body = find.text(paragraphs[page]);
        expect(body, findsOneWidget);
        await tester.ensureVisible(body);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(body).dy,
          lessThan(tester.getTopLeft(next).dy),
        );
        if (page + 1 < paragraphs.length) {
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
