import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/youtube_thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('niarim_thumb_'));
  tearDown(() => directory.deleteSync(recursive: true));

  test("sets only the authenticated user's selected JPEG or PNG", () async {
    final image = File('${directory.path}/poster.png');
    await image.writeAsBytes([137, 80, 78, 71, 1, 2, 3]);
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.host, 'www.googleapis.com');
      expect(request.url.path, '/upload/youtube/v3/thumbnails/set');
      expect(request.url.queryParameters['videoId'], 'abcdefghijk');
      expect(request.url.queryParameters['uploadType'], 'media');
      expect(request.headers['authorization'], 'Bearer accessToken');
      expect(request.headers['content-type'], 'image/png');
      expect(request.bodyBytes, await image.readAsBytes());
      return http.Response('{"items":[]}', 200);
    });
    final uploader = YoutubeThumbnailService(client: client);
    await uploader.setThumbnail(
      file: image,
      videoId: 'abcdefghijk',
      accessToken: 'accessToken',
    );
    uploader.close();
  });

  test('rejects an unsupported thumbnail without contacting YouTube', () async {
    final image = File('${directory.path}/image.gif');
    await image.writeAsBytes([1, 2, 3]);
    final uploader = YoutubeThumbnailService(
      client: MockClient((_) async => throw StateError('must never be sent')),
    );
    await expectLater(
      uploader.setThumbnail(
        file: image,
        videoId: 'abcdefghijk',
        accessToken: 'token',
      ),
      throwsArgumentError,
    );
    uploader.close();
  });

  test('surfaces YouTube channel thumbnail permission errors', () async {
    final image = File('${directory.path}/poster.jpg');
    await image.writeAsBytes([1, 2, 3]);
    final uploader = YoutubeThumbnailService(
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"thumbnail permission denied"}}',
          403,
        ),
      ),
    );
    await expectLater(
      uploader.setThumbnail(
        file: image,
        videoId: 'abcdefghijk',
        accessToken: 'token',
      ),
      throwsA(
        isA<YoutubeThumbnailException>().having(
          (e) => e.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    uploader.close();
  });
  test('Shorts processing is confirmed before custom thumbnail upload', () async {
    var checks = 0;
    final uploader = YoutubeThumbnailService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/youtube/v3/videos');
        expect(request.url.queryParameters['part'], 'processingDetails');
        expect(request.url.queryParameters['id'], 'abcdefghijk');
        expect(request.headers['authorization'], 'Bearer owner-token');
        checks++;
        return http.Response(
          '{"items":[{"id":"abcdefghijk","processingDetails":'
          '{"processingStatus":"${checks < 3 ? 'processing' : 'succeeded'}"}}]}',
          200,
        );
      }),
    );
    await uploader.waitUntilProcessed(
      videoId: 'abcdefghijk',
      accessToken: 'owner-token',
      maxChecks: 3,
      pollInterval: Duration.zero,
    );
    expect(checks, 3);
    uploader.close();
  });

  test('Shorts never set a thumbnail while YouTube still processes the video', () async {
    var checks = 0;
    final uploader = YoutubeThumbnailService(
      client: MockClient((_) async {
        checks++;
        return http.Response(
          '{"items":[{"processingDetails":{"processingStatus":"processing"}}]}',
          200,
        );
      }),
    );
    await expectLater(
      uploader.waitUntilProcessed(
        videoId: 'abcdefghijk',
        accessToken: 'owner-token',
        maxChecks: 2,
        pollInterval: Duration.zero,
      ),
      throwsA(isA<YoutubeThumbnailException>()),
    );
    expect(checks, 2);
    uploader.close();
  });

  test('Shorts reject terminal video processing failures', () async {
    final uploader = YoutubeThumbnailService(
      client: MockClient(
        (_) async => http.Response(
          '{"items":[{"processingDetails":{"processingStatus":"failed"}}]}',
          200,
        ),
      ),
    );
    await expectLater(
      uploader.waitUntilProcessed(
        videoId: 'abcdefghijk',
        accessToken: 'owner-token',
        pollInterval: Duration.zero,
      ),
      throwsA(isA<YoutubeThumbnailException>()),
    );
    uploader.close();
  });
}
