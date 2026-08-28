import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';

/// QRコードの信頼性が確保できるとみなす文字数のおおよその上限。
/// QRコードの実容量自体は数千文字まで確保できるが、モジュール数が
/// 増えるほど1マスが小さくなり、一般的なスマートフォンのカメラで
/// スキャンしづらくなる。パレット・ワークスペース設定等のバイナリ資産を
/// 持たない小さなJSON設定のみをQR共有の対象とし、この上限を超える場合は
/// ファイル共有（既存の`SharePlus`によるファイル共有）へ誘導する。
const int kQrShareSafeCharLimit = 900;

/// テキストペイロード（設定のJSON文字列等）をQRコードとして表示する
/// ダイアログ。読み取り側は標準カメラアプリ等でスキャンした文字列を
/// コピーし、[QrImportDialog]（または同等の貼り付け欄）へ貼り付けて
/// 取り込む想定（アプリ内にカメラスキャン機能は持たない。標準カメラ
/// アプリで十分にQR読み取り→コピーができるため、独自スキャナー実装は
/// 見送った）。
class QrShareDialog extends StatelessWidget {
  final String title;
  final String payload;

  const QrShareDialog({super.key, required this.title, required this.payload});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.qrShareHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: payload));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.qrShareCopiedSnackbar)),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: Text(l10n.qrShareCopyButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
