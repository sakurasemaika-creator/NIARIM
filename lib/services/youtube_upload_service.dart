import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// YouTube Data API `videos.insert` のresumable upload結果。
class YoutubeUploadResult {
  const YoutubeUploadResult({required this.videoId});

  /// YouTubeが発行した一意の動画ID。この値をNIARIMのworkIdとしてそのまま使う。
  final String videoId;
}

typedef YoutubeUploadProgress =
    void Function(int uploadedBytes, int totalBytes);

/// YouTube Data API v3へ動画を直接アップロードするクライアント。
///
/// Lambdaを動画中継に使わず、端末→YouTubeへ直接送る。大きい動画をRAMへ
/// 全読み込みせず、8MiB（256KiBの整数倍）ずつresumable sessionへPUTする。
/// 通信断や5xxではセッションへ現在位置を問い合わせ、YouTube側で受信済みの
/// byte位置から再開する。
class YoutubeUploadService {
  YoutubeUploadService({http.Client? httpClient, this.maxRetries = 5})
    : _http = httpClient ?? http.Client();

  static final Uri _createVideoUri = Uri.parse(
    'https://www.googleapis.com/upload/youtube/v3/videos'
    '?uploadType=resumable&part=snippet,status',
  );

  static const int defaultChunkSize = 8 * 1024 * 1024;

  final http.Client _http;
  final int maxRetries;

