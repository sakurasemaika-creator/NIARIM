import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で、同じファイルを続けて2回読んだとき、2回目は何も
/// 変えないこと：もう1台の項目の中身を持つこの端末の項目（前の読み込みで
/// その版として足した複製）は、1回目の読み込みが同じファイルから足した
/// 同じ中身の別の項目に替わらない。替わると、もう1台の項目のお気に入り・
/// タグがどちらの端末でも付けていない項目に付き、複製の記録が書き足される。
/// また、同じ中身だったのでつなげただけの項目（足した複製ではない）は、後で
/// この端末の一覧に入っても、つなげた項目の版を足した複製として選ばない。
/// この端末で消した複製が、もう1台の項目として同じIDで届いて一覧に入った
/// ときも同じ。

final _ja = lookupAppLocalizations(const Locale('ja'));

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

/// 2つの保存で値の違うキー。
List<String> _changedKeys(Map<String, Object> a, Map<String, Object> b) => [
  for (final key in {...a.keys, ...b.keys})
    if (jsonEncode(a[key]) != jsonEncode(b[key])) key,
]..sort();

/// 自作のブラシ（並び順どおり）。
List<String> _brushes(TransferDevice d) => [
  for (final b in d.brush.brushes)
    if (!d.brush.isBuiltIn(b.id))
      '${b.id}|${b.name}|spacing ${b.spacing}|size ${b.size}'
          '|favorite ${b.isFavorite}|tags ${b.tags}',
];

/// 早替えツールと、それが使うブラシ。
List<String> _quickTools(TransferDevice d) => [
  for (final e in d.quickTool.entries)
    if (e.label.startsWith('ref')) '${e.id}|${e.label}|${e.brushId}',
];

/// 自動塗りのプリセット（見本を除く）。
List<String> _presets(TransferDevice d) => [
  for (final p in d.autofill.presets)
    if (p.name.startsWith('Hair'))
      '${p.id}|${p.name}|${[for (final part in p.parts) part.color]}'
          '|favorite ${p.isFavorite}',
];

Brush _brushOf(TransferDevice d, String id) =>
    d.brush.brushes.singleWhere((b) => b.id == id);

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

  @override
  String toString() =>
      '$id|$name|$content|size $size|favorite $favorite|tags $tags';
}

/// [newId]は足す複製のID（省略すると`copy_0`から）。
TransferMergeRules<_Item> _rules(
  TransferImportReport report, {
  String Function()? newId,
}) => TransferMergeRules<_Item>(
  idOf: (e) => e.id,
  nameOf: (e) => e.name,
  contentOf: (e) => e.content,
  duplicateContentOf: (e) => [e.content, e.size],
  organizationOf: (e) => (favorite: e.favorite, tags: e.tags, folderId: null),
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
  newId: (attempt) => newId?.call() ?? 'copy_$attempt',
  copyNames: TransferCopyNames(_ja, report: report),
);

