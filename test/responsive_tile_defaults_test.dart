import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/responsive_tile_defaults.dart';

void main() {
  test('thumbnail default changes at logical phone/tablet/desktop widths', () {
    expect(tileScreenClassForWidth(360), TileScreenClass.phone);
    expect(tileScreenClassForWidth(599), TileScreenClass.phone);
    expect(tileScreenClassForWidth(600), TileScreenClass.tablet);
    expect(tileScreenClassForWidth(800), TileScreenClass.tablet);
    expect(tileScreenClassForWidth(999), TileScreenClass.tablet);
    expect(tileScreenClassForWidth(1000), TileScreenClass.desktop);
    expect(tileScreenClassForWidth(1280), TileScreenClass.desktop);
    expect(defaultCommunityTileWidthForWidth(390), 140);
    expect(defaultCommunityTileWidthForWidth(800), 200);
    expect(defaultCommunityTileWidthForWidth(1280), 300);
  });
}
