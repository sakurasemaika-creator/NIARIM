// スマホを横に持ったとき（高さ360〜400px）も、キャンバスの早替えツールの
// 浮かぶパネルが画面に収まる（DISC247）。
//
// パネルの高さは「360pxより低くしない」決まりで、文字が大きいほど高く
// していた（DISC234）。横向きのスマホ（740×360）では画面の下から16pxの所に
// 置いた360pxのパネルの上の端が画面の外へ28px切れ、閉じるボタンの上半分が
// 見えなかった（状態表示の帯のある実機ではさらに隠れる）。高さは画面の上の
// 帯と上下の空きを残した場所までに抑え、一覧はその中でスクロールする。
//
// 本物のキャンバスで、7言語×横向きのスマホ（740×360・800×400）と縦向き
// （412×760）×文字1.0/2.0で早替えツールのパネルを開き、
// - パネルが画面の中にある、
// - 閉じるボタン・題・「追加」が見えていて押せる（指が届く）、
// - 一覧がパネルの中にあり（はみ出さない）、早替えツールの行が少なくとも
//   1つ丸ごと見える高さがある（題を固定したまま一覧を数pxに押しつぶさない）、
// ことを見る。縦向きのスマホでは今までどおり360px以上の高さを取る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final shots = Platform.environment['NIARIM_SET4_SHOTS'];
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_quick_landscape_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool under(HitTestTarget target, RenderObject box) {
    if (target is! RenderObject) return false;
    RenderObject? node = target;
    while (node != null) {
      if (identical(node, box)) return true;
      node = node.parent;
    }
    return false;
  }

  /// [finder]の真ん中を押すと、[finder]に届くか（画面の外・切れた所・
  /// 何かの下ではない）。
  bool reachable(WidgetTester tester, Finder finder) {
    final box = tester.renderObject(finder.first) as RenderBox;
    final centre = box.localToGlobal(box.size.center(Offset.zero));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    if (!(Offset.zero & size).contains(centre)) return false;
    return tester
        .hitTestOnBinding(centre)
        .path
        .any((entry) => under(entry.target, box));
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('the quick tool panel fits a phone held sideways ($tag)', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final size in const [
          Size(740, 360),
          Size(800, 400),
          Size(412, 760),
        ]) {
          for (final scale in const [1.0, 2.0]) {
            final at = '${size.width.toInt()}x${size.height.toInt()} x$scale';
            appRouter.go('/home');
            SharedPreferences.setMockInitialValues({
              firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
              'first_launch': false,
              'language': tag.replaceAll('-', '_'),
            });
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final providers = (await tester.runAsync(buildAppProviders))!;
            final root = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: root,
                child: MultiProvider(
                  providers: providers,
                  child: const NiarimApp(),
                ),
              ),
            );
            await settle(tester, 4);
            final service = tester
                .element(find.byType(HomeScreen))
                .read<ProjectService>();
            late String id;
            await tester.runAsync(() async {
              final project = await service.createProject(
                name: 'Quick',
                fps: 2,
                durationSeconds: 1,
                backgroundColor: 0xFFFFFFFF,
                exportWidth: 160,
                exportHeight: 90,
              );
              id = project.id;
            });
            appRouter.push('/canvas/$id');
            await settle(tester, 12);
            // 早替えツールのボタンを長押しして、設定のパネルを開く。
            final button = find.byIcon(Icons.loop);
            if (button.evaluate().isEmpty) {
              problems.add('$at: no quick tool button');
            } else {
              await tester.ensureVisible(button.first);
              await tester.pump();
              await tester.longPress(button.first);
              await settle(tester, 3);
            }
            final panel = find.byType(QuickToolPanel);
            if (panel.evaluate().isEmpty) {
              problems.add('$at: the quick tool panel did not open');
            } else {
              final rect = tester.getRect(panel);
              debugPrint('$at panel $rect');
              if (rect.top < -0.5 || rect.bottom > size.height + 0.5) {
                problems.add('$at: the panel $rect leaves the screen');
              }
              final l10n = AppLocalizations.of(tester.element(panel))!;
              final parts = <String, Finder>{
                'close': find.descendant(
                  of: panel,
                  matching: find.byType(IconButton),
                ),
                'title': find.descendant(
                  of: panel,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is RichText &&
                        w.text
                            .toPlainText()
                            .replaceAll('⁠', '')
                            .replaceAll('​', '')
                            .contains(
                              l10n.quickToolPanelTitle.split(' ').first,
                            ),
                  ),
                ),
                'add': find.descendant(
                  of: panel,
                  matching: find.byWidgetPredicate((w) => w is TextButton),
                ),
              };
              for (final MapEntry(key: name, value: part) in parts.entries) {
                if (part.evaluate().isEmpty) {
                  problems.add('$at: no $name in the panel');
                } else if (!reachable(tester, part)) {
                  problems.add(
                    '$at: the $name ${tester.getRect(part.first)} cannot be '
                    'reached (the panel is $rect)',
                  );
                }
              }
              final list = find.descendant(
                of: panel,
                matching: find.byType(Scrollable),
              );
              for (final e in list.evaluate()) {
                final r = tester.getRect(
                  find.byElementPredicate((x) => x == e),
                );
                if (r.top < rect.top - 0.5 || r.bottom > rect.bottom + 0.5) {
                  problems.add('$at: the list $r leaves the panel $rect');
                }
              }
              // 一覧の見える所に、早替えツールの行が少なくとも1つ丸ごと入る
              // （題を固定したまま一覧を数pxに押しつぶさない）。
              final entries = tester
                  .element(panel)
                  .read<QuickToolService>()
                  .entries;
              final rows = [
                for (final entry in entries)
                  ...find
                      .descendant(
                        of: panel,
                        matching: find.byKey(ValueKey(entry.id)),
                      )
                      .evaluate(),
              ];
              if (list.evaluate().isNotEmpty && rows.isNotEmpty) {
                final viewport = tester.getRect(list.first);
                var tallest = 0.0;
                for (final e in rows) {
                  final row = find.byElementPredicate((x) => x == e);
                  final h = tester.getSize(row).height;
                  if (h > tallest) tallest = h;
                }
                if (viewport.height < tallest - 0.5) {
                  problems.add(
                    '$at: the list shows ${viewport.height.toStringAsFixed(0)}'
                    'px, less than one row',
                  );
                }
              }
              if (size.height > size.width && rect.height < 360 - 0.5) {
                problems.add(
                  '$at: the panel is ${rect.height}px tall on a portrait phone',
                );
              }
            }
            if (shots != null && panel.evaluate().isNotEmpty) {
              await tester.runAsync(() async {
                final boundary =
                    root.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC247-$tag-${size.width.toInt()}x'
                  '${size.height.toInt()}_x'
                  '${scale.toString().replaceAll('.', '')}.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
            for (final error in errors) {
              problems.add('$at ${error.split('\n').first}');
            }
            errors.clear();
            await tester.pumpWidget(const SizedBox.shrink());
            await settle(tester, 2);
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final p in problems) {
        debugPrint(p);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
