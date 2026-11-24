import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 作品広場の作品の絵がまだ無い（読み込み中・YouTubeの絵を取れない・見本の
/// データ）ときの表紙：用紙の色の上に、動画であることだけを示す小さな再生の
/// 印を置く。
///
/// 作品の絵の代わりに見せかけの絵（差し色のグラデーション・動きのコマの
/// 下書き）を描かない。どの作品の絵なのか読み取れず、本物の作品の絵と
/// 見分けもつかなかった。
class CommunityThumbnailPlaceholder extends StatelessWidget {
  const CommunityThumbnailPlaceholder({super.key, this.child});

  /// 用紙の上に重ねるもの（YouTubeの絵。読み込めれば用紙と印を覆う）。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: Icon(
                Icons.play_circle_outline,
                size: math.min(32, constraints.biggest.shortestSide * .3),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
