import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/workspace_preset_service.dart';
import 'package:niarim/utils/saved_list_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 読めない保存項目は、同じ一覧を編集して保存し直しても失わない（DISC070、
/// 所有者の決定 2026-11-19）。読めた項目は通常どおり使え、読めない項目は
/// 元の文字列のまま一覧の後ろへ残り、起動のたびにもう一度読み込みを試す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'workspace_presets';
  const broken = '{"id": "broken-1", "name": ';
  setUp(SavedListCarryOver.reset);

  Future<List<String>> saved() async =>
      (await SharedPreferences.getInstance()).getStringList(key) ?? const [];

  Future<WorkspacePresetService> start() async {
    final service = WorkspacePresetService();
    await service.init();
    return service;
  }

  test('readSavedJsonList keeps the unreadable raw entries for the list', () {
    final items = readSavedJsonList(
      ['{"a": 1}', broken, '[1, 2]', '{"a": 2}'],
      (json) => json['a'] as int,
      listKey: 'k',
    );
    expect(items, [1, 2]);
    expect(SavedListCarryOver.counts, {'k': 2});
    expect(SavedListCarryOver.keep('k', ['x']), ['x', broken, '[1, 2]']);
    // 次に読んで全部読めたら忘れる（読めるようになった項目は戻る）。
    readSavedJsonList(['{"a": 3}'], (json) => json['a'] as int, listKey: 'k');
    expect(SavedListCarryOver.total, 0);
    expect(SavedListCarryOver.keep('k', ['x']), ['x']);
  });

  test(
    'mixed list: readable presets work, editing and saving keeps the '
    'unreadable entry, a restart keeps it, and it comes back once readable',
    () async {
      // 正常な2件を保存してから、読めない1件を間に入れる。
      SharedPreferences.setMockInitialValues({});
      var service = await start();
      await service.save('A', isLeftHanded: false, forcePcMode: null);
      await service.save('B', isLeftHanded: true, forcePcMode: true);
      final good = await saved();
      expect(good, hasLength(2));
      SharedPreferences.setMockInitialValues({
        key: [good[0], broken, good[1]],
      });

      // 読み込み：読めた2件は使え、読めない1件は覚えている。
      service = await start();
      expect(service.presets.map((p) => p.name), ['A', 'B']);
      expect(SavedListCarryOver.counts, {key: 1});

      // 編集・保存：名前を変え、1件を消し、1件を足しても読めない項目は残る。
      await service.rename(service.presets.first.id, 'A2');
      await service.delete(service.presets.last.id);
      await service.save('C', isLeftHanded: false, forcePcMode: false);
      expect(await saved(), contains(broken));
      expect(await saved(), hasLength(3));

      // 再起動：読めた分は編集の後のまま、読めない項目も残る。
      final afterEdit = await saved();
      SavedListCarryOver.reset();
      SharedPreferences.setMockInitialValues({key: afterEdit});
      service = await start();
      expect(service.presets.map((p) => p.name), ['A2', 'C']);
      expect(SavedListCarryOver.counts, {key: 1});
      await service.rename(service.presets.last.id, 'C2');
      expect(await saved(), contains(broken));

      // 復旧の再試行：元のデータが読める形になれば（更新で直った等）、次の
      // 起動で一覧へ戻り、覚えていた分は消える。
      final repaired = jsonEncode({
        ...jsonDecode(afterEdit.first) as Map<String, dynamic>,
        'id': 'recovered',
        'name': 'Recovered',
      });
      final withRepair = [
        for (final entry in await saved()) entry == broken ? repaired : entry,
      ];
      SavedListCarryOver.reset();
      SharedPreferences.setMockInitialValues({key: withRepair});
      service = await start();
      expect(service.presets.map((p) => p.name), contains('Recovered'));
      expect(SavedListCarryOver.total, 0);
    },
  );
}
