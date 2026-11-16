import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_notice.dart';
import '../../services/settings_service.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/responsive.dart';

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
          children: [
            SwitchListTile(
              key: const Key('pushNotificationsOnDevice'),
              title: Text(devicePushLabel(l10n)),
              subtitle: Text(devicePushDescription(l10n)),
              value: settings.pushNotificationsEnabled,
              onChanged: settings.setPushNotificationsEnabled,
            ),
            const Divider(),
            for (final category in CommunityPushCategory.values)
              SwitchListTile(
                key: ValueKey(category.preferenceKey),
                title: Text(communityPushCategoryLabel(l10n, category)),
                value: settings.pushEnabledFor(category),
                onChanged: settings.pushNotificationsEnabled
                    ? (value) => settings.setPushCategory(category, value)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
