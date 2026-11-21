import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/community_work_metadata_labels.dart';
import '../../../services/community_service.dart';

/// Reads one non-indexed NIARIM detail row when the work detail is opened.
class CommunityWorkDescription extends StatefulWidget {
  const CommunityWorkDescription({super.key, required this.workId});
  final String workId;

  @override
  State<CommunityWorkDescription> createState() =>
      _CommunityWorkDescriptionState();
}

class _CommunityWorkDescriptionState extends State<CommunityWorkDescription> {
  String? _description;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommunityWorkDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _description = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final requestedId = widget.workId;
    final api = context.read<CommunityService>().api;
    if (api == null) {
      if (mounted) setState(() => _description = '');
      return;
    }
    try {
      final result = await api.workMetadata(requestedId);
      if (!mounted || widget.workId != requestedId) return;
      setState(() => _description = result['description'] as String? ?? '');
    } catch (_) {
      if (!mounted || widget.workId != requestedId) return;
      setState(() {
        _failed = true;
        _description = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = CommunityWorkMetadataLabels.of(context);
    if (_description == null) return const SizedBox.shrink();
    if (_failed) {
      return TextButton(
        onPressed: () {
          setState(() {
            _description = null;
            _failed = false;
          });
          _load();
        },
        child: Text(labels.loadFailed),
      );
    }
    if (_description!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.description,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          SelectableText(_description!),
        ],
      ),
    );
  }
}
