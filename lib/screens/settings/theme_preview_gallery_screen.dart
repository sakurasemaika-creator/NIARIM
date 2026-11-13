import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../models/export_preset.dart';
import '../export/widgets/export_preset_selector.dart';
import '../../services/theme_service.dart';
import '../../config/accent_text_theme.dart';
import '../../config/font_fallback.dart';
import '../canvas/widgets/canvas_icon_button.dart';
import '../../utils/color_contrast.dart';
import '../../utils/line_break.dart';

/// Lightweight preview of main creation and community screens only.
/// Tab variants, settings/management pages, menus and floating panels are
/// excluded. Export completion is kept as a requested dialog exception.
class ThemePreviewEntry {
  final String id, layout;
  const ThemePreviewEntry(this.id, this.layout);

  /// The page name shown in the gallery's bottom bar, in the app language.
  /// Names that match a real screen title use that screen's text.
  String label(AppLocalizations l) => switch (id) {
    'splash' => l.themePreviewScreenSplash,
    'projects' => l.themePreviewScreenProjects,
    'new' => l.newProjectScreenTitle,
    'detail' => l.themePreviewScreenProjectDetail,
    'canvas' => l.themePreviewScreenCanvas,
    'timeline' => l.themePreviewScreenTimeline,
    'export' => l.themePreviewScreenExport,
    'complete' => l.exportCompleteTitle,
    'save' => l.themePreviewScreenSaves,
    'materials' => l.materialListTitle,
    'community' => l.communityScreenTitle,
    'work' => l.themePreviewScreenWorkDetail,
    'post' => l.themePreviewScreenPost,
    'author' => l.themePreviewScreenAuthor,
    'mine' => l.communityMyWorksTitle,
    'notifications' => l.themePreviewScreenNotifications,
    _ => id,
  };

  /// A shorter page name for a narrow bar: the real screen's own title,
  /// where the page name adds to it ("Work Plaza: work details" →
  /// "Work Details"). Null when there is none.
  String? shortLabel(AppLocalizations l) {
    final short = switch (id) {
      'export' => l.exportScreenTitle,
      'work' => l.communityWorkDetailTitle,
      'post' => l.communityPostButton,
      'notifications' => l.creatorMissionActivityTitle,
      _ => null,
    };
    return short == label(l) ? null : short;
  }
}

/// Show only frequently used creation and community screens. Home tabs
/// (Shared/Trash) are represented by Projects, and infrequent settings,
/// help, legal and administration screens do not need theme samples.
const List<ThemePreviewEntry> themePreviewEntries = [
  ThemePreviewEntry('splash', 'splash'),
  ThemePreviewEntry('projects', 'projects'),
  ThemePreviewEntry('new', 'form'),
  ThemePreviewEntry('detail', 'detail'),
  ThemePreviewEntry('canvas', 'canvas'),
  ThemePreviewEntry('timeline', 'timeline'),
  ThemePreviewEntry('export', 'export'),
  ThemePreviewEntry('complete', 'complete'),
  ThemePreviewEntry('save', 'save'),
  ThemePreviewEntry('materials', 'materials'),
  ThemePreviewEntry('community', 'community'),
  ThemePreviewEntry('work', 'work'),
  ThemePreviewEntry('post', 'post'),
  ThemePreviewEntry('author', 'author'),
  ThemePreviewEntry('mine', 'mine'),
  ThemePreviewEntry('notifications', 'notifications'),
];

/// Live themed, pure render-only widget. No project files, video, login,
/// network or database are touched. PageView builds pages lazily.
class ThemePreviewGalleryScreen extends StatefulWidget {
  const ThemePreviewGalleryScreen({super.key});
  @override
  State<ThemePreviewGalleryScreen> createState() =>
      _ThemePreviewGalleryScreenState();
}

