import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeService>();
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('themePreviewClose'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: ja ? 'プレビューを閉じる' : 'Close preview'),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(themePreviewEntries[_index].label(ja), maxLines: 1,
            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          Text(ja ? 'テーマ配色の見本・サンプルデータ' : 'Theme colors · sample data',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 10)),
        ]),
        actions: [
          Center(child: Text((_index+1).toString()+'/'+themePreviewEntries.length.toString(),
            style: const TextStyle(fontSize: 12))),
          IconButton(
            key: const Key('themePreviewNext'),
            onPressed: _index == themePreviewEntries.length - 1
                ? null : () => _pages.nextPage(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut),
            icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: PageView.builder(
        key: const Key('themePreviewPager'),
        controller: _pages,
        itemCount: themePreviewEntries.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, i) => RepaintBoundary(
          child: _ThemeSampleScreen(entry: themePreviewEntries[i], ja: ja)),
      ),
      bottomNavigationBar: SafeArea(top: false, child: SizedBox(
        height: 30, child: Center(child: Text(
          ja ? '左右にスワイプして画面を切り替え' : 'Swipe sideways to view screens',
          style: TextStyle(fontSize: 11, color: c.onSurfaceVariant))),
      )),
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
    if (entry.layout == 'splash') return _splash(c);
    if (entry.layout == 'canvas') return _canvas(c);
    if (entry.layout == 'timeline') return _timeline(c);
    if (entry.layout == 'complete') return _complete(c);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const Icon(Icons.arrow_back),
        title: Text(entry.label(ja), overflow: TextOverflow.ellipsis),
        actions: const [Padding(padding: EdgeInsets.all(12), child: Icon(Icons.more_vert))]),
      body: _body(c),
    );
  }

  Widget _body(ColorScheme c) {
    switch(entry.layout) {
      case 'projects': return _projects(c);
      case 'community': return _community(c);
      case 'form': return _form(c);
      case 'detail': return _detail(c);
      case 'work': return _communityWork(c);
      case 'author': return _author(c);
      case 'mine': return _myWorks(c);
      case 'export': return _export(c);
      case 'post': return _post(c);
      case 'theme': return _theme(c);
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


  Widget _splash(ColorScheme c) => Scaffold(body: SafeArea(child: Column(children: [
    const Spacer(),
    Icon(Icons.auto_awesome, size: 70, color: c.primary),
    const SizedBox(height: 8),
    Text('NIARIM', style: TextStyle(color: c.onSurface,
      fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 2)),
    const Spacer(),
    Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Container(height: 96, alignment: Alignment.center,
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(16)),
        child: Text(t('作品をつくる', 'Create artwork'),
          style: TextStyle(color: c.onPrimary, fontSize: 22, fontWeight: FontWeight.bold))),
      const SizedBox(height: 18),
      Container(height: 96, alignment: Alignment.center,
        decoration: BoxDecoration(color: c.secondary, borderRadius: BorderRadius.circular(16)),
        child: Text(t('作品広場', 'Community'),
          style: TextStyle(color: c.onSecondary, fontSize: 22, fontWeight: FontWeight.bold))),
    ])),
    const Spacer(),
  ])));

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
    Container(height: 44, color: c.surfaceContainer, child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Text(t('新着', 'New')), Text(t('ランキング', 'Ranking')),
        Text(t('フォロー中', 'Following')),
      ])),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: 4,
      itemBuilder: (_, i) => Card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _art(c, height: 142),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            const Icon(Icons.account_circle), const SizedBox(width: 9),
            Expanded(child: Text(t('サンプル作品', 'Sample artwork'))),
            const Icon(Icons.favorite_border), const SizedBox(width: 10),
            const Icon(Icons.bookmark_border),
          ])),
        ])),
    )),
  ]);

  Widget _canvas(ColorScheme c) => Scaffold(
    body: SafeArea(child: Column(children: [
      SizedBox(height: 48, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.arrow_back), Icon(Icons.undo), Icon(Icons.redo),
          Icon(Icons.layers_outlined), Icon(Icons.more_vert),
        ])),
      Expanded(child: LayoutBuilder(builder: (_, bounds) {
        final side = bounds.maxWidth < bounds.maxHeight
            ? bounds.maxWidth - 24 : bounds.maxHeight - 24;
        return Center(child: SizedBox(
          width: side > 0 ? side : 1,
          height: side > 0 ? side : 1,
          child: Container(
            // Paper is independent canvas content, never a UI theme color.
            color: Colors.white,
            child: const Center(child: Icon(Icons.edit_outlined,
              size: 70, color: Color(0xFFDBAAAA))),
          ),
        ));
      })),
      SizedBox(height: 38, child: Row(children: [
        const Icon(Icons.brush), Expanded(child: Slider(value: .4, onChanged: null)),
        const Text('12'), const SizedBox(width: 12),
      ])),
      SizedBox(height: 38, child: Row(children: [
        const Icon(Icons.opacity), Expanded(child: Slider(value: .85, onChanged: null)),
        const Text('85%'), const SizedBox(width: 12),
      ])),
      SizedBox(height: 56, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.brush), Icon(Icons.auto_fix_off),
          Icon(Icons.format_color_fill), Icon(Icons.colorize),
          Icon(Icons.select_all), Icon(Icons.pan_tool_outlined),
        ])),
      SizedBox(height: 70, child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(8, (i) => Container(
          width: 58, margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: i == 0 ? c.primaryContainer : c.surfaceContainerHigh,
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(5)),
          child: Text((i + 1).toString()),
        )),
      )),
    ])),
  );

  Widget _timeline(ColorScheme c) => Scaffold(
    body: SafeArea(child: Column(children: [
      SizedBox(height: 48, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.arrow_back), Icon(Icons.undo), Icon(Icons.redo),
          Icon(Icons.file_download_outlined), Icon(Icons.more_vert),
        ])),
      Expanded(flex: 3, child: Center(child: AspectRatio(
        aspectRatio: 16/9, child: _art(c, height: 160)))),
      Slider(value: .25, onChanged: null),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [Icon(Icons.skip_previous), Icon(Icons.play_arrow),
          Text('00:02 / 00:12'), Icon(Icons.skip_next)]),
      SizedBox(height: 48, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [Icon(Icons.movie), Icon(Icons.image),
          Icon(Icons.text_fields), Icon(Icons.audiotrack),
          Icon(Icons.camera_alt_outlined)])),
      Expanded(flex: 3, child: ListView(children: [
        _timelineTrack(c, t('フレーム', 'Frames')),
        _timelineTrack(c, t('画像', 'Images')),
        _timelineTrack(c, t('音声', 'Audio')),
        _timelineTrack(c, t('テキスト', 'Text')),
      ])),
    ])),
  );

  Widget _timelineTrack(ColorScheme c, String label) => SizedBox(
    height: 46, child: Row(children: [
      SizedBox(width: 80, child: Padding(
        padding: const EdgeInsets.all(5),
        child: Text(label, style: const TextStyle(fontSize: 11)))),
      ...List.generate(5, (i) => Expanded(child: Container(
        margin: const EdgeInsets.all(2),
        color: i == 0 ? c.primaryContainer : c.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Text((i + 1).toString(), style: const TextStyle(fontSize: 10)),
      ))),
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
    _heading(t('プロジェクト名', 'Project name')),
    _card(Text(t('新しい作品', 'New project'))),
    _heading(t('キャンバスサイズ', 'Canvas size')),
    _card(const Text('1920 × 1080   ·   16:9')),
    _card(_row(Icons.color_lens_outlined, t('背景色', 'Background'))),
    _card(_row(Icons.speed, t('フレームレート', 'Frame rate'), subtitle: '24 fps')),
    const SizedBox(height: 18),
    _cta(c, t('作成', 'Create'), icon: Icons.add),
  ]);

  Widget _detail(ColorScheme c) => _list([
    _art(c, height: 200),
    _card(Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
      Icon(Icons.skip_previous), Icon(Icons.play_arrow), Icon(Icons.skip_next),
    ])),
    _cta(c, t('編集開始', 'Start editing'), icon: Icons.brush),
    _heading(t('プロジェクト情報', 'Project information')),
    _row(Icons.aspect_ratio, t('描画領域', 'Canvas'), subtitle: '1920 × 1080'),
    _row(Icons.movie_filter, t('総フレーム数', 'Frames'), subtitle: '48'),
    _row(Icons.schedule, t('制作時間', 'Work time'), subtitle: '1h 20m'),
  ]);

  Widget _export(ColorScheme c) => _list([
    _heading(t('品質プリセット', 'Quality preset')),
    _card(Text(t('標準       高画質       カスタム',
      'Standard      High       Custom'))),
    const SizedBox(height: 12),
    _heading(t('書き出し形式', 'Export format')),
    _row(Icons.radio_button_checked, 'MP4', subtitle: 'H.264'),
    _row(Icons.radio_button_unchecked, 'GIF'),
    _row(Icons.radio_button_unchecked, 'WebM',
      subtitle: t('透過に対応', 'Supports transparency')),
    _row(Icons.radio_button_unchecked, 'AVI'),
    const SizedBox(height: 20),
    _cta(c, t('書き出し開始', 'Start export'), icon: Icons.download),
  ]);

  Widget _post(ColorScheme c) => _list([
    _heading(t('作品を投稿', 'Post artwork')),
    _card(Text(t('作品タイトル', 'Artwork title'))),
    _card(Text(t('作品の説明', 'Description'))),
    _row(Icons.movie, t('投稿する動画', 'Video')),
    _row(Icons.sell_outlined, t('タグ', 'Tags')),
    _row(Icons.toggle_on, t('作品広場に表示', 'Show in community')),
    const SizedBox(height: 20),
    _cta(c, t('投稿する', 'Post'), icon: Icons.cloud_upload),
  ]);

  Widget _theme(ColorScheme c) => _list([
    _heading(t('カラーカスタマイズ', 'Color customization')),
    ...[
      (t('アクセント', 'Accent'), c.primary),
      (t('文字色', 'Text'), c.onSurface),
      (t('パネル背景', 'Panel background'), c.surface),
      (t('メニュー背景', 'Menu background'), c.surfaceContainer),
      (t('選択色', 'Selection'), c.primaryContainer),
      (t('更新マーク', 'Update mark'), c.tertiary),
    ].map((e) => _card(Row(children: [
      CircleAvatar(radius: 16, backgroundColor: e.$2),
      const SizedBox(width: 14),
      Expanded(child: Text(e.$1)),
      const Icon(Icons.chevron_right),
    ]))),
    _heading(t('プリセット', 'Presets')),
    _card(_row(Icons.palette, t('レッド（ライト）', 'Red (Light)'))),
    _card(_row(Icons.palette, t('ブルー（ダーク）', 'Blue (Dark)'))),
  ]);

  Widget _settings(ColorScheme c) => _list([
    ...[
      (Icons.tune, t('基本', 'Basic')),
      (Icons.speed, t('パフォーマンス', 'Performance')),
      (Icons.gesture, t('ジェスチャー', 'Gestures')),
      (Icons.edit, t('ペン入力', 'Pen input')),
      (Icons.dashboard_customize, t('ワークスペース', 'Workspace')),
      (Icons.palette, t('テーマ・外観', 'Theme & appearance')),
      (Icons.font_download, t('フォント管理', 'Fonts')),
      (Icons.help_outline, t('ヘルプ', 'Help')),
    ].map((e) => _card(_row(e.$1, e.$2))),
  ]);

  Widget _preferences(ColorScheme c) => _list([
    _heading(entry.label(ja)),
    _card(_row(Icons.tune, t('設定項目', 'Setting'),
      subtitle: t('有効', 'Enabled'))),
    _card(_row(Icons.settings, t('標準', 'Standard'))),
    _card(Column(children: [
      _heading(t('強さ', 'Strength')),
      Slider(value: .6, onChanged: null),
    ])),
    _card(_row(Icons.touch_app, t('操作方法', 'Controls'))),
  ]);

  Widget _workspace(ColorScheme c) => _list([
    _heading(t('ツールバー', 'Toolbar')),
    _card(Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [Icon(Icons.brush), Icon(Icons.colorize),
        Icon(Icons.layers), Icon(Icons.pan_tool)])),
    _card(_row(Icons.back_hand_outlined, t('左利きモード', 'Left-handed mode'))),
    _card(_row(Icons.desktop_windows, t('PCモード', 'PC mode'))),
    _card(_row(Icons.dashboard, t('パネル配置', 'Panel layout'))),
    _cta(c, t('適用', 'Apply')),
  ]);

  Widget _premium(ColorScheme c) => _list([
    Center(child: Icon(Icons.auto_awesome, size: 70, color: c.primary)),
    _heading(t('プレミアムでもっと自由に', 'Create more with Premium')),
    _card(_row(Icons.check, t('ウォーターマークなし', 'No watermark'))),
    _card(_row(Icons.check, t('長尺アニメーション', 'Longer animations'))),
    _card(_row(Icons.check, t('多彩な補正', 'More effects'))),
    const SizedBox(height: 12),
    _cta(c, t('プランを見る', 'View plans')),
  ]);

  Widget _storage(ColorScheme c) => _list([
    _heading(t('ストレージ使用量', 'Storage use')),
    _card(Column(children: [
      const Text('380 MB / 2 GB'),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: .19, color: c.primary),
    ])),
    _row(Icons.folder, t('プロジェクト', 'Projects'), subtitle: '240 MB'),
    _row(Icons.delete_outline, t('ゴミ箱', 'Trash'), subtitle: '36 MB'),
  ]);

  Widget _watermark(ColorScheme c) => _list([
    _heading(t('ウォーターマーク', 'Watermark')),
    _art(c, height: 180),
    _card(_row(Icons.text_fields, t('テキストを追加', 'Add text'))),
    _card(_row(Icons.add_photo_alternate, t('画像を追加', 'Add image'))),
  ]);

  Widget _transfer(ColorScheme c) => _list([
    _heading(t('引き継ぎデータ', 'Transfer data')),
    ...[t('設定', 'Settings'), t('ブラシ', 'Brushes'), t('素材', 'Materials')]
      .map((item) => _card(_row(Icons.check_box_outline_blank, item))),
    const SizedBox(height: 14),
    _cta(c, t('書き出し', 'Export'), icon: Icons.file_upload),
  ]);

  Widget _widgets(ColorScheme c) => _list([
    _heading(t('ホーム画面ウィジェット', 'Home screen widgets')),
    _card(_row(Icons.image, t('表示する作品', 'Artwork'))),
    _card(_row(Icons.color_lens, t('テーマ色に合わせる', 'Follow theme colors'))),
    _art(c, height: 160),
  ]);

  Widget _notifications(ColorScheme c) => _list([
    _card(_row(Icons.person_add, t('新しいフォロワー', 'New follower'))),
    _card(_row(Icons.notifications_outlined, t('お知らせ', 'Notification'))),
  ]);

  Widget _save(ColorScheme c) => _list([
    _heading(t('セーブ管理', 'Save management')),
    ...List.generate(4, (i) => _card(_row(
      i == 0 ? Icons.save : Icons.add_box_outlined,
      i == 0 ? t('クイックセーブ', 'Quick save')
        : t('セーブスロット', 'Save slot') + ' ' + i.toString()))),
  ]);

  Widget _catalog(ColorScheme c) => _list([
    _heading(entry.label(ja)),
    _card(_row(Icons.search, t('検索', 'Search'))),
    ...List.generate(3, (i) => _card(_row(
      i.isEven ? Icons.folder_outlined : Icons.description_outlined,
      t('サンプル項目', 'Sample item') + ' ' + (i + 1).toString()))),
    const SizedBox(height: 12),
    _cta(c, t('追加', 'Add'), icon: Icons.add),
  ]);

  Widget _legal(ColorScheme c) => _list([
    _heading(entry.label(ja)),
    _card(Text(t('アプリの利用条件やデータの取扱いについて表示します。',
      'Terms and data handling information appear here.'))),
    _card(Text(t('プレビュー用の見本です。', 'This is a read-only preview.'))),
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

  // SCREEN_LAYOUTS



}
