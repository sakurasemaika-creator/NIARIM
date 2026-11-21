import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）で、もう1台で複製して太さ・不透明度だけを変えた
/// ブラシが失われないこと、早替えツール・ショートカット・ワークスペースが
/// 指すブラシが読み込んだ後も一覧にあること：
/// - 太さ・不透明度だけが違う複製も別のブラシとして届く（空の端末でも、
///   自分の複製を持つ端末でも）。
/// - 早替えツール・ショートカット・ワークスペースの早替えツールのブラシは、
///   合わせた後の一覧のブラシ（同じ中身が既にあって足さなかったならその
///   ブラシ、この端末の版を残して足した複製なら複製）を指す。
/// - この端末で太さを変えた複製に、同じファイルを読み直しても複製は増えない。

final _ja = lookupAppLocalizations(const Locale('ja'));

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

/// ブラシの一覧の「複製」と同じ名前で[id]を複製し、キャンバスで太さ・
/// 不透明度を変えたときと同じく覚えさせる。新しいIDを返す。
Future<String> _duplicate(
  TransferDevice d,
  String id, {
  double? size,
  int? opacity,
}) async {
  final source = d.brush.brushes.singleWhere((b) => b.id == id);
  final copy = d.brush.duplicateBrush(
    id,
    name: numberedCopyName(_ja, source.name, {
      for (final b in d.brush.brushes) b.name,
    }),
  )!;
  // 同じミリ秒に2つ複製するとIDが重なるので、次の複製まで時計を進める。
  await Future<void>.delayed(const Duration(milliseconds: 2));
  d.brush.selectBrush(copy);
  if (size != null) d.brush.updateCurrentBrushSize(size);
  if (opacity != null) d.brush.updateCurrentBrushOpacity(opacity);
  await d.brush.commitRememberedValues();
  await settleTransfer();
  return copy;
}

/// [brushId]を使う早替えツール・ショートカット・ワークスペースを作る。
Future<void> _referTo(TransferDevice d, String brushId, String tag) async {
  final entry = QuickToolEntry(
    id: 'qt_ref_$tag',
    label: 'ref $tag',
    toolKey: 'pen',
    brushId: brushId,
    sizeOverride: 40,
  );
  d.quickTool.addEntry(entry);
  d.shortcut.addBinding(
    ShortcutBinding(
      id: 'sc_ref_$tag',
      label: 'ref $tag',
      keyId: (tag == 'a' ? LogicalKeyboardKey.keyT : LogicalKeyboardKey.keyG)
          .keyId,
      control: true,
      toolKey: 'pen',
      brushId: brushId,
    ),
  );
  await d.workspace.save(
    'Inking $tag',
    isLeftHanded: false,
    forcePcMode: null,
    quickToolEntries: [entry.toJson()],
  );
  await settleTransfer();
}

/// [tag]の早替えツール・ショートカット・ワークスペースが指すブラシ（一覧に
/// 無ければnull）。
({Brush? quick, Brush? shortcut, Brush? workspace}) _referenced(
  TransferDevice d,
  String tag,
) {
  Brush? find(Object? id) =>
      d.brush.brushes.where((b) => b.id == id).firstOrNull;
  final quick = d.quickTool.entries
      .where((e) => e.id == 'qt_ref_$tag')
      .firstOrNull;
  final shortcut = d.shortcut.bindings
      .where((b) => b.id == 'sc_ref_$tag')
      .firstOrNull;
  final workspace = d.workspace.presets
      .where((p) => p.name == 'Inking $tag')
      .firstOrNull;
  return (
    quick: find(quick?.brushId),
    shortcut: find(shortcut?.brushId),
    workspace: find(workspace?.quickToolEntries.firstOrNull?['brushId']),
  );
}

