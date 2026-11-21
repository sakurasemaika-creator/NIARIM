import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 音声素材の波形画像（PNG）を生成・キャッシュするサービス。
///
/// タイムラインの音声トラックは従来プレーンな色帯だけを表示していたが、
/// どこに音が鳴っている箇所があるかが視覚的に分からず不便だった
/// （「音声素材はただのトラック表示だけでなく波形も表示するように」）。
///
/// 素材ファイル全体を1枚の波形画像として生成し、タイムライン上のクリップ帯の
/// 幅に合わせて表示する。動画コンテナを音声トラック素材として使う場合も、
/// 明示的に先頭の音声ストリームを選択して映像ストリームと競合させない。
///
/// 生成にはffmpegの`showwavespic`フィルターを使う。既存のエクスポート
/// 処理（export_engine.dart）と同じ`FFmpegKit.execute`呼び出しパターン
/// を踏襲し、新規パッケージの追加は行わない。
///
/// 生成結果はメモリ・ディスク（一時ディレクトリ）の二段でキャッシュし、
/// タイムラインのスクロールやドラッグ操作のたびにffmpegを再実行しない
/// ようにする。
class AudioWaveformService {
  AudioWaveformService._();

  static const int renderWidth = 800;
  static const int renderHeight = 120;

  static final Map<String, Uint8List?> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> getWaveform({
    required String filePath,
    String? cacheKey,
  }) {
    final key = cacheKey ?? filePath;
    if (_memoryCache.containsKey(key)) return Future.value(_memoryCache[key]);
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _generate(filePath, key);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  static Future<Uint8List?> _generate(String filePath, String key) async {
    try {
      final srcFile = File(filePath);
      if (!await srcFile.exists()) {
        _memoryCache[key] = null;
        return null;
      }
      final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final cacheDir = await _cacheDir();
      final outFile = File('${cacheDir.path}/wf_$safeKey.png');
      if (await outFile.exists() && await outFile.length() > 0) {
        final bytes = await outFile.readAsBytes();
        _memoryCache[key] = bytes;
        return bytes;
      }
      final session = await FFmpegKit.execute(
        '-y -i "${srcFile.path}" -filter_complex '
        '"[0:a:0]showwavespic=s=${renderWidth}x$renderHeight:colors=white[wave]" '
        '-map "[wave]" -frames:v 1 "${outFile.path}"',
      );
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc) || !await outFile.exists()) {
        _memoryCache[key] = null;
        return null;
      }
      final bytes = await outFile.readAsBytes();
      _memoryCache[key] = bytes;
      return bytes;
    } catch (_) {
      _memoryCache[key] = null;
      return null;
    }
  }

  static Future<Directory> _cacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/niarim_waveforms');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @visibleForTesting
  static void clearMemoryCacheForTest() {
    _memoryCache.clear();
    _inFlight.clear();
  }
}
