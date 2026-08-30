import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../services/community_preview_service.dart';
import 'community_work_card.dart';

/// ランキング・新着で作品カードをタップした際に表示するフローティング
/// 動画プレビューウィンドウ。ウィンドウ全体をドラッグして移動でき、
/// 右下のハンドルでリサイズできる。閉じる（×）ボタンと再生（プレース
/// ホルダー）ボタンを並べた下部コントロールバー、および「詳細へ」
/// ボタンを持つ。
///
/// 以前はタイトル文字＋閉じるボタンだけの専用ヘッダーバー（黒帯）を
/// ウィンドウ移動用のドラッグハンドルとして使っていたが、「作品名の
/// 表示は不要」「ドラッグはプレビュー全体で有効にしてほしい（黒帯を
/// 減らして動画・下部コントロールのスペースを広げたい）」という
/// フィードバックを受け、ヘッダーバー自体を廃止した。ドラッグは
/// ウィンドウ全体（リサイズハンドルの領域を除く）で受け付ける。
///
/// `app.dart`の`MaterialApp.router`の`builder`（ルーティングされる画面の
/// 外側、画面遷移をまたいで常に生き続ける層）に配置することで、他の画面
/// （ホーム等）へ移動してもこのウィンドウは表示され続ける
/// （「動画を再生しながら他の画面を閲覧し続けられる」という要件に対応）。
///
/// 実際の動画本体（YouTube埋め込み）はバックエンド未実装のため、
/// 既存の作品詳細と同じプレースホルダー（グラデーション＋再生アイコン）
/// を表示する。将来実際の動画を埋め込む際は、YouTube自身のミニプレイヤー
/// 機能に類似する特許（Google保有）が存在することを踏まえ、この
/// ウィジェットのような独自ドラッグ実装をそのまま流用するのではなく、
/// OS標準のPicture-in-Picture APIへ乗せる方針を検討すること
/// （詳細は`29_動画投稿・ランキング機能仕様.md`参照）。
class CommunityFloatingPreview extends StatefulWidget {
  const CommunityFloatingPreview({super.key});

  @override
  State<CommunityFloatingPreview> createState() => _CommunityFloatingPreviewState();
}

class _CommunityFloatingPreviewState extends State<CommunityFloatingPreview> {
  // 実際の動画埋め込みが無いためプレースホルダーとしての再生状態
  // （見た目のトグルのみ。実際の再生制御は行わない）。
  bool _isPlaying = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityPreviewService>();
    final work = service.work;
    if (work == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.sizeOf(context);
    final position = service.position;
    final size = service.size;

    // リサイズハンドルの当たり判定は、見た目のアイコンより一回り以上
    // 広く取る（「指を反応させるのが難しい」というフィードバックへの対応）。
    // ハンドルは右下角に固定表示され、下部コントロールバーの「詳細へ」
    // ボタンも同じ右下寄りに配置されるため、大きくしすぎると重なって
    // タップを奪ってしまう。当たり判定を広げつつ両立できる大きさに留める。
    const handleHitSize = 32.0;
    const handleIconSize = 16.0;

    return Positioned(
      left: position.dx.clamp(0, (screenSize.width - size.width).clamp(0, double.infinity)),
      top: position.dy.clamp(0, (screenSize.height - size.height).clamp(0, double.infinity)),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ウィンドウ全体（動画エリア＋下部コントロールバー）を
              // ドラッグしてウィンドウを移動する。専用のドラッグ
              // ハンドル（黒帯）は置かず、動画エリアを含む全体を対象に
              // することで上部の黒帯を無くしている。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  service.updatePosition(service.position + details.delta);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: kCommunityThumbnailGradients[
                                work.thumbnailColorIndex % kCommunityThumbnailGradients.length],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _isPlaying ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      // SpacerやExpandedを挟むと、この位置（高さ無制限の
                      // Column内、幅固定のContainer内）で極端なオーバー
                      // フローが発生したため、Flex系ウィジェットを使わず
                      // spaceBetweenで両端に振り分ける構成にしている。
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 再生/一時停止ボタン（プレースホルダー）。
                              // タップ領域は指が反応しやすいよう既定に近い
                              // サイズを維持しつつ、3ボタン構成が最小
                              // ウィンドウ幅（200）に収まるよう左右の余白
                              // だけを詰める。
                              // このウィジェットはMaterialApp.routerの
                              // builder層（Navigator/Overlayの外側）に常駐
                              // するため、IconButtonへtooltip:を指定すると
                              // 内部のTooltipがOverlay祖先を見つけられず
                              // ビルド時に例外になる（「No Overlay widget
                              // found」）。そのためtooltipは付けず、代わりに
                              // Semanticsでラベルだけ提供する。
                              Semantics(
                                label: _isPlaying
                                    ? l10n.communityFloatingPreviewPauseTooltip
                                    : l10n.communityFloatingPreviewPlayTooltip,
                                button: true,
                                child: IconButton(
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                  iconSize: 22,
                                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                                ),
                              ),
                              // 再生ボタンと閉じるボタンの間は、誤タップ防止
                              // のためある程度の間隔を空ける。
                              const SizedBox(width: 16),
                              Semantics(
                                label: l10n.commonClose,
                                button: true,
                                child: IconButton(
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  iconSize: 20,
                                  onPressed: service.close,
                                ),
                              ),
                            ],
                          ),
                          // 右下角のリサイズハンドルと重なってタップを
                          // 奪われないよう、ボタンの右側にハンドル1つ分の
                          // 余白を確保する。
                          Padding(
                            padding: const EdgeInsets.only(right: handleHitSize - 8),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                final workId = work.id;
                                service.close();
                                appRouter.push('/community/work/$workId');
                              },
                              child: Text(
                                l10n.communityFloatingPreviewDetailButton,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 右下コーナーのリサイズハンドル。ドラッグ移動の対象範囲より
              // 手前（Stackの後ろの子ほど上に重なる）にあるため、この
              // 範囲内の操作はドラッグ移動ではなくリサイズとして扱われる。
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    service.updateSize(Size(
                      service.size.width + details.delta.dx,
                      service.size.height + details.delta.dy,
                    ));
                  },
                  child: Container(
                    width: handleHitSize,
                    height: handleHitSize,
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(4),
                    // 見た目のアイコンは小さいままでも、コンテナ自体の
                    // 当たり判定は広く取れるよう半透明の丸背景を敷く。
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(handleHitSize / 2),
                    ),
                    child: const Icon(Icons.open_in_full, size: handleIconSize, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
