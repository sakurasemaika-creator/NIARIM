import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/utils/filter_display_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）の描画フィルター（端末保存データ）は、ほかの一覧と
/// 同じ決まりで合わせる：
/// - 組み込みのフィルターの値は使うたびに変わる最後に使った値なので、
///   この端末で出荷時のままならもう1台で変えた値にし、この端末でも変えて
///   いればこの端末の値のまま（複製は足さない。両方で使っていると、
///   行き来するたびに同じ名前のフィルターが増えた）。
/// - もう1台で複製したフィルターを後でもう1台で変えたら、この端末の版を
///   残してもう1台の版を足す（同じIDだからと捨てない）。足した複製は、
///   フィルターの一覧でも知らせと同じ「(コピー)」の付いた名前で出る。
/// - 同じファイルを読み直しても何も変わらない。

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

/// 種類ごとの強さ（並び順は問わない）。組み込みは「ID:強さ」、自作は
/// 「custom 種類:強さ」。
List<String> _strengths(TransferDevice d, Iterable<FilterKind> kinds) => [
  for (final f in d.filter.filters)
    if (kinds.contains(f.kind))
      d.filter.isBuiltIn(f.id)
          ? '${f.id}:${f.strength}'
          : 'custom ${f.kind.name}:${f.strength}',
]..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_draw_filters_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  const blurs = [FilterKind.gaussianBlur, FilterKind.lensBlur];

  test('a built-in filter tuned on the other device takes those values where '
      'it is as shipped here; where both devices tuned it, this device keeps '
      'its values and no copy is added; a custom filter changed later over '
      'there arrives as a copy shown in the filter list under the name the '
      'import reported; reading the same file again changes nothing', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.filter.updateFilterParams('Filter0001', strength: 42);
    a.filter.duplicateFilter('Filter0001');
    final custom = a.filter.filters.singleWhere(
      (f) => !a.filter.isBuiltIn(f.id),
    );
    a.filter.updateFilterParams(custom.id, strength: 77);
    a.filter.updateFilterParams('Filter0002', strength: 30);
    await settleTransfer();
    final first = await a.export();
    final savedA = await _snapshot();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    var b = await TransferDevice.start();
    b.filter.updateFilterParams('Filter0002', strength: 20);
    await settleTransfer();
    final report = TransferImportReport();
    await b.import(first, nextDir(), report: report);

    final p = _Problems();
    final afterFirst = [
      'Filter0001:42.0',
      'Filter0002:20.0',
      'custom gaussianBlur:77.0',
    ];
    p.check(
      _strengths(b, blurs),
      afterFirst,
      '出荷時のままの組み込みはもう1台の値、両方で変えた組み込みは'
      'この端末の値のまま（複製は足さない）',
    );
    p.check(report.addedCopies, isEmpty, '組み込みの複製は足さない');
    final again = TransferImportReport();
    await b.import(first, nextDir(), report: again);
    p.check(_strengths(b, blurs), afterFirst, '読み直しても変わらない');
    p.check(again.addedCopies, isEmpty, '読み直しでは知らせる複製が無い');

    // もう1台が複製したフィルターを後で変える。
    final savedB = await _snapshot();
    final aLater = await _resume(savedA);
    aLater.filter.updateFilterParams(custom.id, strength: 5);
    await settleTransfer();
    final second = await aLater.export();
    b = await _resume(savedB);
    final later = TransferImportReport();
    await b.import(second, nextDir(), report: later);
    final afterSecond = [...afterFirst, 'custom gaussianBlur:5.0']..sort();
    p.check(
      _strengths(b, blurs),
      afterSecond,
      'もう1台で後から変えた自作のフィルターは、この端末の版を残して足す',
    );
    final copyName = _ja.projectDuplicateName(_ja.filterNameGaussianBlur);
    p.check(later.addedCopies, [copyName], '足した複製を知らせる');
    p.check(
      [
        for (final f in b.filter.filters)
          if (f.kind == FilterKind.gaussianBlur)
            '${filterDisplayName(_ja, f)}:${f.strength}',
      ],
      [
        '${_ja.filterNameGaussianBlur}:42.0',
        '${_ja.filterNameGaussianBlur}:77.0',
        '$copyName:5.0',
      ],
      'フィルターの一覧では、複製は知らせと同じ名前で出る（元のフィルターは'
      'そのまま）',
    );
    await b.import(second, nextDir());
    p.check(_strengths(b, blurs), afterSecond, '読み直しても変わらない');
    final restarted = await _resume(await _snapshot());
    p.check(_strengths(restarted, blurs), afterSecond, '起動し直しても');
    p.verify();
  });

  test('a filter the other device left as shipped does not replace values '
      'tuned here, and the noise style profiles kept for the Noise tile stay '
      'this device\'s', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.filter.updateFilterParams(FilterService.filmGrainFilterId, strength: 90);
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.filter.updateFilterParams('Filter0001', strength: 11);
    await settleTransfer();
    final prefs = await SharedPreferences.getInstance();
    List<FilterDef> saved() => [
      for (final raw in prefs.getStringList('draw_filters')!)
        FilterDef.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    ];
    final grain = saved()
        .singleWhere((f) => f.id == FilterService.filmGrainFilterId)
        .strength;
    final count = saved().length;
    final report = TransferImportReport();
    await b.import(bytes, nextDir(), report: report);

    final p = _Problems();
    p.check(
      b.filter.filters.singleWhere((f) => f.id == 'Filter0001').strength,
      11,
      'この端末で変えた値のまま',
    );
    p.check(
      saved()
          .singleWhere((f) => f.id == FilterService.filmGrainFilterId)
          .strength,
      grain,
      'ノイズの種類ごとの設定はこの端末のまま',
    );
    p.check(saved().length, count, '何も足さない');
    p.check(report.addedCopies, isEmpty, '知らせる複製が無い');
    p.verify();
  });

  test('an older file\'s filter saved before a settings update is read the '
      'way this device reads its own save', () async {
    // 以前の版の保存（プリズムの既定値が古い）を、この端末は今の既定で読む。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final prism = b.filter.filters.singleWhere(
      (f) => f.id == FilterService.prismFilterId,
    );
    final old = prism.copyWith(prismBlurPx: 8, prismDirectionDegrees: 45);
    final data = NiatraData({
      'localPreferences': {
        'draw_filters': [jsonEncode(old.toJson())],
      },
    }, Archive());
    final count = b.filter.filters.length;
    final report = TransferImportReport();
    await b.importData(data, nextDir(), report: report);
    final now = b.filter.filters.singleWhere(
      (f) => f.id == FilterService.prismFilterId,
    );
    expect(
      (now.prismBlurPx, now.prismDirectionDegrees),
      (prism.prismBlurPx, prism.prismDirectionDegrees),
    );
    expect(b.filter.filters.length, count);
    expect(report.addedCopies, isEmpty);
  });

  test('a built-in filter used on both devices with different values does '
      'not add copies, however often the devices are synced', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a0 = await TransferDevice.start();
    a0.filter.updateFilterParams('Filter0001', strength: 33);
    await settleTransfer();
    var savedA = await _snapshot();
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b0 = await TransferDevice.start();
    b0.filter.updateFilterParams('Filter0001', strength: 77);
    await settleTransfer();
    var savedB = await _snapshot();
    final count = b0.filter.filters.length;

    final p = _Problems();
    // 使う → もう1台へ移す、を繰り返す。
    for (final (step, from, value) in [
      (1, 'A', 33.0),
      (2, 'A', 50.0),
      (3, 'B', 60.0),
      (4, 'A', 45.0),
    ]) {
      final fromA = from == 'A';
      final source = await _resume(fromA ? savedA : savedB);
      source.filter.updateFilterParams('Filter0001', strength: value);
      await settleTransfer();
      final bytes = await source.export();
      if (fromA) {
        savedA = await _snapshot();
      } else {
        savedB = await _snapshot();
      }
      final target = await _resume(fromA ? savedB : savedA);
      final keep = target.filter.filters
          .singleWhere((f) => f.id == 'Filter0001')
          .strength;
      final report = TransferImportReport();
      await target.import(bytes, nextDir(), report: report);
      p.check(
        [
          for (final f in target.filter.filters)
            if (f.kind == FilterKind.gaussianBlur) f.strength,
        ],
        [keep],
        'step $step: ガウスぼかしは1つのまま、この端末の値',
      );
      p.check(target.filter.filters.length, count, 'step $step: 増えない');
      p.check(report.addedCopies, isEmpty, 'step $step: 知らせる複製が無い');
      if (fromA) {
        savedB = await _snapshot();
      } else {
        savedA = await _snapshot();
      }
    }
    final a = await _resume(savedA);
    final b = await _resume(savedB);
    p.check(
      [
        for (final d in [a, b])
          d.filter.filters
              .where((f) => f.kind == FilterKind.gaussianBlur)
              .length,
      ],
      [1, 1],
      'どちらの端末も、ガウスぼかしは1つ',
    );
    p.verify();
  });
}
