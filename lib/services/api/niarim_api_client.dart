import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'niarim_api_exception.dart';

/// 認証トークン（GoogleのIDトークン）を取りに行く関数。
///
/// 未ログインならnullを返す。書き込み系APIはnullだと401になる。
/// トークンの取得・更新はログイン基盤側の責務なので、この層は
/// 「呼べば今有効なトークンが返ってくる」ことだけを前提にする。
typedef NiarimAuthTokenProvider = Future<String?> Function();

/// 作品広場バックエンド（`backend/`のLambda Function URL）を叩く
/// 低レベルHTTPクライアント。
///
/// エンドポイントごとの型付きメソッドは[CommunityApi]（`community_api.dart`）
/// が持ち、この層はその下請けとして
/// - ベースURLとパスの結合、クエリ文字列の組み立て
/// - `Authorization: Bearer <IDトークン>`の付与
/// - JSONのエンコード/デコード
/// - エラーレスポンス（`{"error": ..., "code": ...}`）の
///   [NiarimApiException]への変換
/// - タイムアウトと、**安全な場合だけの**再試行
/// だけを担当する。
///
/// ## 再試行の方針
///
/// GETは従来どおり自動再試行する。POST/PATCH/PUT/DELETEは既定では再試行
/// しない。サーバーに届いたあと応答だけ失われた場合に、二重投稿・二重通報
/// などを起こしうるため。
///
/// ただし、サーバー側で明示的に冪等性が保証されている個別エンドポイントだけは、
/// 呼び出し側が[postJson]または[patchJson]の[retries]を明示指定できる。
/// 現在の代表例は `POST /works`（YouTube videoIdがworkId兼冪等キー）と、
/// `PATCH /works/{workId}` の公開状態更新（同じ真偽値を再設定しても結果が同じ）。
/// 他の書き込みはretries=0のままなので、この例外が通報等へ波及しない。
class NiarimApiClient {
  /// APIのベースURL（末尾のスラッシュは持たない）。
  final String baseUrl;

  final http.Client _httpClient;
  final NiarimAuthTokenProvider _tokenProvider;

  /// 1回のリクエストのタイムアウト。
  final Duration timeout;

  /// GETの再試行回数（初回を含まない）。
  final int maxGetRetries;

  /// 再試行の待ち時間（n回目は`retryBackoff * n`待つ）。
  final Duration retryBackoff;

  NiarimApiClient({
    required String baseUrl,
    http.Client? httpClient,
    NiarimAuthTokenProvider? tokenProvider,
    this.timeout = const Duration(seconds: 15),
    this.maxGetRetries = 2,
    this.retryBackoff = const Duration(milliseconds: 400),
  }) : baseUrl = _normalizeBaseUrl(baseUrl),
       _httpClient = httpClient ?? http.Client(),
       _tokenProvider = (tokenProvider ?? _noToken);

  static Future<String?> _noToken() async => null;

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  /// GET。[authenticated]がtrueのときだけIDトークンを付ける
  /// （閲覧系は基本的にログイン不要だが、「自分のブックマーク一覧」の
  /// ように、呼び出し元が本人かどうかでサーバーの応答が変わるものがある）。
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
  }) => _sendWithRetry(
    'GET',
    _uri(path, query),
    authenticated: authenticated,
    retries: maxGetRetries,
  );

  /// POST。既定では書き込みを再送しない。
  ///
  /// [retries]は、呼び出し先が同じリクエストの再送を安全に受け付ける
  /// 冪等エンドポイントであることを確認した場合だけ0より大きくする。
  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    int retries = 0,
  }) => _sendWithRetry(
    'POST',
    _uri(path),
    body: body,
    authenticated: authenticated,
    retries: retries,
  );

  /// PATCH。既定では再送しない。
  ///
  /// 同じPATCHを繰り返しても結果が変わらないことが保証される呼び出しだけ、
  /// [retries]を明示的に指定する。
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    bool authenticated = true,
    int retries = 0,
  }) => _sendWithRetry(
    'PATCH',
    _uri(path),
    body: body,
    authenticated: authenticated,
    retries: retries,
  );

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _sendWithRetry(
    'PUT',
    _uri(path),
    body: body,
    authenticated: authenticated,
    retries: 0,
  );

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authenticated = true,
  }) => _sendWithRetry(
    'DELETE',
    _uri(path),
    authenticated: authenticated,
    retries: 0,
  );

  Future<Map<String, dynamic>> _sendWithRetry(
    String method,
    Uri uri, {
    Object? body,
    required bool authenticated,
    required int retries,
  }) async {
    NiarimApiException? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _sendOnce(method, uri, body: body, auth: authenticated);
      } on NiarimApiException catch (e) {
        // 再試行して意味があるのは、通信自体の失敗とサーバー側の一時障害
        // だけ。4xx（不正なリクエスト・権限不足・上限超過）は何度投げても
        // 同じなので即座に投げ直す。
        if (!e.isNetworkError && !e.isServerError) rethrow;
        lastError = e;
        if (attempt == retries) break;
        await Future<void>.delayed(retryBackoff * (attempt + 1));
      }
    }
    throw lastError!;
  }

  Future<Map<String, dynamic>> _sendOnce(
    String method,
    Uri uri, {
    Object? body,
    required bool auth,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (auth) {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['authorization'] = 'Bearer $token';
      }
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _httpClient.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw NiarimApiException.network('通信がタイムアウトしました');
    } catch (e) {
      throw NiarimApiException.network('通信に失敗しました: $e');
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    // **`response.body`を使わないこと**。あれはContent-Typeのcharsetを見て
    // 復号し、charsetの指定が無ければRFC通りlatin1へ倒す。日本語のエラー
    // メッセージがcharset無しで返ってきた場合、文字化けするか
    // 「Contains invalid characters」で例外になる（実際にこれを踏んだ）。
    // JSONはRFC 8259でUTF-8と決まっているので、常にUTF-8として読む。
    // allowMalformedは、壊れたバイト列でも例外にせず表示可能な文字へ
    // 落として、下のパース失敗の分岐で扱えるようにするため。
    // 204 No Content等、本文が無い成功応答は空のMapとして返す。
    final raw = response.bodyBytes.isEmpty
        ? ''
        : utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic>? json;
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // JSONでない応答（プロキシのエラーページ等）は下でまとめて扱う。
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json != null) return json;
      if (raw.isEmpty) return const {};
      throw NiarimApiException(response.statusCode, 'サーバーの応答を解釈できませんでした');
    }

    throw NiarimApiException(
      response.statusCode,
      (json?['error'] as String?) ?? 'サーバーがエラーを返しました（${response.statusCode}）',
      code: json?['code'] as String?,
    );
  }

  void close() => _httpClient.close();
}
