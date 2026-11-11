import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_asset_bundle.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引き継ぎ（.niatra）の読み込みで、組み込みの項目が増えない・同じファイルを
/// 読み直しても増えない・この端末にしか無い項目を消さない・読み込んだ内容が
/// 次の保存や起動し直しで戻らないこと。
///
/// 読み込みは引き継ぎ画面（`TransferScreen._import`）と同じ順で行う：
/// 画像の展開（`NiatraAssetBundle.restoreEmbeddedAssets`）→各項目
/// （`NiatraSerializer.applyTo`）→端末保存データ
/// （`NiatraSerializer.restoreLocalPreferences`）。「起動し直し」は、同じ
/// 保存（SharedPreferences）から各サービスを作り直して`init`する。

/// 画面の既定（すべての項目にチェック）。
const _allItems = {
  '設定': true,
  '端末保存データ': true,
  '素材': true,
  'ブラシ': true,
  'プリセット': true,
  'UIテーマ': true,
  'パレット': true,
};

class _Device {
  _Device._(
    this.settings,
    this.brush,
    this.tone,
    this.stamp,
    this.autofill,
    this.theme,
    this.palette,
    this.pixelArt,
  );

  final SettingsService settings;
  final BrushService brush;
  final ToneService tone;
  final StampService stamp;
  final AutofillPresetService autofill;
  final ThemeService theme;
  final PaletteService palette;
  final PixelArtPaletteService pixelArt;

  /// アプリの起動（今の保存から各サービスを作る）。
  static Future<_Device> start() async {
    final device = _Device._(
      SettingsService(),
      BrushService(),
      ToneService(),
      StampService(),
      AutofillPresetService(),
      ThemeService(),
      PaletteService(),
      PixelArtPaletteService(),
    );
    await device.settings.init();
    await device.brush.init();
    await device.tone.init();
    await device.stamp.init();
    await device.autofill.init();
    await device.theme.init();
    await device.palette.init();
    await device.pixelArt.init();
    return device;
  }

  Future<Uint8List> export() async {
    final raw = await NiatraSerializer.export(
      selectedItems: _allItems,
      settings: settings,
      brush: brush,
      tone: tone,
      stamp: stamp,
      autofillPresets: autofill,
      theme: theme,
      palette: palette,
      pixelArtPalette: pixelArt,
    );
    return NiatraAssetBundle.enrichExport(
      raw,
      selectedItems: _allItems,
      brush: brush,
      tone: tone,
      stamp: stamp,
    );
  }

  /// 引き継ぎ画面の「読み込み」と同じ順で取り込む。
  Future<void> import(Uint8List bytes, Directory documents) async {
    final data = NiatraSerializer.loadFromBytes(bytes);
    await NiatraAssetBundle.restoreEmbeddedAssets(
      data,
      brush: brush,
      tone: tone,
      stamp: stamp,
      restoreBasePath: documents.path,
    );
    // 以前は戻り値の無い処理、今は保存し終えるまでを返す。どちらでも待てる
    // ように包む。
    await Future<void>.sync(
      () => NiatraSerializer.applyTo(
        data,
        settings: settings,
        brush: brush,
        tone: tone,
        stamp: stamp,
        autofillPresets: autofill,
        theme: theme,
        palette: palette,
        pixelArtPalette: pixelArt,
      ),
    );
    await NiatraSerializer.restoreLocalPreferences(data);
    await _settle();
  }
}

/// 待たずに始めた保存を終わらせる。
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

Brush _customBrush(String id, String name, String imagePath) => Brush(
  id: id,
  name: name,
  size: 17,
  opacity: 73,
  spacing: 12,
  stabilization: true,
  stabilizationStrength: 41,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  customImagePath: imagePath,
);

