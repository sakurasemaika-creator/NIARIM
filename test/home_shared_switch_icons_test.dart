import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/shared_direction_switch.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

// 共有タブの切り替え（受け取ったもの／自分が作成したもの）がアイコンだけに
// なったとき（DISC127）：
// - アイコンも文字の大きさの設定に合わせて大きくなる（文字2倍で18pxのまま
//   だった）。
// - 2つのアイコンは形で見分けられる（受信トレイ・送信トレイは同じ箱で矢印の
//   向きだけが違い、320pxでは見分けにくかった）。
// 判断3（入らない幅ではアイコン・名前は長押し／ホバーと読み上げ）は
// home_shared_direction_switch_test が見張る。

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

final _switch = find.byKey(const Key('sharedDirectionSegmentedControl'));

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<void> _openShared(
  WidgetTester tester, {
  required String language,
  required Size size,
  required double scale,
}) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': language,
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  final dir = Directory.systemTemp.createTempSync('home-shared-icons-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 後始末の途中で保存が走っていても、テストの結果は変えない。
    }
  });
  ExportStorage.invalidate();
  Directory('${dir.path}/exports').createSync();
  await tester.runAsync(
    () => ExportEngine.listExportedFiles(forceRefresh: true),
  );
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await _frames(tester);
  await _settleIo(tester);
  tester.widget<TabBarView>(find.byType(TabBarView)).controller!.animateTo(2);
  await _frames(tester, 8);
  await _settleIo(tester, 2);
}

/// [icon]を[size]pxで描いた字形の、塗られた画素（不透明度が半分以上）。
Future<Set<int>> _glyph(WidgetTester tester, IconData icon, int size) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(
            dimension: size.toDouble(),
            child: Icon(
              icon,
              size: size.toDouble(),
              color: const Color(0xFF000000),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final pixels = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  return {
    for (var i = 0; i < size * size; i++)
      if (pixels.getUint8(i * 4 + 3) >= 128) i,
  };
}

/// 2つの字形の重なり（共通の画素÷どちらかの画素）。
double _overlap(Set<int> a, Set<int> b) =>
    a.intersection(b).length / a.union(b).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in _languages) {
    testWidgets('the icons grow with the text size ($language, 320px)', (
      tester,
    ) async {
      for (final scale in [1.0, 1.5, 2.0]) {
        await _openShared(
          tester,
          language: language,
          size: const Size(320, 800),
          scale: scale,
        );
        final icons = find.descendant(of: _switch, matching: find.byType(Icon));
        if (icons.evaluate().isEmpty) {
          // 名前が入る大きさ（文字で出している）。
          await tester.pumpWidget(const SizedBox.shrink());
          continue;
        }
        expect(icons, findsNWidgets(2), reason: '$language x$scale');
        final drawnScale =
            tester.getRect(_switch).width /
            tester.renderObject<RenderBox>(_switch).size.width;
        for (final element in icons.evaluate()) {
          final box = element.renderObject! as RenderBox;
          final drawn = box.size.width * drawnScale;
          debugPrint('$language x$scale icon ${drawn.toStringAsFixed(1)}px');
          expect(
            drawn,
            closeTo(18 * scale, 0.5),
            reason: '$language x$scale: the icon did not follow the text size',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('the two icons differ in shape, not only in an arrow', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final received = await _glyph(
      tester,
      SharedDirectionSwitch.receivedIcon,
      24,
    );
    final outgoing = await _glyph(
      tester,
      SharedDirectionSwitch.outgoingIcon,
      24,
    );
    expect(received, isNotEmpty);
    expect(outgoing, isNotEmpty);
    final overlap = _overlap(received, outgoing);
    // 参考：受信トレイと送信トレイ（以前の組）の重なり。
    final inbox = await _glyph(tester, Icons.move_to_inbox_outlined, 24);
    final outbox = await _glyph(tester, Icons.outbox_outlined, 24);
    debugPrint(
      'overlap now ${overlap.toStringAsFixed(2)}, '
      'inbox/outbox ${_overlap(inbox, outbox).toStringAsFixed(2)}',
    );
    expect(overlap, lessThan(0.5));
  });
}
