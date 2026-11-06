import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../router.dart';
import 'community_service.dart';
import 'google_auth_service.dart';

/// FCM client glue only. NIARIM data stays on AWS DynamoDB/Lambda.
/// No Firebase Auth, Firestore, Storage or app-wide push state is required.
/// Start only after Firebase.initializeApp succeeds on Android.
class PushNotificationService {
  PushNotificationService({
    required this._auth,
    required this._community,
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  static bool firebaseAvailable = false;
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final GoogleAuthService _auth;
  final CommunityService _community;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  bool _started = false;
  bool _disposed = false;
  bool _syncing = false;
  bool _needsSync = false;
  bool _permissionPrompted = false;
  String? _registeredOwner;
  String? _registeredToken;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _auth.addListener(_scheduleSync);
    _community.addListener(_scheduleSync);
    _refreshSub = _messaging.onTokenRefresh.listen((_) => _scheduleSync());
    _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
    _tapSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    unawaited(_messaging.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    }).catchError((Object error) {
      debugPrint('FCM initial message unavailable: $error');
    }));
    _scheduleSync();
  }

  // Restrict deep links to NIARIM-owned, allowlisted screens. Do not treat
  // arbitrary notification payloads as navigable routes.
  @visibleForTesting
  static String? routeForData(Map<String, dynamic> data) {
    final route = data['targetRoute'];
    if (route == '/creator-missions') return '/creator-missions';
    if (route is String && route.startsWith('/community/work/')) {
      final id = route.substring('/community/work/'.length);
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
        return '/community/work/$id';
      }
    }
    return null;
  }

  void _handleTap(RemoteMessage message) {
    final route = routeForData(message.data);
    if (route == null || _disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) appRouter.push(route);
    });
  }

  void _showForeground(RemoteMessage message) {
    if (_disposed) return;
    final notice = message.notification;
    final body = notice?.body ?? notice?.title;
    if (body == null || body.isEmpty) return;
    final route = routeForData(message.data);
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(body),
      duration: const Duration(seconds: 5),
      action: route == null ? null : SnackBarAction(
        label: '開く',
        onPressed: () => appRouter.push(route),
      ),
    ));
  }

  void _scheduleSync() {
    if (_disposed) return;
    _needsSync = true;
    if (!_syncing) unawaited(_syncLoop());
  }

  Future<void> _syncLoop() async {
    _syncing = true;
    try {
      while (_needsSync && !_disposed) {
        _needsSync = false;
        try {
          await _syncOnce();
        } catch (error) {
          // Offline use must continue; next sign-in/token refresh/app launch
          // retries registration without blocking any editor operation.
          debugPrint('FCM token sync unavailable: $error');
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    final owner = _community.currentUserId;
    final account = _auth.account?.id;
    final api = _community.api;
    if (owner == null || account == null || api == null) {
      if (_registeredToken != null) {
        // Invalidate the old FCM token immediately after sign-out. We may no
        // longer have an OAuth ID token to DELETE the saved backend record;
        // FCM rejects the invalidated token and AWS removes it after a send.
        await _messaging.deleteToken();
        _registeredOwner = null;
        _registeredToken = null;
      }
      return;
    }
    if (_registeredOwner != null && _registeredOwner != owner) {
      await _messaging.deleteToken();
      _registeredOwner = null;
      _registeredToken = null;
    }
    final permission = await _messaging.getNotificationSettings();
    final permitted = permission.authorizationStatus ==
            AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
    if (!permitted) {
      // Android 13+ permission: only prompt once after actual sign-in, never
      // while the signed-out user edits locally.
      if (_permissionPrompted) return;
      _permissionPrompted = true;
      final requested = await _messaging.requestPermission();
      if (requested.authorizationStatus != AuthorizationStatus.authorized &&
          requested.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
    }
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    if (_registeredOwner == owner && _registeredToken == token) return;
    // Refuse to attach a token after a rapid sign-out/account switch.
    if (_auth.account?.id != account || _community.currentUserId != owner) {
      _needsSync = true;
      return;
    }
    final accepted = await api.putPushToken(
      owner,
      token: token,
      platform: 'android',
    );
    if (!accepted) return;
    if (_auth.account?.id != account || _community.currentUserId != owner) {
      await _messaging.deleteToken();
      _registeredOwner = null;
      _registeredToken = null;
      _needsSync = true;
      return;
    }
    _registeredOwner = owner;
    _registeredToken = token;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _auth.removeListener(_scheduleSync);
    _community.removeListener(_scheduleSync);
    unawaited(_refreshSub?.cancel());
    unawaited(_foregroundSub?.cancel());
    unawaited(_tapSub?.cancel());
  }
}
