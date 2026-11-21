import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
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

  Future<void> capturePages(
    WidgetTester tester, {
    required String topic,
    required String title,
    required int pageCount,
    required String filePrefix,
  }) async {
    await open(tester, title);
    for (var page = 0; page < pageCount; page++) {
      await capture(
        tester,
        topic: topic,
        fileName: '$filePrefix-page-${(page + 1).toString().padLeft(2, '0')}',
      );
      if (page + 1 < pageCount) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }
    await close(tester);
  }

  testWidgets('captures the synchronized Tips page layouts for visual review', (
    tester,
  ) async {
    await mount(tester);
    await capturePages(
      tester,
      topic: 'saveSlotAutoSave',
      title: l10n.tipsSaveSlotAutoSaveTitle,
      pageCount: 4,
      filePrefix: 'save-slot',
    );
    await capturePages(
      tester,
      topic: 'clipDuplicate',
      title: l10n.tipsClipDuplicateTitle,
      pageCount: 3,
      filePrefix: 'clip-duplicate',
    );
    await capturePages(
      tester,
      topic: 'autofillManualPartColor',
      title: l10n.tipsAutofillManualPartColorTitle,
      pageCount: 7,
      filePrefix: 'autofill-manual-color',
    );
    expect(tester.takeException(), isNull);
  });
}
