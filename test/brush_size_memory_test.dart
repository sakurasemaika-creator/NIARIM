import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// キャンバスのスライダー・数値入力で変えた太さ・不透明度を、ブラシごとに
/// 覚える。別のブラシへ切り替えて戻っても、アプリを起動し直しても同じ値で、
/// ブラシの一覧にもその値が出る。組み込みのブラシでも同じ（定義そのものは
/// 起動のたびに最新へそろえるので、利用者が変えた値は定義と分けて残す）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BrushService> started() async {
    final service = BrushService();
    await service.init();
    return service;
  }

  test(
    'a built-in brush keeps the size and opacity set on the canvas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await started();
      s.selectBrush('Brush0002');
      final original = s.currentBrush!;
      final size = original.size + 7;
      final opacity = original.opacity == 37 ? 41 : 37;

      s.updateCurrentBrushSize(size);
      s.updateCurrentBrushOpacity(opacity);
      s.selectBrush('Brush0001');
      s.selectBrush('Brush0002');
      expect(s.currentBrush!.size, size, reason: '別のブラシから戻っても同じ太さ');
      expect(s.currentBrush!.opacity, opacity);
      final listed = s.brushes.firstWhere((b) => b.id == 'Brush0002');
      expect(listed.size, size, reason: '一覧にも出る');
      expect(listed.opacity, opacity);
      // 他のブラシは変わらない。
      final other = BrushService();
      SharedPreferences.setMockInitialValues({});
      await other.init();
      for (final b in s.brushes) {
        if (b.id == 'Brush0002') continue;
        final fresh = other.brushes.firstWhere((o) => o.id == b.id);
        expect(b.size, fresh.size, reason: b.id);
        expect(b.opacity, fresh.opacity, reason: b.id);
      }
    },
  );

  test('the remembered values survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await started();
    s.selectBrush('Brush0003');
    final builtInSize = s.currentBrush!.size + 11;
    s.updateCurrentBrushSize(builtInSize);
    s.updateCurrentBrushOpacity(23);
    final copy = s.duplicateBrush('Brush0001', name: 'mine')!;
    s.selectBrush(copy);
    s.updateCurrentBrushSize(64);
    s.updateCurrentBrushOpacity(55);
    await s.commitRememberedValues();

    final again = await started();
    expect(again.currentBrush!.id, copy);
    expect(again.currentBrush!.size, 64);
    expect(again.currentBrush!.opacity, 55);
    final builtIn = again.brushes.firstWhere((b) => b.id == 'Brush0003');
    expect(builtIn.size, builtInSize, reason: '組み込みのブラシも起動し直して同じ');
    expect(builtIn.opacity, 23);
    again.selectBrush('Brush0003');
    expect(again.currentBrush!.size, builtInSize);
  });

  test(
    'built-in definitions still refresh; only touched values are kept',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await started();
      final definition2 = s.brushes.firstWhere((b) => b.id == 'Brush0002');
      final definition3 = s.brushes.firstWhere((b) => b.id == 'Brush0003');
      s.selectBrush('Brush0002');
      s.updateCurrentBrushSize(definition2.size + 5);
      await s.commitRememberedValues();

      // 以前の版が保存した組み込みブラシの定義（名前・太さ・間隔）が古い。
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('brushes')!.map((e) {
        final json = jsonDecode(e) as Map<String, dynamic>;
        if (json['id'] == 'Brush0002' || json['id'] == 'Brush0003') {
          json['name'] = 'old name';
          json['spacing'] = 77;
        }
        if (json['id'] == 'Brush0003') json['size'] = 99.0;
        return jsonEncode(json);
      }).toList();
      await prefs.setStringList('brushes', stored);

      final again = await started();
      final two = again.brushes.firstWhere((b) => b.id == 'Brush0002');
      final three = again.brushes.firstWhere((b) => b.id == 'Brush0003');
      expect(two.name, definition2.name, reason: '定義は最新へそろう');
      expect(two.spacing, definition2.spacing);
      expect(two.size, definition2.size + 5, reason: '利用者が変えた太さは残る');
      expect(two.opacity, definition2.opacity, reason: '変えていない不透明度は定義のまま');
      expect(three.name, definition3.name);
      expect(three.size, definition3.size, reason: '触っていない組み込みブラシは定義の太さ');
    },
  );

  test(
    'quick tools and automation do not overwrite what a brush remembers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await started();
      s.selectBrush('Brush0002');
      final remembered = s.currentBrush!.size + 4;
      s.updateCurrentBrushSize(remembered);
      s.updateCurrentBrushOpacity(60);

      // 早替えツール・自動操作の再生が一時的に当てる値。
      s.updateCurrentBrushSize(120, remember: false);
      s.updateCurrentBrushOpacity(15, remember: false);
      expect(s.currentBrush!.size, 120, reason: 'いま描く太さには効く');
      expect(s.currentBrush!.opacity, 15);
      expect(
        s.brushes.firstWhere((b) => b.id == 'Brush0002').size,
        remembered,
        reason: '覚えている値はそのまま',
      );
      s.selectBrush('Brush0001');
      s.selectBrush('Brush0002');
      expect(s.currentBrush!.size, remembered);
      expect(s.currentBrush!.opacity, 60);
      await s.commitRememberedValues();
      final again = await started();
      expect(again.currentBrush!.size, remembered);
      expect(again.currentBrush!.opacity, 60);
    },
  );

  test('a slider drag is saved once, when it ends', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await started();
    final copy = s.duplicateBrush('Brush0001', name: 'mine')!;
    s.selectBrush(copy);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    double storedSize() =>
        (prefs
                    .getStringList('brushes')!
                    .map((e) => jsonDecode(e) as Map<String, dynamic>)
                    .firstWhere((j) => j['id'] == copy)['size']
                as num)
            .toDouble();
    final before = storedSize();
    for (var size = 10.0; size <= 200; size += 1) {
      s.updateCurrentBrushSize(size);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(storedSize(), before, reason: '動かしている間は保存しない');
    expect(s.currentBrush!.size, 200, reason: '描く太さはすぐ変わる');
    await s.commitRememberedValues();
    expect(storedSize(), 200, reason: '操作の終わりに保存する');

    // 保存を呼び忘れても、ブラシの切り替え・破棄で落とさない。
    s.updateCurrentBrushSize(33);
    s.selectBrush('Brush0001');
    await Future<void>.delayed(Duration.zero);
    expect(storedSize(), 33);
    s.selectBrush(copy);
    s.updateCurrentBrushSize(34);
    s.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(storedSize(), 34);
  });

  test(
    'a built-in set back to its default follows the definition again',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await started();
      s.selectBrush('Brush0002');
      final definition = s.currentBrush!;
      s.updateCurrentBrushSize(definition.size + 9);
      s.updateCurrentBrushOpacity(definition.opacity == 50 ? 51 : 50);
      await s.commitRememberedValues();
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? working() {
        final raw = prefs.getString('brush_builtin_working_values');
        return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      }

      expect(working()!['Brush0002'], {
        'size': definition.size + 9,
        'opacity': definition.opacity == 50 ? 51 : 50,
      });
      // 太さだけ既定へ戻す：不透明度だけを覚える。
      s.updateCurrentBrushSize(definition.size);
      await s.commitRememberedValues();
      expect(working()!['Brush0002'], {
        'opacity': definition.opacity == 50 ? 51 : 50,
      });
      // 両方戻したら覚えから外す。
      s.updateCurrentBrushOpacity(definition.opacity);
      await s.commitRememberedValues();
      expect(working(), isNull);
    },
  );

  test('values that are not numbers are ignored, not applied', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await started();
    s.selectBrush('Brush0002');
    final size = s.currentBrush!.size;
    s.updateCurrentBrushSize(double.nan);
    s.updateCurrentBrushSize(double.infinity);
    s.updateCurrentBrushSize(0);
    s.updateCurrentBrushSize(-3);
    expect(s.currentBrush!.size, size);
    s.updateCurrentBrushOpacity(250);
    expect(s.currentBrush!.opacity, 100);
    s.updateCurrentBrushOpacity(-4);
    expect(s.currentBrush!.opacity, 0);
  });

  for (final (name, stored) in <(String, Object)>[
    ('cut-off text', '{"Brush0002": {"size"'),
    ('a list', '[1, 2]'),
    ('another type', 7),
    (
      'bad entries',
      jsonEncode({
        'Brush0002': {'size': 'wide', 'opacity': 44},
        'Brush0003': 12,
        'Brush0004': {'size': -1},
        'gone': {'size': 9},
        'Brush0005': {'size': 21.5, 'opacity': 900},
      }),
    ),
  ]) {
    test('a damaged saved value ($name) does not stop start-up', () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = await started();
      final defaults = {for (final b in fresh.brushes) b.id: b};
      SharedPreferences.setMockInitialValues({
        'brush_builtin_working_values': stored,
      });
      final s = await started();
      expect(s.brushes.length, fresh.brushes.length);
      final two = s.brushes.firstWhere((b) => b.id == 'Brush0002');
      final five = s.brushes.firstWhere((b) => b.id == 'Brush0005');
      expect(two.size, defaults['Brush0002']!.size, reason: '数でない太さは使わない');
      if (name == 'bad entries') {
        expect(two.opacity, 44, reason: '読める項目は使う');
        expect(five.size, 21.5);
        expect(five.opacity, 100, reason: '範囲に収める');
        expect(
          s.brushes.firstWhere((b) => b.id == 'Brush0004').size,
          defaults['Brush0004']!.size,
        );
        final prefs = await SharedPreferences.getInstance();
        final cleaned =
            jsonDecode(prefs.getString('brush_builtin_working_values')!)
                as Map<String, dynamic>;
        expect(cleaned.keys, unorderedEquals(['Brush0002', 'Brush0005']));
      } else {
        expect(two.opacity, defaults['Brush0002']!.opacity);
      }
    });
  }
}
