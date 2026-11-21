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
  ).first;

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
    ).first;
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
    ).first;
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
        final captures = tipCapturePages(topic, l10n);
        expect(captures, isNotEmpty, reason: topic.name);
        for (final capture in captures) {
          expect(assets, contains(capture.asset));
          expect(capture.size.isEmpty, isFalse);
          for (final focus in capture.focus) {
            expect(focus.isEmpty, isFalse);
            expect(image.intersect(focus), focus, reason: capture.asset);
          }
        }
      }
    },
  );

  testWidgets('arrow keys and swipes advance the complete image-and-text page', (
    tester,
  ) async {
    await mount(tester, const Size(1280, 800));
    await open(tester, l10n.tipsClipDuplicateTitle);

    Finder page(String topic, int index) =>
        find.byKey(ValueKey('tip-page-$topic-$index'));
    Finder viewer(String topic, int index) => find.descendant(
      of: page(topic, index),
      matching: find.byType(TipScreenCaptures),
    );
    String description(String topic, int index) => tester
        .widget<Text>(
          find.descendant(
            of: page(topic, index),
            matching: find.byKey(const ValueKey('tipPageDescription')),
          ),
        )
        .data!;

    final firstAsset = tester
        .widget<TipScreenCaptures>(viewer('clipDuplicate', 0))
        .frames
        .single
        .asset;
    final firstText = description('clipDuplicate', 0);
    expect(firstAsset, endsWith('video-open.webp'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final secondAsset = tester
        .widget<TipScreenCaptures>(viewer('clipDuplicate', 1))
        .frames
        .single
        .asset;
    final secondText = description('clipDuplicate', 1);
    expect(secondAsset, endsWith('video-duplicate-control.webp'));
    expect(secondText, isNot(firstText));

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();
    final thirdAsset = tester
        .widget<TipScreenCaptures>(viewer('clipDuplicate', 2))
        .frames
        .single
        .asset;
    final thirdText = description('clipDuplicate', 2);
    expect(thirdAsset, endsWith('video-duplicated.webp'));
    expect(thirdText, isNot(secondText));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TipScreenCaptures>(viewer('clipDuplicate', 1)).frames.single.asset,
      endsWith('video-duplicate-control.webp'),
    );

    await close(tester);
    await open(tester, l10n.tipsAutofillManualPartColorTitle);
    expect(
      tester
          .widget<TipScreenCaptures>(viewer('autofillManualPartColor', 0))
          .frames
          .single
          .asset,
      endsWith('normal-layer-above.webp'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TipScreenCaptures>(viewer('autofillManualPartColor', 1))
          .frames
          .single
          .asset,
      endsWith('autofill-lineart-menu.webp'),
    );
    expect(
      description('autofillManualPartColor', 1),
      contains('自動塗り用線画レイヤー'),
    );
  });

  testWidgets('save captures and their explanations turn as one page', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    await open(tester, l10n.tipsSaveSlotAutoSaveTitle);

    const expectedAssets = [
      'app_phone_manual-crop-000010062.webp',
      'app_phone_auto-crop-000010043.webp',
      'app_phone_auto_confirm-crop-05249579.webp',
      'app_phone_auto_canvas-crop-002810057.webp',
    ];
    String description(int index) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('tip-page-saveSlotAutoSave-$index')),
            matching: find.byKey(const ValueKey('tipPageDescription')),
          ),
        )
        .data!;

    String? previousText;
    for (var index = 0; index < expectedAssets.length; index++) {
      final page = find.byKey(ValueKey('tip-page-saveSlotAutoSave-$index'));
      final viewer = find.descendant(
        of: page,
        matching: find.byType(TipScreenCaptures),
      );
      expect(viewer, findsOneWidget);
      final frames = tester.widget<TipScreenCaptures>(viewer).frames;
      expect(frames, hasLength(1));
      expect(frames.single.asset, endsWith(expectedAssets[index]));
      final body = description(index);
      expect(body.trim(), isNotEmpty);
      if (previousText != null) expect(body, isNot(previousText));
      previousText = body;

      final viewport = find.descendant(
        of: viewer,
        matching: find.byKey(const ValueKey('tipCaptureViewport')),
      );
      expect(viewport, findsOneWidget);
      final image = find.descendant(of: viewer, matching: find.byType(Image));
      expect(tester.getRect(image), tester.getRect(viewport));
      final picture = tester.widget<Image>(image);
      expect((picture.image as AssetImage).assetName, frames.single.asset);

      if (index < expectedAssets.length - 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }

    final finalPage = find.byKey(
      const ValueKey('tip-page-saveSlotAutoSave-3'),
    );
    await tester.tap(
      find.descendant(
        of: finalPage,
        matching: find.byTooltip(l10n.canvasViewZoomIn),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final zoom = find.byType(Dialog).last;
    expect(
      find.descendant(of: zoom, matching: find.text(l10n.timelinePreviewPlaceholder)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: zoom, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(finalPage, findsOneWidget);
    expect(
      find.descendant(
        of: finalPage,
        matching: find.byKey(const ValueKey('tipPageDescription')),
      ),
      findsOneWidget,
    );
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'all tips use the same illustrated detail layout at ${size.width}px',
      (tester) async {
        await loadAppFonts(tester);
        await mount(tester, size);
        (double, Rect, double, Rect)? reference;
        final entries = allTipTopicEntries(l10n);
        expect(entries, hasLength(TipTopic.values.length));
        for (final (topic, title, description) in entries) {
          await open(tester, title);
          final page = find.byKey(ValueKey('tip-page-${topic.name}-0'));
          final titleFinder = find.descendant(
            of: page,
            matching: find.text(title),
          );
          final body = find.descendant(
            of: page,
            matching: find.byKey(const ValueKey('tipPageDescription')),
          );
          final pageDiagram = find.descendant(
            of: page,
            matching: find.byType(TipDiagram),
          );
          expect(pageDiagram, findsOneWidget, reason: title);
          final figure = tester.getRect(pageDiagram);
          expect(figure.height, greaterThan(350), reason: title);
          expect(
            tester.widget<TipDiagram>(pageDiagram).steps,
            hasLength(3),
            reason: title,
          );
          expect(body, findsOneWidget, reason: title);
          final bodyText = tester.widget<Text>(body).data!.trim();
          expect(bodyText, isNotEmpty, reason: title);
          expect(description, contains(bodyText), reason: title);
          final bodyTop = tester.getTopLeft(body).dy;
          expect(bodyTop - figure.bottom, closeTo(12, .01), reason: title);
          final captureBounds = tester.getRect(
            find.descendant(
              of: pageDiagram,
              matching: find.byKey(const ValueKey('tipCaptureViewport')),
            ),
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
    'every autofill screenshot has its own explanation page and scrolls on a short screen',
    (tester) async {
      await mount(tester, const Size(320, 480), scale: 2);
      await open(tester, l10n.tipsAutofillManualPartColorTitle);
      final captures = tipCapturePages(TipTopic.autofillManualPartColor, l10n);
      final paragraphs = l10n.tipsAutofillManualPartColorDesc.split('\n');
      expect(captures, hasLength(7));
      expect(paragraphs, hasLength(captures.length));
      final next = find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('tipNextTextPage')),
      );
      for (var pageIndex = 0; pageIndex < captures.length; pageIndex++) {
        final page = find.byKey(
          ValueKey('tip-page-autofillManualPartColor-$pageIndex'),
        );
        final pageDiagram = find.descendant(
          of: page,
          matching: find.byType(TipDiagram),
        );
        expect(pageDiagram, findsOneWidget);
        final viewer = find.descendant(
          of: page,
          matching: find.byType(TipScreenCaptures),
        );
        expect(viewer, findsOneWidget);
        final frames = tester.widget<TipScreenCaptures>(viewer).frames;
        expect(frames, hasLength(1));
        expect(frames.single.asset, captures[pageIndex].asset);
        final body = find.descendant(
          of: page,
          matching: find.byKey(const ValueKey('tipPageDescription')),
        );
        expect(body, findsOneWidget);
        expect(tester.widget<Text>(body).data, paragraphs[pageIndex]);
        await tester.ensureVisible(body);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(body).dy,
          lessThan(tester.getTopLeft(next).dy),
        );
        if (pageIndex + 1 < captures.length) {
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
      }
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
