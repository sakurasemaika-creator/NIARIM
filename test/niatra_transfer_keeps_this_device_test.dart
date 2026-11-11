import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/quick_tool_entry.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）を読み込んでも、この端末の内容を黙って失わず、同じ
/// ファイル（や、行き来したファイル）を何度読んでも増えないこと：
/// - 端末保存データは、この端末の作品・ゴミ箱・フォルダ・フォント・透かしの
///   画像・購入の記録を書き換えず、利用者が作った物の一覧（ワークスペース・
///   自動操作・早替えツール・ショートカット・キャンバスの大きさ・描画
///   フィルター・ミュート）は動いているサービスの一覧へ足す。
/// - 今のテーマは、この端末で自分の色にしていればそのまま（もう1台の色は
///   一覧へ足す。行き来して戻ってきた自分の今の色は足さない）。読み込む
///   だけではテーマの保存を書き直さない。
/// - 複製の名前は、どの言語で付けたものでも複製と分かる。アプリの「複製」と
///   同じ形で、番号もそろう。
/// - 戻ってきた複製・利用者が整理した複製は、同じ中身があれば足さない。
/// - キャンバスで変えたブラシの太さ・不透明度は、ブラシの中身の違いに
///   数えない。

AppLocalizations _l10n(String code) => lookupAppLocalizations(Locale(code));

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

