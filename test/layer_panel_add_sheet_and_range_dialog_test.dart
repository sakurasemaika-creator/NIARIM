import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

/// レイヤーパネルの「レイヤーを追加」のシートと、表示範囲のダイアログ。
///
/// * 追加のシートは項目（通常・共通・フォルダ・線画・自動塗り・選択）を
///   スクロールしない列で並べていた。シートは画面の高さの9/16までしか
///   取らないので、低い画面（360x440）では列が105pxはみ出し、下の項目
///   （選択レイヤー等）が縞模様で潰れて選べなかった。
/// * 表示範囲のダイアログ（共通レイヤーの追加・範囲の変更）は、開始・終了の
///   入力欄の`TextEditingController`を`showDialog(...).then()`で破棄していた。
///   `then`はダイアログを閉じた直後（閉じる動きの最中、欄がまだ画面にある
///   うち）に走るので、閉じる間に欄が作り直されると破棄済みの部品を使う。
void main() {
  useTemporaryProjectStorage();
  late List<SingleChildWidget> providers;

  Future<void> boot(WidgetTester tester, Size view) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'language': 'ja',
    });
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    providers = (await tester.runAsync(buildAppProviders))!;
  }

  Widget app(Widget home) => MultiProvider(
    providers: providers,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: context.watch<ThemeService>().themeData,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );

  /// 作品を1つ作り、レイヤーパネルを左上に載せる。
  Future<(ProjectService, String)> showPanel(WidgetTester tester) async {
    await tester.pumpWidget(app(const Scaffold(body: SizedBox.shrink())));
    final projects = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'layers',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    final layer = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((l) => l.type == model.LayerType.normal);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 380,
              child: LayerPanel(
                onClose: () {},
                projectId: project.id,
                sceneId: sceneId,
                frameIndex: 0,
                currentLayerId: layer.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (projects, project.id);
  }

  for (final (label, view, scale) in const [
    ('360x440', Size(360, 440), 1.0),
    ('640x360 (landscape)', Size(640, 360), 1.0),
    ('360x640 text x2', Size(360, 640), 2.0),
  ]) {
    testWidgets('$label: every entry of the add-layer sheet can be reached '
        'and chosen (the sheet scrolls instead of overflowing)', (
      tester,
    ) async {
      await boot(tester, view);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (projects, projectId) = await showPanel(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LayerPanel)),
      )!;
      final sceneId = projects.scenesOf(projectId).first.id;
      int count(model.LayerType type) => projects
          .layersOf(projectId, sceneId, 0)
          .where((l) => l.type == type)
          .length;
      final before = count(model.LayerType.selection);

      await tester.tap(find.byIcon(Icons.library_add).first);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final overflow = tester.takeException();
      expect(
        overflow,
        isNull,
        reason: 'the add-layer sheet overflowed: $overflow',
      );

      // 一番下の「選択レイヤー」まで動かして押せる。
      final last = find.descendant(
        of: sheet,
        matching: find.text(l10n.layerPanelMenuSelectionLayer),
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      final sheetRect = tester.getRect(sheet);
      final lastRect = tester.getRect(last);
      expect(
        sheetRect.top <= lastRect.top && lastRect.bottom <= sheetRect.bottom,
        isTrue,
        reason:
            'the last entry $lastRect is not inside the sheet $sheetRect '
            'after scrolling',
      );
      expect(last.hitTestable(), findsOneWidget);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(count(model.LayerType.selection), before + 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('range dialog: the start/end fields keep a live controller '
      'while the dialog is closing', (tester) async {
    await boot(tester, const Size(360, 780));
    await showPanel(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LayerPanel)))!;
    // 共通レイヤーを追加すると、まず表示範囲のダイアログが開く。
    await tester.tap(find.byIcon(Icons.library_add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.layerPanelMenuCommonLayer));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.pump();

    await tester.tap(find.text(l10n.commonCancel));
    // 閉じる動きの最中（欄はまだ画面にある）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty, reason: 'the dialog is still closing');
    final disposed = <String>[];
    for (final field in fields) {
      try {
        ChangeNotifier.debugAssertNotDisposed(field.controller!);
      } on FlutterError catch (error) {
        disposed.add('${field.decoration?.labelText}: ${error.message}');
      }
    }
    expect(
      disposed,
      isEmpty,
      reason:
          'a field still on screen uses a disposed controller:\n'
          '${disposed.join('\n')}',
    );
    // 閉じる間に欄が作り直されても（画面の大きさが変わる等）落ちない。
    tester.view.physicalSize = const Size(360, 760);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
