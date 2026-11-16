import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves only opaque match keys and their first observed event IDs. Android
/// shares its app-private database with the FCM service in the same process.
class CommunityNoticeHistory {
  static const _channel = MethodChannel(
    'com.niarim.niarim/activity_notice_history',
  );
  static final _fingerprint = RegExp(r'^[a-f0-9]{64}$');
  static final _eventId = RegExp(r'^[A-Za-z0-9_-]{1,120}$');
  static Future<void> _serial = Future<void>.value();

  static Future<Map<String, dynamic>> filter(
    Map<String, dynamic> page,
    String? owner,
  ) async {
    final responseOwner = page['noticeOwner'];
    if (responseOwner != null && owner != null && responseOwner != owner) {
      // An auth change may have happened while the request was in flight.
      return {...page, 'events': const []};
    }
    if (responseOwner is String &&
        RegExp(r'^N[a-f0-9]{32}$').hasMatch(responseOwner)) {
      owner ??= responseOwner;
    }
    final events = (page['events'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final dedup = <Map<String, String>>[];
    for (final event in events.reversed) {
      final key = event['firstKey'];
      final id = event['eventId'];
      if (key is String &&
          _fingerprint.hasMatch(key) &&
          id is String &&
          _eventId.hasMatch(id)) {
        dedup.add({'key': key, 'event': id});
      }
    }
    if (dedup.isEmpty) return page;
    final account = owner;
    final Set<String> accepted;
    if (account == null) {
      accepted = {};
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      accepted =
          (await _channel.invokeListMethod<String>('filter', {
                    'owner': account,
                    'receipts': dedup,
                  }) ??
                  const <String>[])
              .toSet();
    } else {
      final task = _serial.then((_) async {
        final prefs = await SharedPreferences.getInstance();
        final allowed = <String>{};
        for (final receipt in dedup) {
          final key = 'noticeHistory.$account.${receipt['key']}';
          final id = receipt['event']!;
          final previous = prefs.getString(key);
          if (previous == id ||
              (previous == null && await prefs.setString(key, id))) {
            allowed.add(id);
          }
        }
        return allowed;
      });
      _serial = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      accepted = await task;
    }
    final dedupIds = dedup.map((entry) => entry['event']).toSet();
    return {
      ...page,
      'events': [
        for (final event in events)
          if (!dedupIds.contains(event['eventId']) ||
              accepted.contains(event['eventId']))
            event,
      ],
    };
  }
}
