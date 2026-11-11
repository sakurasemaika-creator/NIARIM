import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で移した作品が使う自動塗りプリセット・パーツ・透かし、
/// 自動塗りのパーツが使うトーンは、合わせた後でもう1台の中身を持つこの端末の
/// 項目を指す（この端末の版を残して足した複製なら複製、同じ中身の項目が別の
/// IDで既にあればその項目）。この端末にあった作品は書き換えず、同じファイルを
/// 読み直しても、作品を持ち帰っても、作品は増えない。

const _red = 0xFFFF0000;
const _blue = 0xFF0000FF;
const _green = 0xFF00FF00;
const _gray = 0xFF808080;

/// 今の保存（1台の端末の中身）。
Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

/// 見つけた食い違いを最後にまとめて報告する。
class _Problems {
  final _found = <String>[];

  void check(Object? actual, Object? matcher, String reason) {
    try {
      expect(actual, matcher, reason: reason);
    } on TestFailure catch (e) {
      _found.add('$e'.trim());
    }
  }

  void verify() {
    if (_found.isEmpty) return;
    fail('${_found.length} problem(s):\n\n${_found.join('\n\n')}');
  }
}

/// 作品の整理（名前と整理の順。同じ名前・同じ整理の作品は並び順に
/// よらない）。
List<String> _organisation(ProjectService service) => [
  for (final x in service.projects)
    '${x.name}@'
        '${service.folders.where((f) => f.id == x.folderId).firstOrNull?.name ?? 'top'}'
        '${x.isFavorite ? ' fav' : ''} ${x.tags}',
]..sort();

