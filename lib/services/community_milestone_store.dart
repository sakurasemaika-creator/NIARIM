import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local count milestone. This deliberately has no follower identity.
class CommunityMilestoneEvent {
  final String id;
  final bool isFollower;
  final int count;
  final String? workTitle;
  final DateTime createdAt;
  final bool read;

  const CommunityMilestoneEvent({
    required this.id,
    required this.isFollower,
    required this.count,
    required this.createdAt,
    this.workTitle,
    this.read = false,
  });

  factory CommunityMilestoneEvent.fromJson(Map<String, dynamic> json) =>
      CommunityMilestoneEvent(
        id: json['id'] as String? ?? '',
        isFollower: json['follower'] == true,
        count: (json['count'] as num?)?.toInt() ?? 0,
        workTitle: json['title'] as String?,
        createdAt: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        read: json['read'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'follower': isFollower,
        'count': count,
        'title': workTitle,
        'date': createdAt.toIso8601String(),
        'read': read,
      };

  CommunityMilestoneEvent markedRead() => CommunityMilestoneEvent(
        id: id, isFollower: isFollower, count: count,
        createdAt: createdAt, workTitle: workTitle, read: true,
      );
}

/// Only aggregate counts, last-seen counts and event history are stored.
/// The server does not need to remember a user's previous observed counts.
/// First sample is a baseline, never a notification.
class CommunityMilestoneStore {
  Future<void> _pending = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    final previous = _pending;
    final done = Completer<void>();
    _pending = done.future;
    await previous;
    try {
      return await operation();
    } finally {
      done.complete();
    }
  }

  static const thresholds = <int>[
    10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000,
  ];
  static const prefix = 'community.milestone.v1.';

  String _key(String accountId) => '$prefix$accountId';

  Map<String, dynamic> _read(SharedPreferences prefs, String accountId) {
    try {
      final raw = prefs.getString(_key(accountId));
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  List<CommunityMilestoneEvent> _events(Map<String, dynamic> data) =>
      ((data['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((v) => CommunityMilestoneEvent.fromJson(
                Map<String, dynamic>.from(v),
              ))
          .toList();

  Future<List<CommunityMilestoneEvent>> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return _events(_read(prefs, accountId));
  }

  Future<List<CommunityMilestoneEvent>> markAllRead(String accountId) => _exclusive(() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _read(prefs, accountId);
    final events = _events(data).map((e) => e.markedRead()).toList();
    data['events'] = events.map((e) => e.toJson()).toList();
    await prefs.setString(_key(accountId), jsonEncode(data));
    return events;
  });

  /// [bookmarks] maps work ids to (title, current bookmark count).
  /// Omitted values are left unchanged. This is account-scoped.
  Future<List<CommunityMilestoneEvent>> observe(
    String accountId, {
    int? followers,
    Map<String, (String, int)>? bookmarks,
  }) => _exclusive(() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _read(prefs, accountId);
    final events = _events(data);
    final previousBookmarks = Map<String, dynamic>.from(
      (data['bookmarks'] as Map?) ?? const {},
    );

    int? greatestCrossed(int previous, int current) {
      if (current <= previous) return null;
      for (final t in thresholds.reversed) {
        if (previous < t && current >= t) return t;
      }
      return null;
    }

    if (followers != null) {
      final before = (data['followers'] as num?)?.toInt();
      if (before != null) {
        final crossed = greatestCrossed(before, followers);
        if (crossed != null) {
          events.insert(0, CommunityMilestoneEvent(
            id: 'followers-${DateTime.now().microsecondsSinceEpoch}-$crossed',
            isFollower: true, count: crossed, createdAt: DateTime.now(),
          ));
        }
      }
      data['followers'] = followers;
    }
    if (bookmarks != null) {
      for (final entry in bookmarks.entries) {
        final before = (previousBookmarks[entry.key] as num?)?.toInt();
        final current = entry.value.$2;
        if (before != null) {
          final crossed = greatestCrossed(before, current);
          if (crossed != null) {
            events.insert(0, CommunityMilestoneEvent(
              id: 'work-${entry.key}-${DateTime.now().microsecondsSinceEpoch}-$crossed',
              isFollower: false, count: crossed,
              workTitle: entry.value.$1, createdAt: DateTime.now(),
            ));
          }
        }
        previousBookmarks[entry.key] = current;
      }
    }
    data['bookmarks'] = previousBookmarks;
    data['events'] = events.take(50).map((e) => e.toJson()).toList();
    await prefs.setString(_key(accountId), jsonEncode(data));
    return events.take(50).toList();
  });
}
