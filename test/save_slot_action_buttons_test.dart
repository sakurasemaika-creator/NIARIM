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
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// セーブスロット画面：**全てのスロット1つ1つに**ペン（書き込み）・
/// 本（読み込み）・ゴミ箱（削除）の3ボタンが並ぶことを実画面で検証し、
/// あわせて目視用のPNGを焼く。
///
/// 以前は行をタップするとボトムシートが開き、その中の
/// 「上書きする／復元／削除」を選ぶ2段構えだった。役割が重複するので
/// シートごと廃止している（`_SlotAction`が残っていないこともソースで確認）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('全セーブスロットにペン・本・ゴミ箱の3ボタンが並ぶ', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim_save_slot_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle({int rounds = 5}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();

    final ctx = tester.element(find.byType(MaterialApp).first);
    final ps = ctx.read<ProjectService>();
    final saveService = ctx.read<SaveTreeService>();
    // スロット方式（ゲーム風）でのみ出る画面なので、ツリー方式なら切り替える。
    expect(saveService.isTreeMode, isFalse, reason: 'このテストはスロット方式の画面を対象にしている');
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'save-slot-audit',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    appRouter.go('/save-tree/${project.id}');
    await settle();
    expect(tester.takeException(), isNull);

    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    // 画面に見えているスロット行のぶんだけ、3種類のボタンが揃っている。
    // `find.byTooltip`はIconButtonが内部に作るTooltipを返してしまうので、
    // IconButton自身のtooltipプロパティで探す（onPressedを見たいため）。
    Finder byTooltip(String tooltip) =>
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);
    final writes = byTooltip(l10n.saveTreeSlotWriteTooltip);
    final loads = byTooltip(l10n.saveTreeSlotLoadTooltip);
    final deletes = byTooltip(l10n.saveTreeSlotDeleteTooltip);
    final slotRows = writes.evaluate().length;
    expect(slotRows, greaterThan(1), reason: 'スロット行が表示されていない');
    expect(loads.evaluate().length, slotRows, reason: '本ボタンが足りない');
    expect(deletes.evaluate().length, slotRows, reason: 'ゴミ箱ボタンが足りない');

    // 空スロットでは読み込み・削除は無効（押しても何も起きない）。
    for (final e in loads.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNull);
    }
    for (final e in deletes.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNull);
    }
    // 書き込みは空スロットでも常に押せる。
    for (final e in writes.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNotNull);
    }

    // 役割が重複していた旧ボトムシートが残っていないことをソースで確認する。
    final source = File(
      'lib/screens/save_tree/save_management_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('showModalBottomSheet'),
      isFalse,
      reason: 'スロット操作のボトムシートは3ボタンに置き換えて廃止した',
    );
    expect(
      source.contains('enum _SlotAction'),
      isFalse,
      reason: 'シートの選択肢を表すenumも不要になった',
    );

    // 目視用のPNGを焼く。
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final out = Directory('build/visual-reaudit')..createSync(recursive: true);
    await tester.runAsync(
      () => File('${out.path}/save_slots.png').writeAsBytes(bytes!),
    );
  });
}
