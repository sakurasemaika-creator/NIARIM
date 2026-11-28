// 起動の一覧づくりは作品ファイルの目次（中央ディレクトリ）と作品・シーンだけを
// 読み、絵（タイル）の確かめ（どの項目も申告どおりの大きさに展開できるか）は
// 一覧を出した後に裏のisolateで1作品ずつ行う。作品を開く・ファイルを使う前にも
// 確かめる。絵だけが壊れていた作品は、起動時に全部を確かめていた頃と同じく
// 最新の自動保存から戻し、開いたときにダイアログで知らせる。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

Uint8List _tile(int seed) {
  final pixels = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    final p = i ~/ 4;
    pixels[i] = (p * seed) & 0xff;
    pixels[i + 1] = (p ~/ 7 + seed * 40) & 0xff;
    pixels[i + 2] = (seed * 90) & 0xff;
    pixels[i + 3] = 255;
  }
  return pixels;
}

/// The central directory records of [zip]: each entry's name, the offset of
/// its record and of its local header.
List<({String name, int record, int local})> _records(Uint8List zip) {
  final view = ByteData.sublistView(zip);
  final directory = ZipDirectory.read(InputStream(zip));
  final out = <({String name, int record, int local})>[];
  var at = directory.centralDirectoryOffset;
  for (var i = 0; i < directory.totalCentralDirectoryEntries; i++) {
    final nameLength = view.getUint16(at + 28, Endian.little);
    final extra = view.getUint16(at + 30, Endian.little);
    final comment = view.getUint16(at + 32, Endian.little);
    out.add((
      name: utf8.decode(zip.sublist(at + 46, at + 46 + nameLength)),
      record: at,
      local: view.getUint32(at + 42, Endian.little),
    ));
    at += 46 + nameLength + extra + comment;
  }
  return out;
}

/// [zip] with the stored data of its first tile entry replaced by zeros (the
/// directory, the names and the sizes stay as they were).
Uint8List _withZeroedTile(Uint8List zip) {
  final out = Uint8List.fromList(zip);
  final view = ByteData.sublistView(out);
  final entry = _records(out).firstWhere((r) => r.name.startsWith('Tiles/'));
  final compressed = view.getUint32(entry.record + 20, Endian.little);
  final start =
      entry.local +
      30 +
      view.getUint16(entry.local + 26, Endian.little) +
      view.getUint16(entry.local + 28, Endian.little);
  out.fillRange(start, start + compressed, 0);
  return out;
}

/// [zip] whose first entry named [prefix]… declares [size] bytes in the
/// central directory (it expands to more: a ZIP bomb's forged size).
Uint8List _declaring(Uint8List zip, String prefix, int size) {
  final out = Uint8List.fromList(zip);
  final entry = _records(out).firstWhere((r) => r.name.startsWith(prefix));
  ByteData.sublistView(out).setUint32(entry.record + 24, size, Endian.little);
  return out;
}

/// Counts what an inflater writes, and stops it past [stopAfter] bytes.
class _CountingOutput extends OutputStream {
  _CountingOutput(this.stopAfter);

  final int stopAfter;
  int written = 0;

  void _count(int bytes) {
    written += bytes;
    if (written > stopAfter) throw StateError('past $stopAfter bytes');
  }

  @override
  void writeByte(int value) {
    super.writeByte(value);
    _count(1);
  }

  @override
  void writeBytes(List<int> bytes, [int? len]) {
    super.writeBytes(bytes, len);
    _count(len ?? bytes.length);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-deferred-tiles-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String workPath(String id) => '${temp.path}/niarim/projects/$id/$id.niapro';

  /// A work whose newest automatic save holds tiles 1 and 2 and whose work
  /// file (saved after it) holds tiles 3 and 4.
  Future<({String id, String key, DateTime savedAt})> savedWork({
    bool autosave = true,
  }) async {
    final autosaves = AutosaveService();
    await autosaves.init();
    final projects = ProjectService(autosaves);
    await projects.init();
    final project = await projects.createProject(
      name: '作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 640,
      exportHeight: 360,
    );
    final scene = projects.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    final key = frameLayerKey(scene.id, 0, layer.id);
    final tiles = projects.tileManagerOf(project.id);
    tiles.importAll({
      key: {'0,0': _tile(1), '1,0': _tile(2)},
    });
    if (autosave) await autosaves.save(project.id, projects);
    tiles.importAll({
      key: {'0,0': _tile(3), '1,0': _tile(4)},
    });
    await projects.saveProject(project.id);
    projects.dispose();
    autosaves.dispose();
    return (
      id: project.id,
      key: key,
      // As a later launch reads it back (to the millisecond).
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        autosave ? autosaves.slots.last.savedAt.millisecondsSinceEpoch : 0,
      ),
    );
  }

