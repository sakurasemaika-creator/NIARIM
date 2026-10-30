import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// テーマ・外観の「アクセントの文字・アイコン色」は、背景の上に差し色で
/// 描く文字・アイコンのすべてに効く。差し色とは別の色を選んだテーマで、
/// 引き出しのアイコン、テーマの見本一覧（作品広場・プロジェクト一覧・
/// プロジェクト詳細の模型）、プロジェクト詳細のループ、セーブスロットの
/// 削除がその色で描かれ、
/// 塗り（引き出しの見出し・タブの下線）は差し色のままであることを見張る。
void main() {
  const accent = Color(0xFF2E6B5E);
  const accentText = Color(0xFF8A1538);
  final preset = AppThemePreset.defaultLight.copyWith(
    id: 'custom_accent_text_screens',
    accentColor: accent,
    accentTextColor: accentText,
  );

  Future<ProjectService> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'theme_current_json': jsonEncode(preset.toJson()),
    });
    final dir = Directory.systemTemp.createTempSync('accent-text-screens-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(HomeScreen)).read<ProjectService>();
  }

  Iterable<Color?> iconColors(Finder within) => within.evaluate().isEmpty
      ? const []
      : find
            .descendant(of: within, matching: find.byType(Icon))
            .evaluate()
            .map((e) => (e.widget as Icon).color);

  Color? textColor(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style?.color;

  testWidgets('drawer icons use it, the drawer header keeps the accent', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    final colors = iconColors(drawer).toList();
    expect(colors.where((c) => c == accentText), isNotEmpty);
    expect(colors, isNot(contains(accent)));
    // 見出しは差し色の塗り。
    expect(
      find.descendant(
        of: drawer,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == accent,
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('the theme samples use it for text and icons', (tester) async {
    await open(tester);
    appRouter.push('/settings/theme');
    await tester.pumpAndSettle();
    // 設定の縮小見本（プロジェクト一覧）：選択中のタブ名。
    final thumbnail = find.byType(ThemePreviewThumbnail);
    final tab = find.descendant(of: thumbnail, matching: find.text('プロジェクト'));
    expect(textColor(tester, tab.first), accentText);

    await tester.tap(find.byKey(const Key('themePreviewOpen')));
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(
      find.byKey(const Key('themePreviewPager')),
    );
    // 作品広場：選択中のタブ名。
    final community = themePreviewEntries.indexWhere(
      (e) => e.id == 'community',
    );
    pager.controller!.jumpToPage(community);
    await tester.pumpAndSettle();
    expect(textColor(tester, find.text('新着').first), accentText);
    // プロジェクト詳細：オンのループ。
    final detail = themePreviewEntries.indexWhere((e) => e.id == 'detail');
    pager.controller!.jumpToPage(detail);
    await tester.pumpAndSettle();
    final loop = find.descendant(
      of: find.byKey(const Key('themePreviewDetailLoopButton')),
      matching: find.byType(Icon),
    );
    expect(tester.widget<Icon>(loop).color, accentText);
  });

  testWidgets('the project detail loop button uses it when on', (tester) async {
    final service = await open(tester);
    late final String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'ループ',
        backgroundColor: 0xFFFFFFFF,
        fps: 2,
        durationSeconds: 1,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
    });
    appRouter.push('/project/$id');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    Color? loopColor() => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('projectDetailLoopButton')),
            matching: find.byType(Icon),
          ),
        )
        .color;
    // 既定はループ再生オフ。オンにするとこの色。
    expect(loopColor(), isNot(accentText));
    await tester.tap(find.byKey(const Key('projectDetailLoopButton')));
    await tester.pump();
    expect(loopColor(), accentText);
  });

  testWidgets('the save slot delete icon uses it', (tester) async {
    final service = await open(tester);
    late final String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'スロット',
        backgroundColor: 0xFFFFFFFF,
        fps: 2,
        durationSeconds: 1,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
      final saves = tester
          .element(find.byType(HomeScreen))
          .read<SaveTreeService>();
      await saves.saveToSlot(
        projectId: id,
        slotIndex: 0,
        project: project,
        scenes: service.scenesOf(id),
        tileManager: service.tileManagerOf(id),
      );
    });
    appRouter.push('/save-tree/$id');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final delete = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'このスロットを削除',
    );
    expect(delete, findsWidgets);
    // 保存のあるスロット1の削除はこの色、書き込みは中立色のまま。
    expect(
      (tester.widget<IconButton>(delete.first).icon as Icon).color,
      accentText,
    );
  });
}