  /// [accessToken] はGoogle認証IDトークンではなく、
  /// `https://www.googleapis.com/auth/youtube.upload` のOAuthアクセストークン。
  Future<YoutubeUploadResult> uploadVideo({
    required File file,
    required String accessToken,
    required String title,
    String description = '',
    List<String> tags = const <String>[],
    String privacyStatus = 'private',
    String? mimeType,
    YoutubeUploadProgress? onProgress,
    int chunkSize = defaultChunkSize,
  }) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', '空です');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '空です');
    }
    if (!_validPrivacyStatuses.contains(privacyStatus)) {
      throw ArgumentError.value(
        privacyStatus,
        'privacyStatus',
        'public / unlisted / private のいずれかにしてください',
      );
    }
    if (chunkSize <= 0 || chunkSize % (256 * 1024) != 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', '256KiBの正の整数倍にしてください');
    }
    if (!await file.exists()) {
      throw FileSystemException('アップロード対象ファイルが存在しません', file.path);
    }

    final totalBytes = await file.length();
    if (totalBytes <= 0) {
      throw FileSystemException('空ファイルはアップロードできません', file.path);
    }

    final uploadMimeType = mimeType ?? _mimeTypeFor(file.path);
    final sessionUri = await _startSession(
      accessToken: accessToken,
      totalBytes: totalBytes,
      mimeType: uploadMimeType,
      title: title.trim(),
      description: description,
      tags: tags,
      privacyStatus: privacyStatus,
    );

    final handle = await file.open(mode: FileMode.read);
    try {
      var offset = 0;
      var retry = 0;
      onProgress?.call(0, totalBytes);

      while (offset < totalBytes) {
        await handle.setPosition(offset);
        final remaining = totalBytes - offset;
        final wanted = math.min(chunkSize, remaining);
        final bytes = await handle.read(wanted);
        if (bytes.isEmpty) {
          throw const YoutubeUploadException('動画ファイルを途中までしか読み込めませんでした');
        }

        try {
          final response = await _putChunk(
            sessionUri: sessionUri,
            accessToken: accessToken,
            bytes: bytes,
            start: offset,
            totalBytes: totalBytes,
            mimeType: uploadMimeType,
          );

          if (_isSuccess(response.statusCode)) {
            final id = _videoIdFrom(response);
            onProgress?.call(totalBytes, totalBytes);
            return YoutubeUploadResult(videoId: id);
          }

          if (response.statusCode == 308) {
            offset = _nextOffset(response, fallback: offset + bytes.length);
            retry = 0;
            onProgress?.call(offset, totalBytes);
            continue;
          }

          if (_isRetriable(response.statusCode)) {
            if (retry >= maxRetries) {
              throw YoutubeUploadException.fromResponse(response);
            }
            retry++;
            await _backoff(retry, response.headers['retry-after']);
            final status = await _queryStatus(
              sessionUri: sessionUri,
              accessToken: accessToken,
              totalBytes: totalBytes,
              fallback: offset,
            );
            if (status.videoId case final String id) {
              onProgress?.call(totalBytes, totalBytes);
              return YoutubeUploadResult(videoId: id);
            }
            offset = status.nextOffset;
            onProgress?.call(offset, totalBytes);
            continue;
          }

          throw YoutubeUploadException.fromResponse(response);
        } on YoutubeUploadException {
          rethrow;
        } on Object catch (error) {
          if (retry >= maxRetries) {
            throw YoutubeUploadException('YouTubeへの動画送信に失敗しました', cause: error);
          }
          retry++;
          await _backoff(retry, null);
          try {
            final status = await _queryStatus(
              sessionUri: sessionUri,
              accessToken: accessToken,
              totalBytes: totalBytes,
              fallback: offset,
            );
            if (status.videoId case final String id) {
              onProgress?.call(totalBytes, totalBytes);
              return YoutubeUploadResult(videoId: id);
            }
            offset = status.nextOffset;
            onProgress?.call(offset, totalBytes);
          } on Object {
            // 状態照会自体が一時的に失敗した場合は同じchunkを再送する。
          }
        }
      }
    } finally {
      await handle.close();
    }

    throw const YoutubeUploadException('YouTubeがアップロード完了レスポンスを返しませんでした');
  }

  Future<Uri> _startSession({
    required String accessToken,
    required int totalBytes,
    required String mimeType,
    required String title,
    required String description,
    required List<String> tags,
    required String privacyStatus,
  }) async {
    final request = http.Request('POST', _createVideoUri)
      ..headers.addAll(<String, String>{
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json; charset=UTF-8',
        'x-upload-content-length': '$totalBytes',
        'x-upload-content-type': mimeType,
      })
      ..body = jsonEncode(<String, Object>{
        'snippet': <String, Object>{
          'title': title,
          if (description.isNotEmpty) 'description': description,
          if (tags.isNotEmpty) 'tags': tags,
        },
        'status': <String, Object>{'privacyStatus': privacyStatus},
      });

    final response = await http.Response.fromStream(await _http.send(request));
    if (!_isSuccess(response.statusCode)) {
      throw YoutubeUploadException.fromResponse(response);
    }
    final location = response.headers['location'];
    if (location == null || location.isEmpty) {
      throw const YoutubeUploadException(
        'YouTubeがresumable upload URLを返しませんでした',
      );
    }
    final uri = Uri.tryParse(location);
    if (uri == null || uri.scheme != 'https') {
      throw const YoutubeUploadException('YouTubeが不正なupload URLを返しました');
    }
    return uri;
  }

  Future<http.Response> _putChunk({
    required Uri sessionUri,
    required String accessToken,
    required List<int> bytes,
    required int start,
    required int totalBytes,
    required String mimeType,
  }) async {
    final end = start + bytes.length - 1;
    final request = http.Request('PUT', sessionUri)
      ..headers.addAll(<String, String>{
        'authorization': 'Bearer $accessToken',
        'content-type': mimeType,
        'content-range': 'bytes $start-$end/$totalBytes',
      })
      ..bodyBytes = bytes;
    return http.Response.fromStream(await _http.send(request));
  }

  /// `Content-Range: bytes */total` で現在位置を照会する。
  /// 308なら次に送るbyte位置、既に完了済みなら2xxのvideo resourceから
  /// videoIdを返す。最終chunkのレスポンスだけ端末へ届かなかった場合でも、
  /// 同じ動画を二重アップロードせず完了扱いへ復旧できる。
  Future<_YoutubeUploadStatus> _queryStatus({
    required Uri sessionUri,
    required String accessToken,
    required int totalBytes,
    required int fallback,
  }) async {
    final request = http.Request('PUT', sessionUri)
      ..headers.addAll(<String, String>{
        'authorization': 'Bearer $accessToken',
        'content-length': '0',
        'content-range': 'bytes */$totalBytes',
      });
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 308) {
      return _YoutubeUploadStatus(
        nextOffset: _nextOffset(response, fallback: fallback),
      );
    }
    if (_isSuccess(response.statusCode)) {
      return _YoutubeUploadStatus(
        nextOffset: totalBytes,
        videoId: _videoIdFrom(response),
      );
    }
    if (_isRetriable(response.statusCode)) {
      return _YoutubeUploadStatus(nextOffset: fallback);
    }
    throw YoutubeUploadException.fromResponse(response);
  }

  int _nextOffset(http.Response response, {required int fallback}) {
    final range = response.headers['range'];
    if (range == null || range.isEmpty) return fallback;
    final match = RegExp(r'(?:bytes=)?\d+-(\d+)').firstMatch(range);
    final lastByte = int.tryParse(match?.group(1) ?? '');
    return lastByte == null ? fallback : lastByte + 1;
  }

  String _videoIdFrom(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id'];
        if (id is String && id.isNotEmpty) return id;
      }
    } on Object {
      // 下の共通エラーへ落とす。
    }
    throw const YoutubeUploadException('YouTubeの完了レスポンスにvideoIdがありません');
  }

  Future<void> _backoff(int retry, String? retryAfter) async {
    final serverSeconds = int.tryParse(retryAfter ?? '');
    final seconds = serverSeconds ?? math.min(1 << (retry - 1), 16);
    await Future<void>.delayed(Duration(seconds: seconds));
  }

  static bool _isSuccess(int status) => status >= 200 && status < 300;
  static bool _isRetriable(int status) =>
      status == 408 || status == 429 || (status >= 500 && status < 600);

  static const Set<String> _validPrivacyStatuses = <String>{
    'public',
    'unlisted',
    'private',
  };

  static String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'application/octet-stream';
  }

  void close() => _http.close();
}

class _YoutubeUploadStatus {
  const _YoutubeUploadStatus({required this.nextOffset, this.videoId});

  final int nextOffset;
  final String? videoId;
}

class YoutubeUploadException implements Exception {
  const YoutubeUploadException(this.message, {this.statusCode, this.cause});

  factory YoutubeUploadException.fromResponse(http.Response response) {
    String? youtubeMessage;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          youtubeMessage = error['message'] as String?;
        }
      }
    } on Object {
      // JSONでなければstatusだけで返す。
    }
    return YoutubeUploadException(
      youtubeMessage ?? 'YouTube APIがエラーを返しました',
      statusCode: response.statusCode,
    );
  }

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => statusCode == null
      ? 'YoutubeUploadException: $message'
      : 'YoutubeUploadException($statusCode): $message';
}
