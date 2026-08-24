import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';

/// 起動画面。ロゴを中央に表示し、その上に「みんなのアニメを見る」、下に
/// 「アニメを作る」の2つの大きな導線ボタンを配置する。どちらかをタップする
/// まで自動遷移はしない。
///
/// 表示している間に、ホーム画面の各タブが必要とするデータの先読みを
/// 裏で進めておく（[_preloadHomeData]）。これにより、「アニメを作る」を
/// タップしてホーム画面へ遷移した瞬間には大半の読み込みが完了済みか
/// 完了間近の状態になる。
///
/// ロゴはSVG形式（assets/logo/app_logo.svg）で保持し、flutter_svgで
/// 描画する。画面中央に、上下の導線ボタンに挟まれる形で配置される。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
      unawaited(
        precacheImage(FileImage(File(path)), context).catchError((_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final communityButton = _SplashActionButton(
      icon: Icons.movie_filter_outlined,
      label: l10n.splashViewCommunityButton,
      // secondaryはテーマ・外観設定の「選択色」（AppThemePreset.selectionColor）
      // を直接反映する。tertiaryはColorScheme.fromSeedによる自動算出値のため、
      // ユーザーが選んだ色との対応が分かりにくくなるのを避ける。
      colors: [scheme.secondary, scheme.secondaryContainer],
      onTap: () => context.push('/community-coming-soon'),
    );
    final createButton = _SplashActionButton(
      icon: Icons.brush_outlined,
      label: l10n.splashCreateButton,
      colors: [scheme.primary, scheme.primaryContainer],
      onTap: () => context.go('/home'),
    );
    final logo = SvgPicture.asset(
      'assets/logo/app_logo.svg',
      width: 160,
      height: 160,
    );

    // 縦画面はロゴを挟んで上下にボタンを積む構成、横画面は画面の縦幅が
    // 狭くボタンが上下端に迫って見えるため、ロゴを挟んで左右にボタンを
    // 並べる構成へ切り替える（縦方向の余白を確保するのが目的）。
    final content = isLandscape
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              communityButton,
              const SizedBox(width: 64),
              logo,
              const SizedBox(width: 64),
              createButton,
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              communityButton,
              const SizedBox(height: 72),
              logo,
              const SizedBox(height: 72),
              createButton,
            ],
          );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 起動画面の大きな導線ボタン。単なるテキストボタンではなく、グラデーション
/// 背景・角丸・影を持つ正方形に近いタイル状のボタンにして存在感を出す
/// （中央に大きめのアイコンを図として配置し、下にラベルを添える構成）。
class _SplashActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SplashActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      shadowColor: colors.first.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 84),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
