import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/models/stamp.dart';

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
        id: 'BrushCustom001',
        name: '自作ブラシ',
        size: 12,
        opacity: 90,
        spacing: 15,
        stabilization: true,
        stabilizationStrength: 40,
        pixelMode: true,
        pressureOn: const BrushPressureOnSettings(
          size: PressureRangeSetting(enabled: true, weak: 45, strong: 100),
          opacity: PressureRangeSetting(enabled: true, weak: 45, strong: 100),
          blur: PressureRangeSetting(enabled: true, weak: 5, strong: 5),
          edgeJitter: PressureRangeSetting(
            enabled: false,
            weak: 50,
            strong: 50,
          ),
          mixing: PressureMixingOnSetting(
            enabled: true,
            mode: BrushMixingMode.bleed,
            weakRate: 40,
            strongRate: 40,
          ),
        ),
        pressureOff: const BrushPressureOffSettings(
          blur: FixedBrushSetting(enabled: true, value: 5),
          edgeJitter: FixedBrushSetting(enabled: false, value: 50),
          mixing: PressureMixingOffSetting(
            enabled: true,
            mode: BrushMixingMode.bleed,
            rate: 40,
          ),
        ),
        fadeMode: FadeMode.custom,
        fadeIn: const FadeEndpointSettings(value: 100, rangePx: 80),
        fadeOut: const FadeEndpointSettings(value: 20, rangePx: 160),
        strokeDecay: true,
      );
      s1.addBrush(custom);
      s1.updateBrush(custom.copyWith(size: 20));

      final s2 = BrushService();
      await s2.init();
      final restored = s2.brushes.firstWhere((b) => b.id == 'BrushCustom001');
      expect(restored.size, 20);
      expect(restored.pixelMode, isTrue);
      expect(restored.fadeIn.value, 100);
      expect(restored.fadeIn.rangePx, 80);
      expect(restored.fadeOut.value, 20);
      expect(restored.fadeOut.rangePx, 160);
      expect(restored.pressureOn.mixing.mode, BrushMixingMode.bleed);
      expect(restored.pressureOff.mixing.mode, BrushMixingMode.bleed);
    });


    test('四コマ漫画ブラシの形状設定が複製・再起動後も保持される', () async {
      final s1 = BrushService();
      await s1.init();
      final source = s1.brushes.firstWhere((b) => b.id == 'Brush0025');
      expect(source.tipShape, BrushTipShape.hollowSquare);
      expect(source.rotation, isTrue);
      expect(source.spacing, 125);
      expect(source.size, 80);

      s1.duplicateBrush(source.id);
      final duplicate = s1.brushes.last;
      expect(duplicate.tipShape, BrushTipShape.hollowSquare);
      expect(duplicate.rotation, isTrue);
      expect(duplicate.spacing, 125);
      expect(duplicate.size, 80);

      final s2 = BrushService();
      await s2.init();
      final restored = s2.brushes.firstWhere((b) => b.id == duplicate.id);
      expect(restored.tipShape, BrushTipShape.hollowSquare);
      expect(restored.rotation, isTrue);
      expect(restored.spacing, 125);
      expect(restored.size, 80);
    });

    test('.niabrush round-trip preserves four-panel hollow-square geometry', () async {
      final dir = await Directory.systemTemp.createTemp('niarim-four-panel-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final service = BrushService();
      await service.init();
      final source = service.brushes.firstWhere((b) => b.id == 'Brush0025');
      final path = '${dir.path}/four-panel.niabrush';
      await service.exportBrushToPath(source.id, path);
      final imported = await service.importBrushFile(
        path,
        imagesDirectory: '${dir.path}/images',
      );

      expect(imported.tipShape, BrushTipShape.hollowSquare);
      expect(imported.rotation, isTrue);
      expect(imported.spacing, 125);
      expect(imported.size, 80);
      expect(imported.lateralRepeatEnabled, isFalse);
      expect(imported.lateralRepeatCount, 1);
    });

    test('ブラシ複製で入り/抜きの値と範囲を独立保持する', () async {
      final service = BrushService();
      await service.init();
      final source = Brush(
        id: 'BrushTaperDuplicate',
        name: '入り抜き複製',
        size: 12,
        opacity: 100,
        spacing: 2,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        fadeMode: FadeMode.custom,
        fadeIn: const FadeEndpointSettings(value: 82, rangePx: 73),
        fadeOut: const FadeEndpointSettings(value: 17, rangePx: 211),
        strokeDecay: false,
      );
      service.addBrush(source);
      service.duplicateBrush(source.id);

      final duplicate = service.brushes.last;
      expect(duplicate.id, isNot(source.id));
      expect(duplicate.fadeIn.value, 82);
      expect(duplicate.fadeIn.rangePx, 73);
      expect(duplicate.fadeOut.value, 17);
      expect(duplicate.fadeOut.rangePx, 211);
    });

    test('.niabrush export/import preserves independent fade and custom images', () async {
      final dir = await Directory.systemTemp.createTemp('niarim-niabrush-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final imageA = File('${dir.path}/a.png');
      final imageB = File('${dir.path}/b.png');
      await imageA.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));
      await imageB.writeAsBytes(Uint8List.fromList([5, 6, 7, 8]));

      final service = BrushService();
      await service.init();
      final source = Brush(
        id: 'BrushBundleRoundTrip',
        name: 'bundle round trip',
        size: 18,
        opacity: 91,
        spacing: 7,
        stabilization: true,
        stabilizationStrength: 33,
        pixelMode: true,
        fadeMode: FadeMode.custom,
        fadeIn: const FadeEndpointSettings(value: 81, rangePx: 74),
        fadeOut: const FadeEndpointSettings(value: 19, rangePx: 213),
        strokeDecay: true,
        customImagePaths: [imageA.path, imageB.path],
      );
      service.addBrush(source);

      final bundlePath = '${dir.path}/roundtrip.niabrush';
      await service.exportBrushToPath(source.id, bundlePath);
      final imported = await service.importBrushFile(
        bundlePath,
        imagesDirectory: '${dir.path}/imported',
      );

      expect(imported.id, isNot(source.id));
      expect(imported.fadeIn.value, 81);
      expect(imported.fadeIn.rangePx, 74);
      expect(imported.fadeOut.value, 19);
      expect(imported.fadeOut.rangePx, 213);
      expect(imported.pixelMode, isTrue);
      expect(imported.strokeDecay, isTrue);
      expect(imported.resolvedCustomImagePaths, hasLength(2));
      expect(await File(imported.resolvedCustomImagePaths[0]).readAsBytes(), [1, 2, 3, 4]);
      expect(await File(imported.resolvedCustomImagePaths[1]).readAsBytes(), [5, 6, 7, 8]);
    });
  });

  group('ToneService', () {
    test('自作トーンの追加とお気に入りが再起動後も復元される', () async {
      final s1 = ToneService();
      await s1.init();
      s1.addTone(
        const Tone(
          id: 'ToneCustom001',
          name: '自作トーン',
          texturePath: '/tmp/x.png',
        ),
      );
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
      s1.addStamp(
        const Stamp(
          id: 'StampCustom001',
          name: '自作スタンプ',
          imagePath: '/tmp/s.png',
          rotation: true,
          density: 2.0,
          scatter: 0.5,
        ),
      );

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
