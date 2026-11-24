import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_notice.dart';
import '../../services/settings_service.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/responsive.dart';
import '../../widgets/grouped_sheet.dart';

class CommunityNotificationSettingsScreen extends StatelessWidget {
  const CommunityNotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(devicePushLabel(l10n))),
      body: desktopCentered(
        context,
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // ほかの設定の画面と同じ欄に収める（以前は欄が無く、1つ目の
            // スイッチが上部バーのすぐ下に詰まっていた）。種類ごとの通知は
            // この端末の通知がオンのときだけ切り替えられる。
            GroupedSheet(
              children: [
                SwitchListTile(
                  key: const Key('pushNotificationsOnDevice'),
                  title: Text(devicePushLabel(l10n)),
                  subtitle: Text(
                    devicePushDescription(l10n),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  value: settings.pushNotificationsEnabled,
                  onChanged: settings.setPushNotificationsEnabled,
                ),
                SwitchListTile(
                  key: ValueKey(
                    CommunityPushCategory.publication.preferenceKey,
                  ),
                  title: Text(publicationPushLabel(l10n)),
                  value: settings.pushEnabledFor(
                    CommunityPushCategory.publication,
                  ),
                  onChanged: settings.pushNotificationsEnabled
                      ? (value) => settings.setPushCategory(
                          CommunityPushCategory.publication,
                          value,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