  /// The app started again: a new launch reading the same storage.
  Future<ProjectService> started() async {
    final autosaves = AutosaveService();
    await autosaves.init();
    final projects = ProjectService(autosaves);
    await projects.init();
    addTearDown(() async {
      await projects.backgroundChecksSettled;
      projects.dispose();
      autosaves.dispose();
    });
    return projects;
  }

  void damageTiles(String id) {
    final file = File(workPath(id));
    file.writeAsBytesSync(_withZeroedTile(file.readAsBytesSync()));
  }

  test('a work is listed from its project and scenes as a full read lists '
      'it, without expanding its tiles', () async {
    final work = await savedWork();
    final path = workPath(work.id);
    final full = await NiaproSerializer.load(
      path,
      withTiles: false,
      limits: ArchiveLimits.ownWork,
    );
    final listed = NiaproSerializer.listWorkFile(path);
    expect(
      NiaproSerializer.contentSignature(listed.project, listed.scenes),
      NiaproSerializer.contentSignature(full.project, full.scenes),
    );
    expect(listed.project.name, full.project.name);
    expect(listed.project.updatedAt, full.project.updatedAt);
    expect(listed.tileData, isEmpty);
    expect(listed.tilesLeftIn, path);
    expect(full.tilesUnchecked, isNull);
    expect(listed.tilesUnchecked!.path, path);
    expect(
      NiaproSerializer.checkListedTiles(listed.tilesUnchecked!),
      ListedTilesCheck.whole,
    );

    // A tile entry whose data is damaged: the listing does not read it, the
    // check (and the full read) does.
    damageTiles(work.id);
    await expectLater(
      NiaproSerializer.load(
        path,
        withTiles: false,
        limits: ArchiveLimits.ownWork,
      ),
      throwsFormatException,
    );
    final damaged = NiaproSerializer.listWorkFile(path);
    expect(damaged.project.id, work.id);
    expect(
      NiaproSerializer.checkListedTiles(damaged.tilesUnchecked!),
      ListedTilesCheck.damaged,
    );
  });

  test(
    'the listing refuses only what a full read refuses, and whatever a '
    'full read refuses that the listing read is found by the check',
    () async {
      final work = await savedWork();
      final path = workPath(work.id);
      final original = File(path).readAsBytesSync();
      final probe = File('${temp.path}/probe.niapro');
      final random = math.Random(20261128);
      var refusedByBoth = 0, foundByCheck = 0, readByBoth = 0;
      for (var round = 0; round < 400; round++) {
        final bytes = Uint8List.fromList(original);
        final Uint8List mutated;
        switch (round % 5) {
          case 0:
            mutated = bytes.sublist(0, random.nextInt(bytes.length));
          case 1:
            mutated = Uint8List.fromList([
              ...bytes,
              for (var i = random.nextInt(64); i > 0; i--) random.nextInt(256),
            ]);
          default:
            for (var flips = 1 + random.nextInt(3); flips > 0; flips--) {
              bytes[random.nextInt(bytes.length)] = random.nextInt(256);
            }
            mutated = bytes;
        }
        probe.writeAsBytesSync(mutated);
        NiaproData? full;
        try {
          full = NiaproSerializer.loadFromBytes(
            mutated,
            withTiles: false,
            limits: ArchiveLimits.ownWork,
          );
        } catch (_) {}
        NiaproData? listed;
        try {
          listed = NiaproSerializer.listWorkFile(probe.path);
        } catch (_) {}
        if (listed == null) {
          expect(full, isNull, reason: 'round $round: refused only by listing');
          refusedByBoth++;
          continue;
        }
        final check = listed.tilesUnchecked == null
            ? (full == null ? ListedTilesCheck.damaged : ListedTilesCheck.whole)
            : NiaproSerializer.checkListedTiles(listed.tilesUnchecked!);
        if (full == null) {
          expect(check, ListedTilesCheck.damaged, reason: 'round $round');
          foundByCheck++;
        } else {
          expect(check, ListedTilesCheck.whole, reason: 'round $round');
          expect(
            NiaproSerializer.contentSignature(listed.project, listed.scenes),
            NiaproSerializer.contentSignature(full.project, full.scenes),
            reason: 'round $round',
          );
          expect(listed.project.name, full.project.name);
          readByBoth++;
        }
      }
      expect(refusedByBoth, greaterThan(0));
      expect(foundByCheck, greaterThan(0));
      expect(readByBoth, greaterThan(0));
    },
  );

