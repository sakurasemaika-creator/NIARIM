// 設定の画面に残っていた、言語コードで分けた手書きの表をARBへ移したことの
// 見張り。以前は繁体字が'zh'の行に入って簡体字になっていた。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (language, title, reset) in const [
    ('zh_Hant', '自動收起工具視窗', '重設工作區'),
    ('fr', 'Replier automatiquement les fenêtres d’outils', null),
  ]) {
    testWidgets('$language: PCレイアウトの設定の文', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 2000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsService(),
          child: MaterialApp(
            locale: localeFromLanguageCode(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PcWorkspaceLayoutSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(title), findsOneWidget);
      if (reset != null) expect(find.text(reset), findsOneWidget);
    });
  }
}
