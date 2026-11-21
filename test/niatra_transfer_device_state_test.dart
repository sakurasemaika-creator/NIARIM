import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）の端末保存データが、この端末だけの記録・この端末で
/// 決めたこと・この端末の履歴を、もう1台の物で置き換えないこと：
/// - 購入日・作品広場の節目の知らせ・制作時間の未確認分・端末の性能の判定は
///   この端末の記録のまま（1つの値やアカウントごとの値でも）。
/// - もう1台で出荷時のまま（触っていない）の公式の自動操作・最初からある
///   早替えツール・ショートカットは、この端末で消していれば戻さず、複製にも
///   しない。
/// - 作品のミュートと「いつも表示」は、この端末で決めた方を使う。
/// - もう1台のお気に入りは、もう1台の自動操作（複製として足した方）に付く。
/// - 描画フィルターのカラーノイズの設定はこの端末のまま。
/// - 最近使った色は、この端末の色を先に残し、空きにだけもう1台の色を入れる。

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

/// 端末保存データだけを持つファイル。
NiatraData _deviceData(Map<String, Object> local) =>
    NiatraData({'localPreferences': local}, Archive());

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

CustomAutomation _automation(String id, String name, String command) =>
    CustomAutomation(
      id: id,
      name: name,
      steps: [
        CustomAutomationStep(
          id: '${command}_step',
          surface: CustomAutomationSurface.canvas,
          command: command,
          label: command,
        ),
      ],
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 3),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_device_state_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('device data keeps this device\'s purchase date, community milestone '
      'notifications, unverified creator time and capability check, and '
      'does not export them', () async {
    Map<String, Object> records(String who, int seconds, int date) => {
      'community.milestone.v1.acc': '{"events":[{"id":"$who-event"}]}',
      'creator_edit_unverified_seconds_v1_acc': seconds,
      'premium_purchase_date': date,
      'default_preset': who == 'A' ? 'high' : 'low',
    };
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      ...records('A', 100, 111),
    });
    final a = await TransferDevice.start();
    final bytes = await a.export();
    final local =
        NiatraSerializer.loadFromBytes(bytes).raw['localPreferences'] as Map;

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      ...records('B', 5000, 222),
    });
    final b = await TransferDevice.start();
    await b.import(bytes, nextDir());

    final prefs = await SharedPreferences.getInstance();
    final p = _Problems();
    for (final entry in records('B', 5000, 222).entries) {
      p.check(
        local.containsKey(entry.key),
        isFalse,
        '${entry.key}: この端末の記録なので書き出さない',
      );
      p.check(prefs.get(entry.key), entry.value, '${entry.key}: この端末の記録のまま');
    }
    // 古いファイル（記録を書き出していた版）を読んでも書かない。
    await NiatraSerializer.restoreLocalPreferences(
      _deviceData(records('A', 100, 111)),
    );
    for (final entry in records('B', 5000, 222).entries) {
      p.check(prefs.get(entry.key), entry.value, '${entry.key}: 古いファイルからも書かない');
    }
    p.verify();
  });

  test('device data writes only the settings it knows: a saved value the '
      'app does not classify is neither exported nor written, and a list '
      'saved as a single value is not written', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'bucket_tolerance': 42.0,
      'some_unknown_record_v9': 'A',
    });
    final a = await TransferDevice.start();
    final bytes = await a.export();
    final local =
        NiatraSerializer.loadFromBytes(bytes).raw['localPreferences'] as Map;
    expect(local['bucket_tolerance'], 42.0);
    expect(local.containsKey('some_unknown_record_v9'), isFalse);

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'some_unknown_record_v9': 'B',
      'toolbar_order': ['pen', 'eraser'],
    });
    final b = await TransferDevice.start();
    final layouts = b.workspace.presets.length;
    await NiatraSerializer.restoreLocalPreferences(
      _deviceData({
        'bucket_tolerance': 7.0,
        'some_unknown_record_v9': 'A',
        // 一覧の保存に1つの値が入った壊れたファイル。
        'workspace_presets': 'not a list',
        'toolbar_order': 'pen',
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('bucket_tolerance'), 7.0, reason: '設定は移す');
    expect(prefs.getString('some_unknown_record_v9'), 'B');
    expect(prefs.get('toolbar_order'), ['pen', 'eraser']);
    expect(prefs.get('workspace_presets'), isNot(isA<String>()));
    final restarted = await _resume(await _snapshot());
    expect(restarted.workspace.presets.length, layouts);
  });

  test('an official automation preset and a default quick tool deleted on '
      'this device stay deleted when the other device left them as shipped, '
      'after a restart and a second import', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.automation.delete('builtin_draft_to_lineart');
    b.quickTool.removeEntry('qt3');
    await settleTransfer();
    var device = await _resume(await _snapshot());
    final p = _Problems();
    p.check(
      device.automation.items.map((e) => e.id),
      isNot(contains('builtin_draft_to_lineart')),
      'before: 消した公式の自動操作は起動し直しても戻らない',
    );
    for (final round in ['first', 'second']) {
      final report = TransferImportReport();
      await device.import(bytes, nextDir(), report: report);
      device = await _resume(await _snapshot());
      p.check(
        device.automation.items.map((e) => e.id),
        isNot(contains('builtin_draft_to_lineart')),
        '$round import: 消した公式の自動操作は戻らない',
      );
      p.check(
        device.automation.items.map((e) => e.name),
        isNot(contains(startsWith('線画作成（デジタル）'))),
        '$round import: 複製にもしない',
      );
      p.check(
        device.quickTool.entries.map((e) => e.id),
        isNot(contains('qt3')),
        '$round import: 消した早替えツールは戻らない',
      );
      p.check(report.addedCopies, isEmpty, '$round import: 複製は無い');
    }
    p.verify();
  });

  test('a default shortcut deleted on this device stays deleted when the '
      'other device left it as shipped, and a default the other device '
      'changed still comes', () async {
    // もう1台はやり直し（Ctrl+Y）をCtrl+Uへ変え、ほかの既定は触っていない。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final redo = a.shortcut.bindings.singleWhere((e) => e.id == 'default_redo');
    a.shortcut.updateBinding(
      ShortcutBinding.fromJson({
        ...redo.toJson(),
        'keyId': LogicalKeyboardKey.keyU.keyId,
      }),
    );
    await settleTransfer();
    final bytes = await a.export();

    // この端末は取り消し（Ctrl+Z）をCtrl+Jの自分の割り当てに替え、
    // Shift付きのやり直しとやり直しを消した。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.shortcut.removeBinding('default_undo');
    b.shortcut.removeBinding('default_redo_shift');
    b.shortcut.removeBinding('default_redo');
    b.shortcut.addBinding(
      ShortcutBinding(
        id: 'my_undo',
        label: 'my undo',
        keyId: LogicalKeyboardKey.keyJ.keyId,
        control: true,
        command: ShortcutCommand.undo,
      ),
    );
    await settleTransfer();
    var device = await _resume(await _snapshot());
    final p = _Problems();
    for (final round in ['first', 'second']) {
      await device.import(bytes, nextDir());
      device = await _resume(await _snapshot());
      final ids = device.shortcut.bindings.map((e) => e.id).toList();
      p.check(
        ids,
        isNot(contains('default_redo_shift')),
        '$round import: 消した既定（もう1台で出荷時のまま）は戻らない',
      );
      p.check(
        ids,
        isNot(contains('default_undo')),
        '$round import: Ctrl+Zの取り消しは戻らない',
      );
      p.check(
        device.shortcut.bindings
            .where((e) => e.id == 'default_redo')
            .map((e) => e.keyId),
        [LogicalKeyboardKey.keyU.keyId],
        '$round import: もう1台で変えた既定は届く',
      );
      p.check(
        ids.where((e) => e == 'my_undo').length,
        1,
        '$round import: この端末の割り当てはそのまま',
      );
    }
    p.verify();
  });

  test('an official automation preset the other device left as shipped '
      '(an older app version\'s recipe) adds no copy when this device '
      'renamed its own', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.automation.rename('builtin_draft_to_lineart', 'my lineart');
    final count = b.automation.items.length;
    final shipped = CustomAutomationBuiltinPresets.all().firstWhere(
      (e) => e.id == 'builtin_draft_to_lineart',
    );
    // 古い版の手順（1つだけ）で、出荷時の日付のまま。
    final older = shipped.copyWith(steps: [shipped.steps.first]);
    expect(older.updatedAt.millisecondsSinceEpoch, 0);
    final report = TransferImportReport();
    await b.importData(
      _deviceData({
        'custom_automations_v1': [jsonEncode(older.toJson())],
      }),
      nextDir(),
      report: report,
    );
    final p = _Problems();
    p.check(b.automation.items.length, count, '複製を足さない');
    p.check(report.addedCopies, isEmpty, '複製を知らせない');
    p.check(
      b.automation.items
          .where((e) => e.id == 'builtin_draft_to_lineart')
          .map((e) => e.name),
      ['my lineart'],
      'この端末で変えた名前のまま',
    );
    p.verify();
  });

  test('a work muted on this device stays muted when the other device '
      'always shows it, and the other device\'s choice is used for works '
      'this device has not decided', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'community.mutedWorks.v1': ['W', 'onlyA'],
      'community.alwaysVisibleWorks.v1': ['V'],
    });
    final a = await TransferDevice.start();
    final bytes = await a.export();
    // もう1台では、Wをいつも表示、Vをミュートにしていた。
    final local =
        NiatraSerializer.loadFromBytes(bytes).raw['localPreferences']
            as Map<String, dynamic>;
    // （両方に入った作品は、もう1台でも決まっていないのでどちらにも足さない）
    local['community.mutedWorks.v1'] = ['V', 'onlyA', 'both'];
    local['community.alwaysVisibleWorks.v1'] = ['W', 'shownA', 'both'];

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'community.mutedWorks.v1': ['W'],
      'community.alwaysVisibleWorks.v1': ['V'],
    });
    await TransferDevice.start();
    final community = CommunityService();
    await community.contentFiltersReady;
    await NiatraSerializer.restoreLocalPreferences(_deviceData({...local}));
    await community.reloadLocalContentFilters();
    final prefs = await SharedPreferences.getInstance();
    final muted = prefs.getStringList('community.mutedWorks.v1')!.toSet();
    final shown = prefs
        .getStringList('community.alwaysVisibleWorks.v1')!
        .toSet();
    final p = _Problems();
    p.check(community.isWorkExplicitlyMuted('W'), isTrue, 'W: この端末のミュート');
    p.check(shown, isNot(contains('W')), 'W: いつも表示に足さない');
    p.check(muted, isNot(contains('V')), 'V: この端末のいつも表示のまま');
    p.check(muted, contains('onlyA'), 'もう1台だけのミュートは足す');
    p.check(shown, contains('shownA'), 'もう1台だけのいつも表示は足す');
    p.check(muted.intersection(shown), isEmpty, '両方に入る作品は無い');
    p.check([...muted, ...shown], isNot(contains('both')), 'もう1台で両方なら足さない');
    community.dispose();
    p.verify();
  });

  test('the other device\'s favourite goes to the copy of its automation, '
      'not to this device\'s different automation with the same id, also '
      'when it was favourited after the copy came over, and reading the '
      'file again changes nothing', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'custom_automations_v1': [
        jsonEncode(_automation('automation_same', 'Auto', 'canvas.a').toJson()),
      ],
    });
    final a = await TransferDevice.start();
    final before = await a.export();
    await a.automation.toggleFavorite('automation_same');
    final favourited = await a.export();

    final p = _Problems();
    for (final (stage, bytes) in [
      ('favourited over there', favourited),
      ('copy first, favourited later', before),
    ]) {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'custom_automations_v1': [
          jsonEncode(
            _automation('automation_same', 'Auto', 'canvas.b').toJson(),
          ),
        ],
      });
      var device = await TransferDevice.start();
      await device.import(bytes, nextDir());
      if (bytes == before) {
        // 複製が来た後で、もう1台でお気に入りにしたファイルを読む。
        device = await _resume(await _snapshot());
        await device.import(favourited, nextDir());
      }
      final copy = device.automation.items
          .where((e) => e.name == 'Auto (コピー)')
          .firstOrNull;
      p.check(copy, isNotNull, '$stage: もう1台の自動操作は複製として足す');
      p.check(
        device.automation.isFavorite('automation_same'),
        isFalse,
        '$stage: この端末の自動操作はお気に入りにしない',
      );
      if (copy != null) {
        p.check(
          device.automation.isFavorite(copy.id),
          isTrue,
          '$stage: 複製がもう1台のお気に入り',
        );
      }
      final favourites = {...device.automation.favoriteIds};
      final items = device.automation.items.length;
      await device.import(favourited, nextDir());
      final again = await _resume(await _snapshot());
      p.check(again.automation.items.length, items, '$stage: 読み直しても増えない');
      p.check(
        again.automation.favoriteIds,
        favourites,
        '$stage: 読み直してもお気に入りは同じ',
      );
    }
    p.verify();
  });

  test('a favourite on the other device\'s copy of an automation this '
      'device has with the same steps goes to this device\'s one (no copy '
      'is added)', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'custom_automations_v1': [
        jsonEncode(_automation('automation_x', 'X', 'canvas.x').toJson()),
      ],
    });
    final b = await TransferDevice.start();
    final count = b.automation.items.length;
    await b.importData(
      _deviceData({
        'custom_automations_v1': [
          jsonEncode(
            _automation('automation_y', 'X (コピー)', 'canvas.x').toJson(),
          ),
        ],
        'custom_automation_favorites_v1': ['automation_y'],
      }),
      nextDir(),
    );
    expect(b.automation.items.length, count);
    expect(b.automation.isFavorite('automation_x'), isTrue);
  });

  test('the colour noise settings of the draw filters stay this device\'s, '
      'whether or not the file adds a filter, after a restart', () async {
    for (final duplicate in [false, true]) {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final a = await TransferDevice.start();
      if (duplicate) a.filter.duplicateFilter(a.filter.filters.first.id);
      await settleTransfer();
      final aPrefs = await SharedPreferences.getInstance();
      await aPrefs.setString('draw_filter_noise_color_profile', 'A-profile');
      final bytes = await a.export();

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final b = await TransferDevice.start();
      // この端末のカラーノイズの設定を保存しておく（フィルターの一覧を
      // 保存すると一緒に書かれる）。
      b.filter.toggleFavorite(b.filter.filters.last.id);
      b.filter.toggleFavorite(b.filter.filters.last.id);
      await settleTransfer();
      final bPrefs = await SharedPreferences.getInstance();
      final mine = bPrefs.getString('draw_filter_noise_color_profile');
      expect(mine, isNotNull);
      await b.import(bytes, nextDir());
      expect(
        bPrefs.getString('draw_filter_noise_color_profile'),
        mine,
        reason: 'duplicate=$duplicate: この端末のカラーノイズの設定のまま',
      );
      await _resume(await _snapshot());
      expect(
        (await SharedPreferences.getInstance()).getString(
          'draw_filter_noise_color_profile',
        ),
        mine,
        reason: 'duplicate=$duplicate: 起動し直しても',
      );
    }
  });

  test('recent colours keep this device\'s colours first and fill only the '
      'free places, so reading the same file again keeps a colour used '
      'since', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    for (var i = 0; i < 10; i++) {
      await a.palette.addRecentColor(0xFFAA0000 + i);
    }
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    for (var i = 0; i < 3; i++) {
      await b.palette.addRecentColor(0xFF00BB00 + i);
    }
    final mine = [...b.palette.recentColors];
    await b.import(bytes, nextDir());
    final p = _Problems();
    p.check(b.palette.recentColors.length, 10, '空きにもう1台の色を入れる');
    p.check(b.palette.recentColors.take(3), mine, 'この端末の色を先に残す');

    var device = await _resume(await _snapshot());
    await device.palette.addRecentColor(0xFF123456);
    final used = [...device.palette.recentColors];
    await device.import(bytes, nextDir());
    device = await _resume(await _snapshot());
    p.check(device.palette.recentColors, used, '読み直しても、後で使った色を残す');
    p.verify();
  });
}
