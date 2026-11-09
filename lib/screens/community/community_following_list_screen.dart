import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      await context.read<CommunityService>().refreshOwnFollowing();
    } finally {
      _refreshing = false;
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
    final ids = service.favoriteAuthorIds.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('フォロー中')),
      body: CommunityTopEdgeRefresh(
        key: const Key('communityOwnFollowingPullRefresh'),
        controller: _scrollController,
        enabled: service.isBackendConnected,
        onRefresh: _refresh,
        child: ListView.builder(
          key: const Key('communityOwnFollowingList'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: ids.isEmpty ? 1 : ids.length,
          itemBuilder: (context, index) {
            if (ids.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('フォロー中のユーザーはいません')),
              );
            }
            final id = ids[index];
            final name = service.followedAuthorName(id);
            return ListTile(
              key: Key('communityFollowingAuthor_$id'),
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(name),
              onTap: () => Navigator.of(context).push(
                adMockMaterialPageRoute<void>(
                  builder: (_) => CommunityAuthorWorksScreen(
                    authorId: id,
                    authorName: name,
                  ),
                ),
              ),
              trailing: OutlinedButton(
                key: Key('communityFollowingUnfollow_$id'),
                onPressed: () => reportFailedCommunityEdit(
                  context,
                  service,
                  service.toggleFavoriteAuthor(id),
                ),
                child: const Text('フォロー解除'),
              ),
            );
          },
        ),
      ),
    );
  }
}
