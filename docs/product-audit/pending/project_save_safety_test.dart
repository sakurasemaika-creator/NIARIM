import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

const _layer = 'Scene0001#0#Layer0001';
const _otherLayer = 'Scene0001#1#Layer0001';
const _red = [255, 0, 0, 255];
const _blue = [0, 0, 255, 255];
const _scenes = [
  Scene(
    id: 'Scene0001',
    index: 0,
    frames: [
      Frame(
        index: 0,
        layers: [Layer(id: 'Layer0001', name: 'Ink', type: LayerType.normal)],
      ),
    ],
  ),
];

void _paint(TileManager tm, String key, List<int> rgba) {
  tm.getOrCreateTile(key, 0, 0).setRange(0, 4, rgba);
  tm.markDirty(key, 0, 0);
}

Future<File> _save(Project project, TileManager tm) =>
    NiaproSerializer.save(project: project, scenes: _scenes, tileManager: tm);

Future<void> _expectPixels(File file, String key, List<int> rgba) async {
  final restored = await NiaproSerializer.load(file.path);
  expect(restored.tileData[key]?['0,0']?.take(4), rgba);
}

// Drawing may resume as soon as ZIP construction yields back to the event loop.
// A write scheduled there must stay dirty until a subsequent save includes it.
class _EditAfterSnapshot extends TileManager {
  _EditAfterSnapshot() : super(canvasWidth: 4, canvasHeight: 4);

  bool editAfterSnapshot = false;

  @override
  Map<String, Map<String, Uint8List>> exportAll() {
    final result = super.exportAll();
    if (editAfterSnapshot) {
      editAfterSnapshot = false;
      scheduleMicrotask(() => _paint(this, _layer, _blue));
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Project project;
  late TileManager tm;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim-save-safety-');
    project = Project(
      id: 'save-safety',
      name: '保存検証',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026, 9, 8),
      updatedAt: DateTime(2026, 9, 8),
      totalWorkSeconds: 0,
      exportWidth: 4,
      exportHeight: 4,
    );
    tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    _paint(tm, _layer, _red);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });

  tearDown(() {
    tm.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    dir.deleteSync(recursive: true);
  });

  for (final kind in ['share', 'autosave', 'save-tree']) {
    test('$kindの上書き失敗でも直前のZIPと画素を保持する', () async {
      Future<File> write(Project value) => switch (kind) {
        'share' => NiaproSerializer.saveShare(
          project: value,
          scenes: _scenes,
          tileManager: tm,
          outputDir: dir.path,
        ),
        'autosave' => NiaproSerializer.saveAutosave(
          project: value,
          scenes: _scenes,
          tileManager: tm,
          slotIndex: 0,
        ),
        _ => NiaproSerializer.saveSaveTreeNode(
          project: value,
          scenes: _scenes,
          tileManager: tm,
          nodeId: 'node1',
        ),
      };
      final file = await write(project);
      final original = file.readAsBytesSync();
      _paint(tm, _layer, _blue);
      await expectLater(
        write(project.copyWith(drawingAreaScale: double.nan)),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(file.readAsBytesSync(), original);
      await _expectPixels(file, _layer, _red);
      await write(project);
      await _expectPixels(file, _layer, _blue);
      expect(tm.getDirtyTilesForLayer(_layer), isNotEmpty);
      expect(file.parent.listSync().whereType<Directory>(), isEmpty);
    });
  }

  test('差分保存の失敗を伝え、dirtyと直前のZIPを保持して再試行できる', () async {
    final file = await _save(project, tm);
    final original = file.readAsBytesSync();
    _paint(tm, _layer, _blue);
    await expectLater(
      _save(project.copyWith(drawingAreaScale: double.nan), tm),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
    expect(file.readAsBytesSync(), original);
    expect(tm.getDirtyTilesForLayer(_layer), isNotEmpty);
    expect(
      file.parent.listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
    await _save(project, tm);
    await _expectPixels(file, _layer, _blue);
    expect(tm.getDirtyTilesForLayer(_layer), isEmpty);
  });

  for (final existing in [false, true]) {
    test('並行8保存の順序を保ち最後の版を読み戻せる（既存:$existing）', () async {
      if (existing) await _save(project, tm);
      final errors = <Object>[];
      final results = <File>[];
      await Future.wait([
        for (var i = 0; i < 8; i++)
          _save(project.copyWith(name: 'version$i'), tm).then<void>(
            results.add,
            onError: (Object error, StackTrace stack) => errors.add(error),
          ),
      ]);
      expect(errors, isEmpty);
      expect(results, hasLength(8));
      final restored = await NiaproSerializer.load(results.last.path);
      expect(restored.project.name, 'version7');
      expect(restored.tileData[_layer]?['0,0']?.take(4), _red);
    });
  }

  test('保存済みタイルの書き込み用取得からの変更を差分保存する', () async {
    final file = await _save(project, tm);
    tm.getOrCreateTile(_layer, 0, 0).setRange(0, 4, _blue);
    await _save(project, tm);
    await _expectPixels(file, _layer, _blue);
  });

  test('読み取りバッファの直接変更とinvalidateを差分保存する', () async {
    final file = await _save(project, tm);
    tm.getTile(_layer, 0, 0)!.setRange(0, 4, _blue);
    tm.invalidateTile(_layer, 0, 0);
    await _save(project, tm);
    await _expectPixels(file, _layer, _blue);
  });

  test('autosaveを復元した画素が次の通常保存で古い画素へ戻らない', () async {
    final file = await _save(project, tm);
    _paint(tm, _layer, _blue);
    final autosave = await NiaproSerializer.saveAutosave(
      project: project,
      scenes: _scenes,
      tileManager: tm,
      slotIndex: 0,
    );
    final recovered = await NiaproSerializer.load(autosave.path);
    final reopened = TileManager(canvasWidth: 4, canvasHeight: 4);
    addTearDown(reopened.dispose);
    reopened.importAll((await NiaproSerializer.load(file.path)).tileData);
    await _save(project, reopened);
    reopened.importAll(recovered.tileData);
    await _save(project, reopened);
    await _expectPixels(file, _layer, _blue);
  });

  for (final operation in ['copy', 'rename']) {
    test('保存済みの別フレームへの$operationを差分保存する', () async {
      _paint(tm, _otherLayer, _blue);
      final file = await _save(project, tm);
      if (operation == 'copy') {
        tm.copyLayer(_otherLayer, _layer);
      } else {
        tm.renameKey(_otherLayer, _layer);
      }
      await _save(project, tm);
      await _expectPixels(file, _layer, _blue);
      final recovered = await NiaproSerializer.load(file.path);
      expect(recovered.tileData.containsKey(_otherLayer), operation == 'copy');
    });
  }

  test('ZIP作成後に描いた画素を未保存として保持し次の保存へ含める', () async {
    final edited = _EditAfterSnapshot();
    addTearDown(edited.dispose);
    _paint(edited, _layer, _red);
    edited.editAfterSnapshot = true;
    final file = await _save(project, edited);
    await _expectPixels(file, _layer, _red);
    expect(edited.getDirtyTilesForLayer(_layer), isNotEmpty);
    await _save(project, edited);
    await _expectPixels(file, _layer, _blue);
  });
}
