import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/app_startup.dart';
import 'package:niarim/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const widths = [
    320,
    360,
    375,
    390,
    430,
    480,
    520,
    559,
    560,
    600,
    640,
    641,
    700,
    759,
    760,
    834,
    900,
    1024,
    1180,
    1280,
    1366,
    1440,
    1600,
    1920,
  ];
  const locales = {
    'ja': Locale('ja'),
    'en': Locale('en'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'ko': Locale('ko'),
    'fr': Locale('fr'),
    'es': Locale('es'),
  };

  testWidgets('startup recovery loading/error layout and retry matrix', (
    tester,
  ) async {
    // Render the actual bundled typography, not Flutter test's Ahem squares.
    for (final entry in {
      'HakkouMincho': 'HakkouMincho.ttf',
      'Kuramubon': 'Kuramubon.otf',
      'NotoSerifJP': 'NotoSerifJP.ttf',
      'DelaGothicOne': 'DelaGothicOne-Regular.ttf',
      'NotoSerifKRSubset': 'NotoSerifKRSubset.ttf',
      'NotoSerifSCSubset': 'NotoSerifSCSubset.ttf',
      'NotoSansKRBlackSubset': 'NotoSansKRBlackSubset.ttf',
      'NotoSansSCBlackSubset': 'NotoSansSCBlackSubset.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final out = Directory('build/audit-a001/startup-ui')
      ..createSync(recursive: true);
    final manifest = <Map<String, Object>>[];
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearLocalesTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
    });
    tester.view.devicePixelRatio = 1;
    for (final mode in ['PC', 'SP']) {
      debugDefaultTargetPlatformOverride = mode == 'PC'
          ? TargetPlatform.linux
          : TargetPlatform.android;
      for (final language in locales.entries) {
        tester.platformDispatcher.localesTestValue = [language.value];
        for (final width in widths) {
          final height = mode == 'SP' ? 844 : 900;
          tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
          for (final state in ['loading', 'error']) {
            final id = '${language.key}_${mode}_${width}_$state';
            final pending = Completer<AppServices>();
            var attempts = 0;
            await tester.pumpWidget(
              RepaintBoundary(
                key: const Key('startup-image'),
                child: AppStartup(
                  key: ValueKey(id),
                  initialize: () async {
                    attempts++;
                    if (state == 'error') {
                      throw const FormatException('isolated startup fixture');
                    }
                    return pending.future;
                  },
                  child: const SizedBox(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: id);
            final screenContext = tester.element(find.byType(Scaffold));
            expect(
              Localizations.localeOf(screenContext),
              language.value,
              reason:
                  'The filename must describe the locale actually rendered: $id',
            );
            final localized = lookupAppLocalizations(language.value);
            expect(
              find.text(
                state == 'error'
                    ? localized.startupErrorTitle
                    : localized.startupLoading,
              ),
              findsOneWidget,
              reason: id,
            );
            if (state == 'error') {
              final retry = find.byKey(const Key('startup-retry'));
              expect(retry, findsOneWidget, reason: id);
              expect(
                tester.getRect(retry).right,
                lessThanOrEqualTo(width),
                reason: id,
              );
              await tester.tap(retry);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(attempts, 2, reason: id);
              expect(tester.takeException(), isNull, reason: id);
            }
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('startup-image')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File('${out.path}/$id.png')
                  .writeAsBytesSync(png!.buffer.asUint8List());
              image.dispose();
            });
            manifest.add({
              'id': id,
              'width': width,
              'height': height,
              'mode': mode,
              'language': language.key,
              'state': state,
              'result': 'pass',
              'method': 'Flutter widget renderer and tester input; direct human review recorded separately',
              'image': '$id.png',
            });
            await tester.pumpWidget(const SizedBox());
            if (!pending.isCompleted) pending.complete(AppServices([], []));
            await tester.pump();
          }
        }
      }
    }
    // Short landscape + large text must stay scrollable and keep Retry reachable.
    tester.view.physicalSize = const Size(320, 240);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpWidget(
      AppStartup(
        initialize: () async => throw const FormatException('short landscape'),
        child: const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('startup-retry')));
    await tester.tap(find.byKey(const Key('startup-retry')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Binding invariants run before addTearDown callbacks.
    debugDefaultTargetPlatformOverride = null;
    File(
      '${out.path}/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    expect(manifest.length, 672);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
