import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// レイヤーパネル上部の4ボタン（新規レイヤー・新規フォルダ・追加・画像読込）が
/// **1文字ずつ縦に折り返さない**ことを検証する。
///
/// 4つをExpandedで等分するため、標準的な端末幅（360dp、パネルは約250dp）では
/// 1ボタンあたり約60dpしかない。日本語ラベルはそのままだと1文字ずつ改行され、
/// 6行の縦棒のような塊になって読めなくなる（`build/dialog-screenshots/`の
/// レイヤーパネルを目視して発覚。既存の
/// `build/visual-reaudit/canvas-panels/03_layer_panel.png`にも同じ状態が
/// 写っていたが気付かれていなかった）。
void main() {
  testWidgets('レイヤーパネル上部のボタンラベルが1行に収まる', (tester) async {
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
        name: 'layer-panel-row',
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
              // 実機でパネルが開く幅に近い250dpで載せる。
              body: SizedBox(
                width: 250,
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
    expect(tester.takeException(), isNull);

    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    var checked = 0;
    for (final label in [
      l10n.layerPanelNewLayerButton,
      l10n.layerPanelNewFolderButton,
      l10n.layerPanelAddTooltip,
      l10n.layerPanelImportImageButton,
    ]) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) continue;
      checked++;
      final size = tester.getSize(finder.first);
      // fontSize 11 なので1行なら高さは20px程度。2行以上になっていれば
      // （まして1文字ずつ縦に並んでいれば）ここで確実に落ちる。
      expect(
        size.height,
        lessThan(26),
        reason:
            '"$label" が${size.height.toStringAsFixed(0)}pxの高さになっている'
            '（折り返している）',
      );
    }
    expect(checked, 4, reason: '4つのボタンラベルが見つからない');

    // レイヤー名も同じ理由で縦積みになっていた（既定名「レイヤー1」が
    // 1文字ずつ4行に積まれ、行の高さが3倍になっていた）。ListTileの
    // leading/trailingに幅を取られて名前へ約30dpしか残らないのが原因。
    // 余白を詰めたうえで1行に省略する形にしてある。
    final layerName = l10n.layerPanelDefaultLayerName(1);
    final nameFinder = find.text(layerName);
    expect(nameFinder, findsOneWidget, reason: 'レイヤー名が見つからない');
    final nameSize = tester.getSize(nameFinder);
    expect(
      nameSize.height,
      lessThan(26),
      reason:
          'レイヤー名が${nameSize.height.toStringAsFixed(0)}pxの高さになっている'
          '（縦に折り返している）',
    );
    // 省略記号だらけにならず、名前が読める幅を確保できていること。
    expect(
      nameSize.width,
      greaterThan(40),
      reason:
          'レイヤー名の表示幅が${nameSize.width.toStringAsFixed(0)}pxしかない'
          '（アイコン群に押し出されて名前がほぼ省略記号になる）',
    );
  });
}
