import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/l10n/creative_preset_labels.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 紙・布の質感、和柄・布柄のトーンと、漫符・飾りのスタンプ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tones = {
    'Tone0066': '水彩紙',
    'Tone0067': '画用紙',
    'Tone0068': 'キャンバス地',
    'Tone0069': '青海波',
    'Tone0070': '麻の葉',
    'Tone0071': '輪つなぎ',
    'Tone0072': 'うろこ',
    'Tone0073': 'チェック柄',
    'Tone0074': 'ハウンドトゥース',
  };
  const stamps = {
    'Stamp0029': 'しずく',
    'Stamp0030': '青筋マーク',
    'Stamp0031': '音符',
    'Stamp0032': 'スノーフレーク',
    'Stamp0033': '花びら',
  };

  double meanInk(Uint8List rgba) {
    var sum = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      sum += rgba[i];
    }
    return sum / 255 / (rgba.length / 4);
  }

  test('新しい組み込みは入れたばかりのアプリにあり、7言語の名前がある', () async {
    SharedPreferences.setMockInitialValues({});
    final toneService = ToneService();
    final stampService = StampService();
    await toneService.init();
    await stampService.init();
    for (final MapEntry(key: id, value: name) in tones.entries) {
      final tone = toneService.tones.singleWhere((t) => t.id == id);
      expect(tone.name, name);
      expect(tone.texturePath, 'assets/tones/$id.png');
      expect(tone.pixelMode, isFalse);
      expect(tone.tags, isNotEmpty);
    }
    for (final MapEntry(key: id, value: name) in stamps.entries) {
      final stamp = stampService.stamps.singleWhere((s) => s.id == id);
      expect(stamp.name, name);
      expect(stamp.imagePath, 'assets/stamps/$id.png');
      expect(builtInStampShapes[id], isNotNull);
    }
    for (final locale in AppLocalizations.supportedLocales) {
      final words = lookupAppLocalizations(locale);
      for (final name in [...tones.values, ...stamps.values]) {
        final label = creativePresetLabel(words, name, builtIn: true);
        if (locale.languageCode == 'ja') {
          expect(label, name);
        } else {
          // Chinese may share the kanji (青海波, 音符), never the kana.
          expect(
            RegExp('[\u3040-\u30ff]').hasMatch(label),
            isFalse,
            reason: '$name in $locale: $label',
          );
          if (!locale.languageCode.startsWith('zh')) {
            expect(label, isNot(name), reason: '$name in $locale');
          }
        }
      }
    }
    toneService.dispose();
    stampService.dispose();
  });

  test('前の版の保存にも新しい組み込みが足され、利用者の項目はそのまま', () async {
    SharedPreferences.setMockInitialValues({
      'tones': [
        jsonEncode(
          const Tone(id: 'Tone0001', name: '影の網点', isFavorite: true).toJson(),
        ),
      ],
      'stamps': ['{"id":"Stamp0004","name":"星","isFavorite":true}'],
      // An install that already grouped its presets keeps the saved order.
      'tone_grouped_presets_v1': true,
      'stamp_grouped_presets_v1': true,
    });
    final toneService = ToneService();
    final stampService = StampService();
    await toneService.init();
    await stampService.init();
    final mine = toneService.tones.first;
    expect(mine.id, 'Tone0001');
    expect(mine.name, '影の網点');
    expect(mine.isFavorite, isTrue);
    for (final id in tones.keys) {
      expect(toneService.tones.where((t) => t.id == id), hasLength(1));
    }
    expect(stampService.stamps.first.id, 'Stamp0004');
    expect(stampService.stamps.first.isFavorite, isTrue);
    for (final id in stamps.keys) {
      expect(stampService.stamps.where((s) => s.id == id), hasLength(1));
    }
    toneService.dispose();
    stampService.dispose();
  });

  test('紙・布の質感は濃淡のある薄いトーンで、紙の残る所がある', () {
    for (final name in ['水彩紙', '画用紙', 'キャンバス地']) {
      final rgba = generateBuiltInToneTexture(Tone(id: name, name: name));
      final ink = meanInk(rgba);
      expect(ink, inInclusiveRange(0.08, 0.45), reason: '$name $ink');
      final levels = <int>{for (var i = 3; i < rgba.length; i += 4) rgba[i]};
      expect(levels.length, greaterThan(64), reason: name);
      expect(levels.contains(0), isTrue, reason: name);
    }
  });

  test('チェック柄は縞の所が半分、重なる所が全部の濃さ', () {
    final rgba = generateBuiltInToneTexture(const Tone(id: 'g', name: 'チェック柄'));
    final levels = <int>{for (var i = 3; i < rgba.length; i += 4) rgba[i]};
    expect(levels, {0, 128, 255});
    expect(meanInk(rgba), closeTo(0.5, 0.01));
  });

  test('うろこは三角形が半分を覆う', () {
    final rgba = generateBuiltInToneTexture(const Tone(id: 'u', name: 'うろこ'));
    expect(meanInk(rgba), closeTo(0.5, 0.02));
  });
}
