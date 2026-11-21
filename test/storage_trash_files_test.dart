import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/utils/file_size_label.dart';

import 'helpers/storage_screen_harness.dart';

/// ゴミ箱の中のものは、作品も、書き出した作品・作成した共有ファイルの控え
/// （`niarim/trash/files`）も、まとめて容量削減の画面の「ゴミ箱」に数え、
/// 「ゴミ箱を空にする」で全部を完全に削除する。空にすると「ゴミ箱」は0になる。
///
/// 所有者の判断（2026-11-16）：「ゴミ箱内のデータも「ゴミ箱」として一纏めに
/// してストレージや棒グラフに含めてください。ゴミ箱内が空になって完全削除
/// された状態だとストレージからもゴミ箱が0%になります」
///
/// 以前は控えをどの分類にも数えず、「ゴミ箱を空にする」も作品のゴミ箱しか
/// 消さなかった（控えだけのときは押せなかった）。その後、ゴミ箱のフォルダを
/// 丸ごと数えるようにしたときも、ゴミ箱に出ない（空にできない）写しの途中・
/// 記録の読めないフォルダまで数えて空にしても0にならず、1つ消せない控えが
/// あると残りの控えも消さず、控えだけのときに結果が届くと行が下へ動いた。
final class _UndeletableItem extends IOOverrides {
  _UndeletableItem(this.folderPath);

  final String folderPath;

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return path == folderPath ? _UndeletableFolder(real) : real;
  }
}

class _UndeletableFolder implements Directory {
  _UndeletableFolder(this._real);

