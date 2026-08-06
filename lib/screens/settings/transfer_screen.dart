import 'package:flutter/material.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final Map<String, bool> _items = {
    '設定': true,
    '素材': true,
    'ブラシ': true,
    'プリセット': true,
    'UIテーマ': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('引き継ぎ（.miratra）')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: _items.keys.map((key) {
                return CheckboxListTile(
                  title: Text(key),
                  value: _items[key],
                  onChanged: (v) => setState(() => _items[key] = v!),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _items.updateAll((_, __) => true)),
                  child: const Text('全選択'),
                ),
                TextButton(
                  onPressed: () => setState(() => _items.updateAll((_, __) => false)),
                  child: const Text('全解除'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _items.values.any((v) => v) ? _export : null,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('書き出し'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _export() {
    // TODO: Export .miratra file with selected items
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('.miratraファイルを書き出しました')),
    );
  }
}
