import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/theme_service.dart';

/// One preview per distinct standalone app screen. Excludes folder contents,
/// home/community tabs, menus and floating panels. Export completion is the
/// specifically requested exception: the real app presents it as a dialog.
class ThemePreviewEntry {
  final String id, ja, en, layout;
  const ThemePreviewEntry(this.id, this.ja, this.en, this.layout);
  String label(bool japanese) => japanese ? ja : en;
}

const List<ThemePreviewEntry> themePreviewEntries = [
  ThemePreviewEntry('splash','起動画面','Splash','splash'),
  ThemePreviewEntry('projects','プロジェクト一覧','Projects','projects'),
  ThemePreviewEntry('shared','共有一覧','Shared projects','shared'),
  ThemePreviewEntry('trash','ゴミ箱','Trash','trash'),
  ThemePreviewEntry('new','新規プロジェクト','New project','form'),
  ThemePreviewEntry('detail','プロジェクト詳細','Project details','detail'),
  ThemePreviewEntry('canvas','キャンバスモード','Canvas mode','canvas'),
  ThemePreviewEntry('timeline','タイムラインモード','Timeline mode','timeline'),
  ThemePreviewEntry('export','作品書き出し','Export','export'),
  ThemePreviewEntry('complete','作品書き出し完了','Export complete','complete'),
  ThemePreviewEntry('save','セーブ管理','Save management','save'),
  ThemePreviewEntry('materials','素材管理','Materials','materials'),
  ThemePreviewEntry('community','作品広場','Community','community'),
  ThemePreviewEntry('work','作品広場・作品詳細','Community work detail','work'),
  ThemePreviewEntry('post','作品広場・投稿','Community post','post'),
  ThemePreviewEntry('author','投稿者の作品','Author works','author'),
  ThemePreviewEntry('mine','自分の投稿','My posts','mine'),
  ThemePreviewEntry('notifications','フォロー通知','Follow notifications','notifications'),
  ThemePreviewEntry('settings','設定','Settings','settings'),
  ThemePreviewEntry('theme','テーマ・外観','Theme & appearance','theme'),
  ThemePreviewEntry('performance','パフォーマンス','Performance','preferences'),
  ThemePreviewEntry('gestures','ジェスチャー','Gestures','preferences'),
  ThemePreviewEntry('shortcuts','ショートカット','Shortcuts','preferences'),
  ThemePreviewEntry('pen','ペン入力','Pen input','preferences'),
  ThemePreviewEntry('bucket','バケツ塗り','Bucket fill','preferences'),
  ThemePreviewEntry('workspace','ワークスペース','Workspace','workspace'),
  ThemePreviewEntry('pc_layout','PCワークスペース配置','PC workspace layout','workspace'),
  ThemePreviewEntry('transfer','引き継ぎ','Transfer','transfer'),
  ThemePreviewEntry('widgets','ウィジェット','Widgets','widgets'),
  ThemePreviewEntry('widget_art','ウィジェット作品選択','Widget artwork','materials'),
  ThemePreviewEntry('widget_frame','ウィジェットのフレーム選択','Widget frame picker','widget_frame'),
  ThemePreviewEntry('watermark','ウォーターマーク','Watermark','watermark'),
  ThemePreviewEntry('fonts','フォント管理','Fonts','fonts'),
  ThemePreviewEntry('storage','ストレージ','Storage','storage'),
  ThemePreviewEntry('premium','プレミアム','Premium','premium'),
  ThemePreviewEntry('help','ヘルプ','Help','help'),
  ThemePreviewEntry('tips','使い方のヒント','Tips','help'),
  ThemePreviewEntry('autofill','自動塗り設定','Auto-fill presets','autofill'),
  ThemePreviewEntry('sizes','キャンバスサイズ管理','Canvas sizes','sizes'),
  ThemePreviewEntry('license','ライセンス','Licenses','legal'),
  ThemePreviewEntry('privacy','プライバシーポリシー','Privacy policy','legal'),
];

