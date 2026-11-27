import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' hide ZLibEncoder;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tileBytes = TileManager.tileSize * TileManager.tileSize * 4;

/// A zip of [count] entries that each expand to one tile of zeros (each
/// stored as its own copy of a tiny deflate stream). Built here because the
/// package's Dart encoder takes long for hundreds of megabytes.
Uint8List _zipOfZeroTiles(int count, {String prefix = 'Tiles/t'}) {
  final zeros = Uint8List(_tileBytes);
  final data = Uint8List.fromList(ZLibEncoder(raw: true).convert(zeros));
  final crc = getCrc32(zeros);
  final out = BytesBuilder();
  final central = BytesBuilder();
  void u16(BytesBuilder b, int v) => b.add([v & 0xff, v >> 8 & 0xff]);
  void u32(BytesBuilder b, int v) =>
      b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
  for (var i = 0; i < count; i++) {
    final name = '$prefix$i.bin'.codeUnits;
    final offset = out.length;
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, 0);
    u16(out, 8);
    u16(out, 0);
    u16(out, 0x21);
    u32(out, crc);
    u32(out, data.length);
    u32(out, zeros.length);
    u16(out, name.length);
    u16(out, 0);
    out.add(name);
    out.add(data);
    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0);
    u16(central, 8);
    u16(central, 0);
    u16(central, 0x21);
    u32(central, crc);
    u32(central, data.length);
    u32(central, zeros.length);
    u16(central, name.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, offset);
    central.add(name);
  }
  final centralOffset = out.length;
  final centralBytes = central.takeBytes();
  out.add(centralBytes);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, count);
  u16(out, count);
  u32(out, centralBytes.length);
  u32(out, centralOffset);
  u16(out, 0);
  return out.takeBytes();
}

