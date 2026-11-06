import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/tips/tips_screen.dart' show allTipEntries;
import '../config/font_fallback.dart';
import 'ad_banner_mock_widget.dart';

/// 処理中ダイアログ（フィルター適用／動画書き出し／GIF生成／
/// 透過WebM生成／大量処理実行時に表示、プログレスバー下部に中型広告）。
/// 会員種別に関わらず、10秒おきにランダムでTipsを表示する。現在は
/// ダイアログ下部に配置確認用の中型レクタングル広告モックを表示する（広告を中間に挟むと
/// 視線の邪魔になりやすいため、プログレスバー→Tips→広告の順に配置。
/// 縦に並ぶ分、内容全体をスクロール可能にしている）。実広告への切替時は
/// [AdMediumRectangleMockWidget]だけを差し替える。
class ProgressDialog extends StatefulWidget {
  final String title;
  final double progress;
  final String? subtitle;
  // キャンセルボタン（誤タップ対応）。nullの場合は非表示
  // （キャンセルに対応していない処理からの呼び出しとの後方互換のため）。
  final VoidCallback? onCancel;
  // キャンセル要求後、実際に中断できないフェーズ（例：最終エンコード中）
  // であることをユーザーに伝えるための注記。
  final String? cancelHint;

  const ProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    this.subtitle,
    this.onCancel,
    this.cancelHint,
  });

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog> {
  Timer? _tipTimer;
  // Tips一覧はl10nに依存するがダイアログ表示中に言語が変わることはないため、
  // 毎buildで再構築せず一度だけ計算してキャッシュする（進捗更新のたびに
  // 高頻度で呼ばれるbuild()の負荷を抑える）。
  List<(String, String)>? _tips;
  int? _tipIndex;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startTipRotation();
    });
  }

  void _startTipRotation() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final tips = allTipEntries(l10n);
    if (tips.isEmpty) return;
    setState(() {
      _tips = tips;
      _tipIndex = _random.nextInt(tips.length);
    });
    _tipTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = _random.nextInt(tips.length));
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tips = _tips;
    final tipIndex = _tipIndex;
    final tip = (tips != null && tipIndex != null && tipIndex < tips.length)
        ? tips[tipIndex]
        : null;

    return AlertDialog(
      // 320dp幅の端末でも左右6dpずつの内容余白を残して、AdMob標準の
      // 300×250dpを縮小せず収める。
      insetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(6, 20, 6, 0),
      // 無料会員は広告＋Tipsカードが縦に並び内容が長くなるため、画面が
      // 小さい端末でもオーバーフローしないようスクロール可能にする。
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: widget.progress),
            const SizedBox(height: 8),
            Text('${(widget.progress * 100).round()}%'),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // 処理中プログレスバー→Tips→広告の順に並べる（広告を中間に
            // 挟むと視線の邪魔になりやすいため、最後に配置する）。
            if (tip != null) ...[
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(tip.$1),
                  width: 250,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.progressDialogTipLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kuramubon',
                              fontFamilyFallback: kHeadingFontFallback,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.cancelHint != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.cancelHint!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // 注記を含む処理情報のさらに下へ広告を置き、ダイアログ内でも
            // できるだけ下側に配置する。前後に余白を確保し、キャンセル等の
            // 操作項目と広告が近接しないようにする。
            const SizedBox(height: 20),
            const AdMediumRectangleMockWidget(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: widget.onCancel == null
          ? null
          : [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.commonCancel),
              ),
            ],
    );
  }
}
