import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/community_api.dart';
import 'api/niarim_api_exception.dart';

/// One tiny retryable checkpoint is stored before each network request.
/// The queue is capped to avoid unbounded phone storage and server work.
/// Offline data is NEVER marked as verified or automatically made into coins.
class CreatorEditSessionReporter {
  CreatorEditSessionReporter({
    required CommunityApi? api,
    required String? Function() accountId,
  }) : _api = api, _accountId = accountId;

  /// Enable only with the backend's separately guarded measurement pilot.
  /// No traffic or storage changes occur in default/offline/demo builds.
  static const bool pilotEnabled = bool.fromEnvironment(
    'NIARIM_EDIT_SESSION_PILOT', defaultValue: false,
  );

  final CommunityApi? _api;
  final String? Function() _accountId;
  Future<void> _serial = Future<void>.value();
  _EditPeriod? _active;

  /// Continuous-editing safety limit: the server expires after 20 minutes.
  /// Normal uploads happen on exit or after 2 minutes without interaction.
  static const _checkpointPeriod = Duration(minutes: 15);
  static const _idleAfter = Duration(minutes: 2);
  static const _idlePoll = Duration(seconds: 30);
  static const _maxPending = 16;
  static const _keyPrefix = 'creator_edit_pending_v1_';
  static const _lostPrefix = 'creator_edit_unverified_seconds_v1_';

