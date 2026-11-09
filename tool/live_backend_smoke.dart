import 'dart:io';

import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_config.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';

/// Read-only live check using the very same API client shipped in Flutter.
///
/// Run with:
/// dart run --define=NIARIM_API_BASE_URL=https://YOUR_FUNCTION_URL/ \\
///   tool/live_backend_smoke.dart
///
/// This only reads public discovery, ranking and the authentication guard.
/// It NEVER submits a token, writes to DynamoDB or creates a work.
Future<void> main() async {
  const expectedHost =
      'ibjfhyoqvfanle62ltokgz6sry0fjqfh.lambda-url.ap-northeast-1.on.aws';

  if (!NiarimApiConfig.isConfigured) {
    throw StateError('NIARIM_API_BASE_URL is missing from the Dart define.');
  }
  final uri = Uri.tryParse(NiarimApiConfig.baseUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != expectedHost ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw StateError('The live test is restricted to the NIARIM dev API URL.');
  }

  final api = NiarimApiConfig.createApi();
  if (api == null) {
    throw StateError('Flutter API configuration did not create an API client.');
  }

  // The Flutter production parsing code must accept the live JSON contract.
  final latest = await api.latestWorksPage(limit: 5);
  if (latest.works.length > 5) {
    throw StateError('The live latest-works API exceeded the requested limit.');
  }
  for (final work in latest.works) {
    if (work.workId.isEmpty || work.title.isEmpty) {
      throw StateError('The latest-works API returned an invalid work.');
    }
  }
  stdout.writeln('PASS /works/latest: ${latest.works.length} work(s) parsed');

  final search = await api.latestWorksPage(
    query: '__niarim_live_smoke_tag_not_found__',
    tagMode: true,
    exact: true,
    limit: 5,
  );
  if (search.works.isNotEmpty) {
    throw StateError('Exact-match search unexpectedly returned results.');
  }
  stdout.writeln('PASS /works/latest?q=...&tagMode=true&exact=true');

  final ranking = await api.ranking(RankingPeriod.bookmarks);
  if (ranking.period != 'bookmarks' || ranking.works.length > 25) {
    throw StateError('The live bookmark ranking contract did not match.');
  }
  stdout.writeln(
    'PASS /ranking/bookmarks: ${ranking.works.length} work(s) parsed',
  );

  // A private user list must NOT become readable without an ID token.
  final guardClient = NiarimApiClient(
    baseUrl: NiarimApiConfig.baseUrl,
    maxGetRetries: 0,
  );
  try {
    try {
      await guardClient.getJson('/me/works', authenticated: true);
      throw StateError('SECURITY: anonymous GET /me/works was accepted.');
    } on NiarimApiException catch (e) {
      if (e.statusCode != 401) {
        throw StateError(
          'Expected HTTP 401 from /me/works; got ${e.statusCode}.',
        );
      }
      stdout.writeln('PASS /me/works: anonymous access rejected with HTTP 401');
    }
  } finally {
    guardClient.close();
  }

  stdout.writeln('PASS Flutter/Dart client → live NIARIM backend (read-only)');
}
