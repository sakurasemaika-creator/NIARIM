import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import 'community_error_text.dart';

/// Waits for a work-plaza edit or toggle (a tag, a bookmark, a follow, a
/// repost...) and, when the server refused it or never received it (the
/// edit returns false; it has been undone by then), tells the viewer why.
/// Null (nothing to do) and true (done) say nothing.
Future<void> reportFailedCommunityEdit(
  BuildContext context,
  CommunityService service,
  Future<bool?> edit,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context)!;
  if (await edit != false) return;
  final error = service.lastError;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        error?.isUnauthorized ?? false
            ? l10n.communityEditSignInRequired
            // A refusal the server explains (tag limit, a concurrent
            // change...) says so; anything else asks to retry.
            : communityApiErrorCodeText(l10n, error?.code) ??
                  l10n.communityEditFailed,
      ),
    ),
  );
}
