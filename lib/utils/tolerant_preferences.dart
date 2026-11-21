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

  /// [key]に値はあるが、文字列の一覧としては読めないか（未設定は含まない）。
  ///
  /// 起動処理が「保存が無い＝初回起動」と「保存はあるが読めない」を
  /// 見分けるために使う。後者で既定の内容を書き込むと、読めなかった保存
  /// （後の版や手作業でなら読めたかもしれない自作の内容）を消してしまう。
  bool holdsUnreadableStringList(String key) {
    final value = get(key);
    return value != null &&
        !(value is List && value.every((item) => item is String));
  }
}

/// 保存したエポックからのミリ秒を日時にする。[DateTime]が表せる範囲
/// （±864京ミリ秒）の外の値は、例外にせずnull（＝未設定）を返して
/// [AppErrorReporter]へ記録する。
///
/// 型は合っているので`readInt`はそのまま返す。範囲を見ずに
/// `DateTime.fromMillisecondsSinceEpoch`へ渡すと、起動の初期化がそこで
/// 毎回失敗して二度と起動できない。
DateTime? dateTimeFromSavedMillis(String key, int millis) {
  const limit = 8640000000000000;
  if (millis >= -limit && millis <= limit) {
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  final message = 'Ignored preference "$key": not a representable date';
  debugPrint(message);
  AppErrorReporter.record(StateError(message), null);
  return null;
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
