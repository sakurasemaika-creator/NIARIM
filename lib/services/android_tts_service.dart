import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AndroidTtsVoice {
  const AndroidTtsVoice({
    required this.name,
    required this.locale,
    required this.quality,
  });

  final String name;
  final String locale;
  final int quality;

  factory AndroidTtsVoice.fromMap(Map<Object?, Object?> map) =>
      AndroidTtsVoice(
        name: map['name'] as String,
        locale: map['locale'] as String? ?? '',
        quality: map['quality'] as int? ?? 0,
      );

  String get displayName => '$locale · $name';
}

/// Calls Android's installed offline text-to-speech engine; no voice model is bundled.
class AndroidTtsService {
  AndroidTtsService._();
  static final AndroidTtsService instance = AndroidTtsService._();
  static const MethodChannel _channel =
      MethodChannel('com.niarim.niarim/text_to_speech');

  Future<void> openVoiceSettings() async {
    await _channel.invokeMethod<bool>('openVoiceSettings');
  }

  Future<List<AndroidTtsVoice>> offlineVoices() async {
    final raw = await _channel.invokeMethod<List<Object?>>('offlineVoices');
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(AndroidTtsVoice.fromMap)
        .toList(growable: false);
  }

  Future<File> synthesizeToFile({
    required String text,
    required AndroidTtsVoice voice,
    double rate = 1.0,
    double pitch = 1.0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text');
    if (trimmed.length > 3500) throw ArgumentError('Text is too long.');
    final temp = await getTemporaryDirectory();
    final output = File(temp.path + '/niarim_tts_' +
        DateTime.now().microsecondsSinceEpoch.toString() + '.wav');
    await output.parent.create(recursive: true);
    final path = await _channel.invokeMethod<String>('synthesizeToFile', {
      'text': trimmed,
      'voiceName': voice.name,
      'rate': rate.clamp(0.5, 2.0),
      'pitch': pitch.clamp(0.5, 2.0),
      'outputPath': output.path,
    });
    final file = File(path ?? output.path);
    if (!await file.exists() || await file.length() <= 44) {
      throw StateError('The TTS engine did not create a valid WAV file.');
    }
    return file;
  }
}