/// 元の端末：組み込みブラシの太さを覚え、組み込みをお気に入りにし、自作の
/// ブラシ・トーン・スタンプ（画像つき、フォルダの中）・自動塗り設定・
/// テーマ（編集中）・パレットを作ってから、画面の既定で書き出す。
Future<Uint8List> _exportFromSource(Directory temp) async {
  SharedPreferences.setMockInitialValues({'language': 'ja'});
  final src = await _Device.start();

  src.brush.selectBrush('Brush0001');
  src.brush.updateCurrentBrushSize(23);
  await src.brush.commitRememberedValues();
  src.brush.toggleFavoriteBrush('Brush0002');
  final brushFolder = await src.brush.createFolder('Brush folder A');
  final brushImage = File('${temp.path}/brush_a.png')
    ..writeAsBytesSync([1, 2, 3, 4]);
  src.brush.addBrush(_customBrush('BrushCustomA', 'Custom A', brushImage.path));
  src.brush.moveToFolder('BrushCustomA', brushFolder.id);

  final toneFolder = await src.tone.createFolder('Tone folder A');
  final toneImage = File('${temp.path}/tone_a.png')
    ..writeAsBytesSync([5, 6, 7, 8]);
  src.tone.addTone(
    Tone(id: 'ToneCustomA', name: 'Custom tone A', texturePath: toneImage.path),
  );
  src.tone.moveToFolder('ToneCustomA', toneFolder.id);

  final stampFolder = await src.stamp.createFolder('Stamp folder A');
  final stampImage = File('${temp.path}/stamp_a.png')
    ..writeAsBytesSync([9, 10, 11, 12]);
  src.stamp.addStamp(
    Stamp(
      id: 'StampCustomA',
      name: 'Custom stamp A',
      imagePath: stampImage.path,
    ),
  );
  src.stamp.moveToFolder('StampCustomA', stampFolder.id);

  await src.autofill.addPreset(
    const AutofillPreset(
      id: 'p_custom_a',
      name: 'Custom preset A',
      parts: [AutofillPart(id: 'part_a', name: 'hair', color: 0xFF112233)],
    ),
  );

  src.theme.savePreset(
    AppThemePreset.defaultLight.copyWith(
      id: 'theme_custom_a',
      name: 'My theme A',
      accentColor: const Color(0xFF3355AA),
    ),
  );
  src.theme.applyPreset('theme_custom_a');

  await src.palette.createPalette('Pal A');
  await src.palette.addColorToPalette(
    src.palette.activePalette!.id,
    0xFF445566,
  );
  await src.palette.addRecentColor(0xFF010203);
  await src.pixelArt.addPalette('Pix A', [0xFF000000, 0xFFFFFFFF]);
  await _settle();

  final bytes = await src.export();
  await _settle();
  return bytes;
}

/// 新しく入れた端末の、組み込みの項目の数。
class _BuiltInCounts {
  _BuiltInCounts(_Device fresh)
    : brushes = fresh.brush.brushes.length,
      tones = fresh.tone.tones.length,
      stamps = fresh.stamp.stamps.length,
      autofill = fresh.autofill.presets.length,
      themes = fresh.theme.presets.length,
      brush0003Size = fresh.brush.brushes
          .singleWhere((b) => b.id == 'Brush0003')
          .size;

  final int brushes;
  final int tones;
  final int stamps;
  final int autofill;
  final int themes;
  final double brush0003Size;
}

List<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final v in values)
      if (!seen.add(v)) v,
  ];
}

/// 見つけた食い違いを最後にまとめて報告する（最初の1つで止めると、取り込み・
/// 保存・起動し直しのどの段で何が起きるかが分からない）。
class _Problems {
  final _found = <String>[];

  void check(Object? actual, Object? matcher, String reason) {
    try {
      expect(actual, matcher, reason: reason);
    } on TestFailure catch (e) {
      _found.add('$e'.trim());
    }
  }

  /// [items]のうち[test]に合うものがちょうど1つならそれを返す。
  T? one<T>(Iterable<T> items, bool Function(T) test, String reason) {
    final hits = items.where(test).toList();
    check(hits, hasLength(1), reason);
    return hits.firstOrNull;
  }

  void verify() {
    if (_found.isEmpty) return;
    fail('${_found.length} problem(s):\n\n${_found.join('\n\n')}');
  }
}