/// Live themed, pure render-only widget. No project files, video, login,
/// network or database are touched. PageView builds pages lazily.
class ThemePreviewGalleryScreen extends StatefulWidget {
  const ThemePreviewGalleryScreen({super.key});
  @override
  State<ThemePreviewGalleryScreen> createState() => _ThemePreviewGalleryScreenState();
}
class _ThemePreviewGalleryScreenState extends State<ThemePreviewGalleryScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _controlsVisible = true;
  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeService>();
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: PageView.builder(
            key: const Key('themePreviewPager'),
            controller: _pages,
            itemCount: themePreviewEntries.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => RepaintBoundary(
              child: IgnorePointer(
                child: _ThemeSampleScreen(entry: themePreviewEntries[i], ja: ja),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _controlsVisible
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: .94),
                        border: Border.all(color: c.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      height: 54,
                      child: Row(children: [
                        IconButton(
                          key: const Key('themePreviewClose'),
                          tooltip: ja ? 'プレビューを閉じる' : 'Close preview',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(themePreviewEntries[_index].label(ja),
                              key: const Key('themePreviewTitle'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              ja ? '配色見本' : 'Theme sample',
                              style: TextStyle(
                                fontSize: 10, color: c.onSurfaceVariant)),
                          ],
                        )),
                        Text('${_index + 1}/${themePreviewEntries.length}',
                          style: const TextStyle(fontSize: 11)),
                        IconButton(
                          tooltip: ja ? '前の画面' : 'Previous screen',
                          icon: const Icon(Icons.chevron_left, size: 21),
                          onPressed: _index == 0 ? null
                            : () => _pages.previousPage(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut),
                        ),
                        IconButton(
                          key: const Key('themePreviewNext'),
                          tooltip: ja ? '次の画面' : 'Next screen',
                          icon: const Icon(Icons.chevron_right, size: 21),
                          onPressed: _index == themePreviewEntries.length - 1
                              ? null : () => _pages.nextPage(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut),
                        ),
                        IconButton(
                          key: const Key('themePreviewHideControls'),
                          tooltip: ja ? '操作バーを隠す' : 'Hide controls',
                          icon: const Icon(Icons.visibility_off_outlined, size: 19),
                          onPressed: () => setState(() => _controlsVisible = false),
                        ),
                      ]),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Material(
                          color: c.surface.withValues(alpha: .94),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const Key('themePreviewShowControls'),
                            tooltip: ja ? '操作バーを表示' : 'Show controls',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => setState(() => _controlsVisible = true),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A miniature *live* Flutter render of one existing gallery screen.
/// It is not a screenshot or a second copy of the screen layout:
/// both the inline sample and full-screen gallery use [_ThemeSampleScreen].
///
/// Render the real logical device viewport first, then uniformly scale the
/// result into this small frame. Ignore touches so the only operation on the
/// appearance page is opening the gallery. No project data is loaded.
class ThemePreviewThumbnail extends StatelessWidget {
  final double height;
  const ThemePreviewThumbnail({super.key, this.height = 184});

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width <= 0 ? 360.0 : viewport.width;
    final fullHeight = viewport.height <= 0 ? 760.0 : viewport.height;
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    final scheme = Theme.of(context).colorScheme;
    // A landscape tablet preview must stay compact too, without stretching
    // either axis. Scale the whole viewport by exactly one factor.
    final miniatureHeight = width > fullHeight
        ? height * fullHeight / width
        : height;
    final miniatureWidth = miniatureHeight * width / fullHeight;
    return RepaintBoundary(
      child: Semantics(
        label: japanese
            ? '現在のテーマで描画したプロジェクト一覧の縮小見本'
            : 'Miniature project list rendered with current theme',
        image: true,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Container(
              width: miniatureWidth,
              height: miniatureHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: fullHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(width, fullHeight),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: _ThemeSampleScreen(
                      entry: themePreviewEntries[1], // Projects screen.
                      ja: japanese,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The previews use real Flutter Material widgets and current theme tokens.
/// The screen data and icons are static examples and do not respond to taps.
class _ThemeSampleScreen extends StatelessWidget {
  final ThemePreviewEntry entry;
  final bool ja;
  const _ThemeSampleScreen({required this.entry, required this.ja});
  String t(String j, String e) => ja ? j : e;

  Widget _card(Widget child) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: Padding(padding: const EdgeInsets.all(12), child: child));
  Widget _row(IconData icon, String label, {String? subtitle}) => ListTile(
    dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon),
    title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right, size: 18));
  Widget _heading(String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  Widget _list(List<Widget> children) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), children: children);
  Widget _cta(ColorScheme c, String label, {IconData icon = Icons.check}) =>
    Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(
      color: c.primary, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c.onPrimary, size: 20), const SizedBox(width: 8),
        Text(label, style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.bold)),
      ]));
  Widget _art(ColorScheme c, {double height = 150}) => Container(
    height: height, color: c.surfaceContainerHigh,
    alignment: Alignment.center,
    child: Icon(Icons.movie_creation_outlined, size: 52, color: c.onSurfaceVariant));

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (entry.layout == 'splash') return _splash(context, c);
    if (entry.layout == 'canvas') return _canvas(c);
    if (entry.layout == 'timeline') return _timeline(c);
    if (entry.layout == 'complete') return _complete(c);
    const helpScreens = <String>{
      'new', 'theme', 'settings', 'performance', 'gestures',
      'shortcuts', 'pen', 'bucket', 'workspace', 'transfer',
      'widgets', 'watermark', 'fonts', 'storage', 'premium',
      'help', 'tips', 'autofill', 'sizes', 'license', 'privacy',
    };
    const menuScreens = <String>{
      'projects', 'shared', 'trash', 'detail', 'community',
      'work', 'post', 'author', 'mine', 'notifications',
    };
    final appTitle = switch (entry.id) {
      'detail' => t('練習作品', 'Practice'),
      'projects' => t('プロジェクト一覧', 'Projects'),
      'save' => t('セーブスロット', 'Save slots'),
      'new' => t('新規プロジェクト', 'New project'),
      'export' => t('書き出し', 'Export'),
      'theme' => t('テーマ・外観', 'Theme & appearance'),
      'gestures' => t('ジェスチャー設定', 'Gesture settings'),
      'pen' => t('ペン入力設定', 'Pen input settings'),
      'shortcuts' => t('ショートカット設定', 'Shortcut settings'),
      'bucket' => t('バケツ塗り設定', 'Bucket fill settings'),
      'performance' => t('パフォーマンス設定', 'Performance settings'),
      _ => entry.label(ja),
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: entry.id == 'projects' || entry.id == 'settings' ? null
            : const Icon(Icons.arrow_back),
        title: Text(appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (helpScreens.contains(entry.id))
            const Padding(padding: EdgeInsets.all(12),
              child: Icon(Icons.help_outline, size: 21)),
          if (entry.id == 'settings')
            const Padding(padding: EdgeInsets.all(12),
              child: Icon(Icons.search, size: 21)),
          if (menuScreens.contains(entry.id))
            const Padding(padding: EdgeInsets.all(12),
              child: Icon(Icons.more_vert, size: 21)),
        ],
      ),
      body: _body(context, c),
    );
  }

  Widget _body(BuildContext context, ColorScheme c) {
    switch(entry.layout) {
      case 'projects': return _projects(c);
      case 'shared': return _shared(c);
      case 'trash': return _trash(c);
      case 'widget_frame': return _widgetFrame(c);
      case 'community': return _community(c);
      case 'form': return _form(c);
      case 'detail': return _detail(c);
      case 'work': return _communityWork(c);
      case 'author': return _author(c);
      case 'mine': return _myWorks(c);
      case 'export': return _export(c);
      case 'post': return _post(c);
      case 'theme': return _theme(context, c);
      case 'settings': return _settings(c);
      case 'workspace': return _workspace(c);
      case 'premium': return _premium(c);
      case 'storage': return _storage(c);
      case 'watermark': return _watermark(c);
      case 'preferences': return _preferences(c);
      case 'transfer': return _transfer(c);
      case 'widgets': return _widgets(c);
      case 'notifications': return _notifications(c);
      case 'save': return _save(c);
      case 'legal': return _legal(c);
      default: return _catalog(c);
    }
  }



  // Read-only, zero-data UI atoms shared by theme-preview layouts. All visible
  // colors come from the active theme; sample project artwork is plain white.
  Widget _mockChip(ColorScheme c, String text, {bool active = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? c.primary : c.outlineVariant),
        ),
        child: Text(text, style: TextStyle(
          fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          color: active ? c.onPrimary : c.onSurface)),
      );

  Widget _mockSlider(ColorScheme c, {double position = .24, double height = 32}) =>
      SizedBox(height: height,
        child: Row(children: [
          Expanded(child: LayoutBuilder(builder: (_, bounds) =>
            Stack(alignment: Alignment.centerLeft, children: [
              Container(height: 2, color: c.outlineVariant),
              Container(height: 2, width: bounds.maxWidth * position,
                color: c.primary),
              Positioned(left: (bounds.maxWidth * position - 7).clamp(0.0, bounds.maxWidth - 14),
                child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: c.primary, border: Border.all(color: c.outline)))),
            ]),
          )),
        ]));

  Widget _mockTool(ColorScheme c, IconData icon, {bool active = false}) =>
    Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 18,
        color: active ? c.onPrimaryContainer : c.onSurface));

  Widget _fakePaper(ColorScheme c, {double? height}) =>
    Container(height: height, color: Colors.white);

  Widget _mockSection(ColorScheme c, String title, List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700))),
      ...children,
    ]);

  Widget _mockSettingRow(ColorScheme c, IconData icon, String title,
      {String? subtitle}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        child: ListTile(
        dense: true,
        leading: Icon(icon, color: c.primary, size: 22),
        title: Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle,
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 10)),
        trailing: Icon(Icons.chevron_right, size: 18, color: c.onSurfaceVariant),
        ),
      ),
    );

  Widget _splash(BuildContext context, ColorScheme c) {
    // Match splash_screen.dart: the user's explicit button foreground is
    // used for button labels/icons. The app-logo foreground uses it too.
    final preset = context.read<ThemeService>().current;
    final foreground = preset.buttonTextColor;
    Widget action(IconData icon, String title, String? subtitle,
        Color first, Color second) => Container(
      width: 150, height: 166,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [first, second],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 60, color: foreground),
        const SizedBox(height: 10),
        Text(title, maxLines: 3, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: foreground)),
        if (subtitle != null)
          Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: foreground)),
      ]),
    );
    final logo = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 110, height: 110, padding: const EdgeInsets.all(8.8),
        decoration: BoxDecoration(color: c.primary,
          borderRadius: BorderRadius.circular(24.2)),
        child: SvgPicture.asset('assets/logo/app_logo.svg',
          key: const Key('themePreviewSplashAppLogo'),
          colorFilter: ColorFilter.mode(preset.buttonTextColor, BlendMode.srcIn))),
      const SizedBox(height: 10),
      SvgPicture.asset('assets/logo/title_logo.svg',
        width: 220, height: 220 * 690 / 3470,
        colorFilter: ColorFilter.mode(c.primary, BlendMode.srcIn)),
    ]);
    final community = action(Icons.movie_filter_outlined,
      t('作品広場', 'Community'), t('投稿作品をみる', 'Browse works'),
      c.secondary, c.secondaryContainer);
    final create = action(Icons.brush_outlined,
      t('作品をつくる', 'Create artwork'), null,
      c.primary, c.primaryContainer);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final arrangement = landscape
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            community, const SizedBox(width: 40), logo,
            const SizedBox(width: 40), create,
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            community, const SizedBox(height: 32), logo,
            const SizedBox(height: 32), create,
          ]);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(fit: BoxFit.scaleDown, child: arrangement),
        ),
      )),
    );
  }

  Widget _projects(ColorScheme c) => Column(children: [
    Container(height: 44, color: c.surfaceContainer, child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Text(t('プロジェクト', 'Projects')),
        Text(t('作品一覧', 'Works')),
        Text(t('ブクマ済み', 'Saved')),
      ])),
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      const Icon(Icons.sort), const SizedBox(width: 10),
      Expanded(child: Text(t('更新日時 ▼', 'Last updated ▼'))),
      const Icon(Icons.grid_view), const SizedBox(width: 15), const Icon(Icons.search),
    ])),
    Expanded(child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10), crossAxisCount: 2, childAspectRatio: .88,
      children: [
        _projectTile(c, t('アニメーション', 'Animation')),
        _projectTile(c, t('練習作品', 'Practice')),
        _projectTile(c, t('ラフ', 'Sketch')),
        _projectTile(c, t('新作', 'New work')),
      ])),
    Padding(padding: const EdgeInsets.all(12),
      child: _cta(c, t('新しく作る', 'Create new'), icon: Icons.add)),
  ]);

  Widget _projectTile(ColorScheme c, String title) =>
      Card(clipBehavior: Clip.antiAlias, child: Column(children: [
        Expanded(child: Container(color: c.surfaceContainerHigh,
          alignment: Alignment.center, child: Icon(Icons.movie_creation_outlined,
          size: 42, color: c.primary))),
        Padding(padding: const EdgeInsets.all(9), child: Row(children: [
          Expanded(child: Text(title, maxLines: 1,
            style: const TextStyle(fontSize: 12))),
          Icon(Icons.star_border, color: c.tertiary, size: 16),
          const Icon(Icons.more_vert, size: 16),
        ])),
      ]));


  Widget _community(ColorScheme c) => Column(children: [
    Container(height: 38, color: c.surfaceContainerLow,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(t('新着', 'Latest'), style: TextStyle(
            color: c.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          Text(t('ランキング', 'Ranking'), style: const TextStyle(fontSize: 12)),
          Text(t('フォロー中', 'Following'), style: const TextStyle(fontSize: 12)),
        ])),
    Expanded(child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, childAspectRatio: .66,
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      padding: const EdgeInsets.all(8),
      children: List.generate(6, (i) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.outlineVariant)),
        child: Column(children: [
          Expanded(child: Container(
            color: c.surfaceContainerHigh,
            alignment: Alignment.center,
            child: Icon(Icons.movie_creation_outlined,
              size: 35, color: c.primary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('サンプル作品', 'Sample artwork'),
                  style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.account_circle, size: 14,
                    color: c.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Expanded(child: Text(t('サンプル作者', 'Sample creator'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9))),
                  const Icon(Icons.favorite_border, size: 15),
                  const SizedBox(width: 4),
                  const Icon(Icons.bookmark_border, size: 15),
                ]),
              ]),
          ),
        ]),
      ))),
    ),
  ]);

  Widget _canvas(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 43, child: Row(children: [
        const SizedBox(width: 4),
        _mockTool(c, Icons.undo),
        _mockTool(c, Icons.redo),
        const Spacer(),
        _mockTool(c, Icons.settings_outlined),
        _mockTool(c, Icons.home_outlined),
        _mockTool(c, Icons.aspect_ratio_outlined),
        const SizedBox(width: 6),
      ])),
      // Production canvas has a large centered paper over the workspace
      // surface. No raster engine or project frames are initialized here.
      Expanded(child: LayoutBuilder(builder: (_, bounds) {
        final width = bounds.maxWidth;
        final side = (width - 10).clamp(1.0, bounds.maxHeight);
        return Container(
          color: c.surfaceContainerHigh,
          child: Center(child: SizedBox(width: side, height: side,
            child: _fakePaper(c))),
        );
      })),
      SizedBox(height: 25, child: Row(children: [
        const SizedBox(width: 8),
        Text('●  0%', style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
        const Spacer(),
        Text('2D', style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
        const Icon(Icons.keyboard_arrow_down, size: 16),
        const SizedBox(width: 8),
      ])),
      SizedBox(height: 40, child: Row(children: [
        const SizedBox(width: 8),
        _mockTool(c, Icons.brush, active: true),
        const SizedBox(width: 5),
        Expanded(child: _mockSlider(c, position: .45)),
        Text('12', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        const SizedBox(width: 10),
      ])),
      SizedBox(height: 40, child: Row(children: [
        const SizedBox(width: 8),
        _mockTool(c, Icons.opacity),
        const SizedBox(width: 5),
        Expanded(child: _mockSlider(c, position: .85)),
        Text('85%', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        const SizedBox(width: 10),
      ])),
      SizedBox(height: 48, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _mockTool(c, Icons.brush, active: true),
          _mockTool(c, Icons.auto_fix_off),
          _mockTool(c, Icons.format_color_fill),
          _mockTool(c, Icons.colorize),
          _mockTool(c, Icons.select_all),
          _mockTool(c, Icons.pan_tool_outlined),
          _mockTool(c, Icons.layers_outlined),
          _mockTool(c, Icons.palette_outlined),
        ])),
      Container(height: 51, padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(
          color: c.outlineVariant))),
        child: Row(children: [
          ...List.generate(5, (i) => Container(
            width: 45, margin: const EdgeInsets.fromLTRB(1, 5, 3, 5),
            color: Colors.white,
            child: DecoratedBox(decoration: BoxDecoration(
              border: Border.all(color: i == 0 ? c.primary : c.outlineVariant,
                width: i == 0 ? 2 : 1)))),
          ),
          const Spacer(),
          _mockTool(c, Icons.play_arrow_outlined),
        ])),
    ])),
  );

  Widget _timeline(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 44, child: Row(children: [
        _mockTool(c, Icons.arrow_back),
        Expanded(child: Text(t('練習作品', 'Practice'), maxLines: 1,
          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600))),
        _mockTool(c, Icons.home_outlined),
        _mockTool(c, Icons.undo),
        _mockTool(c, Icons.redo),
        _mockTool(c, Icons.more_vert),
        _mockTool(c, Icons.help_outline),
      ])),
      Expanded(flex: 7, child: Column(children: [
        Expanded(child: Center(
          child: AspectRatio(aspectRatio: 16 / 9,
            child: _fakePaper(c)))),
        const SizedBox(height: 8),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 15),
        child: _mockSlider(c, position: .05, height: 26)),
      SizedBox(height: 46, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mockTool(c, Icons.skip_previous),
          _mockTool(c, Icons.fast_rewind),
          _mockTool(c, Icons.play_arrow),
          _mockTool(c, Icons.fast_forward),
          _mockTool(c, Icons.skip_next),
          _mockTool(c, Icons.repeat),
        ])),
      Container(height: 2, color: c.outlineVariant),
      SizedBox(height: 40, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _mockTool(c, Icons.access_time_outlined),
          _mockTool(c, Icons.movie_outlined),
          _mockTool(c, Icons.image_outlined),
          _mockTool(c, Icons.music_note_outlined),
          _mockTool(c, Icons.text_fields),
          _mockTool(c, Icons.layers_outlined),
          _mockTool(c, Icons.file_copy_outlined),
        ])),
      Container(height: 33, color: c.surfaceContainerHigh,
        child: Row(children: [
          Container(width: 98, alignment: Alignment.center,
            color: c.primary, child: Text('Scene1',
              style: TextStyle(fontSize: 12, color: c.onPrimary))),
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(6, (i) => Text('${i + 1}',
              style: const TextStyle(fontSize: 10))))),
        ])),
      Expanded(flex: 5, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _timelineTrack(c, t('描画フレーム', 'Draw frames')),
          _timelineTrack(c, t('画像', 'Images')),
          _timelineTrack(c, t('動画', 'Video')),
          _timelineTrack(c, t('テキスト', 'Text')),
        ])),
    ])),
  );


  Widget _timelineTrack(ColorScheme c, String label) => SizedBox(
    height: 41, child: Row(children: [
      Container(width: 98, padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft, color: c.surfaceContainerLow,
        child: Text(label, style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis)),
      Expanded(child: Row(
        children: List.generate(5, (i) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == 0 ? c.primary : c.surfaceContainerHigh,
              border: Border.all(color: c.outlineVariant)),
            child: Text('${i + 1}', style: TextStyle(
              fontSize: 10, color: i == 0 ? c.onPrimary : c.onSurfaceVariant)),
          ))))),
    ]),
  );

  Widget _complete(ColorScheme c) => Scaffold(body: Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 80, color: c.primary),
        const SizedBox(height: 12),
        _heading(t('書き出し完了', 'Export complete')),
        Text(t('48フレームを書き出しました', '48 frames exported')),
        const SizedBox(height: 12),
        _card(const Text('animation.mp4')),
        const SizedBox(height: 12),
        _cta(c, t('共有する', 'Share'), icon: Icons.share),
        const SizedBox(height: 18),
        Text(t('プロジェクト一覧に戻る', 'Return to projects'),
          style: TextStyle(color: c.primary)),
      ],
    )),
  ));



  Widget _form(ColorScheme c) => _list([
    Container(
      decoration: BoxDecoration(border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('プロジェクト名', 'Project name'),
          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(t('新規プロジェクト', 'New project'),
          style: const TextStyle(fontSize: 13)),
      ]),
    ),
    const SizedBox(height: 22),
    const Text('FPS', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, children: [
      _mockChip(c, '8'), _mockChip(c, '12', active: true),
      _mockChip(c, '24'),
    ]),
    const SizedBox(height: 22),
    Row(children: [
      Expanded(child: Text(t('サイズ', 'Canvas size'),
        style: const TextStyle(fontWeight: FontWeight.bold))),
      Icon(Icons.tune, size: 18, color: c.primary),
      const SizedBox(width: 6),
      Text(t('サイズ設定', 'Size settings'),
        style: TextStyle(fontSize: 12, color: c.primary)),
    ]),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 9, children: [
      _mockChip(c, 'HD (16:9) 1280×720'),
      _mockChip(c, 'Full HD (16:9) 1920×1080', active: true),
      _mockChip(c, 'HD (9:16) 720×1280'),
      _mockChip(c, 'カスタム'),
      _mockChip(c, 'SNS (1:1) 1080×1080'),
    ]),
    const SizedBox(height: 16),
    Container(height: 64, margin: const EdgeInsets.symmetric(horizontal: 65),
      alignment: Alignment.center, decoration: BoxDecoration(
        color: c.surfaceContainerHigh, border: Border.all(color: c.outlineVariant)),
      child: const Text('1920 × 1080', style: TextStyle(fontSize: 10))),
    const SizedBox(height: 18),
    _mockSettingRow(c, Icons.palette_outlined, t('背景色', 'Background')),
    _mockSettingRow(c, Icons.auto_awesome, t('自動塗り', 'Auto fill')),
    const SizedBox(height: 12),
    _cta(c, t('作成', 'Create'), icon: Icons.add),
  ]);

  Widget _detail(ColorScheme c) => _list([
    AspectRatio(aspectRatio: 16 / 9, child: _fakePaper(c)),
    const SizedBox(height: 10),
    _mockSlider(c, position: .07, height: 28),
    Container(
      height: 54,
      decoration: BoxDecoration(color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mockTool(c, Icons.skip_previous),
          _mockTool(c, Icons.fast_rewind),
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow, color: c.onPrimary)),
          _mockTool(c, Icons.fast_forward),
          _mockTool(c, Icons.skip_next),
        ])),
    const SizedBox(height: 16),
    _cta(c, t('編集開始', 'Start editing'), icon: Icons.edit),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _mockTool(c, Icons.folder_outlined),
      _mockTool(c, Icons.sell_outlined),
      _mockTool(c, Icons.star_border),
      _mockTool(c, Icons.ios_share),
    ]),
    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      Text(t('フォルダ', 'Folder'), style: const TextStyle(fontSize: 11)),
      Text(t('タグ', 'Tags'), style: const TextStyle(fontSize: 11)),
      Text(t('お気に入り', 'Favorite'), style: const TextStyle(fontSize: 11)),
      Text(t('共有', 'Share'), style: const TextStyle(fontSize: 11)),
    ]),
    const SizedBox(height: 16),
    _heading(t('プロジェクト情報', 'Project information')),
    _card(Column(children: [
      _row(Icons.speed, 'FPS', subtitle: '12'),
      _row(Icons.aspect_ratio, t('描画領域', 'Canvas'), subtitle: '320×180'),
      _row(Icons.movie_filter, t('総フレーム数', 'Frames'), subtitle: '12'),
    ])),
  ]);


  Widget _export(ColorScheme c) => _list([
    _heading(t('プリセット', 'Presets')),
    _staticChoiceRow(c,
      [t('標準', 'Standard'), t('高画質', 'High'),
        t('カスタム', 'Custom')], active: 0),
    const SizedBox(height: 18),
    _heading(t('形式', 'Format')),
    ...[
      ('MP4', 'H.264'),
      ('GIF', t('アニメーションGIF', 'Animation GIF')),
      ('WebM', t('透過に対応', 'Supports transparency')),
      ('AVI', t('高品質動画', 'Video')),
    ].asMap().entries.map((e) => Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Row(children: [
        Icon(e.key == 0 ? Icons.radio_button_checked :
          Icons.radio_button_unchecked,
          color: e.key == 0 ? c.primary : c.onSurfaceVariant, size: 19),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.value.$1, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600)),
          Text(e.value.$2, style: TextStyle(fontSize: 10,
            color: c.onSurfaceVariant)),
        ]),
      ]))),
    const SizedBox(height: 15),
    _cta(c, t('書き出し開始', 'Start export'), icon: Icons.file_download_outlined),
  ]);


  Widget _post(ColorScheme c) => _list([
    _heading(t('作品を投稿', 'Post artwork')),
    Container(height: 58, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerLeft,
      child: Text(t('作品タイトル', 'Artwork title'),
        style: TextStyle(color: c.onSurfaceVariant))),
    const SizedBox(height: 12),
    Container(height: 105, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.topLeft,
      child: Text(t('説明を入力', 'Description'),
        style: TextStyle(color: c.onSurfaceVariant))),
    const SizedBox(height: 15),
    _mockSettingRow(c, Icons.movie_outlined, t('投稿する動画', 'Video')),
    _mockSettingRow(c, Icons.sell_outlined, t('タグ', 'Tags')),
    _staticControl(c, t('作品広場に表示', 'Publish in community')),
    const SizedBox(height: 20),
    _cta(c, t('投稿する', 'Post'), icon: Icons.cloud_upload_outlined),
  ]);

  Widget _theme(BuildContext context, ColorScheme c) {
    final preset = context.read<ThemeService>().current;
    return _list([
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ThemePreviewThumbnail(height: 170),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('画面プレビュー', 'Screen preview'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(t('プロジェクト一覧の縮小見本', 'Miniature projects view'),
              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
            const SizedBox(height: 7),
            Text(t('タップで全画面', 'View full screen'),
              style: TextStyle(fontSize: 11, color: c.primary)),
          ])),
      ]),
      const SizedBox(height: 16),
      _heading(t('カラーカスタマイズ', 'Color customization')),
      ...[
        (t('アクセント', 'Accent'), c.primary),
        (t('本文文字色', 'Body text'), c.onSurface),
        (t('ボタン内の文字色', 'Button text'), c.onPrimary),
        (t('メニューの文字色', 'Menu text'), preset.menuTextColor),
        (t('選択中の文字色', 'Selected text'), c.onSecondary),
        (t('パネル背景', 'Panel background'), preset.panelBgColor),
        (t('メニュー背景', 'Menu background'), preset.menuBgColor),
        (t('選択色', 'Selection'), c.secondary),
        (t('更新マーク', 'Update mark'), preset.updateMarkColor),
      ].map((e) => _card(Row(children: [
        CircleAvatar(radius: 16, backgroundColor: e.$2),
        const SizedBox(width: 14),
        Expanded(child: Text(e.$1, style: const TextStyle(fontSize: 12))),
        const Icon(Icons.chevron_right, size: 18),
      ]))),
      _heading(t('プリセット', 'Presets')),
      _mockSettingRow(c, Icons.palette_outlined, t('ライト', 'Light')),
      _mockSettingRow(c, Icons.palette_outlined, t('ダーク', 'Dark')),
    ]);
  }

  Widget _settings(ColorScheme c) => _list([
    ...[
      (Icons.settings_outlined, t('基本', 'Basic'), t('FPS・言語・初期色', 'FPS, language and defaults')),
      (Icons.speed_outlined, t('パフォーマンス', 'Performance'), t('描画品質・Undo回数・自動削除', 'Quality, undo and cleanup')),
      (Icons.gesture_outlined, t('ジェスチャー', 'Gestures'), t('2本指タップ・長押し', 'Gestures')),
      (Icons.keyboard_outlined, t('ショートカット設定', 'Shortcuts'), t('キー・操作を割り当て', 'Key bindings')),
      (Icons.edit_outlined, t('ペン入力', 'Pen input'), t('筆圧・ペンボタン', 'Pressure and stylus')),
      (Icons.dashboard_customize_outlined, t('ワークスペース', 'Workspace'), t('ツール・パネル配置', 'Toolbar and panel')),
      (Icons.format_color_fill_outlined, t('バケツ塗り', 'Bucket fill'), t('許容誤差・隙間閉じ', 'Tolerance and gaps')),
      (Icons.widgets_outlined, t('ホーム画面ウィジェット', 'Home widgets'), t('表示作品・タップ動作', 'Artwork and actions')),
      (Icons.palette_outlined, t('テーマ・外観', 'Theme & appearance'), t('テーマ色・文字色・背景色', 'Theme and colors')),
      (Icons.text_fields, t('フォント管理', 'Fonts'), t('文字入れフォント', 'Fonts')),
      (Icons.help_outline, t('ヘルプ', 'Help'), t('使い方とヒント', 'Help and tips')),
    ].map((e) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(e.$1, color: c.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.$2, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700)),
              Text(e.$3, style: TextStyle(fontSize: 10,
                color: c.onSurfaceVariant), maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ])),
          Icon(Icons.chevron_right, color: c.onSurfaceVariant),
        ])),
    )),
  ]);

  Widget _staticControl(ColorScheme c, String label, {
    String? detail, bool selected = true,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600)),
          if (detail != null) Text(detail, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
        ])),
      Container(width: 30, height: 17,
        padding: const EdgeInsets.all(2),
        alignment: selected ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? c.primary : c.outlineVariant,
          borderRadius: BorderRadius.circular(12)),
        child: Container(width: 13, height: 13,
          decoration: BoxDecoration(color: selected ? c.onPrimary : c.surface,
            shape: BoxShape.circle))),
    ]),
  );

  Widget _staticChoiceRow(ColorScheme c, List<String> choices, {
      int active = 0}) => Row(children: [
        for (var i = 0; i < choices.length; i++) Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == active ? c.primary : c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.outlineVariant)),
            child: Text(choices[i], maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10,
                color: i == active ? c.onPrimary : c.onSurface)),
          )),
      ]);

  Widget _preferences(ColorScheme c) {
    switch (entry.id) {
      case 'performance':
        return _list([
          _mockSection(c, t('描画品質', 'Render quality'), [
            ...[t('低品質', 'Low'), t('中品質', 'Medium'), t('高品質', 'High'),
              t('カスタム', 'Custom')].asMap().entries.map((e) =>
              ListTile(dense: true,
                leading: Icon(e.key == 0
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: e.key == 0 ? c.primary : c.onSurfaceVariant),
                title: Text(e.value, style: const TextStyle(fontSize: 12)),
                subtitle: e.key == 0
                  ? Text(t('動作を軽くして快適に使う', 'Prioritize speed'),
                    style: TextStyle(fontSize: 10, color: c.onSurfaceVariant))
                  : null,
              )),
          ]),
          _mockSection(c, t('容量・動作に関わる設定', 'Storage and behavior'), [
            _mockSettingRow(c, Icons.undo, t('Undoの回数', 'Undo limit'),
              subtitle: t('戻ることができる回数', 'Undo history')),
            _mockSettingRow(c, Icons.delete_outline,
              t('ゴミ箱の自動削除', 'Automatic trash cleanup')),
          ]),
          _mockSection(c, t('履歴の設定', 'History'), [
            Text('OFF', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
          ]),
        ]);
      case 'gestures':
        return _list([
          ...[
            (t('2本指タップ', 'Two-finger tap'), t('取り消し（Undo）', 'Undo')),
            (t('3本指タップ', 'Three-finger tap'), t('やり直し（Redo）', 'Redo')),
            (t('4本指以上のタップ', 'Four-finger tap'), t('何もしない', 'No action')),
            (t('2本指スワイプ左右', 'Two-finger swipe'), t('ツール切り替え', 'Tool change')),
            (t('長押し', 'Long press'), t('スポイト', 'Eyedropper')),
          ].map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(dense: true,
              title: Text(e.$1, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.$2, style: TextStyle(fontSize: 10, color: c.primary)),
                const SizedBox(width: 6), const Icon(Icons.chevron_right, size: 15),
              ]))))),
          const SizedBox(height: 12),
          _mockSection(c, t('長押しスポイト', 'Long press eyedropper'), [
            _staticControl(c, t('長押しでスポイトを起動', 'Eyedropper on hold'),
              detail: t('キャンバス上を長押し', 'Touch and hold on canvas')),
            const SizedBox(height: 8),
            Text(t('反応時間', 'Response time'),
              style: const TextStyle(fontSize: 11)),
            _mockSlider(c, position: .24),
          ]),
        ]);
      case 'shortcuts':
        return _list([
          Text(t('ショートカットの一覧。タップするとキーを変更できます。',
            'Shortcut key bindings.'),
            style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
          ...[
            ('Ctrl+Z', t('取り消し（Undo）', 'Undo')),
            ('Ctrl+Y', t('やり直し（Redo）', 'Redo')),
            ('Ctrl+Shift+Z', t('やり直し（Redo）', 'Redo')),
            ('Ctrl+A', t('全選択', 'Select all')),
            ('Ctrl+C', t('コピー', 'Copy')),
            ('Ctrl+V', t('貼り付け', 'Paste')),
            ('Ctrl+S', t('保存', 'Save')),
          ].map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5)),
                child: Text(e.$1, style: const TextStyle(fontSize: 10))),
              const SizedBox(width: 9),
              Expanded(child: Text(e.$2,
                style: const TextStyle(fontSize: 11))),
              Icon(Icons.delete_outline, size: 17, color: c.primary),
            ]))),
        ]);
      case 'pen':
        return _list([
          _staticControl(c, t('パームリジェクション', 'Palm rejection'),
            detail: t('手のひらの誤操作を防止', 'Prevent palm input')),
          const SizedBox(height: 22),
          _mockSection(c, t('筆圧カーブ', 'Pressure curve'), [
            Text(t('筆圧に合わせて線の太さが変わります。',
              'Pressure changes stroke width.'),
              style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
            const SizedBox(height: 9),
            _staticChoiceRow(c, [
              t('標準', 'Normal'), t('ソフト', 'Soft'),
              t('強', 'Strong'), t('カスタム', 'Custom')], active: 1),
            const SizedBox(height: 12),
            Container(height: 148, decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.outlineVariant))),
          ]),
          const SizedBox(height: 22),
          _mockSection(c, t('ペンボタン設定', 'Pen buttons'), [
            _mockSettingRow(c, Icons.edit_outlined, t('ボタン1', 'Button 1'),
              subtitle: t('消しゴム', 'Eraser')),
            _mockSettingRow(c, Icons.edit_outlined, t('ボタン2', 'Button 2'),
              subtitle: t('スポイト', 'Eyedropper')),
          ]),
        ]);
      case 'bucket':
        return _list([
          _mockSection(c, t('許容誤差', 'Tolerance'), [
            Text(t('タップした色の近さを調整します。',
              'Adjust the acceptable color difference.'),
              style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
            _mockSlider(c, position: .30),
          ]),
          _mockSection(c, t('隙間の許容', 'Gap tolerance'), [
            Text(t('線の隙間を越えて塗りつぶす範囲', 'Fill beyond small gaps'),
              style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
            _mockSlider(c, position: .04),
          ]),
          const SizedBox(height: 18),
          _staticControl(c, t('線の下まで拡張', 'Expand beneath line'),
            detail: t('塗りつぶし領域を線の下へ広げる', 'Expand under outline'),
            selected: false),
        ]);
      default:
        return _list([_mockSettingRow(c, Icons.tune,
          entry.label(ja))]);
    }
  }


  Widget _workspace(ColorScheme c) => _list([
    _mockSection(c, t('ツールバー編集', 'Toolbar editor'), [
      Text(t('表示するツールの並びを設定できます。',
        'Toolbar order and visibility.'),
        style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.all(8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _mockTool(c, Icons.brush),
            _mockTool(c, Icons.auto_fix_off),
            _mockTool(c, Icons.colorize),
            _mockTool(c, Icons.layers),
            _mockTool(c, Icons.pan_tool),
          ])),
    ]),
    const SizedBox(height: 7),
    ...[
      (Icons.brush, t('ペン', 'Pen')),
      (Icons.auto_fix_off, t('消しゴム', 'Eraser')),
      (Icons.format_color_fill, t('バケツ', 'Fill')),
      (Icons.colorize, t('スポイト', 'Eyedropper')),
      (Icons.pan_tool, t('手のひら', 'Hand')),
      (Icons.select_all, t('選択', 'Select')),
      (Icons.text_fields, t('テキスト', 'Text')),
      (Icons.layers_outlined, t('レイヤー', 'Layers')),
    ].map((e) => Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: c.surfaceContainerLow,
      child: Row(children: [
        Icon(Icons.check_box, size: 19, color: c.primary),
        const SizedBox(width: 8), Icon(e.$1, size: 18),
        const SizedBox(width: 8), Expanded(child: Text(e.$2,
          style: const TextStyle(fontSize: 12))),
        Icon(Icons.drag_handle, size: 19, color: c.primary),
      ]))),
    const SizedBox(height: 9),
    _mockSettingRow(c, Icons.back_hand_outlined,
      t('左利きモード', 'Left-handed mode')),
    _mockSettingRow(c, Icons.desktop_windows,
      t('PCモード', 'PC mode')),
    _mockSettingRow(c, Icons.dashboard_outlined,
      t('パネル配置', 'Panel layout')),
    const SizedBox(height: 5),
    _cta(c, t('適用', 'Apply')),
  ]);

  Widget _premium(ColorScheme c) => _list([
    Center(child: Icon(Icons.auto_awesome, size: 48, color: c.primary)),
    const SizedBox(height: 8),
    _heading(t('プレミアムでもっと自由に', 'Create with Premium')),
    ...[
      t('ウォーターマークなし', 'No watermark'),
      t('長尺アニメーション', 'Longer animations'),
      t('多彩な補正', 'More effects'),
    ].map((label) => _mockSettingRow(c, Icons.check, label)),
    const SizedBox(height: 12),
    _cta(c, t('プランを見る', 'View plans')),
  ]);

  Widget _storage(ColorScheme c) => _list([
    _heading(t('NIARIMの使用量', 'NIARIM storage')),
    const SizedBox(height: 8),
    Row(children: [
      SizedBox(width: 120, height: 120,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 120, height: 120,
            child: CircularProgressIndicator(value: .32, strokeWidth: 23,
              color: c.primary, backgroundColor: c.surfaceContainerHigh)),
          Text('380 MB', style: TextStyle(fontSize: 12,
            color: c.onSurface)),
        ])),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('プロジェクトデータ', 'Project data'),
            style: const TextStyle(fontSize: 12)),
          const Text('320 MB', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 8),
          Text(t('キャッシュ', 'Cache'),
            style: const TextStyle(fontSize: 12)),
          const Text('60 MB', style: TextStyle(fontSize: 11)),
        ])),
    ]),
    const SizedBox(height: 24),
    _heading(t('容量を減らす', 'Free up space')),
    ...[
      (Icons.cleaning_services_outlined, t('キャッシュを削除', 'Clear cache')),
      (Icons.delete_sweep_outlined, t('変更履歴を一時削除', 'Clear history cache')),
      (Icons.folder_outlined, t('プロジェクトを整理する', 'Organize projects')),
      (Icons.warning_amber_outlined, t('全データを削除', 'Delete all data')),
    ].map((e) => _mockSettingRow(c, e.$1, e.$2)),
  ]);

  Widget _watermark(ColorScheme c) => Column(children: [
    const SizedBox(height: 12),
    Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wallpaper_outlined, size: 48, color: c.primary),
        const SizedBox(height: 12),
        Text(t('登録されたウォーターマークがありません',
          'No saved watermarks'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(t('右下の＋から作成できます', 'Create one with +'),
          style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
      ]))),
    Padding(padding: const EdgeInsets.all(15),
      child: Align(alignment: Alignment.bottomRight,
        child: CircleAvatar(radius: 23, backgroundColor: c.primary,
          child: Icon(Icons.add, color: c.onPrimary)))),
  ]);

  Widget _transfer(ColorScheme c) => _list([
    _heading(t('引き継ぎデータ', 'Transfer data')),
    Text(t('新しい端末へ引き継ぐ項目を選んでください。',
      'Choose data to transfer.'),
      style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
    const SizedBox(height: 12),
    ...[
      t('設定', 'Settings'), t('素材', 'Materials'),
      t('ブラシ', 'Brushes'), t('自動塗り設定', 'Autofill'),
      t('テーマ', 'Themes'), t('パネル・ツールバーの設定', 'Tool layout'),
    ].map((e) => Material(
      color: c.surfaceContainerLow,
      child: ListTile(dense: true,
        title: Text(e, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.check_box, color: c.primary, size: 20)))),
    const SizedBox(height: 14),
    _heading(t('保存中のプロジェクト（任意）', 'Saved projects')),
    _mockSettingRow(c, Icons.check_box_outline_blank,
      t('練習作品', 'Practice')),
    const SizedBox(height: 20),
    _cta(c, t('書き出し', 'Export'), icon: Icons.file_upload_outlined),
  ]);

  Widget _widgets(ColorScheme c) => _list([
    _heading(t('ホーム画面ウィジェット', 'Home widgets')),
    Text(t('スマホのホーム画面に作品を表示します。',
      'Display your artwork on your home screen.'),
      style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
    const SizedBox(height: 22),
    _heading(t('最新更新作品ウィジェット', 'Latest artwork')),
    _mockSettingRow(c, Icons.image_outlined,
      t('作品を選ぶ', 'Choose artwork')),
    const SizedBox(height: 17),
    _heading(t('作品をランダム表示する', 'Random artwork')),
    _staticChoiceRow(c, [
      t('アプリのテーマ色に合わせる', 'Use app theme'),
      t('自動選択', 'Automatic')]),
    const SizedBox(height: 16),
    _heading(t('作品画像ウィジェット', 'Artwork widget')),
    _staticChoiceRow(c, [
      t('アプリのテーマ色に合わせる', 'Use app theme'),
      t('自動選択', 'Automatic')]),
  ]);

  Widget _notifications(ColorScheme c) => _list([
    _card(_row(Icons.person_add, t('新しいフォロワー', 'New follower'))),
    _card(_row(Icons.notifications_outlined, t('お知らせ', 'Notification'))),
  ]);


  Widget _save(ColorScheme c) => _list([
    ...List.generate(5, (i) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 57, height: 57,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.add, color: c.onPrimaryContainer)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i == 0
                ? t('クイックセーブ', 'Quick save')
                : '${t('スロット', 'Slot')} $i',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(t('保存データなし', 'Empty slot'),
              style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
          ])),
        Icon(Icons.save_outlined, size: 20, color: c.primary),
        const SizedBox(width: 10),
        Icon(Icons.copy_outlined, size: 20, color: c.onSurfaceVariant),
        const SizedBox(width: 10),
        Icon(Icons.delete_outline, size: 20, color: c.onSurfaceVariant),
      ]))),
  ]);

  Widget _catalog(ColorScheme c) {
    final rows = switch (entry.id) {
      'materials' || 'widget_art' => [
        (Icons.image, 'image.png'),
        (Icons.movie, 'clip.mp4'),
        (Icons.audiotrack, 'sound.wav'),
      ],
      'fonts' => [
        (Icons.text_fields, '白光明朝'),
        (Icons.text_fields, 'くらむぼん'),
        (Icons.text_fields, 'Noto Serif JP'),
      ],
      'help' || 'tips' => [
        (Icons.brush, t('描画', 'Drawing')),
        (Icons.layers, t('レイヤー', 'Layers')),
        (Icons.movie_filter, t('アニメーション', 'Animation')),
        (Icons.file_download, t('書き出し', 'Export')),
      ],
      'autofill' => [
        (Icons.palette_outlined, t('キャラクター A', 'Character A')),
        (Icons.palette_outlined, t('キャラクター B', 'Character B')),
        (Icons.palette_outlined, t('背景', 'Background')),
      ],
      'sizes' => [
        (Icons.crop_16_9, '1920 × 1080'),
        (Icons.crop_square, '1080 × 1080'),
        (Icons.crop_portrait, '1080 × 1920'),
      ],
      _ => [(Icons.folder_outlined, t('サンプル', 'Sample'))],
    };
    return _list([
      _heading(entry.label(ja)),
      if (entry.id != 'sizes') _card(_row(Icons.search, t('検索', 'Search'))),
      ...rows.map((row) => _card(_row(row.$1, row.$2))),
      const SizedBox(height: 12),
      _cta(c, t('追加', 'Add'), icon: Icons.add),
    ]);
  }


  Widget _legal(ColorScheme c) => _list([
    _heading(entry.label(ja)),
    ...List.generate(9, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${i + 1}.  ${t('ご利用にあたっての案内', 'Usage information')}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t('本アプリの機能・保存データの取り扱いについて、'
            '各項目に記載された条件をご確認ください。',
            'Review the application terms and data handling information.'),
            style: TextStyle(fontSize: 10,
              color: c.onSurfaceVariant)),
        ]))),
  ]);

  Widget _communityWork(ColorScheme c) => _list([
    _art(c, height: 200),
    _heading(t('サンプル作品', 'Sample artwork')),
    _card(_row(Icons.person, t('作者の名前', 'Creator name'))),
    _card(Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        Icon(Icons.favorite_border),
        Icon(Icons.bookmark_border),
        Icon(Icons.share),
        Icon(Icons.more_horiz),
      ])),
    _heading(t('作品について', 'About this work')),
    _card(Text(t('手描きアニメーションです。', 'Hand-drawn animation.'))),
    _card(Text('#animation   #illustration',
      style: TextStyle(color: c.primary))),
  ]);

  Widget _author(ColorScheme c) => Column(children: [
    SizedBox(height: 128, child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_circle, size: 52, color: c.primary),
        Text(t('作者の名前', 'Creator name'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _cta(c, t('フォローする', 'Follow'), icon: Icons.person_add_alt_1)),
    const SizedBox(height: 12),
    Expanded(child: GridView.count(crossAxisCount: 2, childAspectRatio: .9,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        _projectTile(c, t('作品 1', 'Work 1')),
        _projectTile(c, t('作品 2', 'Work 2')),
        _projectTile(c, t('作品 3', 'Work 3')),
      ])),
  ]);

  Widget _myWorks(ColorScheme c) => _list([
    _heading(t('自分の投稿', 'My posts')),
    _card(_row(Icons.upload_file, t('投稿した作品 1', 'Posted work 1'),
      subtitle: t('公開中', 'Published'))),
    _card(_row(Icons.upload_file, t('投稿した作品 2', 'Posted work 2'),
      subtitle: t('公開中', 'Published'))),
    const SizedBox(height: 18),
    _cta(c, t('新しく投稿', 'Post new work'), icon: Icons.add),
  ]);


  Widget _shared(ColorScheme c) => Column(children: [
    Container(height: 45, padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(children: [
        const Icon(Icons.sort, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(t('更新日時順', 'Last updated'),
          style: const TextStyle(fontSize: 12))),
        Icon(Icons.star_border, size: 19, color: c.primary),
      ])),
    Expanded(child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10), crossAxisCount: 2,
      childAspectRatio: .9,
      children: [
        _projectTile(c, t('共有アニメ', 'Shared animation')),
        _projectTile(c, t('練習作品', 'Practice')),
      ])),
    const SizedBox(height: 15),
  ]);

  Widget _trash(ColorScheme c) => Column(children: [
    Container(height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: Text(t('更新日時順', 'Last updated'),
          style: const TextStyle(fontSize: 11))),
        const Icon(Icons.arrow_downward, size: 16),
      ])),
    Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, size: 44, color: c.primary),
        const SizedBox(height: 12),
        Text(t('ゴミ箱は空です', 'Trash is empty'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]))),
  ]);

  Widget _widgetFrame(ColorScheme c) => Column(children: [
    const SizedBox(height: 14),
    Text(t('表示するフレームを選んでください', 'Choose frame to display'),
      style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
    Expanded(child: Center(child: AspectRatio(
      aspectRatio: 16 / 9, child: _art(c, height: 180)))),
    const Text('1 / 24', style: TextStyle(fontWeight: FontWeight.bold)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Slider(value: .14, onChanged: null)),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Icon(Icons.skip_previous), Icon(Icons.play_arrow),
          Icon(Icons.skip_next)])),
    SizedBox(height: 76, child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      children: List.generate(7, (i) => Container(
        width: 60, margin: const EdgeInsets.all(5),
        alignment: Alignment.center,
        color: i == 0 ? c.secondary : c.surfaceContainer,
        child: Text((i + 1).toString(), style: TextStyle(
          color: i == 0 ? c.onSecondary : c.onSurface,
        )),
      )))),
    Padding(padding: const EdgeInsets.all(12),
      child: _cta(c, t('このフレームを選択', 'Select this frame'))),
  ]);

  // SCREEN_LAYOUTS



}
