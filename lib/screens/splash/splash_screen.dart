import 'package:niarim/services/theme_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';
import '../../config/font_fallback.dart';
import '../../utils/line_break.dart';
import '../../widgets/responsive.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/theme_rescue_button.dart';

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
    unawaited(
      ExportEngine.listExportedFiles().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          AppErrorReporter.record(error, stackTrace);
        },
      ),
    );

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

    // 韓国語は語の途中で折り返さない（「만들기」が「만들／기」に割れていた）。
    final korean = Localizations.localeOf(context).languageCode == 'ko';
    String wrapped(String text) =>
        korean ? keepKoreanWordsTogether(text) : text;
    final communityLabel = wrapped(l10n.splashCommunityButtonTitle);
    final communitySubLabel = wrapped(l10n.splashCommunityButtonSubtitle);
    final createLabel = wrapped(l10n.splashCreateButton);
    // 2つのボタンは同じ大きさに揃える。言語によって文言が折り返すと
    // 片方だけ縦に伸びて不揃いになるため、両方の中身の高さの大きい方に
    // 合わせる。
    // OSの文字サイズを大きくしている端末では、文字と一緒にタイルの幅も
    // 広げる（幅が150pxのままだと「Animation」のような長い語が1行に
    // 入らず、文言が省略されていた）。
    final tileWidth = _SplashActionButton.widthFor(context);
    final tileHeight = math.max(
      _SplashActionButton.heightFor(
        context,
        communityLabel,
        communitySubLabel,
        tileWidth,
      ),
      _SplashActionButton.heightFor(context, createLabel, null, tileWidth),
    );

    final communityButton = _SplashActionButton(
      icon: Icons.movie_filter_outlined,
      label: communityLabel,
      subLabel: communitySubLabel,
      width: tileWidth,
      height: tileHeight,
      // secondaryはテーマ・外観設定の「選択色」（AppThemePreset.selectionColor）
      // を直接反映する。tertiaryはColorScheme.fromSeedによる自動算出値のため、
      // ユーザーが選んだ色との対応が分かりにくくなるのを避ける。
      colors: [scheme.secondary, scheme.secondaryContainer],
      onTap: () => context.push('/community'),
    );
    final createButton = _SplashActionButton(
      icon: Icons.brush_outlined,
      label: createLabel,
      width: tileWidth,
      height: tileHeight,
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
    // どの画面でも、導線のボタンをアプリアイコン（モノグラム）とアプリ名の
    // ロゴより大きく見せる（主役は「作品をつくる」「作品広場」）。ロゴは
    // ボタンの基準幅に対する比で決める：モノグラムはボタンの0.6倍、
    // アプリ名はボタンより一回り狭い0.9倍。並び全体を縮めたり（小さな
    // 横画面）拡大したり（下の`upscale`）しても、比はそのまま保たれる。
    // PC（DeX等）とタブレット（短辺600dp以上）では、画面が広くても導線が
    // 主役になるよう、モノグラムをさらに控えめ（0.55倍）にする。
    final pc =
        isWideScreen(context) || MediaQuery.sizeOf(context).shortestSide >= 600;
    const tileBase = _SplashActionButton.baseWidth;
    final logoSize = tileBase * (pc ? 0.55 : 0.6);
    final titleWidth = tileBase * 0.9;
    final titleHeight = titleWidth * 690 / 3470;
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
          padding: EdgeInsets.all(logoSize * 0.08),
          child: SvgPicture.asset(
            'assets/logo/app_logo.svg',
            // 導線ボタンのアイコン・文字と同じテーマの「ボタン内の文字色」で
            // 白抜きにする（アクセント色の背景に載るのが同じ条件のため）。
            colorFilter: ColorFilter.mode(
              context.watch<ThemeService>().current.buttonTextColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SvgPicture.asset(
          'assets/logo/title_logo.svg',
          width: titleWidth,
          height: titleHeight,
          colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
        ),
      ],
    );

    // 縦画面はロゴを挟んで上下にボタンを積む構成、横画面は画面の縦幅が
    // 狭くボタンが上下端に迫って見えるため、ロゴを挟んで左右にボタンを
    // 並べる構成へ切り替える（縦方向の余白を確保するのが目的）。
    // 横に並べると幅が約600pxになり、小さな端末の横画面（568〜640px）では
    // 右端の「作品をつくる」が画面外へはみ出していた。縦に積む場合も、
    // 文字サイズを大きくしてタイルが広がると狭い画面からはみ出す。
    // 入りきらない幅では並びごと縮めて全体を収める（入るときは等倍）。
    final textEnlarged = MediaQuery.textScalerOf(context).scale(1) > 1.0;
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final availableWidth = screen.width - padding.horizontal - 48;
    final availableHeight =
        screen.height - padding.vertical - 32 - padding.bottom;
    const ring = _SplashActionButton.focusRingInset * 2;
    final tileOuterWidth = tileWidth + ring;
    final tileOuterHeight = tileHeight + ring;
    final logoWidth = math.max(logoSize, titleWidth);
    final logoHeight = logoSize + 10 + titleHeight;
    // ボタンとロゴの間隔。スマホは画面に余裕があれば広め（最大64px）に取り、
    // 小さな端末（高さ568px前後・横画面568〜640px）では収まるまで詰める
    // （縦は12px、横は40pxが下限。横で足りない分は並びごと縮める）。
    // PCは拡大前の寸法での間隔（拡大後は約60px）。
    final double gap;
    if (pc) {
      gap = 34;
    } else if (isLandscape) {
      gap = ((availableWidth - 2 * tileOuterWidth - logoWidth) / 4).clamp(
        40.0,
        64.0,
      );
    } else {
      gap = ((availableHeight - 2 * tileOuterHeight - logoHeight) / 4).clamp(
        12.0,
        64.0,
      );
    }
    final arrangement = isLandscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              communityButton,
              SizedBox(width: gap),
              logo,
              SizedBox(width: gap),
              createButton,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              communityButton,
              SizedBox(height: gap),
              logo,
              SizedBox(height: gap),
              createButton,
            ],
          );
    // PC・タブレットの広い画面では、スマホと同じ寸法のままだと画面の中央に
    // 小さく固まって見える。並び全体を、横並びなら画面幅の約8割、縦積みなら
    // 高さの約3/4まで拡大する（文字・アイコンはベクターなので拡大しても
    // 粗くならない）。拡大は2.2倍まで。
    final arrangementWidth = isLandscape
        ? 2 * tileOuterWidth + logoWidth + 2 * gap
        : math.max(tileOuterWidth, logoWidth);
    final arrangementHeight = isLandscape
        ? math.max(tileOuterHeight, logoHeight)
        : 2 * tileOuterHeight + logoHeight + 2 * gap;
    final upscale = !pc
        ? 1.0
        : isLandscape
        ? math.min(
            math.min(
              availableWidth * 0.8 / arrangementWidth,
              availableHeight * 0.6 / arrangementHeight,
            ),
            2.2,
          )
        : math.min(
            math.min(
              availableWidth * 0.62 / arrangementWidth,
              availableHeight * 0.75 / arrangementHeight,
            ),
            2.2,
          );
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: upscale > 1
          ? SizedBox(
              width: arrangementWidth * upscale,
              height: arrangementHeight * upscale,
              child: FittedBox(child: arrangement),
            )
          : arrangement,
    );

    // Android標準のナビゲーションバー（戻る・ホーム・タブ一覧）の高さぶん、
    // SafeAreaの余白に加えてさらに下部の余白を確保する。端末・OSバージョン
    // によってはSafeAreaだけではジェスチャーナビゲーションバーの領域を
    // 十分に避けきれない場合があるための保険。
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 横画面と、標準の文字サイズの縦画面は、幅と高さの両方へ収めて
            // スクロールさせない（小さな端末でも最初から両方のボタンが
            // 見える）。OSの文字サイズを大きくしているときは、選んだ大きさを
            // 縮めないよう、縦に収まらない分はスクロールで届くようにする。
            if (isLandscape || !textEnlarged || upscale > 1)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
                  child: Center(child: content),
                ),
              )
            else
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
                  child: content,
                ),
              ),
            // テーマ色の組み合わせによって、設定や主要導線が操作不能に
            // なりかねない場合は、発生経路（手動設定・プリセット・import・
            // .niatra等）を問わず右上に復旧ボタンを表示する。
            // 通常UIとは異なり、テーマに依存しない黒文字＋白縁取りの固定色を使う。
            if (context.watch<ThemeService>().needsThemeRescue)
              const Positioned(top: 8, right: 8, child: ThemeRescueButton()),
          ],
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
/// 「投稿作品をみる」）。省略時は[label]のみの構成。どちらも長い言語では
/// 折り返し、タイルは[height]まで縦に伸びる（文言を省略記号で切らない）。
///
/// アイコン・文字の色はテーマの「ボタン内の文字・アイコン色」
/// （[AppThemePreset.buttonTextColor]）。既定テーマでは白。`ColorScheme.onSurface`は
/// `ColorScheme.fromSeed`の自動算出値でユーザーが選んだ配色との対応が
/// 分かりにくいため使わない。この色は
/// `shortcut_widget_renderer.dart`が焼くホーム画面ウィジェットの意匠とも
/// 揃えてあり、`test/home_widget_shortcut_design_test.dart`が一致を守る。
///
/// グラデーションは`Ink`で描く。`Container`の装飾で描くと、押したときの
/// 波紋・ホバー・キーボードのフォーカス表示（いずれもMaterialの面に描かれる）
/// がグラデーションの下に隠れ、押しても何も変わらず、Tabで選んでも
/// どちらが選ばれているか分からなかった。
class _SplashActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final List<Color> colors;
  final VoidCallback onTap;

  /// タイルの幅（[widthFor]）。
  final double width;

  /// タイルの高さの下限（2つのボタンを同じ大きさに揃えるため、
  /// [heightFor]で求めた大きい方を両方へ渡す）。
  final double height;

  const _SplashActionButton({
    required this.icon,
    required this.label,
    this.subLabel,
    required this.colors,
    required this.onTap,
    required this.width,
    required this.height,
  });

  static const double baseWidth = 150;

  /// キーボードのフォーカス枠のために、タイルの外周へ確保している幅。
  static const double focusRingInset = 6;
  static const double _radius = 24;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 16,
  );
  static const double _iconSize = 60;
  static const double _iconGap = 12;
  static const int _maxLines = 3;

  static TextStyle _labelStyle(Color color) => TextStyle(
    color: color,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  static TextStyle _subLabelStyle(Color color) => TextStyle(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  /// タイルの幅。OSの文字サイズの倍率（2倍まで）に合わせて広げる。
  static double widthFor(BuildContext context) =>
      baseWidth * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

  /// [label]・[subLabel]を幅[width]のタイルに描いたときに要る高さ
  /// （最低でも幅と同じ）。OSの文字サイズ設定（textScaler）も含めて実際の
  /// 描画と同じ条件で測る。
  static double heightFor(
    BuildContext context,
    String label,
    String? sub,
    double width,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    // タイルの文字はMaterialの中にあり、テーマのbodyMedium（行の高さ等）を
    // 土台に描かれる。測るときも同じ土台へ重ねる（重ねないと行の高さの
    // ぶん低く見積もり、長い言語でボタンの高さが揃わなかった）。
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final textWidth = width - _padding.horizontal;
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: scaler,
        textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: _maxLines,
      )..layout(maxWidth: textWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    var content =
        _iconSize + _iconGap + measure(label, _labelStyle(Colors.white));
    if (sub != null) content += measure(sub, _subLabelStyle(Colors.white));
    return math.max(width, content + _padding.vertical);
  }

  @override
  State<_SplashActionButton> createState() => _SplashActionButtonState();
}

class _SplashActionButtonState extends State<_SplashActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>().current;
    // ユーザー指定のボタン文字色。明暗差による自動変更は行わない。
    final foreground = theme.buttonTextColor;
    const radius = BorderRadius.all(
      Radius.circular(_SplashActionButton._radius),
    );
    // キーボードで選んだときの枠。タイルの外側（背景の上）に描くので、
    // 背景に対して読める文字色を使う。常に3pxの余白を取っておき、
    // 枠の有無でボタンの位置がずれないようにする。
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(27)),
        border: Border.all(
          color: _focused ? theme.textColor : Colors.transparent,
          width: 3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        elevation: 4,
        shadowColor: widget.colors.first.withValues(alpha: 0.5),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          // InkWellだけではスクリーンリーダーに「ボタン」と伝わらない。
          child: Semantics(
            button: true,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onFocusChange: (focused) => setState(() => _focused = focused),
              splashColor: foreground.withValues(alpha: 0.28),
              highlightColor: foreground.withValues(alpha: 0.14),
              hoverColor: foreground.withValues(alpha: 0.10),
              focusColor: foreground.withValues(alpha: 0.14),
              child: Container(
                width: widget.width,
                // OSの文字サイズ設定（textScaler）を大きくしている端末や、
                // 文言の長い言語でも収まるよう、高さは固定せず下限だけ決める
                // （縦画面はSingleChildScrollView、横画面は縮めて収めるので、
                // 縦に伸びてもレイアウトは破綻しない）。
                constraints: BoxConstraints(minHeight: widget.height),
                padding: _SplashActionButton._padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: foreground,
                      size: _SplashActionButton._iconSize,
                    ),
                    const SizedBox(height: _SplashActionButton._iconGap),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: _SplashActionButton._labelStyle(foreground),
                      maxLines: _SplashActionButton._maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subLabel != null)
                      Text(
                        widget.subLabel!,
                        textAlign: TextAlign.center,
                        style: _SplashActionButton._subLabelStyle(foreground),
                        maxLines: _SplashActionButton._maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