  test('a damaged tile stream that the Dart inflater would decode without end '
      'is refused in a moment', () async {
    final work = await savedWork();
    final path = workPath(work.id);
    final bytes = File(path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);
    final second = _records(
      bytes,
    ).where((r) => r.name.startsWith('Tiles/')).elementAt(1);
    final start =
        second.local +
        30 +
        view.getUint16(second.local + 26, Endian.little) +
        view.getUint16(second.local + 28, Endian.little);
    // Found by the fuzzing above: this one byte makes the stream decode one
    // byte at a time for ever.
    bytes[start + 18] = 17;
    final sink = _CountingOutput(1 << 20);
    try {
      Inflate.stream(
        InputStream(
          bytes.sublist(
            start,
            start + view.getUint32(second.record + 20, Endian.little),
          ),
        ),
        sink,
      );
    } on StateError {
      // Went on past a megabyte (the tile expands to 256 KiB).
    }
    expect(sink.written, greaterThan(TileManager.tileSize * 1024));
    File(path).writeAsBytesSync(bytes);
    expect(
      () => NiaproSerializer.loadFromBytes(
        bytes,
        withTiles: false,
        limits: ArchiveLimits.ownWork,
      ),
      throwsFormatException,
    );
    final listed = NiaproSerializer.listWorkFile(path);
    expect(
      NiaproSerializer.checkListedTiles(listed.tilesUnchecked!),
      ListedTilesCheck.damaged,
    );
  });

  test('an end record followed by a long comment is found where a full read '
      'finds it', () async {
    final work = await savedWork();
    final path = workPath(work.id);
    final original = File(path).readAsBytesSync();
    final end = ZipDirectory.read(InputStream(original)).filePosition;
    for (final comment in [0, 100, 4090, 5000, 0xffff]) {
      final bytes = Uint8List.fromList([
        ...original,
        for (var i = 0; i < comment; i++) i % 7 == 0 ? 0x50 : 0x4b,
      ]);
      ByteData.sublistView(bytes).setUint16(end + 20, comment, Endian.little);
      File(path).writeAsBytesSync(bytes);
      final listed = NiaproSerializer.listWorkFile(path);
      final full = NiaproSerializer.loadFromBytes(
        bytes,
        withTiles: false,
        limits: ArchiveLimits.ownWork,
      );
      expect(listed.tilesUnchecked, isNotNull, reason: 'comment $comment');
      expect(
        NiaproSerializer.contentSignature(listed.project, listed.scenes),
        NiaproSerializer.contentSignature(full.project, full.scenes),
      );
      expect(
        NiaproSerializer.checkListedTiles(listed.tilesUnchecked!),
        ListedTilesCheck.whole,
      );
    }
  });

  test('a work damaged only in its tiles is restored from its newest '
      'automatic save by the background check, as at start-up', () async {
    final work = await savedWork();
    damageTiles(work.id);
    final projects = await started();
    expect(projects.projects.map((p) => p.id), contains(work.id));
    expect(projects.tilesUnchecked(work.id), isTrue);

    projects.checkListedTilesInBackground();
    await projects.backgroundChecksSettled;
    expect(projects.tilesUnchecked(work.id), isFalse);
    expect(projects.tilesUnreadable(work.id), isFalse);
    final tiles = projects.tileManagerOf(work.id);
    expect(tiles.getTile(work.key, 0, 0), _tile(1));
    expect(tiles.getTile(work.key, 1, 0), _tile(2));
    final project = projects.projects.singleWhere((p) => p.id == work.id);
    expect(project.updatedAt, work.savedAt);
    expect(project.sizeBytes, File(workPath(work.id)).lengthSync());
    expect(projects.takeAutosaveRecovery(work.id), work.savedAt);
    expect(projects.takeAutosaveRecovery(work.id), isNull);

    // The file was rebuilt from the automatic save: whole at the next start.
    final next = await started();
    expect(next.tileManagerOf(work.id).getTile(work.key, 0, 0), _tile(1));
    expect(next.tilesUnreadable(work.id), isFalse);
    expect(next.takeAutosaveRecovery(work.id), isNull);
  });

