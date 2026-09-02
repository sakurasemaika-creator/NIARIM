import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('入力イベント密度：カスタムフェードは2点だけの長い線でも途中位置に応じて連続的に細く薄くなる', () async {
    final sparse = await _drawFade(segments: 1);
    final dense = await _drawFade(segments: 50);
    await _saveRgba(sparse, 260, 100, '${out.path}/fade_sparse_input.png');
    await _saveRgba(dense, 260, 100, '${out.path}/fade_dense_input.png');

    final sEarly = _verticalSpan(sparse, 260, 100, 55, threshold: 8);
    final sMid = _verticalSpan(sparse, 260, 100, 130, threshold: 8);
    final sLate = _verticalSpan(sparse, 260, 100, 205, threshold: 8);
    final aEarly = _pixel(sparse, 260, 55, 50)[3];
    final aMid = _pixel(sparse, 260, 130, 50)[3];
    final aLate = _pixel(sparse, 260, 205, 50)[3];

    expect(sEarly, greaterThan(sMid), reason: 'sparse input must still taper progressively');
    expect(sMid, greaterThan(sLate));
    expect(aEarly, greaterThan(aMid));
    expect(aMid, greaterThan(aLate));

    // 同じ幾何パスなら、OSから届くmoveイベント数の違いで見た目が大きく変わらないこと。
    expect((sEarly - _verticalSpan(dense, 260, 100, 55, threshold: 8)).abs(), lessThanOrEqualTo(2));
    expect((sMid - _verticalSpan(dense, 260, 100, 130, threshold: 8)).abs(), lessThanOrEqualTo(2));
    expect((sLate - _verticalSpan(dense, 260, 100, 205, threshold: 8)).abs(), lessThanOrEqualTo(2));
    expect((aEarly - _pixel(dense, 260, 55, 50)[3]).abs(), lessThanOrEqualTo(12));
    expect((aMid - _pixel(dense, 260, 130, 50)[3]).abs(), lessThanOrEqualTo(12));
    expect((aLate - _pixel(dense, 260, 205, 50)[3]).abs(), lessThanOrEqualTo(12));
  });

  test('入力イベント密度：ストローク減衰も2点だけの長い線で距離に沿って徐々に薄くなる', () async {
    final tm = TileManager(canvasWidth: 260, canvasHeight: 90);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, strokeDecay: true)
      ..currentColor = const ui.Color(0xFF206040);
    e.beginStroke(const StrokePoint(x: 20, y: 45), 'decay');
    e.continueStroke(const StrokePoint(x: 240, y: 45), 'decay');
    e.endStroke();
    final image = await tm.compositeLayerToImage('decay');
    await _save(image, '${out.path}/stroke_decay_sparse_input.png');
    final d = await _rgba(image);
    final early = _pixel(d, 260, 55, 45)[3];
    final mid = _pixel(d, 260, 130, 45)[3];
    final late = _pixel(d, 260, 205, 45)[3];
    expect(early, greaterThan(mid), reason: 'decay must use traveled distance within a long segment');
    expect(mid, greaterThan(late));
    image.dispose();
    tm.dispose();
  });
}

Future<Uint8List> _drawFade({required int segments}) async {
  final tm = TileManager(canvasWidth: 260, canvasHeight: 100);
  final e = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(
      size: 30,
      fadeMode: FadeMode.custom,
      fadeCustom: const FadeCustomSettings(startValue: 100, endValue: 20, distancePx: 220),
    )
    ..currentColor = const ui.Color(0xFF2040C0);
  const x0 = 20.0, x1 = 240.0;
  e.beginStroke(const StrokePoint(x: x0, y: 50), 'fade');
  for (var i = 1; i <= segments; i++) {
    final t = i / segments;
    e.continueStroke(StrokePoint(x: x0 + (x1 - x0) * t, y: 50), 'fade');
  }
  e.endStroke();
  final image = await tm.compositeLayerToImage('fade');
  final d = await _rgba(image);
  image.dispose();
  tm.dispose();
  return d;
}

Brush _brush({
  required double size,
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
  bool strokeDecay = false,
}) => Brush(
  id: 'audit13', name: 'audit13', size: size, opacity: 100, spacing: 1,
  blurRadius: 0, stabilization: false, stabilizationStrength: 0,
  pixelMode: false, pressureMode: PressureMode.off, pressureStrength: 100,
  fadeMode: fadeMode, fadeCustom: fadeCustom, strokeDecay: strokeDecay,
  mixingMode: BrushMixingMode.off, mixingRate: 0,
);

int _verticalSpan(Uint8List d,int width,int height,int x,{required int threshold}){
  var minY=height,maxY=-1;
  for(var y=0;y<height;y++) if(d[(y*width+x)*4+3]>=threshold){minY=math.min(minY,y);maxY=math.max(maxY,y);}
  return maxY<minY?0:maxY-minY+1;
}

List<int> _pixel(List<int> d,int width,int x,int y){final i=(y*width+x)*4;return[d[i],d[i+1],d[i+2],d[i+3]];}
Future<Uint8List> _rgba(ui.Image i)async=>(await i.toByteData(format:ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
Future<void> _save(ui.Image i,String p)async{final d=await i.toByteData(format:ui.ImageByteFormat.png);await File(p).writeAsBytes(d!.buffer.asUint8List());}
Future<void> _saveRgba(Uint8List rgba,int w,int h,String p)async{
  final b=await ui.ImmutableBuffer.fromUint8List(rgba);final desc=ui.ImageDescriptor.raw(b,width:w,height:h,pixelFormat:ui.PixelFormat.rgba8888);
  final c=await desc.instantiateCodec();final f=await c.getNextFrame();final png=await f.image.toByteData(format:ui.ImageByteFormat.png);
  await File(p).writeAsBytes(png!.buffer.asUint8List());f.image.dispose();c.dispose();desc.dispose();b.dispose();
}
