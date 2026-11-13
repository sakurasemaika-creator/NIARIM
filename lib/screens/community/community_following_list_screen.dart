import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'community_author_works_screen.dart';
import 'community_edit_feedback.dart';
import 'widgets/community_top_edge_refresh.dart';

/// Private, owner-only directory of authors the current viewer follows.
/// The public author page never offers a link to somebody else's follow list.
class CommunityFollowingListScreen extends StatefulWidget {
  const CommunityFollowingListScreen({super.key});

  @override
  State<CommunityFollowingListScreen> createState() =>
      _CommunityFollowingListScreenState();
}

class _CommunityFollowingListScreenState
    extends State<CommunityFollowingListScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _recentlyUnfollowed = {};
  final Set<String> _togglingIds = {};
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final updated = await context
          .read<CommunityService>()
          .refreshOwnFollowing();
      if (updated && mounted) {
        setState(_recentlyUnfollowed.clear);
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _toggle(String id, String name) async {
    if (_togglingIds.contains(id)) return;
    setState(() => _togglingIds.add(id));
    final service = context.read<CommunityService>();
    await reportFailedCommunityEdit(
      context,
      service,
      service.toggleFavoriteAuthor(id),
    );
    if (!mounted) return;
    setState(() {
      if (service.isFavoriteAuthor(id)) {
        _recentlyUnfollowed.remove(id);
      } else {
        // Keep an unfollowed author available in this session, so the viewer
        // can follow them again without leaving the list or losing the name.
        _recentlyUnfollowed[id] = name;
      }
      _togglingIds.remove(id);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityService>();
    final ids = service.favoriteAuthorIds.toList();
    final removed = _recentlyUnfollowed.entries
        .where((entry) => !service.isFavoriteAuthor(entry.key))
        .toList();
    final isEmpty = ids.isEmpty && removed.isEmpty;
    final l10n = AppLocalizations.of(context)!;

    Widget authorRow(String id, String name, {required bool following}) {
      return ListTile(
        key: Key('communityFollowingAuthor_$id'),
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: following ? null : Text(l10n.communityUnfollowedLabel),
        onTap: () => Navigator.of(context).push(
          adMockMaterialPageRoute<void>(
            builder: (_) =>
                CommunityAuthorWorksScreen(authorId: id, authorName: name),
          ),
        ),
        trailing: OutlinedButton(
          key: Key(
            following
                ? 'communityFollowingUnfollow_$id'
                : 'communityFollowingFollow_$id',
          ),
          onPressed: _togglingIds.contains(id) ? null : () => _toggle(id, name),
          child: Text(
            following
                ? l10n.communityUnfollowAction
                : l10n.communityFavoriteAuthorFollow,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityTabFavoriteAuthors)),
      body: CommunityTopEdgeRefresh(
        key: const Key('communityOwnFollowingPullRefresh'),
        controller: _scrollController,
        enabled: service.isBackendConnected,
        onRefresh: _refresh,
        child: ListView.builder(
          key: const Key('communityOwnFollowingList'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: isEmpty
              ? 1
              : ids.length + (removed.isEmpty ? 0 : removed.length + 1),
          itemBuilder: (context, index) {
            if (isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.communityFollowingListEmpty)),
              );
            }
            if (index < ids.length) {
              final id = ids[index];
              return authorRow(
                id,
                service.followedAuthorName(id),
                following: true,
              );
            }
            if (index == ids.length) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.communityRecentlyUnfollowedHeader),
              );
            }
            final user = removed[index - ids.length - 1];
            return authorRow(user.key, user.value, following: false);
          },
        ),
      ),
    );
  }
}
