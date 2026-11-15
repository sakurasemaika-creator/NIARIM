import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_use_tooltips.dart';
import 'load_app_fonts.dart';

/// ホームをキーボード（Tab）で回すテストの道具。本物のアプリ（起動処理と
/// NiarimApp）を、画面を撮れるように[RepaintBoundary]で包んで開く。
class HomeKeyboardHarness {
  HomeKeyboardHarness._(this.tester, this.dir, this.projects);

  final WidgetTester tester;
  final Directory dir;
  final ProjectService projects;

  static final _boundary = GlobalKey(debugLabel: 'homeKeyboardBoundary');

  /// [works]件の作品を作ってからホームを開く（新しい順に「Work 0」が最後）。
  static Future<HomeKeyboardHarness> open(
    WidgetTester tester, {
    String language = 'ja',
    Size size = const Size(360, 740),
    double textScale = 1,
    int works = 0,
    Map<String, Object> prefs = const {},
  }) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    final dir = Directory.systemTemp.createTempSync('home-keyboard-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      for (var i = 0; i < 5; i++) {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          sleep(const Duration(milliseconds: 20));
        }
      }
    });
    ExportStorage.invalidate();
    Directory('${dir.path}/exports').createSync();
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    final projects = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    if (works > 0) {
      await tester.runAsync(() async {
        for (var i = 0; i < works; i++) {
          await projects.createProject(
            name: 'Work $i',
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 32,
            exportHeight: 18,
          );
          await Future<void>.delayed(const Duration(milliseconds: 3));
        }
      });
    }
    final harness = HomeKeyboardHarness._(tester, dir, projects);
    await harness.settle();
    return harness;
  }

  AppLocalizations get l10n =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> tab({bool shift = false}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  FocusNode? get focus => FocusManager.instance.primaryFocus;

  /// フォーカスのある部品の名前（ツールチップ・作品のカードの部品のキー）。
  String describeFocus() {
    final context = focus?.context;
    if (context == null) return 'none';
    String? key;
    String? tip;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (tip == null && widget is Tooltip) tip = widget.message;
      if (tip == null && widget is FloatingActionButton) tip = widget.tooltip;
      final k = widget.key;
      if (key == null && k is ValueKey && '${k.value}'.contains('_')) {
        key = '${k.value}';
      }
      return key == null;
    });
    return key ?? tip ?? focus.toString();
  }

  /// フォーカスが[finder]の中にあるか。
  bool focusIsIn(Finder finder) {
    final context = focus?.context;
    if (context == null) return false;
    final targets = finder.evaluate().toSet();
    if (targets.contains(context)) return true;
    var found = false;
    context.visitAncestorElements((element) {
      found = targets.contains(element);
      return !found;
    });
    return found;
  }

  /// 画面に描かれたフォーカスの部品の範囲（スクロールの途中なら描かれた位置）。
  Rect get focusRect => focus!.rect;

  /// 浮かぶボタンの範囲（画面の座標）。
  List<Rect> fabRects() => [
    for (final element in find.byType(FloatingActionButton).evaluate())
      () {
        final box = element.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }(),
  ];

  /// 画面を撮る（論理1pxが1画素）。
  Future<ScreenShot> shot() async {
    late ScreenShot result;
    await tester.runAsync(() async {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      result = ScreenShot(
        image.width,
        image.height,
        data!.buffer.asUint8List(),
      );
      image.dispose();
    });
    return result;
  }

  Future<void> close() => tester.pumpWidget(const SizedBox.shrink());
}

/// 撮った画面の画素（RGBA）。
class ScreenShot {
  ScreenShot(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;

  Color at(Offset point) {
    final x = point.dx.floor().clamp(0, width - 1);
    final y = point.dy.floor().clamp(0, height - 1);
    final i = (y * width + x) * 4;
    return Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
  }
}

/// WCAGの相対輝度による2色のコントラスト比。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
