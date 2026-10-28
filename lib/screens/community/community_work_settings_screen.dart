import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';
import 'community_error_text.dart';

/// Per-work owner settings. The YouTube editor is an external destination;
/// NIARIM visibility and AI disclosure use the authenticated NIARIM API.
class CommunityWorkSettingsScreen extends StatefulWidget {
  const CommunityWorkSettingsScreen({
    super.key,
    required this.workId,
    this.youtubePrivacyStatus,
  });

  final String workId;
  final String? youtubePrivacyStatus;

  @override
  State<CommunityWorkSettingsScreen> createState() =>
      _CommunityWorkSettingsScreenState();
}

class _CommunityWorkSettingsScreenState
    extends State<CommunityWorkSettingsScreen> {
  bool _busy = false;

  void _showError(Object error) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.communityMyWorksOperationFailed(
        communityErrorText(l10n, error),
      )),
    ));
  }

  Future<void> _changeVisibility(CommunityWork work, bool published) async {
    if (_busy) return;
    if (published && widget.youtubePrivacyStatus == 'deleted') {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityMyWorksDeletedCannotPublish)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CommunityService>().setNiarimVisibility(
        work.id, published,
      );
    } on CommunityAccountChangedException {
      // The owner changed while this request was in flight.
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAiFlag(CommunityWork work, bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<CommunityService>().setAiImageVideoDisclosure(
        work.id, value,
      );
    } on CommunityAccountChangedException {
      // Do not apply a result to a new account.
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteWork(CommunityWork work) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityMyWorksDeleteConfirmTitle),
        content: Text(l10n.communityMyWorksDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('communityWorkSettingsConfirmDelete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<CommunityService>().deleteOwnWork(work.id);
      if (mounted) Navigator.pop(context, true);
    } on CommunityAccountChangedException {
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openYoutubeStudio(String videoId) async {
    final uri = Uri.parse(
      'https://studio.youtube.com/video/${Uri.encodeComponent(videoId)}/edit',
    );
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.of(context)!.communityMyWorksYoutubeOpenFailed,
          ),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          AppLocalizations.of(context)!.communityMyWorksYoutubeOpenFailed,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final service = context.watch<CommunityService>();
    final work = service.byId(widget.workId);
    final ownWork = work != null && service.isOwnWork(work);
    final cannotPublish = widget.youtubePrivacyStatus == 'deleted';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityMyWorksSettingsTitle)),
      body: desktopCentered(
        context,
        work == null
            ? Center(child: Text(l10n.communityEmptyState))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    work.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.communityYoutubeVideoIdLabel(work.id),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('communityWorkSettingsVisibility'),
                          title: Text(l10n.communityMyWorksPublishInNiarim),
                          subtitle: Text(
                            l10n.communityVisibilityCardTitle,
                          ),
                          value: work.isNiarimPublished,
                          onChanged: !ownWork || _busy ||
                                  (cannotPublish && !work.isNiarimPublished)
                              ? null
                              : (value) => _changeVisibility(work, value),
                        ),
                        const Divider(height: 1),
                        CheckboxListTile(
                          key: const Key('communityWorkSettingsAiFlag'),
                          title: Text(
                            l10n.communityContainsGenerativeAiImageVideo,
                          ),
                          subtitle: Text(
                            l10n.communityContainsGenerativeAiImageVideoHelp,
                          ),
                          value: work.containsGenerativeAiImageOrVideo,
                          onChanged: !ownWork || _busy
                              ? null
                              : (value) => _changeAiFlag(work, value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('communityWorkSettingsYoutubeStudio'),
                    onPressed: service.api == null || !ownWork
                        ? null
                        : () => _openYoutubeStudio(work.id),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.communityMyWorksOpenYoutubeStudio),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.communityMyWorksYoutubeStudioHelp,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    key: const Key('communityWorkSettingsDelete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                    ),
                    onPressed: !ownWork || _busy
                        ? null
                        : () => _deleteWork(work),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.communityMyWorksDeleteNiarim),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
