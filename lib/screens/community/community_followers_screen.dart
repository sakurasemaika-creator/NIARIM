import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/niarim_api_models.dart';
import '../../services/community_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/fit_or_hide_title.dart';
import 'community_author_works_screen.dart';
import 'community_error_text.dart';
import 'widgets/community_top_edge_refresh.dart';

class CommunityFollowersScreen extends StatefulWidget {
  const CommunityFollowersScreen({super.key, required this.ownerId});

  final String ownerId;

  @override
  State<CommunityFollowersScreen> createState() =>
      _CommunityFollowersScreenState();
}

class _CommunityFollowersScreenState extends State<CommunityFollowersScreen> {
  final _scrollController = ScrollController();
  final _followers = <String, ApiUserRef>{};
  late final int _accountRevision;
  bool _loading = true;
  String? _nextCursor;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _accountRevision = context.read<CommunityService>().accountRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loading = false;
      _load();
    });
  }

  bool _isOwner(CommunityService service) =>
      service.accountRevision == _accountRevision &&
      service.isOwnAuthor(widget.ownerId);

  Future<void> _load({String? cursor}) async {
    final service = context.read<CommunityService>();
    if (_loading || !_isOwner(service)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (cursor == null) _nextCursor = null;
    });
    try {
      final page = await service.loadOwnFollowers(
        widget.ownerId,
        cursor: cursor,
      );
      if (!mounted || !_isOwner(service)) return;
      setState(() {
        if (cursor == null) _followers.clear();
        for (final user in page.users) {
          _followers[user.niarimUserId] = user;
        }
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || !_isOwner(service)) return;
      setState(() {
        _error = error;
        _loading = false;
      });
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
    final l10n = AppLocalizations.of(context)!;
    final users = _followers.values.toList();
    final error = _error;
    final cursor = _nextCursor;

    Widget footer() {
      if (_loading) return const CircularProgressIndicator();
      if (error != null) {
        return Column(
          children: [
            Text(communityErrorText(l10n, error), textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _load(cursor: cursor),
              child: Text(l10n.communityRetry),
            ),
          ],
        );
      }
      if (cursor != null) {
        return TextButton(
          onPressed: () => _load(cursor: cursor),
          child: Text(l10n.communityFollowersLoadMore),
        );
      }
      return Text(l10n.communityFollowersEmpty);
    }

    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(l10n.communityFollowersTitle)),
      body: !_isOwner(service)
          ? Center(child: Text(l10n.communityErrorSignInRequired))
          : CommunityTopEdgeRefresh(
              controller: _scrollController,
              enabled: service.isBackendConnected,
              onRefresh: _load,
              child: ListView.builder(
                key: const Key('communityOwnFollowersList'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                    users.length +
                    (_loading ||
                            error != null ||
                            cursor != null ||
                            users.isEmpty
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < users.length) {
                    final user = users[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(user.displayName),
                      onTap: () => Navigator.of(context).push(
                        adMockMaterialPageRoute<void>(
                          builder: (_) => CommunityAuthorWorksScreen(
                            authorId: user.niarimUserId,
                            authorName: user.displayName,
                          ),
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: footer()),
                  );
                },
              ),
            ),
    );
  }
}
