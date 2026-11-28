import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';

const _side = ProjectService.thumbnailLongSide;

/// 一覧のサムネイル（長辺200px）と同じ大きさの、細い斜めの線の絵。
Future<Uint8List> _thinLines() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, _side + 0.0, _side + 0.0),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final pen = ui.Paint()
    ..color = const ui.Color(0xFF000000)
    ..strokeWidth = 1.2;
  canvas.drawLine(const ui.Offset(20, 30), const ui.Offset(180, 170), pen);
  canvas.drawLine(const ui.Offset(20, 170), const ui.Offset(180, 60), pen);
  final image = await recorder.endRecording().toImage(_side, _side);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

/// [png]を幅[decodeWidth]で読み（一覧の`Image.file`の`cacheWidth`と同じ）、
/// Imageの既定の補間で[shown]四方へ描いた画素。
Future<Uint8List> _shown(Uint8List png, int? decodeWidth, int shown) async {
  final codec = await ui.instantiateImageCodec(png, targetWidth: decodeWidth);
  final decoded = (await codec.getNextFrame()).image;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    decoded,
    ui.Rect.fromLTWH(0, 0, decoded.width + 0.0, decoded.height + 0.0),
    ui.Rect.fromLTWH(0, 0, shown + 0.0, shown + 0.0),
    ui.Paint()..filterQuality = Image.file(File('x')).filterQuality,
  );
  final out = await recorder.endRecording().toImage(shown, shown);
  final rgba = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  decoded.dispose();
  out.dispose();
  return rgba!.buffer.asUint8List();
}

/// 線（(20,30)→(180,170)）が通る列ごとの、線を横切る濃さの合計のばらつき
/// （標準偏差÷平均）。点線になるほど大きい。
double _unevenness(Uint8List rgba, int shown) {
  final scale = shown / _side;
  final sums = <double>[];
  for (var x = (40 * scale).ceil(); x < (160 * scale).floor(); x++) {
    final centre = (30 + 140 * ((x + 0.5) / scale - 20) / 160) * scale;
    var sum = 0.0;
    for (var y = (centre - 4).floor(); y <= (centre + 4).ceil(); y++) {
      if (y < 0 || y >= shown) continue;
      sum += 1 - rgba[(y * shown + x) * 4] / 255;
    }
    sums.add(sum);
  }
  final mean = sums.reduce((a, b) => a + b) / sums.length;
  final variance =
      sums.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
      sums.length;
  return math.sqrt(variance) / mean;
}

/// 詳細の行の小さなサムネイルで、細い線が点線になったり消えたりしない
/// （画面の倍率1の詳細の行で発見、P3-14）。表示の画素数で読むと、読み込みの
/// 縮小が間の画素を平均しないので線が途切れた。保存の絵の半分の幅以上で読み、
/// 描くときに縮める。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('small rows read at least half of the stored picture', () {
    expect(projectThumbnailDecodeWidth(48, 1), 96);
    expect(projectThumbnailDecodeWidth(40, 1), 80);
    expect(projectThumbnailDecodeWidth(58, 1), 100);
    // 表示の画素数が保存の絵の半分以上なら今までどおり（メモリを増やさない）。
    expect(projectThumbnailDecodeWidth(48, 2.75), 132);
    expect(projectThumbnailDecodeWidth(64, 2), 128);
  });

  testWidgets('thin lines stay whole in a 40–64px row at 1x', (tester) async {
    await tester.runAsync(() async {
      final png = await _thinLines();
      for (final shown in [40, 48, 58, 64]) {
        final now = _unevenness(
          await _shown(png, projectThumbnailDecodeWidth(shown + 0.0, 1), shown),
          shown,
        );
        final full = _unevenness(await _shown(png, null, shown), shown);
        // 元の大きさで読んで描いたときと同じほど、線が途切れずに続く。
        expect(now, lessThan(full + 0.08), reason: '$shown px');
        expect(now, lessThan(0.4), reason: '$shown px');
      }
    });
  });
}
