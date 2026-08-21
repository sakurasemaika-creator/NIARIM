import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/export_engine.dart';
import '../../services/project_service.dart';

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
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _displayDuration = Duration(seconds: 2);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_displayDuration, () {
      if (!mounted) return;
      // 履歴に残さず置き換える（戻るボタンでスプラッシュへ戻らないようにする）
      context.go('/home');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadHomeData());
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Image.asset(
          'assets/logo/splash_logo.png',
          width: 160,
          height: 160,
        ),
      ),
    );
  }
}