/// 作品の全レイヤー（全シーン・全フレーム）。
List<Layer> _layers(ProjectService service, String projectId) => [
  for (final scene in service.scenesOf(projectId))
    for (final frame in scene.frames) ...frame.layers,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory storage;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_references_');
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

  /// [who]の端末の書類フォルダへ切り替え、[saved]の保存で起動し直す。
  Future<(TransferDevice, ProjectService)> useDevice(
    String who,
    Map<String, Object> saved,
  ) async {
    storage = Directory('${temp.path}/$who')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues(saved);
    final device = await TransferDevice.start();
    final projects = ProjectService();
    await projects.init();
    return (device, projects);
  }

  /// 引き継ぎ画面と同じく、選んだ作品を.niashareにする。
  Future<Map<String, Uint8List>> shares(
    ProjectService service,
    List<String> ids,
  ) async {
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
    return files;
  }

  /// [presetId]のプリセットを使い、最初のレイヤーを[partIds]の先頭のパーツの
  /// 線画にし（残りのパーツは足したレイヤー）、[markId]の透かしのレイヤーを
  /// 持つ作品。
  Future<Project> makeWork(
    ProjectService service,
    String name, {
    required String presetId,
    required List<String> partIds,
    String? markId,
  }) async {
    final work = await service.createProject(
      name: name,
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final scene = service.scenesOf(work.id).first;
    final frame = scene.frames.first;
    service.updateLayer(
      projectId: work.id,
      sceneId: scene.id,
      frameIndex: frame.index,
      layer: frame.layers.first.copyWith(partId: partIds.first),
    );
    for (final partId in partIds.skip(1)) {
      final layer = service.addLayer(
        projectId: work.id,
        sceneId: scene.id,
        frameIndex: frame.index,
        type: LayerType.normal,
        name: partId,
      );
      service.updateLayer(
        projectId: work.id,
        sceneId: scene.id,
        frameIndex: frame.index,
        layer: layer.copyWith(partId: partId),
      );
    }
    if (markId != null) {
      final layer = service.addLayer(
        projectId: work.id,
        sceneId: scene.id,
        frameIndex: frame.index,
        type: LayerType.watermark,
        name: 'mark',
      );
      service.updateLayer(
        projectId: work.id,
        sceneId: scene.id,
        frameIndex: frame.index,
        layer: layer.copyWith(watermarkAssetId: markId),
      );
    }
    await service.setEnabledAutofillPresetIds(work.id, [presetId]);
    await service.saveProject(work.id);
    await settleTransfer();
    return service.projects.firstWhere((p) => p.id == work.id);
  }

  test('a moved project uses the copies that hold the other device\'s '
      'version of its autofill preset, parts and watermark; reading the '
      'file again or taking the project back adds no project', () async {
    // A：自動塗りプリセット「Hair」（赤）と文字の透かし「@me」（赤）を作り、
    // Bへ移す。
    var (a, aWorks) = await useDevice('A', {'language': 'ja'});
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_hair',
        name: 'Hair',
        parts: [AutofillPart(id: 'part_hair', name: 'Hair', color: _red)],
      ),
    );
    final mark = await a.watermark.addTextWatermark('@me', color: _red);
    await settleTransfer();
    final first = await a.export();
    final savedA = await _snapshot();

    // B：受け取って、どちらも青に変える（同じID）。
    var (b, bWorks) = await useDevice('B', {'language': 'ja'});
    await b.import(first, nextDir());
    final hairB = b.autofill.presets.firstWhere((p) => p.id == 'p_hair');
    await b.autofill.updatePreset(
      hairB.copyWith(parts: [hairB.parts.single.copyWith(color: _blue)]),
    );
    final markB = b.watermark.assets.firstWhere((m) => m.id == mark.id);
    await b.watermark.updateAsset(markB.copyWith(textColor: _blue));
    await settleTransfer();
    final savedB = await _snapshot();

    // A：そのプリセットと透かしを使う作品を作り、すべての項目と一緒に移す。
    (a, aWorks) = await useDevice('A', savedA);
    final study = await makeWork(
      aWorks,
      'Hair study',
      presetId: 'p_hair',
      partIds: ['part_hair'],
      markId: mark.id,
    );
    final withWork = await a.export(
      projectFiles: await shares(aWorks, [study.id]),
    );
    await settleTransfer();
    final savedA2 = await _snapshot();

    (b, bWorks) = await useDevice('B', savedB);
    final report = TransferImportReport();
    await b.import(withWork, nextDir(), report: report, projects: bWorks);

    final p = _Problems();
    final hairCopy = b.autofill.presets
        .where((x) => x.name == 'Hair (コピー)')
        .firstOrNull;
    final markCopy = b.watermark.assets
        .where((x) => x.name == '@me (コピー)')
        .firstOrNull;
    p.check(
      [hairCopy?.parts.single.color, markCopy?.textColor],
      [_red, _red],
      'この端末の版を残し、もう1台の版を複製として足す',
    );
    p.check(
      [
        b.autofill.presets
            .firstWhere((x) => x.id == 'p_hair')
            .parts
            .single
            .color,
        b.watermark.assets.firstWhere((x) => x.id == mark.id).textColor,
      ],
      [_blue, _blue],
      'この端末の版はそのまま',
    );
    final moved = bWorks.projects
        .where((x) => x.name == 'Hair study')
        .firstOrNull;
    p.check(moved, isNotNull, '作品が届く');
    if (moved != null && hairCopy != null && markCopy != null) {
      p.check(moved.enabledAutofillPresetIds, [
        hairCopy.id,
      ], '作品で使うプリセットは、もう1台の版を持つ複製');
      final layers = _layers(bWorks, moved.id);
      p.check(
        [
          for (final l in layers)
            if (l.partId != null) b.autofill.findPart(l.partId!)?.color,
        ],
        [_red],
        '線画のパーツは、もう1台の色を持つ複製のパーツ',
      );
      p.check(
        [
          for (final l in layers)
            if (l.watermarkAssetId != null) l.watermarkAssetId,
        ],
        [markCopy.id],
        '透かしのレイヤーは、もう1台の版を持つ複製',
      );
    }

    // 同じファイルを読み直しても、作品は増えない。
    await b.import(withWork, nextDir(), projects: bWorks);
    p.check(
      [for (final x in bWorks.projects) x.name],
      ['Hair study'],
      '読み直しても作品は増えない',
    );
    p.check(
      [
        for (final x in b.autofill.presets) x.name,
      ].where((n) => n.startsWith('Hair')),
      ['Hair', 'Hair (コピー)'],
      '読み直してもプリセットは増えない',
    );

    // Bの作品をAへ持ち帰る：Aの元の作品と同じ（Aの元のプリセット・
    // 透かしを指す）ので、作品は増えない。
    final back = await b.export(
      projectFiles: await shares(bWorks, [
        bWorks.projects.firstWhere((x) => x.name == 'Hair study').id,
      ]),
    );
    await settleTransfer();
    (a, aWorks) = await useDevice('A', savedA2);
    final backReport = TransferImportReport();
    await a.import(back, nextDir(), report: backReport, projects: aWorks);
    p.check(
      [for (final x in aWorks.projects) x.name],
      ['Hair study'],
      '持ち帰った同じ作品は足さない',
    );
    p.check(
      backReport.addedCopies.where((n) => n.startsWith('Hair study')),
      isEmpty,
      '作品の複製を知らせない',
    );
    p.verify();
  });

  test('a part that only the other device\'s version of a preset has is '
      'found in the moved project, with the other device\'s colours', () async {
    var (a, aWorks) = await useDevice('A', {'language': 'ja'});
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_rv',
        name: 'Hero',
        parts: [AutofillPart(id: 'rv_hair', name: 'Hair', color: _red)],
      ),
    );
    await settleTransfer();
    final first = await a.export();
    final savedA = await _snapshot();

    var (b, bWorks) = await useDevice('B', {'language': 'ja'});
    await b.import(first, nextDir());
    // B：パーツ「影」を足し、髪と影の線画を持つ作品を作る。
    final hero = b.autofill.presets.firstWhere((p) => p.id == 'p_rv');
    await b.autofill.updatePreset(
      hero.copyWith(
        parts: [
          ...hero.parts,
          const AutofillPart(id: 'b_shadow', name: 'Shadow', color: _gray),
        ],
      ),
    );
    final scene = await makeWork(
      bWorks,
      'Scene',
      presetId: 'p_rv',
      partIds: ['rv_hair', 'b_shadow'],
    );
    final fromB = await b.export(
      projectFiles: await shares(bWorks, [scene.id]),
    );
    await settleTransfer();

    // A：その間に髪の色を緑に変えていた。
    (a, aWorks) = await useDevice('A', savedA);
    final heroA = a.autofill.presets.firstWhere((p) => p.id == 'p_rv');
    await a.autofill.updatePreset(
      heroA.copyWith(parts: [heroA.parts.single.copyWith(color: _green)]),
    );
    await settleTransfer();
    await a.import(fromB, nextDir(), projects: aWorks);

    final p = _Problems();
    final copy = a.autofill.presets
        .where((x) => x.name == 'Hero (コピー)')
        .firstOrNull;
    p.check(copy?.parts.map((x) => x.color), [_red, _gray], 'Bの版を複製として足す');
    final moved = aWorks.projects.where((x) => x.name == 'Scene').firstOrNull;
    p.check(moved, isNotNull, '作品が届く');
    if (moved != null) {
      p.check(
        [
          for (final l in _layers(aWorks, moved.id))
            if (l.partId != null) a.autofill.findPart(l.partId!)?.color,
        ],
        unorderedEquals([_red, _gray]),
        '線画のパーツは、Bの版のパーツ（Bで足したパーツも見つかる）',
      );
      p.check(moved.enabledAutofillPresetIds, [copy?.id], '作品で使うプリセットはBの版');
    }
    p.check(
      a.autofill.presets.firstWhere((x) => x.id == 'p_rv').parts.single.color,
      _green,
      'この端末の版はそのまま',
    );
    p.verify();
  });

  test('a watermark registered on both devices under different IDs is the '
      'same watermark in the moved project', () async {
    var (a, _) = await useDevice('A', {'language': 'ja'});
    final markA = await a.watermark.addTextWatermark('@me', color: _red);
    await settleTransfer();
    final savedA = await _snapshot();

    // 別のミリ秒で登録する（IDは時刻から付く）。
    await Future<void>.delayed(const Duration(milliseconds: 3));
    var (b, bWorks) = await useDevice('B', {'language': 'ja'});
    final markB = await b.watermark.addTextWatermark('@me', color: _red);
    await settleTransfer();
    expect(markB.id, isNot(markA.id));
    final work = await makeWork(
      bWorks,
      'Signed',
      presetId: 'builtin_gray_underpaint',
      partIds: ['builtin_gray_underpaint_base'],
      markId: markB.id,
    );
    final fromB = await b.export(projectFiles: await shares(bWorks, [work.id]));
    await settleTransfer();

    final (a2, aWorks) = await useDevice('A', savedA);
    await a2.import(fromB, nextDir(), projects: aWorks);
    final p = _Problems();
    p.check(
      [for (final m in a2.watermark.assets) m.id],
      [markA.id],
      '同じ透かしは足さない',
    );
    final moved = aWorks.projects.where((x) => x.name == 'Signed').firstOrNull;
    p.check(moved, isNotNull, '作品が届く');
    if (moved != null) {
      p.check(
        [
          for (final l in _layers(aWorks, moved.id))
            if (l.watermarkAssetId != null) l.watermarkAssetId,
        ],
        [markA.id],
        '作品の透かしのレイヤーは、この端末の同じ透かし',
      );
    }
    p.verify();
  });

  test(
    'autofill parts that use a tone point at the tone holding the other '
    'device\'s texture: the same tone under another ID, or the copy',
    () async {
      var (a, _) = await useDevice('A', {'language': 'ja'});
      final dotsA = File('${temp.path}/dots_a.png')
        ..writeAsBytesSync([1, 2, 3]);
      final linesA = File('${temp.path}/lines_a.png')
        ..writeAsBytesSync([4, 5, 6]);
      a.tone.addTone(
        Tone(id: 'tone_dots_a', name: 'Dots', texturePath: dotsA.path),
      );
      a.tone.addTone(
        Tone(id: 'tone_lines', name: 'Lines', texturePath: linesA.path),
      );
      await a.autofill.addPreset(
        const AutofillPreset(
          id: 'p_toned',
          name: 'Toned',
          parts: [
            AutofillPart(
              id: 'toned_dots',
              name: 'Dots part',
              color: _red,
              useTone: true,
              toneId: 'tone_dots_a',
            ),
            AutofillPart(
              id: 'toned_lines',
              name: 'Lines part',
              color: _red,
              useTone: true,
              toneId: 'tone_lines',
            ),
          ],
        ),
      );
      await settleTransfer();
      final savedA = await _snapshot();
      final p = _Problems();
      // 画像を入れた今の形と、画像を入れない以前の形（トーンと自動塗りを
      // 同じ処理で合わせる）の両方。
      for (final bundled in [true, false]) {
        (a, _) = await useDevice('A', savedA);
        final fromA = await a.export(bundleImages: bundled);

        // B：同じ点のトーンを別のIDで持ち、同じIDの線のトーンは別の画像。
        final (b, _) = await useDevice('B$bundled', {'language': 'ja'});
        final dotsB = File('${temp.path}/dots_b.png')
          ..writeAsBytesSync([1, 2, 3]);
        final linesB = File('${temp.path}/lines_b.png')
          ..writeAsBytesSync([7, 8, 9]);
        b.tone.addTone(
          Tone(id: 'tone_dots_b', name: 'Dots', texturePath: dotsB.path),
        );
        b.tone.addTone(
          Tone(id: 'tone_lines', name: 'Lines', texturePath: linesB.path),
        );
        await settleTransfer();
        await b.import(fromA, nextDir());

        final linesCopy = b.tone.tones
            .where((t) => t.name == 'Lines (コピー)')
            .firstOrNull;
        p.check(linesCopy, isNotNull, '$bundled: 線のトーンはこの端末の版を残して複製を足す');
        p.check(b.tone.tones.where((t) => t.name == 'Dots').map((t) => t.id), [
          'tone_dots_b',
        ], '$bundled: 同じ点のトーンは足さない');
        final toned = b.autofill.presets
            .where((x) => x.id == 'p_toned')
            .firstOrNull;
        p.check(toned?.parts.map((x) => x.toneId), [
          'tone_dots_b',
          linesCopy?.id,
        ], '$bundled: パーツのトーンは、もう1台の画像を持つこの端末のトーン');
      }
      p.verify();
    },
  );

  test('a project moved with the copies of its preset and watermark is not '
      'added again after this device renames or deletes those copies, or the '
      'other device changes its preset and watermark to this device\'s '
      'version', () async {
    final p = _Problems();
    for (final change in ['rename', 'delete', 'converge']) {
      // A：自動塗りプリセット「Hair」（赤）と文字の透かし「@me」（赤）をBへ。
      var (a, aWorks) = await useDevice('A$change', {'language': 'ja'});
      await a.autofill.addPreset(
        const AutofillPreset(
          id: 'p_hair',
          name: 'Hair',
          parts: [AutofillPart(id: 'part_hair', name: 'Hair', color: _red)],
        ),
      );
      final mark = await a.watermark.addTextWatermark('@me', color: _red);
      await settleTransfer();
      final first = await a.export();
      final savedA = await _snapshot();

      // B：受け取って、どちらも青に変える。
      var (b, bWorks) = await useDevice('B$change', {'language': 'ja'});
      await b.import(first, nextDir());
      final hairB = b.autofill.presets.firstWhere((x) => x.id == 'p_hair');
      await b.autofill.updatePreset(
        hairB.copyWith(parts: [hairB.parts.single.copyWith(color: _blue)]),
      );
      await b.watermark.updateAsset(
        b.watermark.assets
            .firstWhere((m) => m.id == mark.id)
            .copyWith(textColor: _blue),
      );
      await settleTransfer();
      final savedB = await _snapshot();

      // A：両方を使う作品を作って移す（Bでは赤の複製を足し、作品はそれを
      // 使う）。
      (a, aWorks) = await useDevice('A$change', savedA);
      final study = await makeWork(
        aWorks,
        'Hair study',
        presetId: 'p_hair',
        partIds: ['part_hair'],
        markId: mark.id,
      );
      final withWork = await a.export(
        projectFiles: await shares(aWorks, [study.id]),
      );
      final savedA2 = await _snapshot();
      (b, bWorks) = await useDevice('B$change', savedB);
      await b.import(withWork, nextDir(), projects: bWorks);
      p.check(
        [for (final x in bWorks.projects) x.name],
        ['Hair study'],
        '$change: 作品が届く',
      );
      final hairCopy = b.autofill.presets
          .where((x) => x.name == 'Hair (コピー)')
          .firstOrNull;
      final markCopy = b.watermark.assets
          .where((x) => x.name == '@me (コピー)')
          .firstOrNull;
      p.check(
        [hairCopy?.id, markCopy?.id].contains(null),
        isFalse,
        '$change: もう1台の版の複製',
      );
      if (hairCopy == null || markCopy == null) continue;

      var next = withWork;
      switch (change) {
        case 'rename':
          // Bで複製の名前を変えてから、同じファイルを読み直す。
          await b.autofill.updatePreset(hairCopy.copyWith(name: 'Hair from A'));
          await b.watermark.updateAsset(markCopy.copyWith(name: '@me from A'));
        case 'delete':
          // Bで複製を消してから、同じファイルを読み直す。
          await b.autofill.removePreset(hairCopy.id);
          await b.watermark.removeWatermark(markCopy.id);
        case 'converge':
          // Aがプリセットと透かしをBと同じ青にして、同じ作品をもう一度移す。
          final savedB2 = await _snapshot();
          (a, aWorks) = await useDevice('A$change', savedA2);
          final hairA = a.autofill.presets.firstWhere((x) => x.id == 'p_hair');
          await a.autofill.updatePreset(
            hairA.copyWith(parts: [hairA.parts.single.copyWith(color: _blue)]),
          );
          await a.watermark.updateAsset(
            a.watermark.assets
                .firstWhere((m) => m.id == mark.id)
                .copyWith(textColor: _blue),
          );
          await settleTransfer();
          next = await a.export(projectFiles: await shares(aWorks, [study.id]));
          (b, bWorks) = await useDevice('B$change', savedB2);
      }
      await settleTransfer();
      final report = TransferImportReport();
      await b.import(next, nextDir(), report: report, projects: bWorks);
      p.check(
        [for (final x in bWorks.projects) x.name],
        ['Hair study'],
        '$change: 同じ作品は足さない',
      );
      p.check(
        report.addedCopies.where((n) => n.startsWith('Hair study')),
        isEmpty,
        '$change: 作品の複製を知らせない',
      );
    }
    p.verify();
  });

  test('an in-app duplicate filed differently from its original keeps the '
      'organisation of both projects when the file is read twice on another '
      'device and taken back', () async {
    final p = _Problems();
    // ファイルの中の作品の順（どちらの順でも同じ）。
    for (final order in ['original first', 'duplicate first']) {
      final tag = order.split(' ').first;
      final (aDevice, aWorks) = await useDevice('A$tag', {'language': 'ja'});
      final scene = await aWorks.createProject(
        name: 'Scene',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await aWorks.saveProject(scene.id);
      await settleTransfer();
      await aWorks.duplicateProject(scene.id, name: 'Scene (コピー)');
      await settleTransfer();
      final copy = aWorks.projects.firstWhere((x) => x.name == 'Scene (コピー)');
      final done = await aWorks.createFolder('Done');
      await aWorks.moveToFolder(copy.id, done.id);
      await aWorks.setFavorite(copy.id, true);
      await aWorks.setProjectTags(copy.id, ['backup']);
      await settleTransfer();

      final expected = _organisation(aWorks);
      p.check(expected, [
        'Scene (コピー)@Done fav [backup]',
        'Scene@top []',
      ], '$order: Aの作品');
      final ids = order == 'original first'
          ? [scene.id, copy.id]
          : [copy.id, scene.id];
      final fromA = await aDevice.export(
        projectFiles: await shares(aWorks, ids),
      );
      final savedA = await _snapshot();

      final (b, bWorks) = await useDevice('B$tag', {'language': 'ja'});
      await b.import(fromA, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), expected, '$order: Bが読む');
      await b.import(fromA, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), expected, '$order: Bが同じファイルを読み直す');
      final fromB = await b.export(
        projectFiles: await shares(bWorks, [
          for (final x in bWorks.projects) x.id,
        ]),
      );

      final (a, aBack) = await useDevice('A$tag', savedA);
      await a.import(fromB, nextDir(), projects: aBack);
      p.check(_organisation(aBack), expected, '$order: Aへ持ち帰る');
    }
    p.verify();
  });

  test(
    'organisation changed later on the other device reaches the matching '
    'one of two projects with the same content: the one with the same '
    'name, or, when the names are the same too, the one in the same folder',
    () async {
      final p = _Problems();
      for (final sameName in [false, true]) {
        final tag = sameName ? 'same' : 'diff';
        final (a, aWorks) = await useDevice('A$tag', {'language': 'ja'});
        final scene = await aWorks.createProject(
          name: 'Scene',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await aWorks.saveProject(scene.id);
        await settleTransfer();
        // 同じ名前のとき、複製は別のフォルダに入れてお気に入りにする（名前で
        // 見分けられないので、整理で見分ける）。
        await aWorks.duplicateProject(
          scene.id,
          name: sameName ? 'Scene' : 'Scene (コピー)',
        );
        await settleTransfer();
        final copy = aWorks.projects.firstWhere((x) => x.id != scene.id);
        if (sameName) {
          final done = await aWorks.createFolder('Done');
          await aWorks.moveToFolder(copy.id, done.id);
          await aWorks.setFavorite(copy.id, true);
        }
        await settleTransfer();
        final both = [scene.id, copy.id];
        final first = await a.export(projectFiles: await shares(aWorks, both));
        final savedA = await _snapshot();

        final (b, bWorks) = await useDevice('B$tag', {'language': 'ja'});
        await b.import(first, nextDir(), projects: bWorks);
        final savedB = await _snapshot();

        // A：複製にだけタグを付けて、もう一度移す。
        final (a2, aWorks2) = await useDevice('A$tag', savedA);
        await aWorks2.setProjectTags(copy.id, ['final']);
        await settleTransfer();
        final expected = _organisation(aWorks2);
        final second = await a2.export(
          projectFiles: await shares(aWorks2, both),
        );
        final (b2, bWorks2) = await useDevice('B$tag', savedB);
        await b2.import(second, nextDir(), projects: bWorks2);
        p.check(_organisation(bWorks2), expected, '$tag: タグは複製にだけ付く');
      }
      p.verify();
    },
  );

  test('when this device has two projects that cannot be told apart, neither '
      'takes the other device\'s organisation; a project deleted here comes '
      'back once', () async {
    final p = _Problems();
    // A：同じ中身・同じ名前・同じ整理の作品を2つ持ち、Bへ移す。
    final (a, aWorks) = await useDevice('A', {'language': 'ja'});
    final scene = await aWorks.createProject(
      name: 'Scene',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    await aWorks.saveProject(scene.id);
    await settleTransfer();
    await aWorks.duplicateProject(scene.id, name: 'Scene');
    await settleTransfer();
    final twins = [for (final x in aWorks.projects) x.id];
    final first = await a.export(projectFiles: await shares(aWorks, twins));
    final savedA = await _snapshot();
    final (b, bWorks) = await useDevice('B', {'language': 'ja'});
    await b.import(first, nextDir(), projects: bWorks);
    p.check(_organisation(bWorks), ['Scene@top []', 'Scene@top []'], '2つとも届く');
    final savedB = await _snapshot();

    // A：片方を消し、残った方にタグを付けて移す。Bの2つのどちらの作品か
    // 決められないので、どちらにも付けない。
    final (a2, aWorks2) = await useDevice('A', savedA);
    await aWorks2.deleteProject(twins.last);
    await aWorks2.setProjectTags(twins.first, ['x']);
    await settleTransfer();
    final second = await a2.export(
      projectFiles: await shares(aWorks2, [twins.first]),
    );
    final (b2, bWorks2) = await useDevice('B', savedB);
    await b2.import(second, nextDir(), projects: bWorks2);
    p.check(_organisation(bWorks2), [
      'Scene@top []',
      'Scene@top []',
    ], '決められない作品の整理は合わせず、作品も足さない');

    // 複製を別のフォルダへ入れた作品の組：Bで元の方を消してから同じ
    // ファイルを読み直すと、元の方だけが1つ戻る。
    final (a3, aWorks3) = await useDevice('A3', {'language': 'ja'});
    final original = await aWorks3.createProject(
      name: 'Pair',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    await aWorks3.saveProject(original.id);
    await settleTransfer();
    await aWorks3.duplicateProject(original.id, name: 'Pair (コピー)');
    await settleTransfer();
    final pairCopy = aWorks3.projects.firstWhere((x) => x.id != original.id);
    final done = await aWorks3.createFolder('Done');
    await aWorks3.moveToFolder(pairCopy.id, done.id);
    await aWorks3.setFavorite(pairCopy.id, true);
    await settleTransfer();
    final expected = _organisation(aWorks3);
    final pair = await a3.export(
      projectFiles: await shares(aWorks3, [original.id, pairCopy.id]),
    );
    final (b3, bWorks3) = await useDevice('B3', {'language': 'ja'});
    await b3.import(pair, nextDir(), projects: bWorks3);
    await bWorks3.deleteProject(
      bWorks3.projects.firstWhere((x) => x.name == 'Pair').id,
    );
    await settleTransfer();
    await b3.import(pair, nextDir(), projects: bWorks3);
    p.check(_organisation(bWorks3), expected, '消した元の作品だけが戻る');
    p.verify();
  });

  test('reading the same file again after refiling one of several same-name '
      'projects with the same content adds nothing; a twin deleted here comes '
      'back once under its own name', () async {
    final p = _Problems();

    /// Aで同じ中身・同じ名前の「Scene」を[folders]の数だけ作り（nullは一番
    /// 上）、すべてを移したファイルと、それを読んだBを返す。
    Future<(Uint8List, TransferDevice, ProjectService)> twins(
      String tag,
      List<String?> folders,
    ) async {
      final (a, aWorks) = await useDevice('A$tag', {'language': 'ja'});
      final scene = await aWorks.createProject(
        name: 'Scene',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await aWorks.saveProject(scene.id);
      await settleTransfer();
      for (var i = 1; i < folders.length; i++) {
        await aWorks.duplicateProject(scene.id, name: 'Scene');
        await settleTransfer();
      }
      final folderIds = <String?, String?>{null: null};
      for (final name in folders.whereType<String>().toSet()) {
        folderIds[name] = (await aWorks.createFolder(name)).id;
      }
      final ids = [for (final x in aWorks.projects) x.id];
      for (var i = 0; i < ids.length; i++) {
        if (folders[i] != null) {
          await aWorks.moveToFolder(ids[i], folderIds[folders[i]]);
        }
      }
      await settleTransfer();
      final file = await a.export(projectFiles: await shares(aWorks, ids));
      final (b, bWorks) = await useDevice('B$tag', {'language': 'ja'});
      await b.import(file, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), _organisation(aWorks), '$tag: Bが読むとAと同じ');
      return (file, b, bWorks);
    }

    String? folderOf(ProjectService service, String name) =>
        service.folders.firstWhere((f) => f.name == name).id;

    // Bで片方のフォルダを変えて、2つ（3つのうち2つ）が同じフォルダに並ぶ。
    for (final (tag, folders, from, to) in [
      ('topIntoDone', ['Done', null], null, 'Done'),
      ('doneToTop', ['Done', null], 'Done', null),
      ('threeTopIntoDone', ['Done', 'Archive', null], null, 'Done'),
    ]) {
      final (file, b, bWorks) = await twins(tag, folders);
      final moved = bWorks.projects.firstWhere(
        (x) => x.folderId == (from == null ? null : folderOf(bWorks, from)),
      );
      await bWorks.moveToFolder(
        moved.id,
        to == null ? null : folderOf(bWorks, to),
      );
      await settleTransfer();
      final before = _organisation(bWorks);
      final report = TransferImportReport();
      await b.import(file, nextDir(), projects: bWorks, report: report);
      p.check(_organisation(bWorks), before, '$tag: 読み直しても変わらない');
      p.check(report.addedCopies, isEmpty, '$tag: 複製を知らせない');
    }

    // Bで1つを消して読み直すと、消した作品が1つだけ同じ名前で戻る（同じ
    // 中身の作品と名前が同じでも複製の名前にしない）。同じフォルダの2つの
    // うちの1つ、またはほかと違うフォルダの1つ（ファイルの先頭にあっても、
    // 戻るのはそのフォルダの作品）。2つずつ2つのフォルダにあるときも、
    // 戻るのは消した作品のフォルダの作品（そのフォルダの作品がファイルの
    // 先でも後でも）。もう一度読み直しても変わらない。
    for (final (tag, folders, deleted) in [
      ('deletedTwin', [null, null], null),
      ('deletedDone', ['Done', null, null], 'Done'),
      ('deletedDoneOfTwo', ['Done', 'Done', null, null], 'Done'),
      ('deletedTopOfTwo', [null, null, 'Done', 'Done'], null),
      ('deletedDoneOfTwoLast', [null, null, 'Done', 'Done'], 'Done'),
    ]) {
      final (file, b, bWorks) = await twins(tag, folders);
      final expected = _organisation(bWorks);
      await bWorks.deleteProject(
        bWorks.projects
            .firstWhere(
              (x) =>
                  x.folderId ==
                  (deleted == null ? null : folderOf(bWorks, deleted)),
            )
            .id,
      );
      await settleTransfer();
      final report = TransferImportReport();
      await b.import(file, nextDir(), projects: bWorks, report: report);
      p.check(_organisation(bWorks), expected, '$tag: 消した作品が同じ名前で1つ戻る');
      p.check(report.addedCopies, isEmpty, '$tag: 複製を知らせない');
      await b.import(file, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), expected, '$tag: もう一度読み直しても増えない');
    }
    p.verify();
  });

  test('a twin deleted here comes back under its own name and with its own '
      'tags, whatever its place in the file', () async {
    final p = _Problems();
    // Aの作品（ファイルの順）の名前とタグ。どれも同じ中身。Bで[deleted]番目と
    // 同じ名前・タグの作品を1つ消して、同じファイルを読み直す。[retagged]は、
    // Bが消す前に付け直すタグ（大文字・小文字だけが違う。同じタグ）。
    for (final (tag, specs, deleted, retagged) in [
      (
        'names',
        [
          ('Scene', <String>[]),
          ('Scene', <String>[]),
          ('Scene (コピー)', <String>[]),
          ('Scene (コピー)', <String>[]),
        ],
        0,
        null,
      ),
      (
        'namesLast',
        [
          ('Scene (コピー)', <String>[]),
          ('Scene (コピー)', <String>[]),
          ('Scene', <String>[]),
          ('Scene', <String>[]),
        ],
        0,
        null,
      ),
      (
        'tags',
        [
          ('Scene', ['final']),
          ('Scene', <String>[]),
        ],
        0,
        null,
      ),
      (
        'tagsCase',
        [
          ('Scene', ['wip']),
          ('Scene', ['final']),
        ],
        0,
        (1, ['Final']),
      ),
    ]) {
      final (a, aWorks) = await useDevice('A$tag', {'language': 'ja'});
      final scene = await aWorks.createProject(
        name: specs.first.$1,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await aWorks.saveProject(scene.id);
      await settleTransfer();
      final ids = [scene.id];
      for (final (name, _) in specs.skip(1)) {
        final known = {for (final x in aWorks.projects) x.id};
        await aWorks.duplicateProject(scene.id, name: name);
        await settleTransfer();
        ids.add(aWorks.projects.firstWhere((x) => !known.contains(x.id)).id);
      }
      for (var i = 0; i < ids.length; i++) {
        if (specs[i].$2.isEmpty) continue;
        await aWorks.setProjectTags(ids[i], specs[i].$2);
      }
      await settleTransfer();
      final expected = _organisation(aWorks);
      final file = await a.export(projectFiles: await shares(aWorks, ids));
      final (b, bWorks) = await useDevice('B$tag', {'language': 'ja'});
      await b.import(file, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), expected, '$tag: Bが読むとAと同じ');
      String idOf((String, List<String>) spec) => bWorks.projects
          .firstWhere(
            (x) => x.name == spec.$1 && x.tags.join(',') == spec.$2.join(','),
          )
          .id;
      if (retagged != null) {
        await bWorks.setProjectTags(idOf(specs[retagged.$1]), retagged.$2);
        await settleTransfer();
      }
      final beforeDeleting = _organisation(bWorks);
      await bWorks.deleteProject(idOf(specs[deleted]));
      await settleTransfer();
      final report = TransferImportReport();
      await b.import(file, nextDir(), projects: bWorks, report: report);
      p.check(
        _organisation(bWorks),
        beforeDeleting,
        '$tag: 消した作品が、その名前・タグで1つ戻る',
      );
      p.check(report.addedCopies, isEmpty, '$tag: 複製を知らせない');
      await b.import(file, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), beforeDeleting, '$tag: もう一度読み直しても変わらない');
    }
    p.verify();
  });

  test('a project moved with a preset that arrived under a numbered name '
      '(this device had its own preset with that name) is not added again '
      'after this device edits or renames that preset', () async {
    final p = _Problems();
    for (final change in ['edit', 'rename']) {
      // A：自動塗りプリセット「Hair」（赤）を使う作品。
      final (a, aWorks) = await useDevice('A$change', {'language': 'ja'});
      await a.autofill.addPreset(
        const AutofillPreset(
          id: 'p_hair',
          name: 'Hair',
          parts: [AutofillPart(id: 'part_hair', name: 'Hair', color: _red)],
        ),
      );
      await settleTransfer();
      final work = await makeWork(
        aWorks,
        'Hair study',
        presetId: 'p_hair',
        partIds: ['part_hair'],
      );
      final file = await a.export(
        projectFiles: await shares(aWorks, [work.id]),
      );

      // B：自分の「Hair」（青）を別のIDで持つ。Aのプリセットは同じIDのまま
      // 「Hair (コピー)」として届き、作品はそれを指す。
      var (b, bWorks) = await useDevice('B$change', {'language': 'ja'});
      await b.autofill.addPreset(
        const AutofillPreset(
          id: 'p_mine',
          name: 'Hair',
          parts: [AutofillPart(id: 'mine_hair', name: 'Hair', color: _blue)],
        ),
      );
      await settleTransfer();
      await b.import(file, nextDir(), projects: bWorks);
      final arrived = b.autofill.presets
          .where((x) => x.name == 'Hair (コピー)')
          .firstOrNull;
      p.check(arrived?.id, 'p_hair', '$change: Aのプリセットは番号を付けて足す');
      final moved = bWorks.projects
          .where((x) => x.name == 'Hair study')
          .firstOrNull;
      p.check(moved, isNotNull, '$change: 作品が届く');
      if (arrived == null || moved == null) continue;
      p.check(
        [
          for (final l in _layers(bWorks, moved.id))
            if (l.partId != null) l.partId,
        ],
        [arrived.parts.single.id],
        '$change: 作品の線画のパーツは、届いたプリセットのパーツ',
      );

      // B：届いたプリセットを変えて（色・名前）起動し直し、同じファイルを
      // 読み直す。
      await b.autofill.updatePreset(
        change == 'edit'
            ? arrived.copyWith(
                parts: [arrived.parts.single.copyWith(color: _green)],
              )
            : arrived.copyWith(name: 'Hair from A'),
      );
      await settleTransfer();
      (b, bWorks) = await useDevice('B$change', await _snapshot());
      final report = TransferImportReport();
      await b.import(file, nextDir(), projects: bWorks, report: report);
      p.check(
        [for (final x in bWorks.projects) x.name],
        ['Hair study'],
        '$change: 同じ作品は足さない',
      );
      p.check(
        report.addedCopies.where((n) => n.startsWith('Hair study')),
        isEmpty,
        '$change: 作品の複製を知らせない',
      );
    }
    p.verify();
  });

  test('a project whose watermark or preset was found here under another ID '
      'is not added again after this device edits its own watermark or '
      'preset', () async {
    final p = _Problems();
    for (final change in ['watermark', 'preset']) {
      // A：自動塗りプリセット「Hair」と文字の透かし「@me」（どちらも赤）を
      // 使う作品。
      final (a, aWorks) = await useDevice('A$change', {'language': 'ja'});
      await a.autofill.addPreset(
        const AutofillPreset(
          id: 'p_hair',
          name: 'Hair',
          parts: [AutofillPart(id: 'part_hair', name: 'Hair', color: _red)],
        ),
      );
      final markA = await a.watermark.addTextWatermark('@me', color: _red);
      await settleTransfer();
      final work = await makeWork(
        aWorks,
        'Signed',
        presetId: 'p_hair',
        partIds: ['part_hair'],
        markId: markA.id,
      );
      final file = await a.export(
        projectFiles: await shares(aWorks, [work.id]),
      );

      // B：同じプリセット・透かしを別のIDで持つ。作品はBのものを指す。
      await Future<void>.delayed(const Duration(milliseconds: 3));
      var (b, bWorks) = await useDevice('B$change', {'language': 'ja'});
      await b.autofill.addPreset(
        const AutofillPreset(
          id: 'p_mine',
          name: 'Hair',
          parts: [AutofillPart(id: 'mine_hair', name: 'Hair', color: _red)],
        ),
      );
      final markB = await b.watermark.addTextWatermark('@me', color: _red);
      await settleTransfer();
      p.check(markB.id, isNot(markA.id), '$change: 透かしのIDは別');
      await b.import(file, nextDir(), projects: bWorks);
      final moved = bWorks.projects
          .where((x) => x.name == 'Signed')
          .firstOrNull;
      p.check(moved, isNotNull, '$change: 作品が届く');
      if (moved == null) continue;
      p.check(
        [
          for (final l in _layers(bWorks, moved.id))
            l.partId ?? l.watermarkAssetId,
        ].whereType<String>(),
        unorderedEquals(['mine_hair', markB.id]),
        '$change: 作品はBの同じプリセットのパーツと透かしを指す',
      );

      // B：自分の透かし・プリセットを変えて起動し直し、同じファイルを
      // 読み直す。
      if (change == 'watermark') {
        await b.watermark.updateAsset(markB.copyWith(textColor: _blue));
      } else {
        final mine = b.autofill.presets.firstWhere((x) => x.id == 'p_mine');
        await b.autofill.updatePreset(
          mine.copyWith(parts: [mine.parts.single.copyWith(color: _blue)]),
        );
      }
      await settleTransfer();
      (b, bWorks) = await useDevice('B$change', await _snapshot());
      final report = TransferImportReport();
      await b.import(file, nextDir(), projects: bWorks, report: report);
      p.check(
        [for (final x in bWorks.projects) x.name],
        ['Signed'],
        '$change: 同じ作品は足さない',
      );
      p.check(
        report.addedCopies.where((n) => n.startsWith('Signed')),
        isEmpty,
        '$change: 作品の複製を知らせない',
      );
    }
    p.verify();
  });

  test('a project from the file that can only be one project here is counted '
      'against it, while another one that could be either takes the other; '
      'a project here that took the organisation of a project from the file '
      'is not counted for another one', () async {
    final p = _Problems();
    // A：「Scene」（一番上）と複製「Scene (コピー)」（Done。[filed]で
    // なければ一番上のまま）をBへ移す（[copyFirst]ならファイルの中で複製が先。
    // Bの作品の並びも同じ順になる）。
    Future<
      (TransferDevice, ProjectService, Map<String, Object>, String, String)
    >
    start(String tag, {bool copyFirst = false, bool filed = true}) async {
      final (a, aWorks) = await useDevice('A$tag', {'language': 'ja'});
      final scene = await aWorks.createProject(
        name: 'Scene',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await aWorks.saveProject(scene.id);
      await settleTransfer();
      await aWorks.duplicateProject(scene.id, name: 'Scene (コピー)');
      await settleTransfer();
      final copy = aWorks.projects.firstWhere((x) => x.id != scene.id);
      final done = await aWorks.createFolder('Done');
      if (filed) await aWorks.moveToFolder(copy.id, done.id);
      await settleTransfer();
      final file = await a.export(
        projectFiles: await shares(
          aWorks,
          copyFirst ? [copy.id, scene.id] : [scene.id, copy.id],
        ),
      );
      final savedA = await _snapshot();
      final (b, bWorks) = await useDevice('B$tag', {'language': 'ja'});
      await b.import(file, nextDir(), projects: bWorks);
      p.check(_organisation(bWorks), [
        'Scene (コピー)@${filed ? 'Done' : 'top'} []',
        'Scene@top []',
      ], '$tag: Bが読む');
      return (b, bWorks, savedA, scene.id, copy.id);
    }

    // A：2つの名前を「Scene (コピー 2)」「Scene (コピー) (コピー)」に変え、
    // 元の方もDoneへ入れて移す。「Scene (コピー) (コピー)」になれるBの作品は
    // 「Scene (コピー)」だけなので、「Scene (コピー 2)」はBの「Scene」と組む
    // （ファイルの作品の順・Bの作品の並びによらず、何も足さない。どの作品も
    // 一番上のままで、どの組も同じ近さのときも：先に「Scene (コピー 2)」が
    // Bの「Scene (コピー)」と組んだ後でも、組み替えて両方を組む）。
    for (final (firstInFile, copyFirst, filed) in [
      ('renamed original', false, true),
      ('renamed copy', false, true),
      ('renamed original', true, true),
      ('renamed copy', true, true),
      ('renamed original', true, false),
      ('renamed copy', true, false),
    ]) {
      final tag =
          '${firstInFile.split(' ').last}${copyFirst ? 'B' : ''}'
          '${filed ? '' : 'Top'}';
      final (b, bWorks, savedA, sceneId, copyId) = await start(
        tag,
        copyFirst: copyFirst,
        filed: filed,
      );
      final before = _organisation(bWorks);
      final (a2, aWorks2) = await useDevice('A$tag', savedA);
      await aWorks2.renameProject(sceneId, 'Scene (コピー 2)');
      await aWorks2.renameProject(copyId, 'Scene (コピー) (コピー)');
      if (filed) {
        await aWorks2.moveToFolder(
          sceneId,
          aWorks2.folders.firstWhere((f) => f.name == 'Done').id,
        );
      }
      await settleTransfer();
      final ids = firstInFile == 'renamed original'
          ? [sceneId, copyId]
          : [copyId, sceneId];
      final second = await a2.export(projectFiles: await shares(aWorks2, ids));
      final report = TransferImportReport();
      await b.import(second, nextDir(), projects: bWorks, report: report);
      p.check(_organisation(bWorks), before, '$tag: 何も足さない');
      p.check(report.addedCopies, isEmpty, '$tag: 複製を知らせない');
    }

    // A：「Scene (コピー)」をもう一度複製して「Scene (コピー) (コピー)」とし、
    // 複製の2つだけを移す。Bの「Scene (コピー)」は同じ名前のファイルの作品の
    // 整理（タグ）を受け取るので、「Scene (コピー) (コピー)」の分には数えず、
    // 新しい作品として足す。
    final (b, bWorks, savedA, _, copyId) = await start('again');
    final (a2, aWorks2) = await useDevice('Aagain', savedA);
    await aWorks2.duplicateProject(copyId, name: 'Scene (コピー) (コピー)');
    await settleTransfer();
    await aWorks2.setProjectTags(copyId, ['final']);
    await settleTransfer();
    final copyOfCopy = aWorks2.projects.firstWhere(
      (x) => x.name == 'Scene (コピー) (コピー)',
    );
    final second = await a2.export(
      projectFiles: await shares(aWorks2, [copyId, copyOfCopy.id]),
    );
    final report = TransferImportReport();
    await b.import(second, nextDir(), projects: bWorks, report: report);
    p.check(_organisation(bWorks), [
      'Scene (コピー) (コピー)@Done []',
      'Scene (コピー)@Done [final]',
      'Scene@top []',
    ], 'again: 複製の複製を足し、タグは同じ名前の作品へ');
    p.check(report.addedCopies, isEmpty, 'again: 複製を知らせない');
    p.verify();
  });

  test('an autofill preset moved with the copy of a tone does not come again '
      'as a copy after the other device changes the tone to this device\'s '
      'version', () async {
    // A：トーン「Dots」をBへ渡す。Bはその画像を変える。
    var (a, _) = await useDevice('A', {'language': 'ja'});
    final dotsA = File('${temp.path}/dots_a.png')..writeAsBytesSync([1, 2, 3]);
    a.tone.addTone(
      Tone(id: 'tone_dots', name: 'Dots', texturePath: dotsA.path),
    );
    await settleTransfer();
    final first = await a.export();
    final savedA = await _snapshot();

    var (b, _) = await useDevice('B', {'language': 'ja'});
    await b.import(first, nextDir());
    final dotsB = File('${temp.path}/dots_b.png')..writeAsBytesSync([9, 9, 9]);
    b.tone.updateTone(
      b.tone.tones
          .firstWhere((t) => t.id == 'tone_dots')
          .copyWith(texturePath: dotsB.path),
    );
    await settleTransfer();
    final savedB = await _snapshot();

    // A：そのトーンを使うプリセットを作って移す（Bではトーンの複製を指す）。
    (a, _) = await useDevice('A', savedA);
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_toned',
        name: 'Toned',
        parts: [
          AutofillPart(
            id: 'toned_dots',
            name: 'Dots part',
            color: _red,
            useTone: true,
            toneId: 'tone_dots',
          ),
        ],
      ),
    );
    await settleTransfer();
    final second = await a.export();
    final savedA2 = await _snapshot();
    (b, _) = await useDevice('B', savedB);
    await b.import(second, nextDir());
    final p = _Problems();
    final dotsCopy = b.tone.tones
        .where((t) => t.name == 'Dots (コピー)')
        .firstOrNull;
    p.check(
      b.autofill.presets
          .where((x) => x.id == 'p_toned')
          .map((x) => x.parts.single.toneId),
      [dotsCopy?.id],
      'パーツはもう1台の画像を持つトーンの複製を指す',
    );
    final savedB2 = await _snapshot();

    // A：トーンの画像をBと同じにして、変えていないプリセットをもう一度移す。
    (a, _) = await useDevice('A', savedA2);
    final same = File('${temp.path}/dots_a2.png')..writeAsBytesSync([9, 9, 9]);
    a.tone.updateTone(
      a.tone.tones
          .firstWhere((t) => t.id == 'tone_dots')
          .copyWith(texturePath: same.path),
    );
    await settleTransfer();
    final third = await a.export();
    (b, _) = await useDevice('B', savedB2);
    final report = TransferImportReport();
    await b.import(third, nextDir(), report: report);
    p.check(
      [
        for (final x in b.autofill.presets)
          if (x.name.startsWith('Toned')) x.name,
      ],
      ['Toned'],
      'プリセットは増えない',
    );
    p.check(report.addedCopies, isEmpty, '何も足さないので知らせない');
    p.verify();
  });

  test('reading an older backup of this device after changing a preset adds '
      'the old preset as a copy but not the project a second time', () async {
    final (a, aWorks) = await useDevice('A', {'language': 'ja'});
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_hair',
        name: 'Hair',
        parts: [AutofillPart(id: 'part_hair', name: 'Hair', color: _red)],
      ),
    );
    final mark = await a.watermark.addTextWatermark('@me', color: _red);
    final work = await makeWork(
      aWorks,
      'Hair study',
      presetId: 'p_hair',
      partIds: ['part_hair'],
      markId: mark.id,
    );
    final backup = await a.export(
      projectFiles: await shares(aWorks, [work.id]),
    );
    final hair = a.autofill.presets.firstWhere((x) => x.id == 'p_hair');
    await a.autofill.updatePreset(
      hair.copyWith(parts: [hair.parts.single.copyWith(color: _blue)]),
    );
    await a.watermark.updateAsset(mark.copyWith(textColor: _blue));
    await settleTransfer();

    await a.import(backup, nextDir(), projects: aWorks);
    final p = _Problems();
    p.check(
      [
        for (final x in a.autofill.presets) x.name,
      ].where((n) => n.startsWith('Hair')),
      ['Hair', 'Hair (コピー)'],
      '前の版のプリセットは複製として足す',
    );
    p.check(
      [for (final x in aWorks.projects) x.name],
      ['Hair study'],
      'この端末の同じ作品は足さない',
    );
    p.verify();
  });
}
