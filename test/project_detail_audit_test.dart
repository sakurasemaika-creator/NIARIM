import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/scene_stack.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:niarim/widgets/project_not_found_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/color_channels.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// ゴミ箱の記録の書き込みを、[rejectTrash]の間だけ断る保存先。
class _TrashRejectingStore extends InMemorySharedPreferencesStore {
  _TrashRejectingStore()
    : super.withData({
        'flutter.$firstUseTooltipsSeenKey': kAllFirstUseTooltipKeys,
        'flutter.first_launch': false,
        'flutter.language': 'ja',
      });

  bool rejectTrash = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (rejectTrash && key == 'flutter.trashed_projects') return false;
    return super.setValue(type, key, value);
  }
}

/// プロジェクト詳細（A009）：名前の変更、ゴミ箱へ移した後の取り消し、
/// プレビューの絵の範囲と背景・重なり順とマスク、早いコマ送りで最後の
/// フレームが出ること、長い言葉の操作の並び、見つからない作品からホームへ
/// 戻れること。
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
  /// [prepare]は塗った後、詳細を開く前に呼ぶ。
  Future<({ProjectService service, String id})> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    int background = 0xFFFFFFFF,
    int exportWidth = 64,
    int exportHeight = 32,
    List<Color> colors = const [],
    String language = 'ja',
    void Function(ProjectService service, String id)? prepare,
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
      prepare?.call(service, id);
    });
    appRouter.push('/project/$id');
    await settleIo(tester);
    return (service: service, id: id);
  }

  Finder artwork() => find.byKey(const Key('projectDetailPreviewArtwork'));

  // プレビューに出ている絵の色（既定は真ん中、[fx]・[fy]は幅・高さの割合）。
  Future<Color> previewColour(
    WidgetTester tester, {
    double fx = 0.5,
    double fy = 0.5,
  }) async {
    final image = tester
        .widget<RawImage>(
          find.descendant(of: artwork(), matching: find.byType(RawImage)),
        )
        .image!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final x = (image.width * fx).floor().clamp(0, image.width - 1);
    final y = (image.height * fy).floor().clamp(0, image.height - 1);
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

  testWidgets('the rename field stays in view above a landscape keyboard', (
    tester,
  ) async {
    // 横向きのスマホ（高さ360）でキーボード（170）が開いている。
    await open(tester, size: const Size(800, 360));
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('名前変更').last);
    await settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 170);
    await settle(tester);
    final editable = find.descendant(
      of: find.byType(NameEntryDialog),
      matching: find.byType(EditableText),
    );
    final rect = tester.getRect(editable);
    // キーボードより上にあり、押すと欄そのものに届く（ダイアログがスクロール
    // しないと、欄の場所は残っても高さ0の並びの中で描かれず、押せなかった）。
    expect(rect.bottom, lessThanOrEqualTo(360 - 170));
    final hit = tester.hitTestOnBinding(rect.center);
    final target = tester.renderObject(editable);
    expect(hit.path.any((entry) => identical(entry.target, target)), isTrue);
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

  testWidgets('leaving after moving to the trash never shows "not found"', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動').last);
    // 移した作品は一覧から消えるが、自分で移して閉じる途中の画面に
    // 「見つかりません」と一覧へのボタンを出さない。
    final seen = <int>[];
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      if (find.byType(ProjectNotFoundView).evaluate().isNotEmpty) seen.add(i);
    }
    expect(seen, isEmpty);
    expect(find.byType(ProjectDetailScreen), findsNothing);
    expect(find.text('元に戻す'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Undo that cannot be saved says so', (tester) async {
    final store = _TrashRejectingStore();
    final previous = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final s = await open(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動').last);
    await settleIo(tester);
    expect(s.service.trash.map((p) => p.id), [s.id]);
    // 戻した状態を保存できない（保存先がいっぱい等）。
    store.rejectTrash = true;
    await tester.tap(find.text('元に戻す'));
    for (var i = 0; i < 4; i++) {
      await settleIo(tester);
    }
    expect(s.service.trash.map((p) => p.id), [s.id]);
    // 黙って何も起きないのではなく、ホームのゴミ箱と同じ文で知らせる。
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(l10n.homeTrashOperationFailed), findsOneWidget);
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

  testWidgets('the preview stacks and masks like the export', (tester) async {
    const drawing = Color(0xFFE53935);
    const material = Color(0xFF1E88E5);
    late String sceneId;
    final s = await open(
      tester,
      colors: const [drawing],
      prepare: (service, id) {
        final tm = service.tileManagerOf(id);
        sceneId = service.scenesOf(id).first.id;
        // レイヤーの並び（layersOf）ではイラストの後ろにあるテキストの素材。
        // 重なり順の既定では、テキストの列はイラストより前に出る。
        final text = service.addLayer(
          projectId: id,
          sceneId: sceneId,
          frameIndex: 0,
          type: LayerType.timelineText,
          name: 'text',
          insertIndex: 1,
        );
        service.replaceLayerPixels(
          projectId: id,
          sceneId: sceneId,
          frameIndex: 0,
          layerId: text.id,
          pixels: solid(tm.canvasWidth, tm.canvasHeight, material),
        );
      },
    );
    // 書き出しと同じく、テキストがイラストの前。
    expect(await previewColour(tester), material);

    // イラストを前にし、真ん中だけ見えるようにマスクする。
    appRouter.push('/settings');
    await settle(tester);
    await tester.runAsync(() async {
      s.service.updateSceneStack(
        s.id,
        sceneId,
        SceneStack(
          order: [kStackFrame, stackTrackKey(StackTrackKind.text, 0)],
          frameMask: const LayerMask(width: 40, height: 40),
        ),
      );
    });
    appRouter.pop();
    await settleIo(tester);
    expect(await previewColour(tester), drawing);
    // マスクの外では、後ろのテキストが見える。
    expect(await previewColour(tester, fx: 0.05, fy: 0.05), material);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('duplicating names the copy in the screen language and numbers '
      'repeated copies', (tester) async {
    // 英語の端末として起動する。
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'en',
    });
    final s = await open(tester);
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await settle(tester);
      await tester.tap(find.text('Duplicate').last);
      await settleIo(tester);
      // 複製は素材とサムネイルを写し終えてから一覧に出る。
      for (var j = 0; j < 40 && s.service.projects.length < 1 + i; j++) {
        await settleIo(tester);
      }
    }
    final copies = [
      for (final p in s.service.projects)
        if (p.id != s.id) p.name,
    ];
    // 画面の言語で「(copy)」を付け、2つ目からは番号を付ける（以前は
    // どの言語でも日本語の「(コピー)」で、同じ名前が並んだ）。
    expect(copies, unorderedEquals(['詳細の作品 (copy)', '詳細の作品 (copy 2)']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the move sheet lists folders under their parents', (
    tester,
  ) async {
    final s = await open(tester);
    await tester.runAsync(() async {
      final parent = await s.service.createFolder('Z親');
      await s.service.createFolder('C単独');
      await s.service.createFolder('A子', parentFolderId: parent.id);
    });
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('フォルダへ移動').last);
    await settle(tester);
    Rect row(String name) => tester.getRect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text(name)),
    );
    // 名前順の階層どおり：C単独・Z親・その下にA子（字下げ）。作った順に
    // 平らに並べると、子のフォルダが別の親の下に見えた。
    expect(row('C単独').top, lessThan(row('Z親').top));
    expect(row('Z親').top, lessThan(row('A子').top));
    expect(row('A子').left, greaterThan(row('Z親').left));
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

  // 同梱フォントは読み込むとこのファイルの残りのテストにも効くので、
  // このテストは最後に置く。
  testWidgets('with the app fonts, no quick action word is broken', (
    tester,
  ) async {
    await loadAppFonts(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    final settings = tester
        .element(find.byType(Scaffold).first)
        .read<SettingsService>();
    final row = find.byKey(const Key('projectDetailQuickActions'));
    Rect at(String key) => tester.getRect(find.byKey(Key(key)));
    final broken = <String>[];
    // 欄の幅を切り捨てたときの1px未満の差で語が折れていた幅（英・西・仏）と、
    // 日本語の大きな文字（「お気に/入り」「ループ再/生」「フォル/ダ」）。
    for (final (language, scale, width) in const [
      ('es', 1.0, 365.0),
      ('en', 1.3, 320.0),
      ('en', 1.8, 411.0),
      ('fr', 1.5, 384.0),
      ('ja', 1.3, 320.0),
      ('ja', 1.5, 360.0),
      ('ja', 2.0, 360.0),
      ('ja', 2.0, 412.0),
      ('ja', 1.0, 360.0),
      // 韓国語の空白で区切った語（「즐겨찾기 미/등록」「반복 재/생」）。
      ('ko', 1.0, 390.0),
      ('ko', 1.5, 412.0),
    ]) {
      await tester.runAsync(() => settings.setLanguage(language));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.view.physicalSize = Size(width, 844);
      await tester.pump();
      await tester.pump();
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: row, matching: find.byType(RichText)),
      )) {
        final text = paragraph.text.toPlainText();
        for (final word in RegExp(r'\S+').allMatches(text)) {
          final tops = {
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end),
              boxHeightStyle: ui.BoxHeightStyle.max,
            ))
              box.top.round(),
          };
          if (tops.length > 1) {
            broken.add('$language x$scale ${width}px "${word.group(0)}"');
          }
        }
      }
      if (language == 'ja' && scale == 1.0) {
        // ふだんの文字の大きさでは、5つとも1行に並んだまま。
        final top = tester.getRect(row).top;
        expect(at('projectDetailShareAction').top, top);
        expect(at('projectDetailLoopButton').top, top);
      }
    }
    expect(broken, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
