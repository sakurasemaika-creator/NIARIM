import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// 音声素材の波形サムネイルを生成・キャッシュするサービス。
/// FFmpeg の showwavespic フィルタを使い、透過 PNG としてキャッシュする。
class AudioWaveformService {
  AudioWaveformService._();

  static final Map<String, Uint8List?> _memoryCache = {};

  static Future<Uint8List?> generate({
    required String filePath,
    required String cacheKey,
    int width = 600,
    int height = 80,
  }) async {
    final renderWidth = width.clamp(1, 2000);
    final renderHeight = height.clamp(1, 500);
    final key = '${cacheKey}_${renderWidth}x$renderHeight';
    if (_memoryCache.containsKey(key)) return _memoryCache[key];

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
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/niarim_waveforms');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static void clearMemoryCache() => _memoryCache.clear();
}
