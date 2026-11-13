import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ゴミ箱のカードの「コピー」「復元」「完全削除」を長押し（ゆっくり押す・
/// マウスで押し続ける）しても、カードの選択を始めず、そのボタンを押した
/// ことになる。カード全体を長押しで選べるようにしたとき（DISC098の4）、
/// ボタンの上の長押しまでカードが取り、ボタンが消えて何も起きなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_trash_long_press_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('holding a trash card button presses that button and does not '
      'start selecting the card (touch at 360, mouse at 1280)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester
        .element(find.byType(SplashScreen))
        .read<ProjectService>();
    late final String workId;
    late final String folderId;
    late final String fileId;
    await tester.runAsync(() async {
      final work = await service.createProject(
        name: '海辺のスケッチ',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      workId = work.id;
      await service.deleteProject(work.id);
      final folder = await service.createFolder('旅行');
      folderId = folder.id;
      final inside = await service.createProject(
        name: '海',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await service.moveToFolder(inside.id, folder.id);
      await service.moveFolderToTrash(folder.id);
      final exported = File('${tempDir.path}/clip_001.mp4')
        ..writeAsBytesSync(List<int>.filled(64, 7));
      fileId = (await LocalFileTrashService.move(
        exported,
        LocalTrashKind.exportedWork,
      )).id;
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await settle(tester, rounds: 8);

    // カードの種類ごとの選択の印とボタン（コピー・復元・完全削除）。
    final cards = <String, List<String>>{
      'trash_project:$workId': [
        'trashCopyProject_$workId',
        'trash-restore-$workId',
        'trash-delete-$workId',
      ],
      'trash_folder:$folderId': [
        'trashCopyFolder_$folderId',
        'trashedFolderRestore_$folderId',
        'trashedFolderDelete_$folderId',
      ],
      'trash_local:$fileId': [
        'trashCopyLocal_$fileId',
        'trash-restore-local-$fileId',
        'trash-delete-local-$fileId',
      ],
    };

    final problems = <String>[];
    for (final (size, kind) in const [
      (Size(360, 800), PointerDeviceKind.touch),
      (Size(1280, 800), PointerDeviceKind.mouse),
    ]) {
      tester.view.physicalSize = size;
      await settle(tester, rounds: 3);
      for (final MapEntry(key: selectionId, value: keys) in cards.entries) {
        for (final (index, key) in keys.indexed) {
          final where = '${size.width.toInt()} ${kind.name} $key';
          final button = find.byKey(ValueKey(key), skipOffstage: false);
          if (button.evaluate().isEmpty) {
            problems.add('$where: the button is not shown');
            continue;
          }
          await tester.scrollUntilVisible(
            button,
            80,
            scrollable: find.byType(Scrollable).last,
          );
          await settle(tester, rounds: 1);
          final gesture = await tester.startGesture(
            tester.getCenter(button),
            kind: kind,
          );
          await tester.pump(kLongPressTimeout + kPressTimeout);
          await gesture.up();
          if (kind == PointerDeviceKind.mouse) await gesture.removePointer();
          await settle(tester, rounds: 3);

          final selected = find
              .byKey(ValueKey('homeSelectedMarker_$selectionId'))
              .evaluate()
              .isNotEmpty;
          if (selected) problems.add('$where: the hold selected the card');
          if (find.byKey(ValueKey(key)).evaluate().isEmpty) {
            problems.add('$where: the buttons went away');
          }
          // 押したボタンの働き：コピーは知らせ、復元・完全削除は確かめる
          // ダイアログ。
          final ran = index == 0
              ? find.text(l10n.homeCopiedSnackbar(1)).evaluate().isNotEmpty
              : find.byType(AlertDialog).evaluate().isNotEmpty;
          if (!ran) problems.add('$where: the button did not run');

          // 後片付け：ダイアログは「キャンセル」で閉じ、選択は終える。
          final cancel = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.commonCancel),
          );
          if (cancel.evaluate().isNotEmpty) {
            await tester.tap(cancel.first);
            await settle(tester, rounds: 3);
          }
          if (selected) {
            await tester.tap(
              find.byTooltip(l10n.homeSelectionAllDeselect).first,
            );
            await settle(tester, rounds: 3);
          }
          // コピーの知らせが消えるのを待つ（次のコピーの知らせと見分ける）。
          for (
            var i = 0;
            i < 80 && find.byType(SnackBar).evaluate().isNotEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    // カードのボタン以外の所の長押しは、これまでどおりカードを選ぶ。
    final title = find.text('海辺のスケッチ', skipOffstage: false);
    await tester.scrollUntilVisible(
      title,
      -80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.longPress(title);
    await settle(tester, rounds: 3);
    expect(
      find.byKey(ValueKey('homeSelectedMarker_trash_project:$workId')),
      findsOneWidget,
    );
    expect(service.trash.map((p) => p.id), contains(workId));
    expect(service.trashedFolders.single.folder.id, folderId);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
