// 主な操作の実行時間（全面監査のD035）。
//
// 1920×1080（新規作成の既定の大きさ）で、線を描く・レイヤーを合成する・
// 全部の組み込みフィルターを当てる・作品名の並べ替えと検索・作品の保存と
// 読み込み・書き出しの1コマの合成とGIFの書き出しをくり返し、
// p50/p95 を build/perf/operation_timing.json に書く。端末ではなく、この
// testを流した計算機の時間なので、同じ計算機での前後の比較（遅くなった
// 処理を見つける）に使う。あまりに遅い処理（下の上限）は失敗にする。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_preview.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/utils/name_collation.dart';

const _w = 1920, _h = 1080;

Map<String, num> _stats(List<int> micros) {
  final sorted = [...micros]..sort();
  num at(double q) => sorted[((sorted.length - 1) * q).round()] / 1000;
  return {'runs': sorted.length, 'p50Ms': at(0.5), 'p95Ms': at(0.95)};
}

/// A busy 1920×1080 picture: random-ish shapes over most of the canvas.
Uint8List _sample() {
  final data = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final inside = ((x ~/ 120) + (y ~/ 90)) % 3 != 0;
      if (!inside) continue;
      data[i] = (x * 255 ~/ _w);
      data[i + 1] = (y * 255 ~/ _h);
      data[i + 2] = ((x + y) % 256);
      data[i + 3] = 255;
    }
  }
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, Object?>{
    'canvas': '${_w}x$_h',
    'host': Platform.operatingSystem,
  };
  final slow = <String>[];
  tearDownAll(() {
    Directory('build/perf').createSync(recursive: true);
    File(
      'build/perf/operation_timing.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  });

  testWidgets('線を描く・合成する（1920×1080）', (tester) async {
    final brushes = {for (final b in BrushService.builtInBrushes) b.id: b};
    final strokes = <String, Object?>{};
    final composites = <int>[];
    for (final id in ['Brush0001', 'Brush0003', 'Brush0010', 'Brush0023']) {
      final times = <int>[];
      await tester.runAsync(() async {
        final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
        try {
          final engine = DrawingEngine(tileManager: tm)
            ..currentColor = Colors.black
            ..currentBrush = brushes[id]!
            ..pressureEnabled = false;
          for (var run = 0; run < 10; run++) {
            final clock = Stopwatch()..start();
            engine.beginStroke(StrokePoint(x: 100, y: 100.0 + run * 80), 'l');
            for (var p = 1; p <= 100; p++) {
              engine.continueStroke(
                StrokePoint(x: 100.0 + p * 17, y: 100.0 + run * 80 + p % 7),
                'l',
              );
            }
            engine.endStroke();
            times.add(clock.elapsedMicroseconds);
            final compose = Stopwatch()..start();
            final image = await tm.compositeLayerToImage('l');
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            image.dispose();
            composites.add(compose.elapsedMicroseconds);
          }
        } finally {
          tm.dispose();
        }
      });
      final stats = _stats(times);
      strokes['${brushes[id]!.name} ($id), 100 points'] = stats;
      if (stats['p95Ms']! > 4000) slow.add('stroke $id ${stats['p95Ms']}ms');
    }
    report['stroke'] = strokes;
    report['compositeLayerToImage'] = _stats(composites);
    expect(slow, isEmpty, reason: slow.join('\n'));
  });

  test('組み込みのフィルターを1回ずつ当てる（1920×1080）', () {
    final data = _sample();
    final filters = <String, Object?>{};
    for (final filter in FilterService.builtInFilters) {
      if (filter.kind == FilterKind.autoLineart) continue; // own timing below
      final times = <int>[];
      for (var run = 0; run < 2; run++) {
        final clock = Stopwatch()..start();
        runFilterPreview((
          filter: filter,
          data: data,
          width: _w,
          height: _h,
          scale: 1,
          canvasWidth: _w,
          canvasHeight: _h,
          mask: null,
          background: null,
          frameIndex: 0,
        ));
        times.add(clock.elapsedMicroseconds);
      }
      final stats = _stats(times);
      filters['${filter.name} (${filter.id})'] = stats;
      if (stats['p95Ms']! > 30000) {
        slow.add('filter ${filter.id} ${stats['p95Ms']}ms');
      }
    }
    report['filters'] = filters;
    expect(slow, isEmpty, reason: slow.join('\n'));
  });

  test('作品名の並べ替えと検索（5000件）', () {
    final names = [
      for (var i = 0; i < 5000; i++)
        '${const ['作品', 'Sketch ', 'アニメ', 'ﾃｽﾄ', 'Ｂｏｏｋ'][i % 5]}${5000 - i}',
    ];
    final sorts = <int>[];
    final searches = <int>[];
    for (var run = 0; run < 10; run++) {
      final clock = Stopwatch()..start();
      final keys = {for (final n in names) n: NameSortKey(n)};
      final sorted = [...names]
        ..sort((a, b) => compareNameKeys(keys[a]!, keys[b]!));
      sorts.add(clock.elapsedMicroseconds);
      expect(sorted.length, names.length);
      final search = Stopwatch()..start();
      final query = foldName('てすと');
      final found = names.where((n) => nameMatches(n, query)).length;
      searches.add(search.elapsedMicroseconds);
      expect(found, 1000);
    }
    report['sortNames5000'] = _stats(sorts);
    report['searchNames5000'] = _stats(searches);
    expect(_stats(sorts)['p95Ms']! < 2000, isTrue);
  });

  testWidgets('作品の保存・読み込み・書き出し（1920×1080、6コマ×2レイヤー）', (tester) async {
    const size = TileManager.tileSize;
    final picture = _sample();
    Uint8List tile(int tx, int ty, int shift) {
      final out = Uint8List(size * size * 4);
      for (var y = 0; y < size; y++) {
        final sy = ty * size + y;
        if (sy >= _h) break;
        for (var x = 0; x < size; x++) {
          final sx = (tx * size + x + shift) % _w;
          final from = (sy * _w + sx) * 4, to = (y * size + x) * 4;
          for (var c = 0; c < 4; c++) {
            out[to + c] = picture[from + c];
          }
        }
      }
      return out;
    }

    const layerIds = ['Layer0001', 'Layer0002'];
    final scene = Scene(
      id: 'Scene0001',
      index: 0,
      name: 'シーン1',
      frames: [
        for (var f = 0; f < 6; f++)
          Frame(
            index: f,
            layers: [
              for (final id in layerIds)
                Layer(id: id, name: id, type: LayerType.normal),
            ],
          ),
      ],
    );
    final data = <String, Map<String, Uint8List>>{};
    for (var f = 0; f < 6; f++) {
      for (var l = 0; l < layerIds.length; l++) {
        data[frameLayerKey(scene.id, f, layerIds[l])] = {
          for (var ty = 0; ty * size < _h; ty++)
            for (var tx = 0; tx * size < _w; tx++)
              '$tx,$ty': tile(tx, ty, f * 40 + l * 300),
        };
      }
    }
    final at = DateTime.utc(2026, 11, 24);
    final project = Project(
      id: 'perf',
      name: 'perf',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: at,
      updatedAt: at,
      totalWorkSeconds: 0,
      exportWidth: _w,
      exportHeight: _h,
    );
    final temp = Directory.systemTemp.createTempSync('niarim-perf-');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => temp.path,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        null,
      );
      temp.deleteSync(recursive: true);
    });

    final saves = <int>[], loads = <int>[], frames = <int>[], gifs = <int>[];
    var fileBytes = 0;
    await tester.runAsync(() async {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      try {
        tiles.importAll(data);
        for (var run = 0; run < 3; run++) {
          final path = '${temp.path}/perf_$run.niapro';
          final save = Stopwatch()..start();
          await NiaproSerializer.saveToPath(
            filePath: path,
            project: project,
            scenes: [scene],
            tileManager: tiles,
          );
          saves.add(save.elapsedMicroseconds);
          final bytes = File(path).readAsBytesSync();
          fileBytes = bytes.length;
          final load = Stopwatch()..start();
          final loaded = NiaproSerializer.loadFromBytes(bytes);
          loads.add(load.elapsedMicroseconds);
          expect(loaded.tileData.length, data.length);
        }
        final engine = ExportEngine();
        for (var run = 0; run < 2; run++) {
          for (var f = 0; f < 6; f++) {
            final clock = Stopwatch()..start();
            await engine.renderFrame(
              layers: scene.frames[f].layers,
              tileManager: tiles,
              sceneId: scene.id,
              frameIndex: f,
              drawingWidth: _w,
              drawingHeight: _h,
              width: _w,
              height: _h,
              backgroundColor: 0xFFFFFFFF,
              scene: scene,
            );
            frames.add(clock.elapsedMicroseconds);
          }
        }
        for (var run = 0; run < 2; run++) {
          final clock = Stopwatch()..start();
          final out = await engine.exportGif(
            projectName: 'perf',
            scenes: [scene],
            tileManager: tiles,
            fps: 12,
            drawingWidth: _w,
            drawingHeight: _h,
            width: 640,
            height: 360,
            backgroundColor: 0xFFFFFFFF,
          );
          gifs.add(clock.elapsedMicroseconds);
          File(out).deleteSync();
        }
      } finally {
        tiles.dispose();
      }
    });
    report['saveNiapro (6 frames x 2 layers)'] = {
      ..._stats(saves),
      'fileBytes': fileBytes,
    };
    report['loadNiapro (6 frames x 2 layers)'] = _stats(loads);
    report['exportRenderFrame (1920x1080)'] = _stats(frames);
    report['exportGif (6 frames, 640x360)'] = _stats(gifs);
    for (final (name, times, limit) in [
      ('save', saves, 60000),
      ('load', loads, 60000),
      ('renderFrame', frames, 10000),
      ('gif', gifs, 120000),
    ]) {
      final p95 = _stats(times)['p95Ms']!;
      if (p95 > limit) slow.add('$name ${p95}ms');
    }
    expect(slow, isEmpty, reason: slow.join('\n'));
  });
}
