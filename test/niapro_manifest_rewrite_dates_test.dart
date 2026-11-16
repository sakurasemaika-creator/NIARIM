import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

/// お気に入り・入っているフォルダだけを書き換える保存（マニフェストの項目
/// だけを変える保存）は、保存の中の各項目の日時をそのまま残す。
///
/// zipを読むと、archiveは項目の日時をzipの形（DOSの日付と時刻を詰めた数）の
/// まま`lastModTime`に入れるが、書くときは同じ欄を1970年からの秒として読む。
/// 読んだ項目をそのまま書き直していたので、星を付けるたびに全項目の日時が
/// 何年もずれた別の日時になり（マニフェストだけは今の日時）、同じ作品の
/// 保存なのにファイルが変わった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('niapro-manifest-dates-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  Future<File> archiveOf(String id) async =>
      File('${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro');

  /// 各項目の日時（zipに書かれたDOSの日付と時刻）と中身。
  Future<Map<String, (int, String)>> entries(String id) async {
    final zip = ZipDecoder().decodeBytes(
      await (await archiveOf(id)).readAsBytes(),
    );
    return {
      for (final file in zip.files)
        file.name: (file.lastModTime, base64Encode(file.content as List<int>)),
    };
  }

  Map<String, Object?> manifestOf(Map<String, (int, String)> entries) =>
      jsonDecode(utf8.decode(base64Decode(entries['manifest.json']!.$2)))
          as Map<String, Object?>;

  DateTime dosDate(int packed) => (ArchiveFile(
    'x',
    0,
    const <int>[],
  )..lastModTime = packed).lastModDateTime;

  /// [before]と[after]の項目が、マニフェストの[changed]以外すべて同じ。
  void expectSameExcept(
    Map<String, (int, String)> before,
    Map<String, (int, String)> after,
    Map<String, Object?> changed,
  ) {
    expect(after.keys.toSet(), before.keys.toSet());
    for (final name in before.keys) {
      expect(
        dosDate(after[name]!.$1),
        dosDate(before[name]!.$1),
        reason: 'the date of $name changed',
      );
      if (name != 'manifest.json') {
        expect(after[name]!.$2, before[name]!.$2, reason: name);
      }
    }
    final manifest = manifestOf(before)..addAll(changed);
    expect(manifestOf(after), manifest);
  }

  test('starring a saved project and moving it to a folder keep the date of '
      'every entry and every entry but the manifest field', () async {
    const w = 128;
    const h = 64;
    final project = Project(
      id: 'proj_dates',
      name: 'Dates',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2025, 4, 5, 6, 7, 8),
      updatedAt: DateTime(2025, 4, 5, 6, 7, 8),
      totalWorkSeconds: 0,
      exportWidth: w,
      exportHeight: h,
    );
    const layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
    final tileManager = TileManager(canvasWidth: w, canvasHeight: h);
    addTearDown(tileManager.dispose);
    final pixels = Uint8List(w * h * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels
        ..[i] = (i ~/ 4) % 251
        ..[i + 3] = 255;
    }
    tileManager.replaceLayerPixels(
      frameLayerKey('Scene0001', 0, layer.id),
      pixels,
    );
    final savedAt = DateTime(2026, 3, 14, 15, 9, 26);
    await NiaproSerializer.save(
      project: project,
      scenes: const [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: [
            Frame(index: 0, layers: [layer]),
          ],
        ),
      ],
      tileManager: tileManager,
      updatedAt: savedAt,
    );
    final before = await entries(project.id);
    expect(before.length, greaterThan(2));
    for (final (packed, _) in before.values) {
      expect(dosDate(packed), DateTime.utc(2026, 3, 14, 15, 9, 26));
    }

    await NiaproSerializer.saveFavorite(
      projectId: project.id,
      isFavorite: true,
    );
    final starred = await entries(project.id);
    expectSameExcept(before, starred, {'isFavorite': true});

    await NiaproSerializer.saveFolderMembership(
      projectId: project.id,
      folderId: 'folder_1',
    );
    expectSameExcept(before, await entries(project.id), {
      'isFavorite': true,
      'folderId': 'folder_1',
    });

    // The project still opens with all of its drawing.
    final loaded = await NiaproSerializer.load(
      (await archiveOf(project.id)).path,
    );
    expect(loaded.project.isFavorite, isTrue);
    expect(loaded.project.folderId, 'folder_1');
    expect(loaded.project.updatedAt, savedAt);
  });

  /// 古い版の保存のように、項目ごとに違う日時を持つ保存（[dates]の順）。
  Future<void> writeOldArchive(String id, List<DateTime> dates) async {
    final file = await archiveOf(id);
    file.parent.createSync(recursive: true);
    final encoder = ZipFileEncoder()..create(file.path);
    final manifest = utf8.encode(jsonEncode({'id': id, 'name': 'Old'}));
    final bodies = <String, List<int>>{
      'manifest.json': manifest,
      'Scene/Scene0001/frames.json': utf8.encode('{"frames":[]}'),
      'Tiles/Scene0001/0/Layer0001_0_0.bin': List<int>.generate(
        4096,
        (i) => (i * 7) & 0xff,
      ),
    };
    for (final (i, MapEntry(:key, :value)) in bodies.entries.indexed) {
      encoder.addArchiveFile(
        ArchiveFile(key, value.length, value)
          ..lastModTime = dates[i].millisecondsSinceEpoch ~/ 1000,
      );
    }
    encoder.closeSync();
  }

  test(
    'an older save whose entries have different dates keeps each date',
    () async {
      final dates = [
        DateTime(2024, 1, 31, 23, 59, 58),
        DateTime(2023, 7, 4, 0, 0, 2),
        DateTime(2099, 12, 1, 12, 30, 44),
      ];
      await writeOldArchive('proj_old', dates);
      final before = await entries('proj_old');
      expect(
        [for (final (packed, _) in before.values) dosDate(packed)],
        [
          for (final d in dates)
            DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second),
        ],
      );

      await NiaproSerializer.saveFavorite(
        projectId: 'proj_old',
        isFavorite: true,
      );
      expectSameExcept(before, await entries('proj_old'), {'isFavorite': true});
    },
  );

  test(
    'an entry whose stored date is not a date gets a valid fixed date',
    () async {
      await writeOldArchive('proj_bad', [
        DateTime(2024, 1, 31, 23, 59, 58),
        DateTime(2023, 7, 4, 0, 0, 2),
        DateTime(2022, 2, 2, 2, 2, 2),
      ]);
      // Some zip writers leave the date of an entry as zero (month 0, day 0).
      final file = await archiveOf('proj_bad');
      final bytes = file.readAsBytesSync();
      _clearDosDates(bytes, 'Scene/Scene0001/frames.json');
      file.writeAsBytesSync(bytes);
      final before = await entries('proj_bad');
      expect(before['Scene/Scene0001/frames.json']!.$1, 0);

      await NiaproSerializer.saveFavorite(
        projectId: 'proj_bad',
        isFavorite: true,
      );
      final after = await entries('proj_bad');
      expect(
        dosDate(after['Scene/Scene0001/frames.json']!.$1),
        DateTime.utc(1980),
      );
      for (final name in [
        'manifest.json',
        'Tiles/Scene0001/0/Layer0001_0_0.bin',
      ]) {
        expect(
          dosDate(after[name]!.$1),
          dosDate(before[name]!.$1),
          reason: name,
        );
      }
      for (final name in before.keys) {
        if (name == 'manifest.json') continue;
        expect(after[name]!.$2, before[name]!.$2, reason: name);
      }
    },
  );
}

/// Set the DOS date and time of the entry [name] to zero in the local header
/// and the central directory of a zip.
void _clearDosDates(Uint8List zip, String name) {
  final data = ByteData.sublistView(zip);
  final encodedName = utf8.encode(name);
  bool nameAt(int offset) {
    if (offset + encodedName.length > zip.length) return false;
    for (var i = 0; i < encodedName.length; i++) {
      if (zip[offset + i] != encodedName[i]) return false;
    }
    return true;
  }

  var cleared = 0;
  for (var i = 0; i + 46 < zip.length; i++) {
    final signature = data.getUint32(i, Endian.little);
    if (signature == 0x04034b50 &&
        data.getUint16(i + 26, Endian.little) == encodedName.length &&
        nameAt(i + 30)) {
      data.setUint32(i + 10, 0, Endian.little);
      cleared++;
    } else if (signature == 0x02014b50 &&
        data.getUint16(i + 28, Endian.little) == encodedName.length &&
        nameAt(i + 46)) {
      data.setUint32(i + 12, 0, Endian.little);
      cleared++;
    }
  }
  expect(cleared, 2);
}