/// 2台の端末（AとB）で、項目を足す・中身・太さ・名前・整理を変える・消す・
/// 複製する・もう1台へ渡す（前に書き出したファイルを渡し直すこともある）を
/// [random]で繰り返す。渡すたびに、受け取った端末の項目のID・名前・中身・
/// 太さが変わらないことと、同じ項目をもう一度合わせても何も変わらないこと
/// （一覧・受け取った項目の中身を持つ項目・複製の記録・知らせ）を確かめる。
/// 食い違いがあれば、そこまでの操作と食い違いを返す。[wide]は中身と名前の
/// 種類を増やし、操作を長く続ける。
String? _randomTransfers(Random random, {required bool wide}) {
  final names = wide
      ? ['Ink', 'Ink (コピー)', 'Ink (コピー 2)', 'Pen', 'Pen (コピー)']
      : ['Ink', 'Ink', 'Ink (コピー)', 'Pen'];
  final newNames = wide
      ? ['Ink', 'Pen', 'Ink (コピー)', 'Pen (コピー 2)']
      : ['Ink', 'Pen', 'Quill'];
  final contents = wide ? ['a', 'b', 'c'] : ['a', 'a', 'b'];
  T pick<T>(List<T> from) => from[random.nextInt(from.length)];

  final items = {'A': <_Item>[], 'B': <_Item>[]};
  final records = {
    'A': TransferCopyRecord.none(),
    'B': TransferCopyRecord.none(),
  };
  final files = {'A': <List<_Item>>[], 'B': <List<_Item>>[]};
  final ids = <String>{};
  final log = <String>[];
  var made = 0;
  String newId(String prefix) {
    final id = '$prefix${made++}';
    ids.add(id);
    return id;
  }

  // 足した複製と、同じ項目としてつなげた組。
  String recorded(TransferCopyRecord record) => jsonEncode({
    for (final id in ids.toList()..sort())
      if (record.copiesOf(id).isNotEmpty || record.origin(id) != id)
        id: [...record.copiesOf(id), 'same item as ${record.origin(id)}'],
  });
  String own(_Item e) => '${e.id}|${e.name}|${e.content}|size ${e.size}';
  _Item changed(
    _Item e, {
    String? name,
    String? content,
    int? size,
    bool? favorite,
    List<String>? tags,
  }) => _Item(
    e.id,
    name ?? e.name,
    content ?? e.content,
    size: size ?? e.size,
    favorite: favorite ?? e.favorite,
    tags: tags ?? e.tags,
  );

  final steps = wide ? 6 + random.nextInt(14) : 5 + random.nextInt(8);
  for (var step = 0; step < steps; step++) {
    final who = random.nextBool() ? 'A' : 'B';
    final other = who == 'A' ? 'B' : 'A';
    final mine = items[who]!;
    final action = random.nextInt(13);
    if (action <= 1 || mine.isEmpty) {
      final added = _Item(newId('${who}_'), pick(names), pick(contents));
      mine.add(added);
      log.add('$who adds $added');
      continue;
    }
    if (action <= 7) {
      final i = random.nextInt(mine.length);
      final e = mine[i];
      switch (action) {
        case 2:
          mine[i] = changed(
            e,
            content: wide ? pick(contents) : (e.content == 'a' ? 'b' : 'a'),
          );
        case 3:
          mine[i] = changed(e, size: e.size == 17 ? 25 : 17);
        case 4:
          mine[i] = changed(e, name: pick(newNames));
        case 5:
          mine.removeAt(i);
        case 6:
          mine[i] = random.nextBool()
              ? changed(e, favorite: !e.favorite)
              : changed(e, tags: e.tags.isEmpty ? ['line'] : []);
        default:
          mine.add(
            _Item(
              newId('${who}_'),
              numberedCopyName(
                _ja,
                TransferCopyNames.copiedFrom(e.name) ?? e.name,
                {for (final x in mine) x.name},
              ),
              e.content,
              size: e.size,
            ),
          );
      }
      log.add('$who changes $e (action $action) => $mine');
      continue;
    }
    // 渡す（前に書き出したファイルのこともある）。
    final sent = files[who]!;
    final again = sent.isNotEmpty && random.nextInt(5) < 2;
    if (!again) sent.add(List.of(mine));
    final file = again ? pick(sent) : sent.last;
    final theirs = items[other]!;
    final record = records[other]!;
    final before = {for (final e in theirs) e.id: own(e)};
    final was = '$theirs';
    final firstPlaced = <String, String>{};
    mergeTransferredItems(
      theirs,
      file,
      _rules(TransferImportReport(), newId: () => newId('copy_')),
      placed: firstPlaced,
      copies: record,
    );
    log.add(
      '$who -> $other${again ? ' (an earlier file)' : ''}: $file into $was '
      '=> $theirs, held by $firstPlaced, record ${recorded(record)}',
    );
    final after = {for (final e in theirs) e.id: own(e)};
    final first = '$theirs';
    final firstRecord = recorded(record);
    final report = TransferImportReport();
    final secondPlaced = <String, String>{};
    final rewritten = mergeTransferredItems(
      theirs,
      file,
      _rules(report, newId: () => newId('copy_')),
      placed: secondPlaced,
      copies: record,
    );
    final problems = [
      for (final entry in before.entries)
        if (after[entry.key] != entry.value)
          'this device\'s item changed: ${entry.value} => ${after[entry.key]}',
      if (rewritten) 'the second merge reports a change',
      if ('$theirs' != first) 'the second merge changed the list: $theirs',
      if ('$secondPlaced' != '$firstPlaced')
        'the second merge changed the holders: $secondPlaced',
      if (recorded(record) != firstRecord)
        'the second merge changed the record: ${recorded(record)}',
      if (report.addedCopies.isNotEmpty)
        'the second merge reported ${report.addedCopies}',
    ];
    if (problems.isNotEmpty) {
      return '  ${log.join('\n  ')}\n  !! ${problems.join('\n  !! ')}';
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_reread_holder_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// [saved]の端末で[file]を読み、起動し直してもう一度読む。2回目が何も
  /// 変えないことを確かめて、1回目の後の端末を返す。
  Future<TransferDevice> readTwice(
    _Problems p,
    Map<String, Object> saved,
    Uint8List bytes,
  ) async {
    final first = await _resume(saved);
    await first.import(bytes, nextDir());
    final afterFirst = await _snapshot();

    final second = await _resume(afterFirst);
    final report = TransferImportReport();
    await second.import(bytes, nextDir(), report: report);
    final afterSecond = await _snapshot();

    p.check(_brushes(second), _brushes(first), '2回目の読み込みはブラシを変えない');
    p.check(_quickTools(second), _quickTools(first), '2回目の読み込みは早替えツールを変えない');
    p.check(_presets(second), _presets(first), '2回目の読み込みは自動塗りを変えない');
    p.check(
      _changedKeys(afterFirst, afterSecond),
      isEmpty,
      '2回目の読み込みはどの保存も書き換えない',
    );
    p.check(report.addedCopies, isEmpty, '2回目の読み込みは何も知らせない');
    return first;
  }

  for (final resized in [false, true]) {
    test('a copy that arrived under its own ID with a numbered name and was '
        'renamed here${resized ? ' and given another size' : ''} stays the '
        'holder of the other device\'s brush when the same file, which also '
        'has a second brush with the same content, is read twice', () async {
      // A：ブラシ「Ink」。
      var a = await _resume({'language': 'ja'});
      a.brush.addBrush(customTransferBrush('BrushX', 'Ink', null));
      await settleTransfer();
      final fromA = await a.export();
      final savedA = await _snapshot();

      // B：同じ名前で別の中身の自分のブラシを持つので、Aのブラシは
      // 「Ink (コピー)」（IDはAのまま）として届く。その名前をBで変える。
      var b = await _resume({'language': 'ja'});
      b.brush.addBrush(
        customTransferBrush('BrushMine', 'Ink', null).copyWith(spacing: 30),
      );
      await settleTransfer();
      await b.import(fromA, nextDir());
      final p = _Problems();
      p.check(_brushOf(b, 'BrushX').name, 'Ink (コピー)', '番号を付けて届く');
      b.brush.updateBrush(
        _brushOf(
          b,
          'BrushX',
        ).copyWith(name: 'Pen', size: resized ? 40.0 : null),
      );
      await settleTransfer();
      final savedB = await _snapshot();

      // A：そのブラシにお気に入りとタグを付け、同じ中身のブラシをもう1つ
      // 持つ。
      a = await _resume(savedA);
      a.brush.addBrush(customTransferBrush('BrushY', 'Ink (コピー)', null));
      a.brush.toggleFavoriteBrush('BrushX');
      a.brush.setTags('BrushX', ['line']);
      a.quickTool.addEntry(
        const QuickToolEntry(
          id: 'qt_x',
          label: 'ref x',
          toolKey: 'pen',
          brushId: 'BrushX',
          sizeOverride: 40,
        ),
      );
      await settleTransfer();
      final file = await a.export();

      b = await readTwice(p, savedB, file);
      final size = resized ? 40.0 : 17.0;
      p.check(_brushes(b), [
        'BrushMine|Ink|spacing 30|size 17.0|favorite false|tags []',
        'BrushX|Pen|spacing 12|size $size|favorite true|tags [line]',
        'BrushY|Ink (コピー)|spacing 12|size 17.0|favorite false|tags []',
      ], 'お気に入りとタグは名前を変えたAのブラシに付き、Aの2つ目のブラシには付かない');
      p.check(_quickTools(b), ['qt_x|ref x|BrushX'], '早替えツールはAのブラシを指す');
      p.verify();
    });
  }

  test('the copy added for the other device\'s version of a brush with the '
      'same ID stays its holder when the same file, in which an earlier '
      'brush has the same content, is read twice', () async {
    var a = await _resume({'language': 'ja'});
    a.brush.addBrush(customTransferBrush('A1', 'Ink', null));
    await settleTransfer();
    final savedA = await _snapshot();

    var b = await _resume({'language': 'ja'});
    b.brush.addBrush(
      customTransferBrush('B3', 'Ink', null).copyWith(spacing: 30),
    );
    await settleTransfer();
    final fromB = await b.export();
    final savedB = await _snapshot();

    // A：Bのブラシを受け取り、自分のブラシと同じ中身に変えて、お気に入りと
    // タグを付ける。
    a = await _resume(savedA);
    await a.import(fromB, nextDir());
    a.brush.updateBrush(_brushOf(a, 'B3').copyWith(spacing: 12));
    a.brush.toggleFavoriteBrush('B3');
    a.brush.setTags('B3', ['line']);
    a.quickTool.addEntry(
      const QuickToolEntry(
        id: 'qt_b3',
        label: 'ref b3',
        toolKey: 'pen',
        brushId: 'B3',
        sizeOverride: 40,
      ),
    );
    await settleTransfer();
    final file = await a.export();

    final p = _Problems();
    b = await readTwice(p, savedB, file);
    final copy = b.brush.brushes.last;
    p.check(_brushes(b), [
      'B3|Ink|spacing 30|size 17.0|favorite false|tags []',
      'A1|Ink (コピー)|spacing 12|size 17.0|favorite false|tags []',
      '${copy.id}|Ink (コピー 2)|spacing 12|size 17.0'
          '|favorite true|tags [line]',
    ], 'お気に入りとタグは、AのB3の版を足した複製に付き、Aの別のブラシには付かない');
    p.check(_quickTools(b), ['qt_b3|ref b3|${copy.id}'], '早替えツールは複製を指す');
    p.verify();
  });

  for (final deleted in [false, true]) {
    test('the copy added for the other device\'s version of a brush and given '
        'another size here stays its holder'
        '${deleted ? ' after this device\'s own version is deleted' : ''} '
        'when the same file, which now also has a second brush with the '
        'same content, is read twice', () async {
      var a = await _resume({'language': 'ja'});
      a.brush.addBrush(customTransferBrush('BrushS', 'Ink', null));
      await settleTransfer();
      final fromA = await a.export();
      final savedA = await _snapshot();

      // B：同じIDで別の中身のブラシを持つので、Aの版は複製として届く。
      // その複製の太さをBで変える。
      var b = await _resume({'language': 'ja'});
      b.brush.addBrush(
        customTransferBrush('BrushS', 'Ink', null).copyWith(spacing: 30),
      );
      await settleTransfer();
      await b.import(fromA, nextDir());
      final copyId = b.brush.brushes.last.id;
      final p = _Problems();
      p.check(_brushOf(b, copyId).name, 'Ink (コピー)', 'Aの版は複製として届く');
      b.brush.updateBrush(_brushOf(b, copyId).copyWith(size: 40));
      if (deleted) b.brush.deleteBrush('BrushS');
      await settleTransfer();
      final savedB = await _snapshot();

      // A：そのブラシにお気に入りとタグを付け、同じ中身のブラシをもう1つ
      // 持つ。
      a = await _resume(savedA);
      a.brush.addBrush(customTransferBrush('BrushY', 'Ink (コピー)', null));
      a.brush.toggleFavoriteBrush('BrushS');
      a.brush.setTags('BrushS', ['line']);
      a.quickTool.addEntry(
        const QuickToolEntry(
          id: 'qt_s',
          label: 'ref s',
          toolKey: 'pen',
          brushId: 'BrushS',
          sizeOverride: 40,
        ),
      );
      await settleTransfer();
      final file = await a.export();

      b = await readTwice(p, savedB, file);
      p.check(_brushes(b), [
        if (!deleted) 'BrushS|Ink|spacing 30|size 17.0|favorite false|tags []',
        '$copyId|Ink (コピー)|spacing 12|size 40.0|favorite true|tags [line]',
        'BrushY|Ink (コピー 2)|spacing 12|size 17.0|favorite false|tags []',
      ], 'お気に入りとタグは、太さを変えた複製に付き、Aの2つ目のブラシには付かない');
      p.check(_quickTools(b), ['qt_s|ref s|$copyId'], '早替えツールは複製を指す');
      p.verify();
    });
  }

  test('the copy added for the other device\'s version of an autofill preset '
      'with the same ID stays its holder when the same file, in which an '
      'earlier preset has the same content, is read twice (the preset list '
      'and the records of copied presets and parts are not written '
      'again)', () async {
    AutofillPreset preset(String id, int color) => AutofillPreset(
      id: id,
      name: 'Hair',
      parts: [AutofillPart(id: '${id}_hair', name: 'Hair', color: color)],
    );
    var a = await _resume({'language': 'ja'});
    await a.autofill.addPreset(preset('p_a', 0xFFFF0000));
    await settleTransfer();
    final savedA = await _snapshot();

    var b = await _resume({'language': 'ja'});
    await b.autofill.addPreset(preset('p_b', 0xFF0000FF));
    await settleTransfer();
    final fromB = await b.export();
    final savedB = await _snapshot();

    // A：Bのプリセットを受け取り、自分のプリセットと同じ中身に変えて、
    // お気に入りにする。
    a = await _resume(savedA);
    await a.import(fromB, nextDir());
    final theirs = a.autofill.presets.singleWhere((x) => x.id == 'p_b');
    await a.autofill.updatePreset(
      theirs.copyWith(
        isFavorite: true,
        parts: [
          for (final part in theirs.parts) part.copyWith(color: 0xFFFF0000),
        ],
      ),
    );
    await settleTransfer();
    final file = await a.export();

    final p = _Problems();
    b = await readTwice(p, savedB, file);
    final copy = b.autofill.presets.last;
    p.check(_presets(b), [
      'p_b|Hair|[${0xFF0000FF}]|favorite false',
      'p_a|Hair (コピー)|[${0xFFFF0000}]|favorite false',
      '${copy.id}|Hair (コピー 2)|[${0xFFFF0000}]|favorite true',
    ], 'お気に入りは、Aのp_bの版を足した複製に付き、Aの別のプリセットには付かない');
    p.verify();
  });

  test('a brush that was only found to be the same as a brush of this device '
      '(not a copy added for it) and later arrives under its own ID is not '
      'taken for the copy added for that brush when the same file is read '
      'twice', () async {
    // A：ブラシ「Ink」をBへ渡す。
    var a = await _resume({'language': 'ja'});
    a.brush.addBrush(customTransferBrush('BrushA0', 'Ink', null));
    await settleTransfer();
    final fromA = await a.export();
    final savedA = await _snapshot();

    // B：受け取ったブラシの名前を変え、同じ中身の自分のブラシ「Ink」を作る。
    var b = await _resume({'language': 'ja'});
    await b.import(fromA, nextDir());
    b.brush.updateBrush(_brushOf(b, 'BrushA0').copyWith(name: 'Quill'));
    b.brush.addBrush(customTransferBrush('BrushB1', 'Ink', null));
    await settleTransfer();
    final fromB = await b.export();
    final savedB = await _snapshot();

    // A：Bの版（名前が違う）は複製「Quill (コピー)」として届き、Bの
    // 「Ink」は同じ中身の自分のブラシが持つ（足さない）。複製の太さを変える。
    a = await _resume(savedA);
    await a.import(fromB, nextDir());
    final p = _Problems();
    final copyId = a.brush.brushes.last.id;
    p.check(_brushes(a), [
      'BrushA0|Ink|spacing 12|size 17.0|favorite false|tags []',
      '$copyId|Quill (コピー)|spacing 12|size 17.0|favorite false|tags []',
    ], 'Bの版は複製として届き、Bの「Ink」は足さない');
    a.brush.updateBrush(_brushOf(a, copyId).copyWith(size: 40));
    await settleTransfer();
    final savedA2 = await _snapshot();

    // B：「Quill」をお気に入りにし、自分の「Ink」の太さを変える。
    b = await _resume(savedB);
    b.brush.toggleFavoriteBrush('BrushA0');
    b.brush.updateBrush(_brushOf(b, 'BrushB1').copyWith(size: 25));
    await settleTransfer();
    final file = await b.export();

    a = await readTwice(p, savedA2, file);
    p.check(_brushes(a), [
      'BrushA0|Ink|spacing 12|size 17.0|favorite false|tags []',
      '$copyId|Quill (コピー)|spacing 12|size 40.0|favorite true|tags []',
      'BrushB1|Ink (コピー)|spacing 12|size 25.0|favorite false|tags []',
    ], 'お気に入りは、Bの版を足した複製に付き、太さを変えて届いたBの「Ink」には付かない');
    p.verify();
  });

  group('mergeTransferredItems, reading the same items twice', () {
    /// [local]へ[incoming]を2回合わせる。2回目が何も変えないことを確かめて、
    /// 1回目の後の一覧と、受け取った項目の中身を持つ項目を返す。
    ({List<String> items, Map<String, String> placed}) mergeTwice(
      _Problems p,
      String what,
      List<_Item> local,
      List<_Item> incoming,
      TransferCopyRecord record,
    ) {
      // 足した複製と、同じ項目としてつなげた組。
      Map<String, List<String>> recorded() => {
        for (final id in {
          for (final e in [...local, ...incoming]) e.id,
        })
          id: [...record.copiesOf(id), 'same item as ${record.origin(id)}'],
      };

      final firstPlaced = <String, String>{};
      mergeTransferredItems(
        local,
        incoming,
        _rules(TransferImportReport()),
        placed: firstPlaced,
        copies: record,
      );
      final items = [for (final e in local) '$e'];
      final recordAfterFirst = jsonEncode(recorded());

      final report = TransferImportReport();
      final secondPlaced = <String, String>{};
      final changed = mergeTransferredItems(
        local,
        incoming,
        _rules(report),
        placed: secondPlaced,
        copies: record,
      );
      p.check(changed, isFalse, '$what: 2回目は何も変えない');
      p.check([for (final e in local) '$e'], items, '$what: 2回目は一覧を変えない');
      p.check(secondPlaced, firstPlaced, '$what: 2回目も同じ項目が中身を持つ');
      p.check(
        jsonEncode(recorded()),
        recordAfterFirst,
        '$what: 2回目は複製の記録を書き足さない',
      );
      p.check(report.addedCopies, isEmpty, '$what: 2回目は何も知らせない');
      return (items: items, placed: firstPlaced);
    }

    test('after random edits and transfers between two devices, a transfer '
        'never changes the ID, name, content or size of an item of the '
        'receiving device, and merging the same items again changes nothing '
        '(20,000 runs each with few and with more names and contents)', () {
      final found = <String>[];
      var failing = 0;
      for (final wide in [false, true]) {
        for (var seed = 0; seed < 20000; seed++) {
          final problem = _randomTransfers(Random(seed), wide: wide);
          if (problem == null) continue;
          failing++;
          if (found.length < 4) {
            found.add('seed $seed${wide ? ' (more names)' : ''}:\n$problem');
          }
        }
      }
      if (failing > 0) {
        fail(
          '$failing of 40000 runs with problems; the first '
          '${found.length}:\n\n${found.join('\n\n')}',
        );
      }
    });

    test('an item that arrived under its own ID with a numbered name and was '
        'renamed here (and given another size) holds the incoming item, not '
        'the second item with that content that the first read added', () {
      final p = _Problems();
      for (final size in [17, 40]) {
        final what = 'size $size';
        final result = mergeTwice(
          p,
          what,
          [
            const _Item('mine', 'Ink', 'own'),
            _Item('x', 'Pen', 'ink', size: size),
          ],
          const [
            _Item('x', 'Ink', 'ink', favorite: true, tags: ['line']),
            _Item('y', 'Ink (コピー)', 'ink'),
          ],
          TransferCopyRecord.none()..add('x', 'x'),
        );
        p.check(result.items, [
          'mine|Ink|own|size 17|favorite false|tags []',
          'x|Pen|ink|size $size|favorite true|tags [line]',
          'y|Ink (コピー)|ink|size 17|favorite false|tags []',
        ], '$what: 整理は名前を変えた項目へ');
        p.check(result.placed, {'x': 'x', 'y': 'y'}, what);
      }
      p.verify();
    });

    test('the copy added for an item with the same ID holds the incoming '
        'item, not an earlier item of the same file with that content', () {
      final p = _Problems();
      final result = mergeTwice(
        p,
        'same ID',
        [const _Item('b3', 'Ink', 'own')],
        const [
          _Item('a1', 'Ink', 'ink'),
          _Item('b3', 'Ink (コピー)', 'ink', favorite: true, tags: ['line']),
        ],
        TransferCopyRecord.none(),
      );
      p.check(result.items, [
        'b3|Ink|own|size 17|favorite false|tags []',
        'a1|Ink (コピー)|ink|size 17|favorite false|tags []',
        'copy_0|Ink (コピー 2)|ink|size 17|favorite true|tags [line]',
      ], '整理は足した複製へ');
      p.check(result.placed, {'a1': 'a1', 'b3': 'copy_0'}, '足した複製が中身を持つ');
      p.verify();
    });

    test('the copy added before for an item, renamed or given another size '
        'here, holds the incoming item (with this device\'s own version '
        'kept or deleted), not the second item with that content that the '
        'first read added', () {
      final p = _Problems();
      for (final (name, size) in [
        ('Ink (コピー)', 40),
        ('Mine', 17),
        ('Mine', 40),
      ]) {
        for (final deleted in [false, true]) {
          final what = '$name, size $size, own version deleted: $deleted';
          final result = mergeTwice(
            p,
            what,
            [
              if (!deleted) const _Item('s', 'Ink', 'own'),
              _Item('c', name, 'ink', size: size),
            ],
            const [
              _Item('s', 'Ink', 'ink', favorite: true, tags: ['line']),
              _Item('y', 'Ink (コピー)', 'ink'),
            ],
            TransferCopyRecord.none()..add('s', 'c'),
          );
          final second = name == 'Ink (コピー)' ? 'Ink (コピー 2)' : 'Ink (コピー)';
          p.check(result.items, [
            if (!deleted) 's|Ink|own|size 17|favorite false|tags []',
            'c|$name|ink|size $size|favorite true|tags [line]',
            'y|$second|ink|size 17|favorite false|tags []',
          ], '$what: 整理は前に足した複製へ');
          p.check(result.placed, {'s': 'c', 'y': 'y'}, what);
        }
      }
      p.verify();
    });

    test('an item with the same content that was here before any transfer '
        'still holds the incoming item when no copy was added for it '
        '(nothing is added, its organization is merged, and the two are '
        'linked once)', () {
      final p = _Problems();
      final record = TransferCopyRecord.none();
      final result = mergeTwice(
        p,
        'no copy recorded',
        [const _Item('mine', 'Ink', 'ink')],
        const [
          _Item('x', 'Ink', 'ink', favorite: true, tags: ['line']),
        ],
        record,
      );
      p.check(result.items, [
        'mine|Ink|ink|size 17|favorite true|tags [line]',
      ], '同じ中身の項目は足さず、整理を合わせる');
      p.check(result.placed, {'x': 'mine'}, 'この端末の項目が中身を持つ');
      p.check(record.origin('x'), record.origin('mine'), '2つは同じ項目');
      p.check(record.copiesOf('x'), isEmpty, 'この端末の項目は、足した複製ではない');
      p.check(record.copiesOf('mine'), isEmpty, '受け取った項目も、足した複製ではない');
      p.verify();
    });

    test('an item that was only found to be the same as an item of this '
        'device (linked, not a copy added for it) is not taken for a copy '
        'added for that item once it is in this device\'s list', () {
      final p = _Problems();

      // 名前に番号を付けて届いたa1（自分自身の版）。同じファイルのa2は、
      // この端末で名前を変えていて、中身と名前が同じa1が持つ。
      var result = mergeTwice(
        p,
        'linked in the same read',
        [
          const _Item('b0', 'Ink (コピー)', 'own'),
          const _Item('a1', 'Ink (コピー 2)', 'ink', tags: ['line']),
          const _Item('a2', 'Pen', 'ink'),
        ],
        const [
          _Item('a1', 'Quill', 'ink', tags: ['line']),
          _Item('a2', 'Ink (コピー 2)', 'ink'),
        ],
        TransferCopyRecord.none()..add('a1', 'a1'),
      );
      p.check(result.items, [
        'b0|Ink (コピー)|own|size 17|favorite false|tags []',
        'a1|Ink (コピー 2)|ink|size 17|favorite false|tags [line]',
        'a2|Pen|ink|size 17|favorite false|tags []',
      ], 'linked in the same read: 整理は自分自身の版へ');
      p.check(result.placed, {
        'a1': 'a1',
        'a2': 'a1',
      }, 'linked in the same read');

      // 前の読み込みで、b1はこの端末のa0が持っていた（つなげただけ）。a0の
      // 版はc0として足してあり、この端末でc0の太さを変えた。b1は太さが
      // 変わって、今度は自分のIDで届く。
      result = mergeTwice(
        p,
        'linked before, with a copy added for the item',
        [
          const _Item('a0', 'Ink', 'ink'),
          const _Item('c0', 'Quill (コピー)', 'ink', size: 40),
        ],
        const [
          _Item('a0', 'Quill', 'ink', favorite: true),
          _Item('b1', 'Ink', 'ink', size: 25),
        ],
        TransferCopyRecord.none()
          ..add('a0', 'c0')
          ..link('b1', 'a0'),
      );
      p.check(result.items, [
        'a0|Ink|ink|size 17|favorite false|tags []',
        'c0|Quill (コピー)|ink|size 40|favorite true|tags []',
        'b1|Ink (コピー)|ink|size 25|favorite false|tags []',
      ], 'linked before, with a copy: 整理はa0の版を足した複製へ');
      p.check(result.placed, {
        'a0': 'c0',
        'b1': 'b1',
      }, 'linked before, with a copy');

      // 前の読み込みで、b2はこの端末のa1が持っていた。この端末でa1の中身を
      // 変えたので、a1の版は同じ中身のa3が持ち、b2は自分のIDで届く。
      result = mergeTwice(
        p,
        'linked before, no copy added for the item',
        [const _Item('a1', 'Ink', 'own'), const _Item('a3', 'Ink', 'ink')],
        const [
          _Item('a1', 'Ink', 'ink', favorite: true),
          _Item('b2', 'Pen', 'ink'),
        ],
        TransferCopyRecord.none()..link('b2', 'a1'),
      );
      p.check(result.items, [
        'a1|Ink|own|size 17|favorite false|tags []',
        'a3|Ink|ink|size 17|favorite true|tags []',
        'b2|Pen|ink|size 17|favorite false|tags []',
      ], 'linked before, no copy: 整理は同じ中身・同じ名前の項目へ');
      p.check(result.placed, {
        'a1': 'a3',
        'b2': 'b2',
      }, 'linked before, no copy');
      p.verify();
    });

    test('a copy that was added for an item, deleted here, and now arrives '
        'under its own ID as an item of the other device is not taken for '
        'the copy added for that item again (the two still count as the '
        'same item for whatever points at them)', () {
      final p = _Problems();
      for (final copyFirst in [false, true]) {
        for (final clash in [false, true]) {
          final what = 'copy first in the file: $copyFirst, name clash: $clash';
          // 前の読み込みでb0の版をc0として足し、この端末でc0を消した。
          // b0の中身は、同じ中身・同じ名前のこの端末のb1が持つ。
          final record = TransferCopyRecord.none()..add('b0', 'c0');
          const b0 = _Item('b0', 'Pen', 'ink', size: 25, favorite: true);
          const c0 = _Item('c0', 'Pen (コピー)', 'ink');
          final result = mergeTwice(
            p,
            what,
            [
              const _Item('b1', 'Pen', 'ink', size: 25),
              if (clash) const _Item('own', 'Pen (コピー)', 'own'),
            ],
            copyFirst ? [c0, b0] : [b0, c0],
            record,
          );
          p.check(result.items, [
            'b1|Pen|ink|size 25|favorite true|tags []',
            if (clash) 'own|Pen (コピー)|own|size 17|favorite false|tags []',
            'c0|Pen (コピー${clash ? ' 2' : ''})|ink|size 17|favorite false|tags []',
          ], '$what: 整理は同じ中身・同じ名前の項目へ');
          p.check(result.placed, {'b0': 'b1', 'c0': 'c0'}, what);
          p.check(
            record.copiesOf('b0'),
            isEmpty,
            '$what: 届いた項目は、もうb0の版を足した複製ではない',
          );
          p.check(record.origin('c0'), record.origin('b0'), '$what: 同じ項目のまま');
        }
      }
      p.verify();
    });
  });
}
