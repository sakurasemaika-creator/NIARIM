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

/// セーブスロット画面：**全てのスロット1つ1つに**メモ＋ペン（書き込み）・
/// ノート（読み込み）・ゴミ箱（削除）の3ボタンが並ぶことを実画面で検証し、
/// あわせて目視用のPNGを焼く。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('全セーブスロットに書き込み・読み込み・削除の3ボタンが並ぶ', (tester) async {
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
    Finder byTooltip(String tooltip) =>
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);
    final writes = byTooltip(l10n.saveTreeSlotWriteTooltip);
    final loads = byTooltip(l10n.saveTreeSlotLoadTooltip);
    final deletes = byTooltip(l10n.saveTreeSlotDeleteTooltip);
    final slotRows = writes.evaluate().length;
    expect(slotRows, greaterThan(1), reason: 'スロット行が表示されていない');
    expect(loads.evaluate().length, slotRows, reason: 'ノートボタンが足りない');
    expect(deletes.evaluate().length, slotRows, reason: 'ゴミ箱ボタンが足りない');

    for (final e in loads.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNull);
    }
    for (final e in deletes.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNull);
    }
    for (final e in writes.evaluate()) {
      expect((e.widget as IconButton).onPressed, isNotNull);
    }

    IconData iconOf(Finder f) =>
        ((f.evaluate().first.widget as IconButton).icon as Icon).icon!;
    expect(iconOf(writes), Icons.edit_note, reason: '書き込みはメモ＋ペンのアイコン');
    expect(iconOf(loads), Icons.book_outlined, reason: '読み込みはノートのアイコン');
    expect(iconOf(deletes), Icons.delete_outline, reason: '削除はゴミ箱のアイコン');

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
    expect(
      source.contains('_SlotConfirmationSummary'),
      isTrue,
      reason: '書き込み・読み込み確認にはサムネイルと保存日時の要約を表示する',
    );

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
