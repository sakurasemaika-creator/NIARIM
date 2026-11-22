// キャンバス（スマホの画面）のフレームの複数選択のバーの操作が、どの幅・
// 文字の大きさでも画面の中にあって押せる（DISC151）。
//
// バーは「n / m フレーム選択中」の文と、全選択・全解除・フィルター適用・
// キャンセルのボタンを1つの`Row`に並べていて、日本語360px・文字2倍で253px、
// 文字1倍でも約34px、600px・文字2倍でもはみ出し、右の「フィルター適用」が
// 画面の外へ切れて押せなかった。
//
// 7言語×320/360/412/600px×文字1.0/1.3/2.0で、バーの4つの操作がそれぞれ
// バーの中・画面の中にあって押せること（文字のボタン、またはアイコンの
// ボタン。アイコンのときは名前を吹き出しと読み上げで伝える）、件数の文が
// 切れず語の途中で折れないこと、はみ出しのエラーが出ないことを見る。
// 320px・文字2倍では、全選択してからフィルター適用を押し、フィルターの
// パネルが開くことも確かめる。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_frame_select_');
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

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('frame multi-select bar keeps every action reachable ($tag)', (
      tester,
    ) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 760);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': tag.replaceAll('-', '_'),
      });
      appRouter.go('/home');
      final root = GlobalKey();
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await settle(tester, 4);
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      final project = (await tester.runAsync(
        () => service.createProject(
          name: 'Frames',
          fps: 12,
          durationSeconds: 2,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 90,
        ),
      ))!;
      final total = service.frameCount(
        project.id,
        service.scenesOf(project.id).first.id,
      );
      appRouter.push('/canvas/${project.id}');
      await settle(tester, 10);
      expect(find.byType(CanvasScreen), findsOneWidget);
      // 「設定/編集」のメニューから複数選択に入る。
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester, 3);
      final item = find.text(l10n.canvasEditMenuFrameMultiSelect);
      await tester.scrollUntilVisible(
        item,
        120,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(item);
      await settle(tester, 3);

      final problems = <String>{};
      final tooWide = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());

      /// [name]の操作（名前の文のボタン、または名前を吹き出しに持つボタン）が
      /// バー[bar]の中・画面の中にあって押せるか。
      String? unreachable(String name, Rect bar, Size screen) {
        final candidates = [
          ...find.text(name).evaluate(),
          ...find.byTooltip(name).evaluate(),
        ];
        for (final element in candidates) {
          final box = element.renderObject;
          if (box is! RenderBox || !box.attached || !box.hasSize) continue;
          final rect = MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
          if (!bar.inflate(0.5).contains(rect.topLeft) ||
              !bar.inflate(0.5).contains(rect.bottomRight)) {
            continue;
          }
          if (rect.left < -0.5 || rect.right > screen.width + 0.5) continue;
          final result = HitTestResult();
          WidgetsBinding.instance.hitTestInView(
            result,
            rect.center,
            tester.view.viewId,
          );
          if (result.path.any((entry) => entry.target == box)) return null;
        }
        return '「$name」is not reachable in the bar $bar';
      }

      try {
        for (final width in [320.0, 360.0, 412.0, 600.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 760);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle(tester, 2);
            final at = '${width.toInt()}px x$scale';
            final countText = l10n.canvasFrameSelectedCount(0, total);
            final count = find.text(countText);
            if (count.evaluate().length != 1) {
              problems.add('$at: ${count.evaluate().length}「$countText」');
              continue;
            }
            final bar = tester.getRect(
              find.ancestor(of: count, matching: find.byType(Container)).first,
            );
            final screen = Size(width, 760);
            if (bar.left < -0.5 || bar.right > width + 0.5) {
              problems.add('$at the bar $bar leaves the screen');
            }
            for (final name in [
              l10n.canvasSelectAllButton,
              l10n.canvasDeselectAllButton,
              l10n.canvasApplyFilterButton,
              l10n.commonCancel,
            ]) {
              final problem = unreachable(name, bar, screen);
              if (problem != null) problems.add('$at $problem');
            }
            for (final p in textParagraphsIn(count)) {
              final lines = ParagraphLines(p);
              final rect = MatrixUtils.transformRect(
                p.getTransformTo(null),
                Offset.zero & p.size,
              );
              if (rect.left < -0.5 || rect.right > width + 0.5) {
                problems.add('$at「$countText」$rect leaves the screen');
              }
              for (final c in lines.charsOutsideWidth()) {
                problems.add('$at「$countText」is cut: $c');
              }
              final broken = brokenWordUnits(p);
              for (final word in broken.fits) {
                problems.add('$at「$countText」: $word');
              }
              tooWide.addAll(broken.tooWide.map((w) => '$at $w'));
            }
            if (shots != null && scale != 1.3 && width != 412) {
              await tester.runAsync(() async {
                final boundary =
                    root.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC151-$tag-${width.toInt()}_x'
                  '${scale.toString().replaceAll('.', '')}.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
            for (final error in errors) {
              problems.add('$at ${error.split('\n').first}');
            }
            errors.clear();
          }
        }
        // 320px・文字2倍で全選択してからフィルター適用を押すと、フィルターの
        // パネルが開く。
        tester.view.physicalSize = const Size(320, 760);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        await settle(tester, 2);
        Future<void> press(String name) async {
          final target =
              [
                ...find.text(name).evaluate(),
                ...find.byTooltip(name).evaluate(),
              ].where((e) {
                final box = e.renderObject;
                return box is RenderBox && box.attached && box.hasSize;
              });
          if (target.isEmpty) {
            problems.add('320px x2.0: no「$name」to press');
            return;
          }
          await tester.tap(
            find.byElementPredicate((e) => e == target.first),
            warnIfMissed: false,
          );
          await settle(tester, 2);
        }

        await press(l10n.canvasSelectAllButton);
        if (find
            .text(l10n.canvasFrameSelectedCount(total, total))
            .evaluate()
            .isEmpty) {
          problems.add('320px x2.0: select all did not select $total frames');
        }
        await press(l10n.canvasApplyFilterButton);
        if (find.byType(FilterPanel).evaluate().isEmpty) {
          problems.add(
            '320px x2.0: apply filter did not open the filter panel',
          );
        }
        for (final error in errors) {
          problems.add('press ${error.split('\n').first}');
        }
      } finally {
        FlutterError.onError = onError;
        semantics.dispose();
      }
      for (final word in tooWide) {
        problems.add('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
