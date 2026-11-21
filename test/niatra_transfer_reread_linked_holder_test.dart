import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で、もう1台の項目を同じ中身なので足さずに持った
/// この端末の項目（つなげた項目、[TransferCopyRecord.link]）は、その後で
/// この端末が一覧の並びを変えても、キャンバスで太さを変えても、同じファイルを
/// 読み直したときにその項目のまま：同じ中身の別の項目（この端末で作った
/// 複製）へ替わって、どちらの端末でも付けていないお気に入り・タグがそちらに
/// 付くことはなく、保存も書き換えない。

final _ja = lookupAppLocalizations(const Locale('ja'));

/// 今の保存（1台の端末の中身）。
Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

/// [saved]の保存で端末を起動する。
Future<TransferDevice> _resume(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return TransferDevice.start();
}

/// 2つの保存で値の違うキー。
List<String> _changedKeys(Map<String, Object> a, Map<String, Object> b) => [
  for (final key in {...a.keys, ...b.keys})
    if (jsonEncode(a[key]) != jsonEncode(b[key])) key,
]..sort();

/// 自作のブラシ（並び順どおり）。
List<String> _brushes(TransferDevice d) => [
  for (final b in d.brush.brushes)
    if (!d.brush.isBuiltIn(b.id))
      '${b.id}|${b.name}|size ${b.size}|favorite ${b.isFavorite}|tags ${b.tags}',
];

/// 1つの値だけを持つ項目（[size]は、同じIDの項目どうしでは比べない値。
/// ブラシの太さと同じ）。
class _Item {
  const _Item(
    this.id,
    this.name,
    this.content, {
    this.size = 17,
    this.favorite = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String content;
  final int size;
  final bool favorite;
  final List<String> tags;

  _Item resized(int to) =>
      _Item(id, name, content, size: to, favorite: favorite, tags: tags);

  @override
  String toString() =>
      '$id|$name|$content|size $size|favorite $favorite|tags $tags';
}

TransferMergeRules<_Item> _rules(TransferImportReport report) =>
    TransferMergeRules<_Item>(
      idOf: (e) => e.id,
      nameOf: (e) => e.name,
      contentOf: (e) => e.content,
      duplicateContentOf: (e) => [e.content, e.size],
      organizationOf: (e) =>
          (favorite: e.favorite, tags: e.tags, folderId: null),
      withOrganization: (e, o) => _Item(
        e.id,
        e.name,
        e.content,
        size: e.size,
        favorite: o.favorite,
        tags: o.tags,
      ),
      asCopy: (e, id, name) => _Item(
        id,
        name,
        e.content,
        size: e.size,
        favorite: e.favorite,
        tags: e.tags,
      ),
      newId: (attempt) => 'copy_$attempt',
      copyNames: TransferCopyNames(_ja, report: report),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeTransferredItems, an item linked on an earlier read', () {
    /// [local]へ[incoming]を合わせ、[between]でこの端末の一覧を変えてから
    /// もう一度合わせる。2回目が一覧の中身・受け取った項目の中身を持つ項目・
    /// 記録・知らせを変えないことを確かめる。
    void mergeAgainAfter(
      String what,
      List<_Item> local,
      List<_Item> incoming,
      void Function(List<_Item> local) between, {
      required Map<String, String> holders,
    }) {
      final record = TransferCopyRecord.none();
      final firstPlaced = <String, String>{};
      mergeTransferredItems(
        local,
        incoming,
        _rules(TransferImportReport()),
        placed: firstPlaced,
        copies: record,
      );
      expect(firstPlaced, holders, reason: '$what: 1回目に中身を持つ項目');
      between(local);
      final items = {for (final e in local) '$e'};
      String recorded() => jsonEncode({
        for (final e in [...local, ...incoming])
          e.id: [...record.copiesOf(e.id), record.origin(e.id)],
      });
      final recordBefore = recorded();

      final report = TransferImportReport();
      final secondPlaced = <String, String>{};
      final changed = mergeTransferredItems(
        local,
        incoming,
        _rules(report),
        placed: secondPlaced,
        copies: record,
      );
      expect(changed, isFalse, reason: '$what: 2回目は何も変えない');
      expect({for (final e in local) '$e'}, items, reason: '$what: 一覧はそのまま');
      expect(secondPlaced, holders, reason: '$what: 同じ項目が中身を持つ');
      expect(recorded(), recordBefore, reason: '$what: 記録を書き足さない');
      expect(report.addedCopies, isEmpty, reason: '$what: 何も知らせない');
    }

    void moveLastToFront(List<_Item> local) =>
        local.insert(0, local.removeLast());

    void resize(List<_Item> local, String id) {
      final index = local.indexWhere((e) => e.id == id);
      local[index] = local[index].resized(25);
    }

    test('the item of this device that held an item this device does not '
        'have stays its holder after this device moves its own duplicate '
        'above it', () {
      mergeAgainAfter(
        'reordered',
        [
          const _Item('mine', 'Ink', 'ink'),
          const _Item('dup', 'Ink (コピー)', 'ink'),
        ],
        const [
          _Item('x', 'Ink', 'ink', favorite: true, tags: ['line']),
        ],
        moveLastToFront,
        holders: {'x': 'mine'},
      );
    });

    test('the item of this device that held an item this device does not '
        'have stays its holder after this device changes its size (a value '
        'that is not compared between the same item)', () {
      mergeAgainAfter(
        'resized here',
        [
          const _Item('mine', 'Ink', 'ink'),
          const _Item('dup', 'Ink (コピー)', 'ink'),
        ],
        const [
          _Item('x', 'Ink', 'ink', favorite: true, tags: ['line']),
        ],
        (local) => resize(local, 'mine'),
        holders: {'x': 'mine'},
      );
    });

    test('the item of this device that held an item this device does not '
        'have still holds it, and nothing is added, after the other device '
        'changes the size of its item', () {
      final local = [
        const _Item('mine', 'Ink', 'ink'),
        const _Item('dup', 'Ink (コピー)', 'ink'),
      ];
      final record = TransferCopyRecord.none();
      mergeTransferredItems(
        local,
        const [_Item('x', 'Ink', 'ink', favorite: true)],
        _rules(TransferImportReport()),
        copies: record,
      );
      final items = [for (final e in local) '$e'];
      final report = TransferImportReport();
      final placed = <String, String>{};
      final changed = mergeTransferredItems(
        local,
        const [_Item('x', 'Ink', 'ink', size: 25, favorite: true)],
        _rules(report),
        placed: placed,
        copies: record,
      );
      expect(changed, isFalse);
      expect([for (final e in local) '$e'], items, reason: 'この端末の太さのまま');
      expect(placed, {'x': 'mine'});
      expect(report.addedCopies, isEmpty);
    });

    test('the item of this device that held the other device\'s version of '
        'an item with the same ID stays its holder after this device moves '
        'its own duplicate above it or changes its size', () {
      for (final resized in [false, true]) {
        mergeAgainAfter(
          resized ? 'same ID, resized here' : 'same ID, reordered',
          [
            const _Item('x', 'Ink', 'own'),
            const _Item('mine', 'Ink', 'ink'),
            const _Item('dup', 'Ink (コピー)', 'ink'),
          ],
          const [
            _Item('x', 'Ink', 'ink', favorite: true, tags: ['line']),
          ],
          (local) {
            if (resized) {
              resize(local, 'mine');
            } else {
              local.insert(1, local.removeLast());
            }
          },
          holders: {'x': 'mine'},
        );
      }
    });
  });

