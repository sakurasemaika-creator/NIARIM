import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Uploads a chosen JPEG/PNG thumbnail to the video's own YouTube channel.
/// The user-provided OAuth youtube.upload token never reaches the NIARIM API.
class YoutubeThumbnailService {
  YoutubeThumbnailService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// The Shorts custom thumbnail must be sent after YouTube processing.
  /// Retain the uploaded video ID on timeout, so retries never upload twice.
  Future<void> waitUntilProcessed({
    required String videoId,
    required String accessToken,
    int maxChecks = 12,
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      throw ArgumentError('動画IDが不正です');
    }
    if (accessToken.isEmpty) {
      throw ArgumentError('YouTubeのアクセストークンがありません');
    }
    if (maxChecks < 1) {
      throw ArgumentError.value(maxChecks, 'maxChecks', '1以上を指定してください');
    }
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/videos', {
      'part': 'processingDetails',
      'id': videoId,
      'fields': 'items(id,processingDetails/processingStatus)',
    });
    for (var check = 0; check < maxChecks; check++) {
      if (check > 0) await Future<void>.delayed(pollInterval);
      final response = await _client.get(
        uri, headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode != 200) {
        throw YoutubeThumbnailException(
          'YouTubeの動画処理状態を確認できませんでした（HTTP ${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['items'] is! List) {
        throw const YoutubeThumbnailException('YouTubeの動画処理状態が不正です');
      }
      final items = decoded['items'] as List;
      if (items.isEmpty || items.first is! Map) continue;
      final video = items.first as Map;
      final details = video['processingDetails'];
      final status = details is Map ? details['processingStatus'] : null;
      if (status == 'succeeded') return;
      if (status == 'failed' || status == 'terminated') {
        throw const YoutubeThumbnailException(
          'YouTubeの動画処理が完了できませんでした。動画の状態を確認してください',
        );
      }
    }
    throw const YoutubeThumbnailException(
      'Shortsの処理がまだ完了していません。しばらくしてから投稿を再試行してください。動画は再アップロードされません',
    );
  }

  Future<void> setThumbnail({
    required File file,
    required String videoId,
    required String accessToken,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      throw ArgumentError('動画IDが不正です');
    }
    final path = file.path.toLowerCase();
    final type = path.endsWith('.png') ? 'image/png'
        : path.endsWith('.jpg') || path.endsWith('.jpeg') ? 'image/jpeg' : null;
    if (type == null) {
      throw ArgumentError('サムネイルはPNGまたはJPEGを選択してください');
    }
    final size = await file.length();
    // YouTube allows 50 MB, but cap local memory/traffic at a safer 10 MB.
    if (size == 0 || size > 10 * 1024 * 1024) {
      throw ArgumentError('サムネイル画像は10MB以内にしてください');
    }
    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/youtube/v3/thumbnails/set',
      {'videoId': videoId, 'uploadType': 'media'},
    );
    final request = http.StreamedRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = type
      ..contentLength = size;
    final responseFuture = _client.send(request);
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final response = await http.Response.fromStream(await responseFuture);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'サムネイルを設定できませんでした（HTTP ${response.statusCode}）';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final details = error['error'];
        if (details is Map && details['message'] is String) {
          message += ': ${details['message']}';
        }
      } on Object {
        // Keep a generic user-facing status. Never include OAuth credentials.
      }
      throw YoutubeThumbnailException(message, statusCode: response.statusCode);
    }
  }

  void close() => _client.close();
}

class YoutubeThumbnailException implements Exception {
  const YoutubeThumbnailException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
