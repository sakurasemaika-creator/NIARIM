import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）を、同じIDの項目を既に持つ端末へ読み込んだとき、
/// この端末で変えた内容を黙って失わないこと（同じIDで中身が違えば、この
/// 端末の項目を残して受け取った項目を「名前 (コピー)」として足す）。
/// 組み込み・最初のパレット・見本の設定は、この端末で出荷時のままなら
/// 受け取った内容にする。どれも同じファイルを読み直しても増えず、使っている
/// 画像のファイルを書き換えない。古い形式のファイル（フォルダ・最近使った色が
/// 端末保存データの中にしか無い）も取り込み、読めない保存のフォルダを残す。

/// 一覧の数（読み直しで増えないことを見る）。
Map<String, int> _counts(TransferDevice d) => {
  'brushes': d.brush.brushes.length,
  'brushFolders': d.brush.folders.length,
  'tones': d.tone.tones.length,
  'toneFolders': d.tone.folders.length,
  'stamps': d.stamp.stamps.length,
  'autofill': d.autofill.presets.length,
  'themes': d.theme.presets.length,
  'palettes': d.palette.palettes.length,
  'pixel': d.pixelArt.palettes.length,
};

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

Future<Map<String, Object>> _savedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_transfer_conflict_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a device that changed the shared items keeps its changes, and gets '
      'the other device\'s own changes as copies, once', () async {
    // 元の端末A：最初のパレットに青、組み込みのペンの太さ22・エアブラシの
    // 太さ55を覚えた。他は出荷時のまま。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.palette.addColorToPalette('default', 0xFF0000FF);
    a.brush.selectBrush('Brush0001');
    a.brush.updateCurrentBrushSize(22);
    a.brush.selectBrush('Brush0003');
    a.brush.updateCurrentBrushSize(55);
    await a.brush.commitRememberedValues();
    final aFolder = await a.brush.createFolder('A folder');
    a.brush.moveToFolder('Brush0002', aFolder.id);
    a.brush.moveToFolder('Brush0005', aFolder.id);
    a.tone.setTags('Tone0002', ['a-tag']);
    await settleTransfer();
    final bytes = await a.export();

    // この端末B：最初のパレットに赤、見本「主人公」へパーツを足し（作品の
    // レイヤーがそのIDを指す）、組み込みのテーマを編集し、組み込みブラシを
    // お気に入りにしてエアブラシの太さ77を覚え、組み込みトーンをお気に入り。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.palette.addColorToPalette('default', 0xFFFF0000);
    final p1 = b.autofill.presets.singleWhere((p) => p.id == 'p1');
    await b.autofill.updatePreset(
      p1.copyWith(
        parts: [
          ...p1.parts,
          const AutofillPart(id: 'part_b_only', name: 'B', color: 0xFF00FF00),
        ],
      ),
    );
    b.theme.applyPreset('orange_light');
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF123456)),
    );
    b.theme.commitCurrent();
    b.brush.toggleFavoriteBrush('Brush0005');
    b.brush.selectBrush('Brush0003');
    b.brush.updateCurrentBrushSize(77);
    await b.brush.commitRememberedValues();
    b.tone.toggleFavorite('Tone0001');
    b.tone.setTags('Tone0001', ['b-tag']);
    b.tone.setTags('Tone0002', ['b-tag']);
    final bFolder = await b.brush.createFolder('B folder');
    b.brush.moveToFolder('Brush0002', bFolder.id);
    await settleTransfer();
    final before = _counts(b);

    final p = _Problems();
    void checkKept(TransferDevice d, String when) {
      final palettes = d.palette.palettes;
      p.check(palettes.where((x) => x.id == 'default').map((x) => x.colors), [
        [0xFFFF0000],
      ], '$when: この端末の最初のパレット（赤）のまま');
      p.check(
        palettes.where((x) => x.name == 'マイパレット (コピー)').map((x) => x.colors),
        [
          [0xFF0000FF],
        ],
        '$when: 元の端末の最初のパレット（青）は複製として1つ',
      );
      p.check(
        d.autofill.findPart('part_b_only')?.name,
        'B',
        '$when: 作品が指すパーツが残る',
      );
      p.check(
        d.theme.presets
            .where((t) => t.id == 'orange_light')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF123456],
        '$when: この端末で編集した組み込みのテーマのまま',
      );
      p.check(
        d.brush.brushes
            .where((x) => x.id == 'Brush0005')
            .map((x) => x.isFavorite),
        [true],
        '$when: この端末のお気に入り',
      );
      p.check(
        d.brush.brushes.where((x) => x.id == 'Brush0003').map((x) => x.size),
        [77],
        '$when: この端末で覚えた太さを残す',
      );
      p.check(
        d.brush.brushes.where((x) => x.id == 'Brush0001').map((x) => x.size),
        [22],
        '$when: この端末で覚えていない太さは受け取る',
      );
      p.check(
        d.tone.tones.where((x) => x.id == 'Tone0001').map((x) => x.isFavorite),
        [true],
        '$when: 組み込みトーンのお気に入り',
      );
      p.check(
        d.tone.tones.where((x) => x.id == 'Tone0001').map((x) => x.tags),
        [
          ['b-tag'],
        ],
        '$when: この端末のタグを残す（受け取ったのは出荷時のタグ）',
      );
      p.check(
        d.tone.tones.where((x) => x.id == 'Tone0002').map((x) => x.tags),
        [
          ['b-tag', 'a-tag'],
        ],
        '$when: 両方で付けたタグは両方',
      );
      p.check(
        d.brush.brushes
            .where((x) => x.id == 'Brush0002')
            .map((x) => x.folderId),
        [bFolder.id],
        '$when: この端末で入れたフォルダのまま',
      );
      p.check(
        d.brush.brushes
            .where((x) => x.id == 'Brush0005')
            .map(
              (x) => d.brush.folders
                  .where((f) => f.id == x.folderId)
                  .map((f) => f.name)
                  .join(),
            ),
        ['A folder'],
        '$when: この端末でフォルダに入れていなければ受け取ったフォルダ',
      );
      // 足すのは元の端末の自分の内容（最初のパレット・フォルダ）だけ。
      p.check(_counts(d), {
        ...before,
        'palettes': before['palettes']! + 1,
        'brushFolders': before['brushFolders']! + 1,
      }, '$when: 出荷時のままの項目の複製は足さない');
    }

    final docs = Directory('${temp.path}/b')..createSync();
    await b.import(bytes, docs);
    checkKept(b, 'after import');
    checkKept(await TransferDevice.start(), 'restart after import');
    final saved = await _savedPrefs();
    await b.import(bytes, docs);
    checkKept(b, 'after importing again');
    p.check(await _savedPrefs(), saved, '2回目の読み込みは保存を何も変えない');
    checkKept(await TransferDevice.start(), 'restart after importing again');
    p.verify();
  });

  test('a device that kept the shared items as shipped takes the other '
      'device\'s changes in place, but never drops a part', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.palette.addColorToPalette('default', 0xFF0000FF);
    final p1 = a.autofill.presets.singleWhere((p) => p.id == 'p1');
    await a.autofill.updatePreset(
      p1.copyWith(
        parts: [
          ...p1.parts,
          const AutofillPart(id: 'part_a_only', name: 'A', color: 0xFF00FF00),
        ],
      ),
    );
    // 見本「ヒロイン」から、この端末の作品が指しうるパーツを1つ外した。
    final p2 = a.autofill.presets.singleWhere((p) => p.id == 'p2');
    await a.autofill.updatePreset(
      p2.copyWith(parts: p2.parts.where((x) => x.id != 'p2_hair_s2').toList()),
    );
    a.theme.applyPreset('orange_light');
    a.theme.previewCurrent(
      a.theme.current.copyWith(accentColor: const Color(0xFF654321)),
    );
    a.theme.commitCurrent();
    a.brush.toggleFavoriteBrush('Brush0005');
    a.brush.selectBrush('Brush0003');
    a.brush.updateCurrentBrushSize(55);
    await a.brush.commitRememberedValues();
    a.tone.setTags('Tone0001', ['mine']);
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final before = _counts(b);

    final p = _Problems();
    void checkTaken(TransferDevice d, String when) {
      p.check(
        d.palette.palettes.where((x) => x.id == 'default').map((x) => x.colors),
        [
          [0xFF0000FF],
        ],
        '$when: 空のままだった最初のパレットは受け取った内容',
      );
      p.check(
        d.autofill.findPart('part_a_only')?.name,
        'A',
        '$when: 見本のままだった「主人公」は受け取った内容',
      );
      p.check(
        d.autofill.presets
            .where((x) => x.id == 'p2')
            .map((x) => x.parts.any((part) => part.id == 'p2_hair_s2')),
        [true],
        '$when: パーツが無くなる置き換えはしない',
      );
      p.check(
        d.autofill.presets.where((x) => x.name == 'ヒロイン (コピー)').length,
        1,
        '$when: 外した方は複製として1つ',
      );
      p.check(
        d.theme.presets
            .where((t) => t.id == 'orange_light')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF654321],
        '$when: 元の配色のままだった組み込みのテーマは受け取った配色',
      );
      p.check(d.theme.isEditingPreset, isTrue, '$when: 編集中のテーマのまま');
      p.check(d.theme.current.id, 'orange_light', '$when: 今のテーマ');
      p.check(
        d.brush.brushes
            .where((x) => x.id == 'Brush0005')
            .map((x) => x.isFavorite),
        [true],
        '$when: お気に入り',
      );
      p.check(
        d.brush.brushes.where((x) => x.id == 'Brush0003').map((x) => x.size),
        [55],
        '$when: 覚えた太さ',
      );
      p.check(
        d.tone.tones.where((x) => x.id == 'Tone0001').map((x) => x.tags),
        [
          ['mine'],
        ],
        '$when: 出荷時のままだった組み込みトーンのタグは受け取ったタグ',
      );
      p.check(_counts(d), {
        ...before,
        'autofill': before['autofill']! + 1,
      }, '$when: 置き換えた項目の複製は足さない');
    }

    final docs = Directory('${temp.path}/b')..createSync();
    await b.import(bytes, docs);
    checkTaken(b, 'after import');
    checkTaken(await TransferDevice.start(), 'restart after import');
    await b.import(bytes, docs);
    checkTaken(b, 'after importing again');
    checkTaken(await TransferDevice.start(), 'restart after importing again');
    p.verify();
  });

  test('a custom item changed here after an earlier transfer stays, and the '
      'other version comes in as a copy once', () async {
    // Bが自作のブラシ・テーマ・パレットを作ってAへ引き継ぐ。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b0 = await TransferDevice.start();
    final img = File('${temp.path}/x.png')..writeAsBytesSync([1, 1, 1]);
    b0.brush.addBrush(customTransferBrush('BrushX', 'X v1', img.path));
    b0.theme.savePreset(
      b0.theme.current.copyWith(id: 'theme_x', name: 'Theme X'),
    );
    await b0.palette.createPalette('Pal X');
    final palX = b0.palette.activePalette!.id;
    await b0.pixelArt.addPalette('Pix X', [0xFF000000]);
    final pixX = b0.pixelArt.palettes.single.id;
    await b0.autofill.addPreset(
      const AutofillPreset(
        id: 'p_x',
        name: 'Preset X',
        parts: [AutofillPart(id: 'part_x', name: 'x', color: 0xFF111111)],
      ),
    );
    await settleTransfer();
    final fromB = await b0.export();
    final bPrefs = await _savedPrefs();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.import(fromB, Directory('${temp.path}/a')..createSync());
    final fromA = await a.export();

    // Bに戻って自作の項目を変えてから、Aのファイルを読む。
    SharedPreferences.setMockInitialValues(bPrefs);
    final b = await TransferDevice.start();
    final x = b.brush.brushes.singleWhere((e) => e.id == 'BrushX');
    b.brush.updateBrush(x.copyWith(name: 'X v2', size: 40));
    b.theme.savePreset(
      b.theme.presets
          .singleWhere((t) => t.id == 'theme_x')
          .copyWith(accentColor: const Color(0xFF00AA00)),
    );
    await b.palette.addColorToPalette(palX, 0xFF222222);
    await b.pixelArt.updatePalette(pixX, colors: [0xFF333333]);
    final px = b.autofill.presets.singleWhere((e) => e.id == 'p_x');
    await b.autofill.updatePreset(
      px.copyWith(parts: [px.parts.single.copyWith(color: 0xFF444444)]),
    );
    await settleTransfer();
    final before = _counts(b);

    final p = _Problems();
    void checkBoth(TransferDevice d, String when) {
      p.check(
        d.brush.brushes
            .where((e) => e.id == 'BrushX')
            .map((e) => '${e.name}/${e.size}'),
        ['X v2/40.0'],
        '$when: この端末で変えたブラシのまま',
      );
      p.check(
        d.brush.brushes.where((e) => e.name == 'X v1 (コピー)').map((e) => e.size),
        [17],
        '$when: 受け取ったブラシは複製として1つ',
      );
      p.check(
        d.theme.presets
            .where((t) => t.id == 'theme_x')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF00AA00],
        '$when: テーマ',
      );
      p.check(
        d.theme.presets.where((t) => t.name == 'Theme X (コピー)').length,
        1,
        '$when: テーマの複製',
      );
      p.check(
        d.palette.palettes.where((e) => e.id == palX).map((e) => e.colors),
        [
          [0xFF222222],
        ],
        '$when: パレット',
      );
      p.check(
        d.palette.palettes.where((e) => e.name == 'Pal X (コピー)').length,
        1,
        '$when: パレットの複製',
      );
      p.check(
        d.pixelArt.palettes.where((e) => e.id == pixX).map((e) => e.colors),
        [
          [0xFF333333],
        ],
        '$when: ドット絵パレット',
      );
      p.check(
        d.pixelArt.palettes.where((e) => e.name == 'Pix X (コピー)').length,
        1,
        '$when: ドット絵パレットの複製',
      );
      p.check(
        d.autofill.findPart('part_x')?.color,
        0xFF444444,
        '$when: 作品が指すパーツはこの端末のまま',
      );
      p.check(
        d.autofill.presets.where((e) => e.name == 'Preset X (コピー)').length,
        1,
        '$when: 自動塗り設定の複製',
      );
      p.check(_counts(d), {
        ...before,
        'brushes': before['brushes']! + 1,
        'themes': before['themes']! + 1,
        'palettes': before['palettes']! + 1,
        'pixel': before['pixel']! + 1,
        'autofill': before['autofill']! + 1,
      }, '$when: 足すのは違った項目の複製だけ');
    }

    final docs = Directory('${temp.path}/b')..createSync();
    await b.import(fromA, docs);
    checkBoth(b, 'after import');
    await b.import(fromA, docs);
    checkBoth(b, 'after importing again');
    checkBoth(await TransferDevice.start(), 'restart');
    p.verify();
  });

  test('an image in use here is never rewritten, and reading the file again '
      'writes no new image', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final aTone = File('${temp.path}/a_tone.png')..writeAsBytesSync([9, 9]);
    a.tone.addTone(
      Tone(id: 'ToneShared', name: 'Shared', texturePath: aTone.path),
    );
    final aStamp = File('${temp.path}/a_stamp.png')..writeAsBytesSync([8, 8]);
    a.stamp.addStamp(
      Stamp(id: 'StampShared', name: 'Shared', imagePath: aStamp.path),
    );
    final aBrush = File('${temp.path}/a_brush.png')..writeAsBytesSync([7, 7]);
    a.brush.addBrush(customTransferBrush('BrushShared', 'Shared', aBrush.path));
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final docs = Directory('${temp.path}/b')..createSync();
    // この端末の同じIDの項目は、アプリの画像フォルダにある別の画像を使う。
    File inUse(String folder, String name, List<int> bytes) =>
        File('${docs.path}/niarim/$folder/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
    final bTone = inUse('Tones', 'ToneShared.png', [5, 5]);
    b.tone.addTone(
      Tone(id: 'ToneShared', name: 'Shared', texturePath: bTone.path),
    );
    final bStamp = inUse('Stamps', 'StampShared.png', [4, 4]);
    b.stamp.addStamp(
      Stamp(id: 'StampShared', name: 'Shared', imagePath: bStamp.path),
    );
    final bBrush = inUse('Brushes', 'BrushShared_000.png', [3, 3]);
    b.brush.addBrush(customTransferBrush('BrushShared', 'Shared', bBrush.path));
    await settleTransfer();

    final p = _Problems();
    List<String> files(String folder) => [
      for (final f in Directory('${docs.path}/niarim/$folder').listSync())
        f.path,
    ]..sort();
    void checkImages(TransferDevice d, String when) {
      for (final (file, bytes) in [
        (bTone, [5, 5]),
        (bStamp, [4, 4]),
        (bBrush, [3, 3]),
      ]) {
        p.check(file.readAsBytesSync(), bytes, '$when: ${file.path}の中身');
      }
      p.check(
        d.tone.tones
            .where((e) => e.id == 'ToneShared')
            .map((e) => e.texturePath),
        [bTone.path],
        '$when: この端末のトーンの画像',
      );
      p.check(
        d.stamp.stamps
            .where((e) => e.id == 'StampShared')
            .map((e) => e.imagePath),
        [bStamp.path],
        '$when: この端末のスタンプの画像',
      );
      p.check(
        d.brush.brushes
            .where((e) => e.id == 'BrushShared')
            .map((e) => e.customImagePath),
        [bBrush.path],
        '$when: この端末のブラシの画像',
      );
      final toneCopy = d.tone.tones
          .where((e) => e.name == 'Shared (コピー)')
          .toList();
      p.check(toneCopy.length, 1, '$when: 受け取ったトーンは複製として1つ');
      if (toneCopy.length == 1) {
        p.check(File(toneCopy.single.texturePath!).readAsBytesSync(), [
          9,
          9,
        ], '$when: 複製のトーンの画像');
      }
      p.check(
        d.stamp.stamps.where((e) => e.name == 'Shared (コピー)').length,
        1,
        '$when: スタンプの複製',
      );
      p.check(
        d.brush.brushes.where((e) => e.name == 'Shared (コピー)').length,
        1,
        '$when: ブラシの複製',
      );
    }

    await b.import(bytes, docs);
    checkImages(b, 'after import');
    final written = {
      for (final folder in ['Tones', 'Stamps', 'Brushes'])
        folder: files(folder),
    };
    p.check(written.values.map((f) => f.length), [2, 2, 2], '使っている画像と複製の画像だけ');
    await b.import(bytes, docs);
    checkImages(b, 'after importing again');
    p.check(
      {
        for (final folder in ['Tones', 'Stamps', 'Brushes'])
          folder: files(folder),
      },
      written,
      '読み直しで画像のファイルを増やさない',
    );
    checkImages(await TransferDevice.start(), 'restart');
    p.verify();
  });

  test('an image that did not come with the file keeps the working image '
      'here, in both file formats', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final aTone = File('${temp.path}/a_tone.png')..writeAsBytesSync([5, 5]);
    a.tone.addTone(
      Tone(id: 'ToneShared', name: 'Shared', texturePath: aTone.path),
    );
    final aStamp = File('${temp.path}/a_stamp.png')..writeAsBytesSync([4, 4]);
    a.stamp.addStamp(
      Stamp(id: 'StampShared', name: 'Shared', imagePath: aStamp.path),
    );
    final aBrush = File('${temp.path}/a_brush.png')..writeAsBytesSync([6, 6]);
    a.brush.addBrush(
      customTransferBrush('BrushShared', 'SharedBrush', aBrush.path),
    );
    await settleTransfer();
    // 元の端末で画像が消えていた（書き出しに入らない）。
    aTone.deleteSync();
    aStamp.deleteSync();
    aBrush.deleteSync();
    final withImages = await a.export();
    final withoutImages = await a.export(bundleImages: false);

    final p = _Problems();
    for (final (format, bytes) in [
      ('bundled', withImages),
      ('old', withoutImages),
    ]) {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final b = await TransferDevice.start();
      final bTone = File('${temp.path}/b_tone.png')..writeAsBytesSync([5, 5]);
      b.tone.addTone(
        Tone(id: 'ToneShared', name: 'Shared', texturePath: bTone.path),
      );
      final bStamp = File('${temp.path}/b_stamp.png')..writeAsBytesSync([4, 4]);
      b.stamp.addStamp(
        Stamp(id: 'StampShared', name: 'Shared', imagePath: bStamp.path),
      );
      final bBrush = File('${temp.path}/b_brush.png')..writeAsBytesSync([6, 6]);
      b.brush.addBrush(
        customTransferBrush('BrushShared', 'SharedBrush', bBrush.path),
      );
      await settleTransfer();
      final before = _counts(b);
      await b.import(bytes, Directory('${temp.path}/$format')..createSync());
      for (final (stage, d) in [
        ('$format: after import', b),
        ('$format: restart', await TransferDevice.start()),
      ]) {
        p.check(
          d.tone.tones
              .where((e) => e.name == 'Shared')
              .map((e) => e.texturePath),
          [bTone.path],
          '$stage: トーンはこの端末の画像のまま',
        );
        p.check(
          d.stamp.stamps
              .where((e) => e.name == 'Shared')
              .map((e) => e.imagePath),
          [bStamp.path],
          '$stage: スタンプ',
        );
        p.check(
          d.brush.brushes
              .where((e) => e.name == 'SharedBrush')
              .map((e) => e.customImagePath),
          [bBrush.path],
          '$stage: ブラシ',
        );
        p.check(_counts(d), before, '$stage: 複製を足さない');
      }
      for (final f in [bTone, bStamp, bBrush]) {
        f.deleteSync();
      }
    }
    p.verify();
  });

  test('built-in tones and stamps take only favourite, tags and folder, even '
      'from a version whose built-ins differ', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final before = _counts(b);
    final toneName = b.tone.tones.singleWhere((t) => t.id == 'Tone0001').name;
    final stampName = b.stamp.stamps
        .singleWhere((s) => s.id == 'Stamp0001')
        .name;
    final image = File('${temp.path}/other.png')..writeAsBytesSync([1]);
    NiatraData file() => NiatraData({
      'tones': [
        {
          ...const Tone(
            id: 'Tone0001',
            name: 'Renamed in another version',
            isFavorite: true,
          ).toJson(),
          'texturePath': image.path,
        },
      ],
      'stamps': [
        {
          ...const Stamp(
            id: 'Stamp0001',
            name: 'Renamed in another version',
            isFavorite: true,
            density: 9,
          ).toJson(),
          'imagePath': image.path,
        },
      ],
    }, Archive());
    final docs = Directory('${temp.path}/b')..createSync();
    await b.importData(file(), docs);
    await b.importData(file(), docs);
    final p = _Problems();
    for (final (stage, d) in [
      ('after import', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(_counts(d), before, '$stage: 組み込みを足さない');
      final tone = d.tone.tones.singleWhere((t) => t.id == 'Tone0001');
      p.check(
        [tone.name, tone.texturePath, tone.isFavorite],
        [toneName, null, true],
        '$stage: 組み込みトーンの中身はこの版のまま、お気に入りだけ',
      );
      final stamp = d.stamp.stamps.singleWhere((s) => s.id == 'Stamp0001');
      p.check(
        [stamp.name, stamp.imagePath, stamp.density, stamp.isFavorite],
        [stampName, null, 1.0, true],
        '$stage: 組み込みスタンプ',
      );
    }
    p.verify();
  });

  test('a file from the previous version (folders, recent colours and the '
      'selected brush and palette only in device data) keeps them', () async {
    final p = _Problems();
    // 前の版の書き出しそのもの（ブラシ・トーンのフォルダ、最近使った色）。
    final real = File(
      'test/fixtures/niatra/previous_version.niatra',
    ).readAsBytesSync();
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final fresh = await TransferDevice.start();
    await fresh.import(real, Directory('${temp.path}/real')..createSync());
    for (final (stage, d) in [
      ('real file', fresh),
      ('real file, restart', await TransferDevice.start()),
    ]) {
      final folder = d.brush.folders
          .where((f) => f.name == 'Old brush folder')
          .firstOrNull;
      p.check(folder, isNotNull, '$stage: ブラシのフォルダ');
      p.check(
        d.brush.brushes
            .where((x) => x.folderId != null && x.folderId == folder?.id)
            .map((x) => x.id)
            .toSet(),
        {'BrushInFolder', 'Brush0002'},
        '$stage: フォルダの中のブラシ',
      );
      final toneFolder = d.tone.folders
          .where((f) => f.name == 'Old tone folder')
          .firstOrNull;
      p.check(toneFolder, isNotNull, '$stage: トーンのフォルダ');
      p.check(
        d.tone.tones.where((x) => x.folderId == toneFolder?.id).length,
        1,
        '$stage: フォルダの中のトーン',
      );
      p.check(d.palette.recentColors, contains(0xFF0A0B0C), '$stage: 最近使った色');
    }

    // 前の版の形を、スタンプのフォルダ・使っていたブラシ・選んでいた
    // パレットまで含めて作る。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final data = NiatraData({
      'creativeAssetsVersion': 1,
      'brushes': [
        {
          ...customTransferBrush('BrushOldF', 'In folder', null).toJson(),
          'folderId': 'BrushFolderOld',
        },
      ],
      'tones': [
        {
          ...const Tone(id: 'ToneOldF', name: 'Tone in folder').toJson(),
          'folderId': 'ToneFolderOld',
        },
      ],
      'stamps': [
        {
          ...const Stamp(id: 'StampOldF', name: 'Stamp in folder').toJson(),
          'folderId': 'StampFolderOld',
        },
      ],
      'palettes': [
        {'id': 'palette_old', 'name': 'Old palette', 'colors': <int>[]},
      ],
      'localPreferences': {
        'brush_folders': [
          jsonEncode({'id': 'BrushFolderOld', 'name': 'Old folder'}),
        ],
        'tone_folders': [
          jsonEncode({'id': 'ToneFolderOld', 'name': 'Old tone folder'}),
        ],
        'stamp_folders': [
          jsonEncode({'id': 'StampFolderOld', 'name': 'Old stamp folder'}),
        ],
        'palette_recent_colors': ['4278190335'],
        'brushes_current_id': 'BrushOldF',
        'color_palette_active_id': 'palette_old',
        'bucket_tolerance': 42.0,
      },
    }, Archive());
    await b.importData(data, Directory('${temp.path}/made')..createSync());
    for (final (stage, d) in [
      ('previous layout', b),
      ('previous layout, restart', await TransferDevice.start()),
    ]) {
      p.check(
        d.brush.brushes
            .where((x) => x.id == 'BrushOldF')
            .map((x) => x.folderId),
        ['BrushFolderOld'],
        '$stage: ブラシのフォルダ',
      );
      p.check(
        d.tone.tones.where((x) => x.id == 'ToneOldF').map((x) => x.folderId),
        ['ToneFolderOld'],
        '$stage: トーンのフォルダ',
      );
      p.check(
        d.stamp.stamps.where((x) => x.id == 'StampOldF').map((x) => x.folderId),
        ['StampFolderOld'],
        '$stage: スタンプのフォルダ',
      );
      p.check(d.palette.recentColors.firstOrNull, 0xFF0000FF, '$stage: 最近使った色');
      p.check(d.brush.currentBrush?.id, 'BrushOldF', '$stage: 使っていたブラシ');
      p.check(d.palette.activePaletteId, 'palette_old', '$stage: 選んでいたパレット');
      p.check(
        (await SharedPreferences.getInstance()).getDouble('bucket_tolerance'),
        42.0,
        '$stage: ほかの端末保存データは今までどおり移す',
      );
    }
    p.verify();
  });

  test('saved folders this version cannot read stay saved', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.tone.createFolder('Folder from A');
    await a.brush.createFolder('Folder from A');
    await a.stamp.createFolder('Folder from A');
    await settleTransfer();
    final withFolders = await a.export();
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    // ブラシ・素材は入っているが、フォルダが1つも無いファイル。
    final noFolders = await (await TransferDevice.start()).export();

    const unreadable = '{"id": "FolderFuture", "name": 7}';
    const keys = ['tone_folders', 'brush_folders', 'stamp_folders'];
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      for (final key in keys) key: ['{"id":"F1","name":"ok"}', unreadable],
    });
    final b = await TransferDevice.start();
    final prefs = await SharedPreferences.getInstance();
    final p = _Problems();
    await b.import(noFolders, Directory('${temp.path}/b1')..createSync());
    for (final key in keys) {
      p.check(prefs.getStringList(key), [
        '{"id":"F1","name":"ok"}',
        unreadable,
      ], 'フォルダを受け取らないとき $key は書き換えない');
    }
    await b.import(withFolders, Directory('${temp.path}/b2')..createSync());
    for (final key in keys) {
      final saved = prefs.getStringList(key) ?? const [];
      p.check(saved, contains(unreadable), '$key: 読めない保存を残す');
      p.check(saved.length, 3, '$key: 受け取ったフォルダを足す');
    }
    final restarted = await TransferDevice.start();
    p.check(restarted.tone.folders.map((f) => f.name), [
      'ok',
      'Folder from A',
    ], '起動し直したトーンのフォルダ');
    p.verify();
  });

  test('when this device edited the theme the other device was editing, this '
      'device keeps its colours and the other colours become a copy that '
      'saving this device\'s theme later does not touch', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.theme.applyPreset('orange_light');
    a.theme.previewCurrent(
      a.theme.current.copyWith(accentColor: const Color(0xFF654321)),
    );
    a.theme.commitCurrent();
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.theme.applyPreset('orange_light');
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF123456)),
    );
    b.theme.commitCurrent();
    await settleTransfer();
    await b.import(bytes, Directory('${temp.path}/b')..createSync());

    final p = _Problems();
    final copy = b.theme.presets
        .where((t) => t.name == 'オレンジ（ライト） (コピー)')
        .toList();
    p.check(copy.length, 1, '元の端末の配色は複製として1つ');
    p.check(copy.map((t) => t.accentColor.toARGB32()), [
      0xFF654321,
    ], '複製は元の端末の色');
    p.check(b.theme.current.id, 'orange_light', '今のテーマはこの端末のまま');
    p.check(b.theme.current.accentColor.toARGB32(), 0xFF123456, '今の色はこの端末の色');
    // この端末のテーマを手直しして保存しても、複製は変わらない。
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF00FF00)),
    );
    b.theme.commitCurrent();
    await settleTransfer();
    for (final (stage, d) in [
      ('after saving', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(
        d.theme.presets
            .where((t) => t.id == 'orange_light')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF00FF00],
        '$stage: この端末で編集したテーマ',
      );
      p.check(
        d.theme.presets
            .where((t) => t.name == 'オレンジ（ライト） (コピー)')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF654321],
        '$stage: 元の端末の色の複製',
      );
    }
    p.verify();
  });

  test('colours the other device had not saved into its theme come as a copy '
      'and do not replace this device\'s own colours', () async {
    // 元の端末は組み込みのテーマを開いて色を変えている途中（テーマには
    // まだ保存していない）で書き出した。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.theme.applyPreset('orange_light');
    a.theme.previewCurrent(
      a.theme.current.copyWith(accentColor: const Color(0xFF654321)),
    );
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.theme.applyPreset('orange_light');
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF123456)),
    );
    b.theme.commitCurrent();
    await settleTransfer();
    final themes = b.theme.presets.length;
    await b.import(bytes, Directory('${temp.path}/b')..createSync());
    await b.import(bytes, Directory('${temp.path}/b2')..createSync());

    final p = _Problems();
    for (final (stage, d) in [
      ('after the import', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(d.theme.presets.length, themes + 1, '$stage: 元の端末の色を1つだけ足す');
      p.check(
        d.theme.presets
            .where((t) => t.accentColor.toARGB32() == 0xFF654321)
            .map((t) => t.name),
        ['オレンジ（ライト） (コピー)'],
        '$stage: 元の端末の色の複製',
      );
      p.check(d.theme.current.id, 'orange_light', '$stage: 今のテーマはこの端末のまま');
      p.check(
        d.theme.current.accentColor.toARGB32(),
        0xFF123456,
        '$stage: 今の色はこの端末の色',
      );
      p.check(
        d.theme.presets
            .where((t) => t.id == 'orange_light')
            .map((t) => t.accentColor.toARGB32()),
        [0xFF123456],
        '$stage: この端末で編集したテーマのまま',
      );
    }
    p.verify();
  });
}
