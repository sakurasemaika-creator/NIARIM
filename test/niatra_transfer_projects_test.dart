import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で選んで移した作品は、同じファイルを読み直しても、
/// もう1台を行き来して戻ってきても、同じ中身の作品を二重にしない。もう1台で
/// 描き足した作品は、この端末の作品を残して「名前 (コピー)」として足し、
/// 読み込みの知らせに出す。

/// 不透明な単色のタイル（乗算済み）。
Uint8List _tile(int value) {
  final bytes = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = value;
    bytes[i + 1] = value;
    bytes[i + 2] = value;
    bytes[i + 3] = 255;
  }
  return bytes;
}

/// 作品の最初のフレームの最初のレイヤーに、[value]の色のタイルを置く。
void _paint(ProjectService service, String projectId, int value) {
  final scene = service.scenesOf(projectId).first;
  final layer = scene.frames.first.layers.first;
  service.tileManagerOf(projectId).importAll({
    frameLayerKey(scene.id, scene.frames.first.index, layer.id): {
      '0,0': _tile(value),
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory storage;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_projects_');
    storage = temp;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => storage.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await settleTransfer();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// [who]の端末を起動する（作品の保存先と設定を入れ替える）。
  Future<ProjectService> device(String who, Map<String, Object> saved) async {
    storage = Directory('${temp.path}/$who')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues(saved);
    final service = ProjectService();
    await service.init();
    return service;
  }

  /// 引き継ぎ画面と同じく、選んだ作品を.niashareにして.niatraへ入れる。
  Future<NiatraData> exportProjects(
    ProjectService service,
    List<String> ids,
  ) async {
    final transfer = await TransferDevice.start();
    final out = Directory('${temp.path}/share')..createSync(recursive: true);
    final files = <String, Uint8List>{};
    for (final id in ids) {
      final file = await NiaproSerializer.saveShare(
        project: service.projects.firstWhere((p) => p.id == id),
        scenes: service.scenesOf(id),
        tileManager: service.tileManagerOf(id),
        outputDir: out.path,
      );
      files['$id.niashare'] = await file.readAsBytes();
      await file.delete();
    }
    final bytes = await NiatraSerializer.export(
      selectedItems: const {},
      settings: transfer.settings,
      brush: transfer.brush,
      tone: transfer.tone,
      stamp: transfer.stamp,
      autofillPresets: transfer.autofill,
      theme: transfer.theme,
      palette: transfer.palette,
      pixelArtPalette: transfer.pixelArt,
      projectFiles: files,
    );
    return NiatraSerializer.loadFromBytes(bytes);
  }

  List<String> names(ProjectService service) =>
      [for (final p in service.projects) p.name]..sort();

  test('a project read twice from the same file, or brought back from the '
      'other device unchanged, is not added again; one drawn on over there '
      'is added as a copy and reported', () async {
    const saved = <String, Object>{'language': 'ja'};
    // この端末（B）の作品を、もう1台（A）へ移す。
    final b = await device('B', saved);
    final work = await b.createProject(
      name: 'B work',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(b, work.id, 40);
    await b.saveProject(work.id);
    final fromB = await exportProjects(b, [work.id]);
    await settleTransfer();

    final a = await device('A', saved);
    await NiatraSerializer.restoreProjects(fromB, a);
    expect(names(a), ['B work']);
    await NiatraSerializer.restoreProjects(fromB, a);
    expect(names(a), ['B work'], reason: '同じファイルを読み直しても増えない');
    final movedId = a.projects.single.id;
    final unchanged = await exportProjects(a, [movedId]);
    _paint(a, movedId, 200);
    final drawnOn = await exportProjects(a, [movedId]);
    await settleTransfer();

    final back = await device('B', saved);
    expect(names(back), ['B work']);
    final report = TransferImportReport();
    await NiatraSerializer.restoreProjects(unchanged, back, report: report);
    expect(names(back), ['B work'], reason: '行き来して戻った同じ作品は足さない');
    expect(report.addedCopies, isEmpty);

    await NiatraSerializer.restoreProjects(drawnOn, back, report: report);
    expect(names(back), [
      'B work',
      'B work (コピー)',
    ], reason: 'もう1台で描き足した作品は、この端末の作品を残して複製として足す');
    expect(report.addedCopies, ['B work (コピー)']);
    await NiatraSerializer.restoreProjects(drawnOn, back);
    expect(names(back), ['B work', 'B work (コピー)'], reason: '読み直しても増えない');
    final original = back.projects.firstWhere((p) => p.name == 'B work');
    expect(
      back
          .tileManagerOf(original.id)
          .exportAll()
          .values
          .single
          .values
          .single[0],
      40,
      reason: 'この端末の作品の絵はそのまま',
    );
  });

  test('a project with the same picture but a name of its own is still '
      'added (it is not the same project)', () async {
    const saved = <String, Object>{'language': 'ja'};
    final c = await device('C', saved);
    final picture = await c.createProject(
      name: 'Picture',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(c, picture.id, 40);
    final file = await exportProjects(c, [picture.id]);
    await settleTransfer();

    final d = await device('D', saved);
    final other = await d.createProject(
      name: 'Other',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(d, other.id, 40);
    await NiatraSerializer.restoreProjects(file, d);
    expect(names(d), ['Other', 'Picture']);
  });

  test('the content comparison covers the project settings, the scenes and '
      'the picture, and not the name, id, dates, organisation or empty '
      'layers', () async {
    final service = await device('E', const {'language': 'ja'});
    final made = await service.createProject(
      name: 'Base',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(service, made.id, 40);
    final base = NiaproData(
      project: service.projects.single,
      scenes: service.scenesOf(made.id),
      tileData: service.tileManagerOf(made.id).exportAll(),
    );
    NiaproData change({
      Project Function(Project p)? project,
      List<Scene>? scenes,
      Map<String, Map<String, Uint8List>>? tiles,
    }) => NiaproData(
      project: project?.call(base.project) ?? base.project,
      scenes: scenes ?? base.scenes,
      tileData: tiles ?? base.tileData,
    );
    expect(
      NiaproSerializer.sameContent(
        base,
        change(
          project: (p) => p.copyWith(
            id: 'other',
            name: 'Renamed',
            createdAt: DateTime(2001),
            updatedAt: DateTime(2002),
            isFavorite: true,
            tags: const ['t'],
            totalWorkSeconds: 99,
          ),
          tiles: {...base.tileData, 'empty#0#layer': {}},
        ),
      ),
      isTrue,
    );
    expect(
      NiaproSerializer.sameContent(
        base,
        change(project: (p) => p.copyWith(fps: 24)),
      ),
      isFalse,
      reason: '作品の設定',
    );
    expect(
      NiaproSerializer.sameContent(
        base,
        change(
          scenes: [
            for (final scene in base.scenes) scene.copyWith(name: 'Other'),
          ],
        ),
      ),
      isFalse,
      reason: 'シーン',
    );
    final key = base.tileData.keys.single;
    expect(
      NiaproSerializer.sameContent(
        base,
        change(
          tiles: {
            key: {'0,0': _tile(41)},
          },
        ),
      ),
      isFalse,
      reason: '絵',
    );
  });
  test('a project and its copy moved together both arrive, also when the '
      'copy comes first in the file, and reading the file again adds '
      'nothing', () async {
    const saved = <String, Object>{'language': 'ja'};
    final a = await device('A', saved);
    final episode = await a.createProject(
      name: 'Episode',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(a, episode.id, 40);
    await a.saveProject(episode.id);
    expect(await a.duplicateProject(episode.id, name: 'Episode (コピー)'), isTrue);
    final copy = a.projects.singleWhere((p) => p.id != episode.id);
    final originalFirst = await exportProjects(a, [episode.id, copy.id]);
    final copyFirst = await exportProjects(a, [copy.id, episode.id]);
    await settleTransfer();

    for (final (order, file) in [
      ('original first', originalFirst),
      ('copy first', copyFirst),
    ]) {
      final b = await device('B-$order', saved);
      final report = TransferImportReport();
      await NiatraSerializer.restoreProjects(file, b, report: report);
      expect(names(b), [
        'Episode',
        'Episode (コピー)',
      ], reason: '$order: 作品も、その複製も届く');
      expect(report.addedCopies, isEmpty, reason: '$order: 名前を変えていない');
      await NiatraSerializer.restoreProjects(file, b);
      expect(names(b), [
        'Episode',
        'Episode (コピー)',
      ], reason: '$order: 読み直しても増えない');
    }
  });

  test('a project this device only has in the Shared tab still arrives in '
      'the projects tab under its own name', () async {
    const saved = <String, Object>{'language': 'ja'};
    final a = await device('A', saved);
    final work = await a.createProject(
      name: 'Ep1',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    _paint(a, work.id, 40);
    await a.saveProject(work.id);
    final file = await exportProjects(a, [work.id]);
    await settleTransfer();

    final b = await device('B', saved);
    // 前に同じ作品を.niashareで送って、共有のタブに取り込んでいた。
    final shareDir = Directory('${temp.path}/share-in')..createSync();
    final share = await NiaproSerializer.saveShare(
      project: a.projects.single,
      scenes: a.scenesOf(work.id),
      tileManager: a.tileManagerOf(work.id),
      outputDir: shareDir.path,
    );
    await b.importSharedProject(await NiaproSerializer.loadShare(share.path));
    final report = TransferImportReport();
    await NiatraSerializer.restoreProjects(file, b, report: report);
    expect(
      [
        for (final p in b.projects)
          if (!p.isSharedImport) p.name,
      ],
      ['Ep1'],
      reason: '自分の作品は作品のタブへ',
    );
    expect([for (final p in b.shared) p.name], ['Ep1'], reason: '共有のタブはそのまま');
    expect(report.addedCopies, isEmpty, reason: '共有のタブの作品とは名前を比べない');
  });

  test('a project brought back unchanged is not added again, but it keeps '
      'the favourite, tags and folder given to it on the other device (a '
      'favourite or folder set here stays); reading the file again or '
      'restarting changes nothing', () async {
    const saved = <String, Object>{'language': 'ja'};
    var b = await device('B', saved);
    final ids = <String>[];
    for (final (name, value) in [('Ep1', 40), ('Ep2', 41)]) {
      final p = await b.createProject(
        name: name,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      _paint(b, p.id, value);
      await b.saveProject(p.id);
      ids.add(p.id);
    }
    await b.setProjectTags(ids[0], ['draft']);
    // Ep2はこの端末でお気に入りにして、自分のフォルダへ入れてある。
    await b.setFavorite(ids[1], true);
    final mineFolder = await b.createFolder('Mine');
    await b.moveToFolder(ids[1], mineFolder.id);
    await settleTransfer();
    final fromB = await exportProjects(b, ids);
    await settleTransfer();
    var prefs = await SharedPreferences.getInstance();
    final savedB = {for (final key in prefs.getKeys()) key: prefs.get(key)!};

    // もう1台で、描かずにお気に入り・タグ・新しいフォルダへの整理だけをする。
    final a = await device('A', saved);
    await NiatraSerializer.restoreProjects(fromB, a);
    final ep1 = a.projects.singleWhere((p) => p.name == 'Ep1');
    final ep2 = a.projects.singleWhere((p) => p.name == 'Ep2');
    await a.setFavorite(ep1.id, true);
    await a.setFavorite(ep2.id, false);
    await a.setProjectTags(ep1.id, ['Draft', 'finished']);
    final done = await a.createFolder('Done');
    await a.moveToFolder(ep1.id, done.id);
    await a.moveToFolder(ep2.id, done.id);
    await settleTransfer();
    final back = await exportProjects(a, [ep1.id, ep2.id]);
    await settleTransfer();

    b = await device('B', savedB);
    final report = TransferImportReport();
    await NiatraSerializer.restoreProjects(back, b, report: report);
    String state(ProjectService d) => ([
      for (final p in d.projects)
        '${p.name}|fav=${p.isFavorite}|tags=${p.tags.join(',')}|'
            'folder=${d.folders.where((f) => f.id == p.folderId).firstOrNull?.name}',
    ]..sort()).join('\n');
    const expected =
        'Ep1|fav=true|tags=draft,finished|folder=Done\n'
        'Ep2|fav=true|tags=|folder=Mine';
    expect(
      state(b),
      expected,
      reason:
          'もう1台での整理が届き、この端末で付けたお気に入り・入れたフォルダは'
          'そのまま（同じ作品は足さない）',
    );
    expect([for (final f in b.folders) f.name]..sort(), ['Done', 'Mine']);
    expect(report.addedCopies, isEmpty);

    await NiatraSerializer.restoreProjects(back, b);
    expect(state(b), expected, reason: '読み直しても変わらない');
    await settleTransfer();
    prefs = await SharedPreferences.getInstance();
    b = await device('B', {
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    });
    expect(state(b), expected, reason: '起動し直しても');
  });

  test(
    'projects with the same name moved together keep their names on a '
    'device that has no project of that name, and nothing is reported; '
    'on a device that has one, they arrive with numbered copy names',
    () async {
      const saved = <String, Object>{'language': 'ja'};
      final a = await device('A', saved);
      final ids = <String>[];
      for (final value in [40, 41]) {
        final p = await a.createProject(
          name: '新規プロジェクト',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        _paint(a, p.id, value);
        await a.saveProject(p.id);
        ids.add(p.id);
      }
      final file = await exportProjects(a, ids);
      await settleTransfer();

      final fresh = await device('F', saved);
      final report = TransferImportReport();
      await NiatraSerializer.restoreProjects(file, fresh, report: report);
      expect(names(fresh), [
        '新規プロジェクト',
        '新規プロジェクト',
      ], reason: '空の端末では、もう1台と同じ名前のまま');
      expect(report.addedCopies, isEmpty, reason: 'この端末に同じ名前の作品は無かった');
      await NiatraSerializer.restoreProjects(file, fresh);
      expect(names(fresh), ['新規プロジェクト', '新規プロジェクト'], reason: '読み直しても増えない');

      final own = await device('G', saved);
      final mine = await own.createProject(
        name: '新規プロジェクト',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      _paint(own, mine.id, 99);
      final ownReport = TransferImportReport();
      await NiatraSerializer.restoreProjects(file, own, report: ownReport);
      expect(names(own), [
        '新規プロジェクト',
        '新規プロジェクト (コピー 2)',
        '新規プロジェクト (コピー)',
      ], reason: 'この端末の作品と同じ名前なら、番号の違う複製の名前で足す');
      expect(ownReport.addedCopies, ['新規プロジェクト (コピー)', '新規プロジェクト (コピー 2)']);
    },
  );

  test('a moved project keeps its folder: the folders it is in come with it '
      '(nested, with colour and favourite), this device\'s folders are not '
      'renamed or moved, a folder trashed here is not brought back, and '
      'reading the file again or restarting changes nothing', () async {
    const saved = <String, Object>{'language': 'ja'};
    final a = await device('A', saved);
    final works = await a.createFolder('Works');
    await a.editFolder(works.id, color: 0xFF3366CC);
    await a.toggleFolderFavorite(works.id);
    final season = await a.createFolder('Season 1', parentFolderId: works.id);
    final trashed = await a.createFolder('Old');
    final ids = <String>[];
    for (final (name, folder) in [
      ('Ep1', season.id),
      ('Ep2', works.id),
      ('Ep3', trashed.id),
      ('Ep4', null),
    ]) {
      final p = await a.createProject(
        name: name,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      _paint(a, p.id, 40 + ids.length);
      await a.saveProject(p.id);
      if (folder != null) await a.moveToFolder(p.id, folder);
      ids.add(p.id);
    }
    final file = await exportProjects(a, ids);
    final aFolders = {for (final f in a.folders) f.id: f};
    await settleTransfer();

    // この端末にも「Works」という自分のフォルダがある。「Old」は前に
    // 受け取って、この端末でゴミ箱へ移した。
    var b = await device('B', {
      ...saved,
      'trashed_project_folders': jsonEncode([
        TrashedFolder(
          folder: ProjectFolder(id: trashed.id, name: 'Old'),
          subfolders: const [],
          projectIds: const [],
          deletedAt: DateTime(2026, 11, 1),
        ).toJson(),
      ]),
    });
    final mine = await b.createFolder('Works');
    await NiatraSerializer.restoreProjects(file, b);

    String folders(ProjectService d) => [
      for (final f in d.folders)
        '${f.name}|parent=${d.folders.where((x) => x.id == f.parentFolderId).firstOrNull?.name}'
            '|${f.color}|${f.isFavorite}|${f.id == mine.id
                ? 'mine'
                : aFolders.containsKey(f.id)
                ? 'A'
                : '?'}',
    ].join('\n');
    // 作品の並び順は問わない（起動し直すと保存から読んだ順になる）。
    String placed(ProjectService d) => ([
      for (final p in d.projects)
        '${p.name}->${d.folders.where((f) => f.id == p.folderId).firstOrNull?.name ?? (p.folderId == null ? 'top' : 'MISSING ${p.folderId}')}',
    ]..sort()).join('\n');
    const expectedFolders =
        'Works|parent=null|null|false|mine\n'
        'Works (2)|parent=null|4281558732|true|A\n'
        'Season 1|parent=Works (2)|null|false|A';
    const expectedPlaced =
        'Ep1->Season 1\n'
        'Ep2->Works (2)\n'
        'Ep3->top\n'
        'Ep4->top';
    expect(folders(b), expectedFolders, reason: '作品のフォルダが一緒に届く');
    expect(placed(b), expectedPlaced, reason: '作品はもう1台と同じフォルダに入る');
    expect(b.trashedFolders.map((t) => t.folder.id), [
      trashed.id,
    ], reason: 'この端末でゴミ箱へ移したフォルダは戻さない');

    await NiatraSerializer.restoreProjects(file, b);
    expect(folders(b), expectedFolders, reason: '読み直しても変わらない');
    expect(placed(b), expectedPlaced, reason: '読み直しても変わらない');

    final prefs = await SharedPreferences.getInstance();
    await settleTransfer();
    b = await device('B', {
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    });
    expect(folders(b), expectedFolders, reason: '起動し直しても');
    expect(placed(b), expectedPlaced, reason: '起動し直しても');
    expect(b.trashedFolders.map((t) => t.folder.id), [trashed.id]);
  });
}
