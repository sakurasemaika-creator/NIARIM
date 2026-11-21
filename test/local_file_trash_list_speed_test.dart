import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';

/// 1つずつ順に読んでいた頃の一覧（比べるための基準）。
Future<List<LocalTrashedFile>> _oneByOne(Directory root) async {
  if (!await root.exists()) return const [];
  bool safe(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\\');
  final entries = <LocalTrashedFile>[];
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    try {
      final meta = jsonDecode(
        await File('${entity.path}/meta.json').readAsString(),
      );
      if (meta is! Map<String, dynamic>) continue;
      final kindName = meta['kind'];
      final kind = LocalTrashKind.values
          .where((v) => v.name == kindName)
          .firstOrNull;
      final id = meta['id'];
      final original = meta['originalPath'];
      final deletedAt = DateTime.tryParse(meta['deletedAt'] as String? ?? '');
      if (kind == null ||
          id is! String ||
          original is! String ||
          deletedAt == null ||
          id != entity.uri.pathSegments.where((part) => part.isNotEmpty).last) {
        continue;
      }
      final archive = '${entity.path}/data';
      final isFolder = kind == LocalTrashKind.exportedWorkFolder;
      if (isFolder
          ? !await Directory(archive).exists()
          : !await File(archive).exists()) {
        continue;
      }
      final names = (meta['fileNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (isFolder &&
          (meta['folderName'] is! String || names.any((name) => !safe(name)))) {
        continue;
      }
      entries.add(
        LocalTrashedFile(
          id: id,
          kind: kind,
          originalPath: original,
          archivedPath: archive,
          deletedAt: deletedAt,
          folderName: meta['folderName'] as String?,
          fileNames: names,
        ),
      );
    } catch (_) {}
  }
  entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  return entries;
}

/// ゴミ箱の書き出した作品・作った共有ファイルの控えの一覧
/// （`LocalFileTrashService.list`）を速く読む。
///
/// 以前は控えごとの記録（`meta.json`）を、この画面の働き手（isolate）から
/// 1つずつ順に非同期で読んでいて、4,000件の控えで約35秒（重い時は約150秒）、
/// ゴミ箱のタブが読み込み中のままだった。非同期の読み込みは1件ごとに
/// 開く・長さ・読む・閉じる・写しの有無の確かめのたびに入出力の働き手との
/// 行き来を待ち、並べて読んでもほとんど速くならなかった（20,000件で14秒→
/// 11秒）。記録は別の働き手で同期に読む。
///
/// 出す項目・その順・読めない記録や途中の項目を飛ばす決まりは、1つずつ
/// 読んでいた頃と同じであること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory trashRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-trash-list-speed-');
    trashRoot = Directory('${root.path}/niarim/trash/files')
      ..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() async {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  final base = DateTime.utc(2026, 11, 1);

  /// 移した控えと同じ形の項目を作る。[record]がnullなら記録を書かない。
  void item(
    String id, {
    String kind = 'exportedWork',
    Object? record,
    bool folder = false,
    bool data = true,
    Duration age = Duration.zero,
    List<String> fileNames = const ['a.mp4'],
    bool useDefaultRecord = true,
  }) {
    final directory = Directory('${trashRoot.path}/$id')..createSync();
    if (data) {
      if (folder) {
        Directory('${directory.path}/data').createSync();
        for (final name in fileNames) {
          if (name.contains('/')) continue;
          File('${directory.path}/data/$name').writeAsBytesSync([1, 2]);
        }
      } else {
        File('${directory.path}/data').writeAsBytesSync([1, 2, 3]);
      }
    }
    final json =
        record ??
        (useDefaultRecord
            ? {
                'id': id,
                'kind': kind,
                'originalPath': folder
                    ? '/docs/niarim/exports'
                    : '/docs/niarim/exports/clip_$id.mp4',
                'deletedAt': base.subtract(age).toIso8601String(),
                if (folder) 'folderName': 'Folder $id',
                if (folder) 'fileNames': fileNames,
              }
            : null);
    if (json != null) {
      File(
        '${directory.path}/meta.json',
      ).writeAsStringSync(json is String ? json : jsonEncode(json));
    }
  }

  List<String> describe(List<LocalTrashedFile> items) => [
    for (final e in items)
      '${e.id} ${e.kind.name} ${e.originalPath} ${e.archivedPath} '
          '${e.deletedAt.toIso8601String()} ${e.folderName} '
          '${e.fileNames.join(',')}',
  ];

  test('the list has the same items in the same order as reading the records '
      'one by one, and still skips unreadable and unfinished items', () async {
    // 正しい項目：書き出した作品・共有ファイル・作品のフォルダ。同じ時刻の
    // 項目も入れる（並べ替えの元の順も同じであること）。
    for (var i = 0; i < 40; i++) {
      item(
        '${2000 + i}',
        kind: i.isEven ? 'exportedWork' : 'outgoingShare',
        age: Duration(hours: i % 7),
      );
    }
    for (var i = 0; i < 6; i++) {
      item(
        '${3000 + i}',
        kind: 'exportedWorkFolder',
        folder: true,
        fileNames: ['a$i.mp4', 'b$i.gif'],
        age: Duration(hours: i),
      );
    }
    // 飛ばすもの。
    item('4000', record: '{not json');
    item('4001', record: '[1, 2, 3]');
    item('4002', useDefaultRecord: false); // 記録が無い（写しの途中）
    item('4003', data: false); // 写しが無い
    item(
      '4004',
      record: {
        'id': '9999',
        'kind': 'exportedWork',
        'originalPath': '/x',
        'deletedAt': base.toIso8601String(),
      },
    ); // 記録の番号がフォルダの名前と違う
    item(
      '4005',
      record: {
        'id': '4005',
        'kind': 'unknownKind',
        'originalPath': '/x',
        'deletedAt': base.toIso8601String(),
      },
    );
    item(
      '4006',
      record: {
        'id': '4006',
        'kind': 'exportedWork',
        'originalPath': '/x',
        'deletedAt': 'yesterday',
      },
    );
    item(
      '4007',
      kind: 'exportedWorkFolder',
      folder: true,
      fileNames: ['../escape.mp4'],
    ); // 危ない名前
    item(
      '4008',
      record: {
        'id': '4008',
        'kind': 'exportedWorkFolder',
        'originalPath': '/x',
        'deletedAt': base.toIso8601String(),
        'fileNames': ['a.mp4'],
      },
      folder: true,
    ); // フォルダの名前が無い
    item('4009', kind: 'exportedWorkFolder'); // フォルダなのに写しがファイル
    File('${trashRoot.path}/stray.json').writeAsStringSync('{}');
    File('${trashRoot.path}/4010').writeAsStringSync('not a folder');

    final expected = await _oneByOne(trashRoot);
    expect(expected, hasLength(46));
    for (var run = 0; run < 3; run++) {
      expect(
        describe(await LocalFileTrashService.list()),
        describe(expected),
        reason: 'run $run',
      );
    }
  });

  test('4,000 Trash items are listed several times faster than reading the '
      'records one by one (both measured here)', () async {
    const count = 4000;
    for (var i = 0; i < count; i++) {
      item(
        '${10000 + i}',
        kind: i % 3 == 0 ? 'outgoingShare' : 'exportedWork',
        age: Duration(seconds: i),
      );
    }
    // 1回目はディスクの覚え（ページキャッシュ）を温めるため。
    await _oneByOne(trashRoot);
    final sequential = Stopwatch()..start();
    final expected = await _oneByOne(trashRoot);
    sequential.stop();
    final listing = Stopwatch()..start();
    final items = await LocalFileTrashService.list();
    listing.stop();
    debugPrint(
      '4,000 items: one by one ${sequential.elapsedMilliseconds} ms, '
      'list ${listing.elapsedMilliseconds} ms',
    );
    expect(describe(items), describe(expected));
    // 実際は10倍以上速い（この環境で約2.6秒→約0.2秒）。重い環境でも
    // 揺れないよう、3倍で見る。
    expect(
      listing.elapsedMilliseconds * 3,
      lessThan(sequential.elapsedMilliseconds),
      reason: 'list is not several times faster than one by one',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
