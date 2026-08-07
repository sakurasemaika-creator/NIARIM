import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miranima/services/brush_service.dart';
import 'package:miranima/services/tone_service.dart';
import 'package:miranima/services/stamp_service.dart';
import 'package:miranima/services/filter_service.dart';
import 'package:miranima/models/brush.dart';
import 'package:miranima/models/tone.dart';
import 'package:miranima/models/stamp.dart';

/// Task#83：ブラシ・トーン・スタンプ・フィルターの状態が再起動で消えるバグの
/// 修正を検証する。従来はインメモリのみで、SharedPreferencesへの永続化が
/// 一切実装されていなかった（お気に入り・並び替え・複製・削除・パラメータ編集の
/// すべてがアプリ再起動のたびに失われていた）。ここでは「新しいサービス
/// インスタンスを作り直してもinit()後に状態が復元される」ことを、
/// アプリ再起動のシミュレーションとして検証する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BrushService', () {
    test('初回起動時は初期ブラシ一式が投入される', () async {
      final service = BrushService();
      await service.init();
      expect(service.brushes, isNotEmpty);
      expect(service.currentBrush, isNotNull);
    });

    test('お気に入り登録が再起動後も復元される', () async {
      final s1 = BrushService();
      await s1.init();
      final id = s1.brushes.first.id;
      s1.toggleFavoriteBrush(id);
      expect(s1.brushes.first.isFavorite, isTrue);

      // 「再起動」＝新しいインスタンスでinit()し直す
      final s2 = BrushService();
      await s2.init();
      expect(s2.brushes.firstWhere((b) => b.id == id).isFavorite, isTrue);
    });

    test('複製・削除・並び替えが再起動後も復元される', () async {
      final s1 = BrushService();
      await s1.init();
      final originalCount = s1.brushes.length;
      final firstId = s1.brushes.first.id;
      s1.duplicateBrush(firstId);
      expect(s1.brushes.length, originalCount + 1);
      s1.reorderBrush(0, s1.brushes.length - 1);
      final expectedOrder = s1.brushes.map((b) => b.id).toList();

      final s2 = BrushService();
      await s2.init();
      expect(s2.brushes.length, originalCount + 1);
      expect(s2.brushes.map((b) => b.id).toList(), expectedOrder);
    });

    test('カスタムブラシの追加・パラメータ編集が再起動後も復元される', () async {
      final s1 = BrushService();
      await s1.init();
      const custom = Brush(
        id: 'BrushCustom001', name: '自作ブラシ', size: 12, opacity: 90, spacing: 15,
        blurRadius: 5, stabilization: true, stabilizationStrength: 40,
        dotPenMode: true, pressureMode: PressureMode.sizeAndOpacity, pressureStrength: 55,
        fadeMode: FadeMode.custom,
        fadeCustom: FadeCustomSettings(startValue: 100, endValue: 20, distancePx: 80),
        strokeDecay: true, mixingMode: BrushMixingMode.bleed, mixingRate: 40,
      );
      s1.addBrush(custom);
      s1.updateBrush(custom.copyWith(size: 20));

      final s2 = BrushService();
      await s2.init();
      final restored = s2.brushes.firstWhere((b) => b.id == 'BrushCustom001');
      expect(restored.size, 20);
      expect(restored.dotPenMode, isTrue);
      expect(restored.fadeCustom?.startValue, 100);
      expect(restored.mixingMode, BrushMixingMode.bleed);
    });
  });

  group('ToneService', () {
    test('自作トーンの追加とお気に入りが再起動後も復元される', () async {
      final s1 = ToneService();
      await s1.init();
      s1.addTone(const Tone(id: 'ToneCustom001', name: '自作トーン', texturePath: '/tmp/x.png'));
      s1.toggleFavorite('ToneCustom001');

      final s2 = ToneService();
      await s2.init();
      final restored = s2.tones.firstWhere((t) => t.id == 'ToneCustom001');
      expect(restored.texturePath, '/tmp/x.png');
      expect(restored.isFavorite, isTrue);
    });
  });

  group('StampService', () {
    test('自作スタンプの追加が再起動後も復元される', () async {
      final s1 = StampService();
      await s1.init();
      s1.addStamp(const Stamp(
          id: 'StampCustom001', name: '自作スタンプ', imagePath: '/tmp/s.png',
          rotation: true, density: 2.0, scatter: 0.5));

      final s2 = StampService();
      await s2.init();
      final restored = s2.stamps.firstWhere((st) => st.id == 'StampCustom001');
      expect(restored.imagePath, '/tmp/s.png');
      expect(restored.rotation, isTrue);
      expect(restored.density, 2.0);
    });
  });

  group('FilterService', () {
    test('パラメータ変更・お気に入りが再起動後も復元される', () async {
      final s1 = FilterService();
      await s1.init();
      final id = s1.filters.first.id;
      s1.updateFilterParams(id, strength: 15);
      s1.toggleFavorite(id);

      final s2 = FilterService();
      await s2.init();
      final restored = s2.filters.firstWhere((f) => f.id == id);
      expect(restored.strength, 15);
      expect(restored.isFavorite, isTrue);
    });
  });
}
