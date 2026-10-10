import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_error_reporter.dart';

/// SharedPreferencesの型付き読み出しを、保存されている値の型が違うときに
/// 例外ではなくnull（＝未設定）で返すようにしたもの。
///
/// 標準の`getInt`等は`as int?`でキャストするため、同じキーに別の型の値が
/// 入っていると例外を投げる。アプリの版の間で同じキーの保存形式が
/// 変わった場合や、設定ファイルが壊れた場合に、起動処理がその場所で
/// 毎回失敗し、何度やり直しても起動できなくなる。読めない値は未設定と
/// 同じに扱って既定値で動かし、値そのものは書き換えない（その設定を
/// 次に変えたときに正しい型で上書きされる）。読めなかったことは
/// [AppErrorReporter]へ記録する。
extension TolerantPreferences on SharedPreferences {
  bool? readBool(String key) {
    final value = get(key);
    return value is bool ? value : _mismatch(key, value, 'bool');
  }

  int? readInt(String key) {
    final value = get(key);
    return value is int ? value : _mismatch(key, value, 'int');
  }

  /// 整数で保存されている値は小数として読む（同じ数値として扱える）。
  double? readDouble(String key) {
    final value = get(key);
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return _mismatch(key, value, 'double');
  }

  String? readString(String key) {
    final value = get(key);
    return value is String ? value : _mismatch(key, value, 'String');
  }

  List<String>? readStringList(String key) {
    final value = get(key);
    if (value is List && value.every((item) => item is String)) {
      return List<String>.of(value.cast<String>());
    }
    return _mismatch(key, value, 'List<String>');
  }
}

Null _mismatch(String key, Object? value, String expected) {
  if (value == null) return null;
  final message =
      'Ignored preference "$key": expected $expected, '
      'found ${value.runtimeType}';
  debugPrint(message);
  AppErrorReporter.record(StateError(message), null);
  return null;
}
