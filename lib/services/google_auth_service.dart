import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// NIARIMバックエンド認証とYouTube投稿認可を同じGoogleアカウントへ
/// ひも付けるサービス。
///
/// 認証（IDトークン）とYouTube Data APIの認可（アクセストークン）は別物。
/// - [backendIdToken] はNIARIM APIの `Authorization: Bearer ...` 用。
/// - [youtubeUploadAccessToken] はYouTube `videos.insert` 用。
///
/// OAuthクライアントIDはリポジトリへ直書きせず、
/// `--dart-define=NIARIM_GOOGLE_CLIENT_ID=...` で渡す。この値はbackendの
/// `GOOGLE_CLIENT_ID` と同じWeb OAuth client IDにすること。Androidで
/// google-services.jsonを使わない構成ではgoogle_sign_inのserverClientId
/// としても利用する。
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  static const String googleClientId = String.fromEnvironment(
    'NIARIM_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static const _youtubeReadOnlyScope =
      'https://www.googleapis.com/auth/youtube.readonly';
  static const List<String> youtubeUploadScopes = <String>[
    _youtubeReadOnlyScope,
    'https://www.googleapis.com/auth/youtube.upload',
  ];

  final GoogleSignIn _signIn;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  /// GoogleSignInごとの`initialize`。SDKは1プロセスにつき1回しか
  /// `initialize`を呼べない（2回目は未定義動作）ため、起動に失敗して
  /// Serviceを作り直した場合も、最初の呼び出しの結果を使い回す。
  static final Expando<Future<void>> _sdkInitializations = Expando();

  GoogleSignInAccount? _account;
  bool _initialized = false;
  bool _authOperationInProgress = false;
  bool _disposed = false;
  Object? _lastError;
  Future<String?>? _backendTokenRefresh;
  String? _lastRejectedBackendToken;

  GoogleSignInAccount? get account => _account;
  bool get isConfigured => googleClientId.isNotEmpty;
  bool get isInitialized => _initialized;
  bool get isSignedIn => _account != null;
  bool get authOperationInProgress =>
      _authOperationInProgress || _backendTokenRefresh != null;
  Object? get lastError => _lastError;

  /// GoogleSignIn 7.xはinitializeを1回だけ呼ぶ必要があるため、起動時に
  /// app_bootstrapから1度だけ実行する。
  ///
  /// OAuthクライアントIDを渡していない通常のWidgetテスト・画面監査・
  /// 未設定開発ビルドでは、ネイティブGoogle SDKへ一切触れず匿名モードで
  /// 初期化完了扱いにする。これにより認証未設定がアプリ全体の起動を妨げない。
  Future<void> init() async {
    if (_initialized) return;
    if (!isConfigured) {
      _initialized = true;
      return;
    }

    await _initializeSdkOnce();
    _initialized = true;

    _authSubscription = _signIn.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn(:final user):
            // A renewal must validate the returned account before adopting
            // it. In particular, an OS account chooser may return a new user.
            if (_backendTokenRefresh == null) _setAccount(user);
          case GoogleSignInAuthenticationEventSignOut():
            _setAccount(null);
        }
      },
      onError: (Object error) {
        _lastError = error;
        notifyListeners();
      },
    );

    final lightweight = _signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      try {
        final user = await lightweight;
        if (user != null) _setAccount(user);
      } catch (error) {
        _lastError = error;
        notifyListeners();
      }
    }
  }

  Future<void> _initializeSdkOnce() async {
    final pending =
        _sdkInitializations[_signIn] ??
        _signIn.initialize(serverClientId: googleClientId);
    _sdkInitializations[_signIn] = pending;
    try {
      await pending;
    } catch (_) {
      // 失敗した初期化は使い回さず、次の起動の試行でやり直す。
      if (identical(_sdkInitializations[_signIn], pending)) {
        _sdkInitializations[_signIn] = null;
      }
      rethrow;
    }
  }

  /// ユーザー操作から呼ぶ対話ログイン。
  ///
  /// Google SDKのauthenticate/signOut/disconnect/追加scope認可は同時実行しない。
  /// アカウント切替と投稿用scope取得が競合すると、IDトークンとYouTube tokenが
  /// 別アカウント由来になる可能性があるため、先行操作中の新規操作は明示的に
  /// 拒否してUI側から再試行してもらう。
  Future<GoogleSignInAccount> signInInteractively() =>
      _runExclusive(_signInInteractivelyInternal);

  Future<GoogleSignInAccount> _signInInteractivelyInternal() async {
    _ensureReadyForGoogle();
    if (!_signIn.supportsAuthenticate()) {
      throw UnsupportedError('このプラットフォームでは対話Googleログインに未対応です');
    }
    final user = await _signIn.authenticate();
    _setAccount(user);
    return user;
  }

  /// NIARIM APIが検証するOpenID Connect IDトークン。
  ///
  /// 期限切れの場合は、同じアカウントでの軽量認証を一度試す。
  /// 再認証できなければ、次の操作からログインし直せるようにログアウト扱いにする。
  Future<String?> backendIdToken() async {
    if (!isConfigured || _disposed) return null;
    final user = _account;
    if (user == null) return null;
    final token = user.authentication.idToken;
    if (token == null || token.isEmpty || _isExpired(token)) {
      return _renewBackendIdToken(user);
    }
    return token;
  }

  Future<String?> refreshRejectedBackendIdToken(String rejected) async {
    final user = _account;
    if (!isConfigured || _disposed || user == null) return null;
    final current = user.authentication.idToken;
    if (current == rejected) return _renewBackendIdToken(user);
    // Parallel requests might both have sent the same old token. Reuse the
    // completed renewal only if this is the token actually replaced.
    return rejected == _lastRejectedBackendToken ? current : null;
  }

  bool _isExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiry = payload is Map<String, dynamic> ? payload['exp'] : null;
      return expiry is int &&
          expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } on FormatException {
      return false;
    }
  }

  Future<String?> _renewBackendIdToken(GoogleSignInAccount user) {
    final pending = _backendTokenRefresh;
    if (pending != null) return pending;
    if (_authOperationInProgress) return Future<String?>.value();

    final renewal = Completer<String?>();
    _backendTokenRefresh = renewal.future;
    notifyListeners();
    unawaited(_completeBackendTokenRenewal(user, renewal));
    return renewal.future;
  }

  Future<void> _completeBackendTokenRenewal(
    GoogleSignInAccount user,
    Completer<String?> renewal,
  ) async {
    String? replacement;
    try {
      GoogleSignInAccount? renewed;
      try {
        renewed = await _signIn.attemptLightweightAuthentication();
      } on Object {
        // A failed renewal is handled like an expired session.
      }
      if (_disposed || !identical(_account, user)) return;

      final rejected = user.authentication.idToken;
      final token = renewed?.authentication.idToken;
      if (renewed == null ||
          renewed.id != user.id ||
          token == null ||
          token.isEmpty ||
          token == rejected ||
          _isExpired(token)) {
        _setAccount(null);
        return;
      }

      _lastRejectedBackendToken = rejected;
      _setAccount(renewed);
      replacement = token;
    } finally {
      _backendTokenRefresh = null;
      renewal.complete(replacement);
      if (!_disposed) notifyListeners();
    }
  }

  /// 動画の投稿と、登録時のチャンネル・動画の所有確認に使う。
  ///
  /// [promptIfNecessary] がfalseならUIを出さず、既に許可済みの時だけ返す。
  /// trueは必ずボタン等のユーザー操作から呼ぶこと。
  Future<String?> youtubeUploadAccessToken({bool promptIfNecessary = false}) =>
      _youtubeAccessToken(
        youtubeUploadScopes,
        promptIfNecessary: promptIfNecessary,
      );

  /// チャンネルの更新や、アップロード済み動画の登録だけを行う場合に使う。
  Future<String?> youtubeReadAccessToken({bool promptIfNecessary = false}) =>
      _youtubeAccessToken(const [
        _youtubeReadOnlyScope,
      ], promptIfNecessary: promptIfNecessary);

  Future<String?> _youtubeAccessToken(
    List<String> scopes, {
    required bool promptIfNecessary,
  }) => _runExclusive(() async {
    _ensureReadyForGoogle();
    var user = _account;
    if (user == null) {
      if (!promptIfNecessary) return null;
      user = await _signInInteractivelyInternal();
    }

    var authorization = await user.authorizationClient.authorizationForScopes(
      scopes,
    );
    if (authorization == null && promptIfNecessary) {
      authorization = await user.authorizationClient.authorizeScopes(scopes);
    }
    return authorization?.accessToken;
  });

  Future<void> signOut() => _runExclusive(() async {
    _ensureReadyForGoogle();
    await _signIn.signOut();
    _setAccount(null);
  });

  Future<void> signOutDeletedAccount(String token) async {
    await _backendTokenRefresh;
    final user = _account;
    if (_disposed || user == null || authOperationInProgress) return;
    if (user.authentication.idToken != token &&
        _lastRejectedBackendToken != token) {
      return;
    }
    await _runExclusive(() async {
      try {
        await _signIn.signOut();
      } finally {
        if (_account?.id == user.id) _setAccount(null);
      }
    });
  }

  /// Google側のNIARIM認可そのものも取り消す場合に使う。
  Future<void> disconnect() => _runExclusive(() async {
    _ensureReadyForGoogle();
    await _signIn.disconnect();
    _setAccount(null);
  });

  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    if (authOperationInProgress) {
      throw StateError('Googleアカウント操作を処理中です。完了後にもう一度お試しください');
    }
    _authOperationInProgress = true;
    notifyListeners();
    try {
      return await operation();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    } finally {
      _authOperationInProgress = false;
      notifyListeners();
    }
  }

  void _setAccount(GoogleSignInAccount? value) {
    if (identical(_account, value)) return;
    if (_account?.id != value?.id) _lastRejectedBackendToken = null;
    _account = value;
    _lastError = null;
    notifyListeners();
  }

  void _ensureReadyForGoogle() {
    if (!_initialized) {
      throw StateError('GoogleAuthService.init() がまだ呼ばれていません');
    }
    if (!isConfigured) {
      throw StateError('NIARIM_GOOGLE_CLIENT_ID が未設定です。Google認証は匿名モードです');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
