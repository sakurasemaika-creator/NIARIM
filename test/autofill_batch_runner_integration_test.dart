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
    _FakePathProvider('/tmp/niarim_autofill_batch_test');

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
}
