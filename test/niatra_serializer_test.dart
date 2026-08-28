import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';

/// NiatraSerializer（引き継ぎ.niatra）の単体テスト。
/// Task#155：パレット（PaletteService）・ドット絵専用パレット
/// （PixelArtPaletteService）が「パレット」カテゴリとして引き継がれる
/// ことを確認する。
Future<
    ({
      SettingsService settings,
      BrushService brush,
      ToneService tone,
      StampService stamp,
      AutofillPresetService autofillPresets,
      ThemeService theme,
      PaletteService palette,
      PixelArtPaletteService pixelArtPalette,
    })> _buildServices() async {
  final settings = SettingsService();
  final brush = BrushService();
  final tone = ToneService();
  final stamp = StampService();
  final autofillPresets = AutofillPresetService();
  final theme = ThemeService();
  final palette = PaletteService();
  final pixelArtPalette = PixelArtPaletteService();
  await settings.init();
  await brush.init();
  await tone.init();
  await stamp.init();
  await autofillPresets.init();
  await theme.init();
  await palette.init();
  await pixelArtPalette.init();
  return (
    settings: settings,
    brush: brush,
    tone: tone,
    stamp: stamp,
    autofillPresets: autofillPresets,
    theme: theme,
    palette: palette,
    pixelArtPalette: pixelArtPalette,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('「パレット」カテゴリでカラーパレット・ドット絵専用パレットの両方が引き継がれる（Task#155）', () async {
    final src = await _buildServices();
    await src.palette.createPalette('引き継ぎ用パレット');
    final srcPalette = src.palette.activePalette!;
    await src.palette.addColorToPalette(srcPalette.id, 0xFF112233);
    await src.pixelArtPalette.addPalette('引き継ぎ用ドット絵パレット', [0xFF000000, 0xFFFFFFFF]);

    final bytes = await NiatraSerializer.export(
      selectedItems: const {'パレット': true},
      settings: src.settings,
      brush: src.brush,
      tone: src.tone,
      stamp: src.stamp,
      autofillPresets: src.autofillPresets,
      theme: src.theme,
      palette: src.palette,
      pixelArtPalette: src.pixelArtPalette,
    );
    final data = NiatraSerializer.loadFromBytes(bytes);

    // dstは別端末を想定するため、srcが書き込んだSharedPreferencesの内容が
    // 混ざらないよう、ここで一度ストレージをリセットしてから作り直す
    // （実機では別々の永続化領域だが、SharedPreferences.setMockInitialValues
    // はテスト全体で1つのストレージを共有するため、明示的に分離する）。
    SharedPreferences.setMockInitialValues({});
    final dst = await _buildServices();
    final dstPaletteCountBefore = dst.palette.palettes.length;

    NiatraSerializer.applyTo(
      data,
      settings: dst.settings,
      brush: dst.brush,
      tone: dst.tone,
      stamp: dst.stamp,
      autofillPresets: dst.autofillPresets,
      theme: dst.theme,
      palette: dst.palette,
      pixelArtPalette: dst.pixelArtPalette,
    );
    // importPalette()/addPalette()内部の永続化はfire-and-forgetのため、
    // ChangeNotifierへの反映（メモリ上のリスト追加）自体は同期的に
    // 完了している前提で直後にアサーションできる。
    // srcのパレットは「デフォルトパレット」＋「引き継ぎ用パレット」の2件
    // あり、選択したカテゴリの全パレットが引き継がれるため、dst側には
    // それら2件がIDを振り直されて追加される。
    expect(dst.palette.palettes, hasLength(dstPaletteCountBefore + 2));
    final importedPalette =
        dst.palette.palettes.firstWhere((p) => p.name == '引き継ぎ用パレット');
    expect(importedPalette.id, isNot(srcPalette.id), reason: 'ID衝突を避けるため振り直すはず');
    expect(importedPalette.colors, contains(0xFF112233));

    expect(dst.pixelArtPalette.palettes, hasLength(1));
    expect(dst.pixelArtPalette.palettes.first.name, '引き継ぎ用ドット絵パレット');
    expect(dst.pixelArtPalette.palettes.first.colors, [0xFF000000, 0xFFFFFFFF]);
  });

  test('「パレット」カテゴリを選択しない場合はパレットが引き継がれない', () async {
    final src = await _buildServices();
    await src.pixelArtPalette.addPalette('選択外パレット', [0xFF000000]);

    final bytes = await NiatraSerializer.export(
      selectedItems: const {'パレット': false, '設定': true},
      settings: src.settings,
      brush: src.brush,
      tone: src.tone,
      stamp: src.stamp,
      autofillPresets: src.autofillPresets,
      theme: src.theme,
      palette: src.palette,
      pixelArtPalette: src.pixelArtPalette,
    );
    final data = NiatraSerializer.loadFromBytes(bytes);

    SharedPreferences.setMockInitialValues({});
    final dst = await _buildServices();
    NiatraSerializer.applyTo(
      data,
      settings: dst.settings,
      brush: dst.brush,
      tone: dst.tone,
      stamp: dst.stamp,
      autofillPresets: dst.autofillPresets,
      theme: dst.theme,
      palette: dst.palette,
      pixelArtPalette: dst.pixelArtPalette,
    );

    expect(dst.pixelArtPalette.palettes, isEmpty);
  });
}
