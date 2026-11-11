import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で画像を使う項目（ブラシ・トーン・スタンプ）と、
/// 同じ中身の項目が既にあって足さなかった項目：
/// - 画像は置いた場所（ファイル名）ではなく中身で比べる。もう1台で足した
///   この端末の版の複製が戻ってきても、この端末の版をもう1つ足さない
///   （受け取った画像は受け取ったIDのファイル名で置くので、場所で比べると
///   いつも別の物に見えた）。
/// - 足さなかった項目のお気に入り・タグ・フォルダは、同じ中身のこの端末の
///   項目へ合わせる（黙って捨てない）。

/// 今の保存（1台の端末の中身）。
Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

/// [saved]の保存で端末を起動する（行き来の間、もう1台の保存は退けておく）。
Future<TransferDevice> _resume(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return TransferDevice.start();
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

String _bytesOf(String? path) {
  if (path == null) return 'none';
  final file = File(path);
  return file.existsSync() ? file.readAsBytesSync().join(',') : 'missing';
}

/// 自作の項目の名前と中身（並び順は問わない）。
List<String> _items(TransferDevice d) => [
  for (final b in d.brush.brushes)
    if (!d.brush.isBuiltIn(b.id))
      'brush ${b.name}|${b.spacing}|${_bytesOf(b.customImagePath)}',
  for (final t in d.tone.tones)
    if (!d.tone.isBuiltIn(t.id)) 'tone ${t.name}|${_bytesOf(t.texturePath)}',
  for (final s in d.stamp.stamps)
    if (!d.stamp.isBuiltIn(s.id))
      'stamp ${s.name}|${s.density}|${_bytesOf(s.imagePath)}',
]..sort();

/// [documents]の下に読み込みが置いた画像。
Set<String> _restored(Directory documents) {
  final restored = Directory('${documents.path}/niarim');
  if (!restored.existsSync()) return const {};
  return {
    for (final file in restored.listSync(recursive: true))
      if (file is File) file.path,
  };
}

/// [import]が[documents]の下に新しく置いた画像のうち、どの項目も使って
/// いない物。
Future<List<String>> _unusedAfter(
  TransferDevice d,
  Directory documents,
  Future<void> Function() import,
) async {
  final before = _restored(documents);
  await import();
  final used = {
    for (final b in d.brush.brushes) ...b.resolvedCustomImagePaths,
    for (final t in d.tone.tones) ?t.texturePath,
    for (final s in d.stamp.stamps) ?s.imagePath,
  };
  return [
    for (final path in _restored(documents))
      if (!before.contains(path) && !used.contains(path)) path,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_images_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a brush, tone and stamp with an image that each device changed '
      'differently reach the other device once, neither device gets its own '
      'version back as a copy, and more round trips change nothing', () async {
    // 端末ごとに1つの書類フォルダ（受け取った画像の置き場所）。
    final aDocs = Directory('${temp.path}/A')..createSync();
    final bDocs = Directory('${temp.path}/B')..createSync();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var a = await TransferDevice.start();
    final ink = File('${aDocs.path}/ink.png')..writeAsBytesSync([1, 2, 3]);
    final dots = File('${aDocs.path}/dots.png')..writeAsBytesSync([4, 5, 6]);
    final star = File('${aDocs.path}/star.png')..writeAsBytesSync([7, 8, 9]);
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', ink.path));
    a.tone.addTone(Tone(id: 'ToneDots', name: 'Dots', texturePath: dots.path));
    a.stamp.addStamp(
      Stamp(id: 'StampStar', name: 'Star', imagePath: star.path),
    );
    await settleTransfer();
    final first = await a.export();
    var savedA = await _snapshot();

    // もう1台は同じ項目を受け取ってから、それぞれ別に変える。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    await b.import(first, bDocs);
    Brush brushOf(TransferDevice d) =>
        d.brush.brushes.singleWhere((x) => x.id == 'BrushInk');
    Tone toneOf(TransferDevice d) =>
        d.tone.tones.singleWhere((x) => x.id == 'ToneDots');
    Stamp stampOf(TransferDevice d) =>
        d.stamp.stamps.singleWhere((x) => x.id == 'StampStar');
    b.brush.updateBrush(brushOf(b).copyWith(spacing: 66));
    final bDots = File('${bDocs.path}/dots-b.png')
      ..writeAsBytesSync([40, 50, 60]);
    b.tone.updateTone(toneOf(b).copyWith(texturePath: bDots.path));
    b.stamp.updateStamp(stampOf(b).copyWith(density: 0.25));
    await settleTransfer();
    var fromB = await b.export();
    var savedB = await _snapshot();

    a = await _resume(savedA);
    a.brush.updateBrush(brushOf(a).copyWith(spacing: 33));
    final aDots = File('${aDocs.path}/dots-a.png')
      ..writeAsBytesSync([41, 51, 61]);
    a.tone.updateTone(toneOf(a).copyWith(texturePath: aDots.path));
    a.stamp.updateStamp(stampOf(a).copyWith(density: 0.75));
    await settleTransfer();
    await a.import(fromB, aDocs);
    final expectedA = _items(a);
    var fromA = await a.export();
    savedA = await _snapshot();

    final p = _Problems();
    p.check(expectedA, [
      'brush Ink (コピー)|66|1,2,3',
      'brush Ink|33|1,2,3',
      'stamp Star (コピー)|0.25|7,8,9',
      'stamp Star|0.75|7,8,9',
      'tone Dots (コピー)|40,50,60',
      'tone Dots|41,51,61',
    ], 'A: もう1台の版を1つずつ足す');

    b = await _resume(savedB);
    final report = TransferImportReport();
    final unusedB = await _unusedAfter(
      b,
      bDocs,
      () => b.import(fromA, bDocs, report: report),
    );
    final expectedB = _items(b);
    p.check(expectedB, [
      'brush Ink (コピー)|33|1,2,3',
      'brush Ink|66|1,2,3',
      'stamp Star (コピー)|0.75|7,8,9',
      'stamp Star|0.25|7,8,9',
      'tone Dots (コピー)|41,51,61',
      'tone Dots|40,50,60',
    ], 'B: もう1台の版を1つずつ足し、もう1台へ渡った自分の版は足さない');
    p.check(report.addedCopies..sort(), [
      'Dots (コピー)',
      'Ink (コピー)',
      'Star (コピー)',
    ], 'B: 知らせるのはもう1台の版の複製だけ');
    p.check(unusedB, isEmpty, 'B: 足さなかった項目の画像を残さない');
    fromB = await b.export();
    savedB = await _snapshot();

    for (var round = 1; round <= 2; round++) {
      a = await _resume(savedA);
      final aReport = TransferImportReport();
      final unusedA = await _unusedAfter(
        a,
        aDocs,
        () => a.import(fromB, aDocs, report: aReport),
      );
      p.check(_items(a), expectedA, 'round $round A: 変わらない');
      p.check(aReport.addedCopies, isEmpty, 'round $round A: 複製を足さない');
      p.check(unusedA, isEmpty, 'round $round A: 使わない画像を残さない');
      fromA = await a.export();
      savedA = await _snapshot();

      b = await _resume(savedB);
      final bReport = TransferImportReport();
      final unused = await _unusedAfter(
        b,
        bDocs,
        () => b.import(fromA, bDocs, report: bReport),
      );
      p.check(_items(b), expectedB, 'round $round B: 変わらない');
      p.check(bReport.addedCopies, isEmpty, 'round $round B: 複製を足さない');
      p.check(unused, isEmpty, 'round $round B: 使わない画像を残さない');
      fromB = await b.export();
      savedB = await _snapshot();
    }
    b = await _resume(savedB);
    p.check(_items(b), expectedB, 'B: 起動し直しても');
    p.verify();
  });

  test('an item not added because this device already has it under another '
      'id gives that item its favourite, tags and folder', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.brush.addBrush(customTransferBrush('BrushPen', 'Pen', null));
    b.tone.addTone(const Tone(id: 'ToneGrid', name: 'Grid'));
    b.stamp.addStamp(const Stamp(id: 'StampLeaf', name: 'Leaf', density: 0.5));
    await settleTransfer();
    final fromB = await b.export();
    final savedB = await _snapshot();

    // もう1台は受け取った項目を複製して整理し、元を消した。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.import(fromB, Directory('${temp.path}/A')..createSync());
    final penCopy = a.brush.duplicateBrush('BrushPen', name: 'Pen (コピー)')!;
    a.brush.deleteBrush('BrushPen');
    final brushFolder = await a.brush.createFolder('Inks');
    a.brush.moveToFolder(penCopy, brushFolder.id);
    a.brush.setTags(penCopy, ['ink']);
    a.brush.toggleFavoriteBrush(penCopy);
    a.tone.addTone(const Tone(id: 'ToneGrid2', name: 'Grid (コピー)'));
    a.tone.deleteTone('ToneGrid');
    final toneFolder = await a.tone.createFolder('Grids');
    a.tone.moveToFolder('ToneGrid2', toneFolder.id);
    a.tone.setTags('ToneGrid2', ['grid']);
    a.tone.toggleFavorite('ToneGrid2');
    a.stamp.addStamp(
      const Stamp(id: 'StampLeaf2', name: 'Leaf (コピー)', density: 0.5),
    );
    a.stamp.deleteStamp('StampLeaf');
    final stampFolder = await a.stamp.createFolder('Leaves');
    a.stamp.moveToFolder('StampLeaf2', stampFolder.id);
    a.stamp.setTags('StampLeaf2', ['leaf']);
    a.stamp.toggleFavorite('StampLeaf2');
    await settleTransfer();
    final fromA = await a.export();

    var device = await _resume(savedB);
    final bDocs = Directory('${temp.path}/B')..createSync();
    await device.import(fromA, bDocs);
    final p = _Problems();
    for (final stage in ['after import', 'read again', 'restart']) {
      if (stage == 'read again') await device.import(fromA, bDocs);
      if (stage == 'restart') device = await _resume(await _snapshot());
      String? folderName(String? id, List<({String id, String name})> all) =>
          all.where((f) => f.id == id).firstOrNull?.name;
      final pen = device.brush.brushes.where(
        (x) => !device.brush.isBuiltIn(x.id),
      );
      p.check(pen.map((x) => x.id), ['BrushPen'], '$stage: ブラシは足さない');
      p.check(pen.map((x) => x.isFavorite), [true], '$stage: ブラシのお気に入り');
      p.check(pen.map((x) => x.tags), [
        ['ink'],
      ], '$stage: ブラシのタグ');
      p.check(
        pen.map(
          (x) => folderName(x.folderId, [
            for (final f in device.brush.folders) (id: f.id, name: f.name),
          ]),
        ),
        ['Inks'],
        '$stage: ブラシのフォルダ',
      );
      final tones = device.tone.tones.where(
        (x) => !device.tone.isBuiltIn(x.id),
      );
      p.check(tones.map((x) => x.id), ['ToneGrid'], '$stage: トーンは足さない');
      p.check(
        tones.map(
          (x) =>
              '${x.isFavorite}|${x.tags.join(',')}|'
              '${folderName(x.folderId, [for (final f in device.tone.folders) (id: f.id, name: f.name)])}',
        ),
        ['true|grid|Grids'],
        '$stage: トーンのお気に入り・タグ・フォルダ',
      );
      final stamps = device.stamp.stamps.where(
        (x) => !device.stamp.isBuiltIn(x.id),
      );
      p.check(stamps.map((x) => x.id), ['StampLeaf'], '$stage: スタンプは足さない');
      p.check(
        stamps.map(
          (x) =>
              '${x.isFavorite}|${x.tags.join(',')}|'
              '${folderName(x.folderId, [for (final f in device.stamp.folders) (id: f.id, name: f.name)])}',
        ),
        ['true|leaf|Leaves'],
        '$stage: スタンプのお気に入り・タグ・フォルダ',
      );
    }
    p.verify();
  });
  test('a copy added earlier for the other device\'s version gets the '
      'favourite, tags and folder the other device gives that item later, '
      'and this device\'s own version keeps its own', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushPen', 'Pen', null));
    a.stamp.addStamp(const Stamp(id: 'StampLeaf', name: 'Leaf'));
    await settleTransfer();
    final first = await a.export();
    var savedA = await _snapshot();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    final bDocs = Directory('${temp.path}/B')..createSync();
    await b.import(first, bDocs);
    b.brush.updateBrush(
      b.brush.brushes
          .singleWhere((x) => x.id == 'BrushPen')
          .copyWith(spacing: 66),
    );
    b.stamp.updateStamp(
      b.stamp.stamps
          .singleWhere((x) => x.id == 'StampLeaf')
          .copyWith(density: 0.25),
    );
    await settleTransfer();
    final savedB = await _snapshot();

    a = await _resume(savedA);
    a.brush.updateBrush(
      a.brush.brushes
          .singleWhere((x) => x.id == 'BrushPen')
          .copyWith(spacing: 33),
    );
    a.stamp.updateStamp(
      a.stamp.stamps
          .singleWhere((x) => x.id == 'StampLeaf')
          .copyWith(density: 0.75),
    );
    await settleTransfer();
    final second = await a.export();
    // 後でもう1台がその項目を整理する。
    final brushFolder = await a.brush.createFolder('Inks');
    a.brush.moveToFolder('BrushPen', brushFolder.id);
    a.brush.setTags('BrushPen', ['ink']);
    a.brush.toggleFavoriteBrush('BrushPen');
    final stampFolder = await a.stamp.createFolder('Leaves');
    a.stamp.moveToFolder('StampLeaf', stampFolder.id);
    a.stamp.setTags('StampLeaf', ['leaf']);
    a.stamp.toggleFavorite('StampLeaf');
    await settleTransfer();
    final third = await a.export();
    savedA = await _snapshot();

    b = await _resume(savedB);
    await b.import(second, bDocs);
    await b.import(third, bDocs);
    final p = _Problems();
    for (final stage in ['after import', 'restart']) {
      if (stage == 'restart') b = await _resume(await _snapshot());
      String brushFolderOf(String? id) =>
          b.brush.folders.where((f) => f.id == id).firstOrNull?.name ?? '-';
      String stampFolderOf(String? id) =>
          b.stamp.folders.where((f) => f.id == id).firstOrNull?.name ?? '-';
      p.check(
        [
          for (final x in b.brush.brushes)
            if (!b.brush.isBuiltIn(x.id))
              '${x.name}|${x.spacing}|${x.isFavorite}|${x.tags.join(',')}|'
                  '${brushFolderOf(x.folderId)}',
        ]..sort(),
        ['Pen (コピー)|33|true|ink|Inks', 'Pen|66|false||-'],
        '$stage: ブラシ',
      );
      p.check(
        [
          for (final x in b.stamp.stamps)
            if (!b.stamp.isBuiltIn(x.id))
              '${x.name}|${x.density}|${x.isFavorite}|${x.tags.join(',')}|'
                  '${stampFolderOf(x.folderId)}',
        ]..sort(),
        ['Leaf (コピー)|0.75|true|leaf|Leaves', 'Leaf|0.25|false||-'],
        '$stage: スタンプ',
      );
    }
    p.verify();
  });
}
