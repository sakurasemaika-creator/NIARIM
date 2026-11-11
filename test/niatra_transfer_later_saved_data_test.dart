import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/canvas_size_preset.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）の決まりを作った後で足された保存の扱い：
/// - 書き出した共有ファイルのお気に入りと、書き出した作品のサムネイルの
///   選び方は、この端末のファイルの場所ごとの記録なので、書き出さず、
///   もう1台の記録で置き換えない。
/// - 保存したキャンバスの大きさは、起動時の読み込みと同じく範囲に収めてから
///   足す（以前の版は範囲外の大きさを保存できた。保存にはそのまま残る）。
/// - 作品の一覧のサムネイルの選び方は作品の中身に数えない（この端末で
///   選んでも、同じファイルの読み直しで作品を足さない）。

/// 今の保存（1台の端末の中身）。
Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_later_saved_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('the favourites of this device\'s exported share files and the '
      'thumbnails chosen for its exported works are neither exported nor '
      'replaced by the other device\'s', () async {
    // どれも、この端末のファイルの場所ごとの記録。
    Map<String, Object> records(String who) => {
      'niarim_outgoing_share_favorites': ['/$who/shares/one.niashare'],
      'work_file_thumbnail_covers':
          '{"/$who/works/clip.mp4":{"mode":"none","frameIndex":null,'
          '"imagePath":null}}',
      'exported_work_thumbnail_overrides_v1':
          '{"/$who/works/clip.mp4":{"mode":"custom",'
          '"imagePath":"/$who/covers/clip.png"}}',
    };
    SharedPreferences.setMockInitialValues({'language': 'ja', ...records('a')});
    final a = await TransferDevice.start();
    final bytes = await a.export();
    final local =
        NiatraSerializer.loadFromBytes(bytes).raw['localPreferences'] as Map;

    SharedPreferences.setMockInitialValues({'language': 'ja', ...records('b')});
    final b = await TransferDevice.start();
    await b.import(bytes, nextDir());
    // 記録を書き出していた版のファイルを読んでも書かない。
    await NiatraSerializer.restoreLocalPreferences(
      NiatraSerializer.loadFromBytes(bytes)
        ..raw['localPreferences'] = records('a'),
    );
    final prefs = await SharedPreferences.getInstance();
    for (final entry in records('b').entries) {
      expect(
        NiatraSerializer.deviceRecordKeys,
        contains(entry.key),
        reason: '${entry.key}: この端末の記録',
      );
      expect(
        local.containsKey(entry.key),
        isFalse,
        reason: '${entry.key}: この端末のファイルの場所は書き出さない',
      );
      expect(
        prefs.get(entry.key),
        entry.value,
        reason: '${entry.key}: この端末の記録のまま',
      );
    }
  });

  test(
    'a canvas size an earlier version saved outside the range arrives '
    'within the range, and reading the same file again adds nothing',
    () async {
      // 以前の版が保存した範囲外の大きさ。起動時の読み込みは範囲に収めるが、
      // 保存はそのまま残り、書き出しにもそのまま入る。
      const huge = '{"id":"size_old","name":"Huge","width":5000,"height":3000}';
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'custom_size_presets': [huge],
      });
      final a = await TransferDevice.start();
      final bytes = await a.export();
      expect(
        (NiatraSerializer.loadFromBytes(bytes).raw['localPreferences']
            as Map)['custom_size_presets'],
        [huge],
      );

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      var b = await TransferDevice.start();
      await b.import(bytes, nextDir());
      List<String> sizes(TransferDevice d) => [
        for (final p in d.settings.customSizePresets)
          '${p.name} ${p.width}x${p.height}',
      ];
      expect(sizes(b), [
        'Huge ${kMaxCanvasEdge}x$kMaxCanvasEdge',
      ], reason: '範囲に収めて足す（収めないと、上限を超えた作品を作れる）');

      // 起動し直して同じファイルを読み直しても、何も変わらない。
      final before = await _snapshot();
      SharedPreferences.setMockInitialValues(before);
      b = await TransferDevice.start();
      final report = TransferImportReport();
      await b.import(bytes, nextDir(), report: report);
      expect(sizes(b), ['Huge ${kMaxCanvasEdge}x$kMaxCanvasEdge']);
      expect(report.addedCopies, isEmpty);
      expect(await _snapshot(), before);

      // この端末が同じ範囲外の保存を持っていても、複製を足さない。
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'custom_size_presets': [huge],
      });
      final c = await TransferDevice.start();
      final same = TransferImportReport();
      await c.import(bytes, nextDir(), report: same);
      expect(sizes(c), ['Huge ${kMaxCanvasEdge}x$kMaxCanvasEdge']);
      expect(same.addedCopies, isEmpty);
    },
  );

  test('choosing how a project\'s thumbnail is made on this device does not '
      'make the same file add the project again', () async {
    // 作品の保存先（path_provider）を、端末ごとのフォルダへ向ける。
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var storage = temp;
    messenger.setMockMethodCallHandler(paths, (_) async => storage.path);
    addTearDown(() async {
      await settleTransfer();
      messenger.setMockMethodCallHandler(paths, null);
    });
    Future<ProjectService> device(String who) async {
      storage = Directory('${temp.path}/$who')..createSync(recursive: true);
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final service = ProjectService();
      await service.init();
      return service;
    }

    final a = await device('A');
    final work = await a.createProject(
      name: 'Work',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    await a.saveProject(work.id);
    final share = await NiaproSerializer.saveShare(
      project: a.projects.single,
      scenes: a.scenesOf(work.id),
      tileManager: a.tileManagerOf(work.id),
      outputDir: (Directory('${temp.path}/share')..createSync()).path,
    );
    final bytes = await (await TransferDevice.start()).export(
      items: const {},
      bundleImages: false,
      projectFiles: {'${work.id}.niashare': await share.readAsBytes()},
    );
    await settleTransfer();

    final b = await device('B');
    await NiatraSerializer.restoreProjects(
      NiatraSerializer.loadFromBytes(bytes),
      b,
    );
    expect([for (final p in b.projects) p.name], ['Work']);
    // 一覧のサムネイルを「なし」にする（作品の設定・絵は変えない）。
    await b.setProjectThumbnail(b.projects.single.id, mode: 'none');
    final report = TransferImportReport();
    await NiatraSerializer.restoreProjects(
      NiatraSerializer.loadFromBytes(bytes),
      b,
      report: report,
    );
    expect([for (final p in b.projects) p.name], ['Work']);
    expect(report.addedCopies, isEmpty);
    expect(b.projects.single.thumbnailMode, 'none', reason: 'この端末で選んだまま');
  });
}
