import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/layer.dart' show LayerBlendMode;

/// AutofillPart.isConfigured（Task#71「未設定時は保存不可」の判定基準）の
/// 単体テスト。
void main() {
  test('トーン未使用ならisConfiguredはtrue', () {
    const part = AutofillPart(id: 'p1', name: '肌', color: 0xFFFFD5B0);
    expect(part.isConfigured, isTrue);
  });

  test('トーン使用中でトーン未選択ならisConfiguredはfalse', () {
    const part = AutofillPart(id: 'p1', name: '肌', color: 0xFFFFD5B0, useTone: true);
    expect(part.isConfigured, isFalse);
  });

  test('トーン使用中でトーン選択済みならisConfiguredはtrue', () {
    const part =
        AutofillPart(id: 'p1', name: '肌', color: 0xFFFFD5B0, useTone: true, toneId: 'tone1');
    expect(part.isConfigured, isTrue);
  });

  test('toJson/fromJsonの往復で全フィールドが保持される', () {
    const part = AutofillPart(
      id: 'p1',
      name: '髪',
      color: 0xFF4A3728,
      opacity: 80,
      blendMode: LayerBlendMode.multiply,
      useTone: true,
      toneId: 'tone2',
      lineColorMode: AutofillLineColorMode.traceAdjust,
      lineColor: 0xFF112233,
      lineOpacity: 60,
      traceHue: 12,
      traceSaturation: 70,
      traceLightness: -30,
      isFavorite: true,
    );
    final restored = AutofillPart.fromJson(part.toJson());
    expect(restored.id, part.id);
    expect(restored.name, part.name);
    expect(restored.color, part.color);
    expect(restored.opacity, part.opacity);
    expect(restored.blendMode, part.blendMode);
    expect(restored.useTone, part.useTone);
    expect(restored.toneId, part.toneId);
    expect(restored.lineColorMode, part.lineColorMode);
    expect(restored.lineColor, part.lineColor);
    expect(restored.lineOpacity, part.lineOpacity);
    expect(restored.traceHue, part.traceHue);
    expect(restored.traceSaturation, part.traceSaturation);
    expect(restored.traceLightness, part.traceLightness);
    expect(restored.isFavorite, part.isFavorite);
  });
}
