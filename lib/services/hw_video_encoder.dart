import 'package:flutter/services.dart';

/// 端末内蔵ハードウェアH.264エンコーダー（Android MediaCodec + MediaMuxer、
/// android/app側のネイティブ実装）の呼び出し（仕様書13：MP4書き出しで
/// FFmpeg/libx264（GPL）を使わないことでGPLコピーレフト・H.264特許
/// ロイヤリティの論点を回避する）。
class HardwareVideoEncoder {
  static const _channel = MethodChannel('com.miranima.miranima/hw_video_encoder');

  /// [framePaths]（表示順のPNGファイルパス一覧。同一パスを複数回指定すると
  /// 静止フレームの複製として扱われる）を指定[fps]でエンコードし、
  /// [outputPath]へMP4として書き出す。
  static Future<void> encodeMp4({
    required List<String> framePaths,
    required int fps,
    required int width,
    required int height,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('encodeMp4', {
      'framePaths': framePaths,
      'fps': fps,
      'width': width,
      'height': height,
      'outputPath': outputPath,
    });
  }
}
