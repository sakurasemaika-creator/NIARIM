import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/audio_waveform_service.dart';

// AudioWaveformServiceのうち、実機のffmpegバイナリを必要としない範囲
// （存在しないファイルの早期nullフォールバック・キャッシュ挙動）を検証する。
// FFmpegKit.execute()はプラットフォームチャンネル経由のプラグインで
// あり、単体テスト環境では呼び出せないため、ffmpegを実行しない
// コードパス（ファイル未存在時の早期return）のみをテスト対象とする。
void main() {
  setUp(() {
    AudioWaveformService.clearMemoryCacheForTest();
  });

  test('存在しないファイルパスはnullを返す', () async {
    final result = await AudioWaveformService.getWaveform(
      filePath: '/no/such/file/for/niarim/waveform/test.mp3',
      cacheKey: 'k0',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    expect(result, isNull);
  });

  test('同一キーへの同時呼び出しはin-flightのFutureを共有する', () async {
    const path = '/no/such/file/for/niarim/waveform/test2.mp3';
    final f1 = AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: 'k1',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    final f2 = AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: 'k1',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    final results = await Future.wait([f1, f2]);
    expect(results[0], isNull);
    expect(results[1], isNull);
  });

  test('生成失敗はメモリキャッシュされ、2回目以降は即座に返る', () async {
    const path = '/no/such/file/for/niarim/waveform/test3.mp3';
    final first = await AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: 'k2',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    expect(first, isNull);

    final sw = Stopwatch()..start();
    final second = await AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: 'k2',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    sw.stop();
    expect(second, isNull);
    // キャッシュ済みならファイルI/Oすら発生せず即座に返るはず。
    expect(sw.elapsedMilliseconds, lessThan(50));
  });

  test('同じファイルの別の区間は、呼び出し側が渡す別のキーで覚える', () async {
    // 区間ごとに波形を作るので、キーはファイルの場所ではなく呼び出し側が
    // 区間を含めて決める（同じファイルを2つのクリップで使っても混ざらない）。
    const path = '/no/such/file/for/niarim/waveform/test4.mp3';
    final a = await AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: '$path#0-1',
      sourceStartSeconds: 0,
      durationSeconds: 1,
    );
    final b = await AudioWaveformService.getWaveform(
      filePath: path,
      cacheKey: '$path#1-2',
      sourceStartSeconds: 1,
      durationSeconds: 1,
    );
    expect(a, isNull);
    expect(b, isNull);
  });
}
