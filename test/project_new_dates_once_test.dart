import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 作った・取り込んだ・複製した作品の作成日時と最終保存の日時は、同じ1回の
/// 時刻にする。
///
/// 以前は`createdAt`と`updatedAt`をそれぞれ`DateTime.now()`で読んでいたので、
/// 読む間に時計が1マイクロ秒進むと、まだ一度も変えていない作品の最終保存が
/// 作成より後になり、新しく作った作品ではその値がファイルにも書かれた。
///
/// ずれるのは2回の読み取りの間に時計の目盛りをまたいだときだけなので、
/// 1回では見逃すことがある。同じ操作を何度も繰り返し、どの回でもそろって
/// いることを確かめる（直す前は、どの操作も数十回のうちに必ずずれた）。
///
/// 複製は一覧へ加えた直後に保存し、保存の時刻が最終保存になる。そこで、
/// 複製の最初の保存が書き始めた時点の一覧の値（保存の間に一覧を描くと
/// 出る値）を[_SaveProbe]で取り出して確かめる。
final class _SaveProbe extends IOOverrides {
  _SaveProbe(this.service);

  final ProjectService service;
  final seen = <String, Project>{};

  @override
  File createFile(String path) {
    if (path.endsWith('.niapro')) {
      for (final p in service.projects) {
        seen.putIfAbsent(p.id, () => p);
      }
    }
    return super.createFile(path);
  }
}

const _rounds = 150;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_new_dates_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({'first_launch': false});
  });

  tearDown(() {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<Project> create(ProjectService service, int i) =>
      service.createProject(
        name: 'P$i',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 16,
        exportHeight: 16,
      );

  test('a new project is created and last saved at the same moment', () async {
    final service = ProjectService();
    addTearDown(service.dispose);
    final mismatched = <String>[];
    for (var i = 0; i < _rounds; i++) {
      final project = await create(service, i);
      final listed = service.projects.firstWhere((p) => p.id == project.id);
      if (project.createdAt != project.updatedAt ||
          listed.createdAt != listed.updatedAt) {
        mismatched.add('${project.createdAt} / ${project.updatedAt}');
      }
    }
    expect(mismatched, isEmpty);

    // The file the first save wrote has the same two dates.
    final last = service.projects.last;
    final saved = await NiaproSerializer.load(
      '${tempDir.path}/niarim/projects/${last.id}/${last.id}.niapro',
    );
    expect(saved.project.updatedAt, saved.project.createdAt);
  });

  test('an imported shared project is created and last saved at the same '
      'moment', () async {
    final service = ProjectService();
    addTearDown(service.dispose);
    final received = Project(
      id: 'sender_project',
      name: 'Received',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2025, 1, 2),
      updatedAt: DateTime(2025, 3, 4),
      totalWorkSeconds: 0,
      exportWidth: 16,
      exportHeight: 16,
    );
    final mismatched = <String>[];
    for (var i = 0; i < _rounds; i++) {
      final project = await service.importSharedProject(
        NiaproData(project: received, scenes: const [], tileData: const {}),
      );
      if (project.createdAt != project.updatedAt) {
        mismatched.add('${project.createdAt} / ${project.updatedAt}');
      }
    }
    expect(mismatched, isEmpty);
  });

  test('a duplicated project is created and last saved at the same moment '
      'until its first save', () async {
    final service = ProjectService();
    addTearDown(service.dispose);
    final original = await create(service, 0);
    final probe = _SaveProbe(service);
    final mismatched = <String>[];
    for (var i = 0; i < _rounds; i++) {
      final before = {for (final p in service.projects) p.id};
      IOOverrides.global = probe;
      expect(await service.duplicateProject(original.id), isTrue);
      IOOverrides.global = null;
      final copyId = service.projects
          .firstWhere((p) => !before.contains(p.id))
          .id;
      final whileSaving = probe.seen[copyId];
      expect(whileSaving, isNotNull);
      if (whileSaving!.createdAt != whileSaving.updatedAt) {
        mismatched.add('${whileSaving.createdAt} / ${whileSaving.updatedAt}');
      }
      // The save then makes its own time the last saved one.
      final copy = service.projects.firstWhere((p) => p.id == copyId);
      expect(copy.createdAt, whileSaving.createdAt);
      expect(copy.updatedAt.isBefore(copy.createdAt), isFalse);
    }
    expect(mismatched, isEmpty);
  });
}
