import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../router.dart';
import '../../services/community_service.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'widgets/community_work_card.dart';
import '../../config/font_fallback.dart';

/// 作品詳細画面（別ルート、`/community/work/:id`）。
///
/// フローティング動画プレビューウィンドウ（`CommunityFloatingPreview`）の
/// 「詳細へ」ボタンから遷移する。リサイズ可能なプレビュー・タイトル・
/// 投稿日・投稿者（タップで投稿者別作品一覧へ）・YouTubeいいね数・
/// タグ（タップで絞り込み・誰でも追加削除可・投稿者はロック可）・
/// ブックマークボタンとNIARIM独自のブックマーク数を表示する。
///
/// `29_動画投稿・ランキング機能仕様.md`のバックエンドは未実装のため、
/// `CommunityService`が保持するダミーデータを参照・編集する。実際の
/// 動画本体（YouTube埋め込み）は無く、既存の一覧・フローティング
/// プレビューと同じプレースホルダー（グラデーション＋再生アイコン）を
/// 表示する。
class CommunityWorkDetailScreen extends StatefulWidget {
  final String workId;
  const CommunityWorkDetailScreen({super.key, required this.workId});

  @override
  State<CommunityWorkDetailScreen> createState() =>
      _CommunityWorkDetailScreenState();
}

class _CommunityWorkDetailScreenState extends State<CommunityWorkDetailScreen> {
  static const double _minPreviewHeight = 140;
  static const double _defaultPreviewHeight = 220;
  // ドラッグ中のプレビュー高さ（指を離しても最後の値をそのまま保持する。
  // タイムラインモードのプレビューのドラッグハンドルと同じ操作感）。
  double _previewHeight = _defaultPreviewHeight;

