import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/accent_text_theme.dart';
import '../config/font_fallback.dart';
import '../l10n/app_localizations.dart';

/// アプリの使い方（はじめのガイド）。初回起動のホームと、設定・ヘルプの
/// 「使い方」から開く。図（アプリの画面を簡略化した絵に、操作する場所の
/// 番号付きの印）と番号付きの手順のページを、スワイプか「次へ」でめくる。
/// どのページからでも「スキップ」で閉じられる。
///
/// 図はアプリの部品（実際のアイコン・テーマの色）で描くので、テーマを
/// 変えても実際の画面と見え方がそろい、言語ごとの画像も要らない。
class AppTutorial extends StatefulWidget {
  const AppTutorial({super.key});

  /// 使い方を開き、閉じるまで待つ（スキップ・最後まで見た・戻る操作）。
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AppTutorial(),
  );

  @override
  State<AppTutorial> createState() => _AppTutorialState();
}

class _AppTutorialState extends State<AppTutorial> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_TutorialPage> _pages(AppLocalizations l10n) => [
    _TutorialPage(
      l10n.tutorialPage1Title,
      [
        l10n.tutorialPage1Step1,
        l10n.tutorialPage1Step2,
        l10n.tutorialPage1Step3,
      ],
      const _WelcomeFigure(),
      lead: l10n.homeFirstLaunchMessage,
    ),
    _TutorialPage(l10n.tutorialPage2Title, [
      l10n.tutorialPage2Step1,
      l10n.tutorialPage2Step2,
      l10n.tutorialPage2Step3,
    ], const _HomeFigure()),
    _TutorialPage(l10n.tutorialPage3Title, [
      l10n.tutorialPage3Step1,
      l10n.tutorialPage3Step2,
      l10n.tutorialPage3Step3,
    ], const _CanvasFigure()),
    _TutorialPage(l10n.tutorialPage4Title, [
      l10n.tutorialPage4Step1,
      l10n.tutorialPage4Step2,
      l10n.tutorialPage4Step3,
    ], const _FramesFigure()),
    _TutorialPage(l10n.tutorialPage5Title, [
      l10n.tutorialPage5Step1,
      l10n.tutorialPage5Step2,
      l10n.tutorialPage5Step3,
    ], const _ExportFigure()),
    _TutorialPage(l10n.tutorialPage6Title, [
      l10n.tutorialPage6Step1,
      l10n.tutorialPage6Step2,
      l10n.tutorialPage6Step3,
    ], const _HelpFigure()),
  ];

  void _next(int count) {
    if (_page >= count - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages(l10n);
    final last = _page == pages.length - 1;
    final body = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const Key('tutorialPages'),
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) =>
                  _TutorialPageView(page: pages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              children: [
                Semantics(
                  label: l10n.tutorialPageIndicator(_page + 1, pages.length),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 大きな文字で横に並びきらなければ、縦に積む（「次へ」が下）。
                OverflowBar(
                  alignment: last
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.center,
                  overflowSpacing: 4,
                  children: [
                    if (!last)
                      TextButton(
                        key: const Key('tutorialSkip'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.tutorialSkip,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    FilledButton(
                      key: Key(last ? 'tutorialStart' : 'tutorialNext'),
                      onPressed: () => _next(pages.length),
                      child: Text(
                        last ? l10n.homeFirstLaunchStart : l10n.tutorialNext,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // スマホ（縦・横）は画面いっぱい、PC・タブレットは中央の枠。
    final screen = MediaQuery.sizeOf(context);
    if (screen.width < 600 || screen.height < 500) {
      return Dialog.fullscreen(child: body);
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: body,
      ),
    );
  }
}

class _TutorialPage {
  const _TutorialPage(this.title, this.steps, this.figure, {this.lead});
  final String title;
  final List<String> steps;
  final Widget figure;

  /// 見出しの下に添える一文（手順の前置き）。
  final String? lead;
}

class _TutorialPageView extends StatelessWidget {
  const _TutorialPageView({required this.page});

  final _TutorialPage page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 図の中の小さな文字は絵の一部なので、文字の大きさの設定では変えない
    // （手順の文は設定どおり大きくなる）。
    final figure = MediaQuery.withNoTextScaling(
      child: FittedBox(child: page.figure),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
            color: scheme.onSurface,
          ),
        ),
        if (page.lead != null) ...[
          const SizedBox(height: 8),
          Text(
            page.lead!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < page.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(i + 1),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    page.steps[i],
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // 横長の画面（スマホの横向き）は図と手順を左右に並べる。
        if (constraints.maxWidth >= 560 &&
            constraints.maxWidth > constraints.maxHeight * 1.4) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(flex: 5, child: figure),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SingleChildScrollView(child: text),
                  ),
                ),
              ],
            ),
          );
        }
        // 縦長の画面は図と手順を上下に並べ、余れば上下の中央に置く。
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 36),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: math.min(constraints.maxHeight * 0.42, 280),
                  child: figure,
                ),
                const SizedBox(height: 20),
                text,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 手順の番号。図の中で操作する場所に付ける印と同じ形。
class _StepBadge extends StatelessWidget {
  const _StepBadge(this.number, {this.size = 24});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 文字の大きさの設定に合わせて丸も大きくする（数字がはみ出さない）。
    final side = MediaQuery.textScalerOf(context).scale(size);
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: size * 0.55,
          height: 1,
          fontWeight: FontWeight.w700,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

// ─── 図（320×200の設計の大きさで描き、ページの幅に合わせて縮める） ───

const _figureSize = Size(320, 200);

/// 図の土台：簡略化した画面と、操作する場所の印。
class _Figure extends StatelessWidget {
  const _Figure({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: _figureSize,
    child: Stack(clipBehavior: Clip.none, children: children),
  );
}

/// 簡略化した画面の枠。
class _MockScreen extends StatelessWidget {
  const _MockScreen({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 操作する場所：囲みの線と、右上に手順の番号。囲む相手に付けて描くので、
/// 言語によって文字の幅が変わっても印がずれない。
class _Marked extends StatelessWidget {
  const _Marked({
    required this.number,
    required this.child,
    this.circle = false,
  });

  final int number;
  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circle ? null : BorderRadius.circular(8),
                border: Border.all(color: scheme.primary, width: 2.5),
              ),
            ),
          ),
        ),
        Positioned(
          top: circle ? -12 : -11,
          right: circle ? -12 : -11,
          child: _StepBadge(number, size: 18),
        ),
      ],
    );
  }
}

