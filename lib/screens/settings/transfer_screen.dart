import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/miratra_serializer.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/brush_service.dart';
import '../../services/settings_service.dart';
import '../../services/stamp_service.dart';
import '../../services/theme_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

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
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('引き継ぎ（.miratra）'), actions: const [HelpButton()]),
      body: desktopCentered(context, Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('他の端末へ引き継ぐ項目を選択してください。',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Card(
                  child: Column(
                    children: [
                      for (final key in _items.keys) ...[
                        if (key != _items.keys.first) const Divider(height: 1),
                        CheckboxListTile(
                          title: Text(key),
                          value: _items[key],
                          onChanged: (v) => setState(() => _items[key] = v!),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: _isBusy ? null : _import,
                  child: const Text('読み込み'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isBusy ? null : () => setState(() => _items.updateAll((_, _) => true)),
                  child: const Text('全選択'),
                ),
                TextButton(
                  onPressed: _isBusy ? null : () => setState(() => _items.updateAll((_, _) => false)),
                  child: const Text('全解除'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (!_isBusy && _items.values.any((v) => v)) ? _export : null,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: const Text('書き出し'),
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      final file = await MiratraSerializer.export(
        selectedItems: _items,
        settings: context.read<SettingsService>(),
        brush: context.read<BrushService>(),
        tone: context.read<ToneService>(),
        stamp: context.read<StampService>(),
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('.miratraファイルを書き出しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('書き出しに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['miratra'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!mounted) return;
    setState(() => _isBusy = true);
    try {
      final data = await MiratraSerializer.load(result.files.first.path!);
      if (!mounted) return;
      MiratraSerializer.applyTo(
        data,
        settings: context.read<SettingsService>(),
        brush: context.read<BrushService>(),
        tone: context.read<ToneService>(),
        stamp: context.read<StampService>(),
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('.miratraファイルを読み込みました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
