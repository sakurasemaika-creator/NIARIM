import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/advertising_service.dart';

class ProgressDialog extends StatelessWidget {
  final String title;
  final double progress;
  final String? subtitle;

  const ProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdvertisingService>();

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('${(progress * 100).round()}%'),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (adService.shouldShowAds) ...[
            const SizedBox(height: 16),
            Container(
              width: 200,
              height: 200,
              color: Colors.grey[800],
              child: const Center(child: Text('SQUARE AD', style: TextStyle(color: Colors.grey))),
            ),
          ],
        ],
      ),
    );
  }
}