  group('reading the same .niatra again', () {
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    late Directory temp;
    var imports = 0;
    Directory nextDir() =>
        Directory('${temp.path}/import${imports++}')..createSync();

    setUp(() {
      temp = Directory.systemTemp.createTempSync('niatra_linked_holder_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, (_) async => temp.path);
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null);
      await settleTransfer();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    /// A：お気に入りでタグ「line」の自作ブラシ「Ink」。B：同じ中身の自分の
    /// 「Ink」と、ブラシの一覧で作ったその複製。BはAのファイルを読み、Aの
    /// 「Ink」はBの「Ink」が持つ（足さない）。読み直しても何も変わらない。
    /// Aのファイルと、読んだ後のBの保存・複製のIDを返す。
    Future<
      ({
        Uint8List file,
        Map<String, Object> saved,
        String dup,
        Map<String, Object> savedA,
      })
    >
    readOnce() async {
      final a = await _resume({'language': 'ja'});
      a.brush.addBrush(customTransferBrush('A_ink', 'Ink', null));
      a.brush.toggleFavoriteBrush('A_ink');
      a.brush.setTags('A_ink', ['line']);
      await settleTransfer();
      final file = await a.export();
      final savedA = await _snapshot();

      var b = await _resume({'language': 'ja'});
      b.brush.addBrush(customTransferBrush('B_ink', 'Ink', null));
      final dup = b.brush.duplicateBrush(
        'B_ink',
        name: numberedCopyName(_ja, 'Ink', {
          for (final x in b.brush.brushes) x.name,
        }),
      )!;
      await settleTransfer();
      await b.import(file, nextDir());
      expect(_brushes(b), [
        'B_ink|Ink|size 17.0|favorite true|tags [line]',
        '$dup|Ink (コピー)|size 17.0|favorite false|tags []',
      ], reason: 'AのInkはBのInkが持ち、お気に入りとタグはそこに付く');
      final saved = await _snapshot();

      b = await _resume(saved);
      await b.import(file, nextDir());
      expect(
        _changedKeys(saved, await _snapshot()),
        isEmpty,
        reason: 'すぐに読み直しても何も変わらない',
      );
      return (file: file, saved: saved, dup: dup, savedA: savedA);
    }

    test('after this device moves its duplicate above the brush that held '
        'the other device\'s brush, reading the same file again gives the '
        'duplicate no favourite or tag and writes nothing', () async {
      final first = await readOnce();
      var b = await _resume(first.saved);
      final from = b.brush.brushes.indexWhere((x) => x.id == first.dup);
      final to = b.brush.brushes.indexWhere((x) => x.id == 'B_ink');
      b.brush.reorderBrush(from, to);
      await settleTransfer();
      final reordered = await _snapshot();

      b = await _resume(reordered);
      final report = TransferImportReport();
      await b.import(first.file, nextDir(), report: report);
      expect(_brushes(b), [
        '${first.dup}|Ink (コピー)|size 17.0|favorite false|tags []',
        'B_ink|Ink|size 17.0|favorite true|tags [line]',
      ], reason: 'お気に入りとタグは、AのInkを持ったBのInkだけ');
      expect(_changedKeys(reordered, await _snapshot()), isEmpty);
      expect(report.addedCopies, isEmpty);
    });

    test('after this device draws with the brush that held the other '
        'device\'s brush and makes it thicker, reading the same file again '
        'gives the duplicate no favourite or tag, adds nothing and keeps '
        'this device\'s size', () async {
      final first = await readOnce();
      var b = await _resume(first.saved);
      b.brush.selectBrush('B_ink');
      b.brush.updateCurrentBrushSize(25);
      await b.brush.commitRememberedValues();
      await settleTransfer();
      final resized = await _snapshot();

      b = await _resume(resized);
      final report = TransferImportReport();
      await b.import(first.file, nextDir(), report: report);
      expect(_brushes(b), [
        'B_ink|Ink|size 25.0|favorite true|tags [line]',
        '${first.dup}|Ink (コピー)|size 17.0|favorite false|tags []',
      ], reason: 'Bで変えた太さのまま、複製には何も付かず、何も足さない');
      // 使っているブラシは設定と同じくもう1台で使っていたブラシになる
      // （1回目の読み込みと同じ）。それ以外は何も書き換えない。
      expect(
        _changedKeys(resized, await _snapshot()),
        anyOf(isEmpty, ['brushes_current_id']),
      );
      expect(report.addedCopies, isEmpty);
    });

    test('after the other device draws with its brush and makes it thicker, '
        'reading its new file adds nothing and the brush that held it keeps '
        'this device\'s size', () async {
      final first = await readOnce();
      final a = await _resume(first.savedA);
      a.brush.selectBrush('A_ink');
      a.brush.updateCurrentBrushSize(40);
      await a.brush.commitRememberedValues();
      await settleTransfer();
      final file = await a.export();

      final b = await _resume(first.saved);
      final report = TransferImportReport();
      await b.import(file, nextDir(), report: report);
      expect(_brushes(b), [
        'B_ink|Ink|size 17.0|favorite true|tags [line]',
        '${first.dup}|Ink (コピー)|size 17.0|favorite false|tags []',
      ], reason: '太さは同じブラシの違いに数えない（この端末の値のまま）');
      expect(
        _changedKeys(first.saved, await _snapshot()),
        anyOf(isEmpty, ['brushes_current_id']),
      );
      expect(report.addedCopies, isEmpty);
    });

    test('after this device moves its duplicate tone above the tone that held '
        'the other device\'s tone, reading the same file again gives the '
        'duplicate no favourite and writes nothing', () async {
      File picture(String name) =>
          File('${temp.path}/$name')
            ..writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10, 9]);
      final a = await _resume({'language': 'ja'});
      a.tone.addTone(
        Tone(id: 'A_dots', name: 'Dots', texturePath: picture('a.png').path),
      );
      a.tone.toggleFavorite('A_dots');
      await settleTransfer();
      final file = await a.export();

      var b = await _resume({'language': 'ja'});
      final mine = picture('b.png').path;
      b.tone.addTone(Tone(id: 'B_dots', name: 'Dots', texturePath: mine));
      b.tone.addTone(
        Tone(id: 'B_dots2', name: 'Dots (コピー)', texturePath: mine),
      );
      await settleTransfer();
      await b.import(file, nextDir());
      String tones(TransferDevice d) => [
        for (final t in d.tone.tones)
          if (t.id.startsWith('A_') || t.id.startsWith('B_'))
            '${t.id}|${t.name}|favorite ${t.isFavorite}',
      ].join(', ');
      expect(
        tones(b),
        'B_dots|Dots|favorite true, B_dots2|Dots (コピー)|favorite false',
      );
      final from = b.tone.tones.indexWhere((t) => t.id == 'B_dots2');
      final to = b.tone.tones.indexWhere((t) => t.id == 'B_dots');
      b.tone.reorderTone(from, to);
      await settleTransfer();
      final reordered = await _snapshot();

      b = await _resume(reordered);
      final report = TransferImportReport();
      await b.import(file, nextDir(), report: report);
      expect(
        tones(b),
        'B_dots2|Dots (コピー)|favorite false, B_dots|Dots|favorite true',
      );
      expect(_changedKeys(reordered, await _snapshot()), isEmpty);
      expect(report.addedCopies, isEmpty);
    });
  });
}
