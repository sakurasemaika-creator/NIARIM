import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// QRコードで共有されたテキスト（[QrShareDialog]が表示したペイロード）を
/// 貼り付けて取り込むダイアログ。標準カメラアプリ等でQRコードを
/// スキャン・コピーした文字列をこの画面へ貼り付けてもらう想定。
/// [onImport]が取り込み処理（JSONのパース・Serviceへの登録）を行い、
/// 成功すればtrueを返す（失敗時はfalseを返すか例外を投げる。呼び出し側で
/// エラー表示する）。
class QrImportDialog extends StatefulWidget {
  final String title;
  final Future<bool> Function(String text) onImport;

  const QrImportDialog({
    super.key,
    required this.title,
    required this.onImport,
  });

  @override
  State<QrImportDialog> createState() => _QrImportDialogState();
}

class _QrImportDialogState extends State<QrImportDialog> {
  final _controller = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _controller.text = data!.text!);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final ok = await widget.onImport(text);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = l10n.qrImportFailedError);
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.qrImportFailedError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.qrImportHint, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.qrImportFieldHint,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_outlined),
                  tooltip: l10n.qrImportPasteButton,
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _submit,
          child: _isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.qrImportSubmitButton),
        ),
      ],
    );
  }
}
