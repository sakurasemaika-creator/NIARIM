import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_error_reporter.dart';

/// 保存した一覧（1件＝JSONのオブジェクトを文字列にしたもの）を1件ずつ読む。
///
/// 途中で切れた・JSONでない・項目が欠けた・型の違う1件があっても、その
/// 1件だけを飛ばして残りを返す。一覧を一度に`map(fromJson)`すると、1件の
/// 例外でServiceの初期化全体が失敗し、起動をやり直しても毎回同じ所で
/// 止まる（保存を消すまで二度と起動できない）。読めなかった項目は
/// [AppErrorReporter]へ記録し、[onSkipped]で呼び出し側へ知らせる。
/// [unreadable]を渡すと、読めなかった項目をそのままの文字列で足す（保存し
/// 直すときに残すため）。
///
/// [listKey]（その一覧の保存キー）を渡すと、読めなかった項目を
/// [SavedListCarryOver]が覚え、その一覧を[SavedListPreferences.setSavedJsonList]
/// で保存し直すときに、元の文字列のまま後ろへ残す（読めない項目を次の保存で
/// 失わない。元のデータは一覧の中に残るので、起動のたびにもう一度読み込みを
/// 試し、読めるようになれば戻る）。
List<T> readSavedJsonList<T>(
  Iterable<String> raw,
  T Function(Map<String, dynamic> json) fromJson, {
  void Function()? onSkipped,
  List<String>? unreadable,
  String? listKey,
}) {
  final items = <T>[];
  final skipped = <String>[];
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
      unreadable?.add(entry);
      skipped.add(entry);
      onSkipped?.call();
    }
  }
  if (listKey != null) SavedListCarryOver.remember(listKey, skipped);
  return items;
}

/// 保存した一覧の中の、読めなかった項目（元の文字列）を一覧の保存キーごとに
/// 覚える。読めた項目は通常どおり使い、読めなかった項目は保存し直すときに
/// 後ろへ残すので、元のデータを失わない。
class SavedListCarryOver {
  SavedListCarryOver._();

  static final Map<String, List<String>> _byKey = {};

  /// [key]の一覧で読めなかった項目を覚える（最後に読んだときの分で置き換える。
  /// 空なら忘れる）。
  static void remember(String key, List<String> entries) {
    if (entries.isEmpty) {
      _byKey.remove(key);
    } else {
      _byKey[key] = List.unmodifiable(entries);
    }
  }

  /// 保存する[encoded]（読めた項目）の後ろへ、[key]の一覧で読めなかった
  /// 項目を元の文字列のまま足したもの。
  static List<String> keep(String key, List<String> encoded) {
    final kept = _byKey[key];
    if (kept == null || kept.isEmpty) return encoded;
    return [...encoded, ...kept.where((entry) => !encoded.contains(entry))];
  }

  /// 一覧の保存キーごとの、読めなかった項目の数。
  static Map<String, int> get counts => {
    for (final entry in _byKey.entries) entry.key: entry.value.length,
  };

  /// 読めなかった項目の合計。
  static int get total =>
      _byKey.values.fold(0, (sum, entries) => sum + entries.length);

  @visibleForTesting
  static void reset() => _byKey.clear();
}

/// 保存した一覧を書く。読めなかった項目（[SavedListCarryOver]）を後ろへ残す。
extension SavedListPreferences on SharedPreferences {
  Future<bool> setSavedJsonList(String key, List<String> encoded) =>
      setStringList(key, SavedListCarryOver.keep(key, encoded));
}
