import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaのレイヤー全体変形で右下拡縮ハンドルをタッチ操作できUndo/Redoできる', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ps = ProjectService();
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final p = (await tester.runAsync(() => ps.createProject(
      name: 'whole-transform-functional', fps: 24, durationSeconds: 1,
      backgroundColor: 0x00000000, exportWidth: 96, exportHeight: 80,
    )))!;
    final scene = ps.scenesOf(p.id).first;
    final layer = ps.layersOf(p.id, scene.id, 0).first;
    final key = ps.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = ps.tileManagerOf(p.id);
    final initial = Uint8List(96 * 80 * 4);
    // 中心(48,40)から右下側に非対称矩形。縮小後の位置/面積を判定しやすくする。
    for (var y = 44; y < 68; y++) {
      for (var x = 54; x < 86; x++) {
        final i = (y * 96 + x) * 4;
        initial[i] = 220; initial[i + 1] = 55; initial[i + 2] = 40; initial[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, initial);
    final before = _read(tm, key, 96, 80);
    final beforeCount = _opaque(before);

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ...providers!,
        ChangeNotifierProvider<ProjectService>.value(value: ps),
        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(
        width: 288, height: 240,
        child: CanvasArea(project: p, currentLayerId: layer.id,
          currentTool: DrawingTool.transform, currentFrame: 0, sceneId: scene.id),
      )))),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(double x, double y) => origin + Offset(x * 3, y * 3);

    // 右下ハンドルは(96,80)。境界ちょうどを避け95.5,79.5から開始しても
    // hit threshold内なのでscaleモードになるはず。中心へ近付けて約0.6倍に縮小する。
    final g = await tester.startGesture(at(95.5, 79.5), kind: PointerDeviceKind.touch);
    await tester.pump();
    await g.moveTo(at(76.0, 64.0));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump();
    await _waitUndo(tester, undo, 1);

    final after = _read(tm, key, 96, 80);
    final afterCount = _opaque(after);
    expect(after, isNot(orderedEquals(before)), reason: '右下ハンドルのタッチドラッグが実画素変形へ到達すること');
    expect(afterCount, lessThan(beforeCount * 0.65), reason: '中心へドラッグしたため実画素面積が明確に縮小すること');
    expect(afterCount, greaterThan(beforeCount * 0.20));

    undo.undo(); await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm,key,96,80), orderedEquals(before));
    undo.redo(); await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm,key,96,80), orderedEquals(after));
  });
}

int _opaque(Uint8List d){var n=0;for(var i=3;i<d.length;i+=4)if(d[i]!=0)n++;return n;}
Future<void> _waitUndo(WidgetTester t,app_undo.UndoManager u,int n)async{final e=DateTime.now().add(const Duration(seconds:3));while(DateTime.now().isBefore(e)&&u.undoCount<n){await t.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));await t.pump();}expect(u.undoCount,n,reason:'変形操作がUndo履歴へ確定すること');}
Uint8List _read(dynamic tm,String key,int w,int h){final o=Uint8List(w*h*4);final tile=tm.getTile(key,0,0) as Uint8List?;if(tile==null)return o;for(var y=0;y<h;y++)o.setRange(y*w*4,(y+1)*w*4,tile,y*256*4);return o;}
