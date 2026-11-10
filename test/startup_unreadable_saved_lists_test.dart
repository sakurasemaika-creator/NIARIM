import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/workspace_preset.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 型の違う値が入った保存を、起動が既定の内容で上書きしないことを確かめる
/// （キーを定数で持つServiceも含める。読めない保存は読めないまま残し、
/// 後の版・手での回復で読めるようにする）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_unreadable_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// lib配下の`prefs.readXxx(定数)`を、同じファイルの
  /// `static const 定数 = '文字列'`でキーへ直す。
  Map<String, String> constantKeys() {
    final read = RegExp(
      r'prefs\.read(Int|Bool|Double|String|StringList)\(\s*([_a-zA-Z]\w*)\s*[,)]',
    );
    final keys = <String, String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in read.allMatches(source)) {
        final name = RegExp.escape(match.group(2)!);
        final declared = RegExp(
          "(?:static\\s+)?const\\s+(?:String\\s+)?$name\\s*=\\s*'([^'\$]+)'",
        ).firstMatch(source);
        if (declared == null) continue;
        keys[declared.group(1)!] = match.group(1)!;
      }
    }
    return keys;
  }

  test('startup leaves saved values of another type as they were '
      '(keys held in constants)', () async {
    final keys = constantKeys();
    expect(keys.length, greaterThan(30));
    expect(keys.keys, containsAll(['brushes', 'brush_folders']));
    final corrupt = <String, Object>{
      for (final entry in keys.entries)
        entry.key: switch (entry.value) {
          'String' || 'StringList' => 7,
          _ => 'not-a-number',
        },
      'language': 'en',
    };
    SharedPreferences.setMockInitialValues(corrupt);
    final created = <ChangeNotifier>[];
    final providers = await buildAppProviders(debugOnCreated: created.add);
    expect(providers, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    final rewritten = [
      for (final key in keys.keys)
        if (prefs.get(key) != corrupt[key]) key,
    ]..sort();
    for (final service in created.reversed) {
      service.dispose();
    }
    expect(
      rewritten,
      isEmpty,
      reason: 'startup overwrote unreadable values: $rewritten',
    );
  });

  /// lib配下で一覧として読むキー（リテラル・定数とも）。
  Set<String> listKeys() {
    final literal = RegExp(r"prefs\.readStringList\(\s*'([^'$]+)'");
    final keys = <String>{
      for (final entry in constantKeys().entries)
        if (entry.value == 'StringList') entry.key,
    };
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in literal.allMatches(file.readAsStringSync())) {
        keys.add(match.group(1)!);
      }
    }
    return keys;
  }

  // 保存した一覧の中の読めない項目（途中で切れた・JSONでない・形の違う
  // 項目）は、1件ずつ試して起動を止めない。
  for (final entries in const [
    ['{"id":"broken"'],
    ['not json'],
    ['{}'],
    ['[]'],
    ['7'],
    ['{"id":7,"name":3}'],
  ]) {
    test('startup survives a saved list holding $entries, one key at a '
        'time', () async {
      final failures = <String>[];
      for (final key in listKeys().toList()..sort()) {
        SharedPreferences.setMockInitialValues({
          'language': 'en',
          key: entries,
        });
        AppErrorReporter.recentErrors.clear();
        final created = <ChangeNotifier>[];
        try {
          await buildAppProviders(debugOnCreated: created.add);
          for (final service in created.reversed) {
            service.dispose();
          }
        } on AppStartupException catch (error) {
          // 失敗した起動は、作ったServiceを自分で片付けている。
          failures.add('$key at ${error.step}: ${error.error}');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 10)));
  }

  /// 初回の起動で保存される内容（本物の保存として使う）と、そのときの件数。
  Future<({Map<String, Object> saved, int brushes, int tones, int stamps})>
  firstLaunch() async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final created = <ChangeNotifier>[];
    await buildAppProviders(debugOnCreated: created.add);
    final counts = (
      brushes: created.whereType<BrushService>().single.brushes.length,
      tones: created.whereType<ToneService>().single.tones.length,
      stamps: created.whereType<StampService>().single.stamps.length,
    );
    for (final service in created.reversed) {
      service.dispose();
    }
    final prefs = await SharedPreferences.getInstance();
    return (
      saved: <String, Object>{
        for (final key in prefs.getKeys()) key: prefs.get(key)!,
      },
      brushes: counts.brushes,
      tones: counts.tones,
      stamps: counts.stamps,
    );
  }

  // 一覧の先頭（組み込みの1件）・末尾（後から足された1件）を、後の版の形かも
  // しれない読めない1件に置き換える。起動は足りない組み込みを足し直そうと
  // するので、読めない項目を除いて保存し直す作りだとここで消える。
  for (final position in const ['first', 'last']) {
    test('a saved list whose $position entry is unreadable is used for what '
        'can be read, and startup does not drop that entry', () async {
      final launch = await firstLaunch();
      final saved = Map<String, Object>.of(launch.saved);
      final keys = listKeys().where((key) => saved[key] is List).toList()
        ..sort();
      expect(
        keys,
        containsAll([
          'autofill_presets',
          'brushes',
          'custom_automations_v1',
          'draw_filters',
          'quick_tool_entries',
          'shortcut_bindings',
          'stamps',
          'tones',
        ]),
      );
      const unreadable = '{"id":"from-a-later-version","name":7}';
      final placed = <String, String>{};
      for (final key in keys) {
        final entries = (saved[key]! as List).cast<String>().toList();
        if (entries.isEmpty) continue;
        final index = position == 'first' ? 0 : entries.length - 1;
        // フィルターは、この版に無い種類の項目を意図して取り除く。種類は
        // 分かるが読めない1件（名前の型が違う）で確かめる。
        placed[key] = key == 'draw_filters'
            ? jsonEncode({
                ...jsonDecode(entries[index]) as Map<String, dynamic>,
                'name': 7,
              })
            : unreadable;
        entries[index] = placed[key]!;
        saved[key] = entries;
      }

      SharedPreferences.setMockInitialValues(saved);
      final second = <ChangeNotifier>[];
      await buildAppProviders(debugOnCreated: second.add);
      // 置き換えた組み込みの1件は定義から足し直されるので、件数は同じ。
      expect(
        second.whereType<BrushService>().single.brushes.length,
        launch.brushes,
      );
      expect(second.whereType<ToneService>().single.tones.length, launch.tones);
      expect(
        second.whereType<StampService>().single.stamps.length,
        launch.stamps,
      );
      final after = await SharedPreferences.getInstance();
      final dropped = [
        for (final key in placed.keys)
          if (!(after.getStringList(key) ?? const []).contains(placed[key]))
            key,
      ];
      for (final service in second.reversed) {
        service.dispose();
      }
      expect(
        dropped,
        isEmpty,
        reason: 'startup dropped the unreadable entry from: $dropped',
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test('one saved value of another type at a time, on top of a normal '
      'install: startup leaves it as it was', () async {
    final launch = await firstLaunch();
    final literal = RegExp(
      r"prefs\.read(Int|Bool|Double|String|StringList)\(\s*'([^'$]+)'",
    );
    final keys = constantKeys();
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in literal.allMatches(file.readAsStringSync())) {
        keys[match.group(2)!] = match.group(1)!;
      }
    }
    expect(keys.length, greaterThan(100));
    // 利用者の内容を持たない記録は、読めなければ起動が書き直す：端末の
    // 性能の判定（初回と同じに測り直す）、組み込みテーマを元の配色へ
    // 戻した印、渡した公式プリセットの記録。
    const repaired = {
      'quality_level',
      'default_preset',
      'theme_original_builtin_palette_restored_v1',
      'custom_automation_offered_builtins_v1',
    };
    // 2通りの土台で確かめる：いまの版で初めて起動した保存と、上の記録が
    // まだ無い版から上げた保存（移行が走るので、起動が保存し直そうとする）。
    final bases = {
      'current': launch.saved,
      'before the records': {
        for (final entry in launch.saved.entries)
          if (!repaired.contains(entry.key)) entry.key: entry.value,
      },
    };
    final rewritten = <String>[];
    final failures = <String>[];
    for (final base in bases.entries) {
      for (final key in keys.keys.toList()..sort()) {
        if (repaired.contains(key)) continue;
        final Object wrong = switch (keys[key]) {
          'String' || 'StringList' => 7,
          _ => 'not-a-number',
        };
        SharedPreferences.setMockInitialValues({...base.value, key: wrong});
        final created = <ChangeNotifier>[];
        try {
          await buildAppProviders(debugOnCreated: created.add);
          for (final service in created.reversed) {
            service.dispose();
          }
        } on AppStartupException catch (error) {
          failures.add('$key (${base.key}) at ${error.step}: ${error.error}');
          continue;
        }
        final prefs = await SharedPreferences.getInstance();
        if (prefs.get(key) != wrong) rewritten.add('$key (${base.key})');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(
      rewritten,
      isEmpty,
      reason: 'startup overwrote unreadable values: $rewritten',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
  test('a workspace preset holding a non-text list item is rejected when it '
      'is read, not later when it is applied or saved', () {
    for (final field in const [
      'toolbarOrder',
      'hiddenToolbarItems',
      'defaultDockedPanels',
      'toolOptionDockOrder',
      'rightDockOrder',
    ]) {
      expect(
        () => WorkspacePreset.fromJson({
          'id': 'w',
          'name': 'n',
          field: ['pen', 7],
        }),
        throwsA(anything),
        reason: field,
      );
    }
    final read = WorkspacePreset.fromJson({
      'id': 'w',
      'name': 'n',
      'toolbarOrder': ['pen', 'eraser'],
    });
    expect(read.toolbarOrder, ['pen', 'eraser']);
    expect(read.toJson()['toolbarOrder'], ['pen', 'eraser']);
  });
}
