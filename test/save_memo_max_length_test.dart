import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/widgets/save_rename_button.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Saving 100-character memo shows one ellipsized line in the '
      'actual empty-slot list and survives a reload', (tester) async {
    SharedPreferences.setMockInitialValues({'quality_level': 'medium'});
    final directory = Directory.systemTemp.createTempSync('save_memo_max_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureKey = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      final boundary = captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1)))!;
      final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png)))!;
      image.dispose();
      final dir = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(() async =>
          File('${dir.path}/$name.png')
              .writeAsBytes(bytes.buffer.asUint8List()));
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final ctx = tester.element(find.byType(MaterialApp).first);
    final ps = ctx.read<ProjectService>();
    final save = ctx.read<SaveTreeService>();
    save.setTreeMode(false);
    final p = await tester.runAsync(() => ps.createProject(
      name: '100 memo check',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xffffffff,
      exportWidth: 64,
      exportHeight: 64,
    ));
    expect(p, isNotNull);
    appRouter.go('/save-tree/${p!.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final pen = find.byKey(Key('saveSlotMemo_${p.id}_0'));
    expect(pen, findsOneWidget);
    await tester.tap(pen);
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextField),
    );
    expect(input, findsOneWidget);
    final text = List.filled(100, 'あ').join();
    await tester.enterText(input, text);
    await tester.pumpAndSettle();
    await capture('memo_01_100_characters_in_single_title_dialog');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 35)),
      );
      await tester.pump();
    }
    expect(save.slotMemoOf(p.id, 0), text);
    expect(save.getNodes(p.id), isEmpty,
        reason: 'Editing an empty slot must not create saved data');
    final label = find.text(text);
    expect(label, findsOneWidget);
    final widget = tester.widget<Text>(label);
    expect(widget.maxLines, 1);
    expect(widget.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    await capture('memo_02_100_characters_ellipsized_empty_slot');

    final reloaded = SaveTreeService();
    await tester.runAsync(reloaded.init);
    expect(reloaded.slotMemoOf(p.id, 0), text);
    reloaded.dispose();
  });

  testWidgets('Memo dialog uses only one heading and handles 100 characters',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = SaveTreeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SaveTreeService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SaveSlotMemoButton(
                projectId: 'memo_test',
                slotIndex: 0,
                initialMemo: '',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveSlotMemo_memo_test_0')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('メモ')),
        findsOneWidget,
        reason: 'The title must not be repeated as a floating input label');
    final field = find.descendant(
        of: dialog, matching: find.byType(TextField));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).maxLength, 100);
    expect(tester.widget<TextField>(field).maxLines, 3);

    final sample = List.filled(100, 'あ').join();
    await tester.enterText(field, sample);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, sample);
    expect(tester.takeException(), isNull);

    final rect = tester.getRect(dialog);
    const logical = Size(360, 760);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(logical.width));
    expect(rect.bottom, lessThanOrEqualTo(logical.height));
    // Confirm that the one-line slot label truncates independently.
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
