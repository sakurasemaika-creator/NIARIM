import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/models/color_palette.dart';
import 'package:niarim/services/palette_service.dart';

/// PaletteService（Task#67で新設。色管理仕様のパレット・最近使った色機能）の
/// 単体テスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('初回起動時はデフォルトパレットが1件作成される', () async {
    final service = PaletteService();
    await service.init();
    expect(service.palettes, hasLength(1));
    expect(service.activePalette, isNotNull);
  });

  test('最近使った色は先頭に追加され、重複は移動、10件を超えると末尾から破棄される', () async {
    final service = PaletteService();
    await service.init();

    for (int i = 0; i < 12; i++) {
      await service.addRecentColor(0xFF000000 + i);
    }
    expect(service.recentColors, hasLength(10));
    // 直近に追加した色が先頭にある
    expect(service.recentColors.first, 0xFF00000B);

    // 既存の色を再度追加すると先頭へ移動し、件数は増えない
    final secondColor = service.recentColors[1];
    await service.addRecentColor(secondColor);
    expect(service.recentColors.first, secondColor);
    expect(service.recentColors, hasLength(10));
  });

  test('パレットの作成・色の追加・削除・お気に入り登録が反映される', () async {
    final service = PaletteService();
    await service.init();

    await service.createPalette('キャラA');
    expect(service.palettes, hasLength(2));
    final newPalette = service.activePalette!;
    expect(newPalette.name, 'キャラA');

    await service.addColorToPalette(newPalette.id, 0xFFFF0000);
    await service.addColorToPalette(newPalette.id, 0xFF00FF00);
    expect(service.activePalette!.colors, [0xFFFF0000, 0xFF00FF00]);

    await service.removeColorFromPalette(newPalette.id, 0);
    expect(service.activePalette!.colors, [0xFF00FF00]);

    await service.toggleFavorite(newPalette.id);
    expect(service.palettes.firstWhere((p) => p.id == newPalette.id).isFavorite, isTrue);
  });

  test('最後の1件のパレットは削除できない', () async {
    final service = PaletteService();
    await service.init();
    expect(service.palettes, hasLength(1));
    final onlyId = service.palettes.first.id;

    await service.deletePalette(onlyId);
    expect(service.palettes, hasLength(1),
        reason: '唯一のパレットは削除されずに残っているはず');
  });

  test('保存内容は再起動後も復元される', () async {
    final service1 = PaletteService();
    await service1.init();
    await service1.createPalette('引き継ぎテスト');
    await service1.addRecentColor(0xFF123456);

    final service2 = PaletteService();
    await service2.init();
    expect(service2.palettes.any((p) => p.name == '引き継ぎテスト'), isTrue);
    expect(service2.recentColors, contains(0xFF123456));
  });

  group('共有（Task#142：個別書き出し・QRコード共有）', () {
    test('importPaletteは新しいIDで取り込み、名前・色を保持する', () async {
      final service = PaletteService();
      await service.init();
      final before = service.palettes.length;

      final imported = await service.importPalette(
        const ColorPalette(id: 'other-device-id', name: '共有パレット', colors: [0xFF112233, 0xFF445566]),
      );

      expect(service.palettes, hasLength(before + 1));
      expect(imported.id, isNot('other-device-id'), reason: 'ID衝突を避けるため振り直すはず');
      expect(imported.name, '共有パレット');
      expect(imported.colors, [0xFF112233, 0xFF445566]);
    });

    test('importPaletteJsonはexportPaletteと同じJSON文字列から復元できる', () async {
      final service = PaletteService();
      await service.init();
      const source = ColorPalette(id: 'x', name: 'QR共有', colors: [0xFF000000]);
      final json = jsonEncode(source.toJson());

      final imported = await service.importPaletteJson(json);
      expect(imported.name, 'QR共有');
      expect(imported.colors, [0xFF000000]);
    });
  });
}