  test('opening a work before the background check reaches it checks it '
      'first, and a rename made meanwhile is kept', () async {
    final work = await savedWork();
    damageTiles(work.id);
    final projects = await started();
    expect(projects.tilesUnchecked(work.id), isTrue);
    await projects.renameProject(work.id, '名前を変えた');
    await projects.saveProject(work.id);
    // The save checked the tiles first and rebuilt the file from the
    // automatic save, with the new name.
    expect(projects.tilesUnchecked(work.id), isFalse);
    expect(projects.tilesRead(work.id), isTrue);
    expect(
      projects.projects.singleWhere((p) => p.id == work.id).name,
      '名前を変えた',
    );
    expect(projects.takeAutosaveRecovery(work.id), work.savedAt);
    await projects.backgroundChecksSettled;

    final next = await started();
    final reopened = next.projects.singleWhere((p) => p.id == work.id);
    expect(reopened.name, '名前を変えた');
    expect(next.tileManagerOf(work.id).getTile(work.key, 0, 0), _tile(1));

    // Opened before any check: the picture is checked as it is read.
    damageTiles(work.id);
    final opened = await started();
    expect(opened.tilesUnchecked(work.id), isTrue);
    final tiles = opened.tileManagerOf(work.id);
    expect(opened.tilesUnchecked(work.id), isFalse);
    expect(opened.tilesUnreadable(work.id), isFalse);
    expect(tiles.getTile(work.key, 0, 0), _tile(1));
    expect(opened.takeAutosaveRecovery(work.id), isNotNull);
  });

  test('restoring a work from the trash before its check restores it from '
      'its automatic save first', () async {
    final work = await savedWork();
    final first = await started();
    await first.deleteProject(work.id);
    await first.backgroundChecksSettled;
    damageTiles(work.id);

    final projects = await started();
    expect(projects.trash.map((p) => p.id), contains(work.id));
    expect(projects.tilesUnchecked(work.id), isTrue);
    await projects.restoreProject(work.id);
    expect(projects.projects.map((p) => p.id), contains(work.id));
    expect(projects.tileManagerOf(work.id).getTile(work.key, 0, 0), _tile(1));
    expect(projects.takeAutosaveRecovery(work.id), work.savedAt);
  });

  test('a work damaged only in its tiles with no readable automatic save '
      'leaves the list as at start-up, and its file is kept', () async {
    final work = await savedWork(autosave: false);
    damageTiles(work.id);
    final damaged = File(workPath(work.id)).readAsBytesSync();
    final projects = await started();
    expect(projects.projects.map((p) => p.id), contains(work.id));
    expect(projects.projectsLoadFailed, isFalse);

    projects.checkListedTilesInBackground();
    await projects.backgroundChecksSettled;
    expect(projects.projects.map((p) => p.id), isNot(contains(work.id)));
    expect(projects.projectsLoadFailed, isTrue);
    expect(File(workPath(work.id)).readAsBytesSync(), damaged);

    // Retry reads it whole, as start-up did: still not listed.
    await projects.retryLoadProjects();
    expect(projects.projects.map((p) => p.id), isNot(contains(work.id)));
    expect(projects.projectsLoadFailed, isTrue);
    expect(File(workPath(work.id)).readAsBytesSync(), damaged);
  });

  test(
    'undamaged works are left as they are by the background check',
    () async {
      final works = [await savedWork(), await savedWork()];
      final files = {for (final w in works) w.id: File(workPath(w.id))};
      final before = {
        for (final e in files.entries)
          e.key: (e.value.readAsBytesSync(), e.value.lastModifiedSync()),
      };
      final projects = await started();
      final listed = [...projects.projects];
      var notified = 0;
      projects.addListener(() => notified++);
      projects.checkListedTilesInBackground();
      await projects.backgroundChecksSettled;
      expect(notified, 0);
      expect(projects.projects, listed);
      for (final w in works) {
        expect(projects.tilesUnchecked(w.id), isFalse);
        expect(projects.tilesRead(w.id), isFalse);
        expect(projects.takeAutosaveRecovery(w.id), isNull);
        expect(files[w.id]!.readAsBytesSync(), before[w.id]!.$1);
        expect(files[w.id]!.lastModifiedSync(), before[w.id]!.$2);
        expect(projects.tileManagerOf(w.id).getTile(w.key, 0, 0), _tile(3));
      }
    },
  );

