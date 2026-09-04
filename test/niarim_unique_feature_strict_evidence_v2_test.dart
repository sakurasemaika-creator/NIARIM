import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/niarim-unique-strict-v2');
  setUpAll(() => out.createSync(recursive: true));

  test('眼鏡断層: マスク無し・空マスク・strength 0 は完全無変更', () {
    const w = 180, h = 120;
    final src = _grid(w, h);
    final e = FilterEngine();
    expect(e.applyLensDistortion(Uint8List.fromList(src), w, h, 70, null), orderedEquals(src));
    expect(e.applyLensDistortion(Uint8List.fromList(src), w, h, 70, Uint8List(w*h*4)), orderedEquals(src));
    final mask = _ellipseMask(w,h,90,60,55,40);
    expect(e.applyLensDistortion(Uint8List.fromList(src), w, h, 0, mask), orderedEquals(src));
  });

  test('眼鏡断層: 選択範囲だけ変形し範囲外は完全保持', () async {
    const w=220,h=150;
    final src=_grid(w,h), mask=_twoSeparatedMasks(w,h);
    final got=FilterEngine().applyLensDistortion(Uint8List.fromList(src),w,h,78,mask);
    var inChanged=0,inTotal=0,outChanged=0;
    for(var p=0;p<w*h;p++){
      final i=p*4, inside=mask[i+3]>0;
      final changed=src[i]!=got[i]||src[i+1]!=got[i+1]||src[i+2]!=got[i+2]||src[i+3]!=got[i+3];
      if(inside){inTotal++;if(changed)inChanged++;} else if(changed){outChanged++;}
    }
    expect(inTotal,greaterThan(2500));
    expect(inChanged/inTotal,greaterThan(.15));
    expect(outChanged,0);
    await _save(src,w,h,'${out.path}/lens_input.png');
    await _save(mask,w,h,'${out.path}/lens_mask_two_separated.png');
    await _save(got,w,h,'${out.path}/lens_positive_78.png');
  });

  test('眼鏡断層: 正負度数が異なる視覚結果を生成', () async {
    const w=200,h=140;
    final src=_grid(w,h), mask=_ellipseMask(w,h,100,70,62,48), e=FilterEngine();
    final plus=e.applyLensDistortion(Uint8List.fromList(src),w,h,82,mask);
    final minus=e.applyLensDistortion(Uint8List.fromList(src),w,h,-82,mask);
    expect(_mad(src,plus),greaterThan(1));
    expect(_mad(src,minus),greaterThan(1));
    expect(_mad(plus,minus),greaterThan(1.2));
    await _save(plus,w,h,'${out.path}/lens_convex_plus82.png');
    await _save(minus,w,h,'${out.path}/lens_concave_minus82.png');
  });

  test('眼鏡断層: 中心オフセット X/Y は各々出力を変える', () async {
    const w=220,h=150;
    final src=_grid(w,h), mask=_ellipseMask(w,h,110,75,70,52), e=FilterEngine();
    final base=e.applyLensDistortion(Uint8List.fromList(src),w,h,75,mask);
    final xp=e.applyLensDistortion(Uint8List.fromList(src),w,h,75,mask,centerOffsetX:22);
    final xm=e.applyLensDistortion(Uint8List.fromList(src),w,h,75,mask,centerOffsetX:-22);
    final yp=e.applyLensDistortion(Uint8List.fromList(src),w,h,75,mask,centerOffsetY:18);
    final ym=e.applyLensDistortion(Uint8List.fromList(src),w,h,75,mask,centerOffsetY:-18);
    for(final v in [xp,xm,yp,ym]) expect(_mad(base,v),greaterThan(.5));
    expect(_mad(xp,xm),greaterThan(.8));
    expect(_mad(yp,ym),greaterThan(.8));
    await _save(base,w,h,'${out.path}/lens_center_default.png');
    await _save(xp,w,h,'${out.path}/lens_center_x_plus22.png');
    await _save(xm,w,h,'${out.path}/lens_center_x_minus22.png');
    await _save(yp,w,h,'${out.path}/lens_center_y_plus18.png');
    await _save(ym,w,h,'${out.path}/lens_center_y_minus18.png');
  });

  test('眼鏡断層: 2連結成分を独立処理し中央の未選択帯は不変', () async {
    const w=240,h=150;
    final src=_grid(w,h), mask=_twoSeparatedMasks(w,h), e=FilterEngine();
    // 中央帯が本当に未選択であることを先に証明。
    for(var y=45;y<110;y++) for(var x=106;x<134;x++) expect(mask[(y*w+x)*4+3],0);
    final got=e.applyLensDistortion(Uint8List.fromList(src),w,h,72,mask);
    expect(_regionMad(src,got,w,22,35,96,120),greaterThan(1));
    expect(_regionMad(src,got,w,144,35,218,120),greaterThan(1));
    expect(_regionMad(src,got,w,106,45,134,110),0);
    await _save(got,w,h,'${out.path}/lens_two_components.png');
  });

  test('オーロラホログラム: 6プリセットが固有出力・alpha保持', () async {
    const w=160,h=96;
    final src=_ramp(w,h), e=FilterEngine();
    final outputs=<AuroraHologramPreset,Uint8List>{};
    for(final p in AuroraHologramPreset.values){
      final got=e.applyAuroraHologram(Uint8List.fromList(src),w,h,strength:100,brightness:0,saturation:0,preset:p);
      outputs[p]=got;
      for(var i=3;i<got.length;i+=4) expect(got[i],src[i]);
      expect(_mad(src,got),greaterThan(5));
      await _save(got,w,h,'${out.path}/hologram_${p.name}.png');
    }
    for(var i=0;i<AuroraHologramPreset.values.length;i++) for(var j=i+1;j<AuroraHologramPreset.values.length;j++) expect(_mad(outputs[AuroraHologramPreset.values[i]]!,outputs[AuroraHologramPreset.values[j]]!),greaterThan(1));
  });

  test('背景馴染ませ: 方向反転で出力が反転し強度変化も反映', () async {
    const w=180,h=120;
    final src=_subject(w,h),e=FilterEngine();
    final d0=e.applyBackgroundBlend(Uint8List.fromList(src),w,h,0xFF8CB0D0,0,18,5);
    final d180=e.applyBackgroundBlend(Uint8List.fromList(src),w,h,0xFF8CB0D0,180,18,5);
    final longer=e.applyBackgroundBlend(Uint8List.fromList(src),w,h,0xFF8CB0D0,0,30,9);
    expect(_mad(src,d0),greaterThan(.5));
    expect(_mad(d0,d180),greaterThan(.5));
    expect(_mad(d0,longer),greaterThan(.25));
    await _save(src,w,h,'${out.path}/background_blend_input.png');
    await _save(d0,w,h,'${out.path}/background_blend_0.png');
    await _save(d180,w,h,'${out.path}/background_blend_180.png');
    await _save(longer,w,h,'${out.path}/background_blend_long_blur.png');
  });
}

