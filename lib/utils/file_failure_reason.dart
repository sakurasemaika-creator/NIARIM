import 'dart:io';

import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'app_error_reporter.dart';

/// 書き出し・読み込み・保存の失敗の理由を、利用者へ見せる文にする。
///
/// 例外の文そのもの（`FileSystemException: Cannot open file, path = …`・
/// `FormatException: Unexpected character …`）は出さない。開発者向けの英語で、
/// 端末のパスや内部の型の名前を含み、利用者には次に何をすればよいか分から
/// なかった（DISC069）。元の例外は「エラーの記録」に残す。
String fileFailureReason(
  AppLocalizations l10n,
  Object error, [
  StackTrace? stackTrace,
]) {
  AppErrorReporter.record(error, stackTrace ?? StackTrace.current);
  if (error is FileSystemException) return l10n.fileFailureReasonAccess;
  if (error is FormatException || error is TypeError) {
    return l10n.fileFailureReasonFormat;
  }
  if (error is UnimplementedError ||
      error is UnsupportedError ||
      error is MissingPluginException) {
    return l10n.communityErrorUnsupported;
  }
  return l10n.fileFailureReasonOther;
}
