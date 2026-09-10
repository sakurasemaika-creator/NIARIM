import 'dart:async';

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

  static const List<String> youtubeUploadScopes = <String>[
    'https://www.googleapis.com/auth/youtube.upload',
  ];

  final GoogleSignIn _signIn;
  // The SDK singleton outlives a failed bootstrap and its service owner.
  // Cache by SDK identity so a fresh service can retry without initializing an
  // already initialized SDK a second time. Failed initialization is retryable.
  static final _sdkInitializations = Expando<Future<void>>();
  Future<void>? _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  GoogleSignInAccount? _account;
  bool _initialized = false;
  bool _authOperationInProgress = false;
  Object? _lastError;

  GoogleSignInAccount? get account => _account;
  bool get isConfigured => googleClientId.isNotEmpty;
  bool get isInitialized => _initialized;
  bool get isSignedIn => _account != null;
  bool get authOperationInProgress => _authOperationInProgress;
  Object? get lastError => _lastError;

  /// GoogleSignIn 7.xはinitializeを1回だけ呼ぶ必要があるため、起動時に
  /// SDKインスタンスごとに初期化を共有し、起動の再試行でも重複させない。
  ///
  /// OAuthクライアントIDを渡していない通常のWidgetテスト・画面監査・
  /// 未設定開発ビルドでは、ネイティブGoogle SDKへ一切触れず匿名モードで
  /// 初期化完了扱いにする。これにより認証未設定がアプリ全体の起動を妨げない。
  Future<void> init() {
    if (_initialized) return Future.value();
    return _initialization ??= _initialize().catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  Future<void> _initializeSdk() async {
    final initialization = _sdkInitializations[_signIn] ??= _signIn.initialize(
      serverClientId: googleClientId,
    );
    try {
      await initialization;
    } catch (_) {
      if (identical(_sdkInitializations[_signIn], initialization)) {
        _sdkInitializations[_signIn] = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (!isConfigured) {
      _initialized = true;
      return;
    }

    await _initializeSdk();

    _authSubscription = _signIn.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn(:final user):
            _setAccount(user);
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
    _initialized = true;
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
  /// UIを出さないため、未設定・未ログイン時はnullを返す。書き込み操作を
  /// 始める前に[signInInteractively]を呼ぶのは画面側の責務。
  Future<String?> backendIdToken() async {
    if (!isConfigured) return null;
    final user = _account;
    if (user == null) return null;
    return user.authentication.idToken;
  }

  /// `youtube.upload` スコープのアクセストークンを取得する。
  ///
  /// [promptIfNecessary] がfalseならUIを出さず、既に許可済みの時だけ返す。
  /// trueは必ずボタン等のユーザー操作から呼ぶこと。
  Future<String?> youtubeUploadAccessToken({bool promptIfNecessary = false}) =>
      _runExclusive(() async {
        _ensureReadyForGoogle();
        var user = _account;
        if (user == null) {
          if (!promptIfNecessary) return null;
          user = await _signInInteractivelyInternal();
        }

        var authorization = await user.authorizationClient
            .authorizationForScopes(youtubeUploadScopes);
        if (authorization == null && promptIfNecessary) {
          authorization = await user.authorizationClient.authorizeScopes(
            youtubeUploadScopes,
          );
        }
        return authorization?.accessToken;
      });

  Future<void> signOut() => _runExclusive(() async {
    _ensureReadyForGoogle();
    await _signIn.signOut();
    _setAccount(null);
  });

  /// Google側のNIARIM認可そのものも取り消す場合に使う。
  Future<void> disconnect() => _runExclusive(() async {
    _ensureReadyForGoogle();
    await _signIn.disconnect();
    _setAccount(null);
  });

  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    if (_authOperationInProgress) {
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
    _authSubscription?.cancel();
    super.dispose();
  }
}
