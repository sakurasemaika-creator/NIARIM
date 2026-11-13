import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/community_youtube_comment_labels.dart';
import '../../../services/community_service.dart';

/// View-only YouTube comments. A collapsed section issues NO YouTube requests.
/// Comment text is held in widget memory only; never persisted to DynamoDB.
class CommunityYoutubeCommentsSection extends StatefulWidget {
  const CommunityYoutubeCommentsSection({super.key, required this.workId});
  final String workId;

  @override
  State<CommunityYoutubeCommentsSection> createState() =>
      _CommunityYoutubeCommentsSectionState();
}

class _CommunityYoutubeCommentsSectionState
    extends State<CommunityYoutubeCommentsSection> {
  bool _loaded = false;
  bool _loading = false;
  bool _unavailable = false;
  bool _failed = false;
  String? _nextCursor;
  final List<Map<String, dynamic>> _comments = [];

  @override
  void didUpdateWidget(covariant CommunityYoutubeCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _loaded = false;
      _loading = false;
      _unavailable = false;
      _failed = false;
      _nextCursor = null;
      _comments.clear();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || (more && _nextCursor == null)) return;
    final api = context.read<CommunityService>().api;
    if (api == null) {
      setState(() {
        _loaded = true;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final payload = await api.youtubeComments(
        widget.workId,
        cursor: more ? _nextCursor : null,
      );
      if (!mounted) return;
      final comments = (payload['comments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        if (!more) _comments.clear();
        _comments.addAll(comments);
        _nextCursor = payload['nextCursor'] as String?;
        _unavailable = payload['unavailable'] == true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _comment(Map<String, dynamic> data, {bool reply = false}) {
    final scheme = Theme.of(context).colorScheme;
    final author = data['author'] as String? ?? '';
    final avatar = data['avatar'] as String? ?? '';
    final body = data['text'] as String? ?? '';
    final publishedAt = DateTime.tryParse(data['publishedAt'] as String? ?? '');
    final stamp = publishedAt == null
        ? ''
        : '${publishedAt.toLocal().year}/${publishedAt.toLocal().month}/${publishedAt.toLocal().day}';
    return Padding(
      padding: EdgeInsets.only(left: reply ? 28 : 0, top: 10, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: reply ? 13 : 17,
            backgroundColor: scheme.surfaceContainerHigh,
            backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
            child: avatar.isEmpty
                ? const Icon(Icons.person_outline, size: 15)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    if (stamp.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(stamp, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = CommunityYoutubeCommentLabels.of(context);
    return Card(
      child: ExpansionTile(
        key: const Key('communityYoutubeCommentsExpansion'),
        leading: const Icon(Icons.comment_outlined),
        title: Text(labels.heading),
        onExpansionChanged: (open) {
          if (open && !_loaded && !_loading) _load();
        },
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              labels.attribution,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (_unavailable || _failed) ...[
            Text(labels.unavailable),
            TextButton(onPressed: () => _load(), child: Text(labels.retry)),
          ] else if (_loaded && _comments.isEmpty)
            Text(labels.noComments),
          for (final comment in _comments) ...[
            _comment(comment),
            for (final reply
                in ((comment['replies'] as List?) ?? const [])
                    .whereType<Map<String, dynamic>>())
              _comment(reply, reply: true),
            if ((comment['totalReplyCount'] as num? ?? 0) >
                ((comment['replies'] as List?)?.length ?? 0))
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  labels.replies(
                    (comment['totalReplyCount'] as num? ?? 0).toInt(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 1),
          ],
          if (!_loading && _nextCursor != null)
            TextButton.icon(
              key: const Key('communityYoutubeCommentsLoadMore'),
              onPressed: () => _load(more: true),
              icon: const Icon(Icons.expand_more),
              label: Text(labels.loadMore),
            ),
        ],
      ),
    );
  }
}
