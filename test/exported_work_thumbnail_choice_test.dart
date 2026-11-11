import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/exported_work_thumbnail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Export covers persist without modifying source file bytes', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('export_cover_test_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final original = File('${temp.path}/animation.png')
      ..writeAsBytesSync([1, 2, 3, 4]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    await ExportedWorkCoverStore.write(
      original, mode: 'none');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'none');
    expect(await ExportedWorkCoverStore.displayPath(original), isNull);
    expect(await original.readAsBytes(), [1, 2, 3, 4]);
    await ExportedWorkCoverStore.write(
      original, mode: 'latest');
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
    expect(await ExportedWorkCoverStore.displayPath(original), original.path);
    // An external overwrite must not retain an obsolete selected cover.
    original.writeAsBytesSync([1, 2, 3, 4, 5]);
    expect((await ExportedWorkCoverStore.read(original))['mode'], 'latest');
  });

  testWidgets('Exported card exposes a three-dot thumbnail action', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      ExportedWorkCard(
        name: 'movie.mp4',
        metadata: '2026/11/11',
        icon: Icons.movie,
        moveLabel: '移動',
        shareLabel: '共有',
        deleteLabel: '削除',
        onOpen: () {},
        onMove: () {},
        onShare: () {},
        onDelete: () {},
        onChangeThumbnail: () {},
      ),
    )));
    final menu = find.byKey(const Key('exportedWorkMoreMenu'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('サムネイル変更'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
