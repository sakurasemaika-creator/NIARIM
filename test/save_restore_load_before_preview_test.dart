// 保存から読み込むときの確かめ：保存を読めたら、絵ができる前でも「読み込む」を
// 押せる。
//
// 実際に使ってみたとき（2026-11-27）、読み込みのボタンが、絵が出るまで約3秒
// 押せなかった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/widgets/save_restore_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();

  testWidgets('load is enabled once the save is read', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    final ps = context.read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'restore-early',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    ))!;
    final data = NiaproData(
      project: project,
      scenes: ps.scenesOf(project.id),
      tileData: const {},
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    NiaproData? chosen;
    var closed = false;
    confirmSavedVersion(
      context,
      projectId: project.id,
      read: () async => data,
      name: 'save',
    ).then((value) {
      chosen = value;
      closed = true;
    });
    // The preview needs real rendering (it does not finish under the test's
    // fake clock); the save itself is already read.
    await tester.pump();
    await tester.pump();
    final load = find.widgetWithText(FilledButton, l10n.saveTreeRestoreAction);
    expect(tester.widget<FilledButton>(load).onPressed, isNotNull);
    await tester.tap(load);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(closed, isTrue);
    expect(chosen, same(data));
  });
}
