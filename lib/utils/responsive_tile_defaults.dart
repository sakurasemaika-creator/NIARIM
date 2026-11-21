import '../widgets/collection_tile_layout.dart';

/// Device-independent defaults for thumbnails, based on logical screen width.
///
/// Only use these defaults when the user has not explicitly chosen a tile size.
enum TileScreenClass { phone, tablet, desktop }

TileScreenClass tileScreenClassForWidth(double width) {
  if (width < 600) return TileScreenClass.phone;
  if (width < 1000) return TileScreenClass.tablet;
  return TileScreenClass.desktop;
}

/// The tile size used until one is chosen: small on phones, medium on
/// tablets and large on PCs.
CollectionViewSize defaultTileSizeFor(double width) =>
    switch (tileScreenClassForWidth(width)) {
      TileScreenClass.phone => CollectionViewSize.small,
      TileScreenClass.tablet => CollectionViewSize.medium,
      TileScreenClass.desktop => CollectionViewSize.large,
    };
