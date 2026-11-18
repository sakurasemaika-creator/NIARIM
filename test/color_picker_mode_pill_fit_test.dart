// PC/DeXモードのキャンバスのドックの色の窓で、色の輪の右下のHSV/RGBの
// 切り替え（ピル）が、輪・ほかの部品・下の数のスライダーに重ならず、
// 名前が切れない（DISC246）。
//
// ピルは「文字1倍で幅66px・高さ28px」と決め打ちして輪の右下の接線に置いて
// いたので、文字2倍ではピルが広く高くなり、ドック200pxで輪に食い込み、
// 下の段（スライダー）に重なり、名前が段の外へはみ出した（仏語・簡体字）。
// 所有者の判断3：入らなければ並べ方を変える（アイコン・段を分ける）。文字は
// 縮めない・省略記号で切らない。
//
// 本物のPCの作業画面で、7言語×ドック200/280px×文字1.0/2.0、HSVとRGBの
// どちらを選んだときも、
// - ピルの2つの名前（HSV・RGB）がそれぞれの区画の中に全部出ている、
// - ピルが色の輪（色相の帯の外周）・透明色の切り替え・スポイトに重ならない、
// - ピルが色の輪の部品の箱の中にあり、下のスライダーに重ならない、
// - ピルが色の窓の横幅からはみ出さない、
// ことを見る。押せば切り替わること（区画を押すとスライダーがH/RとR/Hに
// 替わる）も見る。
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/hsv_color_wheel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

