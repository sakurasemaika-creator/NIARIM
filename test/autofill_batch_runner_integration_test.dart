import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/autofill_batch_runner.dart';
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String path;
  _FakePathProvider(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('batch runner writes pixels and production layer state', () async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider('/tmp/niarim_autofill_batch_test');

    final projectService = ProjectService();
    final project = await projectService.createProject(
      name: 'autofill integration',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 9,
      exportHeight: 9,
    );
    final lineart = projectService.addLayer(
      projectId: project.id,
      sceneId: 'Scene0001',
      frameIndex: 0,
      type: LayerType.autoFillLineart,
      name: 'lineart',
    );
    projectService.assignAutofillPart(
      projectId: project.id,
      sceneId: 'Scene0001',
      frameIndex: 0,
      lineartLayerId: lineart.id,
      partId: 'integration_part',
      partName: 'integration',
    );
    final assigned = projectService
        .layersOf(project.id, 'Scene0001', 0)
        .firstWhere((layer) => layer.id == lineart.id);

    final tm = projectService.tileManagerOf(project.id);
    final pixels = Uint8List(9 * 9 * 4);
    void black(int x, int y) {
      final i = (y * 9 + x) * 4;
      pixels[i + 3] = 255;
    }
    for (var x = 1; x <= 7; x++) {
      black(x, 1);
      black(x, 7);
    }
    for (var y = 1; y <= 7; y++) {
      black(1, y);
      black(7, y);
    }
    tm.replaceLayerPixels(frameLayerKey('Scene0001', 0, lineart.id), pixels);

    final presetService = AutofillPresetService();
    await presetService.init();
    await presetService.addPreset(const AutofillPreset(
      id: 'integration',
      name: 'integration',
      parts: [
        AutofillPart(
          id: 'integration_part',
          name: 'integration',
          color: 0xFF12AB34,
          opacity: 63,
          blendMode: LayerBlendMode.multiply,
          lineOpacity: 77,
        ),
      ],
    ));

    final result = await runAutofillForLayer(
      projectService: projectService,
      presetService: presetService,
      toneService: ToneService(),
      projectId: project.id,
      sceneId: 'Scene0001',
      frameIndex: 0,
      lineartLayer: assigned,
      mode: AutofillMode.repaint,
    );
    expect(result, AutofillBatchResult.applied);

    final layers = projectService.layersOf(project.id, 'Scene0001', 0);
    final lineartIndex = layers.indexWhere((layer) => layer.id == lineart.id);
    expect(lineartIndex, greaterThanOrEqualTo(0));
    expect(layers[lineartIndex + 1].type, LayerType.autoFill);
    final fill = layers[lineartIndex + 1];
    expect(fill.partId, 'integration_part');
    expect(fill.needsAutofillUpdate, isFalse);
    expect(fill.opacity, 63);
    expect(fill.blendMode, LayerBlendMode.multiply);
    expect(layers[lineartIndex].opacity, 77);
    expect(layers[lineartIndex].blendMode, LayerBlendMode.multiply);

    final image = await tm.compositeLayerToImage(
      frameLayerKey('Scene0001', 0, fill.id),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    final center = (4 * 9 + 4) * 4;
    expect(bytes.sublist(center, center + 4), [0x12, 0xAB, 0x34, 0xFF]);
    final outside = 0;
    expect(bytes.sublist(outside, outside + 4), [0, 0, 0, 0]);
  });

  test('smart update preserves edits and does not touch another autofill part', () async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance =
        _FakePathProvider('/tmp/niarim_autofill_smart_update_test');

    final ps = ProjectService();
    final project = await ps.createProject(
      name: 'smart update',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 9,
      exportHeight: 9,
    );
    final lineart = ps.addLayer(
      projectId: project.id,
      sceneId: 'Scene0001',
      frameIndex: 0,
      type: LayerType.autoFillLineart,
      name: 'lineart',
    );
    ps.assignAutofillPart(
      projectId: project.id,
      sceneId: 'Scene0001',
      frameIndex: 0,
      lineartLayerId: lineart.id,
      partId: 'smart_part',
      partName: 'smart',
    );
    var assigned = ps.layersOf(project.id, 'Scene0001', 0)
        .firstWhere((l) => l.id == lineart.id);
    final tm = ps.tileManagerOf(project.id);
    final line = Uint8List(9 * 9 * 4);
    void ink(int x, int y) => line[(y * 9 + x) * 4 + 3] = 255;
    for (var x = 1; x <= 7; x++) {
      ink(x, 1); ink(x, 7);
    }
    for (var y = 1; y <= 7; y++) {
      ink(1, y); ink(7, y);
    }
    tm.replaceLayerPixels(frameLayerKey('Scene0001', 0, lineart.id), line);

    final presets = AutofillPresetService();
    await presets.init();
    await presets.addPreset(const AutofillPreset(
      id: 'smart',
      name: 'smart',
      parts: [AutofillPart(id: 'smart_part', name: 'smart', color: 0xFF22AA44)],
    ));
    await runAutofillForLayer(
      projectService: ps, presetService: presets, toneService: ToneService(),
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      lineartLayer: assigned, mode: AutofillMode.repaint,
    );

    var layers = ps.layersOf(project.id, 'Scene0001', 0);
    final fill = layers[layers.indexWhere((l) => l.id == lineart.id) + 1];
    final fillKey = frameLayerKey('Scene0001', 0, fill.id);
    final edited = Uint8List(9 * 9 * 4);
    final fillImage = await tm.compositeLayerToImage(fillKey);
    final fillData = await fillImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    fillImage.dispose();
    edited.setAll(0, fillData!.buffer.asUint8List());
    final center = (4 * 9 + 4) * 4;
    edited.setRange(center, center + 4, [210, 40, 70, 255]);
    tm.replaceLayerPixels(fillKey, edited);

    final other = ps.addLayer(
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      type: LayerType.autoFill, name: 'other',
    );
    final otherKey = frameLayerKey('Scene0001', 0, other.id);
    final otherPixels = Uint8List(9 * 9 * 4);
    otherPixels.setRange(center, center + 4, [7, 8, 9, 255]);
    tm.replaceLayerPixels(otherKey, otherPixels);

    assigned = ps.layersOf(project.id, 'Scene0001', 0)
        .firstWhere((l) => l.id == lineart.id);
    await runAutofillForLayer(
      projectService: ps, presetService: presets, toneService: ToneService(),
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      lineartLayer: assigned, mode: AutofillMode.smartUpdate,
    );

    final updatedImage = await tm.compositeLayerToImage(fillKey);
    final updatedData = (await updatedImage.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer.asUint8List();
    updatedImage.dispose();
    expect(updatedData.sublist(center, center + 4), [210, 40, 70, 255]);

    final otherImage = await tm.compositeLayerToImage(otherKey);
    final otherAfter = (await otherImage.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer.asUint8List();
    otherImage.dispose();
    expect(otherAfter.sublist(center, center + 4), [7, 8, 9, 255]);
  });

  test('color update recolors existing fill and locks opacity', () async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance =
        _FakePathProvider('/tmp/niarim_autofill_color_update_test');

    final ps = ProjectService();
    final project = await ps.createProject(
      name: 'color update', fps: 1, durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF, exportWidth: 9, exportHeight: 9,
    );
    final lineart = ps.addLayer(
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      type: LayerType.autoFillLineart, name: 'lineart',
    );
    ps.assignAutofillPart(
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      lineartLayerId: lineart.id, partId: 'color_part', partName: 'color',
    );
    final line = Uint8List(9 * 9 * 4);
    void ink(int x, int y) => line[(y * 9 + x) * 4 + 3] = 255;
    for (var x = 1; x <= 7; x++) { ink(x, 1); ink(x, 7); }
    for (var y = 1; y <= 7; y++) { ink(1, y); ink(7, y); }
    final tm = ps.tileManagerOf(project.id);
    tm.replaceLayerPixels(frameLayerKey('Scene0001', 0, lineart.id), line);

    final presets = AutofillPresetService();
    await presets.init();
    await presets.addPreset(const AutofillPreset(
      id: 'color', name: 'color',
      parts: [AutofillPart(id: 'color_part', name: 'color', color: 0xFF336699)],
    ));
    var assigned = ps.layersOf(project.id, 'Scene0001', 0)
        .firstWhere((l) => l.id == lineart.id);
    await runAutofillForLayer(
      projectService: ps, presetService: presets, toneService: ToneService(),
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      lineartLayer: assigned, mode: AutofillMode.repaint,
    );

    await presets.updatePreset(const AutofillPreset(
      id: 'color', name: 'color',
      parts: [AutofillPart(id: 'color_part', name: 'color', color: 0xFFCC5500)],
    ));
    assigned = ps.layersOf(project.id, 'Scene0001', 0)
        .firstWhere((l) => l.id == lineart.id);
    await runAutofillForLayer(
      projectService: ps, presetService: presets, toneService: ToneService(),
      projectId: project.id, sceneId: 'Scene0001', frameIndex: 0,
      lineartLayer: assigned, mode: AutofillMode.colorUpdate,
    );

    final layers = ps.layersOf(project.id, 'Scene0001', 0);
    final fill = layers[layers.indexWhere((l) => l.id == lineart.id) + 1];
    expect(fill.opacityLocked, isTrue);
    final image = await tm.compositeLayerToImage(
      frameLayerKey('Scene0001', 0, fill.id),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer.asUint8List();
    image.dispose();
    final center = (4 * 9 + 4) * 4;
    expect(bytes.sublist(center, center + 4), [0xCC, 0x55, 0, 0xFF]);
  });

}
