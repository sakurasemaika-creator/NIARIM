import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）が、この端末の版を残してもう1台の版を複製として
/// 足したあと、利用者がその複製の名前を変えても、同じファイルを読み直して
/// 同じ複製をもう一度足さないこと（ブラシだけでなく、複製を足すどの一覧
/// でも）。

/// 一覧ごとの、この端末の項目（複製を足すどの一覧も）。[createOwn]は、
/// [create]と同じ名前で、別のIDの別の中身の項目（もう1台の項目と名前だけが
/// 重なる、この端末の自分の項目）。
typedef _Kind = ({
  String what,
  Future<void> Function(TransferDevice d) create,
  Future<void> Function(TransferDevice d) createOwn,
  List<String> Function(TransferDevice d) names,
  Future<void> Function(TransferDevice d, String from, String to) rename,
  Future<void> Function(TransferDevice d, String name) delete,
});

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory storage;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_renamed_copies_');
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

  Future<TransferDevice> useDevice(String who, Map<String, Object> saved) {
    storage = Directory('${temp.path}/$who')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues(saved);
    return TransferDevice.start();
  }

  Future<Map<String, Object>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
  }

  final kinds = <_Kind>[
    (
      what: 'brush',
      create: (d) async =>
          d.brush.addBrush(customTransferBrush('BrushR', 'Pen R', null)),
      createOwn: (d) async => d.brush.addBrush(
        customTransferBrush('BrushMine', 'Pen R', null).copyWith(spacing: 30),
      ),
      names: (d) => [
        for (final b in d.brush.brushes)
          if (!d.brush.isBuiltIn(b.id)) b.name,
      ],
      rename: (d, from, to) async {
        final b = d.brush.brushes.firstWhere((x) => x.name == from);
        d.brush.updateBrush(b.copyWith(name: to));
      },
      delete: (d, name) async => d.brush.deleteBrush(
        d.brush.brushes.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'tone',
      create: (d) async {
        final file = File('${storage.path}/dots.png')
          ..writeAsBytesSync([1, 2, 3]);
        d.tone.addTone(
          Tone(id: 'tone_r', name: 'Dots R', texturePath: file.path),
        );
      },
      createOwn: (d) async {
        final file = File('${storage.path}/own_dots.png')
          ..writeAsBytesSync([9, 9, 9]);
        d.tone.addTone(
          Tone(id: 'tone_mine', name: 'Dots R', texturePath: file.path),
        );
      },
      names: (d) => [
        for (final t in d.tone.tones)
          if (t.id.startsWith('tone_r') || t.name.startsWith('Dots R')) t.name,
      ],
      rename: (d, from, to) async {
        final t = d.tone.tones.firstWhere((x) => x.name == from);
        d.tone.updateTone(t.copyWith(name: to));
      },
      delete: (d, name) async =>
          d.tone.deleteTone(d.tone.tones.firstWhere((x) => x.name == name).id),
    ),
    (
      what: 'stamp',
      create: (d) async {
        final file = File('${storage.path}/star.png')
          ..writeAsBytesSync([4, 5, 6]);
        d.stamp.addStamp(
          Stamp(id: 'stamp_r', name: 'Star R', imagePath: file.path),
        );
      },
      createOwn: (d) async {
        final file = File('${storage.path}/own_star.png')
          ..writeAsBytesSync([9, 9, 9]);
        d.stamp.addStamp(
          Stamp(id: 'stamp_mine', name: 'Star R', imagePath: file.path),
        );
      },
      names: (d) => [
        for (final s in d.stamp.stamps)
          if (s.name.startsWith('Star R')) s.name,
      ],
      rename: (d, from, to) async {
        final s = d.stamp.stamps.firstWhere((x) => x.name == from);
        d.stamp.updateStamp(s.copyWith(name: to));
      },
      delete: (d, name) async => d.stamp.deleteStamp(
        d.stamp.stamps.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'autofill preset',
      create: (d) => d.autofill.addPreset(
        const AutofillPreset(
          id: 'p_r',
          name: 'Hair R',
          parts: [
            AutofillPart(id: 'p_r_hair', name: 'Hair', color: 0xFFFF0000),
          ],
        ),
      ),
      createOwn: (d) => d.autofill.addPreset(
        const AutofillPreset(
          id: 'p_mine',
          name: 'Hair R',
          parts: [
            AutofillPart(id: 'p_mine_hair', name: 'Hair', color: 0xFF0000FF),
          ],
        ),
      ),
      names: (d) => [
        for (final p in d.autofill.presets)
          if (p.name.startsWith('Hair R')) p.name,
      ],
      rename: (d, from, to) {
        final p = d.autofill.presets.firstWhere((x) => x.name == from);
        return d.autofill.updatePreset(p.copyWith(name: to));
      },
      delete: (d, name) => d.autofill.removePreset(
        d.autofill.presets.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'theme',
      create: (d) async => d.theme.savePreset(
        d.theme.current.copyWith(id: 'theme_r', name: 'Theme R'),
      ),
      createOwn: (d) async => d.theme.savePreset(
        d.theme.current.copyWith(
          id: 'theme_mine',
          name: 'Theme R',
          accentColor: const Color(0xFF123456),
        ),
      ),
      names: (d) => [
        for (final t in d.theme.presets)
          if (t.name.startsWith('Theme R')) t.name,
      ],
      rename: (d, from, to) async {
        final t = d.theme.presets.firstWhere((x) => x.name == from);
        d.theme.savePreset(t.copyWith(name: to));
      },
      delete: (d, name) async => d.theme.deletePreset(
        d.theme.presets.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'palette',
      create: (d) => d.palette.createPalette('Pal R'),
      createOwn: (d) async {
        await d.palette.createPalette('Pal R');
        await d.palette.addColorToPalette(
          d.palette.palettes.firstWhere((x) => x.name == 'Pal R').id,
          0xFF123456,
        );
      },
      names: (d) => [
        for (final p in d.palette.palettes)
          if (p.name.startsWith('Pal R')) p.name,
      ],
      rename: (d, from, to) => d.palette.renamePalette(
        d.palette.palettes.firstWhere((x) => x.name == from).id,
        to,
      ),
      delete: (d, name) => d.palette.deletePalette(
        d.palette.palettes.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'pixel art palette',
      create: (d) async => d.pixelArt.addPalette('Pix R', [0xFF000000]),
      createOwn: (d) async => d.pixelArt.addPalette('Pix R', [0xFFFFFFFF]),
      names: (d) => [
        for (final p in d.pixelArt.palettes)
          if (p.name.startsWith('Pix R')) p.name,
      ],
      rename: (d, from, to) => d.pixelArt.updatePalette(
        d.pixelArt.palettes.firstWhere((x) => x.name == from).id,
        name: to,
      ),
      delete: (d, name) => d.pixelArt.deletePalette(
        d.pixelArt.palettes.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'workspace',
      create: (d) =>
          d.workspace.save('Layout R', isLeftHanded: true, forcePcMode: null),
      createOwn: (d) =>
          d.workspace.save('Layout R', isLeftHanded: false, forcePcMode: null),
      names: (d) => [
        for (final p in d.workspace.presets)
          if (p.name.startsWith('Layout R')) p.name,
      ],
      rename: (d, from, to) => d.workspace.rename(
        d.workspace.presets.firstWhere((x) => x.name == from).id,
        to,
      ),
      delete: (d, name) => d.workspace.delete(
        d.workspace.presets.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'automation',
      create: (d) async {
        final copy = await d.automation.importJson(
          d.automation.exportJson(d.automation.items.first.id),
        );
        await d.automation.rename(copy.id, 'Auto R');
      },
      createOwn: (d) async {
        final copy = await d.automation.importJson(
          d.automation.exportJson(d.automation.items.last.id),
        );
        await d.automation.rename(copy.id, 'Auto R');
      },
      names: (d) => [
        for (final a in d.automation.items)
          if (a.name.startsWith('Auto R')) a.name,
      ],
      rename: (d, from, to) => d.automation.rename(
        d.automation.items.firstWhere((x) => x.name == from).id,
        to,
      ),
      delete: (d, name) => d.automation.delete(
        d.automation.items.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'quick tool',
      create: (d) async => d.quickTool.addEntry(
        const QuickToolEntry(id: 'qt_r', label: 'Tool R', toolKey: 'eraser'),
      ),
      createOwn: (d) async => d.quickTool.addEntry(
        const QuickToolEntry(id: 'qt_mine', label: 'Tool R', toolKey: 'pen'),
      ),
      names: (d) => [
        for (final e in d.quickTool.entries)
          if (e.label.startsWith('Tool R')) e.label,
      ],
      rename: (d, from, to) async => d.quickTool.replaceAll([
        for (final e in d.quickTool.entries)
          e.label == from
              ? QuickToolEntry.fromJson({...e.toJson(), 'label': to})
              : e,
      ]),
      delete: (d, name) async => d.quickTool.removeEntry(
        d.quickTool.entries.firstWhere((x) => x.label == name).id,
      ),
    ),
    (
      what: 'canvas size',
      create: (d) => d.settings.addCustomSizePreset('Size R', 640, 360),
      createOwn: (d) => d.settings.addCustomSizePreset('Size R', 800, 600),
      names: (d) => [
        for (final s in d.settings.customSizePresets)
          if (s.name.startsWith('Size R')) s.name,
      ],
      rename: (d, from, to) => d.settings.updateCustomSizePreset(
        d.settings.customSizePresets.firstWhere((x) => x.name == from).id,
        name: to,
      ),
      delete: (d, name) => d.settings.removeCustomSizePreset(
        d.settings.customSizePresets.firstWhere((x) => x.name == name).id,
      ),
    ),
    (
      what: 'watermark',
      create: (d) async =>
          d.watermark.addTextWatermark('@r', color: 0xFFFF0000),
      createOwn: (d) async =>
          d.watermark.addTextWatermark('@r', color: 0xFF0000FF),
      names: (d) => [
        for (final m in d.watermark.assets)
          if (m.name.startsWith('@r')) m.name,
      ],
      rename: (d, from, to) => d.watermark.updateAsset(
        d.watermark.assets.firstWhere((x) => x.name == from).copyWith(name: to),
      ),
      delete: (d, name) => d.watermark.removeWatermark(
        d.watermark.assets.firstWhere((x) => x.name == name).id,
      ),
    ),
  ];

  String original(_Kind kind, TransferDevice d) => kind.names(d).single;

  test('a copy that a transfer added and the user then renamed is found when '
      'the same file is read again, in every list that adds copies', () async {
    // A：どの一覧にも自分の項目を作って、Bへ渡す。
    final a = await useDevice('A', {'language': 'ja'});
    final originals = <String, String>{};
    for (final kind in kinds) {
      await kind.create(a);
      await settleTransfer();
      originals[kind.what] = original(kind, a);
    }
    final fromA = await a.export();

    // B：受け取った項目の名前をこの端末で変えてから、同じファイルを読み直す
    // （もう1台の版を「(コピー)」として足す）。
    final b = await useDevice('B', {'language': 'ja'});
    await b.import(fromA, nextDir());
    for (final kind in kinds) {
      await kind.rename(
        b,
        originals[kind.what]!,
        '${originals[kind.what]} on B',
      );
    }
    await settleTransfer();
    await b.import(fromA, nextDir());

    final p = _Problems();
    for (final kind in kinds) {
      p.check(
        kind.names(b)..sort(),
        ['${originals[kind.what]} (コピー)', '${originals[kind.what]} on B']
          ..sort(),
        '${kind.what}: もう1台の版を複製として足す',
      );
    }
    // 足した複製の名前を変える。
    for (final kind in kinds) {
      if (!kind.names(b).contains('${originals[kind.what]} (コピー)')) continue;
      await kind.rename(
        b,
        '${originals[kind.what]} (コピー)',
        '${originals[kind.what]} from A',
      );
    }
    await settleTransfer();
    final renamed = {
      for (final kind in kinds) kind.what: kind.names(b)..sort(),
    };

    // 同じファイルを読み直す。
    final report = TransferImportReport();
    await b.import(fromA, nextDir(), report: report);
    for (final (stage, d) in [
      ('reading again', b),
      ('restart', await useDevice('B', await snapshot())),
    ]) {
      for (final kind in kinds) {
        p.check(
          kind.names(d)..sort(),
          renamed[kind.what],
          '$stage: ${kind.what}: 名前を変えた複製は同じ版なので、もう一度は足さない',
        );
      }
    }
    p.check(report.addedCopies, isEmpty, '何も足さないので知らせない');

    // この端末の版を消して、名前を変えた複製だけを残してから読み直す：
    // もう1台の版は、その複製としてこの端末にある。
    final mine = await useDevice('B', await snapshot());
    for (final kind in kinds) {
      await kind.delete(mine, '${originals[kind.what]} on B');
    }
    await settleTransfer();
    final afterDelete = TransferImportReport();
    await mine.import(fromA, nextDir(), report: afterDelete);
    for (final kind in kinds) {
      p.check(kind.names(mine), [
        '${originals[kind.what]} from A',
      ], '${kind.what}: 名前を変えた複製だけを残すと、もう1台の版を足さない');
    }
    p.check(afterDelete.addedCopies, isEmpty, '消した後も何も足さない');
    p.verify();
  });

  test(
    'a copy that a transfer added because this device had its own item '
    'with that name (the other device\'s ID kept), renamed here, is found '
    'when the same file is read again, in every list that adds copies',
    () async {
      final a = await useDevice('A', {'language': 'ja'});
      final originals = <String, String>{};
      for (final kind in kinds) {
        await kind.create(a);
        await settleTransfer();
        originals[kind.what] = original(kind, a);
      }
      final fromA = await a.export();

      // B：同じ名前で別の中身の自分の項目を持つ（IDは時刻から付く一覧も
      // あるので、別のミリ秒で作る）。
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final b = await useDevice('B', {'language': 'ja'});
      for (final kind in kinds) {
        await kind.createOwn(b);
        await settleTransfer();
      }
      final first = TransferImportReport();
      await b.import(fromA, nextDir(), report: first);

      final p = _Problems();
      for (final kind in kinds) {
        p.check(
          kind.names(b)..sort(),
          [originals[kind.what], '${originals[kind.what]} (コピー)']..sort(),
          '${kind.what}: この端末の項目を残して、もう1台の項目を番号を付けて足す',
        );
      }
      p.check(
        first.addedCopies.length,
        kinds.length,
        '足した複製を知らせる: ${first.addedCopies}',
      );
      // 足した複製の名前を変えて、起動し直す。
      for (final kind in kinds) {
        if (!kind.names(b).contains('${originals[kind.what]} (コピー)')) continue;
        await kind.rename(
          b,
          '${originals[kind.what]} (コピー)',
          '${originals[kind.what]} from A',
        );
      }
      await settleTransfer();
      final restarted = await useDevice('B', await snapshot());
      final renamed = {
        for (final kind in kinds) kind.what: kind.names(restarted)..sort(),
      };

      // 同じファイルを読み直す。
      final report = TransferImportReport();
      await restarted.import(fromA, nextDir(), report: report);
      for (final (stage, d) in [
        ('reading again', restarted),
        ('restart', await useDevice('B', await snapshot())),
      ]) {
        for (final kind in kinds) {
          p.check(
            kind.names(d)..sort(),
            renamed[kind.what],
            '$stage: ${kind.what}: 名前を変えた複製はもう1台の同じ版なので、もう一度は足さない',
          );
        }
      }
      p.check(report.addedCopies, isEmpty, '何も足さないので知らせない');
      p.verify();
    },
  );
}