const _hsvKey = ValueKey('color-slider-mode-hsv');
const _rgbKey = ValueKey('color-slider-mode-rgb');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final shots = Platform.environment['NIARIM_SET4_SHOTS'];
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_mode_pill_');
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

  Rect rectOf(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  /// [rect]の中で[centre]にいちばん近い点までの距離。
  double distanceTo(Rect rect, Offset centre) {
    final dx = math.max(
      0.0,
      math.max(rect.left - centre.dx, centre.dx - rect.right),
    );
    final dy = math.max(
      0.0,
      math.max(rect.top - centre.dy, centre.dy - rect.bottom),
    );
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 色の窓の中のピルの問題。
  List<String> check(WidgetTester tester, String at) {
    final problems = <String>[];
    final picker = find.byType(ColorPickerPanel);
    if (picker.evaluate().isEmpty) return ['$at: no colour window'];
    final wheel = find.descendant(
      of: picker,
      matching: find.byType(HsvColorWheel),
    );
    final wheelBox = tester.getRect(wheel);
    final hsv = find.descendant(of: wheel, matching: find.byKey(_hsvKey));
    final rgb = find.descendant(of: wheel, matching: find.byKey(_rgbKey));
    if (hsv.evaluate().isEmpty || rgb.evaluate().isEmpty) {
      return ['$at: the HSV/RGB switch is missing'];
    }
    final pill = tester.getRect(hsv).expandToInclude(tester.getRect(rgb));
    // 名前は区画の中に全部出る（文字・吹き出し）。
    for (final (name, segment) in [('HSV', hsv), ('RGB', rgb)]) {
      final box = tester.getRect(segment);
      final texts = [
        for (final e
            in find
                .descendant(of: segment, matching: find.byType(RichText))
                .evaluate())
          e.renderObject! as RenderParagraph,
      ];
      if (texts.isEmpty) {
        final tooltip = find.descendant(
          of: segment,
          matching: find.byTooltip(name),
        );
        final labelled = find.descendant(
          of: segment,
          matching: find.bySemanticsLabel(RegExp(name)),
        );
        if (tooltip.evaluate().isEmpty && labelled.evaluate().isEmpty) {
          problems.add('$at $name: neither a name nor a tooltip');
        }
      }
      for (final p in texts) {
        final r = rectOf(p);
        // 段落の箱より大きな字（箱の外へはみ出して描かれる）も切れている。
        if (p.textSize.width > p.size.width + 0.5 ||
            p.textSize.height > p.size.height + 0.5) {
          problems.add(
            '$at $name: the name ${p.textSize} overflows its box ${p.size}',
          );
        }
        if (p.didExceedMaxLines ||
            r.top < box.top - 0.5 ||
            r.bottom > box.bottom + 0.5 ||
            r.left < box.left - 0.5 ||
            r.right > box.right + 0.5) {
          problems.add('$at $name: the name $r is cut by its segment $box');
        }
        for (final c in ParagraphLines(p).charsOutsideWidth()) {
          problems.add('$at $name: the name runs past its line: $c');
        }
      }
    }
    // 色の輪（色相の帯の外周）に重ならない。
    final ring = tester.getRect(
      find.descendant(
        of: wheel,
        matching: find.byKey(const ValueKey('color-picker-hue-ring')),
      ),
    );
    final radius = ring.width / 2;
    final centre = ring.center;
    final gap = distanceTo(pill, centre) - radius;
    if (gap < -0.5) {
      problems.add(
        '$at: the switch $pill cuts ${(-gap).toStringAsFixed(1)}px into '
        'the hue ring (radius $radius at $centre)',
      );
    }
    // ほかの部品に重ならない。
    for (final key in const [
      ValueKey('color-picker-transparent-toggle'),
      ValueKey('color-picker-eyedropper'),
    ]) {
      final other = find.descendant(of: wheel, matching: find.byKey(key));
      if (other.evaluate().isEmpty) continue;
      final r = tester.getRect(other);
      if (distanceTo(r, centre) < radius - 0.5) {
        problems.add('$at: $key $r overlaps the hue ring $ring');
      }
      if (r.overlaps(pill.deflate(0.5))) {
        problems.add('$at: the switch $pill overlaps $key $r');
      }
    }
    // 輪の部品の箱の中（下のスライダーに重ならない）。
    if (pill.bottom > wheelBox.bottom + 0.5 || pill.top < wheelBox.top - 0.5) {
      problems.add(
        '$at: the switch $pill leaves the wheel box $wheelBox '
        '(it overlaps the sliders below)',
      );
    }
    // 色の窓の横幅に収まる。
    final panel = tester.getRect(picker);
    if (pill.left < panel.left - 0.5 || pill.right > panel.right + 0.5) {
      problems.add('$at: the switch $pill leaves the colour window $panel');
    }
    return problems;
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('the HSV/RGB switch fits beside the colour wheel in the PC '
        'dock ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final semantics = tester.ensureSemantics();
      final problems = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final dock in [200.0, 280.0]) {
          for (final scale in [1.0, 2.0]) {
            final at = 'dock${dock.toInt()} x$scale';
            appRouter.go('/home');
            SharedPreferences.setMockInitialValues({
              firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
              'first_launch': false,
              'language': tag.replaceAll('-', '_'),
              'force_pc_mode': 1,
              'desktop_panel_width': dock,
              'desktop_tool_panel_width': dock,
            });
            tester.view.physicalSize = const Size(1280, 800);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final root = GlobalKey();
            final providers = (await tester.runAsync(buildAppProviders))!;
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
                name: 'Pill',
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
            for (final mode in [_hsvKey, _rgbKey]) {
              final segment = find.byKey(mode);
              if (segment.evaluate().isEmpty) {
                problems.add('$at: no ${mode.value}');
                break;
              }
              await tester.ensureVisible(segment);
              await tester.pump();
              await tester.tap(segment, warnIfMissed: false);
              await settle(tester, 2);
              final where = '$at ${mode == _hsvKey ? 'HSV' : 'RGB'}';
              problems.addAll(check(tester, where));
              // 押した区画のスライダーに替わる。
              final first = mode == _hsvKey ? 'H' : 'R';
              final picker = find.byType(ColorPickerPanel);
              if (find
                  .descendant(of: picker, matching: find.text(first))
                  .evaluate()
                  .isEmpty) {
                problems.add('$where: the $first slider is not shown');
              }
            }
            if (shots != null) {
              final wheel = find.byType(HsvColorWheel);
              await tester.ensureVisible(wheel);
              await tester.pump();
              await tester.runAsync(() async {
                final boundary =
                    root.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC246-$tag-${dock.toInt()}_x'
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
        semantics.dispose();
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
