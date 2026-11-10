import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// A single native share sheet for each saved file, including overlapping views.
abstract final class ExportShareService {
  static final _pending = <String, Future<ShareResult>>{};

  static Future<ShareResult> share(File file, {Rect? origin}) {
    final key = file.absolute.path;
    final previous = _pending[key];
    if (previous != null) return previous;
    late final Future<ShareResult> operation;
    operation =
        Future<ShareResult>.sync(
          () => SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
          ),
        ).whenComplete(() {
          if (identical(_pending[key], operation)) _pending.remove(key);
        });
    _pending[key] = operation;
    return operation;
  }
}
