import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/home_list_filters.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 設定の引き継ぎ（.niatra）の端末保存データは、この起動で読んでいない
/// 文字列の一覧も書き出す。
///
/// 端末の保存（Android・Linux）は、起動時に読んだ一覧を`List<Object?>`の
/// ままSharedPreferencesへ渡し、その一覧を書き直すまで`List<String>`に
/// ならない。書き出しが`List<String>`だけを選んでいたので、ゴミ箱の種類の
/// 絞り込みのように、その起動で変えていない一覧は書き出しから落ちていた
/// （Linuxの実操作で、絞り込みを変えた起動では入り、変えない起動では
/// 入らなかった）。

/// 端末保存データで書き出す一覧（設定の一覧・作品広場のミュート・利用者が
/// 作った物の一覧）。
final _listKeys = <String>{
  ...NiatraSerializer.settingListKeys,
  ...NiatraSerializer.unionListKeys,
  ...NiatraSerializer.mergedListKeys,
};

/// 端末保存データだけを書き出す（ほかの項目のサービスは読まない）。
Future<Map<dynamic, dynamic>> _exportDeviceData() async {
  final bytes = await NiatraSerializer.export(
    selectedItems: const {'端末保存データ': true},
    settings: SettingsService(),
    brush: BrushService(),
    tone: ToneService(),
    stamp: StampService(),
    autofillPresets: AutofillPresetService(),
    theme: ThemeService(),
    palette: PaletteService(),
    pixelArtPalette: PixelArtPaletteService(),
  );
  return NiatraSerializer.loadFromBytes(bytes).raw['localPreferences'] as Map;
}

/// 端末の保存が返す形の一覧（`List<String>`ではない）。
List<Object?> _stored(List<String> items) => <Object?>[...items];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_unread_lists_');
    AppErrorReporter.recentErrors.clear();
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('every list the transfer exports is written even when this run has '
      'not read it (the saved list is not a List<String>)', () async {
    expect(_listKeys, isNotEmpty);
    SharedPreferences.setMockInitialValues({
      for (final key in _listKeys) key: _stored(['$key-1', '$key-2']),
    });
    final prefs = await SharedPreferences.getInstance();
    for (final key in _listKeys) {
      expect(
        prefs.get(key),
        isNot(isA<List<String>>()),
        reason: '$key: the store hands the list back as List<Object?>',
      );
    }

    final local = await _exportDeviceData();
    final missing = [
      for (final key in _listKeys)
        if (local[key] is! List) key,
    ];
    expect(missing, isEmpty, reason: 'lists not read in this run were dropped');
    for (final key in _listKeys) {
      expect(local[key], ['$key-1', '$key-2'], reason: key);
    }
  });

  test(
    'the same lists stored as List<String> are exported as before',
    () async {
      SharedPreferences.setMockInitialValues({
        for (final key in _listKeys) key: ['$key-1', '$key-2'],
      });
      final local = await _exportDeviceData();
      for (final key in _listKeys) {
        expect(local[key], ['$key-1', '$key-2'], reason: key);
      }
    },
  );

  test('a saved list that is not all strings is not exported, is recorded, '
      'and does not stop the export', () async {
    SharedPreferences.setMockInitialValues({
      'toolbar_order': _stored(['pen', 'eraser']),
      'home.trashHiddenKinds.v1': <Object?>['outgoingShare', 3],
      'community.mutedWords': <Object?>['spoiler', null],
    });
    final local = await _exportDeviceData();
    expect(local['toolbar_order'], ['pen', 'eraser']);
    expect(local.containsKey('home.trashHiddenKinds.v1'), isFalse);
    expect(local.containsKey('community.mutedWords'), isFalse);
    // アプリの読み込み（readStringList）と同じく、読めない一覧として記録する。
    expect(
      AppErrorReporter.recentErrors.where(
        (e) =>
            e.contains('home.trashHiddenKinds.v1') ||
            e.contains('community.mutedWords'),
      ),
      hasLength(2),
    );
  });

  test('the Trash filter, a setting list and a muted word saved by an earlier '
      'run reach the other device after a restart, and the other device\'s '
      'unread muted words are kept', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'home.trashHiddenKinds.v1': _stored(['outgoingShare']),
      'toolbar_order': _stored(['eraser', 'pen']),
      'community.mutedWords': _stored(['spoiler']),
    });
    final a = await TransferDevice.start();
    // 起動で一覧を書き直していないこと（書き直すと型が変わり、反例にならない）。
    final before = await SharedPreferences.getInstance();
    expect(before.get('home.trashHiddenKinds.v1'), isNot(isA<List<String>>()));
    expect(before.get('community.mutedWords'), isNot(isA<List<String>>()));
    final bytes = await a.export();

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'community.mutedWords': _stored(['leak']),
    });
    final b = await TransferDevice.start();
    await b.import(bytes, temp);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home.trashHiddenKinds.v1'), ['outgoingShare']);
    expect(prefs.getStringList('toolbar_order'), ['eraser', 'pen']);
    expect(prefs.getStringList('community.mutedWords'), ['leak', 'spoiler']);

    // 起動し直したもう1台のゴミ箱の絞り込み。
    final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    SharedPreferences.setMockInitialValues({
      for (final entry in saved.entries)
        entry.key: entry.value is List
            ? _stored([...(entry.value as List).cast<String>()])
            : entry.value,
    });
    final restarted = SettingsService();
    await restarted.init();
    expect(restarted.homeListFilters(HomeList.trash).hiddenKinds, {
      'outgoingShare',
    });
  });
}