  test('hostile sizes are still refused', () async {
    final work = await savedWork();
    final path = workPath(work.id);
    final original = File(path).readAsBytesSync();

    // A tile entry declaring less than it expands to: listed, then found by
    // the check (and restored from the automatic save).
    final bomb = _declaring(original, 'Tiles/', 1000);
    File(path).writeAsBytesSync(bomb);
    final listed = NiaproSerializer.listWorkFile(path);
    expect(
      NiaproSerializer.checkListedTiles(listed.tilesUnchecked!),
      ListedTilesCheck.damaged,
    );
    final projects = await started();
    projects.checkListedTilesInBackground();
    await projects.backgroundChecksSettled;
    expect(projects.tileManagerOf(work.id).getTile(work.key, 0, 0), _tile(1));

    // The same file received from outside keeps the full check.
    expect(() => NiaproSerializer.loadFromBytes(bomb), throwsFormatException);
    final share = File('${temp.path}/received.niashare')
      ..writeAsBytesSync(bomb);
    await expectLater(
      NiaproSerializer.loadShare(share.path),
      throwsFormatException,
    );

    // The project itself declaring less than it expands to is refused while
    // listing, as by a full read.
    File(path).writeAsBytesSync(_declaring(original, 'manifest.json', 10));
    expect(() => NiaproSerializer.listWorkFile(path), throwsFormatException);

    // A central directory said to run past the end of the file is not read
    // beyond it: the file is read and checked whole, as before.
    final past = Uint8List.fromList(original);
    final end = ZipDirectory.read(InputStream(past)).filePosition;
    ByteData.sublistView(past).setUint32(end + 12, 0x7fffffff, Endian.little);
    File(path).writeAsBytesSync(past);
    final whole = NiaproSerializer.listWorkFile(path);
    expect(whole.tilesUnchecked, isNull);
    final full = NiaproSerializer.loadFromBytes(
      past,
      withTiles: false,
      limits: ArchiveLimits.ownWork,
    );
    expect(
      NiaproSerializer.contentSignature(whole.project, whole.scenes),
      NiaproSerializer.contentSignature(full.project, full.scenes),
    );
  });

  test('a work file broken after it was listed is kept as it is when it is '
      'opened, as before', () async {
    final work = await savedWork();
    final projects = await started();
    final broken = Uint8List.fromList(List.generate(4096, (i) => i % 251));
    File(workPath(work.id)).writeAsBytesSync(broken);
    expect(projects.tileManagerOf(work.id).exportAll(), isEmpty);
    expect(projects.tilesUnreadable(work.id), isTrue);
    expect(projects.takeAutosaveRecovery(work.id), isNull);
    expect(File(workPath(work.id)).readAsBytesSync(), broken);
  });

  test(
    'stopping for a factory reset waits for a check and starts no more',
    () async {
      final works = [await savedWork(), await savedWork()];
      final projects = await started();
      projects.checkListedTilesInBackground();
      await projects.settleWrites();
      final unchecked = works.where((w) => projects.tilesUnchecked(w.id));
      // A check that had started finished; none starts after.
      expect(unchecked.length, lessThan(works.length));
      projects.checkListedTilesInBackground();
      await projects.backgroundChecksSettled;
      expect(
        works.where((w) => projects.tilesUnchecked(w.id)).length,
        unchecked.length,
      );
    },
  );

  group('the recovery dialog', () {
    Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // The checks were started under the test's clock: their steps run as
    // real time and frames go by in turn.
    Future<void> settleChecks(
      WidgetTester tester,
      ProjectService projects,
    ) async {
      var settled = false;
      unawaited(projects.backgroundChecksSettled.then((_) => settled = true));
      for (var i = 0; !settled && i < 200; i++) {
        await settleIo(tester, 1);
      }
      expect(settled, isTrue);
    }

    for (final checkedFirst in [false, true]) {
      testWidgets('is shown when the work is opened '
          '(checked in the background first: $checkedFirst)', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        appRouter.go('/home');
        final work = (await tester.runAsync(() async {
          final saved = await savedWork();
          damageTiles(saved.id);
          return saved;
        }))!;
        final providers = (await tester.runAsync(buildAppProviders))!;
        await tester.pumpWidget(
          MultiProvider(providers: providers, child: const NiarimApp()),
        );
        await tester.pump();
        final projects = tester
            .element(find.byType(HomeScreen))
            .read<ProjectService>();
        if (checkedFirst) {
          await settleChecks(tester, projects);
          expect(projects.tilesUnchecked(work.id), isFalse);
        } else {
          // The background check has not come back: opening checks first.
          expect(projects.tilesUnchecked(work.id), isTrue);
        }
        appRouter.go('/project/${work.id}');
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('作品ファイルを読み込めませんでした'), findsOneWidget);
        expect(projects.tilesUnchecked(work.id), isFalse);
        expect(
          projects.tileManagerOf(work.id).getTile(work.key, 0, 0),
          _tile(1),
        );
        await tester.tap(
          find.byKey(const ValueKey('autosaveRecoveredContinue')),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('作品ファイルを読み込めませんでした'), findsNothing);
        await settleChecks(tester, projects);
        await settleIo(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
