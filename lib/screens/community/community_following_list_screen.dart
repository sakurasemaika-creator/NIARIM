import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'community_author_works_screen.dart';
import 'community_edit_feedback.dart';
import 'widgets/community_top_edge_refresh.dart';
import '../../widgets/fit_or_hide_title.dart';

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
  final Map<String, Future<void>> _pendingToggles = {};
  late final int _accountRevision;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _accountRevision = context.read<CommunityService>().accountRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    final service = context.read<CommunityService>();
    if (service.accountRevision != _accountRevision) return;
    setState(() => _refreshing = true);
    try {
      // A refresh started just after an unfollow must read after the write.
      await Future.wait(_pendingToggles.values.toList());
      if (!mounted || service.accountRevision != _accountRevision) return;
      await service.refreshOwnFollowing();
    } finally {
      if (mounted) {
        setState(() {
          _recentlyUnfollowed.clear();
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _toggle(String id, String name) async {
    if (_refreshing || _pendingToggles.containsKey(id)) return;
    final service = context.read<CommunityService>();
    if (service.accountRevision != _accountRevision) return;
    if (service.isFavoriteAuthor(id)) _recentlyUnfollowed[id] = name;
    final mutation = reportFailedCommunityEdit(
      context,
      service,
      service.toggleFavoriteAuthor(id),
    );
    setState(() {
      _pendingToggles[id] = mutation;
    });
    try {
      await mutation;
    } finally {
      if (mounted) {
        setState(() {
          if (service.accountRevision != _accountRevision ||
              service.isFavoriteAuthor(id)) {
            _recentlyUnfollowed.remove(id);
          }
          _pendingToggles.remove(id);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityService>();
    final isSameAccount = service.accountRevision == _accountRevision;
    final ids = isSameAccount ? service.favoriteAuthorIds.toList() : <String>[];
    final removed = isSameAccount
        ? _recentlyUnfollowed.entries
              .where((entry) => !service.isFavoriteAuthor(entry.key))
              .toList()
        : <MapEntry<String, String>>[];
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
          onPressed: _refreshing || _pendingToggles.containsKey(id)
              ? null
              : () => _toggle(id, name),
          child: Text(
            following
                ? l10n.communityUnfollowAction
                : l10n.communityFavoriteAuthorFollow,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: ModalRoute.of(context)?.canPop == true
            ? const BackButton()
            : null,
        title: FitOrHideTitle(l10n.communityTabFavoriteAuthors),
      ),
      body: CommunityTopEdgeRefresh(
        key: const Key('communityOwnFollowingPullRefresh'),
        controller: _scrollController,
        enabled:
            isSameAccount &&
            (service.isBackendConnected || _recentlyUnfollowed.isNotEmpty),
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
