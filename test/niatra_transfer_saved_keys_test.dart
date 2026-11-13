import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';

/// 端末保存データ（.niatra）での扱いが、アプリが読み書きするすべての保存で
/// 決まっていること（一覧も1つの値も、アカウントごとのキーも）。決まって
/// いない保存は書き出さず、読み込んでも書かない。

/// lib配下で保存を読み書きする所から集めたキー（[keys]）とキーの頭
/// （[prefixes]：アカウントや番号を後ろに付けるキー）。
class _SavedKeys {
  final keys = <String, Set<String>>{};
  final prefixes = <String, Set<String>>{};
  final unresolved = <String>{};
}

/// [source]の中で[name]が表す文字列（`name = '...'`・`name = other(...)`・
/// `name(...) => '...'`）。
String? _resolveName(String name, String source, [int depth = 0]) {
  if (depth > 4) return null;
  final n = RegExp.escape(name);
  final assigned = RegExp(
    "(?<![\\w\$])$n\\s*=\\s*'([^']*)'",
  ).firstMatch(source);
  if (assigned != null) return assigned.group(1);
  final function = RegExp(
    "(?<![\\w\$])$n\\([^)]*\\)\\s*=>\\s*'([^']*)'",
  ).firstMatch(source);
  if (function != null) return function.group(1);
  final alias = RegExp(
    "(?<![\\w\$])$n\\s*=\\s*([_a-zA-Z]\\w*)\\s*[(;]",
  ).firstMatch(source);
  if (alias != null && alias.group(1) != name) {
    return _resolveName(alias.group(1)!, source, depth + 1);
  }
  return null;
}

/// 文字列[text]（キーそのもの、または`$`で後ろを足すキー）をキーかキーの
/// 頭として書き留める。読めなければfalse。
bool _record(
  _SavedKeys found,
  String text,
  String source,
  String where, {
  bool asPrefix = false,
  int depth = 0,
}) {
  if (depth > 4) return false;
  if (!text.contains(r'$')) {
    (asPrefix ? found.prefixes : found.keys)
        .putIfAbsent(text, () => {})
        .add(where);
    return true;
  }
  final leading = RegExp(r'^\$\{?([_a-zA-Z]\w*)\}?').firstMatch(text);
  if (leading != null) {
    final inner = _resolveName(leading.group(1)!, source);
    if (inner == null) return false;
    return _record(
      found,
      inner,
      source,
      where,
      asPrefix: true,
      depth: depth + 1,
    );
  }
  found.prefixes
      .putIfAbsent(text.substring(0, text.indexOf(r'$')), () => {})
      .add(where);
  return true;
}

_SavedKeys _scan() {
  final call = RegExp(
    r'\.(?:read|set)(?:String|Int|Bool|Double|StringList)\(\s*',
  );
  final found = _SavedKeys();
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    final source = file.readAsStringSync();
    for (final match in call.allMatches(source)) {
      final rest = source.substring(match.end);
      final where =
          '$path:${source.substring(0, match.start).split('\n').length}';
      if (rest.startsWith("'")) {
        final literal = rest.substring(1, rest.indexOf("'", 1));
        if (!_record(found, literal, source, where)) {
          found.unresolved.add("$path '$literal'");
        }
        continue;
      }
      final name = RegExp(r'^([_a-zA-Z]\w*)\s*[(,)]').firstMatch(rest);
      final text = name == null ? null : _resolveName(name.group(1)!, source);
      if (text == null || !_record(found, text, source, where)) {
        found.unresolved.add(
          '$path ${name?.group(1) ?? rest.split('\n').first}',
        );
      }
    }
  }
  return found;
}

void main() {
  test('every saved key the app reads or writes (lists, single values and '
      'keys with an account or number after them) is moved by an item, '
      'added to this device\'s list, kept as this device\'s record or '
      'setting, or moved as a setting', () {
    final found = _scan();
    expect(
      found.keys.keys,
      containsAll([
        'brushes',
        'workspace_presets',
        'trashed_projects',
        'premium_purchase_date',
        'default_preset',
        'draw_filter_noise_color_profile',
        'language',
      ]),
    );
    expect(
      found.prefixes.keys,
      containsAll([
        'autosave_',
        'community.milestone.v1.',
        'creator_edit_unverified_seconds_v1_',
      ]),
    );
    // 渡されたキーをそのまま読み書きする所（キーは呼び出し側で集めている）。
    expect(found.unresolved, {
      'lib/engine/niatra_serializer.dart key',
      // 期間と数でキーを選ぶ（どれもpending_coin_redemption_で始まる）。
      'lib/services/coin_redemption_attempt_store.dart key',
      'lib/services/work_folder_service.dart key',
      'lib/utils/folder_persistence.dart key',
      "lib/screens/community/community_screen.dart '\$key.\$account'",
      'lib/screens/community/community_screen.dart key',
    }, reason: 'キーを読み取れない保存の読み書き');

    final classified = {
      ...BrushService.savedPreferenceKeys,
      ...ToneService.savedPreferenceKeys,
      ...StampService.savedPreferenceKeys,
      ...AutofillPresetService.savedPreferenceKeys,
      ...ThemeService.savedPreferenceKeys,
      ...PaletteService.savedPreferenceKeys,
      ...PixelArtPaletteService.savedPreferenceKeys,
      ...NiatraSerializer.deviceRecordKeys,
      ...NiatraSerializer.mergedListKeys,
      ...NiatraSerializer.unionListKeys,
      ...NiatraSerializer.settingListKeys,
      ...NiatraSerializer.settingKeys,
      ...NiatraSerializer.keptSettingKeys,
    };
    bool deviceRecord(String key) =>
        NiatraSerializer.deviceRecordPrefixes.any(key.startsWith);
    expect(
      [
        for (final entry in found.keys.entries)
          if (!classified.contains(entry.key) && !deviceRecord(entry.key))
            '${entry.key} (${entry.value.first})',
        for (final entry in found.prefixes.entries)
          if (!deviceRecord(entry.key)) '${entry.key}… (${entry.value.first})',
      ],
      isEmpty,
      reason:
          '端末保存データでの扱いが決まっていない保存（NiatraSerializerの'
          'どれかの一覧へ入れる。決まっていない保存は書かない）',
    );
    // 移す設定の一覧に、もう使っていないキーを残さない。
    expect([
      for (final key in {
        ...NiatraSerializer.settingKeys,
        ...NiatraSerializer.settingListKeys,
      })
        if (!found.keys.containsKey(key)) key,
    ], isEmpty);
  });
}
