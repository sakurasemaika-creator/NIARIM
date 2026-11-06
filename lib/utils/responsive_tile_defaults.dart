/// Device-independent defaults for thumbnails, based on logical screen width.
///
/// Only use these defaults when the user has not explicitly chosen a tile size.
enum TileScreenClass { phone, tablet, desktop }

TileScreenClass tileScreenClassForWidth(double width) {
  if (width < 600) return TileScreenClass.phone;
  if (width < 1000) return TileScreenClass.tablet;
  return TileScreenClass.desktop;
}

double defaultCommunityTileWidthForWidth(double width) =>
    switch (tileScreenClassForWidth(width)) {
      TileScreenClass.phone => 140.0,
      TileScreenClass.tablet => 200.0,
      TileScreenClass.desktop => 300.0,
    };