  final Directory _real;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException(
        'Deletion failed',
        _real.path,
        const OSError('Permission denied', 13),
      );
  @override
  void deleteSync({bool recursive = false}) => throw FileSystemException(
    'Deletion failed',
    _real.path,
    const OSError('Permission denied', 13),
  );

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  Directory get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  Future<bool> exists() => _real.exists();
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<FileStat> stat() => _real.stat();
  @override
  FileStat statSync() => _real.statSync();
  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => _real.list(recursive: recursive, followLinks: followLinks);
  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => _real.listSync(recursive: recursive, followLinks: followLinks);
  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on the probed folder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-trash-files-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => switch (call.method) {
        'getApplicationCacheDirectory' => cache.path,
        'getTemporaryDirectory' => '${root.path}/tmp',
        _ => docs.path,
      },
    );
    StorageInfoService().invalidate();
  });

  tearDown(() {
    IOOverrides.global = null;
    messenger.setMockMethodCallHandler(pathChannel, null);
    StorageInfoService().invalidate();
    root.deleteSync(recursive: true);
  });

  File writeFile(String relative, int bytes) => File('${docs.path}/$relative')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 3));

  /// The bytes of a Trash item: its copy and its record.
  int itemBytes(LocalTrashedFile entry) {
    final folder = File(entry.archivedPath).parent;
    return folder
        .listSync(recursive: true)
        .whereType<File>()
        .fold(0, (sum, f) => sum + f.lengthSync());
  }

  Future<LocalTrashedFile> trashExport(String name, int bytes) =>
      LocalFileTrashService.move(
        writeFile('niarim/exports/$name', bytes),
        LocalTrashKind.exportedWork,
      );

  Future<LocalTrashedFile> trashShare(String name, int bytes) =>
      LocalFileTrashService.move(
        writeFile('niarim/shared/outgoing/1700000000000009/$name', bytes),
        LocalTrashKind.outgoingShare,
      );

  group('breakdown', () {
    test('the trashed exported works and share files are counted in the '
        'Trash, and an emptied Trash is 0', () async {
      writeFile('niarim/exports/kept.gif', 500);
      final clip = await trashExport('clip.mp4', 3000);
      final share = await trashShare('walk.niashare', 1200);
      final folder = await LocalFileTrashService.moveWorkFolder(
        folderName: 'Clips',
        files: [
          writeFile('niarim/exports/a.png', 700),
          writeFile('niarim/exports/b.png', 800),
        ],
      );
      final trashBytes = [
        clip,
        share,
        folder,
      ].fold(0, (sum, e) => sum + itemBytes(e));

      var breakdown = await StorageInfoService().computeBreakdown({});
      expect(
        breakdown.bytesOf(StorageCategory.trash),
        trashBytes,
        reason: 'the files in the Trash are missing from the Trash',
      );
      expect(breakdown.bytesOf(StorageCategory.exports), 500);
      expect(breakdown.incomplete, isEmpty);

      for (final entry in await LocalFileTrashService.list()) {
        await LocalFileTrashService.deleteForever(entry);
      }
      StorageInfoService().invalidate();
      breakdown = await StorageInfoService().computeBreakdown({});
      expect(breakdown.bytesOf(StorageCategory.trash), 0);
      expect(breakdown.nonEmptyCategories, {StorageCategory.exports});
    });

    test(
      'folders the Trash list does not show (a copy still being made, an '
      'unreadable record) are not counted: emptying brings the Trash to 0',
      () async {
        final clip = await trashExport('clip.mp4', 3000);
        final trash = '${docs.path}/niarim/trash/files';
        // A move still copying: no record yet.
        final copying = '$trash/${DateTime.now().microsecondsSinceEpoch + 5}';
        File('$copying/data')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(List.filled(90, 1));
        // A record that cannot be read.
        const unreadable = '1600000000000001';
        File('$trash/$unreadable/data')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(List.filled(70, 1));
        File('$trash/$unreadable/meta.json').writeAsStringSync('{broken');

        final breakdown = await StorageInfoService().computeBreakdown({});
        expect(breakdown.bytesOf(StorageCategory.trash), itemBytes(clip));

        await LocalFileTrashService.deleteForever(clip);
        StorageInfoService().invalidate();
        final emptied = await StorageInfoService().computeBreakdown({});
        expect(emptied.bytesOf(StorageCategory.trash), 0);
      },
    );
  });

  group('storage screen', () {
    Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
    }

    Future<void> waitFor(
      WidgetTester tester,
      bool Function() done, {
      required String reason,
    }) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await settle(tester, rounds: 1);
      }
      expect(done(), isTrue, reason: reason);
    }

    ListTile emptyTrashRow(WidgetTester tester, AppLocalizations l10n) =>
        tester.widget<ListTile>(storageTile(l10n.storageEmptyTrashButton));

    String? subtitleOf(ListTile tile) => (tile.subtitle as Text?)?.data;

    /// The names the confirmation lists, in order.
    List<String> dialogNames(WidgetTester tester) {
      final names = <String>[];
      while (true) {
        final target = find.byKey(
          ValueKey('trash-dialog-target-${names.length}'),
        );
        if (target.evaluate().isEmpty) return names;
        names.add(tester.widget<Text>(target).data!);
      }
    }

    Future<AppLocalizations> openStorage(WidgetTester tester) async {
      final providers = await bootstrapStorageScreen(tester);
      return showStorageScreen(
        tester,
        providers,
        StorageInfoService(),
        size: const Size(390, 1400),
      );
    }

    testWidgets('only exported works and share files in the Trash: the row '
        'shows their size, lists them and empties the Trash to 0', (
      tester,
    ) async {
      final entries = await tester.runAsync(
        () async => [
          await trashExport('clip.mp4', 3000),
          await trashShare('walk.niashare', 1200),
        ],
      );
      final bytes = entries!.fold(0, (sum, e) => sum + itemBytes(e));
      final l10n = await openStorage(tester);
      await waitFor(
        tester,
        () =>
            subtitleOf(emptyTrashRow(tester, l10n)) != l10n.storageCalculating,
        reason: 'the scan never finished',
      );
      expect(
        emptyTrashRow(tester, l10n).enabled,
        isTrue,
        reason: 'the row cannot be pressed with only files in the Trash',
      );
      expect(
        subtitleOf(emptyTrashRow(tester, l10n)),
        fileSizeLabel(l10n, bytes),
      );

      await tester.ensureVisible(storageTile(l10n.storageEmptyTrashButton));
      await tester.tap(storageTile(l10n.storageEmptyTrashButton));
      await waitFor(
        tester,
        () =>
            find.byKey(const Key('trash-dialog-confirm')).evaluate().isNotEmpty,
        reason: 'the confirmation did not open',
      );
      expect(dialogNames(tester).toSet(), {
        'clip.mp4',
        'walk.niashare',
      }, reason: 'the confirmation does not list the files');
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      await waitFor(
        tester,
        () => find.byKey(const Key('trash-dialog-confirm')).evaluate().isEmpty,
        reason: 'the confirmation did not close',
      );
      expect(await tester.runAsync(LocalFileTrashService.list), isEmpty);
      await waitFor(
        tester,
        () => subtitleOf(emptyTrashRow(tester, l10n)) == fileSizeLabel(l10n, 0),
        reason: 'the Trash did not become 0 after emptying',
      );
      expect(emptyTrashRow(tester, l10n).enabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('projects and files in the Trash are all listed and all '
        'removed', (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      final projects = await storageProjectServiceOf(tester, providers);
      await addStorageTestProject(tester, projects, trashed: true);
      await tester.runAsync(() => trashExport('clip.mp4', 3000));
      final l10n = await showStorageScreen(
        tester,
        providers,
        StorageInfoService(),
        size: const Size(390, 1400),
      );
      await waitFor(
        tester,
        () => emptyTrashRow(tester, l10n).enabled,
        reason: 'the row never became pressable',
      );
      await tester.ensureVisible(storageTile(l10n.storageEmptyTrashButton));
      await tester.tap(storageTile(l10n.storageEmptyTrashButton));
      await waitFor(
        tester,
        () =>
            find.byKey(const Key('trash-dialog-confirm')).evaluate().isNotEmpty,
        reason: 'the confirmation did not open',
      );
      expect(dialogNames(tester), ['Storage test', 'clip.mp4']);
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      await waitFor(
        tester,
        () => find.byKey(const Key('trash-dialog-confirm')).evaluate().isEmpty,
        reason: 'the confirmation did not close',
      );
      expect(projects.trash, isEmpty);
      expect(await tester.runAsync(LocalFileTrashService.list), isEmpty);
      await waitFor(
        tester,
        () => subtitleOf(emptyTrashRow(tester, l10n)) == fileSizeLabel(l10n, 0),
        reason: 'the Trash did not become 0 after emptying',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a file that cannot be removed keeps the confirmation open with '
      'the reason and the file, and the rest is removed',
      (tester) async {
        final entries = await tester.runAsync(
          () async => [
            await trashExport('stuck.mp4', 3000),
            await trashExport('gone.mp4', 2000),
          ],
        );
        final stuck = entries!.first;
        final l10n = await openStorage(tester);
        await waitFor(
          tester,
          () => emptyTrashRow(tester, l10n).enabled,
          reason: 'the row never became pressable',
        );
        IOOverrides.global = _UndeletableItem(
          File(stuck.archivedPath).parent.path,
        );
        await tester.ensureVisible(storageTile(l10n.storageEmptyTrashButton));
        await tester.tap(storageTile(l10n.storageEmptyTrashButton));
        await waitFor(
          tester,
          () => find
              .byKey(const Key('trash-dialog-confirm'))
              .evaluate()
              .isNotEmpty,
          reason: 'the confirmation did not open',
        );
        await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
        await waitFor(
          tester,
          () =>
              find.byKey(const Key('trash-dialog-error')).evaluate().isNotEmpty,
          reason: 'the failure was not shown',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('trash-dialog-error'))).data,
          l10n.homeTrashOperationFailed,
        );
        expect(dialogNames(tester), ['stuck.mp4']);
        IOOverrides.global = null;
        expect(
          (await tester.runAsync(LocalFileTrashService.list))!.map((e) => e.id),
          [stuck.id],
        );
        await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
        await waitFor(
          tester,
          () =>
              subtitleOf(emptyTrashRow(tester, l10n)) ==
              fileSizeLabel(l10n, itemBytes(stuck)),
          reason: 'the Trash does not show what is left',
        );
        expect(emptyTrashRow(tester, l10n).enabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('with only files in the Trash, the rows do not move when the '
        'scan arrives', (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      await tester.runAsync(() => trashExport('clip.mp4', 3000));
      final service = ScriptedStorage()
        ..rememberedCategories = const {StorageCategory.cache};
      final l10n = await showStorageScreen(tester, providers, service);
      Map<String, double> rows() => {
        for (final title in [
          l10n.storageClearCacheButton,
          l10n.storageEmptyTrashButton,
          l10n.storageEraseAllButton,
        ])
          title: tester.getTopLeft(storageTile(title)).dy,
      };
      final scanning = rows();
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(
        StorageBreakdown({
          StorageCategory.trash: 4096,
          StorageCategory.cache: 123,
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(
        rows(),
        scanning,
        reason: 'the rows moved when the Trash bar came',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
