import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
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
      if (covers) {
        await tester.binding.handlePopRoute();
        await settle(tester, 4);
        expect(canvasIsOnTop(tester), isTrue);
        expect(tester.takeException(), isNull);
      }
    });
  }

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
    // 一番下の「追加する」まで送って押せる位置に出せる。
    final add = find.text("Ajouter aux filtres d'effet");
    await tester.ensureVisible(add);
    await tester.pump();
    expect(tester.getRect(add).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
