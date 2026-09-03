// 上書き保存が失敗しても直前の保存が失われないことを確認する。
//
// 【経緯】saveToSlotは以前、新しいアーカイブを書き込む「前」に既存
// スロットのノードを一覧から外していた。そのため書き込みが失敗すると
// （空き容量不足・書き込みエラー等）新しい保存が作られないまま古い保存
// だけが消え、上書き保存の失敗がそのままデータ損失になっていた。
// 書き込み成功後に入れ替える順序へ直したことを固定する。
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('niarim_overwrite');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  testWidgets('上書き保存が失敗しても直前の保存が残る', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final ps = ProjectService();
      await ps.init();
      final sts = SaveTreeService();

      final project = await ps.createProject(
        name: '上書き検証',
        fps: 24,
        durationSeconds: 5,
        backgroundColor: 0xFFFFFFFF,
      );
      final pid = project.id;

      // 1回目：正常に保存する。
      await sts.saveToSlot(
        projectId: pid,
        slotIndex: 0,
        project: project,
        scenes: ps.scenesOf(pid),
        tileManager: ps.tileManagerOf(pid),
        comment: '最初の保存',
      );
      expect(sts.getNodes(pid).length, 1);
      final firstNodeId = sts.getNodes(pid).first.id;

      // 2回目：同じスロットへの上書きを、書き込みが失敗する状況で行う。
      // 保存先ディレクトリの実際の場所を探し、ディレクトリを同名ファイルへ
      // 置き換えて書き込み不能にする。
      Directory? saveDir;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is Directory && entity.path.endsWith('SaveTree')) {
          saveDir = entity;
          break;
        }
      }
      expect(saveDir, isNotNull, reason: 'SaveTreeディレクトリが見つからない');
      saveDir!.deleteSync(recursive: true);
      File(saveDir.path).writeAsStringSync('block');

      Object? thrown;
      try {
        await sts.saveToSlot(
          projectId: pid,
          slotIndex: 0,
          project: project,
          scenes: ps.scenesOf(pid),
          tileManager: ps.tileManagerOf(pid),
          comment: '失敗する上書き',
        );
      } catch (e) {
        thrown = e;
      }

      // 書き込みに失敗したこと自体は想定どおり。重要なのはその後の状態。
      expect(thrown, isNotNull, reason: '書き込み不能な状況を作れていない');
      final nodes = sts.getNodes(pid);
      expect(nodes.length, 1, reason: '上書き失敗で保存が消えている');
      expect(nodes.first.id, firstNodeId, reason: '直前の保存が別物になっている');
      expect(nodes.first.comment, '最初の保存');
    });
  }, timeout: const Timeout(Duration(seconds: 90)));
}