/// この端末の作品・ゴミ箱・フォルダ・書き出した作品・フォント・透かし・
/// ホーム画面のウィジェット・購入・自動保存の記録（端末保存データで
/// 書き換えてはいけない保存）。
Map<String, Object> _deviceRecords(String who) => {
  'project_folders': '[{"id":"f$who","name":"$who folder"}]',
  'trashed_projects': ['proj$who'],
  'trashed_project_folders': '[{"id":"tf$who"}]',
  'shared_folders': '[{"id":"sf$who"}]',
  'work_folders': '[{"id":"wf$who"}]',
  'work_file_folder_map': '{"$who.mp4":"wf$who"}',
  'watermark_assets': [
    '{"id":"wm$who","name":"$who mark","type":"image","fileName":"$who.png"}',
  ],
  'user_fonts': '[{"family":"$who"}]',
  'home_widget_config_v1': '{"device":"$who"}',
  'premium_purchase_product_id': '$who-product',
  'autosave_0_project': 'proj$who',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_keeps_device_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('device data adds the other device\'s own lists to this device\'s, '
      'keeps this device\'s projects, trash, folders, fonts and watermark '
      'images, and still moves settings', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.workspace.save('A layout', isLeftHanded: false, forcePcMode: null);
    final aAuto = await a.automation.importJson(
      a.automation.exportJson(a.automation.items.first.id),
    );
    await a.automation.rename(aAuto.id, 'A auto');
    await a.automation.toggleFavorite(aAuto.id);
    a.quickTool.addEntry(
      const QuickToolEntry(id: 'qtA', label: 'A tool', toolKey: 'eraser'),
    );
    a.shortcut.addBinding(
      ShortcutBinding(
        id: 'scA',
        label: 'A',
        keyId: LogicalKeyboardKey.keyK.keyId,
        control: true,
        command: ShortcutCommand.undo,
      ),
    );
    // この端末で同じキーの組み合わせを使っている割り当ては足さない。
    a.shortcut.addBinding(
      ShortcutBinding(
        id: 'scA2',
        label: 'A2',
        keyId: LogicalKeyboardKey.keyJ.keyId,
        control: true,
        command: ShortcutCommand.playPause,
      ),
    );
    await a.settings.addCustomSizePreset('A size', 640, 360);
    a.filter.duplicateFilter(a.filter.filters.first.id);
    final aFilter = a.filter.filters[1];
    final favouriteFilter = a.filter.filters.first.id;
    a.filter.toggleFavorite(favouriteFilter);
    final aPrefs = await SharedPreferences.getInstance();
    for (final entry in _deviceRecords('A').entries) {
      final value = entry.value;
      if (value is String) await aPrefs.setString(entry.key, value);
      if (value is List<String>) await aPrefs.setStringList(entry.key, value);
    }
    await aPrefs.setStringList('community.mutedWords', ['a-word']);
    await aPrefs.setDouble('bucket_tolerance', 42.0);
    await aPrefs.setStringList('toolbar_hidden', ['x-tool']);
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      ..._deviceRecords('B'),
      'community.mutedWords': ['b-word'],
    });
    final b = await TransferDevice.start();
    await b.workspace.save('B layout', isLeftHanded: true, forcePcMode: null);
    final bAuto = await b.automation.importJson(
      b.automation.exportJson(b.automation.items.first.id),
    );
    await b.automation.rename(bAuto.id, 'B auto');
    b.quickTool.addEntry(
      const QuickToolEntry(id: 'qtB', label: 'B tool', toolKey: 'eraser'),
    );
    b.shortcut.addBinding(
      ShortcutBinding(
        id: 'scB',
        label: 'B',
        keyId: LogicalKeyboardKey.keyJ.keyId,
        control: true,
        command: ShortcutCommand.redo,
      ),
    );
    await b.settings.addCustomSizePreset('B size', 320, 240);
    await settleTransfer();
    final bFilters = b.filter.filters.length;
    await b.import(bytes, nextDir());

    final p = _Problems();
    Future<void> checkDevice(TransferDevice d, String stage) async {
      p.check(
        d.workspace.presets.map((x) => x.name),
        containsAll(['A layout', 'B layout']),
        '$stage: ワークスペース',
      );
      p.check(
        d.automation.items.map((x) => x.name),
        containsAll(['A auto', 'B auto']),
        '$stage: 自動操作',
      );
      p.check(
        d.automation.isFavorite(aAuto.id),
        isTrue,
        '$stage: もう1台でお気に入りにした自動操作',
      );
      p.check(
        d.quickTool.entries.map((x) => x.id),
        containsAll(['qtA', 'qtB']),
        '$stage: 早替えツール',
      );
      p.check(
        d.shortcut.bindings.map((x) => x.id),
        containsAll(['scA', 'scB']),
        '$stage: ショートカット',
      );
      p.check(
        d.shortcut.bindings.map((x) => x.id),
        isNot(contains('scA2')),
        '$stage: この端末で使っているキーには割り当てない',
      );
      p.check(
        d.filter.filters
            .where((x) => x.id == favouriteFilter)
            .map((x) => x.isFavorite),
        [isTrue],
        '$stage: もう1台でお気に入りにした描画フィルター',
      );
      p.check(
        d.settings.customSizePresets.map((x) => x.name),
        containsAll(['A size', 'B size']),
        '$stage: キャンバスの大きさ',
      );
      p.check(
        d.filter.filters.where((x) => x.id == aFilter.id).map((x) => x.name),
        [aFilter.name],
        '$stage: もう1台で複製した描画フィルター',
      );
      p.check(d.filter.filters.length, bFilters + 1, '$stage: 描画フィルターは足しただけ');
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _deviceRecords('B').entries) {
        p.check(
          prefs.get(entry.key),
          entry.value,
          '$stage: この端末の記録（${entry.key}）はそのまま',
        );
      }
      p.check(
        prefs.getStringList('community.mutedWords'),
        containsAll(['a-word', 'b-word']),
        '$stage: ミュートした語は両方',
      );
      p.check(prefs.getDouble('bucket_tolerance'), 42.0, '$stage: 設定は今までどおり移す');
      p.check(prefs.getStringList('toolbar_hidden'), [
        'x-tool',
      ], '$stage: 設定の一覧も移す');
    }

    await checkDevice(b, 'after the import');
    await checkDevice(await TransferDevice.start(), 'restart');

    // 動いているサービスがいつもの保存をしても、読み込んだ分は戻らない。
    await b.workspace.save('B second', isLeftHanded: true, forcePcMode: null);
    b.quickTool.addEntry(
      const QuickToolEntry(id: 'qtB2', label: 'B tool 2', toolKey: 'pen'),
    );
    await settleTransfer();
    final saved = await TransferDevice.start();
    p.check(
      saved.workspace.presets.map((x) => x.name),
      containsAll(['A layout', 'B layout', 'B second']),
      'restart after saving: ワークスペース',
    );
    p.check(
      saved.quickTool.entries.map((x) => x.id),
      containsAll(['qtA', 'qtB', 'qtB2']),
      'restart after saving: 早替えツール',
    );

    // 同じファイルをもう一度読んでも、どの一覧も変わらない。
    final before = await _snapshot();
    await saved.import(bytes, nextDir());
    final after = await _snapshot();
    for (final key in before.keys) {
      if (before[key] is List) {
        p.check(after[key], before[key], 'reading again: $key');
      }
    }
    p.verify();
  });

  test('a file from an earlier version that carries the other device\'s '
      'project, trash and folder records in its device data does not '
      'overwrite this device\'s, and its lists are only added', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      ..._deviceRecords('B'),
      'community.mutedWords': ['b-word'],
      'workspace_presets': [
        '{"id":"wsB","name":"B layout","isLeftHanded":true}',
      ],
    });
    final b = await TransferDevice.start();
    await b.importData(
      NiatraData({
        'localPreferences': {
          ..._deviceRecords('A'),
          'community.mutedWords': ['a-word'],
          'workspace_presets': [
            '{"id":"wsA","name":"A layout","isLeftHanded":false}',
          ],
          'some_unknown_list_v9': ['from A'],
          'bucket_tolerance': 42.0,
        },
      }, Archive()),
      nextDir(),
    );
    final prefs = await SharedPreferences.getInstance();
    final p = _Problems();
    for (final entry in _deviceRecords('B').entries) {
      p.check(prefs.get(entry.key), entry.value, 'この端末の記録（${entry.key}）');
    }
    p.check(prefs.getStringList('community.mutedWords'), [
      'b-word',
      'a-word',
    ], 'ミュートした語は足すだけ');
    p.check(
      (await TransferDevice.start()).workspace.presets.map((x) => x.name),
      ['B layout', 'A layout'],
      'ワークスペースは足すだけ',
    );
    p.check(
      prefs.containsKey('some_unknown_list_v9'),
      isFalse,
      '扱いの決まっていない一覧は書かない',
    );
    p.check(prefs.getDouble('bucket_tolerance'), 42.0, '設定は移す');
    p.verify();
  });

  test('a theme the other device applied and then deleted does not become '
      'this device\'s theme of the same id', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.theme.savePreset(
      AppThemePreset.defaultLight.copyWith(
        id: 'theme_x',
        name: 'X',
        panelBgColor: const Color(0xFF111111),
      ),
    );
    a.theme.applyPreset('theme_x');
    a.theme.deletePreset('theme_x');
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.theme.savePreset(
      AppThemePreset.defaultLight.copyWith(
        id: 'theme_x',
        name: 'X',
        panelBgColor: const Color(0xFF222222),
      ),
    );
    await settleTransfer();
    await b.import(bytes, nextDir());

    final p = _Problems();
    p.check(b.theme.isEditingPreset, isFalse, 'この端末のテーマXの編集にはしない');
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF00AA00)),
    );
    b.theme.commitCurrent();
    await settleTransfer();
    for (final (stage, d) in [
      ('after saving', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(
        d.theme.presets
            .where((t) => t.id == 'theme_x')
            .map((t) => t.panelBgColor.toARGB32()),
        [0xFF222222],
        '$stage: この端末のテーマXのまま',
      );
    }
    p.verify();
  });

  test('this device\'s own current colours stay when the other device never '
      'changed its theme, and when both have their own colours the other '
      'colours are added to the list once', () async {
    final p = _Problems();
    // 元の端末はテーマに触れていない。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final untouched = await (await TransferDevice.start()).export();

    // この端末は一覧の配色を取り込んで手直しした（一覧には無い色）。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    b.theme.adoptPresetColors('green_light');
    b.theme.previewCurrent(
      b.theme.current.copyWith(accentColor: const Color(0xFF7700CC)),
    );
    b.theme.commitCurrent();
    await settleTransfer();
    final themes = b.theme.presets.length;
    await b.import(untouched, nextDir());
    for (final (stage, d) in [
      ('adopted colours', b),
      ('adopted colours, restart', await TransferDevice.start()),
    ]) {
      p.check(
        d.theme.current.accentColor.toARGB32(),
        0xFF7700CC,
        '$stage: この端末の今の色のまま',
      );
      p.check(d.theme.presets.length, themes, '$stage: テーマは増えない');
    }

    // この端末は組み込みのテーマをその場で編集して使っている。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final c = await TransferDevice.start();
    c.theme.applyPreset('orange_light');
    c.theme.previewCurrent(
      c.theme.current.copyWith(accentColor: const Color(0xFF123456)),
    );
    c.theme.commitCurrent();
    await settleTransfer();
    await c.import(untouched, nextDir());
    p.check(c.theme.current.id, 'orange_light', 'edited built-in: そのテーマのまま');
    p.check(
      c.theme.current.accentColor.toARGB32(),
      0xFF123456,
      'edited built-in: この端末の色のまま',
    );

    // どちらの端末も自分の色にしている。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.theme.adoptPresetColors('green_light');
    a.theme.previewCurrent(
      a.theme.current.copyWith(accentColor: const Color(0xFF13579B)),
    );
    a.theme.commitCurrent();
    await settleTransfer();
    final own = await a.export();
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final d = await TransferDevice.start();
    d.theme.adoptPresetColors('green_light');
    d.theme.previewCurrent(
      d.theme.current.copyWith(accentColor: const Color(0xFF7700CC)),
    );
    d.theme.commitCurrent();
    await settleTransfer();
    final before = d.theme.presets.length;
    await d.import(own, nextDir());
    await d.import(own, nextDir());
    for (final (stage, e) in [
      ('both own', d),
      ('both own, restart', await TransferDevice.start()),
    ]) {
      p.check(
        e.theme.current.accentColor.toARGB32(),
        0xFF7700CC,
        '$stage: この端末の今の色のまま',
      );
      p.check(
        e.theme.presets
            .where((t) => t.accentColor.toARGB32() == 0xFF13579B)
            .length,
        1,
        '$stage: もう1台の色は一覧に1つ',
      );
      p.check(e.theme.presets.length, before + 1, '$stage: 2回読んでも1つだけ');
    }
    p.verify();
  });

  test('after the files go both ways, neither device gets a copy of its own '
      'current colours in its theme list', () async {
    // どちらの端末も組み込みのテーマのカードを押して配色を取り込み、色を
    // 1つ変えて使っている。
    Future<TransferDevice> ownColours(int accent) async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final d = await TransferDevice.start();
      d.theme.adoptPresetColors('orange_dark');
      d.theme.previewCurrent(
        d.theme.current.copyWith(accentColor: Color(accent)),
      );
      d.theme.commitCurrent();
      await settleTransfer();
      return d;
    }

    const colourA = 0xFF00AA28;
    const colourB = 0xFF00AAC8;
    final a = await ownColours(colourA);
    final fromA = await a.export();
    final savedA = await _snapshot();
    final b = await ownColours(colourB);
    final themesB = b.theme.presets.length;
    await b.import(fromA, nextDir());
    final fromB = await b.export();
    final savedB = await _snapshot();

    final p = _Problems();
    // 元の端末へ戻す：もう1台の色は足すが、自分の色の複製は足さない。
    final backA = await _resume(savedA);
    final themesA = backA.theme.presets.length;
    final reportA = TransferImportReport();
    await backA.import(fromB, nextDir(), report: reportA);
    final fromA2 = await backA.export();
    for (final (stage, d) in [
      ('A after B', backA),
      ('A after B, restart', await _resume(await _snapshot())),
    ]) {
      p.check(
        d.theme.current.accentColor.toARGB32(),
        colourA,
        '$stage: 今の色は自分の色のまま',
      );
      p.check(
        d.theme.presets
            .where((t) => t.accentColor.toARGB32() == colourA)
            .map((t) => t.name),
        isEmpty,
        '$stage: 自分の今の色の複製は一覧に足さない',
      );
      p.check(
        d.theme.presets
            .where((t) => t.accentColor.toARGB32() == colourB)
            .length,
        1,
        '$stage: もう1台の色は1つ',
      );
      p.check(d.theme.presets.length, themesA + 1, '$stage: 1つだけ増える');
    }
    p.check(reportA.addedCopies, [
      _l10n('ja').projectDuplicateName(backA.theme.current.name),
    ], 'A after B: 知らせる複製はもう1台の色だけで、番号は付かない');

    // もう1台へもう一度戻す：何も増えない。
    final backB = await _resume(savedB);
    final reportB = TransferImportReport();
    await backB.import(fromA2, nextDir(), report: reportB);
    for (final (stage, d) in [
      ('B after A again', backB),
      ('B after A again, restart', await _resume(await _snapshot())),
    ]) {
      p.check(
        d.theme.current.accentColor.toARGB32(),
        colourB,
        '$stage: 今の色は自分の色のまま',
      );
      p.check(
        d.theme.presets
            .where((t) => t.accentColor.toARGB32() == colourB)
            .map((t) => t.name),
        isEmpty,
        '$stage: 自分の今の色の複製は一覧に足さない',
      );
      p.check(d.theme.presets.length, themesB + 1, '$stage: 最初に足した1つだけ');
    }
    p.check(reportB.addedCopies, isEmpty, 'B after A again: 複製は足さない');
    p.verify();
  });

  test('an item whose name is taken here by a different item comes with a '
      'numbered name, once, and a copy of a built-in brush that differs only '
      'in size still comes', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    await a.palette.createPalette('Skin');
    await a.palette.addColorToPalette(a.palette.activePalette!.id, 0xFF111111);
    final pen = a.brush.duplicateBrush('Brush0001', name: 'ペン (コピー)')!;
    a.brush.selectBrush(pen);
    a.brush.updateCurrentBrushSize(20);
    await a.brush.commitRememberedValues();
    await settleTransfer();
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.palette.createPalette('Skin');
    await b.palette.addColorToPalette(b.palette.activePalette!.id, 0xFF222222);
    await settleTransfer();
    final documents = nextDir();
    await b.import(bytes, documents);
    await b.import(bytes, documents);

    final p = _Problems();
    for (final (stage, d) in [
      ('after reading twice', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(
        {
          for (final x in d.palette.palettes)
            if (x.name.startsWith('Skin')) x.name: x.colors,
        },
        {
          'Skin': [0xFF222222],
          'Skin (コピー)': [0xFF111111],
        },
        '$stage: 同じ名前の別のパレットは番号を付けて1つ',
      );
      p.check(
        d.brush.brushes.where((x) => x.name == 'ペン (コピー)').map((x) => x.size),
        [20],
        '$stage: 組み込みを複製して太さだけ変えたブラシ',
      );
    }
    p.verify();
  });

  test('reading a file that changes no theme does not rewrite the saved '
      'themes, so entries this version cannot read and a value of another '
      'type stay', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final untouched = await (await TransferDevice.start()).export();
    final saved = await _snapshot();
    final themes = List<String>.from(saved['theme_presets']! as List);
    final current = saved['theme_current_json']!;

    // 今の色だけが変わるファイル（元の端末は一覧の配色を取り込んで手直し
    // した）でも、テーマの一覧の保存は書き直さない。
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    a.theme.adoptPresetColors('green_light');
    a.theme.previewCurrent(
      a.theme.current.copyWith(accentColor: const Color(0xFF13579B)),
    );
    a.theme.commitCurrent();
    await settleTransfer();
    final ownColours = await a.export();

    final p = _Problems();
    for (final (stage, stored) in <(String, Object)>[
      ('an entry this version cannot read', [...themes, '{"id":"theme_fu']),
      ('a value of another type', 'not a list'),
    ]) {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'theme_presets': stored,
        'theme_current_json': current,
        'theme_original_builtin_palette_restored_v1': true,
      });
      final b = await TransferDevice.start();
      await b.import(ownColours, nextDir());
      final prefs = await SharedPreferences.getInstance();
      p.check(
        prefs.get('theme_presets'),
        stored,
        '$stage, only the current colours change: テーマの一覧の保存はそのまま',
      );
      p.check(
        b.theme.current.accentColor.toARGB32(),
        0xFF13579B,
        '$stage, only the current colours change: 今の色はもう1台の色',
      );
      p.check(
        prefs.get('theme_current_json'),
        isNot(current),
        '$stage, only the current colours change: 今の色は保存する',
      );
    }
    for (final (stage, stored) in <(String, Object)>[
      ('an entry this version cannot read', [...themes, '{"id":"theme_fu']),
      ('a value of another type', 'not a list'),
    ]) {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'theme_presets': stored,
        'theme_current_json': current,
        'theme_original_builtin_palette_restored_v1': true,
      });
      final b = await TransferDevice.start();
      await b.import(untouched, nextDir());
      final prefs = await SharedPreferences.getInstance();
      p.check(prefs.get('theme_presets'), stored, '$stage: テーマの保存はそのまま');
      p.check(prefs.get('theme_current_json'), current, '$stage: 今の色の保存もそのまま');
    }
    p.verify();
  });

  test('copies are recognised in every language, so reading the same file '
      'again after the language changed (even by the import itself) adds '
      'nothing', () async {
    final p = _Problems();
    for (final (stage, sourceLanguage, copyLanguage) in [
      ('copy named in Japanese', 'ja', 'ja'),
      ('the other device is English, copy named in English', 'en', 'en'),
      ('copy named in Korean', 'ja', 'ko'),
    ]) {
      SharedPreferences.setMockInitialValues({'language': sourceLanguage});
      final a = await TransferDevice.start();
      await a.palette.createPalette('マイパレット');
      final id = a.palette.activePalette!.id;
      await a.palette.addColorToPalette(id, 0xFF0000AA);
      await settleTransfer();
      final first = await a.export();
      await a.palette.addColorToPalette(id, 0xFF0000BB);
      await settleTransfer();
      final second = await a.export();

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final b = await TransferDevice.start();
      await b.import(first, nextDir(), l10n: _l10n(copyLanguage));
      await b.palette.addColorToPalette(id, 0xFF00CC00);
      await settleTransfer();
      await b.import(second, nextDir(), l10n: _l10n(copyLanguage));
      final count = b.palette.palettes.length;
      p.check(
        b.palette.palettes.map((x) => x.name),
        contains(_l10n(copyLanguage).projectDuplicateName('マイパレット')),
        '$stage: 1回目は複製を足す',
      );
      // 起動し直すと、端末保存データで移った言語になっていることがある。
      final restarted = await TransferDevice.start();
      await restarted.import(
        second,
        nextDir(),
        l10n: _l10n(restarted.settings.language),
      );
      for (final locale in AppLocalizations.supportedLocales) {
        await restarted.import(
          second,
          nextDir(),
          l10n: lookupAppLocalizations(locale),
        );
      }
      p.check(
        restarted.palette.palettes.map((x) => x.name).toList(),
        hasLength(count),
        '$stage: 別の言語で読み直しても増えない',
      );
    }
    p.verify();
  });

  test('palettes going back and forth between two devices that both edit '
      'them settle without twins, and a rename settles too', () async {
    final p = _Problems();

    /// Pのパレット（最初の色を含むもの）を名前順に。
    List<String> describe(TransferDevice d) => [
      for (final x in d.palette.palettes)
        if (x.colors.contains(0xFF0000AA)) '${x.name}=${x.colors}',
    ]..sort();

    Future<void> rounds(
      String stage, {
      required Future<void> Function(TransferDevice a) editA,
      required Future<void> Function(TransferDevice b) editB,
      required int expected,
    }) async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final a0 = await TransferDevice.start();
      await a0.palette.createPalette('P');
      await a0.palette.addColorToPalette(
        a0.palette.activePalette!.id,
        0xFF0000AA,
      );
      await settleTransfer();
      final start = await a0.export();
      var savedA = await _snapshot();
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final b0 = await TransferDevice.start();
      await b0.import(start, nextDir());
      var savedB = await _snapshot();

      // それぞれの端末で編集してから、何度も行き来させる。
      await editA(await _resume(savedA));
      await settleTransfer();
      savedA = await _snapshot();
      await editB(await _resume(savedB));
      await settleTransfer();
      savedB = await _snapshot();
      final states = <String>[];
      for (var round = 0; round < 4; round++) {
        final fromA = await (await _resume(savedA)).export();
        final b = await _resume(savedB);
        await b.import(fromA, nextDir());
        final fromB = await b.export();
        savedB = await _snapshot();
        final a = await _resume(savedA);
        await a.import(fromB, nextDir());
        savedA = await _snapshot();
        final bNow = await _resume(savedB);
        states.add('A: ${describe(a)} | B: ${describe(bNow)}');
        for (final (who, d) in [('A', a), ('B', bNow)]) {
          final names = [
            for (final x in d.palette.palettes)
              if (x.colors.contains(0xFF0000AA)) x.name,
          ];
          p.check(
            names.toSet().length,
            names.length,
            '$stage round $round $who: 同じ名前のパレットが並ばない ${describe(d)}',
          );
          p.check(
            names.length,
            expected,
            '$stage round $round $who: 増え続けない ${describe(d)}',
          );
        }
      }
      p.check(states[3], states[0], '$stage: 行き来しても落ち着く');
    }

    String paletteP(TransferDevice d) =>
        d.palette.palettes.singleWhere((x) => x.name == 'P').id;
    await rounds(
      'both edit',
      editA: (a) => a.palette.addColorToPalette(paletteP(a), 0xFF0000BB),
      editB: (b) => b.palette.addColorToPalette(paletteP(b), 0xFF0000CC),
      expected: 2,
    );
    await rounds(
      'rename',
      editA: (a) async {},
      editB: (b) => b.palette.renamePalette(paletteP(b), 'Q'),
      expected: 2,
    );
    p.verify();
  });

  test(
    'after keeping the other device\'s version (deleting this one and '
    'giving the copy the name), reading the file again adds no twin',
    () async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final a = await TransferDevice.start();
      final image = File('${temp.path}/a.png')..writeAsBytesSync([1, 2, 3]);
      a.brush.addBrush(
        customTransferBrush('BrushShared', 'Soft pencil', image.path),
      );
      a.theme.savePreset(
        AppThemePreset.defaultLight.copyWith(
          id: 'theme_shared',
          name: 'Night sky',
          accentColor: const Color(0xFF3355AA),
        ),
      );
      await a.palette.createPalette('Skin tones');
      final palette = a.palette.activePalette!.id;
      await a.palette.addColorToPalette(palette, 0xFFEEC9A8);
      await settleTransfer();
      final first = await a.export();
      final shared = a.brush.brushes.singleWhere((x) => x.id == 'BrushShared');
      a.brush.updateBrush(shared.copyWith(spacing: 30));
      a.theme.savePreset(
        a.theme.presets
            .singleWhere((t) => t.id == 'theme_shared')
            .copyWith(accentColor: const Color(0xFFAA3355)),
      );
      await a.palette.addColorToPalette(palette, 0xFF8D5524);
      await settleTransfer();
      final second = await a.export();

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final b = await TransferDevice.start();
      // アプリと同じく、この端末の書類のフォルダは1つ。
      final documents = nextDir();
      await b.import(first, documents);
      final mine = b.brush.brushes.singleWhere((x) => x.id == 'BrushShared');
      b.brush.updateBrush(mine.copyWith(spacing: 9));
      b.theme.savePreset(
        b.theme.presets
            .singleWhere((t) => t.id == 'theme_shared')
            .copyWith(accentColor: const Color(0xFF22AA44)),
      );
      await b.palette.addColorToPalette(palette, 0xFF00FF00);
      await settleTransfer();
      await b.import(second, documents);

      // もう1台の方を残す：この端末の方を消し、複製にもとの名前を付ける。
      final copyBrush = b.brush.brushes.singleWhere(
        (x) => x.name == 'Soft pencil (コピー)',
      );
      b.brush.deleteBrush('BrushShared');
      b.brush.updateBrush(copyBrush.copyWith(name: 'Soft pencil'));
      final copyTheme = b.theme.presets.singleWhere(
        (x) => x.name == 'Night sky (コピー)',
      );
      b.theme.deletePreset('theme_shared');
      b.theme.savePreset(copyTheme.copyWith(name: 'Night sky'));
      final copyPalette = b.palette.palettes.singleWhere(
        (x) => x.name == 'Skin tones (コピー)',
      );
      await b.palette.deletePalette(palette);
      await b.palette.renamePalette(copyPalette.id, 'Skin tones');
      await settleTransfer();
      await b.import(second, documents);

      final p = _Problems();
      for (final (stage, d) in [
        ('after reading again', b),
        ('restart', await TransferDevice.start()),
      ]) {
        p.check(
          d.brush.brushes.where((x) => x.name.startsWith('Soft pencil')).length,
          1,
          '$stage: ブラシは1つ',
        );
        p.check(
          d.theme.presets.where((x) => x.name.startsWith('Night sky')).length,
          1,
          '$stage: テーマは1つ',
        );
        p.check(
          d.palette.palettes
              .where((x) => x.name.startsWith('Skin tones'))
              .length,
          1,
          '$stage: パレットは1つ',
        );
      }
      p.verify();
    },
  );

  test('the size and opacity changed on the canvas are not a different '
      'brush, so reading the same file again adds no copy', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final a = await TransferDevice.start();
    final image = File('${temp.path}/a.png')..writeAsBytesSync([1, 2, 3]);
    a.brush.addBrush(
      customTransferBrush('BrushShared', 'Soft pencil', image.path),
    );
    await settleTransfer();
    final file = await a.export();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    await b.import(file, nextDir());
    b.brush.selectBrush('BrushShared');
    b.brush.updateCurrentBrushSize(12);
    b.brush.updateCurrentBrushOpacity(60);
    b.brush.selectBrush('Brush0003');
    b.brush.updateCurrentBrushSize(80);
    await b.brush.commitRememberedValues();
    await settleTransfer();
    final count = b.brush.brushes.length;
    await b.import(file, nextDir());

    final p = _Problems();
    for (final (stage, d) in [
      ('after reading again', b),
      ('restart', await TransferDevice.start()),
    ]) {
      p.check(d.brush.brushes.length, count, '$stage: ブラシは増えない');
      final shared = d.brush.brushes.singleWhere((x) => x.id == 'BrushShared');
      p.check(shared.size, 12, '$stage: この端末で変えた太さ');
      p.check(shared.opacity, 60, '$stage: この端末で変えた不透明度');
    }
    p.verify();
  });

  test('a file without any device data still merges its items (the device '
      'data step is not needed for them)', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final b = await TransferDevice.start();
    final count = b.palette.palettes.length;
    await b.importData(
      NiatraData({
        'palettes': [
          {
            'id': 'palette_only',
            'name': 'Only',
            'colors': [0xFF112233],
          },
        ],
      }, Archive()),
      nextDir(),
    );
    expect(b.palette.palettes.length, count + 1);
  });
}
