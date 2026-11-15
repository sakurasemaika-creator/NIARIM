import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 作品を保存したとき、保存のファイル（マニフェスト）に書く最終保存の日時と、
/// 一覧が覚えている最終保存の日時は同じ値になる。
///
/// 以前は保存のファイルへ書く日時と一覧の日時を別々に`DateTime.now()`で
/// 取っていて、数ミリ秒ずれた。ゴミ箱へ移す前の保存は一覧の日時をそのまま
/// 書くので、お気に入りの作品をゴミ箱へ移すのを断ったときも保存のファイルが
/// 書き換わった（最終保存の日時が数ミリ秒進む）。保存の中の各項目の日時
/// （zipの更新日時）も保存した時刻で、2秒ごとに変わるので、同じ作品を
/// 書き直すだけでもファイルが変わった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  final services = <ProjectService>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('save-updated-at-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() {
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  /// 起動（保存から読み直す）。
  Future<ProjectService> start() async {
    final service = ProjectService();
    services.add(service);
    await service.init();
    return service;
  }

  Future<File> archive(String id) async =>
      File('${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro');

  /// 保存のファイルのマニフェストに書かれた最終保存の日時。
  Future<DateTime> savedUpdatedAt(String id) async =>
      (await NiaproSerializer.load((await archive(id)).path)).project.updatedAt;

  test('a new project and every later save write the same last saved time '
      'to the save file and to the list', () async {
    final service = await start();
    final project = await service.createProject(
      name: 'Clock',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    );
    final created = service.projects.single.updatedAt;
    final onDisk = await savedUpdatedAt(project.id);
    debugPrint('CREATED list=$created file=$onDisk');
    expect(onDisk, created, reason: 'the first save of a new project');

    var previous = created;
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 3));
      await service.saveProject(project.id);
      final listed = service.projects.single.updatedAt;
      final written = await savedUpdatedAt(project.id);
      debugPrint('SAVE $i list=$listed file=$written');
      expect(written, listed, reason: 'save $i');
      expect(listed.isAfter(previous), isTrue, reason: 'save $i moves it on');
      previous = listed;
    }

    // 起動し直しても同じ日時（一覧の並び・最終保存の表示が変わらない）。
    final reloaded = await start();
    expect(reloaded.projects.single.updatedAt, previous);
  });

  test('refusing to move a favourite to the Trash leaves its save file byte '
      'for byte, also a few seconds after it was saved', () async {
    final service = await start();
    final project = await service.createProject(
      name: 'Kept',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    );
    await service.toggleFavorite(project.id);
    await service.saveProject(project.id);
    final file = await archive(project.id);
    final bytes = file.readAsBytesSync();
    final listed = service.projects.single.updatedAt;

    // zipの項目の日時は2秒刻み。次の刻みへ進んでから断られる操作をする。
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    await expectLater(
      service.deleteProject(project.id),
      throwsA(isA<FavoriteProjectDeleteException>()),
    );
    final after = file.readAsBytesSync();
    debugPrint(
      'REFUSED TRASH sameBytes=${listEquals(after, bytes)} '
      'list=${service.projects.single.updatedAt} '
      'file=${await savedUpdatedAt(project.id)}',
    );
    expect(service.projects.single.updatedAt, listed);
    expect(await savedUpdatedAt(project.id), listed);
    expect(listEquals(after, bytes), isTrue, reason: 'the save file changed');
  });
}