  void _openAuthorWorks(CommunityWork work) {
    Navigator.of(context).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddTagDialog(CommunityService communityService, String workId) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.communityAddTagDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.communityAddTagDialogHint,
            ),
            onSubmitted: (v) {
              Navigator.pop(ctx);
              communityService.addTag(workId, v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                communityService.addTag(workId, controller.text);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(CommunityWork work) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = [
      l10n.communityReportReasonInappropriate,
      l10n.communityReportReasonCopyright,
      l10n.communityReportReasonSpam,
      l10n.communityReportReasonOther,
    ];
    String selected = reasons.first;
    final detailController = TextEditingController();
    // 未入力のまま送信しようとした場合のみエラー表示を出す（最初から
    // 赤字を出して威圧的にならないよう、送信ボタンを一度押すまでは
    // エラーを表示しない）。
    bool showDetailError = false;
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: detailController,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.communityReportDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.communityReportDialogBody),
                  const SizedBox(height: 8),
                  // 選択状態と変更通知はRadioGroupがまとめて持つ
                  // （groupValue/onChangedはFlutter 3.32で非推奨）。
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (v) => setDialogState(() => selected = v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final reason in reasons)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(reason),
                            value: reason,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: l10n.communityReportDetailLabel,
                      hintText: l10n.communityReportDetailHint,
                      errorText: showDetailError
                          ? l10n.communityReportDetailRequiredError
                          : null,
                    ),
                    onChanged: (_) {
                      if (showDetailError) {
                        setDialogState(() => showDetailError = false);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  if (detailController.text.trim().isEmpty) {
                    setDialogState(() => showDetailError = true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _showComingSoonSnackbar(
                    l10n.communityReportComingSoonSnackbar,
                  );
                  // 通報送信後、続けてこの投稿者をブロックするか確認する
                  // （「通報後はブロック確認ポップアップを表示してほしい」
                  // という要望への対応）。
                  _showBlockConfirmDialog(work);
                },
                child: Text(l10n.communityReportSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(CommunityWork work) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.communityBlockConfirmTitle(work.authorName)),
        content: Text(l10n.communityBlockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeService.activeColorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showComingSoonSnackbar(l10n.communityBlockComingSoonSnackbar);
            },
            child: Text(l10n.communityWorkDetailBlockButton),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final mo = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mo/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final communityService = context.watch<CommunityService>();
    final work = communityService.byId(widget.workId);
    if (work == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.communityWorkDetailTitle)),
        body: Center(child: Text(l10n.communityWorkNotFoundMessage)),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final isBookmarked = communityService.isBookmarked(work.id);
    final isAuthorSelf = work.authorId == kDummySelfAuthorId;
    final isReposted = communityService.isRepostedBySelf(work.id);
    final maxPreviewHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      _minPreviewHeight,
      500.0,
    );
    final previewHeight = _previewHeight.clamp(
      _minPreviewHeight,
      maxPreviewHeight,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityWorkDetailTitle)),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // リサイズ可能なプレビュー（タイムラインモードのプレビュー
              // ドラッグハンドルと同じ操作感）。実際の動画本体は無いため、
              // 既存の一覧・フローティングプレビューと同じプレースホルダー
              // を表示する。
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: previewHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            communityThumbnailGradient(Theme.of(context).colorScheme, work.thumbnailColorIndex),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.70),
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onVerticalDragUpdate: (d) => setState(() {
                  _previewHeight = (previewHeight + d.delta.dy).clamp(
                    _minPreviewHeight,
                    maxPreviewHeight,
                  );
                }),
                child: Container(
                  height: 20,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Text(
                work.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAuthorWorks(work),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 投稿者アイコン（あれば表示。ダミーデータには
                          // アイコン画像が無いため、常に頭文字アバターに
                          // フォールバックする）。
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              work.authorName.substring(0, 1),
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              work.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // お気に入り作者（フォロー、Task#144）。自分自身の作品では表示しない。
                  if (!isAuthorSelf)
                    IconButton(
                      onPressed: () =>
                          communityService.toggleFavoriteAuthor(work.authorId),
                      icon: Icon(
                        communityService.isFavoriteAuthor(work.authorId)
                            ? Icons.person_remove_alt_1
                            : Icons.person_add_alt_1,
                        color: communityService.isFavoriteAuthor(work.authorId)
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                      tooltip: communityService.isFavoriteAuthor(work.authorId)
                          ? l10n.communityFavoriteAuthorFollowing
                          : l10n.communityFavoriteAuthorFollow,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.viewCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  // YouTube側の「いいね」数。APIが返す値をそのまま表示し、
                  // NIARIM側で独自に加算・合算はしない（YouTube API利用規約
                  // の要件）。
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.likeCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  // NIARIM独自のブックマーク数（YouTube側の「いいね」とは
                  // 別のNIARIM内機能。29_動画投稿・ランキング機能仕様.md
                  // 8.5節）。
                  Icon(
                    Icons.bookmark,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.bookmarkCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  // リポスト数（Task#145）。ブックマーク同様NIARIM独自の
                  // カウントで、YouTube側の統計とは無関係。
                  Icon(Icons.repeat, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(
                      communityService.repostCountOf(work.id),
                      languageCode,
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.communityWorkDetailPostedLabel(_formatDate(work.postedAt)),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (isAuthorSelf) ...[
                const SizedBox(height: 12),
                _NiarimVisibilitySwitch(
                  isPublished: work.isNiarimPublished,
                  onChanged: () =>
                      communityService.toggleNiarimVisibility(work.id),
                ),
              ] else if (!work.isNiarimPublished) ...[
                const SizedBox(height: 12),
                _NiarimHiddenNotice(),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in work.tags)
                    _TagChip(
                      label: tag,
                      isLocked: work.lockedTags.contains(tag),
                      // ロックの鍵アイコン自体は投稿者本人のみ操作可能
                      // （ロック中/解除中の切り替え）。それ以外の
                      // ユーザーには鍵アイコンのみ表示し操作はさせない。
                      onToggleLock: isAuthorSelf
                          ? () => communityService.toggleTagLock(work.id, tag)
                          : null,
                      // ロックされていないタグのみ誰でも削除できる。
                      onRemove: work.lockedTags.contains(tag)
                          ? null
                          : () => communityService.removeTag(work.id, tag),
                      // go()（ナビゲーション履歴を丸ごと置き換える）ではなく
                      // push()を使う。go()だと起動画面まで含めて履歴が消え、
                      // 作品広場画面左上の「起動画面へ戻る」矢印が消えて
                      // しまうバグと、同じ`/community`ルートへ連続でナビゲート
                      // した際にCommunityScreenのStateが使い回されて
                      // initState()が再実行されず2回目以降のタグ検索が
                      // 効かないバグの、両方の原因になっていた。
                      onTap: () => appRouter.push('/community', extra: tag),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(l10n.communityAddTagButton),
                    onPressed: () =>
                        _showAddTagDialog(communityService, work.id),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showComingSoonSnackbar(
                        l10n.communityWorkDetailViewOnYoutubeComingSoonSnackbar,
                      ),
                      icon: const Icon(Icons.smart_display_outlined),
                      label: Text(l10n.communityWorkDetailViewOnYoutube),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => communityService.toggleBookmark(work.id),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: Text(
                      isBookmarked
                          ? l10n.communityWorkDetailBookmarkRemove
                          : l10n.communityWorkDetailBookmarkAdd,
                    ),
                  ),
                ],
              ),
              // リポスト（Task#145）：投稿者本人も含め誰でもリポストできる
              // （フォロワーへ改めて周知する用途を想定し、フォローボタンとは
              // 異なり投稿者本人にも制限しない）。
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => communityService.toggleRepost(work.id),
                  icon: Icon(
                    Icons.repeat,
                    color: isReposted ? scheme.primary : null,
                  ),
                  label: Text(
                    isReposted
                        ? l10n.communityRepostedButton
                        : l10n.communityRepostButton,
                    style: TextStyle(color: isReposted ? scheme.primary : null),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: isReposted ? BorderSide(color: scheme.primary) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showReportDialog(work),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(l10n.communityWorkDetailReportButton),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showBlockConfirmDialog(work),
                      icon: const Icon(Icons.block, size: 18),
                      label: Text(l10n.communityWorkDetailBlockButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// タグ表示チップ。タップでそのタグによる絞り込みへ遷移し、ロックされて
/// いないタグには削除ボタン（誰でも操作可）、投稿者本人が見ている場合
/// のみロック/解除の切り替えボタンを追加で表示する。
class _TagChip extends StatelessWidget {
  final String label;
  final bool isLocked;
  final VoidCallback? onToggleLock;
  final VoidCallback? onRemove;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isLocked,
    required this.onToggleLock,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLocked) ...[
                Icon(Icons.lock, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (onToggleLock != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  tooltip: isLocked
                      ? l10n.communityTagUnlockTooltip
                      : l10n.communityTagLockTooltip,
                  icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                  onPressed: onToggleLock,
                ),
              if (onRemove != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  tooltip: l10n.communityRemoveTagTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 作品広場独自の公開/非公開設定を切り替えるカード。投稿者本人
/// にのみ表示する（29_動画投稿・ランキング機能仕様.md 13章）。YouTube側
/// の公開設定とは独立した設定であることが伝わるよう、専用の説明文を
/// 添える。
class _NiarimVisibilitySwitch extends StatelessWidget {
  final bool isPublished;
  final VoidCallback onChanged;

  const _NiarimVisibilitySwitch({
    required this.isPublished,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPublished ? Icons.public : Icons.lock_outline,
                color: isPublished ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.communityVisibilityCardTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPublished
                          ? l10n.communityVisibilityPublishedDesc
                          : l10n.communityVisibilityHiddenDesc,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: isPublished, onChanged: (_) => onChanged()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 非公開になっている作品の詳細画面に表示する注意書き（投稿者本人以外が
/// 何らかの経路でたどり着いた場合の保険。通常は一覧側で除外済みのため
/// 到達しない想定）。
class _NiarimHiddenNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.communityVisibilityHiddenNotice,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
