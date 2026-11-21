import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 作品・受け取った作品にお気に入りの星を付け外ししても、最終保存
/// （`updatedAt`、ホームの「更新日時」の並びとプロジェクト詳細の「最終保存」）は
/// 変わらず、作品の中身も書き直さない。お気に入りは起動し直しても残る。
///
/// 以前は星を付けるたびに作品を保存し直し、保存の最終保存の日時が星の時刻に
/// なった。その起動の中では一覧の値が前のままなので気づきにくく、起動し
/// 直すと星を付けた作品が「更新日時」の並びの先頭へ動いた（受け取った共有の
/// 作品で、Linuxの実操作で見つけた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  final services = <ProjectService>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('favorite-last-saved-');
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

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

  /// 更新日時の新しい順（ホームの既定の並び）の名前。
  List<String> byUpdated(Iterable<Project> projects) =>
      ([...projects]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
          .map((p) => p.name)
          .toList();

  Map<String, DateTime> updatedOf(ProjectService service) => {
    for (final p in service.projects) p.name: p.updatedAt,
  };

  Future<File> archive(String id) async =>
      File('${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro');

  /// 保存の中身（マニフェストは項目ごと、ほかは項目のバイト列）。
  Future<Map<String, Object?>> contents(String id) async {
    final zip = ZipDecoder().decodeBytes(
      await (await archive(id)).readAsBytes(),
    );
    return {
      for (final file in zip.files)
        if (file.isFile)
          file.name: file.name == 'manifest.json'
              ? jsonDecode(utf8.decode(file.content as List<int>))
              : base64Encode(file.content as List<int>),
    };
  }

  Future<Project> received(ProjectService service, String name) async {
    final project = await service.importSharedProject(
      NiaproData(
        project: Project(
          id: 'source-$name',
          name: name,
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 64,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          totalWorkSeconds: 0,
        ),
        scenes: const [
          Scene(id: 'Scene0001', index: 0, frames: [Frame(index: 0)]),
        ],
        tileData: const {},
      ),
    );
    await service.saveProject(project.id);
    return project;
  }

  test('starring and unstarring a project and a received work keeps their '
      'last saved time and the order by last saved after a restart, and '
      'the stars are kept', () async {
    final first = await start();
    for (final name in ['Alpha', 'Bravo']) {
      final p = await first.createProject(
        name: name,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      await first.saveProject(p.id);
      await tick();
    }
    await received(first, 'Whiskey');
    await tick();
    await received(first, 'Charlie');
    await tick();

    // 星を付ける前の、起動し直した一覧（保存に書いた最終保存）。
    final before = await start();
    final savedBefore = updatedOf(before);
    final orderBefore = byUpdated(before.projects);
    expect(orderBefore, ['Charlie', 'Whiskey', 'Bravo', 'Alpha']);
    final alpha = before.projects.firstWhere((p) => p.name == 'Alpha');
    final whiskey = before.projects.firstWhere((p) => p.name == 'Whiskey');
    final bravo = before.projects.firstWhere((p) => p.name == 'Bravo');
    expect(whiskey.isSharedImport, isTrue);
    final alphaContents = await contents(alpha.id);
    await tick();

    await before.toggleFavorite(alpha.id);
    await before.setFavorite(whiskey.id, true);
    await before.setFavorite(bravo.id, true);
    await tick();
    await before.setFavorite(bravo.id, false);
    // この起動の中の値も変わらない。
    expect(updatedOf(before), savedBefore);

    final after = await start();
    expect(updatedOf(after), savedBefore, reason: 'last saved moved');
    expect(byUpdated(after.projects), orderBefore);
    final stars = {for (final p in after.projects) p.name: p.isFavorite};
    expect(stars, {
      'Alpha': true,
      'Bravo': false,
      'Whiskey': true,
      'Charlie': false,
    });

    // 作品の中身は書き直さず、マニフェストもお気に入りの印だけが変わる。
    final alphaAfter = await contents(alpha.id);
    expect(alphaAfter.keys.toSet(), alphaContents.keys.toSet());
    for (final name in alphaContents.keys) {
      if (name == 'manifest.json') continue;
      expect(alphaAfter[name], alphaContents[name], reason: name);
    }
    final manifestBefore = Map<String, Object?>.of(
      alphaContents['manifest.json']! as Map<String, Object?>,
    );
    final manifestAfter = Map<String, Object?>.of(
      alphaAfter['manifest.json']! as Map<String, Object?>,
    );
    expect(manifestBefore['isFavorite'], isFalse);
    expect(manifestAfter['isFavorite'], isTrue);
    manifestBefore.remove('isFavorite');
    manifestAfter.remove('isFavorite');
    expect(manifestAfter, manifestBefore);
  });

  test('a star on a work whose save file is gone writes the work again with '
      'its last saved time, and the star is kept', () async {
    final first = await start();
    final p = await first.createProject(
      name: 'Lost',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    );
    await first.saveProject(p.id);
    await (await archive(p.id)).delete();
    await tick();

    await first.toggleFavorite(p.id);
    final after = await start();
    expect(after.projects.single.isFavorite, isTrue);
    expect(after.projects.single.updatedAt, first.projects.single.updatedAt);
  });
}
