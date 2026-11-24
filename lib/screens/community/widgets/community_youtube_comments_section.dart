import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../l10n/community_youtube_comment_labels.dart';
import '../../../services/community_service.dart';
import '../../../utils/app_locale.dart';
import '../../../widgets/grouped_sheet.dart';

/// View-only YouTube comments. A collapsed section issues NO YouTube requests.
/// Comment text is held in widget memory only; never persisted to DynamoDB.
class CommunityYoutubeCommentsSection extends StatefulWidget {
  const CommunityYoutubeCommentsSection({
    super.key,
    required this.workId,
    required this.onOpenYouTube,
  });

  final String workId;
  final VoidCallback onOpenYouTube;

  @override
  State<CommunityYoutubeCommentsSection> createState() =>
      _CommunityYoutubeCommentsSectionState();
}

class _CommunityYoutubeCommentsSectionState
    extends State<CommunityYoutubeCommentsSection> {
  static const _displayChunk = 20;
  static const _maxComments = 100;

  bool _loaded = false;
  Object? _request;
  bool _unavailable = false;
  bool _failed = false;
  bool _hasMoreOnYouTube = false;
  int _visibleCount = _displayChunk;
  List<Map<String, dynamic>> _comments = [];

  bool get _loading => _request != null;

  @override
  void didUpdateWidget(covariant CommunityYoutubeCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _loaded = false;
      _request = null;
      _unavailable = false;
      _failed = false;
      _hasMoreOnYouTube = false;
      _visibleCount = _displayChunk;
      _comments = [];
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final api = context.read<CommunityService>().api;
    if (api == null) {
      setState(() {
        _loaded = true;
        _failed = true;
      });
      return;
    }
    final request = Object();
    setState(() {
      _request = request;
      _failed = false;
    });
    try {
      final payload = await api.youtubeComments(widget.workId);
      if (!mounted || _request != request) return;
      final comments = (payload['comments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .take(_maxComments)
          .toList();
      setState(() {
        _comments = comments;
        final cursor = payload['nextCursor'];
        _hasMoreOnYouTube =
            (cursor is String && cursor.isNotEmpty) ||
            comments.length == _maxComments;
        _unavailable = payload['unavailable'] == true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted && _request == request) {
        setState(() {
          _loaded = true;
          _failed = true;
        });
      }
    } finally {
      if (mounted && _request == request) setState(() => _request = null);
    }
  }

  Widget _comment(Map<String, dynamic> data, {bool reply = false}) {
    final scheme = Theme.of(context).colorScheme;
    final author = data['author'] as String? ?? '';
    final avatar = data['avatar'] as String? ?? '';
    final body = data['text'] as String? ?? '';
    final publishedAt = DateTime.tryParse(data['publishedAt'] as String? ?? '');
    // 日付は表示言語の書き方（作品の詳細の投稿日と同じ`yMd`）。
    final stamp = publishedAt == null
        ? ''
        : DateFormat.yMd(
            appLocalizationsOf(context).localeName,
          ).format(publishedAt.toLocal());
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
    // 上の設定の面と同じ幅・同じ細い縁の面（MenuCardの外側の余白で、
    // この欄だけ内側に寄っていた）。
    return GroupedSheet(
      children: [
        ExpansionTile(
          key: const Key('communityYoutubeCommentsExpansion'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            Icons.comment_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
            for (final comment in _comments.take(_visibleCount)) ...[
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
            if (_visibleCount < _comments.length)
              TextButton.icon(
                key: const Key('communityYoutubeCommentsLoadMore'),
                onPressed: () => setState(() => _visibleCount += _displayChunk),
                icon: const Icon(Icons.expand_more),
                label: Text(labels.loadMore),
              )
            else if (!_unavailable && !_failed && _hasMoreOnYouTube)
              TextButton.icon(
                key: const Key('communityYoutubeCommentsOpenYouTube'),
                onPressed: widget.onOpenYouTube,
                icon: const Icon(Icons.open_in_new),
                label: Text(labels.openYouTube),
              ),
          ],
        ),
      ],
    );
  }
}
