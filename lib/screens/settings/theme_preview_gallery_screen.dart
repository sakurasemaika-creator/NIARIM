import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/theme_service.dart';
import '../../utils/color_contrast.dart';

/// Lightweight preview of main creation and community screens only.
/// Tab variants, settings/management pages, menus and floating panels are
/// excluded. Export completion is kept as a requested dialog exception.
class ThemePreviewEntry {
  final String id, ja, en, layout;
  const ThemePreviewEntry(this.id, this.ja, this.en, this.layout);
  String label(bool japanese) => japanese ? ja : en;
}

/// Show only frequently used creation and community screens. Home tabs
/// (Shared/Trash) are represented by Projects, and infrequent settings,
/// help, legal and administration screens do not need theme samples.
const List<ThemePreviewEntry> themePreviewEntries = [
  ThemePreviewEntry('splash','起動画面','Splash','splash'),
  ThemePreviewEntry('projects','プロジェクト一覧','Projects','projects'),
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
        Text(label, style: TextStyle(color: c.onPrimary,
          fontFamily: 'Kuramubon', fontWeight: FontWeight.bold)),
      ]));
  Widget _art(ColorScheme c, {double height = 150}) => Container(
    height: height, color: c.surfaceContainerHigh,
    alignment: Alignment.center,
    child: Icon(Icons.movie_creation_outlined, size: 52, color: c.onSurfaceVariant));

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (entry.layout == 'splash') return _splash(context, c);
    if (entry.layout == 'community') return _community(c);
    if (entry.layout == 'projects') return _projects(c);
    if (entry.layout == 'author') return _author(c);
    if (entry.layout == 'mine') return _myWorks(c);
    if (entry.layout == 'canvas') return _canvas(c);
    if (entry.layout == 'timeline') return _timeline(c);
    if (entry.layout == 'complete') return _complete(c);
    const helpScreens = <String>{'new', 'detail', 'export', 'materials', 'save'};
    const menuScreens = <String>{
      'projects', 'detail', 'community',
      'author',
    };
    final appTitle = switch (entry.id) {
      'detail' => t('all-route-audit', 'all-route-audit'),
      'work' => t('作品詳細', 'Work details'),
      'post' => t('作品を投稿', 'Post artwork'),
      'notifications' => t('フォロー通知', 'Follow notifications'),
      'widget_frame' => t('練習作品', 'Practice'),
      'projects' => t('プロジェクト一覧', 'Projects'),
      'save' => t('セーブスロット', 'Save slots'),
      'new' => t('新規プロジェクト', 'New project'),
      'tips' => t('活用Tips', 'Tips'),
      'widget_art' => t('ウィジェット作品選択', 'Widget artwork'),
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
        leading: const <String>{
          'new', 'detail', 'export', 'materials', 'save', 'work', 'settings',
        }.contains(entry.id) ? null : const Icon(Icons.arrow_back),
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
      case 'materials': return _catalog(c);
      case 'widget_art': return _widgetArtwork(c);
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
      case 'workspace': return entry.id == 'pc_layout' ? _pcLayout(c) : _workspace(c);
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

  Widget _projects(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: const Icon(Icons.menu),
      titleSpacing: 0,
      title: Row(children: [

        Flexible(child: Text(t('更新日時', 'Modified'),
          style: const TextStyle(fontSize: 16,
            fontFamily: 'Kuramubon', fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        const Icon(Icons.arrow_drop_down, size: 20),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_downward, size: 20),
      ]),
      actions: [
        const Icon(Icons.grid_view, size: 21),
        const SizedBox(width: 14),
        const Icon(Icons.search, size: 22),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: SizedBox(height: 45, child: Row(children: [
          for (final tab in [
            t('プロジェクト', 'Projects'), t('作品一覧', 'Works'),
            t('ブクマ済み', 'Bookmarks'),
          ]) Expanded(child: Column(children: [
            Expanded(child: Center(child: Text(tab, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              color: tab == t('プロジェクト', 'Projects')
                ? contrastingForeground(opaqueOver(c.surface, Colors.black), c.primary)
                : c.onSurfaceVariant)))),
            Container(height: 2, color: tab == t('プロジェクト', 'Projects')
                ? c.primary : Colors.transparent),
          ])),
        ])),
      ),
    ),
    body: Stack(children: [
      Column(children: [
        Align(alignment: Alignment.topLeft, child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 7, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24)),
            child: Text(t('お気に入り', 'Favorites'),
              style: const TextStyle(fontFamily: 'Kuramubon', fontSize: 11,
                fontWeight: FontWeight.w700)),
          ),
        )),
        Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 36,
              backgroundColor: c.primary.withValues(alpha: .13),
              child: Icon(Icons.movie_creation_outlined,
                size: 31, color: c.primary)),
            const SizedBox(height: 13),
            Text(t('プロジェクトがありません', 'No projects'),
              style: const TextStyle(fontFamily: 'Kuramubon',
                fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text(t('＋ボタンから新規作成', 'Create with the + button'),
              style: TextStyle(
                fontSize: 11, color: c.onSurfaceVariant)),
          ],
        ))),
      ]),
      Positioned(left: 13, bottom: 20,
        child: Container(
          key: const Key('themePreviewHomeBackFab'),
          width: 56, height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: DecoratedBox(decoration: BoxDecoration(
            color: c.primary, shape: BoxShape.circle),
            child: SizedBox(width: 56, height: 56,
              child: Icon(Icons.arrow_back, color: c.onPrimary)))),
      ),
      Positioned(right: 13, bottom: 20,
        child: Container(
          width: 58, height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primary, shape: BoxShape.circle),
          child: Icon(Icons.add, color: c.onPrimary, size: 27))),
    ]),
  );

  Widget _projectTile(ColorScheme c, String title) =>
      Card(clipBehavior: Clip.antiAlias, child: Column(children: [
        Expanded(child: Container(color: c.surfaceContainerHigh,
          alignment: Alignment.center, child: Icon(Icons.movie_creation_outlined,
          size: 42, color: c.primary))),
        Padding(padding: const EdgeInsets.all(9), child: Row(children: [
          Expanded(child: Text(title, maxLines: 1,
            style: const TextStyle(fontSize: 12))),
          Icon(Icons.star_border, color: c.primary, size: 16),
          const Icon(Icons.more_vert, size: 16),
        ])),
      ]));


  Widget _community(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 57, child: Row(children: [
        const SizedBox(width: 14),
        Expanded(child: Text(t('作品広場', 'Community'),
          style: const TextStyle(fontFamily: 'Kuramubon',
            fontSize: 20, fontWeight: FontWeight.w800))),
        Stack(clipBehavior: Clip.none, children: [
          Icon(Icons.notifications_none, size: 25, color: c.onSurface),
          Positioned(right: -4, top: -8,
            child: Container(width: 18, height: 18,
              decoration: BoxDecoration(
                color: c.error, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('4', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: c.onError)))),
        ]),
        const SizedBox(width: 18),
        Icon(Icons.filter_alt_outlined, color: c.onSurface, size: 23),
        const SizedBox(width: 3),
        Text(t('総合', 'All'), style: const TextStyle(fontSize: 12)),
        Icon(Icons.arrow_drop_down, color: c.onSurface, size: 19),
        const SizedBox(width: 16),
        Icon(Icons.visibility_off_outlined, color: c.onSurface, size: 23),
        const SizedBox(width: 18),
        Icon(Icons.search, color: c.onSurface, size: 23),
        const SizedBox(width: 16),
        Icon(Icons.help_outline, color: c.onSurface, size: 23),
        const SizedBox(width: 12),
      ])),
      SizedBox(height: 44, child: Row(children: [
        for (final tab in [
          t('新着', 'New'),
          t('ランキング', 'Ranking'),
          t('フォロー中', 'Following'),
        ])
          Expanded(child: Column(children: [
            Expanded(child: Center(child: Text(tab,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: tab == t('新着', 'New')
                  ? c.primary : c.onSurfaceVariant)))),
            Container(width: 30, height: 3,
              decoration: BoxDecoration(
                color: tab == t('新着', 'New')
                  ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(3))),
          ])),
      ])),
      Divider(height: 1, thickness: .5, color: c.outlineVariant),
      Expanded(child: Stack(children: [
        GridView.count(
          key: const Key('themePreviewCommunityWorks'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          crossAxisCount: 2, mainAxisSpacing: 18,
          crossAxisSpacing: 20, childAspectRatio: .75,
          children: List.generate(8, (i) {
            final label = [
              t('雨上がりの約束', 'After the rain'),
              t('夜明けの冒険', 'Dawn adventure'),
              t('雨上がりの約束', 'After the rain'),
              t('最後のメロディ', 'Last melody'),
            ][i % 4];
            final accent = i.isEven
              ? const Color(0xFFFF8BA7) : const Color(0xFFD0A875);
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.onSurface, width: 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 9, child: Stack(children: [
                    Positioned.fill(child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          accent.withValues(alpha: .55), accent,
                        ], begin: Alignment.topLeft,
                          end: Alignment.bottomRight)))),
                    Center(child: Container(
                      height: 40, width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.onSurface.withValues(alpha: .9)),
                      child: Icon(Icons.play_arrow,
                        size: 25, color: c.surface))),
                    Positioned(right: 5, top: 5,
                      child: Container(
                        width: 43, height: 43,
                        decoration: BoxDecoration(
                          color: c.onSurface.withValues(alpha: .9),
                          shape: BoxShape.circle),
                        child: Icon(Icons.bookmark_border,
                          size: 25, color: c.surface))),
                    Positioned(right: 5, bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                        color: c.onSurface.withValues(alpha: .85),
                        child: Text(i.isEven ? '1:25' : '1:40',
                          style: TextStyle(color: c.surface, fontSize: 9)))),
                  ])),
                  Expanded(flex: 12, child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 12),
                        Text(t('サンプル作者', 'Sample artist'),
                          style: TextStyle(fontSize: 10,
                            color: c.onSurfaceVariant)),
                        const Spacer(),
                        Row(children: [
                          Icon(Icons.play_arrow, size: 11,
                            color: c.onSurfaceVariant),
                          Text('16,998', style: TextStyle(
                            fontSize: 10, color: c.onSurfaceVariant)),
                          const SizedBox(width: 9),
                          Icon(Icons.bookmark, size: 10,
                            color: c.onSurfaceVariant),
                          Text('278', style: TextStyle(
                            fontSize: 10, color: c.onSurfaceVariant)),
                        ]),
                      ],
                    )),
                  ),
                ]),
            );
          }),
        ),
        Positioned(bottom: 18, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 17, vertical: 14),
            decoration: BoxDecoration(
              color: c.primary, borderRadius: BorderRadius.circular(36),
              border: Border.all(color: c.onSurface, width: 3)),
            child: Row(children: [
              Icon(Icons.video_library_outlined,
                size: 22, color: c.onPrimary),
              const SizedBox(width: 8),
              Text(t('自分の投稿', 'My posts'),
                style: TextStyle(color: c.onPrimary,
                  fontWeight: FontWeight.w700)),
            ]),
          )),
      ])),
    ])),
  );

  Widget _canvas(ColorScheme c) => Scaffold(
    key: const Key('themePreviewCanvasScaffold'),
    // Match the real canvas outer area. Bars have transparent backgrounds.
    backgroundColor: c.surfaceContainerHighest,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 43, child: Row(children: [
        const SizedBox(width: 8),
        _mockTool(c, Icons.undo),
        _mockTool(c, Icons.redo),
        const Spacer(),
        _mockTool(c, Icons.settings),
        _mockTool(c, Icons.home_outlined),
        _mockTool(c, Icons.movie_filter_outlined),
        const SizedBox(width: 8),
      ])),
      // No project instance, image decoding, or raster engine. The real
      // initial canvas shows a landscape paper and collapsed brush settings.
      Expanded(child: Container(
        key: const Key('themePreviewCanvasViewport'),
        color: c.surfaceContainerHigh,
        child: LayoutBuilder(builder: (_, bounds) {
          final paperWidth = bounds.maxWidth;
          return Center(child: SizedBox(
            key: const Key('themePreviewCanvasPaper'),
            width: paperWidth,
            height: (paperWidth * 9 / 16).clamp(1.0, bounds.maxHeight),
            child: const ColoredBox(color: Colors.white),
          ));
        }),
      )),
      SizedBox(height: 32, child: Row(children: [
        const SizedBox(width: 12),
        Icon(Icons.circle, size: 7, color: c.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('5', style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
        const SizedBox(width: 8),
        Icon(Icons.opacity, size: 12, color: c.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('100%', style: TextStyle(fontSize: 10,
          color: c.onSurfaceVariant)),
        const Spacer(),
        Text(t('詳細', 'Details'), style: TextStyle(
          fontSize: 10, color: c.onSurfaceVariant)),
        const Icon(Icons.keyboard_arrow_down, size: 17),
        const SizedBox(width: 8),
      ])),
      SizedBox(height: 25, child: Center(child:
        Icon(Icons.keyboard_arrow_down, size: 19, color: c.onSurfaceVariant))),
      SizedBox(height: 50, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mockTool(c, Icons.brush, active: true),
          _mockTool(c, Icons.auto_fix_off),
          _mockTool(c, Icons.format_color_fill),
          _mockTool(c, Icons.colorize),
          _mockTool(c, Icons.pan_tool),
          _mockTool(c, Icons.select_all),
          _mockTool(c, Icons.text_fields),
          _mockTool(c, Icons.category),
          Container(height: 25, width: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: c.outlineVariant, width: 2))),
          _mockTool(c, Icons.tune),
          _mockTool(c, Icons.layers_outlined),
        ])),
      SizedBox(height: 22, child: Center(child:
        Icon(Icons.keyboard_arrow_down, size: 19, color: c.onSurfaceVariant))),
      Container(
        key: const Key('themePreviewCanvasFrameStrip'),
        height: 58, padding: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.transparent,
        child: Row(children: [
          ...List.generate(4, (i) => Container(
            width: 49, margin: const EdgeInsets.fromLTRB(1, 5, 0, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: i == 0 ? c.primary : c.outlineVariant,
                width: i == 0 ? 2 : 1)),
          )),
          const Spacer(),
          _mockTool(c, Icons.movie_filter_outlined),
          _mockTool(c, Icons.chevron_right),
        ])),
    ])),
  );

  Widget _timeline(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 56, child: Row(children: [
        _mockTool(c, Icons.arrow_back),
        _mockTool(c, Icons.palette_outlined),
        Expanded(child: Text('all-route-audit',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15,
            fontFamily: 'Kuramubon', fontWeight: FontWeight.bold))),
        _mockTool(c, Icons.home_outlined),
        _mockTool(c, Icons.undo),
        _mockTool(c, Icons.redo),
        _mockTool(c, Icons.more_vert),
        _mockTool(c, Icons.help_outline),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ClipRRect(borderRadius: BorderRadius.circular(3),
          child: AspectRatio(
            key: const Key('themePreviewTimelinePaper'),
            aspectRatio: 16 / 9,
            child: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Colors.white)),
              Positioned(top: 4, right: 4,
                child: Icon(Icons.fullscreen, size: 18,
                  color: c.onSurfaceVariant)),
              Positioned(bottom: 6, left: 8,
                child: Text('10/100', key: const Key('themePreviewFrameCounter'),
                  style: TextStyle(color: c.onSurface, fontSize: 11,
                    fontWeight: FontWeight.w700))),
              Positioned(bottom: 2, right: 4,
                child: Icon(Icons.repeat,
                  key: const Key('themePreviewLoopButton'),
                  size: 24, color: c.primary)),
            ]),
          ))),
      // The resize grip has no time labels beside it.
      SizedBox(height: 22, child: Center(child: Container(
        key: const Key('themePreviewResizeGrip'),
        width: 40, height: 5,
        decoration: BoxDecoration(color: c.outlineVariant,
          borderRadius: BorderRadius.circular(3))))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _mockSlider(c, position: .09, height: 43)),
      SizedBox(height: 58, child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth / 7 < 48
              ? constraints.maxWidth / 7 : 48.0;
          Widget transport(IconData icon, String key) => SizedBox(
            key: Key(key),
            width: buttonWidth,
            height: buttonWidth,
            child: Center(child: _mockTool(c, icon)),
          );
          return Row(children: [
            Expanded(child: Align(alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown,
                child: Text('0.4s',
                  key: const Key('themePreviewCurrentSeconds'),
                  style: TextStyle(fontSize: 11,
                    color: c.onSurfaceVariant))))),
            transport(Icons.skip_previous, 'themePreviewSkipPrevious'),
            transport(Icons.fast_rewind, 'themePreviewFastRewind'),
            transport(Icons.play_arrow, 'themePreviewPlay'),
            transport(Icons.fast_forward, 'themePreviewFastForward'),
            transport(Icons.skip_next, 'themePreviewSkipNext'),
            Expanded(child: Align(alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown,
                child: Text('4.2s',
                  key: const Key('themePreviewTotalSeconds'),
                  style: TextStyle(fontSize: 11,
                    color: c.onSurfaceVariant))))),
          ]);
        },
      )),
      Container(height: 1, color: c.outlineVariant),
      SizedBox(height: 40, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _mockTool(c, Icons.add_circle_outline),
          _mockTool(c, Icons.video_collection_outlined),
          _mockTool(c, Icons.movie_outlined),
          _mockTool(c, Icons.camera_outlined),
          _mockTool(c, Icons.push_pin_outlined),
          _mockTool(c, Icons.layers_outlined),
          _mockTool(c, Icons.note_add_outlined),
        ])),
      Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 8),
        color: c.surfaceContainerLow, child: Row(children: [
          Text(t('選択', 'Select'), style: TextStyle(fontSize: 11,
            color: c.primary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.primary, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              Icon(Icons.check, size: 12, color: c.onPrimary),
              const SizedBox(width: 5),
              Text('Scene1', style: TextStyle(fontSize: 11,
                color: c.onPrimary, fontFamily: 'Kuramubon',
                fontWeight: FontWeight.bold)),
            ])),
          const SizedBox(width: 12),
          _mockTool(c, Icons.more_vert),
          _mockTool(c, Icons.add),
        ])),
      Container(key: const Key('themePreviewTimelineTracks'),
        height: 44, color: c.surface,
        child: Row(children: [
          SizedBox(width: 100, child: Row(children: [
            _mockTool(c, Icons.movie_filter_outlined),
            Expanded(child: Text(t('フレーム', 'Frames'),
              style: const TextStyle(fontSize: 10,
                fontFamily: 'Kuramubon'))),
          ])),
          ...List.generate(5, (i) => Expanded(child: Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: i == 0 ? c.primary : c.outlineVariant,
                width: i == 0 ? 2 : 1),
              borderRadius: BorderRadius.circular(3)),
            child: Text((i + 1).toString(),
              style: const TextStyle(fontSize: 8)),
          ))),
        ])),
      Expanded(child: ClipRect(child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(children: [
          _previewMaterialTrack(c, Icons.layers_outlined,
            t('共通レイヤー', 'Shared layer'), 0),
          _previewMaterialTrack(c, Icons.text_fields,
            t('テキスト', 'Text'), 1),
          _previewMaterialTrack(c, Icons.image_outlined,
            t('画像', 'Image'), 2),
          _previewMaterialTrack(c, Icons.movie_outlined,
            t('動画', 'Video'), 3),
          _previewMaterialTrack(c, Icons.music_note,
            t('音声', 'Audio'), 4),
          _previewMaterialTrack(c, Icons.camera_outlined,
            t('カメラ', 'Camera'), 5),
          _previewMaterialTrack(c, Icons.more_time,
            t('タイムスタンプ', 'Timestamp'), 6),
          _previewMaterialTrack(c, Icons.auto_fix_high,
            t('演出フィルター', 'Effects'), 7),
          _previewMaterialTrack(c, Icons.movie_filter_outlined,
            t('エンドカード', 'End card'), 8),
        ])),
      )),
    ])),
  );

  Widget _previewMaterialTrack(ColorScheme c, IconData icon,
      String label, int index) => SizedBox(
    key: Key('themePreviewMaterialTrack$index'),
    height: 18,
    child: Row(children: [
      SizedBox(width: 112, child: Row(children: [
        const SizedBox(width: 6),
        Icon(icon, size: 11, color: c.onSurfaceVariant),
        const SizedBox(width: 3),
        Expanded(child: Text(label, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 8, color: c.onSurface))),
      ])),
      Expanded(child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
        decoration: BoxDecoration(
          color: index.isEven ? c.primaryContainer : c.tertiaryContainer,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: c.outlineVariant)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 5),
        child: Text(index == 4 ? '♪ sample.wav'
          : index == 2 ? 'sample.png'
          : index == 3 ? 'sample.mp4'
          : label, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 8,
            color: index.isEven ? c.onPrimaryContainer
              : c.onTertiaryContainer)),
      )),
    ]),
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

  Widget _complete(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(t('書き出し', 'Export')),
      actions: [Icon(Icons.help_outline, color: c.onSurface)]),
    body: Stack(children: [
      Positioned.fill(child: _export(c)),
      Positioned.fill(child: ColoredBox(
        color: Colors.black.withValues(alpha: .46))),
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          elevation: 0,
          color: c.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide.none),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('書き出し完了', 'Export complete'),
                  style: const TextStyle(fontSize: 21,
                    fontFamily: 'Kuramubon', fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Text(t('48フレームを書き出しました', '48 frames exported'),
                  style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Text(t('保存先: animation.mp4', 'Saved to animation.mp4'),
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(t('ファイルを端末に保存する場合は「共有」から保存先を選択してください。',
                  'Choose a destination from Share to save on your device.'),
                  style: TextStyle(
                    fontSize: 11, color: c.onSurfaceVariant)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(child: Text(t('プロジェクト一覧へ',
                    'Back to projects'), style: TextStyle(
                      fontSize: 12, fontFamily: 'Kuramubon', color: c.primary))),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17, vertical: 10),
                    decoration: BoxDecoration(color: c.primary,
                      borderRadius: BorderRadius.circular(24)),
                    child: Text(t('共有', 'Share'),
                      style: TextStyle(fontFamily: 'Kuramubon', color: c.onPrimary))),
                ]),
              ]),
          ),
        ))),
    ]),
  );

  Widget _form(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      InputDecorator(
        key: const Key('themePreviewMockName'),
        isEmpty: false,
        decoration: InputDecoration(
          labelText: t('プロジェクト名', 'Project name'),
          border: const OutlineInputBorder(),
        ),
        child: Text(t('新規プロジェクト', 'New project')),
      ),
      const SizedBox(height: 24),
      const Text('FPS', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final n in [8, 12, 24])
          ChoiceChip(label: Text('$n'), selected: n == 12,
            onSelected: (_) {}),
      ]),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Text(t('サイズ', 'Canvas size'),
          style: const TextStyle(fontWeight: FontWeight.bold))),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune, size: 18),
          label: Text(t('サイズ設定', 'Size settings')),
        ),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) => Wrap(
        key: const Key('themePreviewMockSizes'),
        spacing: 8, runSpacing: 8,
        children: [
          for (final item in [
            (t('Full HD (16:9・YouTube等横動画向け)', 'Full HD (16:9 landscape)'), '1920×1080'),
            (t('HD (16:9・軽量版)', 'HD (16:9)'), '1280×720'),
            (t('1:1 スクエア (Twitter/Instagram投稿向け)', 'Square (1:1)'), '1080×1080'),
            (t('9:16 縦型 (YouTubeショートリール・ストーリーズ向け)', 'Vertical (9:16)'), '1080×1920'),
            (t('4:5 縦長 (Instagramフィード投稿向け)', 'Portrait (4:5)'), '1080×1350'),
            (t('4:3 (アナログ放送比率)', '4:3 aspect ratio'), '1440×1080'),
          ].asMap().entries)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth),
              child: ChoiceChip(
                label: Text(item.value.$1 + ' (' + item.value.$2 + ')',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
                selected: item.key == 0,
                onSelected: (_) {},
              ),
            ),
          ChoiceChip(label: Text(t('カスタム', 'Custom')),
            selected: false, onSelected: (_) {}),
        ],
      )),
      const SizedBox(height: 12),
      Center(child: Container(width: 160, height: 90,
        color: c.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Text('1920×1080',
          style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)))),
      const SizedBox(height: 24),
      _mockSettingRow(c, Icons.palette_outlined, t('背景色', 'Background')),
      _mockSettingRow(c, Icons.auto_awesome, t('自動塗り', 'Auto fill')),
      const SizedBox(height: 16),
      _cta(c, t('作成', 'Create'), icon: Icons.add),
    ],
  );

  Widget _detail(ColorScheme c) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          key: const Key('themePreviewFakeProjectCanvas'),
          aspectRatio: 16 / 9,
          child: _fakePaper(c),
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 34,
          child: Row(children: [
            Expanded(child: Align(
              alignment: Alignment.centerLeft,
              child: Text('0.1s',
                key: const Key('themePreviewDetailCurrentSeconds'),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)))),
            Text('2/12',
              key: const Key('themePreviewDetailFrameCounter'),
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            const SizedBox(width: 6),
            SizedBox(
              width: 34, height: 34,
              child: Icon(Icons.repeat,
                key: const Key('themePreviewDetailLoopButton'),
                color: c.primary, size: 20)),
            Expanded(child: Align(
              alignment: Alignment.centerRight,
              child: Text('1.0s',
                key: const Key('themePreviewDetailTotalSeconds'),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)))),
          ]),
        ),
      ),
      KeyedSubtree(
        key: const Key('themePreviewDetailSeekBar'),
        child: _mockSlider(c, position: .11, height: 28),
      ),
      Container(
        height: 60,
        decoration: BoxDecoration(
          color: c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _mockTool(c, Icons.skip_previous),
            _mockTool(c, Icons.fast_rewind),
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: Icon(Icons.play_arrow, color: c.onPrimary, size: 30)),
            _mockTool(c, Icons.fast_forward),
            _mockTool(c, Icons.skip_next),
          ])),
      const SizedBox(height: 16),
      _cta(c, t('編集開始', 'Start editing'), icon: Icons.edit),
      const SizedBox(height: 24),
      Row(children: [
        for (final item in [
          (Icons.folder_outlined, t('フォルダ', 'Folder')),
          (Icons.sell_outlined, t('タグ', 'Tags')),
          (Icons.star_border, t('お気に入り\n未登録', 'Favorite\nNot added')),
          (Icons.ios_share, t('共有', 'Share')),
        ])
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(item.$1, size: 24, color: c.onSurfaceVariant),
            const SizedBox(height: 5),
            Text(item.$2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10)),
          ])),
      ]),
      const SizedBox(height: 26),
      Text(t('プロジェクト情報', 'Project information'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (final item in [
            ('FPS', '12'),
            (t('書き出しサイズ', 'Export size'), '320×180'),
            (t('総フレーム数', 'Total frames'), '12'),
            (t('制作時間', 'Editing time'), '0時間0分'),
            (t('最終保存', 'Last saved'), '2026/10/23 10:00'),
            (t('容量', 'Size'), '0B'),
          ])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Text(item.$1, style: TextStyle(fontSize: 11,
                  color: c.onSurfaceVariant)),
                const Spacer(),
                Text(item.$2, style: const TextStyle(fontSize: 11)),
              ])),
        ]))),
    ],
  );

  Widget _export(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      Text(t('プリセット', 'Preset'),
        style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: SegmentedButton<String>(
        segments: [
          ButtonSegment<String>(
            value: 'standard', label: Text(t('標準', 'Standard'))),
          ButtonSegment<String>(
            value: 'high', label: Text(t('高画質', 'High quality'))),
          ButtonSegment<String>(
            value: 'custom', label: Text(t('カスタム', 'Custom'))),
        ],
        selected: const {'standard'}, onSelectionChanged: (_) {},
        showSelectedIcon: true,
      )),
      const SizedBox(height: 24),
      Text(t('形式', 'Format'),
        style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      for (final option in [
        ('MP4', t('汎用動画形式', 'Universal video format')),
        ('GIF', t('アニメーションGIF', 'Animated GIF')),
        (t('透過WebM', 'Transparent WebM'),
          t('透明背景動画', 'Transparent background video')),
        ('AVI', t('高品質動画 (連番非対応)', 'High-quality AVI')),
      ].asMap().entries)
        SizedBox(height: 76, child: Row(children: [
          Icon(option.key == 0
            ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: option.key == 0 ? c.primary : c.onSurfaceVariant,
            size: 21),
          const SizedBox(width: 16),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.value.$1, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(option.value.$2, style: TextStyle(
                fontSize: 11, color: c.onSurfaceVariant)),
            ],
          )),
        ])),
      const SizedBox(height: 24),
      _cta(c, t('書き出し開始', 'Start export'),
        icon: Icons.file_download),
    ],
  );

  Widget _post(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      InputDecorator(
        decoration: InputDecoration(
          labelText: t('作品タイトル', 'Artwork title'),
          counterText: '0/100',
          border: const OutlineInputBorder()),
        child: const SizedBox(height: 20),
      ),
      const SizedBox(height: 20),
      SizedBox(height: 43, child: OutlinedButton.icon(
        onPressed: () {}, icon: const Icon(Icons.video_file_outlined),
        label: Text(t('投稿する動画を選択', 'Select a video')),
      )),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: false, onChanged: (_) {},
        title: Text(t('ショート動画として投稿', 'Post as a short')),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: false, onChanged: (_) {},
        title: Text(t('AI生成画像・動画を含む', 'Contains generative AI')),
        subtitle: Text(t('AIで生成した画像・動画が含まれる場合はオンにしてください。',
          'Enable if the content contains generative AI images or video.'),
          style: const TextStyle(fontSize: 11)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: true, onChanged: (_) {},
        title: Text(t('NIARIM作品広場に公開する',
          'Show in NIARIM community')),
        subtitle: Text(t('作品広場で他のユーザーに公開されます。',
          'Publish to other users in the community.'),
          style: const TextStyle(fontSize: 11)),
      ),
      const SizedBox(height: 16),
      Text(t('説明', 'Description'),
        style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(height: 98, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.outline)),
        alignment: Alignment.topLeft,
        child: Text(t('説明を入力', 'Add a description'),
          style: TextStyle(color: c.onSurfaceVariant))),
      const SizedBox(height: 12),
      _mockSettingRow(c, Icons.sell_outlined, t('タグ', 'Tags')),
      const SizedBox(height: 16),
      _cta(c, t('投稿する', 'Post'), icon: Icons.cloud_upload_outlined),
    ],
  );

  Widget _theme(BuildContext context, ColorScheme c) {
    final preset = context.read<ThemeService>().current;
    return ListView(
      key: const Key('themePreviewContentList'),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Material(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const ThemePreviewThumbnail(height: 184),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('画面プレビュー', 'Screen preview'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(t('プロジェクト一覧の見本', 'Project list sample'),
                      style: TextStyle(
                        fontSize: 12, color: c.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Flexible(child: Text(
                        t('タップして全${themePreviewEntries.length}画面を見る',
                          'Tap to view ${themePreviewEntries.length} screens'),
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: c.primary))),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_full, size: 17, color: c.primary),
                    ]),
                  ],
                )),
              ]),
            ),
          )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(t('カラーカスタマイズ', 'Color customization'),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        for (final item in [
          (t('アクセントカラー', 'Accent'), preset.accentColor),
          (t('本文・通常の文字色', 'Body text'), preset.textColor),
          (t('ボタン内の文字・アイコン色', 'Button text'),
            preset.buttonTextColor),
          (t('メニュー・上部バーの文字色', 'Menu text'),
            preset.menuTextColor),
          (t('選択中の文字・アイコン色', 'Selection text'),
            preset.selectionTextColor),
          (t('パネル背景色', 'Panel background'), preset.panelBgColor),
          (t('メニュー背景色', 'Menu background'), preset.menuBgColor),
          (t('選択色', 'Selection color'), preset.selectionColor),
          (t('更新マーク色', 'Update mark'), preset.updateMarkColor),
        ])
          Padding(padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 4),
            child: Material(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              elevation: 1,
              shadowColor: c.shadow.withValues(alpha: .15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.$2,
                      border: Border.all(color: c.outlineVariant))),
                  const SizedBox(width: 14),
                  Expanded(child: Text(item.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14))),
                  Icon(Icons.chevron_right,
                    size: 18, color: c.onSurfaceVariant),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _settings(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      for (final item in [
        (Icons.settings, t('基本', 'Basic'),
          t('FPS・背景色・言語', 'FPS, background and language')),
        (Icons.speed, t('パフォーマンス', 'Performance'),
          t('画質設定・Undo回数・ゴミ箱・動作の軽さ', 'Quality, undo, trash and speed')),
        (Icons.touch_app, t('ジェスチャー', 'Gestures'),
          t('2本指タップ・長押し', 'Multi-touch and long press')),
        (Icons.keyboard, t('ショートカット設定', 'Shortcuts'),
          t('キーボード・左手デバイスにツールや操作を割り当て', 'Keyboard bindings')),
        (Icons.edit, t('ペン入力', 'Pen input'),
          t('筆圧・傾き・ペンボタン', 'Pressure, tilt and buttons')),
        (Icons.desktop_windows, t('ワークスペース', 'Workspace'),
          t('ツールバー配置・パネル配置', 'Toolbar and panels')),
        (Icons.format_color_fill, t('バケツ塗り', 'Bucket fill'),
          t('許容誤差・拡張・線の下まで塗る', 'Tolerance and gap closure')),
        (Icons.widgets_outlined, t('ホーム画面ウィジェット', 'Home widgets'),
          t('表示作品・タップ動作', 'Artwork and actions')),
        (Icons.palette, t('テーマ・外観', 'Theme & appearance'),
          t('テーマ配色・文字色・背景色', 'Theme colors and backgrounds')),
        (Icons.lock_outline, t('ウォーターマーク', 'Watermark'),
          t('カスタムウォーターマーク', 'Custom watermark')),
        (Icons.import_export, t('引き継ぎ', 'Transfer'),
          t('プロジェクトのエクスポート・インポート', 'Export and import')),
        (Icons.font_download_outlined, t('フォント管理', 'Font management'),
          t('文字入れフォント', 'Text fonts')),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            shadowColor: c.shadow.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        c.primary.withValues(alpha: 0.22),
                        c.primary.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                  child: Icon(item.$1, color: c.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(item.$3, style: TextStyle(
                      fontSize: 12, color: c.onSurfaceVariant),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
                Icon(Icons.chevron_right, color: c.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      const Divider(height: 24),
      Center(child: Text(t('利用規約・ライセンス', 'Terms and licenses'),
        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
    ],
  );

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
        return ListView(
          key: const Key('themePreviewContentList'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              color: c.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                for (final item in [
                  (t('2本指タップ', 'Two-finger tap'),
                    t('取り消し (Undo)', 'Undo')),
                  (t('3本指タップ', 'Three-finger tap'),
                    t('やり直し (Redo)', 'Redo')),
                  (t('4本指以上のタップ', 'Four-finger tap'),
                    t('何もしない', 'No action')),
                  (t('2本指スワイプ左右', 'Two-finger swipe'),
                    t('フレーム移動', 'Frame movement')),
                  (t('長押し', 'Long press'),
                    t('スポイト', 'Eyedropper')),
                ].asMap().entries) ...[
                  if (item.key > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(item.value.$1),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(item.value.$2, style: TextStyle(color: c.primary)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: c.primary, size: 20),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(t('長押しスポイト', 'Hold eyedropper'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: c.onSurfaceVariant)),
            ),
            Card(
              elevation: 1,
              color: c.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                SwitchListTile(
                  title: Text(t('長押しでスポイトを起動', 'Eyedropper on hold')),
                  subtitle: Text(t('キャンバスを長押し',
                    'Touch and hold on the canvas'),
                    style: const TextStyle(fontSize: 11)),
                  value: true, onChanged: (_) {},
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text(t('長押し時間', 'Hold duration'))),
                      Text(t('0.5秒', '0.5 s')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.remove_circle_outline, size: 22),
                      Expanded(child: Slider(value: .5, min: .2, max: 3,
                        onChanged: (_) {})),
                      const Icon(Icons.add_circle_outline, size: 22),
                    ]),
                  ]),
                ),
              ]),
            ),
          ],
        );
      
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
        return ListView(
          key: const Key('themePreviewContentList'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(t('パームリジェクション', 'Palm rejection'),
              style: TextStyle(fontWeight: FontWeight.w700,
                color: c.onSurfaceVariant)),
            Card(
              elevation: 1, color: c.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                title: Text(t('パームリジェクション', 'Palm rejection')),
                subtitle: Text(t('ペン使用中は指による誤操作を防ぎます。',
                  'Prevent accidental touch during pen input.'),
                  style: const TextStyle(fontSize: 11)),
                value: true, onChanged: (_) {},
              ),
            ),
            const SizedBox(height: 20),
            Text(t('筆圧カーブ', 'Pressure curve'),
              style: TextStyle(fontWeight: FontWeight.w700,
                color: c.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(t('弱い筆圧から筆圧の上がり方を調整します。',
              'Configure pen pressure response.'),
              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
            const SizedBox(height: 8),
            _staticChoiceRow(c, [
              t('弱', 'Weak'), t('普通', 'Normal'),
              t('強', 'Strong'), t('カスタム', 'Custom')], active: 1),
            const SizedBox(height: 8),
            Text(t('筆圧の「サイズ／不透明度に反映」の曲線は、'
              '選択したブラシごとの個別設定でも変更できます。',
              'Brush-specific pressure curves may be edited separately.'),
              style: TextStyle(fontSize: 10, color: c.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(t('この設定で試し描きができます',
                  'Try drawing with these settings'),
                style: TextStyle(fontSize: 10, color: c.onSurfaceVariant))),
              Text(t('クリア', 'Clear'),
                style: TextStyle(fontSize: 11, color: c.primary)),
            ]),
            const SizedBox(height: 6),
            Container(height: 118,
              decoration: BoxDecoration(
                color: c.surfaceContainerHigh,
                border: Border.all(color: c.outlineVariant),
                borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text(t('ペンボタン設定', 'Pen buttons'),
              style: TextStyle(fontWeight: FontWeight.w700,
                color: c.onSurfaceVariant)),
            Card(
              elevation: 1, color: c.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                ListTile(
                  title: Text(t('ボタン1', 'Button 1')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t('消しゴム切替', 'Eraser'),
                      style: TextStyle(color: c.primary)),
                    Icon(Icons.chevron_right, color: c.primary),
                  ]),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(t('ボタン2', 'Button 2')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t('スポイト', 'Eyedropper'),
                      style: TextStyle(color: c.primary)),
                    Icon(Icons.chevron_right, color: c.primary),
                  ]),
                ),
              ]),
            ),
          ],
        );
      
      case 'bucket':
        return ListView(
          key: const Key('themePreviewContentList'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in [
              (t('許容誤差', 'Color tolerance'), t('タップした位置の色から'
                'どこまでの色を同じと判定するかを調整します。',
                'Choose how far the fill extends beyond the selected color'),
                '30', .30),
              (t('拡張', 'Expansion'), t('塗った領域を境界線の外側へ'
                '指定pxだけ広げます。', 'Expand painted area by a given number of pixels.'),
                '0', .03),
            ]) ...[
              Row(children: [
                Text(item.$1, style: const TextStyle(
                  fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(item.$3, style: TextStyle(fontSize: 12,
                  color: c.onSurfaceVariant)),
              ]),
              const SizedBox(height: 7),
              Text(item.$2, style: TextStyle(fontSize: 11,
                color: c.onSurfaceVariant)),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.remove_circle_outline,
                  color: c.onSurfaceVariant, size: 23),
                Expanded(child: Slider(value: item.$4, onChanged: (_) {})),
                Icon(Icons.add_circle_outline,
                  color: c.onSurfaceVariant, size: 23),
              ]),
              const SizedBox(height: 16),
            ],
            Card(
              elevation: 1, color: c.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                title: Text(t('線の下まで潜る', 'Extend beneath line')),
                subtitle: Text(t('線と塗りの境界を自然につなぐため、'
                  '線の下へ塗りを拡張します。',
                  'Expand filled color beneath the outline.'),
                  style: const TextStyle(fontSize: 11)),
                value: false, onChanged: (_) {},
              ),
            ),
          ],
        );
      
      default:
        return _list([_mockSettingRow(c, Icons.tune,
          entry.label(ja))]);
    }
  }


  Widget _pcLayout(ColorScheme c) {
    Widget orderPanel(String title, String hint, List<String> labels) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(hint, style: TextStyle(
          fontSize: 11, color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Card(
          color: c.surfaceContainerLow,
          elevation: 1,
          child: Column(children: [
            for (final label in labels)
              ListTile(
                title: Text(label),
                trailing: Icon(Icons.drag_handle,
                  color: c.onSurfaceVariant)),
            Align(alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
                child: Text(t('順序をリセット', 'Reset order'),
                  style: TextStyle(
                    fontSize: 12, color: c.primary)))),
          ]),
        ),
      ]);
    return ListView(
      key: const Key('themePreviewContentList'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('PCモードのパネルをドラッグして順番を変更できます。',
          'Change the order of desktop panels.'),
          style: TextStyle(
            fontSize: 12, color: c.onSurfaceVariant)),
        const SizedBox(height: 20),
        orderPanel(
          t('ツールオプション配置', 'Tool options'),
          t('左側に並ぶツールオプションの順番', 'Left dock order'),
          [t('ブラシ', 'Brush'), t('消しゴム', 'Eraser'),
           t('バケツ', 'Bucket'), t('選択', 'Selection')]),
        const SizedBox(height: 20),
        orderPanel(
          t('右パネル配置', 'Right dock'),
          t('右側のパネルをドラッグして並べ替え', 'Right dock order'),
          [t('レイヤー', 'Layers'), t('カラー', 'Colors'),
           t('履歴', 'History')]),
        const SizedBox(height: 20),
        Text(t('パネル幅', 'Panel width'),
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: c.onSurfaceVariant)),
        Card(
          color: c.surfaceContainerLow,
          child: Column(children: [
            ListTile(title: Text(t('ツールパネル幅', 'Tool dock width')),
              trailing: const Text('280px')),
            ListTile(title: Text(t('右パネル幅', 'Right dock width')),
              trailing: const Text('280px')),
            Align(alignment: Alignment.centerRight,
              child: Padding(padding: const EdgeInsets.all(10),
                child: Text(t('幅をリセット', 'Reset width'),
                  style: TextStyle(color: c.primary)))),
          ]),
        ),
      ],
    );
  }

  Widget _widgetArtwork(ColorScheme c) => Column(children: [
    Padding(padding: const EdgeInsets.all(8),
      child: Card(
        color: c.surfaceContainerHigh,
        child: ListTile(
          leading: Icon(Icons.block_outlined, color: c.onSurfaceVariant),
          title: Text(t('選ばない', 'Do not select')),
        )),
    ),
    Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: [
        _mockChip(c, t('お気に入りのみ', 'Favorites only')),
        const Spacer(),
        Text(t('プロジェクト', 'Projects'),
          style: TextStyle(fontSize: 11,
            color: c.onSurfaceVariant)),
        const Icon(Icons.chevron_right, size: 18),
      ])),
    Expanded(child: GridView.count(
      key: const Key('themePreviewWidgetArtworkProjects'),
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: .90,
      children: [
        for (final text in [
          t('練習作品', 'Practice'), t('新作', 'New work'),
        ])
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              border: Border.all(color: c.outlineVariant),
              borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              const Expanded(
                child: ColoredBox(color: Colors.white,
                  child: SizedBox.expand())),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: Text(text,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11))),
                  Icon(Icons.more_vert, size: 16,
                    color: c.onSurfaceVariant),
                ])),
            ]),
          ),
      ]),
    ),
  ]);

  Widget _workspace(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      Text(t('ツールバー編集', 'Toolbar editor'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 4),
      Text(t('表示するツールをチェックでオンオフし、ドラッグで並び替えできます。',
        'Toggle and reorder visible tools.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 10),
      Container(
        height: 45, padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final icon in [
              Icons.brush, Icons.auto_fix_off, Icons.format_color_fill,
              Icons.colorize, Icons.back_hand_outlined,
              Icons.select_all, Icons.text_fields, Icons.category,
            ]) Icon(icon, size: 22, color: c.onSurface),
          ]),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          for (final item in [
            (Icons.brush, t('Gペン', 'G pen')),
            (Icons.auto_fix_off, t('消しゴム', 'Eraser')),
            (Icons.format_color_fill, t('バケツ', 'Bucket')),
            (Icons.colorize, t('スポイト', 'Eyedropper')),
            (Icons.back_hand_outlined, t('指', 'Finger')),
            (Icons.pan_tool, t('手のひら', 'Pan hand')),
            (Icons.select_all, t('選択', 'Selection')),
            (Icons.text_fields, t('テキスト', 'Text')),
            (Icons.category, t('図形', 'Shapes')),
          ]) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: SizedBox(height: 46, child: Row(children: [
              Icon(Icons.check_box, size: 20, color: c.primary),
              const SizedBox(width: 12),
              Icon(item.$1, color: c.onSurface, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(item.$2,
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700))),
              Icon(Icons.drag_handle, color: c.primary, size: 20),
            ])),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      _mockSettingRow(c, Icons.back_hand_outlined,
        t('左利きモード', 'Left-handed mode')),
      _mockSettingRow(c, Icons.desktop_windows,
        t('PCモード', 'PC mode')),
      _mockSettingRow(c, Icons.dashboard_outlined,
        t('パネル配置', 'Panel placement')),
    ],
  );

  Widget _storage(ColorScheme c) {
    Widget action(IconData icon, String title, {
      String? subtitle, bool warning = false, bool inactive = false,
    }) {
      final ink = warning ? c.error : inactive
          ? c.onSurfaceVariant.withValues(alpha: .45) : c.primary;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, color: ink, size: 22),
              const SizedBox(width: 15),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: inactive ? ink : c.onSurface)),
                  if (subtitle != null) Text(subtitle,
                    style: TextStyle(fontSize: 11,
                      color: c.onSurfaceVariant)),
                ])),
              if (!inactive) Icon(Icons.chevron_right, color: ink),
            ]),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('themePreviewContentList'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('NIARIMの内訳', 'NIARIM breakdown'),
          style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: const Key('themePreviewStoragePie'),
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [c.primary, c.tertiary, c.tertiary],
                  stops: const [0.0, .003, 1.0]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in [
                  (c.primary, t('プロジェクトデータ', 'Project data'), '1.2KB'),
                  (c.tertiary, t('キャッシュ', 'Cache'), '769.5KB'),
                ]) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: item.$1, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.$2,
                      style: const TextStyle(fontSize: 12))),
                    Text(item.$3, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            )),
          ],
        ),
        const SizedBox(height: 24),
        Text(t('整理する', 'Clean up'),
          style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        action(Icons.cleaning_services_outlined,
          t('キャッシュを削除', 'Clear cache'), subtitle: '769.5KB'),
        action(Icons.image_not_supported_outlined,
          t('未使用素材を一括削除', 'Remove unused media')),
        action(Icons.delete_sweep_outlined,
          t('ゴミ箱を空にする', 'Empty trash'), subtitle: '0B',
          inactive: true),
        action(Icons.folder_open_outlined,
          t('プロジェクトを整理する', 'Organize projects')),
        const Divider(height: 24),
        action(Icons.warning_amber_outlined,
          t('全データを削除（初期化）', 'Delete all data'),
          warning: true),
      ],
    );
  }

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

  Widget _widgets(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      Text(t('スマホのホーム画面へ、好きな作品のフレームを'
        '「作品をつくる」「作品広場」の種類のウィジェットを置けます。',
        'Place artwork widgets on your home screen.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 8),
      Text(t('ホーム画面ウィジェットから作品を開いたときも、'
        '選んだ作品のコマを静止画として表示します。',
        'Widgets display your selected frame.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 20),
      Text(t('起動画面ウィジェット', 'Startup widget'),
        style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(t('選んだ作品のフレームを表示します。',
        'Display one selected project frame.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 10),
      Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: Icon(Icons.add_photo_alternate_outlined,
              color: c.primary),
            title: Text(t('作品を選ぶ', 'Choose artwork')),
            trailing: Icon(Icons.chevron_right, color: c.primary),
          )),
      ),
      Text(t('作品をつくるウィジェット', 'Create artwork widget'),
        style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(t('タップすると「新規作成」を開きます。',
        'Open project creation on tap.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 14),
      for (final title in [
        t('アプリのテーマに合わせる', 'Follow app theme'),
        t('色を選ぶ', 'Choose color'),
      ])
        ListTile(
          leading: Icon(title == t('アプリのテーマに合わせる', 'Follow app theme')
            ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: c.primary),
          title: Text(title),
        ),
      const SizedBox(height: 18),
      Text(t('作品広場ウィジェット', 'Community widget'),
        style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(t('タップすると「作品広場」を開きます。',
        'Open the community when tapped.'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 10),
      ListTile(
        leading: Icon(Icons.radio_button_checked, color: c.primary),
        title: Text(t('アプリのテーマに合わせる', 'Follow app theme'))),
      ListTile(
        leading: Icon(Icons.radio_button_unchecked, color: c.onSurfaceVariant),
        title: Text(t('色を選ぶ', 'Choose color'))),
    ],
  );

  Widget _notifications(ColorScheme c) => ListView.separated(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (_, i) => ListTile(
      leading: CircleAvatar(
        backgroundColor: c.primaryContainer,
        child: Text(['さ', 'み', 'あ', 'な'][i],
          style: TextStyle(color: c.onPrimaryContainer))),
      title: Text(
        t(['さくらさんがフォローしました', 'みらいさんがフォローしました',
          'あおいさんがフォローしました', 'なつさんがフォローしました'][i],
          ['Sakura followed you', 'Mirai followed you',
           'Aoi followed you', 'Natsu followed you'][i])),
      subtitle: Text('2026/10/23 10:0' + i.toString()),
    ),
  );

  Widget _save(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    children: [
      for (var i = 0; i < 5; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Material(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 82),
              decoration: BoxDecoration(
                border: Border.all(
                  color: c.outlineVariant.withValues(alpha: .65)),
                borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  height: 58, width: 58,
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Icon(Icons.add, color: c.onSurfaceVariant)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t('スロット', 'Slot') + ' ' + (i + 1).toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(t('保存データなし', 'No saved data'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.onSurfaceVariant)),
                  ])),
                const SizedBox(width: 4),
                Icon(Icons.edit_note, color: c.primary),
                const SizedBox(width: 18),
                Icon(Icons.book_outlined,
                  color: c.onSurfaceVariant.withValues(alpha: .6)),
                const SizedBox(width: 18),
                Icon(Icons.delete_outline,
                  color: c.onSurfaceVariant.withValues(alpha: .6)),
              ]),
            ),
          ),
        ),
    ],
  );

  Widget _catalog(ColorScheme c) {
    Widget search(String hint) => Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.search, size: 20, color: c.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(hint, style: TextStyle(color: c.onSurfaceVariant)),
      ]),
    );

    if (entry.id == 'materials' || entry.id == 'widget_art') {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 38, backgroundColor: c.primary.withValues(alpha: .16),
            child: Icon(Icons.perm_media_outlined, size: 36,
              color: c.primary)),
          const SizedBox(height: 18),
          Text(t('素材がありません', 'No materials yet'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('タイムラインから画像・動画・音声を追加すると\nここに表示されます',
            'Images, videos and audio appear here after import.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
        ],
      ));
    }

    if (entry.id == 'fonts') {
      return Column(children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.outlineVariant))),
          child: Row(children: [
            for (final item in [
              t('ダウンロード', 'Download'),
              t('探してDL', 'Browse'),
              t('読み込み', 'Import'),
            ]) Expanded(child: Center(child: Text(item,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: c.primary)))),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: search(t('フォント名で検索...', 'Search fonts...'))),
          const SizedBox(width: 8),
          _mockChip(c, t('お気に入り', 'Favorites')),
        ])),
        Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 38,
              backgroundColor: c.primary.withValues(alpha: .16),
              child: Icon(Icons.font_download_outlined,
                color: c.primary, size: 38)),
            const SizedBox(height: 18),
            Text(t('フォントがありません', 'No fonts'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t('「探してDL」または「読み込み」から追加できます',
              'Find or import fonts.'),
              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
              textAlign: TextAlign.center),
          ],
        ))),
      ]);
    }

    if (entry.id == 'help' || entry.id == 'tips') {
      final isTips = entry.id == 'tips';
      final titles = isTips
        ? <String>[
          t('タイムラインの素材は複製・移動・削除ができる',
            'Duplicate, move and delete timeline items'),
          t('テキストツールで字幕を入れる', 'Add subtitles'),
          t('効果音はクリップ編集でフェードとリズムよく調整する',
            'Adjust audio fades and rhythm'),
          t('縦書き×ルビでタイトルロゴ風の演出',
            'Create titles with vertical text'),
          t('自分の署名はウォーターマーク、エンドカードは別物',
            'Watermarks and end cards'),
          t('実写動画×手描きを重ねてアニメを作る',
            'Animate over video'),
        ]
        : <String>[
          t('基本の操作（タップ・長押し・スワイプ）', 'Basic gestures'),
          t('ペンツール', 'Pen tools'),
          t('消しゴムツール', 'Eraser'),
          t('バケツツール', 'Bucket fill'),
          t('指移動塗り', 'Finger paint'),
          t('スポイトツール', 'Eyedropper'),
          t('選択ツール', 'Selection'),
          t('指ツール', 'Pan'),
        ];
      return ListView(
        key: const Key('themePreviewContentList'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        children: [
          search(isTips
            ? t('Tipsを検索...', 'Search tips...')
            : t('検索...', 'Search...')),
          const SizedBox(height: 12),
          if (isTips) Text(t('動画制作のコツ', 'Video production tips'),
            style: TextStyle(fontWeight: FontWeight.w700, color: c.primary)),
          for (final title in titles)
            Padding(padding: const EdgeInsets.only(top: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 13),
                decoration: BoxDecoration(
                  color: c.surfaceContainerLow,
                  border: Border.all(color: c.outlineVariant),
                  borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  CircleAvatar(radius: 14,
                    backgroundColor: c.primary.withValues(alpha: .12),
                    child: Icon(isTips
                      ? Icons.lightbulb_outline : Icons.help_outline,
                      size: 17, color: c.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700))),
                  Icon(isTips ? Icons.chevron_right
                    : Icons.keyboard_arrow_down,
                    size: 19, color: c.onSurfaceVariant),
                ]),
              )),
        ],
      );
    }

    if (entry.id == 'autofill') {
      return Stack(children: [
        ListView(
          key: const Key('themePreviewContentList'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _mockChip(c, t('お気に入り', 'Favorites')),
            const SizedBox(height: 8),
            for (final item in [
              (t('グレー単色の下塗り', 'Grey base coat'), 1),
              (t('主人公', 'Main character'), 25),
              (t('ヒロイン', 'Heroine'), 24),
            ]) Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(15)),
                child: Row(children: [
                  Container(width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.grid_view, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: const TextStyle(
                        fontWeight: FontWeight.w700)),
                      Text(item.$2.toString() + t('パーツ', ' parts'),
                        style: TextStyle(fontSize: 10,
                          color: c.onSurfaceVariant)),
                    ])),
                  Icon(Icons.star_border, color: c.primary),
                  const SizedBox(width: 14),
                  Icon(Icons.more_vert, color: c.onSurfaceVariant),
                ]),
              ),
            ),
          ],
        ),
        Positioned(bottom: 24, right: 20,
          child: Container(width: 58, height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primary,
              border: Border.all(color: c.onSurface, width: 2),
              shape: BoxShape.circle),
            child: Icon(Icons.add, color: c.onPrimary, size: 32))),
      ]);
    }

    return _list([
      _heading(entry.label(ja)),
      for (final row in [
        (Icons.crop_16_9, '1920 × 1080'),
        (Icons.crop_square, '1080 × 1080'),
        (Icons.crop_portrait, '1080 × 1920'),
      ]) _card(_row(row.$1, row.$2)),
    ]);
  }

  Widget _legal(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      for (final section in entry.id == 'license'
        ? <(String, String)>[
          (t('利用規約', 'Terms of service'),
           t('本アプリをご利用いただく前に、以下の条件をお読みください。'
             'NIARIMはアニメーション制作を支援するアプリです。',
             'Please review the conditions for using this app.')),
          (t('第1条（適用）', 'Article 1 — Scope'),
           t('この利用規約は、本アプリおよび関連する機能の利用に関する'
             '基本的な条件について定めるものです。',
             'These terms describe use of the application and its features.')),
          (t('第2条（利用条件）', 'Article 2 — Conditions'),
           t('ユーザーは本規約に従って、本アプリが提供する機能を'
             '利用するものとします。',
             'Users agree to follow the terms when using this application.')),
          (t('第3条（禁止事項）', 'Article 3 — Prohibited actions'),
           t('第三者の権利を侵害する行為、サービスの正常な運用を妨げる行為'
             'および法令に反する行為を禁止します。',
             'Do not infringe third-party rights or disrupt the service.')),
        ]
        : <(String, String)>[
          (t('プライバシーポリシー', 'Privacy policy'),
           t('このプライバシーポリシーでは、NIARIMをご利用いただく際の'
             '情報の取り扱いと保護についてご説明します。',
             'This policy describes the use and protection of information.')),
          (t('第1条（収集する情報）', '1. Collected information'),
           t('アプリ利用に必要な情報や、利用者が入力した情報について、'
             '必要な範囲で取り扱います。',
             'Information is processed only as needed for app functionality.')),
          (t('第2条（利用目的）', '2. Purposes'),
           t('取得した情報は、本アプリの提供や運営、'
             'セキュリティ維持のために利用されます。',
             'Information supports app services and security.')),
          (t('第3条（データの保存）', '3. Data storage'),
           t('制作データの管理については利用者の操作と設定に基づきます。',
             'Project data is handled under the user settings.')),
        ])
        Padding(padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.$1, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(section.$2, style: TextStyle(
                fontSize: 12, height: 1.65, color: c.onSurface)),
              const SizedBox(height: 8),
              Text(section.$2, style: TextStyle(
                fontSize: 12, height: 1.65, color: c.onSurface)),
            ],
          )),
    ],
  );

  Widget _communityWork(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    children: [
      ClipRRect(borderRadius: BorderRadius.circular(16),
        child: AspectRatio(aspectRatio: 1.5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFB9C8), Color(0xFFFF6485)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
            alignment: Alignment.center,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: .58)),
              child: const Icon(Icons.play_arrow, color: Colors.white,
                size: 32)),
          ))),
      SizedBox(height: 20, child: Center(child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: c.outlineVariant)))),

      Text(t('夜明けの冒険', 'Dawn adventure'),
        style: const TextStyle(fontSize: 19,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Row(children: [
        CircleAvatar(radius: 14,
          backgroundColor: c.primary.withValues(alpha: .18),
          child: Text(t('あ', 'A'),
            style: TextStyle(color: c.primary))),
        const SizedBox(width: 8),
        Text(t('あさかぜ工房', 'Asakaze Studio'),
          style: TextStyle(color: c.primary, fontSize: 13)),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        Icon(Icons.play_arrow, size: 14, color: c.onSurfaceVariant),
        Text('9,637', style: TextStyle(
          color: c.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 12),
        Icon(Icons.thumb_up_alt_outlined,
          size: 14, color: c.onSurfaceVariant),
        Text('326', style: TextStyle(
          color: c.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 12),
        Icon(Icons.bookmark_border, size: 14, color: c.onSurfaceVariant),
        Text('1,412', style: TextStyle(
          color: c.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 12),
        Icon(Icons.repeat, size: 14, color: c.onSurfaceVariant),
        Text('0', style: TextStyle(
          color: c.onSurfaceVariant, fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      Text(t('2026/10/14に投稿', 'Published 2026/10/14'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIARIM', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: c.primary)),
            const SizedBox(height: 8),
            Wrap(spacing: 13, runSpacing: 9,
              children: [
                for (final x in [
                  '2400f', '24fps', '1920×1080', '6h 40m', '2026/10/13',
                ])
                  Text(x, style: TextStyle(
                    fontSize: 11, color: c.onSurfaceVariant)),
              ]),
          ]),
      ),
      const SizedBox(height: 12),
      for (final item in [
        (Icons.public, t('作品広場での公開状態',
          'Public visibility'), t('公開中', 'Public'), true),
        (Icons.auto_awesome, t('AI画像・AI動画使用',
          'AI images or video'), t('未使用', 'Not used'), false),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(item.$1, color: c.primary),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$2, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(item.$3, style: TextStyle(
                  fontSize: 11, color: c.onSurfaceVariant)),
              ])),
            Switch(value: item.$4, onChanged: (_) {}),
          ]),
        ),
    ],
  );

  Widget _mockCommunityCard(ColorScheme c, String title) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.onSurface)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 9, child: Stack(children: [
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                c.primary.withValues(alpha: .28),
                c.primary.withValues(alpha: .82),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
          Center(child: CircleAvatar(radius: 23,
            backgroundColor: c.onSurface.withValues(alpha: .82),
            child: Icon(Icons.play_arrow, color: c.surface, size: 25))),
          Positioned(top: 4, right: 4, child: CircleAvatar(radius: 22,
            backgroundColor: c.onSurface.withValues(alpha: .82),
            child: Icon(Icons.bookmark_border,
              color: c.surface, size: 23))),
          Positioned(bottom: 4, right: 4, child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 2),
            color: c.onSurface.withValues(alpha: .8),
            child: Text('1:25', style: TextStyle(
              fontSize: 9, color: c.surface)))),
        ])),
        Expanded(flex: 12, child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 9),
              Text(t('サンプル作者', 'Sample artist'),
                style: TextStyle(
                  fontSize: 10, color: c.onSurfaceVariant)),
              const Spacer(),
              Row(children: [
                Icon(Icons.play_arrow, size: 11,
                  color: c.onSurfaceVariant),
                Text('16,998', style: TextStyle(
                  fontSize: 10, color: c.onSurfaceVariant)),
                const SizedBox(width: 7),
                Icon(Icons.bookmark, size: 10,
                  color: c.onSurfaceVariant),
                Text('278', style: TextStyle(
                  fontSize: 10, color: c.onSurfaceVariant)),
              ]),
            ],
          ),
        )),
      ]),
  );

  Widget _author(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(t('サンプル作者', 'Sample artist')),
      actions: [
        Icon(Icons.filter_alt_outlined, color: c.onSurface),
        const SizedBox(width: 6),
        Icon(Icons.arrow_drop_down, color: c.onSurface),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Row(children: [
          for (final name in [
            t('作品', 'Works'), t('ブックマーク', 'Bookmarks'),
          ])
          Expanded(child: Container(
            height: 47, alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: name == t('作品', 'Works')
                  ? c.primary : Colors.transparent, width: 2))),
            child: Text(name, style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13,
              color: name == t('作品', 'Works')
                  ? c.primary : c.onSurfaceVariant)))),
        ]),
      ),
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(radius: 24, backgroundColor: c.primaryContainer,
            child: Text(t('さ', 'S'), style: TextStyle(
              fontSize: 18, color: c.onPrimaryContainer))),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('サンプル作者', 'Sample artist'),
                style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(spacing: 7, runSpacing: 2, children: [
                for (final label in [
                  t('投稿 3件', '3 posts'),
                  t('フォロー中 4', '4 following'),
                  t('フォロワー 12', '12 followers'),
                ])
                  Text(label, style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'HakkouMincho',
                    fontFamilyFallback: const ['NotoSerifJP'],
                    color: c.onSurfaceVariant)),
              ]),
            ],
          )),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(width: double.infinity,
          child: FilledButton.icon(onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(t('フォローする', 'Follow'))))),
      const SizedBox(height: 12),
      Expanded(child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2, crossAxisSpacing: 10,
        mainAxisSpacing: 10, childAspectRatio: .85,
        children: [
          _mockCommunityCard(c, t('雨上がりの約束', 'After the rain')),
          _mockCommunityCard(c, t('夜明けの冒険', 'Dawn adventure')),
          _mockCommunityCard(c, t('最後のメロディ', 'Last melody')),
        ],
      )),
    ]),
  );

  Widget _myWorks(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(t('自分の投稿', 'My posts')),
      actions: [
        Icon(Icons.refresh, color: c.onSurface),
        const SizedBox(width: 16),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            elevation: 0, color: c.surfaceContainerLow,
            child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 20,
                      backgroundColor: c.primaryContainer,
                      child: Icon(Icons.person_outline,
                        color: c.onPrimaryContainer)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t('Googleアカウント未連携',
                      'Google account not connected'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(onPressed: () {},
                      icon: const Icon(Icons.video_call_outlined),
                      label: Text(t('作品を投稿', 'Post artwork'))),
                    OutlinedButton.icon(onPressed: () {},
                      icon: const Icon(Icons.account_circle_outlined),
                      label: Text(t('Googleアカウント', 'Google account'))),
                  ]),
                ]),
            ),
          ),
        ),
        Expanded(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.video_library_outlined, size: 48,
              color: c.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(t('投稿した作品がありません', 'No posted artwork'),
              style: TextStyle(color: c.onSurfaceVariant)),
          ],
        ))),
      ],
    ),
  );

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
      aspectRatio: 16 / 9, child: const ColoredBox(color: Colors.white)))),
    const Text('1 / 24', style: TextStyle(fontWeight: FontWeight.bold)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Slider(value: .14, onChanged: (_) {})),
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