  /// A secure random UUID prevents nonce collision; it is not proof of edits.
  static String _nonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return [
      [for (int i = 0; i < 4; i++) hex(i)].join(),
      [for (int i = 4; i < 6; i++) hex(i)].join(),
      [for (int i = 6; i < 8; i++) hex(i)].join(),
      [for (int i = 8; i < 10; i++) hex(i)].join(),
      [for (int i = 10; i < 16; i++) hex(i)].join(),
    ].join('-');
  }

  bool get _canSend => pilotEnabled && _api != null && _accountId() != null;

  /// Start at entry to either canvas or timeline; a short 3-second visit
  /// creates the same kind of session as an extended one.
  void begin({
    required String projectId,
    required int Function() activeSeconds,
  }) {
    if (!_canSend) return;
    end();
    final period = _EditPeriod(
      projectId: projectId,
      accountId: _accountId()!,
      nonce: _nonce(),
      activeSeconds: activeSeconds,
      lastSnapshotSeconds: activeSeconds(),
    );
    _active = period;
    period.timer = Timer.periodic(
      _checkpointPeriod, (_) => _checkpoint(period, stop: false),
    );
    // The client-only idle poll performs NO network request until the
    // editor has been inactive for two minutes.
    period.idleTimer = Timer.periodic(_idlePoll, (_) {
      if (period.closed || !identical(_active, period)) return;
      if (DateTime.now().difference(period.lastInteractionAt) >= _idleAfter) {
        _checkpoint(period, stop: true);
      }
    });
    _enqueue(() async {
      await _drain(period.accountId);
      await _start(period);
    });
  }

  /// Pointer movement keeps an in-progress brush stroke active without
  /// counting taps, scrubbing, or panning as verified edits.
  void noteInteraction() {
    final period = _active;
    if (period != null && !period.closed) {
      period.lastInteractionAt = DateTime.now();
    }
  }

  void recordCommittedMutation(
    String projectId, {required int Function() activeSeconds},
  ) {
    if (_active == null && _canSend) {
      // Reopen a short bounded server session after an idle flush. The
      // absolute local editing counter is never resent as a fresh delta.
      begin(projectId: projectId, activeSeconds: activeSeconds);
    }
    final period = _active;
    if (period == null || period.closed ||
        period.projectId != projectId ||
        period.accountId != _accountId()) return;
    // Count commits, not pointer/tap/scrub events. A single real edit suffices
    // for a 1-9 second session, capped by the backend's server clock.
    period.lastInteractionAt = DateTime.now();
    if (period.mutations < 100000) period.mutations++;
  }

  void _checkpoint(_EditPeriod period, {required bool stop}) {
    if (period.closed && !stop) return;
    final nowSeconds = period.activeSeconds();
    final delta = max(0, nowSeconds - period.lastSnapshotSeconds);
    period.lastSnapshotSeconds = nowSeconds;
    final edits = period.mutations;
    period.mutations = 0;
    if (stop) {
      period.closed = true;
      period.timer?.cancel();
      period.timer = null;
      period.idleTimer?.cancel();
      period.idleTimer = null;
      if (identical(_active, period)) _active = null;
    }
    // No need for a costly write if there was no actual editing;
    // still close the server session at exit.
    if (!stop && delta == 0 && edits == 0) return;
    _enqueue(() async {
      if (period.accountId != _accountId()) return; // account isolation
      await _drain(period.accountId);
      if (period.sessionId == null) await _start(period);
      if (period.sessionId == null) {
        // If start failed before the server was contacted, retaining the
        // unverified time locally is safer than fabricating server credit.
        await _retainUnverified(period.accountId, delta);
        return;
      }
      final payload = <String, dynamic>{
        'sessionId': period.sessionId,
        'sequence': period.sequence++,
        'activeSeconds': delta.clamp(0, 3600),
        'meaningfulMutations': edits.clamp(0, 100000),
        'stop': stop,
      };
      await _persistAndDrain(period.accountId, payload);
    });
  }

  void end() {
    final period = _active;
    if (period == null) return;
    _checkpoint(period, stop: true);
  }

  Future<void> _start(_EditPeriod p) async {
    if (p.accountId != _accountId() || _api == null) return;
    try {
      final result = await _api.beginCreatorEditSession(p.nonce);
      final sid = result['sessionId'];
      final seq = result['nextSequence'];
      if (sid is String && seq is int && seq > 0) {
        p.sessionId = sid;
        p.sequence = seq;
      }
    } on Object catch (error) {
      // A network error or a disabled server means no reward credit.
      debugPrint('Creator edit candidate start unavailable: $error');
    }
  }

  void _enqueue(Future<void> Function() work) {
    // Async failures must not permanently break the serial chain.
    _serial = _serial.then((_) => work()).catchError((Object error) {
      debugPrint('Creator edit checkpoint deferred: $error');
    });
  }

  Future<List<Map<String, dynamic>>> _pending(
    SharedPreferences prefs, String accountId,
  ) async {
    final raw = prefs.getString('$_keyPrefix$accountId');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .take(_maxPending).toList();
    } on Object {
      return [];
    }
  }

  Future<void> _retainUnverified(String accountId, int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_lostPrefix$accountId';
    final prev = prefs.getInt(key) ?? 0;
    // Keep ONE aggregate integer, never per-edit or per-15-min histories.
    await prefs.setInt(key, min(360000000, prev + seconds));
  }

  Future<void> _persistAndDrain(
    String accountId, Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await _pending(prefs, accountId);
    if (pending.length >= _maxPending) {
      // Missing the head sequence means later entries cannot safely replay.
      // Consolidate candidate seconds for the local UI, never for rewards.
      final lost = pending.fold<int>(0,
          (sum, p) => sum + ((p['activeSeconds'] as num?)?.toInt() ?? 0));
      await _retainUnverified(accountId, lost);
      pending.clear();
    }
    pending.add(payload);
    await prefs.setString('$_keyPrefix$accountId', jsonEncode(pending));
    await _drain(accountId);
  }

  Future<void> _drain(String accountId) async {
    if (accountId != _accountId() || _api == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = await _pending(prefs, accountId);
    while (pending.isNotEmpty && accountId == _accountId()) {
      final payload = pending.first;
      try {
        await _api.checkpointCreatorEditSession(
          sessionId: payload['sessionId'] as String,
          sequence: (payload['sequence'] as num).toInt(),
          activeSeconds: (payload['activeSeconds'] as num).toInt(),
          meaningfulMutations: (payload['meaningfulMutations'] as num).toInt(),
          stop: payload['stop'] == true,
        );
        pending.removeAt(0);
        await prefs.setString('$_keyPrefix$accountId', jsonEncode(pending));
      } on NiarimApiException catch (error) {
        // A stale/invalid server session cannot be made valid by retries.
        // Preserve its total as non-reward-eligible local seconds and clear
        // the dependent sequence chain. A new server session can then start.
        if (error.code == 'EDIT_SESSION_EXPIRED' ||
            error.code == 'EDIT_SESSION_MISSING' ||
            error.code == 'EDIT_SESSION_SEQUENCE') {
          final lost = pending.fold<int>(0,
              (sum, p) =>
                  sum + ((p['activeSeconds'] as num?)?.toInt() ?? 0));
          await _retainUnverified(accountId, lost);
          pending.clear();
          await prefs.remove('$_keyPrefix$accountId');
        }
        return;
      } on Object {
        // Device offline or HTTP response lost: identical seq stays on disk
        // for the next session launch. No double grant is possible.
        return;
      }
    }
  }

  /// For test harnesses, wait for any pending in-process tasks.
  Future<void> get settled => _serial;
}

class _EditPeriod {
  _EditPeriod({
    required this.projectId,
    required this.accountId,
    required this.nonce,
    required this.activeSeconds,
    required this.lastSnapshotSeconds,
  });
  final String projectId;
  final String accountId;
  final String nonce;
  final int Function() activeSeconds;
  Timer? timer;
  Timer? idleTimer;
  DateTime lastInteractionAt = DateTime.now();
  String? sessionId;
  int sequence = 1;
  int lastSnapshotSeconds;
  int mutations = 0;
  bool closed = false;
}
