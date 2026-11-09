import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/community_work_metadata_labels.dart';

/// Copying is local to the post form; it never updates YouTube or NIARIM
/// until the user explicitly submits the form.
enum CommunityFieldCopyError { tooLong, invalidYoutubeDescription }

/// Replaces the destination with the full source text, without truncation.
/// The destination remains untouched if its input constraints are violated.
CommunityFieldCopyError? copyCommunityFieldText({
  required TextEditingController source,
  required TextEditingController destination,
  required int maxLength,
  bool youtubeDescription = false,
}) {
  final text = source.text;
  if (text.length > maxLength) return CommunityFieldCopyError.tooLong;
  if (youtubeDescription &&
      (utf8.encode(text).length > 5000 ||
          text.contains('<') ||
          text.contains('>'))) {
    return CommunityFieldCopyError.invalidYoutubeDescription;
  }
  destination.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  return null;
}

/// Form-to-form copy button. Every press requires explicit confirmation.
class CommunityPostCopyButton extends StatefulWidget {
  const CommunityPostCopyButton({
    super.key,
    required this.source,
    required this.destination,
    required this.label,
    required this.maxLength,
    required this.enabled,
    required this.onError,
    this.youtubeDescription = false,
  });

  final TextEditingController source;
  final TextEditingController destination;
  final String label;
  final int maxLength;
  final bool enabled;
  final bool youtubeDescription;
  final void Function(CommunityFieldCopyError error, int maxLength) onError;

  @override
  State<CommunityPostCopyButton> createState() =>
      _CommunityPostCopyButtonState();
}

class _CommunityPostCopyButtonState extends State<CommunityPostCopyButton> {
  bool _confirmationOpen = false;

  Future<void> _confirmCopy() async {
    if (_confirmationOpen || !widget.enabled) return;
    _confirmationOpen = true;
    final originalSource = widget.source.text;
    final originalDestination = widget.destination.text;
    try {
      final labels = CommunityWorkMetadataLabels.of(context);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('communityPostCopyConfirmationDialog'),
          title: Text(labels.copyConfirmTitle),
          content: Text(labels.copyConfirmMessage),
          actions: [
            TextButton(
              key: const Key('communityPostCopyCancelButton'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(labels.copyCancel),
            ),
            FilledButton(
              key: const Key('communityPostCopyConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(labels.copyConfirmAction),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true || !widget.enabled) return;
      // If the form changed while the dialog was open, never overwrite it.
      if (widget.source.text != originalSource ||
          widget.destination.text != originalDestination) {
        return;
      }
      final error = copyCommunityFieldText(
        source: widget.source,
        destination: widget.destination,
        maxLength: widget.maxLength,
        youtubeDescription: widget.youtubeDescription,
      );
      if (error != null) widget.onError(error, widget.maxLength);
    } finally {
      _confirmationOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.source,
      builder: (context, value, _) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: widget.enabled && value.text.isNotEmpty
              ? _confirmCopy
              : null,
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
