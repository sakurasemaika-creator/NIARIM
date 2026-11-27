// レイヤーに足した4つ（所有者の判断、2026-11-27、全部入りの作品づくりの判断カード
// J15）。
//
// * 画像の読み込みで「全体を入れる／キャンバスいっぱいに広げる」と「今のレイヤーを
//   差し替える」（以前はいつも全体を新しいレイヤーへ）。
// * 通常レイヤーの名前変更・複製（以前は共通レイヤーだけ）。
// * ドラッグでフォルダへ出し入れ（以前は同じフォルダの中の並べ替えだけ）。
// * 拡大縮小・回転の数値（以前はスライダーだけ）。キーフレームが1つ以下のときは
//   レイヤー全体に効く（素材と同じ決まり）。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

class _OnePicture extends FilePicker {
  _OnePicture(this.path);
  final String path;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(path: path, name: 'wide.png', size: File(path).lengthSync()),
  ]);
}

void main() {
  late Directory directory;

  Future<
    ({
      ProjectService ps,
      String id,
      String scene,
      AppLocalizations l10n,
      Layer ink,
      Layer box,
      Layer inside,
    })
  >
  openCanvas(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
      'default_docked_panels': ['layer'],
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    directory = Directory.systemTemp.createTempSync('layer-j15-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'j15',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first.id;
    final box = ps.addLayer(
      projectId: project.id,
      sceneId: scene,
      frameIndex: 0,
      type: LayerType.folder,
      name: 'Box',
    );
    final inside = ps.addLayer(
      projectId: project.id,
      sceneId: scene,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'Inside',
      parentFolderId: box.id,
    );
    final ink = ps.addLayer(
      projectId: project.id,
      sceneId: scene,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'Ink',
    );
    await tester.runAsync(() => ps.saveProject(project.id));
    appRouter.push('/canvas/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CanvasScreen)),
    )!;
    return (
      ps: ps,
      id: project.id,
      scene: scene,
      l10n: l10n,
      ink: ink,
      box: box,
      inside: inside,
    );
  }

  Future<void> settle(WidgetTester tester) =>
      pumpRealAsync(tester, const Duration(milliseconds: 300));

  Future<void> openOptions(WidgetTester tester, Layer layer) async {
    final menu = find.byKey(ValueKey('canvasLayerMenu_${layer.id}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await settle(tester);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
    await settle(tester);
  }

  testWidgets('a normal layer is renamed and duplicated from its menu', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n, :ink, :box, :inside) = await openCanvas(
      tester,
    );
    await openOptions(tester, ink);
    await tester.tap(find.byKey(const ValueKey('layerOptionsRename')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Line');
    await tester.tap(find.text(l10n.commonChange));
    await settle(tester);
    List<String> names() => [for (final l in ps.layersOf(id, scene, 0)) l.name];
    expect(names(), contains('Line'));
    expect(names(), isNot(contains('Ink')));

    await openOptions(tester, ink);
    await tester.tap(find.byKey(const ValueKey('layerOptionsDuplicate')));
    await settle(tester);
    expect(
      names(),
      containsAll([
        'Line',
        numberedEditorCopyName(l10n, 'Line', {'Line'}),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the size and angle show their numbers and are the whole '
      'layer\'s', (tester) async {
    final (:ps, :id, :scene, :l10n, :ink, :box, :inside) = await openCanvas(
      tester,
    );
    Layer stored() =>
        ps.storedLayersOf(id, scene, 0).singleWhere((l) => l.id == ink.id);
    LabeledSlider slider(String label) => tester.widget<LabeledSlider>(
      find.byWidgetPredicate((w) => w is LabeledSlider && w.label == label),
    );

    await openOptions(tester, ink);
    expect(
      find.text(l10n.layerTransformWholeHint(l10n.layerPanelKeyframeLabel)),
      findsOneWidget,
    );
    slider(l10n.layerKeyframeScaleLabel).onChanged!(2);
    await tester.pump();
    expect(slider(l10n.layerKeyframeScaleLabel).valueText, '×2.00');
    slider(l10n.layerKeyframeRotationLabel).onChanged!(30);
    await tester.pump();
    expect(slider(l10n.layerKeyframeRotationLabel).valueText, '30°');
    await closeSheet(tester);
    expect(stored().keyframes, hasLength(1));
    expect(stored().keyframes.single.scale, 2);
    expect(stored().keyframes.single.rotation, 30);

    // Changed again, the one keyframe changes: no second one appears.
    await openOptions(tester, ink);
    slider(l10n.layerKeyframeScaleLabel).onChanged!(1.5);
    await tester.pump();
    await closeSheet(tester);
    expect(stored().keyframes, hasLength(1));
    expect(stored().keyframes.single.scale, 1.5);
    expect(stored().keyframes.single.rotation, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a layer is dragged into a folder and out again', (tester) async {
    final (:ps, :id, :scene, :l10n, :ink, :box, :inside) = await openCanvas(
      tester,
    );
    final undo = tester.element(find.byType(CanvasScreen)).read<UndoManager>();
    Layer find0(String layerId) =>
        ps.layersOf(id, scene, 0).singleWhere((l) => l.id == layerId);
    // The rows as the panel shows them.
    List<String> rows() => [
      for (final l in ps.layersOf(id, scene, 0))
        if (l.parentFolderId == null ||
            ps.isLayerFolderExpanded(id, find0(l.parentFolderId!)))
          l.id,
    ];
    void reorder(int from, int to) => tester
        .widget<ReorderableListView>(
          find.descendant(
            of: find.byType(LayerPanel),
            matching: find.byType(ReorderableListView),
          ),
        )
        .onReorderItem!(from, to);

    // "Ink" dropped where "Inside" is: into the folder, beside it.
    var order = rows();
    reorder(order.indexOf(ink.id), order.indexOf(inside.id));
    await settle(tester);
    expect(find0(ink.id).parentFolderId, box.id);
    // Moved down to where "Inside" was: just below it.
    expect(rows().indexOf(ink.id), rows().indexOf(inside.id) + 1);
    undo.undo(projectId: id);
    await settle(tester);
    expect(find0(ink.id).parentFolderId, isNull, reason: 'one undo step');

    // Dropped after the open folder's row: to the top inside it.
    order = rows();
    final inkAt = order.indexOf(ink.id);
    final boxAt = order.indexOf(box.id);
    if (inkAt < boxAt) {
      reorder(inkAt, boxAt);
      await settle(tester);
      expect(find0(ink.id).parentFolderId, box.id);
    }

    // "Inside" dropped beside the root layer "Ink"... or the folder itself:
    // out of the folder.
    order = rows();
    reorder(order.indexOf(inside.id), order.indexOf(box.id));
    await settle(tester);
    expect(find0(inside.id).parentFolderId, isNull);
    expect(find0(box.id).type, LayerType.folder);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an image fills the canvas, or replaces the current layer', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n, :ink, :box, :inside) = await openCanvas(
      tester,
    );
    // A wide red picture (4:1) on the 64×48 canvas.
    final picture = img.Image(width: 80, height: 20);
    img.fill(picture, color: img.ColorRgba8(255, 0, 0, 255));
    final path = '${directory.path}/wide.png';
    File(path).writeAsBytesSync(img.encodePng(picture));
    FilePicker.platform = _OnePicture(path);
    final tiles = ps.tileManagerOf(id);
    int alphaAt(String layerId, int x, int y) =>
        ((tiles
                        .getPixelColorAt(
                          ps.tileKeyFor(id, scene, 0, layerId),
                          x,
                          y,
                        )
                        ?.a ??
                    0) *
                255)
            .round();
    Future<void> import(String choice, {bool replace = false}) async {
      await tester.tap(find.byTooltip(l10n.layerPanelImportImageButton).first);
      await settle(tester);
      if (replace) {
        await tester.tap(find.byKey(const ValueKey('layerImportReplace')));
        await tester.pump();
      }
      await tester.tap(find.byKey(ValueKey(choice)));
      await pumpRealAsync(tester, const Duration(milliseconds: 800));
    }

    // Fill: the corners are covered too.
    final before = ps.layersOf(id, scene, 0).length;
    await import('layerImportFill');
    final layers = ps.layersOf(id, scene, 0);
    expect(layers, hasLength(before + 1));
    final filled = layers.firstWhere((l) => l.name == 'wide');
    expect(alphaAt(filled.id, 1, 1), 255);
    expect(alphaAt(filled.id, 62, 46), 255);

    // Fit: the whole picture, so the top is left clear.
    await import('layerImportFit');
    final fitted = ps
        .layersOf(id, scene, 0)
        .firstWhere((l) => l.name == 'wide' && l.id != filled.id);
    expect(alphaAt(fitted.id, 32, 1), 0);
    expect(alphaAt(fitted.id, 32, 24), 255);

    // Replace: the current layer gets the picture, and no layer is added.
    final current = tester
        .widget<CanvasArea>(find.byType(CanvasArea))
        .currentLayerId!;
    final count = ps.layersOf(id, scene, 0).length;
    await import('layerImportFill', replace: true);
    expect(ps.layersOf(id, scene, 0), hasLength(count));
    expect(alphaAt(current, 1, 1), 255);
    expect(tester.takeException(), isNull);
  });
}
