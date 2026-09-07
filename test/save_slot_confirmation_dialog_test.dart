import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('既存スロットの書き込み・読み込み確認にサムネイルと保存日時が表示される', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });

    final tempDir = Directory.systemTemp.createTempSync(
      'niarim_save_slot_confirmation_',
    );
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

    Future<void> settle({int rounds = 6}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    String formatDate(DateTime dt) =>
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    FileImage fileImageOf(Image image) {
      ImageProvider provider = image.image;
      if (provider is ResizeImage) {
        provider = provider.imageProvider;
      }
      expect(provider, isA<FileImage>());
      return provider as FileImage;
    }

    Future<void> expectConfirmationSummary({
      required String title,
      required String thumbnailPath,
      required String savedAtText,
      required String comment,
    }) async {
      final dialog = find.widgetWithText(AlertDialog, title);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text(comment)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(savedAtText)),
        findsOneWidget,
      );

      final imageFinder = find.descendant(
        of: dialog,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(fileImageOf(image).file.path, thumbnailPath);

      // Image.file の非同期デコードまで進める。壊れたPNGや誤ったパスなら
      // errorBuilder の image_outlined に落ちるため、RawImage の存在まで確認する。
      await settle(rounds: 8);
      expect(
        find.descendant(of: dialog, matching: find.byType(RawImage)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byIcon(Icons.image_outlined),
        ),
        findsNothing,
      );
    }

    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await settle();

    final context = tester.element(find.byType(MaterialApp).first);
    final projectService = context.read<ProjectService>();
    final saveService = context.read<SaveTreeService>();
    expect(saveService.isTreeMode, isFalse);

    final project = (await tester.runAsync(
      () => projectService.createProject(
        name: 'save-slot-confirmation',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;

    // 実際にデコード可能な1x1 PNGを保存サービスへ渡し、既存データ入りの
    // スロットを本番と同じ SaveTree 領域に作る。
    final thumbnailBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    const comment = '確認ダイヤログ既存データ';
    final node = (await tester.runAsync(
      () => saveService.saveToSlot(
        projectId: project.id,
        slotIndex: 0,
        project: project,
        scenes: projectService.scenesOf(project.id),
        tileManager: projectService.tileManagerOf(project.id),
        comment: comment,
        thumbnailPngBytes: thumbnailBytes,
      ),
    ))!;

    expect(node.thumbnailPath, isNotNull);
    final thumbnailFile = File(node.thumbnailPath!);
    expect(thumbnailFile.existsSync(), isTrue);
    expect(thumbnailFile.readAsBytesSync(), orderedEquals(thumbnailBytes));
    final savedAtText = formatDate(node.savedAt);

    // projectDetail は既存スロットからの読み込みが許可される正式な入口。
    appRouter.go('/save-tree/${project.id}?entry=projectDetail');
    await settle();
    expect(tester.takeException(), isNull);

    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    Finder byTooltip(String tooltip) => find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    );

    final writes = byTooltip(l10n.saveTreeSlotWriteTooltip);
    final loads = byTooltip(l10n.saveTreeSlotLoadTooltip);
    expect(writes, findsWidgets);
    expect(loads, findsWidgets);
    expect((tester.widget<IconButton>(loads.first)).onPressed, isNotNull);

    // 既存スロットへの書き込み（上書き）確認を直接開く。
    await tester.tap(writes.first);
    await settle();
    await expectConfirmationSummary(
      title: l10n.saveTreeOverwriteAction,
      thumbnailPath: node.thumbnailPath!,
      savedAtText: savedAtText,
      comment: comment,
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(AlertDialog, l10n.saveTreeOverwriteAction),
        matching: find.widgetWithText(TextButton, l10n.commonCancel),
      ),
    );
    await settle();
    expect(find.widgetWithText(AlertDialog, l10n.saveTreeOverwriteAction), findsNothing);

    // 同じ既存スロットの読み込み確認を直接開く。
    await tester.tap(loads.first);
    await settle();
    await expectConfirmationSummary(
      title: l10n.saveTreeRestoreAction,
      thumbnailPath: node.thumbnailPath!,
      savedAtText: savedAtText,
      comment: comment,
    );
  }, timeout: const Timeout(Duration(seconds: 120)));
}