/// 灰色の帯（文字の代わり）。
class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.height = 6, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color:
          color ??
          Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

/// 1枚のフレーム（白い紙に、弾むボールの絵）。[ghostY]があれば前の
/// フレームの絵を薄く重ねる（オニオンスキン）。
class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.size,
    required this.ballY,
    this.highlight = false,
    this.ghostY,
    this.ghostMark,
  });

  final Size size;
  final double ballY;
  final bool highlight;
  final double? ghostY;

  /// 薄く重ねた絵に付ける手順の番号。
  final int? ghostMark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;
    final ball = size.width * 0.26;
    final floor = size.height * 0.12;
    Widget ghost = _Ball(size: ball, color: ink.withValues(alpha: 0.2));
    if (ghostMark != null) {
      ghost = _Marked(number: ghostMark!, circle: true, child: ghost);
    }
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? scheme.primary : scheme.outlineVariant,
          width: highlight ? 2.5 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            right: 4,
            bottom: floor,
            child: Container(height: 1.5, color: ink.withValues(alpha: 0.5)),
          ),
          if (ghostY != null)
            Positioned(
              left: (size.width - ball) / 2 - ball * 0.7,
              top: ghostY! * (size.height - ball - floor - 4),
              child: ghost,
            ),
          Positioned(
            left: (size.width - ball) / 2,
            top: ballY * (size.height - ball - floor - 4),
            child: _Ball(size: ball, color: ink),
          ),
        ],
      ),
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
    ),
  );
}

/// 丸い塗りのボタン（FAB・再生）。
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, this.size = 34});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.6, color: scheme.onPrimary),
    );
  }
}