String _verdict(Uint8List zip, ArchiveLimits limits) {
  try {
    return 'read ${ArchiveSecurity.decodeZip(zip, limits: limits).length}';
  } on FormatException catch (error) {
    return 'refused ${error.message}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ArchiveSecurity.debugReceivedWorkBudget = null);

  // More tiles than the fixed limit for received archives (256 MB) allows.
  const overFixedLimit = 1100;

  test('a received work may expand as far as this device can hold', () {
    final zip = _zipOfZeroTiles(overFixedLimit);
    expect(
      overFixedLimit * _tileBytes,
      greaterThan(ArchiveSecurity.maxExpandedBytes),
    );
    expect(_verdict(zip, ArchiveLimits.ownWork), 'read $overFixedLimit');
    // Other received archives keep the fixed limits.
    expect(_verdict(zip, ArchiveLimits.received), startsWith('refused'));

    // A device that can hold it (a quarter of 2 GB of memory and more).
    ArchiveSecurity.debugReceivedWorkBudget = 512 * 1024 * 1024;
    expect(_verdict(zip, ArchiveLimits.receivedWork), 'read $overFixedLimit');

    // A device that cannot: refused as the fixed limit refused it.
    ArchiveSecurity.debugReceivedWorkBudget = ArchiveSecurity.maxExpandedBytes;
    expect(_verdict(zip, ArchiveLimits.receivedWork), startsWith('refused'));
  });

  test('a ZIP bomb is still refused from outside', () {
    // Far more than the largest budget, from a small file.
    final bomb = _zipOfZeroTiles(18000);
    expect(bomb.length, lessThan(16 * 1024 * 1024));
    ArchiveSecurity.debugReceivedWorkBudget =
        ArchiveSecurity.maxReceivedWorkBudget;
    expect(_verdict(bomb, ArchiveLimits.receivedWork), startsWith('refused'));
    expect(_verdict(bomb, ArchiveLimits.received), startsWith('refused'));
  });

  test('the budget comes from this device and never goes below the fixed '
      'limits', () {
    expect(
      ArchiveSecurity.receivedWorkBudget(),
      inInclusiveRange(
        ArchiveSecurity.maxExpandedBytes,
        ArchiveSecurity.maxReceivedWorkBudget,
      ),
    );
    ArchiveSecurity.debugReceivedWorkBudget = 1;
    final floor = ArchiveLimits.receivedWork;
    const fixed = ArchiveLimits.received;
    expect(floor.compressedBytes, fixed.compressedBytes);
    expect(floor.expandedBytes, fixed.expandedBytes);
    expect(floor.singleEntryBytes, fixed.singleEntryBytes);
    expect(floor.metadataEntryBytes, fixed.metadataEntryBytes);
    expect(floor.entries, fixed.entries);
  });

  test('a damaged own file is still told from a whole one', () {
    final zip = _zipOfZeroTiles(3);
    final directory = ZipDirectory.read(InputStream(zip));
    // Declare the first entry a byte larger than it expands to.
    ByteData.sublistView(zip).setUint32(
      directory.centralDirectoryOffset + 24,
      _tileBytes + 1,
      Endian.little,
    );
    expect(
      _verdict(zip, ArchiveLimits.ownWork),
      'refused ZIPエントリの展開後サイズが申告値と一致しません',
    );
  });

  group('a work over the fixed limit', () {
    late Directory root;
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      root = Directory.systemTemp.createTempSync('niarim-large-work-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      SharedPreferences.setMockInitialValues({'language': 'ja'});
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      root.deleteSync(recursive: true);
    });

    test('keeps its autosave, manual save, comparison with the autosave and '
        'its trip through the trash', () async {
      final service = ProjectService();
      await service.init();
      final project = await service.createProject(
        name: '大きな作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 640,
        exportHeight: 360,
      );
      final scene = service.scenesOf(project.id).first;
      final layer = scene.frames.first.layers.firstWhere(
        (l) => l.type == LayerType.normal,
      );
      final painted = Uint8List(_tileBytes)..fillRange(0, _tileBytes, 200);
      final key = frameLayerKey(scene.id, 0, layer.id);
      service.tileManagerOf(project.id).importAll({
        key: {'0,0': painted},
      });
      await service.saveProject(project.id);
      service.dispose();

      // Grow the file past the fixed limit (entries the reader skips, so the
      // test keeps little in memory; the checks see every entry alike), and
      // keep the same file as the autosave and a manual save.
      final dir = '${root.path}/niarim/projects/${project.id}';
      final file = File('$dir/${project.id}.niapro');
      final grown = Archive();
      for (final entry
          in ZipDecoder().decodeBytes(file.readAsBytesSync()).files) {
        grown.addFile(entry);
      }
      final padding = Uint8List(_tileBytes);
      for (var i = 0; i < overFixedLimit; i++) {
        grown.addFile(
          ArchiveFile(
            'Tiles/${scene.id}/pad/pad_$i.bin',
            padding.length,
            padding,
          ),
        );
      }
      final bytes = ZipEncoder().encode(grown)!;
      file.writeAsBytesSync(bytes);
      Directory('$dir/autosave').createSync(recursive: true);
      file.copySync('$dir/autosave/slot_0.niapro');
      Directory('$dir/SaveTree').createSync(recursive: true);
      file.copySync('$dir/SaveTree/node_big.niapro');

      final autosaved = await NiaproSerializer.loadAutosave(project.id, 0);
      expect(autosaved.tileData[key]?['0,0'], painted);
      final manual = await NiaproSerializer.loadSaveTreeNode(
        project.id,
        'node_big',
      );
      expect(manual.tileData[key]?['0,0'], painted);
      // The autosave compares the work with its file; a large work file was
      // read with the received limits, never matched, and every idle moment
      // wrote another autosave of the same work, pushing older ones out.
      expect(
        await NiaproSerializer.workFileContentSignature(project.id),
        NiaproSerializer.contentSignature(autosaved.project, autosaved.scenes),
      );

      // A transfer (.niatra) that carries the work, read on a device that
      // can hold it and on one that cannot.
      final transfer = Archive()
        ..addFile(
          ArchiveFile(
            'data.json',
            0,
            utf8.encode(
              jsonEncode({
                'projectFiles': ['big.niashare'],
              }),
            ),
          ),
        )
        ..addFile(
          ArchiveFile.noCompress('Projects/big.niashare', bytes.length, bytes),
        );
      final transferBytes = ZipEncoder().encode(transfer)!;
      ArchiveSecurity.debugReceivedWorkBudget = 512 * 1024 * 1024;
      NiatraSerializer.validateProjects(
        NiatraSerializer.loadFromBytes(transferBytes),
      );
      ArchiveSecurity.debugReceivedWorkBudget =
          ArchiveSecurity.maxExpandedBytes;
      expect(
        () => NiatraSerializer.validateProjects(
          NiatraSerializer.loadFromBytes(transferBytes),
        ),
        throwsFormatException,
      );
      ArchiveSecurity.debugReceivedWorkBudget = null;

      final next = ProjectService();
      addTearDown(next.dispose);
      await next.init();
      expect(next.projects.map((p) => p.id), [project.id]);
      await next.deleteProject(project.id);
      expect(next.trash.map((p) => p.id), [project.id]);
      await next.restoreProject(project.id);
      expect(next.projects.map((p) => p.id), [project.id]);
      expect(next.tileManagerOf(project.id).exportAll()[key]?['0,0'], painted);
    });
  });
}
