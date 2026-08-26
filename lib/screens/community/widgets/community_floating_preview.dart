import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../services/community_preview_service.dart';
import 'community_work_card.dart';

/// ランキング・新着で作品カードをタップした際に表示するフローティング
/// 動画プレビューウィンドウ。画面の隅にドラッグで移動・コーナーハンドルで
/// リサイズでき、閉じる（×）ボタンと「詳細へ」ボタンを持つ。
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
class CommunityFloatingPreview extends StatelessWidget {
  const CommunityFloatingPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityPreviewService>();
    final work = service.work;
    if (work == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.sizeOf(context);
    final position = service.position;
    final size = service.size;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ヘッダー：ドラッグでウィンドウを移動する。
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      service.updatePosition(service.position + details.delta);
                    },
                    child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              work.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          InkWell(
                            onTap: service.close,
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      child: const Center(
                        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            final workId = work.id;
                            service.close();
                            appRouter.push('/community/work/$workId');
                          },
                          child: Text(
                            l10n.communityFloatingPreviewDetailButton,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 右下コーナーのリサイズハンドル。
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
                    width: 22,
                    height: 22,
                    alignment: Alignment.bottomRight,
                    child: const Icon(Icons.open_in_full, size: 12, color: Colors.white70),
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
