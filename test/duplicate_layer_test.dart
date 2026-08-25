import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/project_service.dart';

/// ProjectService.duplicateLayer（キャンバスモードのレイヤーコピー＆
/// ペースト・タイムラインの素材クリップ複製の両方が使う共通処理）が、
/// ピクセル内容も正しく複製することを検証する。
///
/// TileManagerの実キーは「シーンID#フレーム番号#レイヤーID」の合成キー
/// であり、レイヤーIDをそのままキーとして渡すと複製元が見つからず
/// 空の複製になってしまう不具合が過去にあったため、その再発を防ぐための
/// 回帰テスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ui.Color> pixelAt(ui.Image image, int x, int y, int width) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final idx = (y * width + x) * 4;
    return ui.Color.fromARGB(bytes[idx + 3], bytes[idx], bytes[idx + 1], bytes[idx + 2]);
  }

  test('duplicateLayerは複製元のピクセル内容を正しく引き継ぐ', () async {
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: 'テスト',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final scene = service.scenesOf(project.id).first;
    final layer = service.layersOf(project.id, scene.id, 0).first;

    final tm = service.tileManagerOf(project.id);
    final key = service.tileKeyFor(project.id, scene.id, 0, layer.id);
    final tile = tm.getOrCreateTile(key, 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255); // 赤・不透明

    final copy = service.duplicateLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: layer.id,
    );
    expect(copy, isNotNull);
    expect(copy!.id, isNot(layer.id));

    final copyKey = service.tileKeyFor(project.id, scene.id, 0, copy.id);
    final image = await tm.compositeLayerToImage(copyKey);
    expect(
      await pixelAt(image, 0, 0, tm.canvasWidth),
      const ui.Color.fromARGB(255, 255, 0, 0),
      reason: '複製先のレイヤーにも複製元と同じピクセルが引き継がれているはず',
    );
    image.dispose();

    // 複製後、レイヤー一覧にもコピーが実際に挿入されていることを確認する。
    final layers = service.layersOf(project.id, scene.id, 0);
    expect(layers.any((l) => l.id == copy.id), isTrue);
  });
}