class _ThemePreviewGalleryScreenState extends State<ThemePreviewGalleryScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _controlsVisible = true;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeService>();
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              key: const Key('themePreviewPager'),
              controller: _pages,
              itemCount: themePreviewEntries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => RepaintBoundary(
                child: IgnorePointer(
                  child: _ThemeSampleScreen(
                    entry: themePreviewEntries[i],
                    l: l,
                    accentText: AccentTextTheme.of(context),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
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
                        // No fixed height: with large text the name may
                        // take two lines (never cut, see _GalleryPageName).
                        constraints: const BoxConstraints(minHeight: 54),
                        child: Row(
                          children: [
                            IconButton(
                              key: const Key('themePreviewClose'),
                              tooltip: l.themePreviewCloseTooltip,
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: _GalleryPageName(
                                entry: themePreviewEntries[_index],
                                position:
                                    '${_index + 1}/${themePreviewEntries.length}',
                              ),
                            ),
                            IconButton(
                              tooltip: l.themePreviewPreviousScreen,
                              icon: const Icon(Icons.chevron_left, size: 21),
                              onPressed: _index == 0
                                  ? null
                                  : () => _pages.previousPage(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                            ),
                            IconButton(
                              key: const Key('themePreviewNext'),
                              tooltip: l.themePreviewNextScreen,
                              icon: const Icon(Icons.chevron_right, size: 21),
                              onPressed:
                                  _index == themePreviewEntries.length - 1
                                  ? null
                                  : () => _pages.nextPage(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                            ),
                            IconButton(
                              key: const Key('themePreviewHideControls'),
                              tooltip: l.themePreviewHideControls,
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                size: 19,
                              ),
                              onPressed: () =>
                                  setState(() => _controlsVisible = false),
                            ),
                          ],
                        ),
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
                              tooltip: l.themePreviewShowControls,
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _controlsVisible = true),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page name, the colour-sample caption and the page number in the
/// gallery's bar.
///
/// Screen names are never cut with "…" and never shrunk: the name may take
/// two lines; when it does not fit, the real screen's shorter title is tried,
/// and when that does not fit either the name is left out. The page number
/// stays, and long-pressing (touch) or hovering (mouse) it shows the full
/// name, which screen readers also announce. The choice follows the measured
/// width, so it is the same on any device of the same width and text size.
class _GalleryPageName extends StatelessWidget {
  const _GalleryPageName({required this.entry, required this.position});

  final ThemePreviewEntry entry;
  final String position;

  static const TextStyle _nameStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  /// Letters of scripts that put spaces between words: a line may only
  /// break at a space there.
  static final RegExp _wordLetters = RegExp(
    r'[A-Za-zÀ-ÖØ-öø-ÿœŒ\uac00-\ud7af]',
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    final captionStyle = TextStyle(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
    );
    const positionStyle = TextStyle(fontSize: 11);

    Size measure(String text, TextStyle style, {int? maxLines, double? width}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
        maxLines: maxLines,
      )..layout(maxWidth: width ?? double.infinity);
      final size = painter.didExceedMaxLines
          ? Size.infinite
          : Size(painter.width, painter.height);
      painter.dispose();
      return size;
    }

    // Fits within [lines] lines at [width], breaking only between words.
    bool fits(String text, TextStyle style, double width, int lines) {
      if (width <= 0) return false;
      if (measure(text, style, maxLines: lines, width: width).width > width) {
        return false;
      }
      return text
          .split(' ')
          .where(_wordLetters.hasMatch)
          .every((word) => measure(word, style).width <= width);
    }

    final full = entry.label(l);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final nameWidth =
            box.maxWidth - measure(position, positionStyle).width - gap;
        final name = [full, ?entry.shortLabel(l)]
            .where(
              (n) => fits(keepKoreanWordsTogether(n), _nameStyle, nameWidth, 2),
            )
            .firstOrNull;
        final caption = l.themePreviewSampleCaption;
        final showCaption =
            name != null && fits(caption, captionStyle, nameWidth, 1);
        return Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null)
                    Text(
                      keepKoreanWordsTogether(name),
                      key: const Key('themePreviewTitle'),
                      semanticsLabel: plainSemanticsLabel(
                        keepKoreanWordsTogether(name),
                      ),
                      maxLines: 2,
                      style: _nameStyle,
                    ),
                  if (showCaption)
                    Text(caption, maxLines: 1, style: captionStyle),
                ],
              ),
            ),
            const SizedBox(width: gap),
            Tooltip(
              key: const Key('themePreviewPosition'),
              message: full,
              // Read out with the number unless the full name is on screen.
              excludeFromSemantics: name == full,
              child: Text(position, style: positionStyle),
            ),
          ],
        );
      },
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
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // A landscape tablet preview must stay compact too, without stretching
    // either axis. Scale the whole viewport by exactly one factor.
    final miniatureHeight = width > fullHeight
        ? height * fullHeight / width
        : height;
    final miniatureWidth = miniatureHeight * width / fullHeight;
    return RepaintBoundary(
      child: Semantics(
        label: l.themePreviewThumbnailSemantics,
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
                      l: l,
                      accentText: AccentTextTheme.of(context),
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
  final AppLocalizations l;
  // 背景の上の差し色の文字・アイコン（実際の画面のAccentTextTheme）。
  // 塗りは差し色（c.primary）のまま。
  final Color accentText;
  const _ThemeSampleScreen({
    required this.entry,
    required this.l,
    required this.accentText,
  });
  Widget _cta(ColorScheme c, String label, {IconData icon = Icons.check}) =>
      Container(
        // Grows for a second line instead of overflowing (large text, long
        // languages), like the real filled buttons.
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c.onPrimary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.onPrimary,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (entry.layout == 'splash') return _splash(context, c);
    if (entry.layout == 'community') return _community(c);
    if (entry.layout == 'projects') return _projects(context, c);
    if (entry.layout == 'author') return _author(c);
    if (entry.layout == 'mine') return _myWorks(c);
    if (entry.layout == 'canvas') return _canvas(c);
    if (entry.layout == 'timeline') return _timeline(c);
    if (entry.layout == 'complete') return _complete(c);
    const helpScreens = <String>{
      'new',
      'detail',
      'export',
      'materials',
      'save',
    };
    const menuScreens = <String>{'projects', 'detail', 'community', 'author'};
    // The app bar title of the real screen each sample stands for.
    final appTitle = switch (entry.id) {
      'detail' => l.themePreviewSampleProjectName,
      'work' => l.communityWorkDetailTitle,
      'post' => l.communityPostButton,
      'notifications' => l.creatorMissionActivityTitle,
      'save' => l.saveTreeScreenTitleSlot,
      'new' => l.newProjectScreenTitle,
      'export' => l.exportScreenTitle,
      _ => entry.label(l),
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            const <String>{
              'new',
              'detail',
              'export',
              'materials',
              'save',
              'work',
              'settings',
            }.contains(entry.id)
            ? null
            : const Icon(Icons.arrow_back),
        title: Text(appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (helpScreens.contains(entry.id))
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.help_outline, size: 21),
            ),
          if (entry.id == 'settings')
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.search, size: 21),
            ),
          if (menuScreens.contains(entry.id))
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.more_vert, size: 21),
            ),
        ],
      ),
      body: _body(context, c),
    );
  }

  Widget _body(BuildContext context, ColorScheme c) {
    switch (entry.layout) {
      case 'materials':
        return _materials(c);
      case 'form':
        return _form(c);
      case 'detail':
        return _detail(c);
      case 'work':
        return _communityWork(c);
      case 'export':
        return _export(c);
      case 'post':
        return _post(c);
      case 'notifications':
        return _notifications(c);
      case 'save':
        return _save(c);
      default:
        return _materials(c);
    }
  }

  // Read-only, zero-data UI atoms shared by theme-preview layouts. All visible
  // colors come from the active theme; sample project artwork is plain white.
  Widget _mockSlider(
    ColorScheme c, {
    double position = .24,
    double height = 32,
  }) => SizedBox(
    height: height,
    child: Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (_, bounds) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 2, color: c.outlineVariant),
                Container(
                  height: 2,
                  width: bounds.maxWidth * position,
                  color: c.primary,
                ),
                Positioned(
                  left: (bounds.maxWidth * position - 7).clamp(
                    0.0,
                    bounds.maxWidth - 14,
                  ),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.primary,
                      border: Border.all(color: c.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // Other previews use normal Material icons. Canvas previews use the
  // same outlined glyphs as the REAL transparent CanvasIconButton.
  Widget _mockTool(
    ColorScheme c,
    IconData icon, {
    bool active = false,
    bool canvasOutline = false,
  }) {
    // CanvasIconButton marks selection by recoloring the GLYPH, not by
    // placing an opaque tile behind it. Other mock controls retain their
    // existing selected-container styling.
    final foreground = active
        ? (canvasOutline ? c.primary : c.onPrimaryContainer)
        : c.onSurface;
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active && !canvasOutline
            ? c.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        icon,
        size: 18,
        color: foreground,
        shadows: canvasOutline
            ? CanvasIconButton.foregroundShadows(foreground, c)
            : null,
      ),
    );
  }

  Widget _fakePaper(ColorScheme c, {double? height}) =>
      Container(height: height, color: Colors.white);

  Widget _mockSettingRow(
    ColorScheme c,
    IconData icon,
    String title, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: accentText, size: 22),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 10),
              ),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: c.onSurfaceVariant,
        ),
      ),
    ),
  );

  Widget _splash(BuildContext context, ColorScheme c) {
    // Match splash_screen.dart: the user's explicit button foreground is
    // used for button labels/icons. The app-logo foreground uses it too.
    final preset = context.read<ThemeService>().current;
    final foreground = preset.buttonTextColor;
    // Like the real splash tiles: Kuramubon labels, up to three lines, and
    // both tiles grow to the taller one instead of clipping long languages.
    TextStyle titleStyle(Color color) => TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
      color: color,
    );
    TextStyle subtitleStyle(Color color) => TextStyle(
      fontSize: 12,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
      color: color,
    );
    const tileWidth = 150.0;
    const tilePadding = 14.0;
    double textHeight(String text, TextStyle style) {
      final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
      )..layout(maxWidth: tileWidth - tilePadding * 2);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final tileHeight = [
      166.0,
      60 +
          10 +
          textHeight(
            keepKoreanWordsTogether(l.splashCommunityButtonTitle),
            titleStyle(foreground),
          ) +
          textHeight(
            keepKoreanWordsTogether(l.splashCommunityButtonSubtitle),
            subtitleStyle(foreground),
          ) +
          tilePadding * 2,
      60 +
          10 +
          textHeight(
            keepKoreanWordsTogether(l.splashCreateButton),
            titleStyle(foreground),
          ) +
          tilePadding * 2,
    ].reduce((a, b) => a > b ? a : b);
    Widget action(
      IconData icon,
      String title,
      String? subtitle,
      Color first,
      Color second,
    ) => Container(
      width: tileWidth,
      height: tileHeight,
      padding: const EdgeInsets.all(tilePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [first, second],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: foreground),
          const SizedBox(height: 10),
          // Korean breaks only between words, as on the real splash.
          Text(
            keepKoreanWordsTogether(title),
            semanticsLabel: title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: titleStyle(foreground),
          ),
          if (subtitle != null)
            Text(
              keepKoreanWordsTogether(subtitle),
              semanticsLabel: subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: subtitleStyle(foreground),
            ),
        ],
      ),
    );
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          padding: const EdgeInsets.all(8.8),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(24.2),
          ),
          child: SvgPicture.asset(
            'assets/logo/app_logo.svg',
            key: const Key('themePreviewSplashAppLogo'),
            colorFilter: ColorFilter.mode(
              preset.buttonTextColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SvgPicture.asset(
          'assets/logo/title_logo.svg',
          width: 220,
          height: 220 * 690 / 3470,
          colorFilter: ColorFilter.mode(c.primary, BlendMode.srcIn),
        ),
      ],
    );
    final community = action(
      Icons.movie_filter_outlined,
      l.splashCommunityButtonTitle,
      l.splashCommunityButtonSubtitle,
      c.secondary,
      c.secondaryContainer,
    );
    final create = action(
      Icons.brush_outlined,
      l.splashCreateButton,
      null,
      c.primary,
      c.primaryContainer,
    );
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final arrangement = landscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              community,
              const SizedBox(width: 40),
              logo,
              const SizedBox(width: 40),
              create,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              community,
              const SizedBox(height: 32),
              logo,
              const SizedBox(height: 32),
              create,
            ],
          );
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(fit: BoxFit.scaleDown, child: arrangement),
          ),
        ),
      ),
    );
  }

  Widget _projects(BuildContext context, ColorScheme c) {
    final theme = Theme.of(context);
    final tabBackground = opaqueOver(
      theme.appBarTheme.backgroundColor ?? c.surface,
      opaqueOver(theme.scaffoldBackgroundColor, Colors.black),
    );
    final tabScheme = c.copyWith(
      surface: tabBackground,
      onSurface: theme.appBarTheme.foregroundColor ?? c.onSurface,
    );
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const Icon(Icons.menu),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                l.homeSortFieldUpdated,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_downward, size: 20),
          ],
        ),
        actions: [
          const Icon(Icons.grid_view, size: 21),
          const SizedBox(width: 14),
          const Icon(Icons.search, size: 22),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: SizedBox(
            height: 45,
            child: Row(
              children: [
                for (final tab in [
                  l.homeTabProjects,
                  l.homeTabWorks,
                  l.homeTabBookmarked,
                ])
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                                color: tab == l.homeTabProjects
                                    ? accentText
                                    : c.onSurfaceVariant,
                                shadows: tab == l.homeTabProjects
                                    ? CanvasIconButton.actionShadows(
                                        accentText,
                                        tabBackground,
                                        tabScheme,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 2,
                          color: tab == l.homeTabProjects
                              ? c.primary
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 9, 7, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      l.homeFavoritesOnly,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: c.primary.withValues(alpha: .13),
                        child: Icon(
                          Icons.movie_creation_outlined,
                          size: 31,
                          color: accentText,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        l.projectListEmptyTitle,
                        style: const TextStyle(
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.projectListEmptyHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 13,
            bottom: 20,
            child: Container(
              key: const Key('themePreviewHomeBackFab'),
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.arrow_back, color: c.onPrimary),
                ),
              ),
            ),
          ),
          Positioned(
            right: 13,
            bottom: 20,
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: c.onPrimary, size: 27),
            ),
          ),
        ],
      ),
    );
  }

  /// Like the real Work Plaza app bar: back, the title and three actions.
  /// The title is never cut and never broken inside a word (Korean breaks
  /// only at spaces): the bar grows for a second or third line, and when
  /// even one word does not fit beside the actions, the title takes a line
  /// of its own under them.
  Widget _communityHeader(ColorScheme c) => LayoutBuilder(
    builder: (context, box) {
      const titleStyle = TextStyle(
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      );
      final title = keepKoreanWordsTogether(l.communityScreenTitle);
      final scaler = MediaQuery.textScalerOf(context);
      final style = DefaultTextStyle.of(context).style.merge(titleStyle);
      double widestWord() {
        var widest = 0.0;
        for (final word in title.split(' ')) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        return widest;
      }

      Widget action(IconData icon) => SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, size: 24, color: c.onSurface),
      );
      final actions = [
        SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: c.onSurface,
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '4',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        action(Icons.visibility_off_outlined),
        action(Icons.help_outline),
      ];
      final titleText = Text(
        title,
        semanticsLabel: plainSemanticsLabel(title),
        softWrap: true,
        style: titleStyle,
      );
      final besideActions = box.maxWidth - 8 - 48.0 * (1 + actions.length);
      if (widestWord() <= besideActions) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 57),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                action(Icons.arrow_back),
                Expanded(child: titleText),
                ...actions,
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [action(Icons.arrow_back), const Spacer(), ...actions],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: titleText,
          ),
        ],
      );
    },
  );

  /// Like the real tabs: icon and name, or (when one name does not fit its
  /// tab on one line) the icons alone, with the names read out.
  Widget _communityTabs(ColorScheme c) => LayoutBuilder(
    builder: (context, box) {
      final tabs = [
        (Icons.schedule_outlined, l.communityTabNew),
        (Icons.emoji_events_outlined, l.communityTabRanking),
        (Icons.person_outlined, l.communityTabFavoriteAuthors),
      ];
      const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
      final style = DefaultTextStyle.of(context).style.merge(labelStyle);
      final scaler = MediaQuery.textScalerOf(context);
      final tabWidth = box.maxWidth / tabs.length;
      final showLabels = tabs.every((tab) {
        final painter = TextPainter(
          text: TextSpan(text: tab.$2, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final fits = 24 + 6 + painter.width + 16 <= tabWidth;
        painter.dispose();
        return fits;
      });
      return Row(
        children: [
          for (final (i, tab) in tabs.indexed)
            Expanded(
              child: Semantics(
                label: tab.$2,
                selected: i == 0,
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 41),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.$1,
                            size: 24,
                            color: i == 0 ? accentText : c.onSurfaceVariant,
                          ),
                          if (showLabels) ...[
                            const SizedBox(width: 6),
                            Text(
                              tab.$2,
                              maxLines: 1,
                              softWrap: false,
                              style: labelStyle.copyWith(
                                color: i == 0 ? accentText : c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == 0 ? c.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  /// Two cards side by side, each as tall as its content (the text lines
  /// grow with the text size instead of overflowing a fixed card height).
  Widget _cardRows(List<Widget> cards, {double spacing = 20}) => Column(
    children: [
      for (var i = 0; i < cards.length; i += 2) ...[
        if (i > 0) SizedBox(height: spacing - 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[i]),
            SizedBox(width: spacing),
            Expanded(
              child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
            ),
          ],
        ),
      ],
    ],
  );

  /// The title, artist and counts under a work's picture (one line each,
  /// like the real cards).
  Widget _mockCardText(ColorScheme c, String title, {double fontSize = 13}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize),
            ),
            const SizedBox(height: 10),
            Text(
              l.themePreviewSampleArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            // The counts move to a second line rather than being cut.
            Wrap(
              spacing: 9,
              children: [
                for (final (icon, count) in [
                  (Icons.play_arrow, '16,998'),
                  (Icons.bookmark, '278'),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 11, color: c.onSurfaceVariant),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 10,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _community(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(
      child: Column(
        children: [
          _communityHeader(c),
          _communityTabs(c),
          Divider(height: 1, thickness: .5, color: c.outlineVariant),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  key: const Key('themePreviewCommunityWorks'),
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  children: [
                    _cardRows([
                      for (var i = 0; i < 8; i++)
                        _communityWorkCard(
                          c,
                          [
                            l.themePreviewSampleWorkTitle1,
                            l.themePreviewSampleWorkTitle2,
                            l.themePreviewSampleWorkTitle1,
                            l.themePreviewSampleWorkTitle3,
                          ][i % 4],
                          i,
                        ),
                    ]),
                  ],
                ),
                Positioned(
                  bottom: 18,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: c.onSurface, width: 3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 22,
                          color: c.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l.communityMyWorksTitle,
                          style: TextStyle(
                            color: c.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _communityWorkCard(ColorScheme c, String label, int i) {
    final accent = i.isEven ? const Color(0xFFFF8BA7) : const Color(0xFFD0A875);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.onSurface, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.75,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: .55), accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.onSurface.withValues(alpha: .9),
                    ),
                    child: Icon(Icons.play_arrow, size: 25, color: c.surface),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: c.onSurface.withValues(alpha: .9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_border,
                      size: 25,
                      color: c.surface,
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    color: c.onSurface.withValues(alpha: .85),
                    child: Text(
                      i.isEven ? '1:25' : '1:40',
                      style: TextStyle(color: c.surface, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _mockCardText(c, label),
        ],
      ),
    );
  }

  Widget _canvas(ColorScheme c) => Scaffold(
    key: const Key('themePreviewCanvasScaffold'),
    // Match the real canvas outer area. Bars have transparent backgrounds.
    backgroundColor: c.surfaceContainerHighest,
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 43,
            child: Row(
              children: [
                const SizedBox(width: 8),
                _mockTool(c, Icons.undo, canvasOutline: true),
                _mockTool(c, Icons.redo, canvasOutline: true),
                const Spacer(),
                _mockTool(c, Icons.settings, canvasOutline: true),
                _mockTool(c, Icons.home_outlined, canvasOutline: true),
                // Direction cue for the same timeline switch used in CanvasScreen.
                SizedBox(
                  key: const Key('themePreviewCanvasTimelineButton'),
                  width: 36,
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_filter_outlined,
                        size: 19,
                        color: c.onSurface,
                        shadows: CanvasIconButton.foregroundShadows(
                          c.onSurface,
                          c,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward,
                        size: 13,
                        color: c.onSurface,
                        shadows: CanvasIconButton.foregroundShadows(
                          c.onSurface,
                          c,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // No project instance, image decoding, or raster engine. The real
          // initial canvas shows a landscape paper and collapsed brush settings.
          Expanded(
            child: Container(
              key: const Key('themePreviewCanvasViewport'),
              color: c.surfaceContainerHighest,
              child: LayoutBuilder(
                builder: (_, bounds) {
                  final paperWidth = bounds.maxWidth;
                  return Center(
                    child: SizedBox(
                      key: const Key('themePreviewCanvasPaper'),
                      width: paperWidth,
                      height: (paperWidth * 9 / 16).clamp(
                        1.0,
                        bounds.maxHeight,
                      ),
                      child: const ColoredBox(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.circle,
                  size: 7,
                  color: c.onSurfaceVariant,
                  shadows: CanvasIconButton.foregroundShadows(
                    c.onSurfaceVariant,
                    c,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '5',
                  style: TextStyle(
                    fontSize: 10,
                    color: c.onSurfaceVariant,
                    shadows: CanvasIconButton.foregroundShadows(
                      c.onSurfaceVariant,
                      c,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.opacity,
                  size: 12,
                  color: c.onSurfaceVariant,
                  shadows: CanvasIconButton.foregroundShadows(
                    c.onSurfaceVariant,
                    c,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '100%',
                  style: TextStyle(
                    fontSize: 10,
                    color: c.onSurfaceVariant,
                    shadows: CanvasIconButton.foregroundShadows(
                      c.onSurfaceVariant,
                      c,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  l.canvasBrushSliderToggleLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: c.onSurfaceVariant,
                    shadows: CanvasIconButton.foregroundShadows(
                      c.onSurfaceVariant,
                      c,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 17,
                  color: c.onSurfaceVariant,
                  shadows: CanvasIconButton.foregroundShadows(
                    c.onSurfaceVariant,
                    c,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          SizedBox(
            height: 25,
            child: Center(
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 19,
                color: c.onSurfaceVariant,
                shadows: CanvasIconButton.foregroundShadows(
                  c.onSurfaceVariant,
                  c,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mockTool(c, Icons.brush, active: true, canvasOutline: true),
                _mockTool(c, Icons.auto_fix_off, canvasOutline: true),
                _mockTool(c, Icons.format_color_fill, canvasOutline: true),
                _mockTool(c, Icons.colorize, canvasOutline: true),
                _mockTool(c, Icons.pan_tool, canvasOutline: true),
                _mockTool(c, Icons.select_all, canvasOutline: true),
                _mockTool(c, Icons.text_fields, canvasOutline: true),
                _mockTool(c, Icons.category, canvasOutline: true),
                Container(
                  key: const Key('themePreviewCanvasColorSwatch'),
                  height: 25,
                  width: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: CanvasIconButton.outlineColor(Colors.black, c),
                      width: 2,
                    ),
                  ),
                ),
                _mockTool(c, Icons.tune, canvasOutline: true),
                _mockTool(c, Icons.layers_outlined, canvasOutline: true),
              ],
            ),
          ),
          SizedBox(
            height: 22,
            child: Center(
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 19,
                color: c.onSurfaceVariant,
                shadows: CanvasIconButton.foregroundShadows(
                  c.onSurfaceVariant,
                  c,
                ),
              ),
            ),
          ),
          Container(
            key: const Key('themePreviewCanvasFrameStrip'),
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.transparent,
            child: Row(
              children: [
                ...List.generate(
                  4,
                  (i) => Container(
                    width: 49,
                    margin: const EdgeInsets.fromLTRB(1, 5, 0, 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: i == 0 ? c.primary : c.outlineVariant,
                        width: i == 0 ? 2 : 1,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _mockTool(c, Icons.movie_filter_outlined, canvasOutline: true),
                _mockTool(c, Icons.chevron_right, canvasOutline: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timeline(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                _mockTool(c, Icons.arrow_back),
                _mockTool(c, Icons.palette_outlined),
                Expanded(
                  child: Text(
                    l.themePreviewSampleProjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _mockTool(c, Icons.home_outlined),
                _mockTool(c, Icons.undo),
                _mockTool(c, Icons.redo),
                _mockTool(c, Icons.more_vert),
                _mockTool(c, Icons.help_outline),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: AspectRatio(
                key: const Key('themePreviewTimelinePaper'),
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.white),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.fullscreen,
                        size: 18,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Text(
                        '10/100',
                        key: const Key('themePreviewFrameCounter'),
                        style: TextStyle(
                          color: c.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 4,
                      child: Icon(
                        Icons.repeat,
                        key: const Key('themePreviewLoopButton'),
                        size: 24,
                        color: accentText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The resize grip has no time labels beside it.
          SizedBox(
            height: 22,
            child: Center(
              child: Container(
                key: const Key('themePreviewResizeGrip'),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: c.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _mockSlider(c, position: .09, height: 43),
          ),
          SizedBox(
            height: 58,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth = constraints.maxWidth / 7 < 48
                    ? constraints.maxWidth / 7
                    : 48.0;
                Widget transport(IconData icon, String key) => SizedBox(
                  key: Key(key),
                  width: buttonWidth,
                  height: buttonWidth,
                  child: Center(child: _mockTool(c, icon)),
                );
                return Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '0.4s',
                            key: const Key('themePreviewCurrentSeconds'),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    transport(Icons.skip_previous, 'themePreviewSkipPrevious'),
                    transport(Icons.fast_rewind, 'themePreviewFastRewind'),
                    transport(Icons.play_arrow, 'themePreviewPlay'),
                    transport(Icons.fast_forward, 'themePreviewFastForward'),
                    transport(Icons.skip_next, 'themePreviewSkipNext'),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '4.2s',
                            key: const Key('themePreviewTotalSeconds'),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(height: 1, color: c.outlineVariant),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mockTool(c, Icons.add_circle_outline),
                _mockTool(c, Icons.video_collection_outlined),
                _mockTool(c, Icons.movie_outlined),
                _mockTool(c, Icons.camera_outlined),
                _mockTool(c, Icons.push_pin_outlined),
                _mockTool(c, Icons.layers_outlined),
                _mockTool(c, Icons.note_add_outlined),
              ],
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: c.surfaceContainerLow,
            child: Row(
              children: [
                Text(
                  l.toolbarItemSelect,
                  style: TextStyle(fontSize: 11, color: accentText),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 12, color: c.onPrimary),
                      const SizedBox(width: 5),
                      Text(
                        'Scene1',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.onPrimary,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _mockTool(c, Icons.more_vert),
                _mockTool(c, Icons.add),
              ],
            ),
          ),
          Container(
            key: const Key('themePreviewTimelineTracks'),
            height: 44,
            color: c.surface,
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      _mockTool(c, Icons.movie_filter_outlined),
                      Expanded(
                        child: Text(
                          l.timelineFrameTrackLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(
                  5,
                  (i) => Expanded(
                    child: Container(
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      alignment: Alignment.bottomLeft,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: i == 0 ? c.primary : c.outlineVariant,
                          width: i == 0 ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        (i + 1).toString(),
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _previewMaterialTrack(
                      c,
                      Icons.layers_outlined,
                      l.layerPanelCommonLayerLabel,
                      0,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.text_fields,
                      l.timelineMaterialText,
                      1,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.image_outlined,
                      l.projectListMaterialImage,
                      2,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.movie_outlined,
                      l.projectListMaterialVideo,
                      3,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.music_note,
                      l.projectListMaterialAudio,
                      4,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.camera_outlined,
                      l.timelineCameraTrackLabel,
                      5,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.more_time,
                      l.timelineMarkerTrackLabel,
                      6,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.auto_fix_high,
                      l.timelineEffectFilterLabel,
                      7,
                    ),
                    _previewMaterialTrack(
                      c,
                      Icons.movie_filter_outlined,
                      l.timelineEndCardTrackLabel,
                      8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _previewMaterialTrack(
    ColorScheme c,
    IconData icon,
    String label,
    int index,
  ) => SizedBox(
    key: Key('themePreviewMaterialTrack$index'),
    height: 18,
    child: Row(
      children: [
        SizedBox(
          width: 112,
          child: Row(
            children: [
              const SizedBox(width: 6),
              Icon(icon, size: 11, color: c.onSurfaceVariant),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: c.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
            decoration: BoxDecoration(
              color: index.isEven ? c.primaryContainer : c.tertiaryContainer,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: c.outlineVariant),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 5),
            child: Text(
              index == 4
                  ? '♪ sample.wav'
                  : index == 2
                  ? 'sample.png'
                  : index == 3
                  ? 'sample.mp4'
                  : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: index.isEven
                    ? c.onPrimaryContainer
                    : c.onTertiaryContainer,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _complete(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(l.exportScreenTitle),
      actions: [Icon(Icons.help_outline, color: c.onSurface)],
    ),
    body: Stack(
      children: [
        Positioned.fill(child: _export(c)),
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: .46)),
        ),
        // Like the real AlertDialog: the dialog scrolls when its text is
        // taller than the screen (large text, long languages).
        Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Material(
              elevation: 0,
              color: c.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.exportCompleteTitle,
                      style: const TextStyle(
                        fontSize: 21,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l.exportCompleteFramesBody(48),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.exportSaveLocationLabel('animation.mp4'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l.exportSaveLocationHint,
                      style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    // Like the real dialog's buttons: side by side, or one
                    // under the other when they do not fit.
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 14,
                      overflowSpacing: 10,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            l.exportBackToProjectsButton,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Kuramubon',
                              fontFamilyFallback: kHeadingFontFallback,
                              color: accentText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            l.commonShare,
                            style: TextStyle(
                              fontFamily: 'Kuramubon',
                              fontFamilyFallback: kHeadingFontFallback,
                              color: c.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
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
          labelText: l.newProjectNameLabel,
          border: const OutlineInputBorder(),
        ),
        child: Text(l.newProjectScreenTitle),
      ),
      const SizedBox(height: 24),
      const Text('FPS', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final n in [8, 12, 24])
            ChoiceChip(
              label: Text('$n'),
              selected: n == 12,
              onSelected: (_) {},
            ),
        ],
      ),
      const SizedBox(height: 24),
      // The button moves under the label when both do not fit on a line.
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l.newProjectSizeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune, size: 18),
            label: Text(l.newProjectSizePresetManageButton),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          key: const Key('themePreviewMockSizes'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in [
              (l.newProjectPresetFullHd, '1920×1080'),
              (l.newProjectPresetHd, '1280×720'),
              (l.newProjectPresetSquare, '1080×1080'),
              (l.newProjectPresetVertical, '1080×1920'),
              (l.newProjectPresetPortrait, '1080×1350'),
              (l.newProjectPresetAnalog, '1440×1080'),
            ].asMap().entries)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: ChoiceChip(
                  label: Text(
                    '${item.value.$1} (${item.value.$2})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  selected: item.key == 0,
                  onSelected: (_) {},
                ),
              ),
            ChoiceChip(
              label: Text(l.newProjectCustomSize),
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Container(
          width: 160,
          height: 90,
          color: c.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Text(
            '1920×1080',
            style: TextStyle(fontSize: 10, color: c.onSurfaceVariant),
          ),
        ),
      ),
      const SizedBox(height: 24),
      _mockSettingRow(
        c,
        Icons.palette_outlined,
        l.newProjectBackgroundColorLabel,
      ),
      _mockSettingRow(c, Icons.auto_awesome, l.autofillPresetSelectionButton),
      const SizedBox(height: 16),
      _cta(c, l.commonCreate, icon: Icons.add),
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
          // Match the real player: the time labels stay at the two edges
          // and the three intervening horizontal gaps are equal.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0.1s',
                key: const Key('themePreviewDetailCurrentSeconds'),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
              Text(
                '2/12',
                key: const Key('themePreviewDetailFrameCounter'),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
              SizedBox(
                key: const Key('themePreviewDetailLoopButton'),
                width: 34,
                height: 34,
                child: Icon(Icons.repeat, color: accentText, size: 20),
              ),
              Text(
                '1.0s',
                key: const Key('themePreviewDetailTotalSeconds'),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ],
          ),
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
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _mockTool(c, Icons.skip_previous),
            _mockTool(c, Icons.fast_rewind),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: c.onPrimary, size: 30),
            ),
            _mockTool(c, Icons.fast_forward),
            _mockTool(c, Icons.skip_next),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _cta(c, l.projectDetailStartEditButton, icon: Icons.edit),
      const SizedBox(height: 24),
      Row(
        children: [
          for (final item in [
            (Icons.folder_outlined, l.creativePanelFolderButton),
            (Icons.sell_outlined, l.projectDetailTagsQuickAction),
            (Icons.star_border, l.projectDetailFavoriteUnregistered),
            (Icons.ios_share, l.projectDetailShareQuickAction),
          ])
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 24, color: c.onSurfaceVariant),
                  const SizedBox(height: 5),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 26),
      Text(
        l.projectDetailInfoSectionTitle,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final item in [
                ('FPS', '12'),
                (l.projectDetailInfoExportSize, '320×180'),
                (l.projectDetailInfoTotalFrames, '12'),
                (l.projectDetailInfoWorkTime, l.newProjectDurationHm(0, 0)),
                (l.projectDetailInfoLastSaved, '2026/10/23 10:00'),
                (l.projectDetailInfoSize, '0B'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(item.$2, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _export(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        l.exportPresetSection,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      const SizedBox(height: 8),
      // The real selector: it switches to another layout when the three
      // labels do not fit, instead of breaking a word inside a segment.
      ExportPresetSelector(value: ExportPreset.standard, onChanged: (_) {}),
      const SizedBox(height: 24),
      Text(
        l.exportFormatSection,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      const SizedBox(height: 8),
      for (final option in [
        ('MP4', l.exportFormatMp4Subtitle),
        ('GIF', l.exportFormatGifSubtitle),
        (l.helpTransparentWebmTitle, l.exportFormatWebmSubtitle),
        ('AVI', l.exportFormatAviSubtitle),
      ].asMap().entries)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Row(
            children: [
              Icon(
                option.key == 0
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: option.key == 0 ? c.primary : c.onSurfaceVariant,
                size: 21,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.value.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.value.$2,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.onSurfaceVariant,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      _cta(c, l.exportStartButton, icon: Icons.file_download),
    ],
  );

  Widget _post(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      InputDecorator(
        decoration: InputDecoration(
          labelText: l.communityPostTitleLabel,
          counterText: '0/100',
          border: const OutlineInputBorder(),
        ),
        child: const SizedBox(height: 20),
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 43,
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.video_file_outlined),
          label: Text(l.communityPostPickVideo),
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: false,
        onChanged: (_) {},
        title: Text(l.communityPostAsShort),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: false,
        onChanged: (_) {},
        title: Text(l.communityContainsGenerativeAiImageVideo),
        subtitle: Text(
          l.communityContainsGenerativeAiImageVideoHelp,
          style: const TextStyle(fontSize: 11),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: true,
        onChanged: (_) {},
        title: Text(l.communityPostShowInPlaza),
        subtitle: Text(
          l.communityPostShowInPlazaHelp,
          style: const TextStyle(fontSize: 11),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        l.themePreviewSampleDescriptionLabel,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Container(
        height: 98,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.outline),
        ),
        alignment: Alignment.topLeft,
        child: Text(
          l.themePreviewSampleDescriptionHint,
          style: TextStyle(color: c.onSurfaceVariant),
        ),
      ),
      const SizedBox(height: 12),
      _mockSettingRow(c, Icons.sell_outlined, l.projectDetailTagsQuickAction),
      const SizedBox(height: 16),
      _cta(c, l.communityPostButton, icon: Icons.cloud_upload_outlined),
    ],
  );

  // Mirrors the real notification list: follower and bookmark milestones.
  Widget _notifications(ColorScheme c) {
    final items = [
      (Icons.people_outline, l.communityFollowerMilestone('100')),
      (
        Icons.bookmarks_outlined,
        l.communityBookmarkMilestone(l.themePreviewSampleWorkTitle1, '50'),
      ),
      (Icons.people_outline, l.communityFollowerMilestone('50')),
      (
        Icons.bookmarks_outlined,
        l.communityBookmarkMilestone(l.themePreviewSampleWorkTitle2, '10'),
      ),
    ];
    return ListView.separated(
      key: const Key('themePreviewContentList'),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => ListTile(
        leading: Icon(items[i].$1, color: accentText),
        title: Text(items[i].$2),
        subtitle: Text('2026/10/2${3 - i}'),
      ),
    );
  }

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
                  color: c.outlineVariant.withValues(alpha: .65),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.add, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.saveTreeSlotLabel(i + 1),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.saveTreeNoDataLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_note, color: accentText),
                  const SizedBox(width: 18),
                  Icon(
                    Icons.book_outlined,
                    color: c.onSurfaceVariant.withValues(alpha: .6),
                  ),
                  const SizedBox(width: 18),
                  Icon(
                    Icons.delete_outline,
                    color: c.onSurfaceVariant.withValues(alpha: .6),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _materials(ColorScheme c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: c.primary.withValues(alpha: .16),
            child: Icon(Icons.perm_media_outlined, size: 36, color: accentText),
          ),
          const SizedBox(height: 18),
          Text(
            l.materialEmptyTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l.materialEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _communityWork(ColorScheme c) => ListView(
    key: const Key('themePreviewContentList'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFB9C8), Color(0xFFFF6485)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: .58),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 20,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: c.outlineVariant,
            ),
          ),
        ),
      ),

      Text(
        l.themePreviewSampleWorkTitle2,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: c.primary.withValues(alpha: .18),
            child: Text(
              l.themePreviewSampleStudio.characters.first,
              style: TextStyle(color: accentText),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l.themePreviewSampleStudio,
            style: TextStyle(color: accentText, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Icon(Icons.play_arrow, size: 14, color: c.onSurfaceVariant),
          Text(
            '9,637',
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.thumb_up_alt_outlined,
            size: 14,
            color: c.onSurfaceVariant,
          ),
          Text(
            '326',
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Icon(Icons.bookmark_border, size: 14, color: c.onSurfaceVariant),
          Text(
            '1,412',
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Icon(Icons.repeat, size: 14, color: c.onSurfaceVariant),
          Text('0', style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        l.communityWorkDetailPostedLabel('2026/10/14'),
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NIARIM',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 13,
              runSpacing: 9,
              children: [
                for (final x in [
                  '2400f',
                  '24fps',
                  '1920×1080',
                  '6h 40m',
                  '2026/10/13',
                ])
                  Text(
                    x,
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final item in [
        (
          Icons.public,
          l.communityVisibilityCardTitle,
          l.communityVisibilityPublishedDesc,
          true,
        ),
        (
          Icons.auto_awesome,
          l.communityContainsGenerativeAiImageVideo,
          l.communityContainsGenerativeAiImageVideoHelp,
          false,
        ),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item.$1, color: accentText),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(value: item.$4, onChanged: (_) {}),
            ],
          ),
        ),
    ],
  );

  Widget _mockCommunityCard(ColorScheme c, String title) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.onSurface),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.98,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.primary.withValues(alpha: .28),
                        c.primary.withValues(alpha: .82),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: c.onSurface.withValues(alpha: .82),
                  child: Icon(Icons.play_arrow, color: c.surface, size: 25),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: c.onSurface.withValues(alpha: .82),
                  child: Icon(
                    Icons.bookmark_border,
                    color: c.surface,
                    size: 23,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  color: c.onSurface.withValues(alpha: .8),
                  child: Text(
                    '1:25',
                    style: TextStyle(fontSize: 9, color: c.surface),
                  ),
                ),
              ),
            ],
          ),
        ),
        _mockCardText(c, title, fontSize: 12),
      ],
    ),
  );

  Widget _author(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(
        l.themePreviewSampleArtist,
        style: const TextStyle(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      actions: [
        Icon(Icons.filter_alt_outlined, color: c.onSurface),
        const SizedBox(width: 6),
        Icon(Icons.arrow_drop_down, color: c.onSurface),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Row(
          children: [
            for (final name in [
              l.communityAuthorTabWorks,
              l.communityAuthorTabBookmarks,
            ])
              Expanded(
                child: Container(
                  height: 47,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: name == l.communityAuthorTabWorks
                            ? c.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: name == l.communityAuthorTabWorks
                          ? accentText
                          : c.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.primaryContainer,
                child: Text(
                  l.themePreviewSampleArtist.characters.first,
                  style: TextStyle(fontSize: 18, color: c.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.themePreviewSampleArtist,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 2,
                      children: [
                        for (final label in [
                          l.communityAuthorWorksCount(3),
                          l.communityAuthorFollowingCount(4),
                          l.communityAuthorFollowerCount(12),
                        ])
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'HakkouMincho',
                              fontFamilyFallback: kBodyFontFallback,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l.communityFavoriteAuthorFollow),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              _cardRows([
                _mockCommunityCard(c, l.themePreviewSampleWorkTitle1),
                _mockCommunityCard(c, l.themePreviewSampleWorkTitle2),
                _mockCommunityCard(c, l.themePreviewSampleWorkTitle3),
              ], spacing: 10),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _myWorks(ColorScheme c) => Scaffold(
    backgroundColor: c.surface,
    appBar: AppBar(
      title: Text(l.communityMyWorksTitle),
      actions: [
        Icon(Icons.refresh, color: c.onSurface),
        const SizedBox(width: 16),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            elevation: 0,
            color: c.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: c.primaryContainer,
                        child: Icon(
                          Icons.person_outline,
                          color: c.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.communityMyWorksAccountNotConnected,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.video_call_outlined),
                        label: Text(l.communityPostButton),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.account_circle_outlined),
                        label: Text(l.communityMyWorksAddAccount),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 実際の「自分の投稿」の空の表示と同じ色。
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: accentText.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 12),
                Text(
                  l.communityEmptyState,
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // SCREEN_LAYOUTS
}
