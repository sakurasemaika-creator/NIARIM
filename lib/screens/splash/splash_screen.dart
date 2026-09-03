import 'package:niarim/services/theme_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';
import '../../config/font_fallback.dart';

/// 起動画面。ロゴを中央に表示し、その上に「作品広場」（コミュニティ
/// 画面への導線。1行目に大きく「作品広場」、2行目にやや小さく
/// 「投稿作品をみる」と表示する2行構成）、下に「作品をつくる」の
/// 2つの大きな導線ボタンを配置する。どちらかをタップするまで自動遷移は
/// しない。
///
/// 表示している間に、ホーム画面の各タブが必要とするデータの先読みを
/// 裏で進めておく（[_preloadHomeData]）。これにより、「アニメを作る」を
/// タップしてホーム画面へ遷移した瞬間には大半の読み込みが完了済みか
/// 完了間近の状態になる。
///
/// ロゴはSVG形式（assets/logo/app_logo.svg：モノグラム、
/// assets/logo/title_logo.svg：アプリタイトルロゴ）で保持し、flutter_svgで
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
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final communityButton = _SplashActionButton(
      icon: Icons.movie_filter_outlined,
      label: l10n.splashCommunityButtonTitle,
      subLabel: l10n.splashCommunityButtonSubtitle,
      // secondaryはテーマ・外観設定の「選択色」（AppThemePreset.selectionColor）
      // を直接反映する。tertiaryはColorScheme.fromSeedによる自動算出値のため、
      // ユーザーが選んだ色との対応が分かりにくくなるのを避ける。
      colors: [scheme.secondary, scheme.secondaryContainer],
      onTap: () => context.push('/community'),
    );
    final createButton = _SplashActionButton(
      icon: Icons.brush_outlined,
      label: l10n.splashCreateButton,
      colors: [scheme.primary, scheme.primaryContainer],
      // 作品広場と同じく起動画面を履歴へ残し、Android標準の戻る操作でも
      // 「作品をつくる」ホームからこの画面へ戻れるようにする。
      onTap: () => context.push('/home'),
    );
    // モノグラムは、アプリランチャーアイコン（tool/gen_app_icon.py）と
    // 同じ「テーマ色の角丸正方形の背景に、モノグラムを白抜きで重ねる」
    // 見た目に揃える。以前はSVGを直接テーマ色で塗るだけで背景を持たな
    // かったが、実際にホーム画面に並ぶアプリアイコンと起動画面の印象が
    // 揃うよう、同じ意匠にした（生成物はグリフがキャンバスの約86%を
    // 占めるが、ここではContainerへのpaddingで同じ比率を再現する。
    // 「スマホアプリ版Claudeのアイコンくらいのバランス」という要望を
    // 受けて0.58→0.74→0.86と拡大した経緯があり、export_engine.dartの
    // _renderEndCardPngの余白比率と必ず同じ値に揃えること）。
    // 背景色は固定のアクセント色ではなくscheme.primary（テーマ・外観
    // 設定で選んだ色）を使い、ユーザーが選んだテーマ配色から浮いて
    // 見えないようにする。タイトルロゴ（アプリ名の書き文字）は背景を
    // 持たない単色SVGのまま、モノグラムの下に元のSVGアスペクト比
    // （幅3470×高さ690相当）を保った横長サイズで添える。
    const logoSize = 110.0;
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(logoSize * 0.22),
          ),
          padding: const EdgeInsets.all(logoSize * 0.08),
          child: SvgPicture.asset(
            'assets/logo/app_logo.svg',
            colorFilter: ColorFilter.mode(ThemeService.activeColorScheme.onSurface, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: 10),
        SvgPicture.asset(
          'assets/logo/title_logo.svg',
          width: 220,
          height: 220 * 690 / 3470,
          colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
        ),
      ],
    );

    // 縦画面はロゴを挟んで上下にボタンを積む構成、横画面は画面の縦幅が
    // 狭くボタンが上下端に迫って見えるため、ロゴを挟んで左右にボタンを
    // 並べる構成へ切り替える（縦方向の余白を確保するのが目的）。
    final content = isLandscape
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              communityButton,
              const SizedBox(width: 40),
              logo,
              const SizedBox(width: 40),
              createButton,
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              communityButton,
              const SizedBox(height: 40),
              logo,
              const SizedBox(height: 40),
              createButton,
            ],
          );

    // Android標準のナビゲーションバー（戻る・ホーム・タブ一覧）の高さぶん、
    // SafeAreaの余白に加えてさらに下部の余白を確保する。端末・OSバージョン
    // によってはSafeAreaだけではジェスチャーナビゲーションバーの領域を
    // 十分に避けきれない場合があるための保険。
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
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
///
/// [subLabel]を指定すると、[label]を1行目に大きく・太字で、[subLabel]を
/// 2行目にやや小さく添える2行構成になる（例：「作品広場」
/// 「投稿作品をみる」）。省略時は[label]のみの1行構成（[createButton]
/// が使う従来通りの表示）。
class _SplashActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SplashActionButton({
    required this.icon,
    required this.label,
    this.subLabel,
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
          width: 150,
          // OSの文字サイズ設定（textScaler）を大きくしている端末では、
          // 中のアイコン＋ラベルが150pxに収まらず縦方向のRenderFlex
          // オーバーフローになっていた。高さ固定をやめ「最低150px・
          // 文字が伸びたぶんだけ縦に広がる」形にする（縦画面では
          // SingleChildScrollView、横画面ではRowの中にあるため、
          // 縦に伸びてもレイアウトは破綻しない）。
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ThemeService.activeColorScheme.onSurface, size: 60),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ThemeService.activeColorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
                maxLines: subLabel == null ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subLabel != null)
                Text(
                  subLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ThemeService.activeColorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
