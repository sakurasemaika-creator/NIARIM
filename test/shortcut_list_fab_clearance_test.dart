// ショートカットの一覧で、「追加」の浮かぶボタンが最後の行の削除のボタンを
// 隠さない（DISC156）。
//
// 一覧の下端に浮かぶボタンの分の余白が無かったので、一覧を最後までスクロール
// しても、最後の行の削除のボタンが「追加」の浮かぶボタンの下に入ったまま
// 押せなかった（仏語360px・文字2倍で「Ajouter」の下）。
//
// 7言語×320/360/412px×文字1.0/2.0で、画面の下にジェスチャーの帯（安全な
// 領域）がある端末も含め、一覧を最後までスクロールしたとき、最後の行の削除の
// ボタンが浮かぶボタンと重ならず、押すとその行の削除の確認が開くことを見張る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET1_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetPadding()
      ..resetViewPadding();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  /// 一覧を本当の最後までスクロールする（行の高さがそろっていないと、1回の
  /// ドラッグでは見込みの最後で止まり、残りの行を並べると最後が先へ延びる）。
  Future<void> scrollToEnd(WidgetTester tester, Finder list) async {
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -20000));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(list).position;
      if (position.pixels >= position.maxScrollExtent - 0.5) return;
    }
  }

  /// 既定の7つに足す割り当て（どの幅・文字の大きさでも一覧がスクロールする
  /// だけの行数にする）。
  final extra = [
    for (final (i, key) in [
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
    ].indexed)
      ShortcutBinding(
        id: 'sc_test_$i',
        label: 'test',
        keyId: key.keyId,
        alt: true,
        command: ShortcutCommand.values[i % ShortcutCommand.values.length],
      ),
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the add button leaves the last row\'s delete button free '
        '($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      SharedPreferences.setMockInitialValues({});
      final service = ShortcutService();
      await tester.runAsync(service.init);
      for (final binding in extra) {
        service.addBinding(binding);
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final settings = SettingsService();
      await tester.runAsync(settings.init);
      final rootKey = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShortcutService>.value(value: service),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
          ],
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ShortcutSettingsScreen(),
            ),
          ),
        ),
      );
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final inset in [0.0, 24.0]) {
          for (final width in [320.0, 360.0, 412.0]) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = Size(width, 740);
              tester.view.devicePixelRatio = 1;
              tester.view.padding = FakeViewPadding(bottom: inset);
              tester.view.viewPadding = FakeViewPadding(bottom: inset);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await tester.pumpAndSettle();
              final at = '${width.toInt()}px x$scale inset ${inset.toInt()}';
              final list = find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await scrollToEnd(tester, list);

              final deletes = find.byIcon(Icons.delete_outline);
              final last = deletes.last;
              final lastRect = tester.getRect(last);
              final fab = tester.getRect(find.byType(FloatingActionButton));
              if (lastRect.overlaps(fab)) {
                problems.add(
                  '$at: the last delete button $lastRect is under the add '
                  'button $fab',
                );
              }
              final hit = tester.hitTestOnBinding(lastRect.center);
              final button = tester.renderObject(
                find.ancestor(of: last, matching: find.byType(IconButton)),
              );
              if (!hit.path.any((entry) => entry.target == button)) {
                problems.add('$at: a tap on the last delete button misses it');
              }

              if (shots != null && scale == 2.0 && inset == 24.0) {
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC156-${tag}_${width.toInt()}_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
              }

              for (final error in errors) {
                problems.add('$at: ${error.split('\n').first}');
              }
              errors.clear();
              await tester.drag(list, const Offset(0, 20000));
              await tester.pumpAndSettle();
            }
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(12)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');

      // 最後の行の削除のボタンは押せる：その行の削除の確認が開く。
      final list = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await scrollToEnd(tester, list);
      await tester.tap(
        find.byIcon(Icons.delete_outline).last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.commonDelete),
        ),
        findsWidgets,
        reason: 'the delete confirmation opens (not the key capture)',
      );
      expect(find.text(l10n.shortcutCaptureTitle), findsNothing);
    });
  }
}
