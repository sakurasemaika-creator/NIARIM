import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/export_share_service.dart';
import '../utils/app_error_reporter.dart';

/// 共有できなかった理由を、利用者へ見せる文にする（OSの例外の文は出さない）。
/// この端末・OSに共有の仕組みが無いときと、それ以外の失敗を分ける。
String exportShareFailureText(AppLocalizations l10n, Object error) =>
    error is UnimplementedError ||
        error is UnsupportedError ||
        error is MissingPluginException
    ? l10n.communityErrorUnsupported
    : l10n.communityErrorGeneric;

/// 共有シートの出どころ（タブレットの吹き出しの位置）にする部品の矩形。
Rect? exportShareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize && !box.size.isEmpty
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
}

/// 書き出したファイルを共有し、できなかったときは画面下の通知で知らせる。
///
/// 上にダイアログが重なっていない画面から呼ぶこと（通知はダイアログの
/// 後ろに隠れる。ダイアログの中から共有するときは、その中に文を出す）。
Future<void> shareExportedFileWithNotice(
  BuildContext context,
  File file,
) async {
  // 共有の後は画面が無くなっていることがあるので、先に取っておく。
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final origin = exportShareOrigin(context);
  try {
    await ExportShareService.share(file, origin: origin);
  } catch (error, stackTrace) {
    AppErrorReporter.record(error, stackTrace);
    messenger?.showSnackBar(
      SnackBar(content: Text(exportShareFailureText(l10n, error))),
    );
  }
}
