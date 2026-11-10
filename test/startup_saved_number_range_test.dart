import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 保存した数が範囲の外（負の数・とても大きな数・数でない小数）でも、起動が
/// 止まらない・終わらなくならないことを確かめる。型は合っているので
/// `readInt`等はそのまま返す。使う側が範囲を見ていないと、起動の初期化が
/// 毎回同じ所で失敗して二度と起動できない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_number_range_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// lib配下で数として読むキー（リテラルと、同じファイルの定数。
  /// `autosave_${i}_savedAt`のように組み立てるキーは、0番の分を足す）。
  Map<String, String> numberKeys() {
    final literal = RegExp(r"prefs\.read(Int|Double)\(\s*'([^'$]+)'");
    final constant = RegExp(
      r'prefs\.read(Int|Double)\(\s*([_a-zA-Z]\w*)\s*[,)]',
    );
    final keys = <String, String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        keys[match.group(2)!] = match.group(1)!;
      }
      for (final match in constant.allMatches(source)) {
        final name = RegExp.escape(match.group(2)!);
        final declared = RegExp(
          "(?:static\\s+)?const\\s+(?:String\\s+)?$name\\s*=\\s*'([^'\$]+)'",
        ).firstMatch(source);
        if (declared != null) keys[declared.group(1)!] = match.group(1)!;
      }
    }
    return keys
      ..['autosave_0_savedAt'] = 'Int'
      ..['autosave_0_slot'] = 'Int';
  }

  Future<String?> startupFailure(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final created = <ChangeNotifier>[];
    try {
      await buildAppProviders(debugOnCreated: created.add);
      for (final service in created.reversed) {
        service.dispose();
      }
      return null;
    } on AppStartupException catch (error) {
      return 'at ${error.step}: ${error.error}';
    }
  }

  test('startup survives saved numbers outside any sensible range, one key '
      'at a time', () async {
    final keys = numberKeys();
    expect(keys.length, greaterThan(15));
    expect(
      keys.keys,
      containsAll(['undo_limit', 'autosave_count', 'premium_purchase_date']),
    );
    // 自動保存の1件が読まれるように、0番の項目をそろえた土台。
    const base = <String, Object>{
      'language': 'en',
      'autosave_count': 1,
      'autosave_0_project': 'p',
      'autosave_0_savedAt': 0,
      'autosave_0_slot': 0,
    };
    // 数に比例した仕事をしていないかは、何も足さない起動の時間と比べる。
    final plain = Stopwatch()..start();
    expect(await startupFailure(base), isNull);
    plain.stop();
    final slow = <String>[];
    final failures = <String>[];
    for (final key in keys.keys.toList()..sort()) {
      final isInt = keys[key] == 'Int';
      // まず、大きいが有限の数：数に比例した仕事をしないこと（しているなら
      // 2の62乗では終わらないので、その先の値は試さない）。
      final watch = Stopwatch()..start();
      final Object large = isInt ? 3000000 : 3000000.0;
      final failure = await startupFailure({...base, key: large});
      watch.stop();
      if (failure != null) failures.add('$key=$large $failure');
      if (watch.elapsedMilliseconds > plain.elapsedMilliseconds + 500) {
        slow.add(
          '$key=$large took ${watch.elapsedMilliseconds} ms '
          '(plain startup ${plain.elapsedMilliseconds} ms)',
        );
        continue;
      }
      final extremes = isInt
          ? <Object>[-1, 0, 1 << 62, -(1 << 62)]
          : <Object>[
              -1.0,
              0.0,
              1e300,
              -1e300,
              double.nan,
              double.infinity,
              1 << 62,
            ];
      for (final value in extremes) {
        // 終わらない起動を見つけたとき、どの値かが記録に残るようにする。
        debugPrint('probe $key=$value');
        final extreme = await startupFailure({...base, key: value});
        if (extreme != null) failures.add('$key=$value $extreme');
      }
    }
    final problems = [...slow, ...failures];
    expect(problems, isEmpty, reason: problems.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
