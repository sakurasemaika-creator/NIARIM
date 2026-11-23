import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/tolerant_preferences.dart';
import 'keep_together_text.dart';

/// The version of the Terms of Service and the Privacy Policy that a user
/// agrees to. Raise it when either document changes in a way that users must
/// agree to again; the next purchase, sign-in or post then asks again.
const String kLegalDocumentsVersion = '2026-11-23';

/// The version the user last agreed to (saved on this device only).
const String kLegalConsentVersionKey = 'legal.consent.version';

/// When the user agreed (UTC, ISO 8601), saved with the version.
const String kLegalConsentAgreedAtKey = 'legal.consent.agreedAt';

/// Whether the user has agreed to the current version of both documents.
Future<bool> hasCurrentLegalConsent() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.readString(kLegalConsentVersionKey) ==
      kLegalDocumentsVersion;
}

/// Asks for agreement to the Terms of Service and the Privacy Policy before
/// a purchase, a Google sign-in or a post to the Work Plaza.
///
/// Drawing never asks. Once the user agrees, the version and the time are
/// saved on this device and the question is not asked again until
/// [kLegalDocumentsVersion] changes. Returns whether the action may continue:
/// false when the user cancels or the agreement could not be saved.
Future<bool> ensureLegalConsent(BuildContext context) async {
  final preferences = await SharedPreferences.getInstance();
  if (preferences.readString(kLegalConsentVersionKey) ==
      kLegalDocumentsVersion) {
    return true;
  }
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (_) => const LegalConsentDialog(),
  );
  if (agreed != true) return false;
  final agreedAt = DateTime.now().toUtc().toIso8601String();
  // The time is written first, so a saved version always has its time.
  return await preferences.setString(kLegalConsentAgreedAtKey, agreedAt) &&
      await preferences.setString(
        kLegalConsentVersionKey,
        kLegalDocumentsVersion,
      );
}

/// The question itself: what is asked and why, links to read both
/// documents, and "Cancel" / "Agree and continue".
class LegalConsentDialog extends StatelessWidget {
  const LegalConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.maybeOf(context);
    return AlertDialog(
      key: const Key('legalConsentDialog'),
      title: Text(l10n.legalConsentTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          messageText(l10n.legalConsentBody),
          if (router != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('legalConsentReadTerms'),
              onPressed: () => router.push('/settings/license'),
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.legalConsentReadTerms),
            ),
            TextButton.icon(
              key: const Key('legalConsentReadPrivacy'),
              onPressed: () => router.push('/settings/privacy-policy'),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(l10n.legalConsentReadPrivacy),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('legalConsentCancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('legalConsentAgree'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.legalConsentAgree),
        ),
      ],
    );
  }
}
