// PC/DeXモードのキャンバスのドックで、窓の題・レイヤーの窓の操作の名前・
// スタンプの名前を「…」で切らない（DISC148）。
//
// 簡体字・ドック200pxで、レイヤーの窓の操作の名前が「新…」「导…」、色の窓の
// 題が「取…」と切れ、文字2倍ではスタンプの名前「三角形」が「三…」と切れて
// いた。所有者の判断3：名前が入らなければアイコン（名前は長押し・ホバーの
// 吹き出しと読み上げ）。文字は縮めない・省略記号で切らない。
//
// 7言語×ドックの幅200/280px×文字1.0/2.0で、
// - ドックの窓の題（色・レイヤー・ツールの設定）が「…」で切れない（入らない
//   ときは窓のアイコンを出し、題を吹き出しと読み上げで伝える）、
// - レイヤーの窓の4つの操作（普通のレイヤー・フォルダ・ほかを追加・画像を
//   読み込む）の名前が「…」で切れない（入らないときはアイコンのボタンで、
//   名前を吹き出しと読み上げで伝える）、
// - ツールの設定の「スタンプ」のタブのスタンプの名前が「…」で切れない、
// ことを見る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

String _plain(String text) =>
    text.replaceAll('⁠', '').replaceAll('​', '').replaceAll(' ', ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_pc_dock_labels_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [name]の文（段落）が「…」で切れずに出ているか、[name]を吹き出しに持つ
  /// もの（アイコン）があり、読み上げで[name]を伝えるか。どちらでもなければ
  /// 問題の文。[scope]の中だけを見る。
  String? shownOrIcon(WidgetTester tester, Finder scope, String name) {
    final paragraphs = [
      for (final e
          in find
              .descendant(of: scope, matching: find.byType(RichText))
              .evaluate())
        if (e.renderObject case final RenderParagraph p
            when _plain(p.text.toPlainText(includeSemanticsLabels: false)) ==
                name)
          p,
    ];
    for (final p in paragraphs) {
      if (p.didExceedMaxLines) {
        return '「$name」is cut with an ellipsis (${p.size.width.toStringAsFixed(0)}px)';
      }
      final full = p.getMaxIntrinsicWidth(double.infinity);
      if (p.maxLines == 1 && full > p.size.width + 0.5) {
        return '「$name」is cut (${full.toStringAsFixed(0)}px in '
            '${p.size.width.toStringAsFixed(0)}px)';
      }
    }
    if (paragraphs.isNotEmpty) return null;
    final tooltip = find.descendant(of: scope, matching: find.byTooltip(name));
    if (tooltip.evaluate().isEmpty) {
      return '「$name」is neither shown nor an icon';
    }
    // 読み上げ：意味の木のどこかの節の名前か吹き出しの文に[name]がある。
    var announced = false;
    bool visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.label.contains(name) || data.tooltip.contains(name)) {
        announced = true;
        return false;
      }
      node.visitChildren(visit);
      return !announced;
    }

    final root =
        tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
    // 子の持ち主ごとの意味の木（ビューごと）も見る。
    for (final view in tester.binding.renderViews) {
      final node = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (node != null && !announced) visit(node);
    }
    if (!announced) return '「$name」(icon) is not announced';
    return null;
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('PC dock titles, layer actions and stamp names are not cut '
        '($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final semantics = tester.ensureSemantics();
      final problems = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final dock in [200.0, 280.0]) {
          for (final scale in [1.0, 2.0]) {
            final at = 'dock${dock.toInt()} x$scale';
            appRouter.go('/home');
            SharedPreferences.setMockInitialValues({
              firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
              'first_launch': false,
              'language': tag.replaceAll('-', '_'),
              'force_pc_mode': 1,
              'desktop_panel_width': dock,
              'desktop_tool_panel_width': dock,
            });
            tester.view.physicalSize = const Size(1280, 800);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final root = GlobalKey();
            final providers = (await tester.runAsync(buildAppProviders))!;
            await tester.pumpWidget(
              RepaintBoundary(
                key: root,
                child: MultiProvider(
                  providers: providers,
                  child: const NiarimApp(),
                ),
              ),
            );
            await settle(tester, 4);
            final service = tester
                .element(find.byType(HomeScreen))
                .read<ProjectService>();
            late String id;
            await tester.runAsync(() async {
              final project = await service.createProject(
                name: 'Dock',
                fps: 2,
                durationSeconds: 1,
                backgroundColor: 0xFFFFFFFF,
                exportWidth: 160,
                exportHeight: 90,
              );
              id = project.id;
            });
            appRouter.push('/canvas/$id');
            await settle(tester, 12);
            final screen = find.byType(MaterialApp);
            // 窓の題。
            for (final title in [
              l10n.workspaceDockPanelColorPicker,
              l10n.workspaceDockPanelLayer,
            ]) {
              final problem = shownOrIcon(tester, screen, title);
              if (problem != null) problems.add('$at window title $problem');
            }
            // レイヤーの窓の操作。
            final layers = find.byType(LayerPanel);
            if (layers.evaluate().isEmpty) {
              problems.add('$at: no layer window');
            } else {
              for (final name in [
                l10n.layerPanelNewLayerButton,
                l10n.layerPanelNewFolderButton,
                l10n.layerPanelAddTooltip,
                l10n.layerPanelImportImageButton,
              ]) {
                final problem = shownOrIcon(tester, layers, name);
                if (problem != null) problems.add('$at layer action $problem');
              }
            }
            // ツールの設定のスタンプのタブ。
            final stampTab = [
              ...find.text(l10n.penSubToolTabStamp).evaluate(),
              ...find.byTooltip(l10n.penSubToolTabStamp).evaluate(),
            ];
            if (stampTab.isEmpty) {
              problems.add('$at: no stamp tab');
            } else {
              await tester.tap(
                find.byElementPredicate((e) => e == stampTab.first),
              );
              await settle(tester, 3);
              final stamps = find.byType(StampPanel);
              final names = tester
                  .element(stamps)
                  .read<StampService>()
                  .stamps
                  .map((s) => s.name)
                  .toSet();
              var seen = 0;
              for (final e
                  in find
                      .descendant(of: stamps, matching: find.byType(RichText))
                      .evaluate()) {
                final p = e.renderObject;
                if (p is! RenderParagraph) continue;
                final shown = _plain(
                  p.text.toPlainText(includeSemanticsLabels: false),
                );
                if (!names.contains(shown)) continue;
                seen++;
                if (p.didExceedMaxLines) {
                  problems.add('$at stamp name「$shown」is cut with an ellipsis');
                }
              }
              if (seen == 0) problems.add('$at: no stamp names seen');
            }
            if (shots != null) {
              await tester.runAsync(() async {
                final boundary =
                    root.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC148-$tag-${dock.toInt()}_x'
                  '${scale.toString().replaceAll('.', '')}.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
            for (final error in errors) {
              problems.add('$at ${error.split('\n').first}');
            }
            errors.clear();
            await tester.pumpWidget(const SizedBox.shrink());
            await settle(tester, 2);
          }
        }
      } finally {
        FlutterError.onError = onError;
        semantics.dispose();
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
