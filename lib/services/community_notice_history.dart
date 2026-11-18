import 'community_notice.dart';

/// Validates the response account and filters notices from older servers.
Map<String, dynamic> filterCommunityNoticePage(
  Map<String, dynamic> page,
  String? owner,
) {
  final responseOwner = page['noticeOwner'];
  if (responseOwner != null && owner != null && responseOwner != owner) {
    // An auth change may have happened while the request was in flight.
    return {...page, 'events': const []};
  }
  final events = page['events'];
  if (events is! List) return {...page, 'events': const []};
  return {
    ...page,
    'events': [
      for (final event in events.whereType<Map>())
        if (!isRetiredSocialNotice(event['kind'])) event,
    ],
  };
}
