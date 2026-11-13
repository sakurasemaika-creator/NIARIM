import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 手動の保存で、前の保存の後片付け（保存の控え`{id}.pending.json`・
/// サムネイル・前の保存のファイルを消す）が「見つからない」以外で失敗しても、
/// 新しい保存は書けているので失敗にしないこと。以前は、新しい保存を書いた
/// 後で`saveToSlot`・`deleteNode`が例外になり、保存の画面は「保存に
/// 失敗しました」と出し、書けた保存は一覧に入らなかった。消せずに残った
/// 控え・サムネイルは、次に一覧を読んだときに何も戻さないこと。
///
/// テストはrootで動き、chmodでは消せなくならないので、[_BlockedPaths]
/// （IOOverrides）で決まったファイルだけを消せない・読めないように見せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;
  late _BlockedPaths paths;
  late ProjectService projects;
  final services = <SaveTreeService>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    AppErrorReporter.recentErrors.clear();
    dir = Directory.systemTemp.createTempSync('niarim_save_leftovers_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    paths = _BlockedPaths();
    IOOverrides.global = paths;
  });

  tearDown(() {
    IOOverrides.global = null;
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    projects.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String saveTree(String projectId) =>
      '${dir.path}/niarim/projects/$projectId/SaveTree';

  /// 保存の一覧を（読めるなら）読んだ、新しい起動のサービス。
  Future<SaveTreeService> start(WidgetTester tester) async {
    final service = SaveTreeService();
    services.add(service);
    await tester.runAsync(service.init);
    return service;
  }

  Future<Project> createProject(WidgetTester tester) async {
    projects = ProjectService();
    return (await tester.runAsync(() async {
      await projects.init();
      return projects.createProject(
        name: '後片付け',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
    }))!;
  }

  /// 保存の画面と同じく、押したときに見せていたスロットの中身で保存する。
  Future<SaveNode> save(
    WidgetTester tester,
    SaveTreeService service,
    Project project,
    int slot,
    String comment, {
    bool thumbnail = false,
  }) async {
    final replacing = [
      for (final n in service.getNodes(project.id))
        if (n.slotIndex == slot) n.id,
    ].firstOrNull;
    final intent = service.beginSlotSave(
      project.id,
      slot,
      replacing: replacing,
    );
    try {
      return (await tester.runAsync(
        () => service.saveToSlot(
          projectId: project.id,
          slotIndex: slot,
          project: project,
          scenes: projects.scenesOf(project.id),
          tileManager: projects.tileManagerOf(project.id),
          comment: comment,
          thumbnailPngBytes: thumbnail
              ? Uint8List.fromList(const [137, 80, 78, 71])
              : null,
          intent: intent,
        ),
      ))!;
    } finally {
      intent.end();
    }
  }

  Map<int, String?> slots(SaveTreeService service, String projectId) => {
    for (final n in service.getNodes(projectId)) n.slotIndex: n.comment,
  };

  /// 前の起動で保存Aを書き、この起動では一覧を読めないまま保存Bを書いた
  /// （Bの控えがある）。
  Future<({Project project, SaveTreeService service, SaveNode b})> pendingSave(
    WidgetTester tester,
  ) async {
    final project = await createProject(tester);
    final first = await start(tester);
    await save(tester, first, project, 0, 'A');
    final index = '${saveTree(project.id)}/${SaveTreeService.indexFileName}';
    paths.unreadable.add(index);
    final service = await start(tester);
    expect(service.saveListUnreadable(project.id), isTrue);
    final b = await save(tester, service, project, 1, 'B');
    final note = File(
      '${saveTree(project.id)}/${b.id}${SaveTreeService.pendingSuffix}',
    );
    expect(note.existsSync(), isTrue);
    return (project: project, service: service, b: b);
  }

  bool recorded(String path) =>
      AppErrorReporter.recentErrors.any((entry) => entry.contains(path));

  testWidgets('overwriting a save whose note cannot be deleted still saves '
      'and lists the new save, and the leftover note brings nothing back', (
    tester,
  ) async {
    final s = await pendingSave(tester);
    final note =
        '${saveTree(s.project.id)}/${s.b.id}${SaveTreeService.pendingSuffix}';
    paths.undeletable.add(note);

    final c = await save(tester, s.service, s.project, 1, 'C');

    expect(slots(s.service, s.project.id), {1: 'C'});
    expect(File('${saveTree(s.project.id)}/${c.id}.niapro').existsSync(), true);
    expect(
      File('${saveTree(s.project.id)}/${s.b.id}.niapro').existsSync(),
      false,
    );
    expect(File(note).existsSync(), isTrue);
    expect(recorded(note), isTrue);

    // 次の起動（一覧を読める）：Aと、控えから戻るC。消した保存Bは戻らない。
    paths.clear();
    final next = await start(tester);
    expect(slots(next, s.project.id), {0: 'A', 1: 'C'});
  });

  testWidgets('deleting a save whose note cannot be deleted finishes, and the '
      'leftover note brings nothing back', (tester) async {
    final s = await pendingSave(tester);
    final note =
        '${saveTree(s.project.id)}/${s.b.id}${SaveTreeService.pendingSuffix}';
    paths.undeletable.add(note);

    await tester.runAsync(() => s.service.deleteNode(s.project.id, s.b.id));

    expect(s.service.getNodes(s.project.id), isEmpty);
    expect(
      File('${saveTree(s.project.id)}/${s.b.id}.niapro').existsSync(),
      false,
    );
    expect(File(note).existsSync(), isTrue);
    expect(recorded(note), isTrue);

    paths.clear();
    final next = await start(tester);
    expect(slots(next, s.project.id), {0: 'A'});
    expect(next.getArchivedNodes(s.project.id), isEmpty);
  });

  testWidgets('overwriting a save whose thumbnail cannot be deleted still '
      'saves and lists the new save', (tester) async {
    final project = await createProject(tester);
    final service = await start(tester);
    final a = await save(tester, service, project, 0, 'A', thumbnail: true);
    final thumb = '${saveTree(project.id)}/${a.id}_thumb.png';
    expect(File(thumb).existsSync(), isTrue);
    paths.undeletable.add(thumb);

    final d = await save(tester, service, project, 0, 'D', thumbnail: true);

    expect(slots(service, project.id), {0: 'D'});
    expect(service.getNodes(project.id).single.id, d.id);
    expect(File('${saveTree(project.id)}/${a.id}.niapro').existsSync(), false);
    expect(recorded(thumb), isTrue);

    paths.clear();
    final next = await start(tester);
    expect(slots(next, project.id), {0: 'D'});
    expect(next.getArchivedNodes(project.id), isEmpty);
  });

  testWidgets('deleting a save whose thumbnail cannot be deleted finishes and '
      'writes the list', (tester) async {
    final project = await createProject(tester);
    final service = await start(tester);
    final a = await save(tester, service, project, 0, 'A', thumbnail: true);
    await save(tester, service, project, 1, 'B');
    final thumb = '${saveTree(project.id)}/${a.id}_thumb.png';
    paths.undeletable.add(thumb);

    await tester.runAsync(() => service.deleteNode(project.id, a.id));

    expect(slots(service, project.id), {1: 'B'});
    expect(File('${saveTree(project.id)}/${a.id}.niapro').existsSync(), false);
    expect(recorded(thumb), isTrue);
    final index = jsonDecode(
      File(
        '${saveTree(project.id)}/${SaveTreeService.indexFileName}',
      ).readAsStringSync(),
    );
    expect([for (final n in index['nodes'] as List) n['comment']], ['B']);

    paths.clear();
    final next = await start(tester);
    expect(slots(next, project.id), {1: 'B'});
  });

  testWidgets('overwriting a save whose file cannot be deleted still saves '
      'the new save and keeps the old one in a free slot', (tester) async {
    final project = await createProject(tester);
    final service = await start(tester);
    final a = await save(tester, service, project, 0, 'A');
    final archive = '${saveTree(project.id)}/${a.id}.niapro';
    paths.undeletable.add(archive);

    final e = await save(tester, service, project, 0, 'E');

    // 新しい保存はスロット1へ。消せなかった保存は（ファイルが残っているので）
    // 空いているスロットに残す。
    expect(
      service.getNodes(project.id).firstWhere((n) => n.slotIndex == 0).id,
      e.id,
    );
    expect(slots(service, project.id), {0: 'E', 1: 'A'});
    expect(File(archive).existsSync(), isTrue);
    expect(recorded(archive), isTrue);

    paths.clear();
    final next = await start(tester);
    expect(slots(next, project.id), {0: 'E', 1: 'A'});
  });
}

/// 決まったファイルだけを消せない・読めないように見せる（端末では、権限の
/// 無いフォルダ・入出力の失敗で起きる）。
final class _BlockedPaths extends IOOverrides {
  /// 消すと権限の失敗になるファイル。
  final Set<String> undeletable = {};

  /// 開くと権限の失敗になるファイル。
  final Set<String> unreadable = {};

  void clear() {
    undeletable.clear();
    unreadable.clear();
  }

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return undeletable.contains(path) || unreadable.contains(path)
        ? _BlockedFile(real, this)
        : real;
  }
}

PathAccessException _denied(String path, String message) =>
    PathAccessException(path, const OSError('Permission denied', 13), message);

class _BlockedFile implements File {
  _BlockedFile(this._real, this._paths);

  final File _real;
  final _BlockedPaths _paths;

  bool get _undeletable => _paths.undeletable.contains(_real.path);
  bool get _unreadable => _paths.unreadable.contains(_real.path);

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<bool> exists() => _real.exists();
  @override
  int lengthSync() => _real.lengthSync();
  @override
  Future<int> length() => _real.length();
  @override
  DateTime lastModifiedSync() => _real.lastModifiedSync();
  @override
  FileStat statSync() => _real.statSync();
  @override
  Future<FileStat> stat() => _real.stat();

  @override
  Uint8List readAsBytesSync() {
    if (_unreadable) throw _denied(path, 'Cannot open file');
    return _real.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() async => readAsBytesSync();

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    if (_unreadable) throw _denied(path, 'Cannot open file');
    return _real.readAsStringSync(encoding: encoding);
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      readAsStringSync(encoding: encoding);

  @override
  void deleteSync({bool recursive = false}) {
    if (_undeletable) throw _denied(path, 'Cannot delete file');
    _real.deleteSync(recursive: recursive);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (_undeletable) throw _denied(path, 'Cannot delete file');
    return _real.delete(recursive: recursive);
  }

  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a blocked file');
}
