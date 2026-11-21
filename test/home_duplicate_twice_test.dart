import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

// 複製・貼り付けを素早く2回押したとき。
// - 「複製」は、1つ目の複製が素材を写している間にもう一度押しても、
//   2つの複製に別の名前を付ける（以前は同じ名前が2つできた）。
// - 「貼り付け」は、1回目が始まる前（確認や書き出したファイルの読み込みを
//   待っている間）にもう一度押しても、1回だけ貼り付ける。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 素材の写し・保存は本物のファイルの読み書きで、偽の時計の下では
  // runAsyncを呼ぶまで終わらない（1つ目の複製が写している途中のまま）。
  Future<void> addMaterial(HomeClipboardHarness home, String projectId) async {
    final materials = Directory(
      '${home.dir.path}/niarim/projects/$projectId/Materials',
    )..createSync(recursive: true);
    File('${materials.path}/m1.png').writeAsBytesSync(List.filled(4096, 1));
    File(
      '${materials.path}/materials.json',
    ).writeAsStringSync('{"nextCounter":1,"materials":[]}');
  }

  testWidgets('Duplicate from the card menu twice while the first copy is '
      'still copying gives two names', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final apple = await home.addWork('apple');
    await addMaterial(home, apple.id);
    final duplicate = home.l10n.themeDuplicateAction;
    await home.chooseFromCardMenu('apple', duplicate);
    await home.settle();
    await home.chooseFromCardMenu('apple', duplicate);
    await home.waitFor(() => home.projects.projects.length == 3);
    await home.settleIo(3);
    final names = home.projects.projects.map((p) => p.name).toList();
    expect(names, hasLength(3));
    expect(names.toSet(), {'apple', 'apple (copy)', 'apple (copy 2)'});
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Duplicate on a received work twice while the first copy is '
      'still copying gives two names', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final walk = await home.addReceived('Walk');
    await addMaterial(home, walk.id);
    await home.showTab(2);
    final menu = find.byKey(ValueKey('receivedShareMenu_${walk.id}'));
    for (var i = 0; i < 2; i++) {
      await tester.tap(menu);
      await home.settle();
      await tester.tap(find.text(home.l10n.themeDuplicateAction).last);
      await home.settle();
    }
    await home.waitFor(() => home.projects.shared.length == 3);
    await home.settleIo(3);
    final names = home.projects.shared.map((p) => p.name).toList();
    expect(names, hasLength(3));
    expect(names.toSet(), {'Walk', 'Walk (copy)', 'Walk (copy 2)'});
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Duplicate on the project detail screen twice while the first '
      'copy is still copying gives two names', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final apple = await home.addWork('apple');
    await addMaterial(home, apple.id);
    final duplicate = home.l10n.themeDuplicateAction;
    appRouter.push('/project/${apple.id}');
    await home.settleIo(3);
    await home.settle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await home.settle();
      await tester.tap(find.text(duplicate).last);
      await home.settle();
    }
    await home.waitFor(() => home.projects.projects.length == 3);
    await home.settleIo(3);
    final names = home.projects.projects.map((p) => p.name).toList();
    expect(names, hasLength(3));
    expect(names.toSet(), {'apple', 'apple (copy)', 'apple (copy 2)'});
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 1回目の貼り付けが素材を写している間の2回目（以前から1回だけ）。
  testWidgets('Paste pressed twice on the Projects tab makes one copy', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final apple = await home.addWork('apple');
    await addMaterial(home, apple.id);
    await home.copy(['apple']);
    await tester.tap(home.pasteButton);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(home.pasteButton, warnIfMissed: false);
    await home.waitFor(() => home.projects.projects.length >= 2);
    await home.settleIo(6);
    expect(home.projects.projects.map((p) => p.name).toSet(), {
      'apple',
      'apple (copy)',
    });
    expect(home.projects.projects, hasLength(2));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Paste of a copied works folder pressed twice makes one copy', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      language: 'en',
      exports: ['clip.mp4'],
    );
    final works = tester
        .element(find.byType(Scaffold).first)
        .read<WorkFolderService>();
    final folder = (await tester.runAsync(() => works.createFolder('Clips')))!;
    await tester.runAsync(() => works.moveFileToFolder('clip.mp4', folder.id));
    await home.showTab(1);
    await tester.longPress(find.text('Clips').first);
    await home.settle();
    await home.copySelection();
    // 1回目は書き出したファイルを読み込んでいる（偽の時計では終わらない）。
    await tester.tap(home.pasteButton);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(home.pasteButton, warnIfMissed: false);
    await home.waitFor(() => works.folders.length >= 2);
    await home.settleIo(10);
    expect(works.folders.map((f) => f.name).toList()..sort(), [
      'Clips',
      'Clips (copy)',
    ]);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 確認のダイアログが出るまでの間の2回目（以前から1回だけ）。
  testWidgets('Paste into the Trash pressed twice asks once', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    await home.addWork('apple');
    await home.copy(['apple']);
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await tester.tap(home.pasteButton, warnIfMissed: false);
    await home.settle();
    expect(find.byKey(const Key('homePasteToTrashDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
    await home.waitFor(() => home.projects.trash.length == 1);
    await home.settle();
    expect(find.byKey(const Key('homePasteToTrashDialog')), findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
