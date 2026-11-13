import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/font_fallback.dart';
import '../../l10n/app_localizations.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../utils/color_contrast.dart';
import 'community_edit_feedback.dart';
import 'community_error_text.dart';
import 'widgets/community_work_card.dart';

/// 閲覧フィルターとブックマーク日時順を反映する公開作品一覧。
class CommunityBookmarkedTab extends StatelessWidget {
  const CommunityBookmarkedTab({
    super.key,
    required this.onBrowseWorks,
    required this.scrollController,
  });

  final VoidCallback onBrowseWorks;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = opaqueOver(theme.scaffoldBackgroundColor, Colors.black);
    final foreground = scheme.primary;
    final textForeground = scheme.onSurface;
    final bodyForeground = scheme.onSurfaceVariant;
    final service = context.watch<CommunityService>();
    final works = service.bookmarkedWorksForViewer;
    final canReload =
        service.isBackendConnected && service.currentUserId != null;
    final loading = canReload && service.isSocialLoading;
    final error = canReload ? service.socialError : null;
    final needsLoad = canReload && !service.hasLoadedSocial && error == null;
    final hidden = service.bookmarkedIds.isNotEmpty;
    final title = loading
        ? l10n.homeBookmarkedLoading
        : error != null
        ? l10n.homeBookmarkedLoadFailed
        : needsLoad
        ? l10n.homeBookmarkedLoadPrompt
        : hidden
        ? l10n.homeBookmarkedHiddenTitle
        : l10n.homeBookmarkedEmptyTitle;
    final String? body = loading || needsLoad
        ? null
        : error != null
        ? communityErrorText(l10n, error)
        : hidden
        ? l10n.homeBookmarkedHiddenBody
        : service.isBackendConnected && service.currentUserId == null
        ? l10n.homeBookmarkedSignInBody
        : l10n.homeBookmarkedEmptyBody;

    Future<void> reload() async {
      if (!service.hasLoadedSocial || service.socialError != null) {
        await service.loadSocial();
      } else {
        await service.refreshViewerBookmarks();
      }
    }

    final scroll = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: scrollController,
        physics: canReload ? const AlwaysScrollableScrollPhysics() : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: works.isEmpty ? const EdgeInsets.all(24) : EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: works.isEmpty
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (works.isEmpty) ...[
                  if (loading)
                    CircularProgressIndicator(color: foreground)
                  else
                    Icon(
                      error != null
                          ? Icons.cloud_off_outlined
                          : Icons.bookmark_border,
                      size: 64,
                      color: foreground,
                    ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textForeground,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: bodyForeground),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (canReload && !loading)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: foreground,
                          ),
                          onPressed: reload,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            error != null
                                ? l10n.communityRetry
                                : l10n.communityReloadTooltip,
                          ),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: foreground,
                        ),
                        onPressed: onBrowseWorks,
                        icon: const Icon(Icons.explore_outlined),
                        label: Text(l10n.communityTabNew),
                      ),
                    ],
                  ),
                ] else ...[
                  if (loading)
                    LinearProgressIndicator(
                      color: foreground,
                      backgroundColor: Color.alphaBlend(
                        foreground.withValues(alpha: 0.15),
                        background,
                      ),
                      semanticsLabel: l10n.homeBookmarkedLoading,
                    ),
                  if (canReload)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (error != null)
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  l10n.homeBookmarkedLoadFailed,
                                  style: TextStyle(color: textForeground),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          IconButton(
                            onPressed: loading ? null : reload,
                            tooltip: error != null
                                ? l10n.communityRetry
                                : l10n.communityReloadTooltip,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  CommunityWorkGrid(
                    works: works,
                    bookmarkedIds: service.bookmarkedIds,
                    onTapWork: (work) =>
                        context.read<CommunityPreviewService>().show(work),
                    onToggleBookmark: (work) => reportFailedCommunityEdit(
                      context,
                      service,
                      service.toggleBookmark(work.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return canReload
        ? RefreshIndicator(onRefresh: reload, child: scroll)
        : scroll;
  }
}
