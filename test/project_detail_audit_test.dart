import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/color_channels.dart';
import 'helpers/first_use_tooltips.dart';

/// プロジェクト詳細（A009）：名前の変更、ゴミ箱へ移した後の取り消し、
/// プレビューの絵の範囲と背景、早いコマ送りで最後のフレームが出ること、
/// 長い言葉の操作の並び、見つからない作品からホームへ戻れること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_project_detail_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // 合成・ファイルの読み書きのような本物の非同期の処理を実時間で待つ。
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Uint8List solid(int width, int height, Color color) {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = color.red8;
      bytes[i + 1] = color.green8;
      bytes[i + 2] = color.blue8;
      bytes[i + 3] = 255;
    }
    return bytes;
  }

  /// 作品を作って詳細を開く。[colors]を渡すと、フレームごとにその色で塗る。
  Future<({ProjectService service, String id})> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    int background = 0xFFFFFFFF,
    int exportWidth = 64,
    int exportHeight = 32,
    List<Color> colors = const [],
    String language = 'ja',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final service = context.read<ProjectService>();
    if (language != 'ja') {
      await tester.runAsync(
        () => context.read<SettingsService>().setLanguage(language),
      );
    }
    late final String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: '詳細の作品',
        fps: colors.isEmpty ? 1 : colors.length,
        durationSeconds: 1,
        backgroundColor: background,
        exportWidth: exportWidth,
        exportHeight: exportHeight,
      );
      id = project.id;
      final tm = service.tileManagerOf(id);
      final scene = service.scenesOf(id).first;
      for (var i = 0; i < colors.length; i++) {
        service.replaceLayerPixels(
          projectId: id,
          sceneId: scene.id,
          frameIndex: i,
          layerId: service.layersOf(id, scene.id, i).first.id,
          pixels: solid(tm.canvasWidth, tm.canvasHeight, colors[i]),
        );
      }
    });
    appRouter.push('/project/$id');
    await settleIo(tester);
    return (service: service, id: id);
  }

  Finder artwork() => find.byKey(const Key('projectDetailPreviewArtwork'));

  // プレビューに出ている絵の真ん中の色。
  Future<Color> previewColour(WidgetTester tester) async {
    final image = tester
        .widget<RawImage>(
          find.descendant(of: artwork(), matching: find.byType(RawImage)),
        )
        .image!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final x = image.width ~/ 2;
    final y = image.height ~/ 2;
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  testWidgets('rename refuses a blank name, trims it and saves on Enter', (
    tester,
  ) async {
    final s = await open(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('名前変更').last);
    await settle(tester);
    expect(find.byType(NameEntryDialog), findsOneWidget);
    final field = find.descendant(
      of: find.byType(NameEntryDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '   ');
    await tester.pump();
    final change = find.widgetWithText(FilledButton, '変更');
    expect(tester.widget<FilledButton>(change).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byType(NameEntryDialog), findsOneWidget);
    // 空のままEnterを押しても欄から抜けない（抜けると続けて打った字が
    // どこにも入らなかった）。
    expect(
      tester
          .state<EditableTextState>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .widget
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(field, '  新しい名前  ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleIo(tester);
    expect(find.byType(NameEntryDialog), findsNothing);
    expect(s.service.projects.singleWhere((p) => p.id == s.id).name, '新しい名前');
    expect(find.text('新しい名前'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving to the trash from the detail can be undone', (
    tester,
  ) async {
    final s = await open(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動').last);
    await settleIo(tester);
    expect(find.byType(ProjectDetailScreen), findsNothing);
    expect(s.service.trash.map((p) => p.id), [s.id]);
    expect(find.text('元に戻す'), findsOneWidget);
    await tester.tap(find.text('元に戻す'));
    for (var i = 0; i < 40 && s.service.trash.isNotEmpty; i++) {
      await settleIo(tester);
    }
    expect(s.service.trash, isEmpty);
    expect(s.service.projects.map((p) => p.id), contains(s.id));
    expect(tester.takeException(), isNull);
  });

  for (final (name, width, height, background) in [
    ('portrait', 32, 64, 0xFF202020),
    ('landscape', 64, 32, 0xFFFFE0A0),
    ('transparent', 64, 64, 0x00000000),
  ]) {
    testWidgets('the $name preview shows the artwork at its own ratio', (
      tester,
    ) async {
      await open(
        tester,
        exportWidth: width,
        exportHeight: height,
        background: background,
      );
      final rect = tester.getRect(artwork());
      final ratio = width / height;
      // 16:9の枠の中で、絵の縦横比の範囲だけに背景を敷く。
      final box = tester.getRect(
        find.descendant(of: artwork(), matching: find.byType(AspectRatio)),
      );
      expect(box.width / box.height, moreOrLessEquals(ratio, epsilon: 0.02));
      expect(box.width, lessThanOrEqualTo(rect.width + 0.5));
      expect(box.height, lessThanOrEqualTo(rect.height + 0.5));
      final checker = find.descendant(
        of: artwork(),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TransparencyCheckerPainter,
        ),
      );
      // 透明の作品は市松模様、塗った背景は背景の色。
      expect(checker, background >>> 24 == 0 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick seeking ends on the frame chosen last', (tester) async {
    const colours = [
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFDD835),
    ];
    await open(tester, colors: colours);
    expect(await previewColour(tester), colours[0]);
    // 描き終える前に次々と送る（描いている間の要求を捨てると、途中の絵が
    // 残った）。
    final next = find.byTooltip('1フレーム進む');
    for (var i = 0; i < 3; i++) {
      await tester.tap(next);
      await tester.pump();
    }
    await settleIo(tester);
    expect(await previewColour(tester), colours[3]);
    expect(find.textContaining('4/4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the preview redraws after editing on another screen', (
    tester,
  ) async {
    final s = await open(tester, colors: const [Color(0xFFE53935)]);
    expect(await previewColour(tester), const Color(0xFFE53935));
    // 別の画面（キャンバス等）に移っている間に絵が変わる。
    appRouter.push('/settings');
    await settle(tester);
    await tester.runAsync(() async {
      final tm = s.service.tileManagerOf(s.id);
      final scene = s.service.scenesOf(s.id).first;
      s.service.replaceLayerPixels(
        projectId: s.id,
        sceneId: scene.id,
        frameIndex: 0,
        layerId: s.service.layersOf(s.id, scene.id, 0).first.id,
        pixels: solid(tm.canvasWidth, tm.canvasHeight, const Color(0xFF1E88E5)),
      );
    });
    appRouter.pop();
    await settleIo(tester);
    expect(await previewColour(tester), const Color(0xFF1E88E5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the size and save time follow the saved file', (tester) async {
    final s = await open(tester, size: const Size(390, 1400));
    int fileSize() => tempDir
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith('${s.id}.niapro'))
        .lengthSync();
    String shown(int bytes) =>
        bytes < 1024 ? '${bytes}B' : '${(bytes / 1024).toStringAsFixed(1)}KB';
    final created = s.service.projects
        .singleWhere((p) => p.id == s.id)
        .updatedAt;
    // 作ったばかりでも0Bではなく、保存したファイルの大きさ。
    final first = (await tester.runAsync(() async => fileSize()))!;
    expect(first, greaterThan(0));
    expect(find.text(shown(first)), findsOneWidget);
    // 別の画面で描いて保存すると、戻ったときに新しい大きさになる。
    appRouter.push('/settings');
    await settle(tester);
    await tester.runAsync(() async {
      final tm = s.service.tileManagerOf(s.id);
      final scene = s.service.scenesOf(s.id).first;
      final noise = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
      for (var i = 0; i < noise.length; i += 4) {
        noise[i] = (i * 37) & 255;
        noise[i + 1] = (i * 91) & 255;
        noise[i + 2] = (i * 13) & 255;
        noise[i + 3] = 255;
      }
      s.service.replaceLayerPixels(
        projectId: s.id,
        sceneId: scene.id,
        frameIndex: 0,
        layerId: s.service.layersOf(s.id, scene.id, 0).first.id,
        pixels: noise,
      );
      await s.service.saveProject(s.id);
    });
    appRouter.pop();
    await settleIo(tester);
    final second = (await tester.runAsync(() async => fileSize()))!;
    expect(second, isNot(first));
    expect(find.text(shown(second)), findsOneWidget);
    // 最終保存の時刻も、作ったときのままではなく保存した時刻。
    final saved = s.service.projects.singleWhere((p) => p.id == s.id);
    expect(saved.updatedAt.isAfter(created), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels are not broken inside a word', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, size: const Size(320, 700), language: 'fr');
    final labels = [
      'Dossier',
      'Étiquettes',
      'Pas dans les favoris',
      'Partager',
    ];
    for (final label in labels) {
      final finder = find.descendant(
        of: find.byKey(const Key('projectDetailQuickActions')),
        matching: find.text(label),
      );
      expect(finder, findsOneWidget, reason: label);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final text = paragraph.text.toPlainText();
      // 1つの語の文字の箱がすべて同じ行にあれば、語の途中で折れていない。
      for (final match in RegExp(r'\S+').allMatches(text)) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
        final tops = {for (final box in boxes) box.top.round()};
        expect(
          tops,
          hasLength(1),
          reason: '"${match.group(0)}" in "$text" is split',
        );
      }
    }
    // ここまで欄が狭いと、ループは共有のすぐ下の行の右へ下りる。
    final share = tester.getRect(find.text('Partager'));
    final loop = tester.getRect(
      find.byKey(const Key('projectDetailLoopButton')),
    );
    expect(loop.top, greaterThanOrEqualTo(share.bottom - 1));
    expect(loop.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the loop sits right beside Share', (tester) async {
    await open(tester);
    final share = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('projectDetailQuickActions')),
        matching: find.text('共有'),
      ),
    );
    final loop = tester.getRect(
      find.byKey(const Key('projectDetailLoopButton')),
    );
    expect(loop.left, greaterThanOrEqualTo(share.right));
    expect(loop.left - share.right, lessThan(80));
    expect(loop.top < share.bottom && loop.bottom > share.top, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing project offers the way back to the projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    appRouter.go('/project/does-not-exist');
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester);
    expect(find.text('プロジェクトが見つかりません'), findsOneWidget);
    await tester.tap(find.byKey(const Key('projectDetailNotFoundHome')));
    await settle(tester);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      '/home',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tags dialog scrolls, keeps typing and keeps the typed tag', (
    tester,
  ) async {
    final s = await open(tester, size: const Size(320, 560));
    final tagsButton = find.descendant(
      of: find.byKey(const Key('projectDetailQuickActions')),
      matching: find.text('タグ'),
    );
    await tester.ensureVisible(tagsButton);
    await tester.tap(tagsButton);
    await settle(tester);
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    bool typing() => tester
        .state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        )
        .widget
        .focusNode
        .hasFocus;
    for (var i = 0; i < 30; i++) {
      await tester.enterText(field, 'タグ$i');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Enterで足した後も欄に打ち続けられる。
      expect(typing(), isTrue);
    }
    await tester.enterText(field, 'とても長いタグ' * 20);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // タグが多くてもダイアログからはみ出さない。
    expect(tester.takeException(), isNull);
    await tester.enterText(field, '  打ったまま  ');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '保存');
    final screen = Offset.zero & tester.view.physicalSize;
    expect(screen.contains(tester.getCenter(save)), isTrue);
    await tester.tap(save);
    await settleIo(tester);
    expect(find.byType(AlertDialog), findsNothing);
    final tags = s.service.projects.singleWhere((p) => p.id == s.id).tags;
    expect(tags, hasLength(32));
    expect(tags.last, '打ったまま');
    expect(tester.takeException(), isNull);
  });
}
