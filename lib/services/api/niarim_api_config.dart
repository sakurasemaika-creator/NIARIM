import 'package:http/http.dart' as http;

import 'community_api.dart';
import 'niarim_api_client.dart';

/// 作品広場バックエンドの接続先設定。
///
/// ## なぜビルド時の値なのか
///
/// バックエンド（`backend/`のCDKスタック）はデプロイのたびに
/// Lambda Function URLが決まる。アプリに焼き込むURLは、
/// `flutter build apk --dart-define=NIARIM_API_BASE_URL=https://xxxx.lambda-url.ap-northeast-1.on.aws`
/// のようにビルド時へ渡す。設定画面から変えられるようにはしない
/// （利用者が任意のサーバーへ向けられると、なりすましサーバーへ
/// IDトークンを送らせる経路になるため）。
///
/// ## 未設定のときの挙動
///
/// 何も渡さずにビルドすると[baseUrl]は空文字になり、[isConfigured]が
/// falseになる。この状態では`CommunityService`はダミーデータのまま動く
/// （デプロイ前でもアプリの画面確認・スクリーンショット・テストが
/// 一通りできる状態を保つため）。デプロイ後にURLを渡してビルドし直せば、
/// 同じ画面がそのまま実データで動く。
class NiarimApiConfig {
  const NiarimApiConfig._();

  /// ビルド時に`--dart-define=NIARIM_API_BASE_URL=...`で渡すAPIのベースURL。
  static const String baseUrl = String.fromEnvironment(
    'NIARIM_API_BASE_URL',
    defaultValue: '',
  );

  /// バックエンドの接続先が設定されているか。
  ///
  /// `https://`で始まることまで確認する。平文HTTPだとIDトークンが
  /// 盗聴されうるため、設定ミスは「未設定扱い（ダミーデータのまま）」へ
  /// 倒して、間違って平文で送ってしまう事故を防ぐ。
  static bool get isConfigured =>
      baseUrl.isNotEmpty && baseUrl.startsWith('https://');

  /// 設定済みならAPIクライアントを作る。未設定ならnull。
  ///
  /// [tokenProvider]はログイン基盤（未実装）が用意するGoogle IDトークンの
  /// 取得関数。渡さない場合は常に未ログイン扱いになり、読み取り系APIだけが
  /// 使える。
  static CommunityApi? createApi({
    NiarimAuthTokenProvider? tokenProvider,
    http.Client? httpClient,
  }) {
    if (!isConfigured) return null;
    return CommunityApi(
      NiarimApiClient(
        baseUrl: baseUrl,
        tokenProvider: tokenProvider,
        httpClient: httpClient,
      ),
    );
  }
}
