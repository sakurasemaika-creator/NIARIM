import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Uploads a chosen JPEG/PNG thumbnail to the video's own YouTube channel.
/// The user-provided OAuth youtube.upload token never reaches the NIARIM API.
class YoutubeThumbnailService {
  YoutubeThumbnailService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

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
