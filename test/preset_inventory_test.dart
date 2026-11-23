// 全プリセットの棚卸し（全面監査のD033）。
//
// 組み込みのブラシ・トーン・スタンプ・テーマ・自動操作・自動塗りを1件ずつ
// 当てて、結果が出ること・保存の形（JSON）で行き来して変わらないこと・
// 7言語の名前に日本語が残らないことを確かめる。1件＝1子TODO
// （AUDIT_DELTA_ROUTE.mdのD033.*）の根拠として、build/preset-inventory/ に
// 一覧（inventory.json）と結果の画像の一覧表（*.png）を書く。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/l10n/autofill_names.dart';
import 'package:niarim/l10n/creative_preset_labels.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/utils/custom_automation_labels.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languages = ['en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
final _kana = RegExp(r'[぀-ヿ]');
final _kanji = RegExp(r'[一-鿿]');

AppLocalizations _words(String code) => lookupAppLocalizations(
  code == 'zh_Hant'
      ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
      : Locale(code),
);

/// Japanese must not show through in another language: no kana anywhere,
/// and no kanji outside Chinese.
String? _japaneseLeft(String code, String text) {
  if (_kana.hasMatch(text)) return '$code: $text';
  if (!code.startsWith('zh') && _kanji.hasMatch(text)) return '$code: $text';
  return null;
}

int _ink(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n;
}

