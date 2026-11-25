import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_error_text.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';

/// The backend refuses posting and re-publishing for an account whose posting
/// is suspended after repeated violations, with the stable code
/// `POSTING_SUSPENDED` (backend/src/lib/moderation.ts). The app must say so in
/// every language and tell the user where to object, instead of the generic
/// "no permission" text for a 403.
void main() {
  const locales = {
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  for (final entry in locales.entries) {
    test('POSTING_SUSPENDED has its own message (${entry.key})', () {
      final l10n = lookupAppLocalizations(entry.value);
      const error = NiarimApiException(
        403,
        '規約に反する投稿が続いたため、作品広場への投稿を停止しています',
        code: 'POSTING_SUSPENDED',
      );
      final text = communityErrorText(l10n, error);
      expect(text, l10n.communityErrorPostingSuspended);
      expect(text, isNot(l10n.communityErrorForbidden));
      expect(text, contains('support@miranima-studio.com'));
    });
  }

  test('the terms explain suspension and objections in every language', () {
    for (final locale in locales.values) {
      final body = lookupAppLocalizations(locale).licenseTermsArt12Body;
      expect(body, contains('support@miranima-studio.com'));
    }
  });
}
