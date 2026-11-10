import 'dart:convert';

import 'app_error_reporter.dart';

/// 保存した一覧（1件＝JSONのオブジェクトを文字列にしたもの）を1件ずつ読む。
///
/// 途中で切れた・JSONでない・項目が欠けた・型の違う1件があっても、その
/// 1件だけを飛ばして残りを返す。一覧を一度に`map(fromJson)`すると、1件の
/// 例外でServiceの初期化全体が失敗し、起動をやり直しても毎回同じ所で
/// 止まる（保存を消すまで二度と起動できない）。読めなかった項目は
/// [AppErrorReporter]へ記録し、[onSkipped]で呼び出し側へ知らせる。
List<T> readSavedJsonList<T>(
  Iterable<String> raw,
  T Function(Map<String, dynamic> json) fromJson, {
  void Function()? onSkipped,
}) {
  final items = <T>[];
  for (final entry in raw) {
    try {
      final decoded = jsonDecode(entry);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('A saved list entry is not an object');
      }
      items.add(fromJson(decoded));
    } catch (error, stack) {
      // TypeError（項目の型違い）も含めて受ける。
      AppErrorReporter.record(error, stack);
      onSkipped?.call();
    }
  }
  return items;
}
