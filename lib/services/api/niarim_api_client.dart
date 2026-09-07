import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'niarim_api_exception.dart';

typedef NiarimAuthTokenProvider = Future<String?> Function();

class NiarimApiClient {
  final String baseUrl;

  final http.Client _httpClient;
  final NiarimAuthTokenProvider _tokenProvider;

  final Duration timeout;
  final int maxGetRetries;
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

  bool _canRetryUnauthorized(String method, Uri uri) {
    if (method == 'GET') return true;
    if (method == 'POST' && uri.path == '/works') return true;
    if (method == 'PATCH' && RegExp(r'^/works/[^/]+$').hasMatch(uri.path)) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> _sendWithRetry(
    String method,
    Uri uri, {
    Object? body,
    required bool authenticated,
    required int retries,
  }) async {
    NiarimApiException? lastError;
    var transientAttempts = 0;
    var authRetryUsed = false;

    while (true) {
      try {
        return await _sendOnce(method, uri, body: body, auth: authenticated);
      } on NiarimApiException catch (e) {
        if (authenticated &&
            e.isUnauthorized &&
            !authRetryUsed &&
            _canRetryUnauthorized(method, uri)) {
          authRetryUsed = true;
          lastError = e;
          continue;
        }

        if (!e.isNetworkError && !e.isServerError) rethrow;
        lastError = e;
        if (transientAttempts >= retries) break;
        transientAttempts++;
        await Future<void>.delayed(retryBackoff * transientAttempts);
      }
    }
    throw lastError;
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
    final raw = response.bodyBytes.isEmpty
        ? ''
        : utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic>? json;
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
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
