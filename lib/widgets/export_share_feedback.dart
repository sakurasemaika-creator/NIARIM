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
/// 後ろに隠れる。ダイアログの中から共有するときは、その中に
/// [ExportShareNotice]で文を出す）。
Future<void> shareExportedFileWithNotice(BuildContext context, File file) =>
    shareFilesWithNotice(context, [XFile(file.path)], key: file.absolute.path);

/// 複数のファイル、またはファイルになっていないバイト列を1回で共有し、
/// できなかったときは画面下の通知で知らせる（[shareExportedFileWithNotice]と
/// 同じ決まり）。共有の結果を返し、できなかったときはnullを返す。
///
/// [key]は共有するものの名前で、同じ名前の共有シートが開いている間の
/// 二度目はそれに合流する。[fileNameOverrides]はバイト列から作るファイルの
/// 名前（付けないと拡張子が失われる）。
Future<ShareResult?> shareFilesWithNotice(
  BuildContext context,
  List<XFile> files, {
  required String key,
  List<String>? fileNameOverrides,
}) => ExportShareHandles.of(
  context,
).shareFiles(files, key: key, fileNameOverrides: fileNameOverrides);

/// 画面から先に取っておく、知らせる先・文言・共有シートの出どころ。
///
/// 共有の前に時間のかかる処理（共有ファイルの作成）があると、終わったときには
/// 始めた画面が無くなっていることがある。先に取っておけば、そのときも同じ
/// 決まりで知らせ、共有できる（黙って止めない）。
class ExportShareHandles {
  ExportShareHandles.of(BuildContext context)
    : messenger = ScaffoldMessenger.maybeOf(context),
      l10n = AppLocalizations.of(context)!,
      origin = exportShareOrigin(context);

  final ScaffoldMessengerState? messenger;
  final AppLocalizations l10n;
  final Rect? origin;

  /// 画面下の通知で知らせる。
  void tell(String message) {
    final messenger = this.messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// [shareFilesWithNotice]と同じ（共有の結果を返し、できなかったときは
  /// 知らせてnullを返す）。
  Future<ShareResult?> shareFiles(
    List<XFile> files, {
    required String key,
    List<String>? fileNameOverrides,
  }) async {
    try {
      return await ExportShareService.shareFiles(
        files,
        key: key,
        fileNameOverrides: fileNameOverrides,
        origin: origin,
      );
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      tell(exportShareFailureText(l10n, error));
      return null;
    }
  }

  /// 書き出したファイル1つを共有する（[shareExportedFileWithNotice]と同じ）。
  Future<ShareResult?> share(File file) =>
      shareFiles([XFile(file.path)], key: file.absolute.path);
}

/// ダイアログ・パネルの中から共有する。できなかったときは記録して、その中に
/// [ExportShareNotice]で出す文のもとになる例外を返す（できたらnull）。
Future<Object?> shareExportedFileCatching(
  BuildContext context,
  File file,
) async {
  try {
    await ExportShareService.share(file, origin: exportShareOrigin(context));
    return null;
  } catch (error, stackTrace) {
    AppErrorReporter.record(error, stackTrace);
    return error;
  }
}

/// [ExportShareNotice]を出した直後に呼ぶ（[noticeKey]はその知らせのkey）。
/// 低い画面・長い一覧では知らせが下に隠れるので、次のフレームで、見える所
/// まで送る（もう見えていれば動かさない）。
void revealExportShareNotice(GlobalKey noticeKey) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = noticeKey.currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(
      target,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });
}

/// 共有できなかったときの知らせを、その場（ダイアログ・パネルの中）に出す1行。
///
/// 文字の色はその面の文字色。色ではなく先頭の印と文で知らせ、読み上げへも
/// 伝える。次の共有を始めるときに消すこと。
class ExportShareNotice extends StatelessWidget {
  const ExportShareNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