/// 元の端末の内容が1つずつ入っていること（`extra…`はこの端末にしか無い
/// 自作の項目の数）。
void _checkTransferred(
  _Problems p,
  _Device d,
  _BuiltInCounts builtIn, {
  int extraBrushes = 0,
  int extraThemes = 0,
  int extraPalettes = 0,
  required String when,
}) {
  final brushes = d.brush.brushes;
  p.check(_duplicates(brushes.map((b) => b.id)), isEmpty, '$when: brush ids');
  p.check(
    _duplicates(brushes.map((b) => b.name)),
    isEmpty,
    '$when: 組み込みのブラシが別のIDでもう一度入っていない',
  );
  p.check(brushes.length, builtIn.brushes + 1 + extraBrushes, '$when: ブラシの数');
  final pen = p.one(brushes, (b) => b.id == 'Brush0001', '$when: ペン');
  p.check(pen?.size, 23, '$when: 組み込みのペンで覚えた太さ');
  p.check(
    d.brush.hasRememberedBuiltInValues('Brush0001'),
    isTrue,
    '$when: 組み込みのペンの太さを覚えている',
  );
  p.check(
    p.one(brushes, (b) => b.id == 'Brush0002', '$when: Gペン')?.isFavorite,
    isTrue,
    '$when: 組み込みのお気に入り',
  );
  final custom = p.one(brushes, (b) => b.name == 'Custom A', '$when: 自作');
  final brushFolder = p.one(
    d.brush.folders,
    (f) => f.name == 'Brush folder A',
    '$when: ブラシのフォルダ',
  );
  p.check(custom?.folderId, brushFolder?.id, '$when: 自作のブラシのフォルダ');
  final brushImage = custom?.customImagePath;
  p.check(
    brushImage != null && File(brushImage).existsSync()
        ? File(brushImage).readAsBytesSync()
        : null,
    [1, 2, 3, 4],
    '$when: 自作のブラシの画像',
  );

  final tones = d.tone.tones;
  p.check(_duplicates(tones.map((t) => t.id)), isEmpty, '$when: tone ids');
  p.check(tones.length, builtIn.tones + 1, '$when: トーンの数');
  final tone = p.one(tones, (t) => t.name == 'Custom tone A', '$when: トーン');
  p.check(
    tone?.folderId,
    p
        .one(
          d.tone.folders,
          (f) => f.name == 'Tone folder A',
          '$when: トーンのフォルダが1つ',
        )
        ?.id,
    '$when: トーンのフォルダ',
  );

  final stamps = d.stamp.stamps;
  p.check(_duplicates(stamps.map((s) => s.id)), isEmpty, '$when: stamp ids');
  p.check(stamps.length, builtIn.stamps + 1, '$when: スタンプの数');
  final stamp = p.one(stamps, (s) => s.name == 'Custom stamp A', '$when: スタンプ');
  p.check(
    stamp?.folderId,
    p
        .one(
          d.stamp.folders,
          (f) => f.name == 'Stamp folder A',
          '$when: スタンプのフォルダが1つ',
        )
        ?.id,
    '$when: スタンプのフォルダ',
  );

  final presets = d.autofill.presets;
  p.check(_duplicates(presets.map((x) => x.id)), isEmpty, '$when: preset ids');
  p.check(presets.length, builtIn.autofill + 1, '$when: 見本の自動塗り設定が増えていない');
  p.one(presets, (x) => x.name == 'Custom preset A', '$when: 自動塗り設定');

  final themes = d.theme.presets;
  p.check(_duplicates(themes.map((t) => t.id)), isEmpty, '$when: theme ids');
  p.check(
    themes.length,
    builtIn.themes + 1 + extraThemes,
    '$when: 組み込みのテーマが増えていない',
  );
  p.one(themes, (t) => t.name == 'My theme A', '$when: 自作のテーマ');
  p.check(d.theme.current.name, 'My theme A', '$when: 今のテーマ');
  p.check(d.theme.isEditingPreset, isTrue, '$when: 編集していたテーマは一覧のそのテーマのまま');

  final palettes = d.palette.palettes;
  p.check(
    _duplicates(palettes.map((x) => x.id)),
    isEmpty,
    '$when: palette ids',
  );
  p.check(palettes.length, 2 + extraPalettes, '$when: 最初のパレット（マイパレット）が2つにならない');
  p.check(p.one(palettes, (x) => x.name == 'Pal A', '$when: パレット')?.colors, [
    0xFF445566,
  ], '$when: パレットの色');
  p.check(d.palette.recentColors, contains(0xFF010203), '$when: 最近使った色');
  final pixel = d.pixelArt.palettes;
  p.check(_duplicates(pixel.map((x) => x.id)), isEmpty, '$when: pixel ids');
  p.one(pixel, (x) => x.name == 'Pix A', '$when: ドット絵パレット');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_transfer_merge_');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a fresh install gets each item once, keeps the remembered size of '
      'built-in brushes and folders, and a later save or restart does not '
      'undo the import', () async {
    final p = _Problems();
    final bytes = await _exportFromSource(temp);
    final documents = Directory('${temp.path}/dst')..createSync();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final dst = await _Device.start();
    final builtIn = _BuiltInCounts(dst);
    await dst.import(bytes, documents);
    _checkTransferred(p, dst, builtIn, when: 'after import');

    // この時点で起動し直したときに見える内容（読み込みの後に何も保存して
    // いない）。動いているサービスはそのまま使い続ける。
    final peek = await _Device.start();
    _checkTransferred(p, peek, builtIn, when: 'restart right after import');

    // 読み込んだ後、動いているサービスでいつもの操作をして保存する（お気に
    // 入り・キャンバスで太さを変える）。読み込んだ内容が古い一覧で上書き
    // されない。
    final s = dst;
    final customId = s.brush.brushes
        .where((b) => b.name == 'Custom A')
        .firstOrNull
        ?.id;
    if (customId != null) s.brush.toggleFavoriteBrush(customId);
    s.brush.selectBrush('Brush0003');
    s.brush.updateCurrentBrushSize(builtIn.brush0003Size + 8);
    await s.brush.commitRememberedValues();
    final toneId = s.tone.tones
        .where((t) => t.name == 'Custom tone A')
        .firstOrNull
        ?.id;
    if (toneId != null) s.tone.toggleFavorite(toneId);
    final stampId = s.stamp.stamps
        .where((t) => t.name == 'Custom stamp A')
        .firstOrNull
        ?.id;
    if (stampId != null) s.stamp.toggleFavorite(stampId);
    final themeId = s.theme.presets
        .where((t) => t.name == 'My theme A')
        .firstOrNull
        ?.id;
    if (themeId != null) s.theme.toggleFavorite(themeId);
    final paletteId = s.palette.palettes
        .where((x) => x.name == 'Pal A')
        .firstOrNull
        ?.id;
    if (paletteId != null) await s.palette.toggleFavorite(paletteId);
    await _settle();
    _checkTransferred(p, s, builtIn, when: 'after saving');

    final again = await _Device.start();
    _checkTransferred(p, again, builtIn, when: 'restart after saving');
    p.check(
      again.brush.brushes
          .where((b) => b.name == 'Custom A')
          .map((b) => b.isFavorite),
      [true],
      'restart after saving: お気に入りにしたブラシ',
    );
    p.check(
      again.brush.brushes.where((b) => b.id == 'Brush0003').map((b) => b.size),
      [builtIn.brush0003Size + 8],
      'restart after saving: 読み込みの後に覚えた太さ',
    );
    p.verify();
  });

  test(
    'importing into the same install again adds nothing and keeps what '
    'only this install has, including a saved brush it cannot read',
    () async {
      final p = _Problems();
      final bytes = await _exportFromSource(temp);
      final documents = Directory('${temp.path}/dst')..createSync();

      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final fresh = await _Device.start();
      final builtIn = _BuiltInCounts(fresh);
      // この端末だけの自作の項目と、この版では読めない保存のブラシ1件。
      final ownImage = File('${temp.path}/own.png')..writeAsBytesSync([7, 7]);
      fresh.brush.addBrush(
        _customBrush('BrushOwn', 'Own brush', ownImage.path),
      );
      fresh.theme.savePreset(
        AppThemePreset.defaultDark.copyWith(id: 'theme_own', name: 'Own theme'),
      );
      await fresh.palette.createPalette('Own palette');
      await _settle();
      const unreadable = '{"id": "BrushFuture", "name": 5}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('brushes', [
        ...prefs.getStringList('brushes')!,
        unreadable,
      ]);

      final dst = await _Device.start();
      await dst.import(bytes, documents);
      await dst.import(bytes, documents);
      void checkOwn(_Device d, String when) {
        _checkTransferred(
          p,
          d,
          builtIn,
          extraBrushes: 1,
          extraThemes: 1,
          extraPalettes: 1,
          when: when,
        );
        p.one(
          d.brush.brushes,
          (b) => b.name == 'Own brush',
          '$when: この端末にしか無いブラシを、元の端末の一覧で消さない',
        );
        p.one(d.theme.presets, (t) => t.name == 'Own theme', '$when: テーマ');
        p.one(
          d.palette.palettes,
          (x) => x.name == 'Own palette',
          '$when: パレット',
        );
        p.check(
          prefs.getStringList('brushes'),
          contains(unreadable),
          '$when: 読めない保存の項目は、取り込みで保存し直しても残す',
        );
      }

      checkOwn(dst, 'after importing twice');
      final restarted = await _Device.start();
      checkOwn(restarted, 'restart after importing twice');
      // 読み直しで画像のファイルを増やさない（同じ中身の画像を使い回す）。
      for (final folder in ['Brushes', 'Tones', 'Stamps']) {
        p.check(
          Directory('${documents.path}/niarim/$folder').listSync(),
          hasLength(1),
          '$folder: 読み直しで画像のファイルが増えない',
        );
      }
      p.verify();
    },
  );

  test('a file made before images were bundled (no remembered-size map, no '
      'folders) is merged the same way', () async {
    final temp2 = Directory('${temp.path}/src')..createSync();
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final src = await _Device.start();
    src.brush.selectBrush('Brush0001');
    src.brush.updateCurrentBrushSize(23);
    await src.brush.commitRememberedValues();
    final image = File('${temp2.path}/old.png')..writeAsBytesSync([3, 3]);
    src.brush.addBrush(_customBrush('BrushOld', 'Old custom', image.path));
    await _settle();
    final bytes = await NiatraSerializer.export(
      selectedItems: const {'ブラシ': true, 'UIテーマ': true},
      settings: src.settings,
      brush: src.brush,
      tone: src.tone,
      stamp: src.stamp,
      autofillPresets: src.autofill,
      theme: src.theme,
      palette: src.palette,
      pixelArtPalette: src.pixelArt,
    );
    await _settle();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final dst = await _Device.start();
    final builtInBrushes = dst.brush.brushes.length;
    final builtInThemes = dst.theme.presets.length;
    for (var i = 0; i < 2; i++) {
      final data = NiatraSerializer.loadFromBytes(bytes);
      // 古いファイルには覚えた太さの一覧もフォルダも無い。
      data.raw
        ..remove('brushRememberedBuiltInValues')
        ..remove('brushFolders');
      await NiatraAssetBundle.restoreEmbeddedAssets(
        data,
        brush: dst.brush,
        tone: dst.tone,
        stamp: dst.stamp,
        restoreBasePath: temp.path,
      );
      await Future<void>.sync(
        () => NiatraSerializer.applyTo(
          data,
          settings: dst.settings,
          brush: dst.brush,
          tone: dst.tone,
          stamp: dst.stamp,
          autofillPresets: dst.autofill,
          theme: dst.theme,
          palette: dst.palette,
          pixelArtPalette: dst.pixelArt,
        ),
      );
    }
    await _settle();
    for (final d in [dst, await _Device.start()]) {
      expect(d.brush.brushes, hasLength(builtInBrushes + 1));
      expect(
        d.brush.brushes.where((b) => b.name == 'Old custom'),
        hasLength(1),
      );
      expect(
        d.brush.brushes.singleWhere((b) => b.id == 'Brush0001').size,
        23,
        reason: '覚えた太さの一覧が無いファイルでは、組み込みの値のうち定義と違うもの',
      );
      expect(d.brush.hasRememberedBuiltInValues('Brush0001'), isTrue);
      expect(d.theme.presets, hasLength(builtInThemes));
    }
  });

  test('device data in an older file does not overwrite the lists that the '
      'items merge, but other saved settings are still restored', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final dst = await _Device.start();
    await _settle();
    final prefs = await SharedPreferences.getInstance();
    final brushesBefore = prefs.getStringList('brushes');
    final themesBefore = prefs.getStringList('theme_presets');
    final data = NiatraData({
      'localPreferences': {
        'brushes': ['{"id":"BrushFromOldFile"}'],
        'brush_builtin_working_values': '{"Brush0001":{"size":99}}',
        'theme_presets': <String>[],
        'tones': <String>[],
        'color_palettes': <String>[],
        'autofill_presets': <String>[],
        'pixel_art_palettes': <String>[],
        'stamps': <String>[],
        'bucket_tolerance': 42.0,
        'google_refresh_token': 'never',
      },
    }, Archive());
    await NiatraSerializer.restoreLocalPreferences(data);
    expect(prefs.getStringList('brushes'), brushesBefore);
    expect(prefs.getString('brush_builtin_working_values'), isNull);
    expect(prefs.getStringList('theme_presets'), themesBefore);
    expect(prefs.getStringList('tones'), isNot(isEmpty));
    expect(prefs.getDouble('bucket_tolerance'), 42.0);
    expect(prefs.containsKey('google_refresh_token'), isFalse);

    final restarted = await _Device.start();
    expect(restarted.brush.brushes.length, dst.brush.brushes.length);
    expect(restarted.theme.presets.length, dst.theme.presets.length);
  });

  test(
    'an id that looks like a path does not write outside the image folder',
    () async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final dst = await _Device.start();
      final archive = Archive()
        ..addFile(ArchiveFile('CreativeAssets/Brushes/0.png', 2, [8, 8]));
      final raw = <String, dynamic>{
        'creativeAssetsVersion': 1,
        'brushes': [
          {
            ..._customBrush('../../outside', 'Odd id', '').toJson(),
            'customImagePath': null,
            'embeddedImagePath': 'CreativeAssets/Brushes/0.png',
          },
        ],
      };
      final base = Directory('${temp.path}/base')..createSync();
      await NiatraAssetBundle.restoreEmbeddedAssets(
        NiatraData(raw, archive),
        brush: dst.brush,
        tone: dst.tone,
        stamp: dst.stamp,
        restoreBasePath: base.path,
      );
      final odd = dst.brush.brushes.singleWhere((b) => b.name == 'Odd id');
      final written = File(odd.customImagePath!);
      expect(written.readAsBytesSync(), [8, 8]);
      expect(
        written.parent.absolute.path,
        Directory('${base.path}/niarim/Brushes').absolute.path,
      );
      expect(temp.listSync().map((e) => e.path.split('/').last), ['base']);
    },
  );

  test('every imported palette gets its own id', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final src = await _Device.start();
    for (var i = 0; i < 40; i++) {
      await src.palette.createPalette('Palette $i');
      await src.pixelArt.addPalette('Pixel $i', [0xFF000000 + i]);
    }
    await _settle();
    final bytes = await src.export();
    await _settle();

    SharedPreferences.setMockInitialValues({'language': 'ja'});
    final dst = await _Device.start();
    await dst.import(bytes, Directory('${temp.path}/dst')..createSync());
    expect(_duplicates(dst.palette.palettes.map((p) => p.id)), isEmpty);
    expect(_duplicates(dst.pixelArt.palettes.map((p) => p.id)), isEmpty);
    expect(
      dst.palette.palettes.where((p) => p.name.startsWith('Palette ')),
      hasLength(40),
    );
    expect(dst.pixelArt.palettes, hasLength(40));

    final restarted = await _Device.start();
    expect(_duplicates(restarted.palette.palettes.map((p) => p.id)), isEmpty);
    expect(_duplicates(restarted.pixelArt.palettes.map((p) => p.id)), isEmpty);
    expect(restarted.pixelArt.palettes, hasLength(40));
  });
}
