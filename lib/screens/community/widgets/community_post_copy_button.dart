import 'dart:convert';

import 'package:flutter/material.dart';

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

/// One-tap form-to-form copy button, updated when the source text changes.
class CommunityPostCopyButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: source,
      builder: (context, value, _) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: enabled && value.text.isNotEmpty
              ? () {
                  final error = copyCommunityFieldText(
                    source: source,
                    destination: destination,
                    maxLength: maxLength,
                    youtubeDescription: youtubeDescription,
                  );
                  if (error != null) onError(error, maxLength);
                }
              : null,
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(label),
        ),
      ),
    );
  }
}
