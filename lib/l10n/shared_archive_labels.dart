import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';

/// Short labels for the received/created switch and native-file share action.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
abstract final class SharedArchiveLabels {
  static Map<String, String> of(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    return {
      'received': l10n.sharedArchiveReceived,
      'created': l10n.sharedArchiveCreated,
      'share': l10n.sharedArchiveShare,
      'empty': l10n.sharedArchiveEmpty,
    };
  }
}
