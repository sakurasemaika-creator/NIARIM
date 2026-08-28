import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';

/// PixelArtPaletteService（Task#151：ドット絵専用パレット管理）の単体テスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('初回起動時はパレットが0件', () async {
    final service = PixelArtPaletteService();
    await service.init();
    expect(service.palettes, isEmpty);
  });

  test('パレットの追加・取得・更新・削除ができる', () async {
    final service = PixelArtPaletteService();
    await service.init();

    final palette = await service.addPalette('レトロ8色', [0xFF000000, 0xFFFFFFFF]);
    expect(service.palettes, hasLength(1));
    expect(service.paletteById(palette.id)?.name, 'レトロ8色');
    expect(service.paletteById(palette.id)?.colors, [0xFF000000, 0xFFFFFFFF]);

    await service.updatePalette(palette.id, name: 'レトロ改', colors: [0xFFFF0000]);
    expect(service.paletteById(palette.id)?.name, 'レトロ改');
    expect(service.paletteById(palette.id)?.colors, [0xFFFF0000]);

    await service.deletePalette(palette.id);
    expect(service.palettes, isEmpty);
    expect(service.paletteById(palette.id), isNull);
  });

  test('存在しないIDはnullを返す', () async {
    final service = PixelArtPaletteService();
    await service.init();
    expect(service.paletteById('no-such-id'), isNull);
    expect(service.paletteById(null), isNull);
  });

  test('永続化：再初期化しても内容が復元される', () async {
    final first = PixelArtPaletteService();
    await first.init();
    await first.addPalette('保存テスト', [0xFF123456]);

    final second = PixelArtPaletteService();
    await second.init();
    expect(second.palettes, hasLength(1));
    expect(second.palettes.first.name, '保存テスト');
    expect(second.palettes.first.colors, [0xFF123456]);
  });

  test('importPaletteJsonはexportPaletteと同じJSON形式から復元できる（Task#142）', () async {
    final service = PixelArtPaletteService();
    await service.init();
    final json = jsonEncode({'id': 'x', 'name': 'QR共有パレット', 'colors': [0xFF000000, 0xFFFFFFFF]});

    final imported = await service.importPaletteJson(json);

    expect(imported.name, 'QR共有パレット');
    expect(imported.colors, [0xFF000000, 0xFFFFFFFF]);
    expect(service.palettes, hasLength(1));
  });
}
