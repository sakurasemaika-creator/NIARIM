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
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  GoogleSignInAccount? _account;
  bool _initialized = false;
  Object? _lastError;

  GoogleSignInAccount? get account => _account;
  bool get isInitialized => _initialized;
  bool get isSignedIn => _account != null;
  Object? get lastError => _lastError;

  /// GoogleSignIn 7.xはinitializeを1回だけ呼ぶ必要があるため、起動時に
  /// app_bootstrapから1度だけ実行する。UIを出さないlightweight認証もここで
  /// 試みるが、未ログインならそのまま匿名利用を継続する。
  Future<void> init() async {
    if (_initialized) return;

    await _signIn.initialize(
      serverClientId: googleClientId.isEmpty ? null : googleClientId,
    );
    _initialized = true;

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
        // 起動時の無操作認証失敗はアプリ起動を妨げない。必要になった時に
        // [signInInteractively] で明示的にログインしてもらう。
        _lastError = error;
        notifyListeners();
      }
    }
  }

  /// ユーザー操作から呼ぶ対話ログイン。
  Future<GoogleSignInAccount> signInInteractively() async {
    _ensureInitialized();
    if (!_signIn.supportsAuthenticate()) {
      throw UnsupportedError('このプラットフォームでは対話Googleログインに未対応です');
    }
    try {
      final user = await _signIn.authenticate();
      _setAccount(user);
      return user;
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  /// NIARIM APIが検証するOpenID Connect IDトークン。
  ///
  /// UIを出さないため、未ログイン時はnullを返す。書き込み操作を始める前に
  /// [signInInteractively] を呼ぶのは画面側の責務。
  Future<String?> backendIdToken() async {
    final user = _account;
    if (user == null) return null;
    return user.authentication.idToken;
  }

  /// `youtube.upload` スコープのアクセストークンを取得する。
  ///
  /// [promptIfNecessary] がfalseならUIを出さず、既に許可済みの時だけ返す。
  /// trueは必ずボタン等のユーザー操作から呼ぶこと。
  Future<String?> youtubeUploadAccessToken({
    bool promptIfNecessary = false,
  }) async {
    _ensureInitialized();
    var user = _account;
    if (user == null) {
      if (!promptIfNecessary) return null;
      user = await signInInteractively();
    }

    try {
      var authorization = await user.authorizationClient.authorizationForScopes(
        youtubeUploadScopes,
      );
      if (authorization == null && promptIfNecessary) {
        authorization = await user.authorizationClient.authorizeScopes(
          youtubeUploadScopes,
        );
      }
      return authorization?.accessToken;
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _ensureInitialized();
    await _signIn.signOut();
    _setAccount(null);
  }

  /// Google側のNIARIM認可そのものも取り消す場合に使う。
  Future<void> disconnect() async {
    _ensureInitialized();
    await _signIn.disconnect();
    _setAccount(null);
  }

  void _setAccount(GoogleSignInAccount? value) {
    if (identical(_account, value)) return;
    _account = value;
    _lastError = null;
    notifyListeners();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('GoogleAuthService.init() がまだ呼ばれていません');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
