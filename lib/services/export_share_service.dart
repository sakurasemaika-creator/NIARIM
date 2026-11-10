import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

// Screens take the share types from here instead of importing share_plus.
export 'package:share_plus/share_plus.dart'
    show ShareResult, ShareResultStatus, XFile;

/// A single native share sheet for each saved file, including overlapping views.
abstract final class ExportShareService {
  static final _pending = <String, Future<ShareResult>>{};
  static final _running = <String>{};

  static Future<ShareResult> share(File file, {Rect? origin}) =>
      shareFiles([XFile(file.path)], key: file.absolute.path, origin: origin);

  /// Several files, or bytes that are not on disk, in one native share sheet.
  ///
  /// [key] names what is being shared: a call with the same key while that
  /// sheet is still open joins it instead of opening a second one.
  /// [fileNameOverrides] names files built from bytes (they have no name of
  /// their own outside the web).
  static Future<ShareResult> shareFiles(
    List<XFile> files, {
    required String key,
    List<String>? fileNameOverrides,
    Rect? origin,
  }) {
    final previous = _pending[key];
    if (previous != null) return previous;
    late final Future<ShareResult> operation;
    operation =
        Future<ShareResult>.sync(
          () => SharePlus.instance.share(
            ShareParams(
              files: files,
              fileNameOverrides: fileNameOverrides,
              sharePositionOrigin: origin,
            ),
          ),
        ).whenComplete(() {
          if (identical(_pending[key], operation)) _pending.remove(key);
        });
    _pending[key] = operation;
    return operation;
  }

  /// Whether a flow started with [runExclusive] for [key] is still running.
  static bool isRunning(String key) => _running.contains(key);

  /// Runs one write-then-share flow for [key] at a time.
  ///
  /// A second activation while the first is still writing its file or showing
  /// its share sheet does nothing and returns false, so the same file is never
  /// written by two flows at once.
  static Future<bool> runExclusive(
    String key,
    Future<void> Function() flow,
  ) async {
    if (!_running.add(key)) return false;
    try {
      await flow();
      return true;
    } finally {
      _running.remove(key);
    }
  }
}
