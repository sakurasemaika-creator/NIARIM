// キャンバスモードのバー類が「自前の背景を持たない」状態を守る。
//
// 上部バー・太さ/不透明度スライダー・ツールバー・折りたたみハンドルは、
// アイコンだけがキャンバスの上に浮かんでいる意匠（canvas_icon_button.dart）。
// ところがこれらはキャンバスのStackの外側（Columnの別の行）に置かれている
// ため、透過した先に見えるのはキャンバス外周ではなくScaffold本来の背景色に
// なる。結果、バーの帯だけが明るい別パネルのように見える不具合が過去に
// 2度発生している（Task#163で一度ツールバー側へ外周色を塗って対処したが、
// その後の変更で透明へ戻り再発した）。
//
// 正しい形は「バーは透明のまま・Scaffoldの背景をキャンバス外周色に揃える」。
// テストが緑でも見た目の後退は起きるので、両側をここで機械的に見張る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart'
    show kCanvasOutsideColor;
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_canvas_bar_transparency_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() => appDocs.createSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => appDocs.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('キャンバス画面のバーは背景を持たず、その背後はキャンバス外周色である', (tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = (await tester.runAsync(buildAppProviders))!;
    ProjectService? ps;
    StateSetter? rebuildHost;
    String? projectId;

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                ps ??= context.read<ProjectService>();
                rebuildHost = setState;
                if (projectId == null) return const SizedBox.expand();
                return CanvasScreen(projectId: projectId);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final project = (await tester.runAsync(
      () => ps!.createProject(
        name: 'canvas-bar-transparency',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 320,
      ),
    ))!;
    projectId = project.id;
    rebuildHost!(() {});
    await tester.pump(const Duration(milliseconds: 1400));

    // 1. Scaffoldの背景がキャンバス外周と同じ色であること。
    //    ここがnull（＝テーマのsurface）へ戻ると、バーの帯だけが明るい
    //    別パネルのように浮いて見える。
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(CanvasScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(
      scaffold.backgroundColor,
      kCanvasOutsideColor,
      reason: 'バーの背後はキャンバス外周と地続きの色であること',
    );

    // 2. ツールバー本体は自前の背景を持たないこと。
    final toolbarBox = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ToolbarWidget),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      toolbarBox.color,
      Colors.transparent,
      reason: 'ツールバーへ背景色を塗らないこと（Scaffold側の色を透かす）',
    );
  });

  test('バー類のソースへ不透明な背景色が入り込んでいない', () {
    // 過去2回とも「バー側へ色を塗る」形で再発しているので、ソースの側でも
    // 見張る。kCanvasOutsideColorをバーの背景として塗り直す変更が入ったら
    // ここで落ちる（Scaffoldの背景で揃える方針から外れるため）。
    final sources = {
      'lib/screens/canvas/widgets/toolbar_widget.dart': null,
      'lib/screens/canvas/widgets/brush_size_slider.dart': null,
    };
    for (final path in sources.keys) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('color: kCanvasOutsideColor'),
        isFalse,
        reason: '$path はバー自身に背景を塗らないこと（Scaffoldの背景で揃える）',
      );
      expect(
        source.contains('color: Colors.transparent'),
        isTrue,
        reason: '$path の背景はColors.transparentであること',
      );
    }
  });
}