Uint8List _grid(int w,int h){final o=Uint8List(w*h*4);for(var y=0;y<h;y++)for(var x=0;x<w;x++){final i=(y*w+x)*4,l=x%14<2||y%14<2;o[i]=l?30:x*255~/math.max(1,w-1);o[i+1]=l?40:y*255~/math.max(1,h-1);o[i+2]=l?55:(x+y)*255~/math.max(1,w+h-2);o[i+3]=255;}return o;}
Uint8List _ellipseMask(int w,int h,double cx,double cy,double rx,double ry){final o=Uint8List(w*h*4);for(var y=0;y<h;y++)for(var x=0;x<w;x++){final dx=(x-cx)/rx,dy=(y-cy)/ry;if(dx*dx+dy*dy<=1){final i=(y*w+x)*4;o[i]=o[i+1]=o[i+2]=o[i+3]=255;}}return o;}
Uint8List _twoSeparatedMasks(int w,int h){final a=_ellipseMask(w,h,w*.27,h*.52,w*.15,h*.27),b=_ellipseMask(w,h,w*.73,h*.52,w*.15,h*.27);for(var i=0;i<a.length;i+=4)if(b[i+3]>0){a[i]=a[i+1]=a[i+2]=a[i+3]=255;}return a;}
Uint8List _ramp(int w,int h){final o=Uint8List(w*h*4);for(var y=0;y<h;y++)for(var x=0;x<w;x++){final i=(y*w+x)*4,v=x*255~/math.max(1,w-1);o[i]=o[i+1]=o[i+2]=v;o[i+3]=(x+y)%17==0?120:255;}return o;}
Uint8List _subject(int w,int h){final o=Uint8List(w*h*4);for(var y=28;y<h-26;y++)for(var x=48;x<w-46;x++){final i=(y*w+x)*4;o[i]=220;o[i+1]=120;o[i+2]=82;o[i+3]=255;}return o;}
double _mad(Uint8List a,Uint8List b){double s=0;for(var i=0;i<a.length;i++)s+=(a[i]-b[i]).abs();return s/a.length;}
double _regionMad(Uint8List a,Uint8List b,int w,int x0,int y0,int x1,int y1){double s=0;var n=0;for(var y=y0;y<y1;y++)for(var x=x0;x<x1;x++){final i=(y*w+x)*4;for(var c=0;c<4;c++){s+=(a[i+c]-b[i+c]).abs();n++;}}return n==0?0:s/n;}
Future<void> _save(Uint8List rgba,int w,int h,String p)async{final c=Completer<ui.Image>();ui.decodeImageFromPixels(rgba,w,h,ui.PixelFormat.rgba8888,c.complete);final im=await c.future,d=await im.toByteData(format:ui.ImageByteFormat.png);im.dispose();await File(p).writeAsBytes(d!.buffer.asUint8List());}
