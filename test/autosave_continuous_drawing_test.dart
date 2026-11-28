// 作品ファイルは線を描くたびには書かないので、描き続けている間の線は自動保存
// だけが持つ。休まず描き続けても、30秒を過ぎたら次の線を描き終えた所で書く
// （以前は3分ごとにしか書かず、その間に落ちると3分ぶんの線が残らなかった）。
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  void stroke(UndoManager undo) =>
      undo.push(ProjectEditUndoAction('stroke', () {}, () {}), projectId: 'p');

  testWidgets('drawing without a 5-second pause is saved within about 30 '
      'seconds, right after a stroke ends', (tester) async {
    final autosaves = AutosaveService();
    final projects = ProjectService();
    final undo = UndoManager();
    addTearDown(autosaves.dispose);
    addTearDown(projects.dispose);
    addTearDown(undo.dispose);
    autosaves.attach(projects, 'p', undoManager: undo);

    // A stroke every 2 seconds for 28 seconds: nothing is saved yet.
    for (var t = 0; t < 14; t++) {
      stroke(undo);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(autosaves.debugAutoSaveStarts, 0);
    // The 30 seconds run out between strokes; the next stroke is saved at
    // once.
    await tester.pump(const Duration(seconds: 2));
    expect(autosaves.debugAutoSaveStarts, 0);
    stroke(undo);
    expect(autosaves.debugAutoSaveStarts, 1);

    // The count starts again from the first change after that save (at 32
    // seconds), so it runs out at 62 seconds.
    for (var t = 0; t < 14; t++) {
      await tester.pump(const Duration(seconds: 2));
      stroke(undo);
    }
    await tester.pump(const Duration(seconds: 3));
    stroke(undo);
    expect(autosaves.debugAutoSaveStarts, 1);
    await tester.pump(const Duration(seconds: 1));
    stroke(undo);
    expect(autosaves.debugAutoSaveStarts, 2);
    autosaves.detach();
  });

  testWidgets('a pause of 5 seconds still saves as before', (tester) async {
    final autosaves = AutosaveService();
    final projects = ProjectService();
    final undo = UndoManager();
    addTearDown(autosaves.dispose);
    addTearDown(projects.dispose);
    addTearDown(undo.dispose);
    autosaves.attach(projects, 'p', undoManager: undo);
    stroke(undo);
    await tester.pump(const Duration(seconds: 4));
    expect(autosaves.debugAutoSaveStarts, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(autosaves.debugAutoSaveStarts, 1);
    // That save also ends the 30-second count: a later stroke waits for its
    // own pause again.
    await tester.pump(const Duration(seconds: 40));
    stroke(undo);
    expect(autosaves.debugAutoSaveStarts, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(autosaves.debugAutoSaveStarts, 2);
    autosaves.detach();
    debugPrint('autosaves: ${autosaves.debugAutoSaveStarts}');
  });
}
