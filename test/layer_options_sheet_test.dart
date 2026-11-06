import 'helpers/project_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// レイヤーの詳細設定シートで続けて変えた設定が互いに打ち消し合わないこと
/// （以前は開いた時点のレイヤーを元に更新していたため、不透明度を変えてから
/// ロックすると不透明度が元に戻り、スライダーのつまみも動かなかった）。
void main() {
  useTemporaryProjectStorage();
  testWidgets('不透明度を変えてからロックしても不透明度が残る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = (await tester.runAsync(buildAppProviders))!;

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final service = tester
        .element(find.byType(Scaffold))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => service.createProject(
        name: 'layer-options-sheet',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final sceneId = service.scenesOf(project.id).first.id;

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 700,
                child: LayerPanel(
                  onClose: () {},
                  projectId: project.id,
                  sceneId: sceneId,
                  frameIndex: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    model() => service.layersOf(project.id, sceneId, 0).first;
    expect(model().opacity, 100);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    final opacityRow = find.ancestor(
      of: find.text(l10n.layerPanelOpacityLabel),
      matching: find.byType(LabeledSlider),
    );
    final minus = find.descendant(
      of: opacityRow,
      matching: find.byIcon(Icons.remove_circle_outline),
    );
    await tester.tap(minus);
    await tester.pump();
    await tester.tap(minus);
    await tester.pump();
    // The slider follows: its value reads 98%.
    expect(
      find.descendant(of: opacityRow, matching: find.text('98%')),
      findsOneWidget,
    );
    expect(model().opacity, 98);

    final lock = find.widgetWithText(SwitchListTile, l10n.layerPanelLockLabel);
    await tester.ensureVisible(lock);
    await tester.pumpAndSettle();
    await tester.tap(lock);
    await tester.pumpAndSettle();
    expect(model().isLocked, isTrue);
    expect(model().opacity, 98);
  });
}