/// 1ページ目：フレームに描く→少しずつ動かして並べる→再生して書き出す。
class _WelcomeFigure extends StatelessWidget {
  const _WelcomeFigure();

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurfaceVariant;
    const card = Size(56, 80);
    return _Figure(
      children: [
        const Positioned(
          left: 10,
          top: 60,
          child: _Marked(number: 1, child: _FrameCard(size: card, ballY: 0)),
        ),
        const Positioned(
          left: 86,
          top: 60,
          child: _Marked(
            number: 2,
            child: Row(
              children: [
                _FrameCard(size: card, ballY: 0.55),
                SizedBox(width: 8),
                _FrameCard(size: card, ballY: 1),
              ],
            ),
          ),
        ),
        Positioned(
          left: 216,
          top: 88,
          child: Icon(Icons.arrow_forward, color: ink),
        ),
        Positioned(
          left: 252,
          top: 56,
          child: _Marked(
            number: 3,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  const _RoundButton(icon: Icons.play_arrow, size: 40),
                  const SizedBox(height: 10),
                  Icon(Icons.video_file_outlined, size: 28, color: ink),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 2ページ目：ホームの＋→新規プロジェクト→作成、一覧。
class _HomeFigure extends StatelessWidget {
  const _HomeFigure();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accentText = AccentTextTheme.of(context);
    const small = TextStyle(fontSize: 10, height: 1.2);
    final heading = small.copyWith(
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    Widget row(double barWidth) => Padding(
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          _Bar(width: barWidth),
        ],
      ),
    );
    return _Figure(
      children: [
        Positioned.fromRect(
          rect: const Rect.fromLTWH(20, 6, 280, 188),
          child: _MockScreen(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    children: [
                      for (final (i, label) in [
                        l10n.homeTabProjects,
                        l10n.homeTabWorks,
                        l10n.homeTabBookmarked,
                      ].indexed)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: heading.copyWith(
                                  color: i == 0
                                      ? accentText
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 2,
                                color: i == 0
                                    ? scheme.primary
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
                  child: _Marked(number: 3, child: row(70)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                  child: row(58),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                  child: row(46),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 74,
          top: 96,
          child: _Marked(
            number: 2,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).dialogTheme.backgroundColor ??
                    scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Color(0x33000000)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        size: 14,
                        color: accentText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.homeAddSheetNewProject,
                        style: small.copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.commonCreate,
                      style: heading.copyWith(color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          right: 32,
          bottom: 18,
          child: _Marked(
            number: 1,
            circle: true,
            child: _RoundButton(icon: Icons.add),
          ),
        ),
      ],
    );
  }
}

/// 3ページ目：キャンバスのツール・色・取り消し。
class _CanvasFigure extends StatelessWidget {
  const _CanvasFigure();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurfaceVariant;
    final accentText = AccentTextTheme.of(context);
    return _Figure(
      children: [
        Positioned.fromRect(
          rect: const Rect.fromLTWH(20, 6, 280, 188),
          child: _MockScreen(
            color: scheme.surfaceContainerHighest,
            child: Stack(
              children: [
                Positioned(
                  left: 60,
                  top: 30,
                  width: 160,
                  height: 112,
                  child: Container(
                    color: Colors.white,
                    child: CustomPaint(
                      painter: _DoodlePainter(scheme.onSurface),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 10,
                  child: _Marked(
                    number: 3,
                    child: Row(
                      children: [
                        Icon(Icons.undo, size: 16, color: ink),
                        const SizedBox(width: 6),
                        Icon(Icons.redo, size: 16, color: ink),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Marked(
                        number: 1,
                        circle: true,
                        child: Icon(Icons.brush, size: 18, color: accentText),
                      ),
                      FaIcon(FontAwesomeIcons.eraser, size: 15, color: ink),
                      FaIcon(FontAwesomeIcons.fillDrip, size: 15, color: ink),
                      Icon(Icons.colorize, size: 18, color: ink),
                      Icon(Icons.highlight_alt, size: 18, color: ink),
                      Icon(Icons.text_fields, size: 18, color: ink),
                      _Marked(
                        number: 2,
                        circle: true,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: scheme.onSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      Icon(Icons.layers_outlined, size: 18, color: ink),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 4ページ目：フレーム一覧・＋・前のフレームを薄く重ねる。
class _FramesFigure extends StatelessWidget {
  const _FramesFigure();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const thumb = Size(36, 36);
    return _Figure(
      children: [
        Positioned.fromRect(
          rect: const Rect.fromLTWH(20, 6, 280, 188),
          child: _MockScreen(
            color: scheme.surfaceContainerHighest,
            child: const SizedBox.expand(),
          ),
        ),
        const Positioned(
          left: 100,
          top: 16,
          child: _FrameCard(
            size: Size(120, 110),
            ballY: 0.8,
            ghostY: 0.3,
            ghostMark: 3,
          ),
        ),
        Positioned(
          left: 70,
          top: 146,
          child: Row(
            children: [
              const _FrameCard(size: thumb, ballY: 0.1),
              const SizedBox(width: 8),
              const _FrameCard(size: thumb, ballY: 0.45),
              const SizedBox(width: 12),
              const _Marked(
                number: 1,
                child: _FrameCard(size: thumb, ballY: 0.8, highlight: true),
              ),
              const SizedBox(width: 14),
              _Marked(
                number: 2,
                child: Container(
                  width: thumb.width,
                  height: thumb.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5ページ目：タイムラインを開く→再生→書き出し。
class _ExportFigure extends StatelessWidget {
  const _ExportFigure();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurfaceVariant;
    return _Figure(
      children: [
        Positioned.fromRect(
          rect: const Rect.fromLTWH(8, 22, 126, 160),
          child: _MockScreen(
            color: scheme.surfaceContainerHighest,
            child: Stack(
              children: [
                const Positioned(
                  left: 18,
                  right: 18,
                  top: 36,
                  bottom: 30,
                  child: ColoredBox(color: Colors.white),
                ),
                Positioned(
                  right: 8,
                  top: 10,
                  child: _Marked(
                    number: 1,
                    child: Row(
                      children: [
                        Icon(Icons.movie_filter_outlined, size: 16, color: ink),
                        Icon(Icons.chevron_right, size: 12, color: ink),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 140,
          top: 90,
          child: Icon(Icons.arrow_forward, color: ink),
        ),
        Positioned.fromRect(
          rect: const Rect.fromLTWH(170, 22, 142, 160),
          child: _MockScreen(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  height: 66,
                  color: Colors.white,
                ),
                _Marked(
                  number: 2,
                  circle: true,
                  child: Icon(Icons.play_arrow, size: 22, color: ink),
                ),
                const Spacer(),
                Container(
                  color: scheme.surfaceContainerHigh,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.add_circle_outline, size: 14, color: ink),
                      Icon(Icons.layers_outlined, size: 14, color: ink),
                      _Marked(
                        number: 3,
                        circle: true,
                        child: Icon(Icons.upload_file, size: 14, color: ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 6ページ目：？・はじめての説明・設定から見直す。
class _HelpFigure extends StatelessWidget {
  const _HelpFigure();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurfaceVariant;
    final accentText = AccentTextTheme.of(context);
    return _Figure(
      children: [
        Positioned.fromRect(
          rect: const Rect.fromLTWH(20, 6, 280, 188),
          child: _MockScreen(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: ink),
                      const SizedBox(width: 10),
                      const _Bar(width: 70, height: 8),
                      const Spacer(),
                      _Marked(
                        number: 1,
                        circle: true,
                        child: Icon(Icons.help_outline, size: 18, color: ink),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 10, 0, 0),
                  child: _Marked(
                    number: 2,
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: scheme.onInverseSurface,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _Bar(
                              width: double.infinity,
                              color: scheme.onInverseSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _Marked(
                    number: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 14, color: ink),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 12, color: ink),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: accentText,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.settingsTutorialTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// キャンバスの絵（なめらかな線）。
class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.7)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.55,
        size.height * 0.95,
        size.width * 0.85,
        size.height * 0.3,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.35),
      size.height * 0.12,
      paint,
    );
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => oldDelegate.color != color;
}
