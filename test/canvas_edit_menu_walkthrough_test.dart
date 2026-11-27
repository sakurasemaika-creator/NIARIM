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
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/color_adjust_sheet.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/filter_display_name.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:niarim/widgets/filter_sample_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// キャンバスの「設定/編集」メニューの全項目を、スマホの幅で1つずつ開いて
/// 撮る（`build/canvas-edit-menu/`）。どの項目も例外を出さずに開き、
/// 画面を移る項目はキャンバスへ戻れること、メニューの中で選ぶ項目
/// （自動塗り確認表示）は選んだ値がその場で見えることを見張る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final out = Directory('build/canvas-edit-menu');
  late Directory tempDir;

  setUpAll(() => out.createSync(recursive: true));

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_edit_menu_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final rootKey = GlobalKey();

  // ファイルの読み書き・合成のような本物の非同期の処理を実時間で待つ。
  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
      image.dispose();
    });
  }

  Future<void> openMenu(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    await settle(tester, 4);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: '編集メニュー',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    appRouter.push('/canvas/$id');
    await settle(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester, 3);
  }

  Future<void> tapEntry(WidgetTester tester, String label) async {
    final entry = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.ensureVisible(entry);
    await tester.pump();
    await tester.tap(entry);
    await settle(tester, 8);
  }

  bool canvasIsOnTop(WidgetTester tester) => ModalRoute.of(
    tester.element(find.byType(CanvasScreen, skipOffstage: false)),
  )!.isCurrent;

  // メニューのシート（資料ウィンドウの項目を含むシート）が閉じていること。
  // 背景色・自動操作は、メニューを閉じてから自分のシートを開く。
  Finder menuSheet() => find.ancestor(
    of: find.text('資料ウィンドウ', skipOffstage: false),
    matching: find.byType(BottomSheet, skipOffstage: false),
  );

  testWidgets(
    'the first PC filter opening starts at the list with no preview',
    (tester) async {
      await openMenu(tester, size: const Size(1280, 800));
      await tapEntry(tester, 'フィルター');
      final panel = find.byType(FilterPanel);
      expect(panel, findsOneWidget);
      final context = tester.element(panel);
      final l10n = AppLocalizations.of(context)!;
      final service = context.read<FilterService>();
      expect(service.currentFilter, isNull);
      // 一覧の先頭のカード（NIARIMならではのフィルターが先に並ぶ）。
      expect(
        find.descendant(
          of: panel,
          matching: find.text(
            filterDisplayName(l10n, service.galleryFilters.first),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<CanvasArea>(find.byType(CanvasArea)).currentLayerPreview,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the menu itself', (tester) async {
    await openMenu(tester);
    await capture(tester, '00_menu');
    // 一番下まで送った所も撮る（項目が画面に収まらない端末がある）。
    await tester.ensureVisible(find.text('資料ウィンドウ'));
    await tester.pump();
    await capture(tester, '00_menu_bottom');
    expect(tester.takeException(), isNull);
  });

  testWidgets('autofill check view shows the chosen mode at once', (
    tester,
  ) async {
    await openMenu(tester);
    await tester.tap(find.text('通常表示'));
    await settle(tester, 3);
    await tester.tap(find.text('パーツ分け確認').last);
    await settle(tester, 3);
    await capture(tester, '01_autofill_check');
    // メニューの中の表示がその場で変わる（メニューを作り直さないと前の値の
    // ままだった）。
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('パーツ分け確認'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.palette_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // covers：キャンバスの上に別の画面・シート・ダイアログを開く項目。
  // 戻る操作でキャンバスへ戻れること。
  for (final (index, label, covers) in [
    (2, '自動塗り設定', true),
    (3, '背景切替', false),
    (4, '背景色', true),
    (5, 'オニオンスキン', false),
    (6, '自動操作', true),
    (7, 'フィルター', false),
    (8, 'フレーム複数選択', false),
    (9, '筆圧カーブ', true),
    (10, '自由変形・メッシュ変形', false),
    (11, '色調調整', false),
    (12, '資料ウィンドウ', false),
  ]) {
    testWidgets('$label opens without errors', (tester) async {
      await openMenu(tester);
      await tapEntry(tester, label);
      final name = '${index.toString().padLeft(2, '0')}_$label';
      await capture(tester, name);
      expect(tester.takeException(), isNull);
      expect(menuSheet(), findsNothing);
      expect(canvasIsOnTop(tester), !covers);
      if (label == '色調調整') {
        // The common focus menu owns the bounded floating surface; the
        // real canvas remains the preview instead of a separate image popup.
        expect(
          find.byKey(const ValueKey('color-adjust-focus-menu')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('color-adjust-bottom-bar')),
          findsOneWidget,
        );
        final panel = tester.getRect(find.byType(ColorAdjustSheet));
        expect(panel.width, closeTo(360, 1));
        expect(find.widgetWithText(FilledButton, '適用'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'キャンセル'), findsOneWidget);
      }
      if (covers) {
        await tester.binding.handlePopRoute();
        await settle(tester, 4);
        expect(canvasIsOnTop(tester), isTrue);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'color adjustment previews live on canvas; cancel restores, apply saves',
    (tester) async {
      await openMenu(tester);
      final ps = tester
          .element(find.byType(CanvasScreen))
          .read<ProjectService>();
      final project = ps.projects.firstWhere((p) => p.name == '編集メニュー');
      final scene = ps.scenesOf(project.id).first;
      final layer = scene.frames.first.layers.first;
      final pixels = Uint8List(160 * 90 * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels[i] = 220;
        pixels[i + 1] = 110;
        pixels[i + 2] = 80;
        pixels[i + 3] = 255;
      }
      ps.replaceLayerPixels(
        projectId: project.id,
        sceneId: scene.id,
        frameIndex: 0,
        layerId: layer.id,
        pixels: pixels,
      );
      await tapEntry(tester, '色調調整');
      expect(
        find.byKey(const ValueKey('color-adjust-bottom-bar')),
        findsOneWidget,
      );

      final slider = find.descendant(
        of: find.byType(ColorAdjustSheet),
        matching: find.byType(LabeledSlider),
      );
      expect(slider, findsNWidgets(3));
      await settle(tester, 7);

      // Brightness is the second slider. It must send an actual canvas preview,
      // not change a dedicated 120x120 image in a popup.
      tester.widget<LabeledSlider>(slider.at(1)).onChanged?.call(-70);
      await settle(tester, 12);
      await capture(tester, '11b_color_adjust_live_canvas_darkened');
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await settle(tester, 5);
      expect(find.byType(ColorAdjustSheet), findsNothing);
      await capture(tester, '11c_color_adjust_cancel_restores_canvas');

      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester, 3);
      await tapEntry(tester, '色調調整');
      await settle(tester, 6);
      final second = find.descendant(
        of: find.byType(ColorAdjustSheet),
        matching: find.byType(LabeledSlider),
      );
      tester.widget<LabeledSlider>(second.at(1)).onChanged?.call(-70);
      await settle(tester, 10);
      await tester.tap(find.widgetWithText(FilledButton, '適用'));
      await settle(tester, 6);
      expect(find.byType(ColorAdjustSheet), findsNothing);
      await capture(tester, '11d_color_adjust_apply_saved_canvas');

      final key = ps.tileKeyFor(project.id, scene.id, 0, layer.id);
      final raw = await tester.runAsync(() async {
        final rendered = await ps
            .tileManagerOf(project.id)
            .compositeLayerToImage(key);
        try {
          return await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          rendered.dispose();
        }
      });
      expect(raw, isNotNull);
      expect(
        raw!.getUint8(0),
        lessThan(220),
        reason: 'Apply must persist adjusted pixels, not just a preview',
      );
    },
  );

  // 一番長い仏語の文言・文字2倍・320pxでも、色調調整のパネルははみ出さない。
  testWidgets('color adjust fits in French at twice the text size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'fr',
    });
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openMenu(tester, size: const Size(320, 700));
    // メニューの自動塗り確認表示は、選択肢が項目名の下の行に移る。
    await capture(tester, '13_menu_fr_x2');
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Normal')).dy,
      greaterThanOrEqualTo(
        tester
            .getBottomLeft(
              find.text('Affichage de vérification du remplissage auto'),
            )
            .dy,
      ),
    );
    await tapEntry(tester, 'Réglage des couleurs');
    await capture(tester, '14_color_adjust_fr_x2');
    expect(tester.takeException(), isNull);
    // 取り消し・適用はスクロールの外で押せる位置にあり、フィルターとして
    // 残す「追加する」は題の右のメニューから選べる。
    for (final label in ['Annuler', 'Appliquer']) {
      final button = find.text(label).last;
      expect(tester.getRect(button).right, lessThanOrEqualTo(320));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(700));
    }
    await tester.tap(find.byKey(const ValueKey('color-adjust-save-menu')));
    await settle(tester, 3);
    final add = find.text('Ajouter aux filtres d’effet');
    expect(tester.getRect(add).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('color adjustment adds named drawing and timeline filters', (
    tester,
  ) async {
    await openMenu(tester);
    final canvas = tester.element(find.byType(CanvasScreen));
    final l10n = AppLocalizations.of(canvas)!;
    final ps = canvas.read<ProjectService>();
    final filters = canvas.read<FilterService>();
    final project = ps.projects.single;
    final sceneId = ps.scenesOf(project.id).single.id;
    final startSelection = filters.currentFilter?.id;
    final initialCount = filters.filters.length;
    final panel = find.byType(ColorAdjustSheet);
    final dialog = find.byType(AlertDialog);
    final nameField = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );

    Future<void> reopen() async {
      await tester.tap(find.byIcon(Icons.settings));
      await settle(tester, 3);
      await tapEntry(tester, l10n.canvasColorAdjustMenuTitle);
    }

    // フィルターとして残す2つは、パネルの題の右のメニューの中。
    Future<void> prompt(String label) async {
      await tester.tap(
        find.descendant(
          of: panel,
          matching: find.byKey(const ValueKey('color-adjust-save-menu')),
        ),
      );
      await settle(tester, 3);
      await tester.tap(find.text(label).last);
      await settle(tester, 4);
    }

    Future<void> submit(String input, String notice) async {
      await tester.enterText(nameField, input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 5);
      expect(panel, findsNothing);
      expect(find.text(notice), findsOneWidget);
      ScaffoldMessenger.of(canvas).removeCurrentSnackBar();
    }

    await tapEntry(tester, l10n.canvasColorAdjustMenuTitle);
    final sliders = find.descendant(
      of: panel,
      matching: find.byType(LabeledSlider),
    );
    tester.widget<LabeledSlider>(sliders.at(1)).onChanged!.call(-40);
    await settle(tester, 3);
    await prompt(l10n.canvasColorAdjustAddToDrawFilter);
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      contains('${l10n.filterColorAdjustBrightnessLabel} -40'),
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.text(l10n.commonCancel)),
    );
    await settle(tester, 4);
    expect(panel, findsOneWidget);
    expect(filters.filters, hasLength(initialCount));

    await prompt(l10n.canvasColorAdjustAddToDrawFilter);
    await submit('  夜の画面  ', l10n.canvasColorAdjustDrawFilterAdded('夜の画面'));
    await reopen();
    await prompt(l10n.canvasColorAdjustAddToDrawFilter);
    await submit('夜の画面', l10n.canvasColorAdjustDrawFilterAdded('夜の画面 (2)'));
    expect(filters.currentFilter?.id, startSelection);
    final added = filters.filters.skip(initialCount).toList();
    expect(added.map((f) => f.name), ['夜の画面', '夜の画面 (2)']);
    expect(added.first.caBrightness, -40);
    expect(
      filterSamplePixels(added.first),
      isNot(equals(filterSamplePixels(added.last))),
    );

    await reopen();
    await prompt(l10n.canvasColorAdjustAddToEffectFilter);
    await submit('光', l10n.canvasColorAdjustEffectFilterAdded('光'));
    await reopen();
    await prompt(l10n.canvasColorAdjustAddToEffectFilter);
    await submit('光', l10n.canvasColorAdjustEffectFilterAdded('光 (2)'));
    await tester.runAsync(() => ps.saveProject(project.id));
    final restored = ProjectService();
    addTearDown(restored.dispose);
    await tester.runAsync(restored.init);
    final effects = restored.effectFiltersOf(project.id, sceneId);
    expect(effects.map((e) => e.name), ['光', '光 (2)']);
    for (final effect in effects) {
      expect((effect.startFrame, effect.endFrame), (0, 1));
    }

    appRouter.go('/timeline/${project.id}');
    await settle(tester, 8);
    expect(find.text('光'), findsWidgets);
    expect(find.text('光 (2)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // 文字がすべて見えている：行の高さが足りずに2行目が切れていない
  // （固定の高さの行に折り返した文字を入れると「Vérifier la」だけが
  // 見えた）、画面の外へ出ていない。
  void expectFullyShown(WidgetTester tester, Finder text, double width) {
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
      ),
    );
    final rect = tester.getRect(text);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(width));
  }

  // 一番長い仏語・英語の文言・文字2倍・320pxでも、自動塗り確認表示の
  // 選択肢はどれも読めて選べ、選んだ値も切れずに見える。
  for (final (language, longest) in [
    ('fr', 'Vérifier la silhouette'),
    ('en', 'Check silhouette'),
  ]) {
    testWidgets(
      'autofill check choices read in full in $language at twice the size',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          'first_launch': false,
          'language': language,
        });
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openMenu(tester, size: const Size(320, 700));
        final sheet = find.byType(BottomSheet);
        var choice = find.descendant(of: sheet, matching: find.text(longest));
        if (choice.evaluate().isEmpty) {
          // 選択肢がメニューの中に並んでいないとき（ドロップダウン）は
          // 開いてから選ぶ。
          await tester.tap(
            find.descendant(of: sheet, matching: find.text('Normal')),
          );
          await settle(tester, 3);
          choice = find.text(longest).last;
        }
        await tester.ensureVisible(choice);
        await tester.pump();
        expectFullyShown(tester, choice, 320);
        await tester.tap(choice);
        await settle(tester, 3);
        await capture(tester, '15_autofill_check_${language}_x2');
        final shown = find.descendant(of: sheet, matching: find.text(longest));
        expect(shown, findsOneWidget);
        expectFullyShown(tester, shown, 320);
        expect(
          find.descendant(of: sheet, matching: find.byIcon(Icons.contrast)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