/// 自作のブラシの名前・太さ・不透明度（並び順は問わない）。
List<String> _custom(TransferDevice d) => [
  for (final b in d.brush.brushes)
    if (!d.brush.isBuiltIn(b.id)) '${b.name}|${b.size}|${b.opacity}',
]..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_brush_refs_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('copies that differ only in size or opacity all arrive on an empty '
      'device, and the quick tool, shortcut and workspace that use one of '
      'them point at it', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final image = File('${temp.path}/ink.png')..writeAsBytesSync([1, 2, 3]);
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', image.path));
    await settleTransfer();
    final inkCopy = await _duplicate(a, 'BrushInk', size: 40);
    await _duplicate(a, 'Brush0002', size: 4);
    await _duplicate(a, 'Brush0002', size: 60);
    await _duplicate(a, 'Brush0002', opacity: 30);
    // 何も変えていない複製が2つ（もう1台では別々のブラシ）。
    await _duplicate(a, 'Brush0002');
    await _duplicate(a, 'Brush0002');
    await _referTo(a, inkCopy, 'a');
    final expected = _custom(a);
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final f = await TransferDevice.start();
    final report = TransferImportReport();
    await f.import(bytes, nextDir(), report: report);
    await f.import(bytes, nextDir());

    final p = _Problems();
    p.check(report.addedCopies, isEmpty, '空の端末では複製の名前で足さない');
    for (final (stage, d) in [
      ('after import', f),
      ('restart', await _resume(await _snapshot())),
    ]) {
      p.check(_custom(d), expected, '$stage: もう1台の自作ブラシがすべて届く');
      final refs = _referenced(d, 'a');
      for (final (what, brush) in [
        ('quick tool', refs.quick),
        ('shortcut', refs.shortcut),
        ('workspace', refs.workspace),
      ]) {
        p.check(
          brush == null ? null : '${brush.name}|${brush.size}',
          '${_ja.projectDuplicateName('Ink')}|40.0',
          '$stage: $whatは太さ40の「Ink (コピー)」を指す',
        );
      }
    }
    p.verify();
  });

  test('on a device with its own copy of the same brush, the other '
      'device\'s copies that differ only in size still arrive', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final image = File('${temp.path}/ink.png')..writeAsBytesSync([1, 2, 3]);
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', image.path));
    await settleTransfer();
    final early = await a.export();
    final inkCopy = await _duplicate(a, 'BrushInk', size: 40);
    await _duplicate(a, 'Brush0002', size: 4);
    await _duplicate(a, 'Brush0002', size: 60);
    await _referTo(a, inkCopy, 'a');
    final theirs = [
      for (final b in a.brush.brushes)
        if (!a.brush.isBuiltIn(b.id) && b.id != 'BrushInk') (b.name, b.size),
    ];
    final bytes = await a.export();

    // この端末は前にもう1台のInkを受け取り、自分でもGペンを複製した。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.import(early, nextDir());
    final own = await _duplicate(b, 'Brush0002', size: 10);
    final ownName = b.brush.brushes.singleWhere((x) => x.id == own).name;
    await b.import(bytes, nextDir());
    await b.import(bytes, nextDir());

    final p = _Problems();
    for (final (stage, d) in [
      ('after import', b),
      ('restart', await _resume(await _snapshot())),
    ]) {
      final mine = d.brush.brushes.where((x) => x.id == own).firstOrNull;
      p.check(
        mine == null ? null : '${mine.name}|${mine.size}',
        '$ownName|10.0',
        '$stage: この端末の複製はそのまま',
      );
      for (final (name, size) in theirs) {
        p.check(
          d.brush.brushes
              .where(
                (x) =>
                    x.id != own &&
                    x.size == size &&
                    TransferCopyNames.related(x.name, name),
              )
              .length,
          1,
          '$stage: もう1台の「$name」（太さ$size）が1つ届く',
        );
      }
      final refs = _referenced(d, 'a');
      for (final (what, brush) in [
        ('quick tool', refs.quick),
        ('shortcut', refs.shortcut),
        ('workspace', refs.workspace),
      ]) {
        p.check(brush?.size, 40, '$stage: $whatは太さ40のInkの複製を指す');
      }
    }
    p.verify();
  });

  test('after a round trip, a quick tool, shortcut and workspace made for the '
      'copy of a brush that comes back to the device it came from point at '
      'the brush with that content, and reading the file again changes '
      'nothing', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final x = await _duplicate(a, 'Brush0002', size: 30);
    final first = await a.export();
    Brush brushOf(TransferDevice d, String id) =>
        d.brush.brushes.singleWhere((b) => b.id == id);
    a.brush.updateBrush(brushOf(a, x).copyWith(spacing: 33));
    await settleTransfer();
    final second = await a.export();
    final savedA = await _snapshot();

    // もう1台は同じブラシを別に変えてから、変えた後のファイルを読む。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.import(first, nextDir());
    b.brush.updateBrush(brushOf(b, x).copyWith(spacing: 66));
    await settleTransfer();
    await b.import(second, nextDir());
    final y = b.brush.brushes.singleWhere((e) => e.spacing == 33 && e.id != x);
    await _referTo(b, y.id, 'a');
    // もう1台の版のブラシを使う早替えツールなども、元の端末へ渡る。
    await _referTo(b, x, 'b');
    // もう1台では足した複製を使っている。
    b.brush.selectBrush(y.id);
    await settleTransfer();
    final back = await b.export();

    final device = await _resume(savedA);
    device.brush.selectBrush('Brush0001');
    await settleTransfer();
    await device.import(back, nextDir());
    final counts = (
      device.brush.brushes.length,
      device.quickTool.entries.length,
      device.shortcut.bindings.length,
      device.workspace.presets.length,
    );
    await device.import(back, nextDir());

    final p = _Problems();
    p.check(
      (
        device.brush.brushes.length,
        device.quickTool.entries.length,
        device.shortcut.bindings.length,
        device.workspace.presets.length,
      ),
      counts,
      '読み直しても何も増えない',
    );
    for (final (stage, d) in [
      ('after import', device),
      ('restart', await _resume(await _snapshot())),
    ]) {
      final refs = _referenced(d, 'a');
      for (final (what, brush) in [
        ('quick tool', refs.quick),
        ('shortcut', refs.shortcut),
        ('workspace', refs.workspace),
      ]) {
        p.check(brush?.id, x, '$stage: $whatは同じ中身のこの端末のブラシを指す');
      }
      p.check(
        d.brush.currentBrush?.id,
        x,
        '$stage: もう1台で使っていたブラシ（戻ってきた複製）は、同じ中身の'
        'この端末のブラシとして選ぶ',
      );
      final theirs = _referenced(d, 'b');
      for (final (what, brush) in [
        ('quick tool', theirs.quick),
        ('shortcut', theirs.shortcut),
        ('workspace', theirs.workspace),
      ]) {
        p.check(brush == null ? null : (brush.id == x, brush.spacing), (
          false,
          66,
        ), '$stage: もう1台の版を使う$whatは、足した複製（間隔66）を指す');
      }
    }
    p.verify();
  });

  test('a copy added for the other device\'s version keeps the size changed '
      'here, and reading the same file again adds no copy', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final x = await _duplicate(a, 'Brush0002', size: 30);
    final first = await a.export();
    a.brush.updateBrush(
      a.brush.brushes.singleWhere((b) => b.id == x).copyWith(spacing: 33),
    );
    await settleTransfer();
    final second = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    await b.import(first, nextDir());
    b.brush.updateBrush(
      b.brush.brushes.singleWhere((e) => e.id == x).copyWith(spacing: 66),
    );
    await settleTransfer();
    await b.import(second, nextDir());
    final y = b.brush.brushes.singleWhere((e) => e.spacing == 33).id;
    b.brush.selectBrush(y);
    b.brush.updateCurrentBrushSize(12);
    await b.brush.commitRememberedValues();
    await settleTransfer();
    final count = b.brush.brushes.length;
    // 起動し直してから読み直す（前に足した複製は保存から分かる）。
    b = await _resume(await _snapshot());
    final report = TransferImportReport();
    await b.import(second, nextDir(), report: report);

    final p = _Problems();
    p.check(report.addedCopies, isEmpty, '読み直しでは複製を足さない');
    for (final (stage, d) in [
      ('after reading again', b),
      ('restart', await _resume(await _snapshot())),
    ]) {
      p.check(d.brush.brushes.length, count, '$stage: ブラシは増えない');
      p.check(
        d.brush.brushes.singleWhere((e) => e.id == y).size,
        12,
        '$stage: この端末で変えた太さ',
      );
    }
    p.verify();
  });
  test('when both devices duplicated the same brush, reading the other '
      'device\'s file again changes nothing: the quick tool, shortcut, '
      'workspace and current brush keep pointing at the other device\'s '
      'brush, and its copy name takes the next number', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final base = a.brush.brushes.singleWhere((x) => x.id == 'Brush0002').name;
    final xa = await _duplicate(a, 'Brush0002', size: 40);
    await _referTo(a, xa, 'a');
    a.brush.selectBrush(xa);
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final xb = await _duplicate(b, 'Brush0002', size: 25);
    await b.import(bytes, nextDir());
    // この端末で、受け取ったブラシの太さを変えて使う。
    b.brush.selectBrush(xa);
    b.brush.updateCurrentBrushSize(12);
    await b.brush.commitRememberedValues();
    await settleTransfer();
    ({int brushes, int quick, int shortcuts, int workspaces}) counts(
      TransferDevice d,
    ) => (
      brushes: d.brush.brushes.length,
      quick: d.quickTool.entries.length,
      shortcuts: d.shortcut.bindings.length,
      workspaces: d.workspace.presets.length,
    );
    final before = counts(b);
    final report = TransferImportReport();
    await b.import(bytes, nextDir(), report: report);

    final p = _Problems();
    p.check(report.addedCopies, isEmpty, '読み直しでは何も足さない');
    for (final (stage, d) in [
      ('read again', b),
      ('restart', await _resume(await _snapshot())),
    ]) {
      p.check(counts(d), before, '$stage: 何も増えない');
      final theirs = d.brush.brushes.where((x) => x.id == xa).firstOrNull;
      p.check(
        theirs == null ? null : '${theirs.name}|${theirs.size}',
        '${_ja.projectDuplicateNameNumbered(base, 2)}|12.0',
        '$stage: もう1台の複製は「(コピー 2)」（「(コピー) (コピー)」ではない）で、'
            'この端末で変えた太さのまま',
      );
      final mine = d.brush.brushes.where((x) => x.id == xb).firstOrNull;
      p.check(
        mine == null ? null : '${mine.name}|${mine.size}',
        '${_ja.projectDuplicateName(base)}|25.0',
        '$stage: この端末の複製はそのまま',
      );
      final refs = _referenced(d, 'a');
      for (final (what, brush) in [
        ('quick tool', refs.quick),
        ('shortcut', refs.shortcut),
        ('workspace', refs.workspace),
      ]) {
        p.check(brush?.id, xa, '$stage: $whatはもう1台のブラシを指す');
      }
      p.check(d.brush.currentBrush?.id, xa, '$stage: 使うブラシはもう1台のブラシ');
    }
    p.verify();
  });
  test('reading a changed brush again finds the copy added for it before, '
      'not another copy made here that differs only in size, so nothing '
      'that uses the brush is added again', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushPen', 'Pen', null));
    await settleTransfer();
    await _referTo(a, 'BrushPen', 'a');
    final first = await a.export();
    final savedA = await _snapshot();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    await b.import(first, nextDir());
    Brush brushOf(TransferDevice d, String id) =>
        d.brush.brushes.singleWhere((x) => x.id == id);
    b.brush.updateBrush(brushOf(b, 'BrushPen').copyWith(spacing: 66));
    await settleTransfer();
    final savedB = await _snapshot();

    a = await _resume(savedA);
    a.brush.updateBrush(brushOf(a, 'BrushPen').copyWith(spacing: 33));
    await settleTransfer();
    final second = await a.export();

    b = await _resume(savedB);
    await b.import(second, nextDir());
    final added = b.brush.brushes.singleWhere(
      (x) => x.spacing == 33 && x.id != 'BrushPen',
    );
    // この端末でも同じブラシを複製して、間隔を同じにして太さだけ変え、
    // 前に足した複製より前に並べた。
    final own = b.brush.duplicateBrush('BrushPen', name: 'Pen (コピー 2)')!;
    b.brush.updateBrush(brushOf(b, own).copyWith(spacing: 33, size: 50));
    final ownIndex = b.brush.brushes.indexWhere((x) => x.id == own);
    final addedIndex = b.brush.brushes.indexWhere((x) => x.id == added.id);
    b.brush.reorderBrush(ownIndex, addedIndex);
    await settleTransfer();
    final counts = (
      b.brush.brushes.length,
      b.quickTool.entries.length,
      b.shortcut.bindings.length,
      b.workspace.presets.length,
    );
    final report = TransferImportReport();
    await b.import(second, nextDir(), report: report);

    final p = _Problems();
    p.check(report.addedCopies, isEmpty, '読み直しでは何も足さない');
    p.check(
      (
        b.brush.brushes.length,
        b.quickTool.entries.length,
        b.shortcut.bindings.length,
        b.workspace.presets.length,
      ),
      counts,
      '何も増えない',
    );
    p.check(
      [
        for (final e in b.quickTool.entries) e.brushId,
        for (final x in b.shortcut.bindings) x.brushId,
        for (final w in b.workspace.presets)
          for (final e in w.quickToolEntries) e['brushId'],
      ],
      isNot(contains(own)),
      'この端末で作った太さ違いの複製を指す物は無い',
    );
    p.verify();
  });

  test('reading the other device\'s brush again after editing it here adds '
      'the other device\'s version even when this device has its own copy '
      'that differs from it only in size; the current brush is the added '
      'version and nothing that uses the brush points at this device\'s own '
      'copy; reading the file again adds nothing', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushPen', 'Pen', null));
    await settleTransfer();
    await _referTo(a, 'BrushPen', 'a');
    a.brush.selectBrush('BrushPen');
    await settleTransfer();
    final file = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.import(file, nextDir());
    // この端末で太い版を自分で複製して、元のブラシの間隔を変える。
    final thick = await _duplicate(b, 'BrushPen', size: 50);
    b.brush.updateBrush(
      b.brush.brushes
          .singleWhere((x) => x.id == 'BrushPen')
          .copyWith(spacing: 66),
    );
    await settleTransfer();
    final report = TransferImportReport();
    await b.import(file, nextDir(), report: report);

    final p = _Problems();
    final theirs = _ja.projectDuplicateNameNumbered('Pen', 2);
    for (final (stage, d) in [
      ('read again', b),
      ('restart', await _resume(await _snapshot())),
    ]) {
      p.check(_custom(d), [
        '$theirs|17.0|73',
        'Pen (コピー)|50.0|73',
        'Pen|17.0|73',
      ], '$stage: もう1台の版が「(コピー 2)」として届く');
      final added = d.brush.brushes.where((x) => x.name == theirs).firstOrNull;
      p.check(added?.spacing, 12, '$stage: 届いたのはもう1台の間隔');
      p.check(d.brush.currentBrush?.id, added?.id, '$stage: 使うブラシはもう1台の版');
      p.check(
        [
          for (final e in d.quickTool.entries) e.brushId,
          for (final x in d.shortcut.bindings) x.brushId,
          for (final w in d.workspace.presets)
            for (final e in w.quickToolEntries) e['brushId'],
        ],
        isNot(contains(thick)),
        '$stage: この端末で作った太い複製を指す物は無い',
      );
      p.check(
        d.brush.brushes.singleWhere((x) => x.id == thick).size,
        50,
        '$stage: この端末の複製はそのまま',
      );
    }
    p.check(report.addedCopies, contains(theirs), '足した複製を知らせる');
    ({int brushes, int quick, int shortcuts, int workspaces}) counts() => (
      brushes: b.brush.brushes.length,
      quick: b.quickTool.entries.length,
      shortcuts: b.shortcut.bindings.length,
      workspaces: b.workspace.presets.length,
    );
    final before = counts();
    final again = TransferImportReport();
    await b.import(file, nextDir(), report: again);
    p.check(counts(), before, 'もう一度読み直しても増えない');
    p.check(again.addedCopies, isEmpty, 'もう一度読み直しても知らせる複製は無い');
    p.verify();
  });

  test(
    'brushes with the same name moved together keep their names on a '
    'device that has no brush of that name, and nothing is reported',
    () async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final a = await TransferDevice.start();
      a.brush.addBrush(customTransferBrush('BrushX1', 'Pencil X', null));
      a.brush.addBrush(
        customTransferBrush('BrushX2', 'Pencil X', null, size: 9),
      );
      await settleTransfer();
      final file = await a.export();

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final f = await TransferDevice.start();
      final report = TransferImportReport();
      await f.import(file, nextDir(), report: report);
      final p = _Problems();
      p.check(_custom(f), [
        'Pencil X|17.0|73',
        'Pencil X|9.0|73',
      ], 'もう1台と同じ名前のまま');
      p.check(report.addedCopies, isEmpty, 'この端末に同じ名前のブラシは無かった');
      await f.import(file, nextDir());
      p.check(_custom(f), [
        'Pencil X|17.0|73',
        'Pencil X|9.0|73',
      ], '読み直しても増えない');

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final g = await TransferDevice.start();
      g.brush.addBrush(
        customTransferBrush('BrushMine', 'Pencil X', null, size: 3),
      );
      await settleTransfer();
      final ownReport = TransferImportReport();
      await g.import(file, nextDir(), report: ownReport);
      p.check(_custom(g), [
        'Pencil X (コピー 2)|9.0|73',
        'Pencil X (コピー)|17.0|73',
        'Pencil X|3.0|73',
      ], 'この端末に同じ名前のブラシがあれば、番号の違う名前で足す');
      p.check(ownReport.addedCopies, [
        'Pencil X (コピー)',
        'Pencil X (コピー 2)',
      ], '足した複製を知らせる');
      p.verify();
    },
  );

  test('a quick tool and workspace moved with the copy of a brush do not '
      'come again as copies after the other device changes the brush to '
      'this device\'s version', () async {
    // A：自作のブラシをBへ渡す。Bはそれを変える。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushP', 'Pen P', null));
    await settleTransfer();
    final first = await a.export();
    final savedA = await _snapshot();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    await b.import(first, nextDir());
    Brush pen(TransferDevice d) =>
        d.brush.brushes.singleWhere((x) => x.id == 'BrushP');
    b.brush.updateBrush(pen(b).copyWith(spacing: 66));
    await settleTransfer();
    final savedB = await _snapshot();

    // A：そのブラシを使う早替えツール・ワークスペースを作って移す（Bでは
    // Aの版の複製を指す）。
    a = await _resume(savedA);
    await _referTo(a, 'BrushP', 'p');
    final second = await a.export();
    final savedA2 = await _snapshot();
    b = await _resume(savedB);
    await b.import(second, nextDir());
    final p = _Problems();
    final copy = b.brush.brushes.where((x) => x.name == 'Pen P (コピー)');
    p.check(copy.map((x) => x.spacing), [12], 'Aの版を複製として足す');
    p.check(
      _referenced(b, 'p').quick?.id,
      copy.firstOrNull?.id,
      '早替えツールはAの版の複製',
    );
    final savedB2 = await _snapshot();

    // A：ブラシをBと同じにして、変えていない早替えツール・ワークスペースを
    // もう一度移す。
    a = await _resume(savedA2);
    a.brush.updateBrush(pen(a).copyWith(spacing: 66));
    await settleTransfer();
    final third = await a.export();
    b = await _resume(savedB2);
    final report = TransferImportReport();
    await b.import(third, nextDir(), report: report);
    p.check(
      [
        for (final e in b.quickTool.entries)
          if (e.label.startsWith('ref p')) e.label,
      ],
      ['ref p'],
      '早替えツールは増えない',
    );
    p.check(
      [
        for (final w in b.workspace.presets)
          if (w.name.startsWith('Inking p')) w.name,
      ],
      ['Inking p'],
      'ワークスペースは増えない',
    );
    p.check(report.addedCopies, isEmpty, '何も足さないので知らせない');
    p.verify();
  });

  test('a quick tool and workspace whose brush was found here under another '
      'ID are not added again after this device changes its own brush and '
      'the same file is read again', () async {
    // A：自作のブラシと、それを使う早替えツール・ワークスペース。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', null));
    await settleTransfer();
    await _referTo(a, 'BrushInk', 'i');
    final file = await a.export();

    // B：同じ中身・同じ名前のブラシを別のIDで持つ。早替えツール・
    // ワークスペースはBのブラシを指す。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    b.brush.addBrush(customTransferBrush('BrushMine', 'Ink', null));
    await settleTransfer();
    await b.import(file, nextDir());
    final p = _Problems();
    p.check(_custom(b), ['Ink|17.0|73'], '同じブラシは足さない');
    p.check(_referenced(b, 'i').quick?.id, 'BrushMine', '早替えツールはBのブラシ');
    p.check(_referenced(b, 'i').workspace?.id, 'BrushMine', 'ワークスペースはBのブラシ');

    // B：自分のブラシを変えて起動し直し、同じファイルを読み直す。
    b.brush.updateBrush(
      b.brush.brushes
          .singleWhere((x) => x.id == 'BrushMine')
          .copyWith(spacing: 30),
    );
    await settleTransfer();
    b = await _resume(await _snapshot());
    final report = TransferImportReport();
    await b.import(file, nextDir(), report: report);
    p.check(
      [
        for (final e in b.quickTool.entries)
          if (e.label.startsWith('ref i')) e.label,
      ],
      ['ref i'],
      '早替えツールは増えない',
    );
    p.check(
      [
        for (final w in b.workspace.presets)
          if (w.name.startsWith('Inking i')) w.name,
      ],
      ['Inking i'],
      'ワークスペースは増えない',
    );
    p.check(report.addedCopies, ['Ink (コピー)'], 'Aの版のブラシだけを複製として足す');
    p.verify();
  });

  test('quick tools and workspaces whose two brushes were both found here as '
      'one brush under another ID are not added again after this device '
      'changes that brush and the same file is read again', () async {
    // A：同じ中身のブラシが2つ（複製しただけ）と、それぞれを使う早替え
    // ツール・ワークスペース。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', null));
    a.brush.addBrush(customTransferBrush('BrushInk2', 'Ink (コピー)', null));
    await settleTransfer();
    await _referTo(a, 'BrushInk', 'i');
    await _referTo(a, 'BrushInk2', 'a');
    final file = await a.export();

    // B：同じ中身のブラシを別のIDで1つ持つ。Aの2つのブラシはどちらもBの
    // ブラシで、早替えツール・ワークスペースはBのブラシを指す。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    b.brush.addBrush(customTransferBrush('BrushMine', 'Ink', null));
    await settleTransfer();
    await b.import(file, nextDir());
    final p = _Problems();
    p.check(_custom(b), ['Ink|17.0|73'], '同じブラシは足さない');
    for (final tag in ['i', 'a']) {
      p.check(_referenced(b, tag).quick?.id, 'BrushMine', '$tag: 早替えツールはBのブラシ');
      p.check(
        _referenced(b, tag).workspace?.id,
        'BrushMine',
        '$tag: ワークスペースはBのブラシ',
      );
    }

    // B：自分のブラシを変えて起動し直し、同じファイルを読み直す。
    b.brush.updateBrush(
      b.brush.brushes
          .singleWhere((x) => x.id == 'BrushMine')
          .copyWith(spacing: 30),
    );
    await settleTransfer();
    b = await _resume(await _snapshot());
    final report = TransferImportReport();
    await b.import(file, nextDir(), report: report);
    p.check(
      [
        for (final e in b.quickTool.entries)
          if (e.label.startsWith('ref ')) e.label,
      ]..sort(),
      ['ref a', 'ref i'],
      '早替えツールは増えない',
    );
    p.check(
      [
        for (final w in b.workspace.presets)
          if (w.name.startsWith('Inking ')) w.name,
      ]..sort(),
      ['Inking a', 'Inking i'],
      'ワークスペースは増えない',
    );
    p.check(
      report.addedCopies.where((name) => !name.startsWith('Ink (コピー')),
      isEmpty,
      'ブラシのほかは複製として足さない',
    );
    p.verify();
  });

  test(
    'a quick tool and workspace whose brush was found here as one of two '
    'identical brushes of this device are not added again after this '
    'device changes that brush and the same file finds the other one',
    () async {
      // A：自作のブラシと、それを使う早替えツール・ワークスペース。
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final a = await TransferDevice.start();
      a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', null));
      await settleTransfer();
      await _referTo(a, 'BrushInk', 'i');
      final file = await a.export();

      // B：同じ中身のブラシを別のIDで2つ持つ（自分で複製した）。早替え
      // ツール・ワークスペースはBの1つ目のブラシを指す。
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      var b = await TransferDevice.start();
      b.brush.addBrush(customTransferBrush('BrushMine', 'Ink', null));
      b.brush.addBrush(customTransferBrush('BrushMine2', 'Ink (コピー)', null));
      await settleTransfer();
      await b.import(file, nextDir());
      final p = _Problems();
      p.check(_custom(b), ['Ink (コピー)|17.0|73', 'Ink|17.0|73'], '同じブラシは足さない');
      p.check(_referenced(b, 'i').quick?.id, 'BrushMine', '早替えツールはBのブラシ');

      // B：1つ目のブラシを変えて起動し直し、同じファイルを読み直す（Aの
      // ブラシは、同じ中身のままのBの2つ目のブラシ）。
      b.brush.updateBrush(
        b.brush.brushes
            .singleWhere((x) => x.id == 'BrushMine')
            .copyWith(spacing: 30),
      );
      await settleTransfer();
      b = await _resume(await _snapshot());
      final report = TransferImportReport();
      await b.import(file, nextDir(), report: report);
      p.check(_custom(b), ['Ink (コピー)|17.0|73', 'Ink|17.0|73'], 'ブラシは増えない');
      p.check(
        [
          for (final e in b.quickTool.entries)
            if (e.label.startsWith('ref i')) e.label,
        ],
        ['ref i'],
        '早替えツールは増えない',
      );
      p.check(
        [
          for (final w in b.workspace.presets)
            if (w.name.startsWith('Inking i')) w.name,
        ],
        ['Inking i'],
        'ワークスペースは増えない',
      );
      p.check(report.addedCopies, isEmpty, '何も足さないので知らせない');
      p.verify();
    },
  );

  test('a brush of this device that was found to be the other device\'s brush '
      'under another ID is still this device\'s own brush, not a copy the '
      'transfer added: after it is renamed here, reading the same file again '
      'adds the other device\'s brush as before, and the quick tool and '
      'workspace that use it are not added again', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.brush.addBrush(customTransferBrush('BrushInk', 'Ink', null));
    await settleTransfer();
    await _referTo(a, 'BrushInk', 'i');
    final file = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    b.brush.addBrush(customTransferBrush('BrushMine', 'Ink', null));
    await settleTransfer();
    await b.import(file, nextDir());
    final p = _Problems();
    p.check(_custom(b), ['Ink|17.0|73'], '同じブラシは足さない');

    // B：自分のブラシの名前を変えて起動し直し、同じファイルを読み直す。
    b.brush.updateBrush(
      b.brush.brushes
          .singleWhere((x) => x.id == 'BrushMine')
          .copyWith(name: 'My ink'),
    );
    await settleTransfer();
    b = await _resume(await _snapshot());
    final report = TransferImportReport();
    await b.import(file, nextDir(), report: report);
    for (final stage in ['reading again', 'reading once more']) {
      p.check(_custom(b), [
        'Ink|17.0|73',
        'My ink|17.0|73',
      ], '$stage: 名前の違うAのブラシは、Aの名前で1つ足す');
      p.check(
        _referenced(b, 'i').quick?.id,
        'BrushMine',
        '$stage: 早替えツールはBのブラシのまま',
      );
      p.check(
        [
          for (final e in b.quickTool.entries)
            if (e.label.startsWith('ref i')) e.label,
        ],
        ['ref i'],
        '$stage: 早替えツールは増えない',
      );
      p.check(
        [
          for (final w in b.workspace.presets)
            if (w.name.startsWith('Inking i')) w.name,
        ],
        ['Inking i'],
        '$stage: ワークスペースは増えない',
      );
      p.check(report.addedCopies, isEmpty, '$stage: 複製は足さないので知らせない');
      await b.import(file, nextDir(), report: report);
    }
    p.verify();
  });

  test('every ID that the copy records link counts as the same item for '
      'whatever points at it: copies of one item, a copy of a copy, one item '
      'that holds two items of the other device, links both ways', () {
    final record = TransferCopyRecord.none()
      // 複製の複製を先に、その元の複製を後に書き留める。
      ..add('a_copy', 'a_copy_copy')
      ..add('a', 'a_copy')
      ..add('a', 'a_copy_2')
      // この端末の1つの項目が、もう1台の2つの項目の版を持つ。
      ..add('b', 'mine')
      ..add('c', 'mine')
      // 行きと帰りで互いの版を持つ。
      ..add('x', 'y')
      ..add('y', 'x')
      // 名前に番号を付けて足した項目（IDはもう1台のまま）。
      ..add('same', 'same');
    final p = _Problems();
    for (final id in ['a', 'a_copy', 'a_copy_2', 'a_copy_copy']) {
      p.check(record.origin(id), 'a', '$id: 元が1つずつなら、いちばん元の項目');
    }
    p.check(
      {
        for (final id in ['b', 'c', 'mine']) record.origin(id),
      },
      hasLength(1),
      '2つの項目の版を持つ項目と、その2つは同じ項目',
    );
    p.check(
      {
        for (final id in ['x', 'y']) record.origin(id),
      },
      hasLength(1),
      '互いの版を持つ2つは同じ項目',
    );
    p.check(record.origin('same'), 'same', '自分自身の版');
    p.check(record.origin('other'), 'other', '記録に無いIDはそのまま');
    p.check(
      {
        for (final id in ['a', 'b', 'x', 'same', 'other']) record.origin(id),
      },
      hasLength(5),
      'つながらない項目は別の項目',
    );
    p.verify();
  });
}
