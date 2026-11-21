import '../l10n/app_localizations.dart';

/// 制作時間[totalSeconds]の表記。プロジェクト詳細・作品広場・テーマの
/// 見本一覧で同じ文にする（新規作成の長さと同じ文：「6時間40分」
/// 「6h 40m」「6 h 40 min」）。
///
/// ちょうどの時間は分を書かない（「1時間0分」ではなく「1時間」）。0より長く
/// 1分に満たないときは1分、0以下は0分。
String workTimeLabel(AppLocalizations l10n, int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = seconds ~/ 3600;
  var minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    if (seconds > 0 && minutes == 0) minutes = 1;
    return l10n.newProjectDurationM(minutes);
  }
  return minutes == 0
      ? l10n.newProjectDurationH(hours)
      : l10n.newProjectDurationHm(hours, minutes);
}
