import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/save_tree_service.dart';
import '../../../widgets/keep_together_text.dart';

/// いちばん大きい番号のスロットの題を、語と番号をつないで1行に並べた幅
/// （[context]の書式に[style]を重ね、文字の大きさで）。
///
/// スロットの一覧のカードで、題（語と番号を1つのかたまりにした
/// `KeepTogetherText`）をサムネイルの横に置くか（`ActionBesideOrBelow`の
/// `minTextWidth`）を決める。どのスロットも同じ並べ方になるよう、いちばん
/// 広い題の幅で決める（保存の管理の画面・セーブツリーの画面のスロットの表示）。
double widestSlotTitleWidth(BuildContext context, TextStyle style) {
  final label = AppLocalizations.of(
    context,
  )!.saveTreeSlotLabel(context.read<SaveTreeService>().slotMax);
  final painter = TextPainter(
    text: KeepTogetherText(
      label,
      keep: [label],
    ).joinedSpan(DefaultTextStyle.of(context).style.merge(style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
