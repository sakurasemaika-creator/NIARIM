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

  Future<void> _editTag(CommunityWork work, {String? original}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<CommunityService>();
    var entered = original ?? '';
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(original == null
            ? l10n.communityAddTagDialogTitle
            : l10n.communityWorkEditTag),
        content: TextFormField(
          key: const Key('communityWorkTagInput'),
          autofocus: true,
          initialValue: entered,
          maxLength: 30,
          decoration: InputDecoration(hintText: l10n.communityAddTagDialogHint),
          onChanged: (value) => entered = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('communityWorkTagSave'),
            onPressed: () => Navigator.pop(dialogContext, entered),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    final next = tag?.trim();
    if (!mounted || next == null || next.isEmpty || next == original) return;
    if (service.byId(work.id)?.tags.contains(next) == true) return;
    if (next.length > 30) return;
    if (original == null &&
        work.tags.length >= CommunityService.maxTagsPerWork) {
      _showError(StateError(l10n.communityErrorTagLimitExceeded(
          CommunityService.maxTagsPerWork)));
      return;
    }
    setState(() => _busy = true);
    try {
      // The existing API implements add/remove as separate, conditional
      // operations. Roll back the old tag if the replacement is rejected.
      if (original != null && await service.removeTag(work.id, original) != true) {
        _showError(service.lastError ?? StateError(l10n.communityWorkTagChangeFailed));
        return;
      }
      final added = await service.addTag(work.id, next);
      if (added != true) {
        if (original != null) await service.addTag(work.id, original);
        _showError(service.lastError ?? StateError(l10n.communityWorkTagChangeFailed));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeTag(CommunityWork work, String tag,
      {required bool remove}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = context.read<CommunityService>();
      final done = remove
          ? await service.removeTag(work.id, tag)
          : await service.toggleTagLock(work.id, tag);
      if (done != true && mounted) {
        _showError(service.lastError ??
            StateError(AppLocalizations.of(context)!.communityWorkTagChangeFailed));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.communityWorkTagsTitle,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(l10n.communityWorkTagsHint,
                              style: TextStyle(color: scheme.onSurfaceVariant,
                                  fontSize: 12)),
                          for (final tag in work.tags)
                            Row(
                              key: ValueKey('communityWorkTag-$tag'),
                              children: [
                                Expanded(
                                  child: InkWell(
                                    key: ValueKey('communityWorkTagText-$tag'),
                                    onTap: ownWork && !_busy &&
                                            !work.lockedTags.contains(tag)
                                        ? () => _editTag(work, original: tag)
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(tag,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('communityWorkTagEdit-$tag'),
                                  tooltip: l10n.commonEdit,
                                  onPressed: ownWork && !_busy &&
                                          !work.lockedTags.contains(tag)
                                      ? () => _editTag(work, original: tag)
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  key: ValueKey('communityWorkTagLock-$tag'),
                                  tooltip: work.lockedTags.contains(tag)
                                      ? l10n.communityTagUnlockTooltip
                                      : l10n.communityTagLockTooltip,
                                  onPressed: ownWork && !_busy
                                      ? () => _changeTag(work, tag, remove: false)
                                      : null,
                                  icon: Icon(work.lockedTags.contains(tag)
                                      ? Icons.lock
                                      : Icons.lock_open_outlined),
                                ),
                                IconButton(
                                  key: ValueKey('communityWorkTagDelete-$tag'),
                                  tooltip: l10n.communityRemoveTagTooltip,
                                  onPressed: ownWork && !_busy &&
                                          !work.lockedTags.contains(tag)
                                      ? () => _changeTag(work, tag, remove: true)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          TextButton.icon(
                            key: const Key('communityWorkTagAdd'),
                            onPressed: ownWork && !_busy &&
                                    work.tags.length < CommunityService.maxTagsPerWork
                                ? () => _editTag(work)
                                : null,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.communityAddTagButton),
                          ),
                        ],
                      ),
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
