// ダイアログ・知らせ・作品広場の画面に残っていた日本語だけ・日本語と英語だけの
// 文をARBへ移したことの見張り（ホーム以外）。実際のウィジェットを日本語以外で
// 組み立て、その言語の文が出ることを確かめる。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_following_list_screen.dart';
import 'package:niarim/screens/community/widgets/community_youtube_player.dart';
import 'package:niarim/screens/settings/font_catalog_tab.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shared_asset_card_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localized(String language, Widget home) => MaterialApp(
  locale: localeFromLanguageCode(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

CommunityService _emptyCommunity() {
  final service = CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'following': <Object>[], 'works': <Object>[]}),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
        tokenProvider: () async => 'test',
      ),
    ),
  );
  service.setCurrentUserId('self');
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (language, title, empty) in const [
    ('es', 'Siguiendo', 'Todavía no sigues a nadie'),
    ('zh_Hant', '追蹤', '還沒有追蹤任何人'),
  ]) {
    testWidgets('$language: 作品広場のフォロー中の一覧（見出し・空の表示）', (tester) async {
      final service = _emptyCommunity();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => PremiumService()),
          ],
          child: _localized(language, const CommunityFollowingListScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(title)),
        findsOneWidget,
      );
      expect(find.text(empty), findsOneWidget);
    });
  }

  testWidgets('fr: 作品広場の埋め込みのプレーヤー（動画が結び付いていない）', (tester) async {
    await tester.pumpWidget(
      _localized(
        'fr',
        const Scaffold(
          body: CommunityYoutubePlayer(videoId: '', playing: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Aucune vidéo YouTube n’est associée'), findsOneWidget);
  });

  testWidgets('ko: ブラシ・トーン・スタンプの共有カードのメニュー', (tester) async {
    late String label;
    await tester.pumpWidget(
      _localized(
        'ko',
        Builder(
          builder: (context) {
            label = SharedAssetCardService.exportMenuLabel(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(label, '공유 카드 내보내기');
  });

  testWidgets('es: フォントのダウンロードの失敗の知らせ', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _localized(
        'es',
        Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      fontDownloadFailureText(
        l10n,
        const FontDownloadException(FontDownloadFailure.network),
      ),
      'No se puede conectar a la red.',
    );
    expect(
      fontDownloadFailureText(
        l10n,
        const FontDownloadException(FontDownloadFailure.corrupted),
      ),
      'El archivo de la fuente está dañado.',
    );
  });
}
