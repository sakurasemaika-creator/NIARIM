import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tip_capture_data.dart';
import 'package:niarim/screens/tips/tip_diagram_data.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/screens/tips/tip_screen_capture.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  const japanese = Locale('ja');
  final l10n = lookupAppLocalizations(japanese);
  final dialog = find.byType(Dialog);

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
    await tester.pumpWidget(
      MaterialApp(
        locale: japanese,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeService().themeDataFor(japanese),
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

  Future<void> capture(
    WidgetTester tester, {
    required String topic,
    required String fileName,
  }) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(ValueKey('tip-detail-capture-$topic')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode $fileName');
    final file = File('build/feature-captures/tips/$fileName.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    image.dispose();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), '');

  Future<void> captureTopicPages(
    WidgetTester tester, {
    required TipTopic topic,
    required String title,
    required String description,
    required List<TipScreenCapture> pages,
  }) async {
    final topicKey = topic.name;
    await open(tester, title);
    final pageTexts = <String>[];
    for (var index = 0; index < pages.length; index++) {
      await tester.pumpAndSettle();
      final page = find.byKey(ValueKey('tip-page-$topicKey-$index'));
      expect(page, findsOneWidget, reason: '$topicKey page $index');

      final viewer = find.descendant(
        of: page,
        matching: find.byType(TipScreenCaptures),
      );
      expect(viewer, findsOneWidget, reason: '$topicKey page $index');
      final frames = tester.widget<TipScreenCaptures>(viewer).frames;
      expect(frames, hasLength(1), reason: '$topicKey page $index');
      expect(
        frames.single.asset,
        pages[index].asset,
        reason: '$topicKey page $index must show its own capture',
      );

      final body = find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('tipPageDescription')),
      );
      expect(body, findsOneWidget, reason: '$topicKey page $index');
      final pageText = tester.widget<Text>(body).data ?? '';
      expect(pageText.trim(), isNotEmpty, reason: '$topicKey page $index');
      pageTexts.add(pageText);

      final pageNumber = (index + 1).toString().padLeft(2, '0');
      await capture(
        tester,
        topic: topicKey,
        fileName: '$topicKey-page-$pageNumber',
      );
      if (index + 1 < pages.length) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }

    // Preserve the complete explanation while giving each screenshot its own
    // relevant text segment. Paragraph separators are intentionally removed
    // when paragraphs become individual swipe pages.
    expect(
      compact(pageTexts.join()),
      compact(description),
      reason: '$topicKey must not lose or duplicate explanation text',
    );
    await close(tester);
  }

  testWidgets('captures every Tips screenshot with its matching text page', (
    tester,
  ) async {
    await mount(tester);
    final entries = allTipTopicEntries(l10n);
    var capturedPages = 0;
    for (final (topic, title, description) in entries) {
      final pages = tipCapturePages(topic, l10n);
      if (pages.isEmpty) continue;
      await captureTopicPages(
        tester,
        topic: topic,
        title: title,
        description: description,
        pages: pages,
      );
      capturedPages += pages.length;
    }
    expect(capturedPages, greaterThan(100));
    expect(tester.takeException(), isNull);
  });
}
