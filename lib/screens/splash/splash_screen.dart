import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';
import '../tips/tips_screen.dart' show allTipEntries;

/// 起動時のスプラッシュ画面。ロゴを約2秒間表示してからプロジェクト一覧
/// （ホーム画面）へ自動遷移する。
///
/// ロゴ画像は未完成のため、現時点では単色のプレースホルダー画像
/// （assets/logo/splash_logo.png）を表示している。本番ロゴが用意でき
/// 次第、同じファイル名・パスへ差し替えるだけでよい（コード変更不要）。
///
/// 表示している間に、ホーム画面の各タブが必要とするデータの先読みを
/// 裏で進めておく（[_preloadHomeData]）。これにより、ホーム画面へ遷移
/// した瞬間には大半の読み込みが完了済みか完了間近の状態になる。
/// また、処理中ダイアログ（[ProgressDialog]）と同様に、待ち時間を活用して
/// ランダムなTipsを1件表示する。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _displayDuration = Duration(seconds: 2);
  Timer? _timer;
  (String, String)? _tip;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_displayDuration, () {
      if (!mounted) return;
      // 履歴に残さず置き換える（戻るボタンでスプラッシュへ戻らないようにする）
      context.go('/home');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickRandomTip();
      _preloadHomeData();
    });
  }

  /// 表示するTipsを1件ランダムに選ぶ。スプラッシュは表示時間が短いため
  /// （約2秒）、[ProgressDialog]のような一定間隔での切り替えは行わない。
  void _pickRandomTip() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final tips = allTipEntries(l10n);
    if (tips.isEmpty) return;
    setState(() => _tip = tips[Random().nextInt(tips.length)]);
  }

  /// ホーム画面の各タブが表示に使うデータを先読みする。
  /// - 「作品一覧」タブ：exportsフォルダのファイル一覧（ディスクI/O）を
  ///   [ExportEngine.listExportedFiles]のキャッシュへ載せておく。
  /// - 「プロジェクト」「共有」タブ：一覧に並ぶサムネイル画像を
  ///   [precacheImage]でデコードし、Flutterの画像キャッシュへ載せておく。
  /// プロジェクト・共有・ゴミ箱の一覧自体（メタデータ）はProjectServiceが
  /// main()内で既に読み込み済みのため、ここでの対象はディスクI/O・画像
  /// デコードが必要なものに限られる。
  Future<void> _preloadHomeData() async {
    unawaited(ExportEngine.listExportedFiles());

    if (!mounted) return;
    final projectService = context.read<ProjectService>();
    final thumbnailPaths = <String>{
      for (final p in projectService.projects)
        if (p.thumbnailPath != null) p.thumbnailPath!,
      for (final p in projectService.shared)
        if (p.thumbnailPath != null) p.thumbnailPath!,
    };
    for (final path in thumbnailPaths) {
      if (!mounted) return;
      unawaited(precacheImage(FileImage(File(path)), context).catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tip = _tip;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo/splash_logo.png',
              width: 160,
              height: 160,
            ),
            if (tip != null) ...[
              const SizedBox(height: 32),
              Container(
                width: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(l10n.progressDialogTipLabel,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: scheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(tip.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(tip.$2,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
