// 組み込みブラシのうち、絵の具として混ざるもの（混色ブラシ・マーカーペン・
// 平筆・水彩・ガッシュ）だけが混色オン（所有者の依頼、2026-11-27
// 「プリセットのガッシュ系のブラシなど、混色すべきブラシは混色ONにしておいて
// ください」）。ガッシュは不透明な絵の具なので油彩風混色（下を覆い、引いた
// 所だけ混ぜる）で、混色ブラシより控えめに拾い、色延びも短い。乾いた画材
// （パステル・チョーク・木炭・鉛筆）・線を引くペン（面相筆を含む）・
// エアブラシ・スプレー・ピクセル・グリッター・チェーン・髪・網・コマ割りは
// 混色オフ。筆圧オン・オフのどちらでも同じ混ざり方にする。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

void main() {
  const mixing = {
    'Brush0004': BrushMixingMode.oil, // 混色ブラシ
    'Brush0005': BrushMixingMode.oil, // マーカーペン
    'Brush0009': BrushMixingMode.oil, // 平筆
    'Brush0010': BrushMixingMode.watercolor, // 水彩
    'Brush0027': BrushMixingMode.oil, // ガッシュ（不透明水彩）
  };
  final brushes = {for (final b in BrushService.builtInBrushes) b.id: b};

  test('only the paint brushes mix, each in its own way', () {
    for (final id in mixing.keys) {
      expect(brushes, contains(id));
    }
    for (final brush in brushes.values) {
      final on = brush.pressureOn.mixing;
      final off = brush.pressureOff.mixing;
      final mode = mixing[brush.id];
      expect(off.enabled, mode != null, reason: brush.name);
      // With and without pen pressure the brush mixes the same way.
      expect(on.enabled, off.enabled, reason: brush.name);
      if (mode == null) continue;
      expect(off.mode, mode, reason: brush.name);
      expect(on.mode, mode, reason: brush.name);
      expect(off.rate, greaterThan(0), reason: brush.name);
      expect(on.weakRate, off.rate, reason: brush.name);
      expect(on.strongRate, off.rate, reason: brush.name);
      expect(on.stretch, off.stretch, reason: brush.name);
    }
  });

  test('gouache picks up less than the oil mixing brush, and drags it less '
      'far', () {
    final gouache = brushes['Brush0027']!.pressureOff.mixing;
    final oil = brushes['Brush0004']!.pressureOff.mixing;
    expect(gouache.rate, lessThan(oil.rate));
    expect(gouache.stretch, lessThan(oil.stretch));
    // A marker's ink picked up on one colour soon runs out.
    final marker = brushes['Brush0005']!.pressureOff.mixing;
    expect(marker.stretch, lessThan(oil.stretch));
  });
}
