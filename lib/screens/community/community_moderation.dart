import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/typing_dialog_inset.dart';

Future<void> reportCommunityContent(
  BuildContext context, {
  String? workId,
  String? authorId,
}) async {
  final service = context.read<CommunityService>();
  final api = service.api;
  final l10n = AppLocalizations.of(context)!;
  if (!service.isBackendConnected) {
    _showFeedback(context, l10n.communitySampleReportUnavailable);
    return;
  }
  if (!_canModerate(context, service)) return;
  final revision = service.accountRevision;
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => _CommunityReportDialog(
      title: authorId == null
          ? l10n.communityWorkDetailReportButton
          : l10n.communityReportAuthor,
    ),
  );
  if (reason == null ||
      !context.mounted ||
      revision != service.accountRevision) {
    return;
  }
  try {
    await api!.report(workId: workId, authorId: authorId, reason: reason);
    if (context.mounted && revision == service.accountRevision) {
      _showFeedback(context, l10n.communityReportSent);
    }
  } catch (_) {
    if (context.mounted && revision == service.accountRevision) {
      _showFeedback(context, l10n.communityModerationFailed);
    }
  }
}

Future<void> confirmCommunityBlock(
  BuildContext context,
  String authorId, {
  required bool blocked,
}) async {
  final service = context.read<CommunityService>();
  if (!_canModerate(context, service)) return;
  final l10n = AppLocalizations.of(context)!;
  final action = blocked
      ? l10n.communityBlockAuthor
      : l10n.communityUnblockAuthor;
  final revision = service.accountRevision;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(action),
      content: blocked ? Text(l10n.communityBlockPrivacyNotice) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  if (confirmed != true ||
      !context.mounted ||
      revision != service.accountRevision) {
    return;
  }
  try {
    await service.setAuthorBlocked(authorId, blocked);
    if (context.mounted) _showFeedback(context, l10n.communityModerationSaved);
  } on CommunityAccountChangedException {
    return;
  } catch (_) {
    if (context.mounted) _showFeedback(context, l10n.communityModerationFailed);
  }
}

Future<void> manageCommunityBlocks(BuildContext context) async {
  final service = context.read<CommunityService>();
  if (!_canModerate(context, service)) return;
  final l10n = AppLocalizations.of(context)!;
  final revision = service.accountRevision;
  try {
    final ids = await service.loadBlockedAuthors();
    if (!context.mounted || revision != service.accountRevision) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.communityBlockedUsers),
        scrollable: true,
        content: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final active = ids.where(service.isAuthorBlocked).toList();
            if (active.isEmpty) return Text(l10n.communityBlockedUsersEmpty);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in active)
                  ListTile(
                    title: Text(service.authorNameOf(id) ?? id),
                    trailing: IconButton(
                      tooltip: l10n.communityUnblockAuthor,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      onPressed: () =>
                          confirmCommunityBlock(context, id, blocked: false),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  } on CommunityAccountChangedException {
    return;
  } catch (_) {
    if (context.mounted && revision == service.accountRevision) {
      _showFeedback(context, l10n.communityModerationFailed);
    }
  }
}

bool _canModerate(BuildContext context, CommunityService service) {
  final l10n = AppLocalizations.of(context)!;
  if (service.api == null) {
    _showFeedback(context, l10n.communityModerationFailed);
    return false;
  }
  if (context.read<GoogleAuthService?>()?.account == null) {
    _showFeedback(context, l10n.communitySignInPromptTitle);
    return false;
  }
  return true;
}

void _showFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _CommunityReportDialog extends StatefulWidget {
  const _CommunityReportDialog({required this.title});
  final String title;

  @override
  State<_CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<_CommunityReportDialog> {
  String _reason = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      insetPadding: typingDialogInsetPadding(context),
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        decoration: InputDecoration(labelText: l10n.communityReportReason),
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        onChanged: (text) => setState(() => _reason = text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _reason.isEmpty || _reason.length > 1000
              ? null
              : () => Navigator.pop(context, _reason),
          child: Text(l10n.communityReportSend),
        ),
      ],
    );
  }
}