/// Lays [tiles] (RGBA, [w]×[h] each) out in rows of [columns] on white.
img.Image _sheet(List<Uint8List> tiles, int w, int h, {int columns = 6}) {
  final rows = (tiles.length + columns - 1) ~/ columns;
  final sheet = img.Image(width: w * columns, height: h * rows);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  for (var i = 0; i < tiles.length; i++) {
    final tile = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: tiles[i].buffer,
      numChannels: 4,
    );
    img.compositeImage(
      sheet,
      tile,
      dstX: (i % columns) * w,
      dstY: (i ~/ columns) * h,
    );
    img.drawRect(
      sheet,
      x1: (i % columns) * w,
      y1: (i ~/ columns) * h,
      x2: (i % columns) * w + w - 1,
      y2: (i ~/ columns) * h + h - 1,
      color: img.ColorRgb8(220, 220, 220),
    );
  }
  return sheet;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final out = Directory('build/preset-inventory')..createSync(recursive: true);
  final inventory = <String, List<Map<String, Object?>>>{};
  tearDownAll(
    () => File(
      '${out.path}/inventory.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(inventory)),
  );

  testWidgets('ブラシ：どれも線を描き、保存の形で変わらず、7言語の名前がある', (tester) async {
    const w = 240, h = 96;
    final brushes = BrushService.builtInBrushes;
    final tiles = <Uint8List>[];
    final problems = <String>[];
    for (final brush in brushes) {
      final pixels = (await tester.runAsync(() async {
        final tm = TileManager(canvasWidth: w, canvasHeight: h);
        try {
          final engine = DrawingEngine(tileManager: tm)
            ..currentColor = const Color(0xFF2B2A3A)
            ..currentBrush = brush.copyWith(
              size: brush.size.clamp(4, 28).toDouble(),
            )
            ..pressureEnabled = false;
          engine.beginStroke(const StrokePoint(x: 24, y: 60), 'layer');
          for (var x = 28.0; x <= 216; x += 4) {
            final t = (x - 24) / 192;
            engine.continueStroke(
              StrokePoint(x: x, y: 60 - 28 * (4 * t * (1 - t))),
              'layer',
            );
          }
          engine.endStroke();
          final image = await tm.compositeLayerToImage('layer');
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return data!.buffer.asUint8List();
        } finally {
          tm.dispose();
        }
      }))!;
      if (_ink(pixels) < 40) problems.add('${brush.id} ${brush.name}: 線が無い');
      final again = Brush.fromJson(
        jsonDecode(jsonEncode(brush.toJson())) as Map<String, dynamic>,
      );
      if (jsonEncode(again.toJson()) != jsonEncode(brush.toJson())) {
        problems.add('${brush.id}: 保存の形で変わる');
      }
      final names = {
        for (final code in _languages)
          code: creativePresetLabel(_words(code), brush.name, builtIn: true),
      };
      for (final MapEntry(:key, :value) in names.entries) {
        final left = _japaneseLeft(key, value);
        if (left != null) problems.add('${brush.id} 名前 $left');
      }
      tiles.add(pixels);
      (inventory['brush'] ??= []).add({
        'id': brush.id,
        'name': brush.name,
        'names': names,
        'ink': _ink(pixels),
      });
    }
    File(
      '${out.path}/brushes.png',
    ).writeAsBytesSync(img.encodePng(_sheet(tiles, w, h, columns: 5)));
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(brushes.length, greaterThanOrEqualTo(32));
  });

  test('トーン：どれも模様を描き、保存の形で変わらず、7言語の名前がある', () async {
    final service = ToneService();
    await service.init();
    final tones = [
      for (final tone in service.tones)
        if (service.isBuiltIn(tone.id)) tone,
    ];
    await Future.wait(tones.map(ensureToneTextureLoaded));
    final tiles = <Uint8List>[];
    final problems = <String>[];
    for (final tone in tones) {
      final rgba = generateBuiltInToneTexture(tone);
      final ink = _ink(rgba);
      if (ink == 0 || ink == rgba.length ~/ 4) {
        problems.add('${tone.id} ${tone.name}: 白紙か全面ベタ');
      }
      final again = Tone.fromJson(
        jsonDecode(jsonEncode(tone.toJson())) as Map<String, dynamic>,
      );
      if (jsonEncode(again.toJson()) != jsonEncode(tone.toJson())) {
        problems.add('${tone.id}: 保存の形で変わる');
      }
      final names = {
        for (final code in _languages)
          code: creativePresetLabel(_words(code), tone.name, builtIn: true),
      };
      for (final MapEntry(:key, :value) in names.entries) {
        final left = _japaneseLeft(key, value);
        if (left != null) problems.add('${tone.id} 名前 $left');
      }
      tiles.add(rgba);
      (inventory['tone'] ??= []).add({
        'id': tone.id,
        'name': tone.name,
        'names': names,
      });
    }
    File(
      '${out.path}/tones.png',
    ).writeAsBytesSync(img.encodePng(_sheet(tiles, 64, 64, columns: 12)));
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(tones.length, greaterThanOrEqualTo(62));
  });

  test('スタンプ：どれも形を描き、保存の形で変わらず、7言語の名前がある', () async {
    final service = StampService();
    await service.init();
    final stamps = [
      for (final stamp in service.stamps)
        if (service.isBuiltIn(stamp.id)) stamp,
    ];
    final tiles = <Uint8List>[];
    final problems = <String>[];
    for (final stamp in stamps) {
      final rgba = await generateBuiltInStampTexture(stamp);
      final ink = _ink(rgba);
      if (ink == 0 || ink == rgba.length ~/ 4) {
        problems.add('${stamp.id} ${stamp.name}: 空か全面ベタ');
      }
      final again = Stamp.fromJson(
        jsonDecode(jsonEncode(stamp.toJson())) as Map<String, dynamic>,
      );
      if (jsonEncode(again.toJson()) != jsonEncode(stamp.toJson())) {
        problems.add('${stamp.id}: 保存の形で変わる');
      }
      final names = {
        for (final code in _languages)
          code: creativePresetLabel(_words(code), stamp.name, builtIn: true),
      };
      for (final MapEntry(:key, :value) in names.entries) {
        final left = _japaneseLeft(key, value);
        if (left != null) problems.add('${stamp.id} 名前 $left');
      }
      tiles.add(rgba);
      (inventory['stamp'] ??= []).add({
        'id': stamp.id,
        'name': stamp.name,
        'names': names,
      });
    }
    File(
      '${out.path}/stamps.png',
    ).writeAsBytesSync(img.encodePng(_sheet(tiles, 128, 128, columns: 8)));
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(stamps.length, greaterThanOrEqualTo(23));
  });

  test('テーマ：どれも画面の色を作り、保存の形で変わらない', () async {
    final service = ThemeService();
    await service.init();
    final themes = [
      for (final preset in service.presets)
        if (ThemeService.isBuiltInPreset(preset.id)) preset,
    ];
    final problems = <String>[];
    for (final preset in themes) {
      service.restoreCurrent(preset);
      final theme = service.themeData;
      if (theme.colorScheme.primary != Color(preset.accentColor.toARGB32())) {
        problems.add('${preset.id}: 差し色が画面に出ない');
      }
      final again = AppThemePreset.fromJson(
        jsonDecode(jsonEncode(preset.toJson())) as Map<String, dynamic>,
      );
      if (jsonEncode(again.toJson()) != jsonEncode(preset.toJson())) {
        problems.add('${preset.id}: 保存の形で変わる');
      }
      (inventory['theme'] ??= []).add({
        'id': preset.id,
        'name': preset.name,
        'accent':
            '#${preset.accentColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      });
    }
    service.dispose();
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(themes.length, greaterThanOrEqualTo(28));
  });

  test('自動操作：公式の手順が読め、保存の形で変わらず、7言語の名前と手順名がある', () {
    final presets = CustomAutomationBuiltinPresets.all();
    final problems = <String>[];
    for (final preset in presets) {
      if (preset.steps.isEmpty) problems.add('${preset.id}: 手順が無い');
      final again = CustomAutomation.fromJson(
        (jsonDecode(jsonEncode(preset.toJson())) as Map)
            .cast<String, Object?>(),
      );
      if (jsonEncode(again.toJson()) != jsonEncode(preset.toJson())) {
        problems.add('${preset.id}: 保存の形で変わる');
      }
      final names = <String, String>{};
      for (final code in _languages) {
        final words = _words(code);
        names[code] = customAutomationDisplayName(words, preset.name);
        final texts = [
          names[code]!,
          for (final step in preset.steps)
            customAutomationStepLabel(words, step),
        ];
        for (final text in texts) {
          final left = _japaneseLeft(code, text);
          if (left != null) problems.add('${preset.id} $left');
        }
      }
      (inventory['automation'] ??= []).add({
        'id': preset.id,
        'name': preset.name,
        'steps': preset.steps.length,
        'names': names,
      });
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(presets.length, greaterThanOrEqualTo(3));
  });

  test('自動塗り：組み込みのプリセットとパーツが保存の形で変わらず、7言語の名前がある', () async {
    final service = AutofillPresetService();
    await service.init();
    final presets = [
      for (final preset in service.presets)
        if (AutofillPresetService.hasDefaultPresetName(preset)) preset,
    ];
    final problems = <String>[];
    for (final preset in presets) {
      if (preset.parts.isEmpty) problems.add('${preset.id}: パーツが無い');
      final again = AutofillPreset.fromJson(
        jsonDecode(jsonEncode(preset.toJson())) as Map<String, dynamic>,
      );
      if (jsonEncode(again.toJson()) != jsonEncode(preset.toJson())) {
        problems.add('${preset.id}: 保存の形で変わる');
      }
      final names = <String, String>{};
      for (final code in _languages) {
        final words = _words(code);
        names[code] = preset.displayName(words);
        for (final text in [
          names[code]!,
          for (final part in preset.parts) part.displayName(words),
        ]) {
          final left = _japaneseLeft(code, text);
          if (left != null) problems.add('${preset.id} $left');
        }
      }
      (inventory['autofill'] ??= []).add({
        'id': preset.id,
        'name': preset.name,
        'parts': preset.parts.length,
        'names': names,
      });
    }
    service.dispose();
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(presets, isNotEmpty);
  });
}
