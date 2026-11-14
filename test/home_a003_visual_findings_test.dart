import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

// ホームの表示マトリクス・初回の案内・幅の連続変更（A003）の画像を見比べて
// 見つかった見た目の不具合の見張り。本物のアプリ（buildAppProviders＋
// NiarimApp）を同梱の書体で描き、描かれた文字・色・位置で確かめる。

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

/// 表示マトリクスの自作テーマ：用紙は明るく、メニュー（上部バー・引き出し・
/// カード）は暗く、本文の文字は暗い・メニューの文字は明るい。
const _customTheme = AppThemePreset(
  id: ThemeService.customCurrentId,
  name: 'Matrix custom',
  accentColor: Color(0xFF2E7D6B),
  textColor: Color(0xFF1F2328),
  buttonTextColor: Color(0xFFFFFFFF),
  menuTextColor: Color(0xFFEDEFF2),
  selectionTextColor: Color(0xFFFFFFFF),
  panelBgColor: Color(0xFFF7F4EC),
  menuBgColor: Color(0xFF1E2430),
  selectionColor: Color(0xFF2E7D6B),
  updateMarkColor: Color(0xFFE0A100),
);

/// 初回の案内を見たことの保存だけを断る保存先。
class _RejectFirstLaunchStore extends SharedPreferencesStorePlatform {
  _RejectFirstLaunchStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.first_launch' && value == false) {
      return Future.value(false);
    }
    return delegate.setValue(valueType, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
}

class _Home {
  _Home(this.tester);

  final WidgetTester tester;
  late Directory directory;
  late ProjectService projects;
  late SettingsService settings;
  late ThemeService themes;

  AppLocalizations get l10n =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Future<void> frames([int count = 8]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settleIo([int rounds = 3]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> open({
    String language = 'ja',
    Size size = const Size(390, 844),
    double scale = 1,
    double top = 0,
    double bottom = 0,
    bool failing = false,
    bool firstLaunch = false,
    bool rejectFirstLaunchSave = false,
    Map<String, Object> prefs = const {},
  }) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': firstLaunch,
      'language': language,
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    if (rejectFirstLaunchSave) {
      final store = _RejectFirstLaunchStore(
        SharedPreferencesStorePlatform.instance,
      );
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = store.delegate,
      );
    }
    directory = Directory.systemTemp.createTempSync('niarim_a003_visual_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (failing && call.method == 'getApplicationDocumentsDirectory') {
        return null;
      }
      return directory.path;
    });
    messenger.setMockStreamHandler(
      _ffmpegEventChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final insets = FakeViewPadding(top: top, bottom: bottom);
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      messenger.setMockMethodCallHandler(_pathChannel, null);
      messenger.setMockStreamHandler(_ffmpegEventChannel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          if (directory.existsSync()) directory.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });
    ExportStorage.invalidate();
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await frames(6);
    await settleIo();
    final home = tester.element(find.byType(HomeScreen));
    projects = home.read<ProjectService>();
    settings = home.read<SettingsService>();
    themes = home.read<ThemeService>();
  }

  /// 終わったら画面を外し、保存の途中の処理を終わらせる。
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settleIo(2);
  }

  Future<Project> addProject(String name, {bool favourite = false}) async {
    late Project project;
    await tester.runAsync(() async {
      project = await projects.createProject(
        name: name,
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 640,
        exportHeight: 360,
      );
      if (favourite) await projects.setFavorite(project.id, true);
    });
    await frames(4);
    await settleIo();
    return project;
  }

  Future<void> addFolder(String name) async {
    await tester.runAsync(() => projects.createFolder(name));
    await frames(4);
    await settleIo();
  }

  /// 書き出した作品のファイルを置く（[trash]ならゴミ箱へ移す）。
  Future<void> addExports(
    List<String> names, {
    List<String> trash = const [],
  }) async {
    await tester.runAsync(() async {
      final exports = await ExportStorage.createManagedDirectory();
      for (final name in names) {
        File('${exports.path}/$name').writeAsBytesSync(List.filled(64, 1));
      }
      for (final name in trash) {
        await LocalFileTrashService.move(
          File('${exports.path}/$name'),
          LocalTrashKind.exportedWork,
        );
      }
      ExportStorage.invalidate();
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });
    await frames(4);
    await settleIo();
  }

  Future<void> trashProject(String name) async {
    await tester.runAsync(() async {
      final project = await projects.createProject(
        name: name,
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await projects.deleteProject(project.id);
    });
    await frames(4);
    await settleIo();
  }

  Future<void> setPc(bool value) async {
    await tester.runAsync(() => settings.setForcePcMode(value));
    await frames(6);
  }

  /// タブを開き、その一覧の読み込み（本物のファイルの読み書き）を待つ。
  Future<void> showTab(int index) async {
    await tester.tap(find.byKey(ValueKey('home_tab_$index')));
    await frames(10);
    for (var i = 0; i < 5; i++) {
      await settleIo(3);
      await frames(4);
    }
  }

  /// テーマを替え、テーマの移り変わり（アニメーション）を終える。
  Future<void> applyTheme(AppThemePreset preset) async {
    themes.previewCurrent(preset);
    await frames(12);
  }
}

/// [finder]の描いた段落（Text・Text.richの中のRenderParagraph）。
RenderParagraph _paragraph(WidgetTester tester, Finder finder) {
  final element = finder.evaluate().single;
  RenderParagraph? found;
  void visit(Element e) {
    if (found != null) return;
    final render = e.renderObject;
    if (render is RenderParagraph) {
      found = render;
      return;
    }
    e.visitChildElements(visit);
  }

  visit(element);
  return found!;
}

/// 描いた段落の根の書式（Text が DefaultTextStyle と合わせた書式）。
TextStyle _style(RenderParagraph paragraph) => paragraph.text.style!;

/// [element]から外へたどって最初に出会う[Material]の色。
Color? _materialColorAround(Element element) {
  Color? color;
  element.visitAncestorElements((a) {
    final widget = a.widget;
    if (widget is Material && widget.color != null) {
      color = widget.color;
      return false;
    }
    return true;
  });
  return color;
}

/// 2つの字の間で行が変わっている所のうち、[inWord]が両方の字に真を返す所
/// （語の途中での折り返し）。
List<String> _breaksInsideWords(
  RenderParagraph paragraph,
  bool Function(String char) inWord,
) {
  final lines = ParagraphLines(paragraph);
  final text = lines.visible;
  final found = <String>[];
  for (var i = 1; i < text.length; i++) {
    final a = lines.lineOf(i - 1);
    final b = lines.lineOf(i);
    if (a == null || b == null || a == b) continue;
    if (inWord(text[i - 1]) && inWord(text[i])) {
      found.add(
        '${text.substring(0, i)} / ${text.substring(i)}'.replaceAll('\n', ' '),
      );
    }
  }
  return found;
}

final _hangulSyllable = RegExp(r'[가-힣]');
bool _isHangul(String c) => _hangulSyllable.hasMatch(c);
bool _isLatinLetter(String c) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(c);

void main() {
  testWidgets('共有の切り替えの選んでいない側の名前・印が、その下地の上で読める', (tester) async {
    final home = _Home(tester);
    for (final (size, language) in const [
      (Size(390, 844), 'ja'),
      (Size(1280, 900), 'en'),
    ]) {
      await home.open(language: language, size: size);
      await home.applyTheme(_customTheme);
      await home.showTab(2);
      for (final outgoing in [false, true]) {
        if (outgoing) {
          final control = find.byKey(
            const Key('sharedDirectionSegmentedControl'),
          );
          final segments = find.descendant(
            of: control,
            matching: find.byType(TextButton),
          );
          await tester.tap(segments.last);
          await home.frames(6);
          await home.settleIo(2);
        }
        final control = find.byKey(
          const Key('sharedDirectionSegmentedControl'),
        );
        expect(control, findsOneWidget);
        final faint = <String>[];
        for (final element
            in find
                .descendant(of: control, matching: find.byType(RichText))
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final ink = _style(paragraph).color!;
          final under = _materialColorAround(element)!;
          final ratio = contrastRatio(
            opaqueOver(ink, under),
            opaqueOver(under, _customTheme.panelBgColor),
          );
          if (ratio < 3) {
            faint.add(
              '"${paragraph.text.toPlainText()}" $ink on $under '
              '(${ratio.toStringAsFixed(2)}:1)',
            );
          }
        }
        expect(
          faint,
          isEmpty,
          reason:
              '$language ${size.width.round()} outgoing=$outgoing: '
              'labels/icons not readable on their segment',
        );
      }
      await home.close();
    }
  });

  testWidgets('お気に入りでないカードの星が、丸い下地の上で見える', (tester) async {
    final home = _Home(tester);
    await home.open(size: const Size(390, 844));
    await home.addProject('星なし');
    await home.addProject('星あり', favourite: true);
    await home.applyTheme(_customTheme);
    final faint = <String>[];
    for (final element
        in find
            .byWidgetPredicate(
              (w) =>
                  w is Icon &&
                  w.icon == Icons.star &&
                  w.size != null &&
                  w.size! <= 16,
            )
            .evaluate()) {
      final icon = element.widget as Icon;
      Color? fill;
      element.visitAncestorElements((a) {
        final w = a.widget;
        if (w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle) {
          fill = (w.decoration as BoxDecoration).color;
          return false;
        }
        return true;
      });
      final under = opaqueOver(fill!, _customTheme.panelBgColor);
      final ratio = contrastRatio(opaqueOver(icon.color!, under), under);
      if (ratio < 3) {
        faint.add('${icon.color} on $fill (${ratio.toStringAsFixed(2)}:1)');
      }
    }
    expect(faint, isEmpty, reason: 'favourite stars not visible');
    await home.close();
  });

  testWidgets('引き出しの見出しのアプリ名は見出しの書体（くらむぼん）', (tester) async {
    final home = _Home(tester);
    await home.open(size: const Size(390, 844));
    final menu = find.byIcon(Icons.menu);
    await tester.tap(menu.last);
    await home.frames(10);
    final paragraph = _paragraph(tester, find.text('NIARIM').last);
    expect(_style(paragraph).fontFamily, 'Kuramubon');
    expect(_style(paragraph).fontFamilyFallback, kHeadingFontFallback);
    await home.close();
  });

  testWidgets('文字2倍の狭い画面では列を減らし、カードの名前を語の途中で切らない', (tester) async {
    final home = _Home(tester);
    await home.open(size: const Size(320, 844), scale: 2);
    await home.addFolder('Archive of finished commissions');
    for (var i = 1; i <= 4; i++) {
      await home.addProject('カット0$i');
    }
    final grid = tester.renderObject<RenderSliverGrid>(
      find.byType(SliverGrid).first,
    );
    final layout =
        grid.gridDelegate.getLayout(grid.constraints)
            as SliverGridRegularTileLayout;
    final name = _paragraph(
      tester,
      find.text('Archive of finished commissions', findRichText: true),
    );
    expect(
      _breaksInsideWords(name, _isLatinLetter),
      isEmpty,
      reason: 'card width ${layout.childCrossAxisExtent}',
    );
    expect(
      layout.crossAxisCount,
      lessThanOrEqualTo(2),
      reason: 'card width ${layout.childCrossAxisExtent} at text x2 on 320',
    );
    await home.close();
  });

  testWidgets('一覧が空なら「一番上へ」は出さない（送る先が無い）', (tester) async {
    final home = _Home(tester);
    await home.open(size: const Size(390, 844));
    expect(find.byKey(const Key('homeScrollToTopFab')), findsNothing);
    for (var i = 1; i <= 12; i++) {
      await home.addProject('カット$i');
    }
    expect(find.byKey(const Key('homeScrollToTopFab')), findsOneWidget);
    await home.close();
  });

  testWidgets('状態バー・ボタンの帯のある低い画面・文字2倍でも、作り方の案内が浮かぶボタンに隠れない', (tester) async {
    final home = _Home(tester);
    for (final language in const ['ja', 'en', 'es', 'fr', 'ko']) {
      await home.open(
        language: language,
        size: const Size(320, 568),
        scale: 2,
        top: 24,
        bottom: 48,
      );
      final hint = find.text(home.l10n.projectListEmptyHint);
      expect(hint, findsOneWidget, reason: language);
      final hintRect = tester.getRect(hint);
      // 案内は、一覧の見える所（スクロールの枠）の中に全部見えている。
      final viewport = tester.getRect(
        find.ancestor(of: hint, matching: find.byType(Scrollable)).first,
      );
      expect(
        hintRect.bottom,
        lessThanOrEqualTo(viewport.bottom + 0.5),
        reason: '$language hint $hintRect cut by $viewport',
      );
      for (final fab in find.byType(FloatingActionButton).evaluate()) {
        final fabRect = tester.getRect(find.byWidget(fab.widget));
        expect(
          hintRect.overlaps(fabRect),
          isFalse,
          reason: '$language hint $hintRect under a FAB $fabRect',
        );
      }
      await home.close();
    }
  });

  testWidgets('横向きの低い画面（640x360）でも、空の表示の見出しを途中で切らない', (tester) async {
    final home = _Home(tester);
    for (final language in const ['en', 'fr', 'ko']) {
      await home.open(language: language, size: const Size(640, 360));
      final l10n = home.l10n;
      for (final (tab, title) in [
        (2, l10n.homeSharedEmpty),
        (3, l10n.homeTrashEmpty),
      ]) {
        await home.showTab(tab);
        // 描いた段落（Text.richの読み上げの名前でも探せる）のうち、画面の中の
        // もの（タブを送る前の隣のタブは画面の外）。
        final shown = find
            .text(title, findRichText: true)
            .evaluate()
            .where((e) => e.widget is RichText)
            .where((e) {
              final rect = tester.getRect(find.byWidget(e.widget));
              return rect.left >= 0 && rect.right <= 640;
            })
            .toList();
        expect(shown, hasLength(1), reason: '$language tab $tab');
        final rect = tester.getRect(find.byWidget(shown.single.widget));
        final viewport = tester.getRect(
          find
              .ancestor(
                of: find.byWidget(shown.single.widget),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(viewport.bottom + 0.5),
          reason: '$language tab $tab: "$title" $rect cut by $viewport',
        );
      }
      await home.close();
    }
  });

  testWidgets('並び順の名前は、省略記号で切らずに全部出すか印だけにする（英語・320・文字1.3倍）', (tester) async {
    final home = _Home(tester);
    await home.open(language: 'en', size: const Size(320, 844), scale: 1.3);
    await home.addProject('Walk cycle');
    for (final tab in [0, 1, 2]) {
      if (tab != 0) await home.showTab(tab);
      final label = find.text(home.l10n.homeSortFieldUpdated);
      for (final element in label.evaluate()) {
        final paragraph = element.renderObject;
        if (paragraph is! RenderParagraph || !paragraph.attached) continue;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'tab $tab: sort label cut to "Updat…"',
        );
      }
    }
    await home.close();
  });

  testWidgets('作品一覧を読めなかったときも、ほかのタブと同じ知らせと「再試行」', (tester) async {
    final home = _Home(tester);
    await home.open(language: 'en', size: const Size(390, 844), failing: true);
    await home.showTab(1);
    final message = find.text(home.l10n.homeWorksLoadFailed);
    expect(message, findsOneWidget);
    expect(
      find.ancestor(
        of: message,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'ProjectsLoadFailureNotice',
        ),
      ),
      findsOneWidget,
      reason: 'works failure is drawn differently from the other tabs',
    );
    await home.close();
  });

  testWidgets('韓国語：ゴミ箱の「삭제됨」・日付、詳細表示の名前、作品一覧の読めなかった知らせ', (tester) async {
    final home = _Home(tester);
    final problems = <String>[];
    for (final width in const [320.0, 360.0, 390.0]) {
      await home.open(
        language: 'ko',
        size: Size(width, 844),
        scale: 1.3,
        prefs: const {'home.projectViewMode.v1': 'detail'},
      );
      await home.addProject('애니메이션 연습 장면과 표정 연습 모음');
      for (final element
          in find
              .text('애니메이션 연습 장면과 표정 연습 모음', findRichText: true)
              .evaluate()) {
        final render = element.renderObject;
        if (render is! RenderParagraph) continue;
        problems.addAll(
          _breaksInsideWords(render, _isHangul).map((b) => '$width name: $b'),
        );
      }
      await home.trashProject('오래된 초안');
      await home.showTab(3);
      for (final element
          in find.textContaining('삭제됨', findRichText: true).evaluate()) {
        final render = element.renderObject;
        if (render is! RenderParagraph) continue;
        problems.addAll(
          _breaksInsideWords(
            render,
            (c) => _isHangul(c) || RegExp(r'[0-9.]').hasMatch(c),
          ).map((b) => '$width trash: $b'),
        );
      }
      await home.close();
    }
    await home.open(
      language: 'ko',
      size: const Size(320, 844),
      scale: 2,
      failing: true,
    );
    await home.showTab(1);
    for (final element
        in find.textContaining('불러오지', findRichText: true).evaluate()) {
      final render = element.renderObject;
      if (render is! RenderParagraph) continue;
      problems.addAll(
        _breaksInsideWords(render, _isHangul).map((b) => 'works: $b'),
      );
    }
    expect(problems, isEmpty);
    await home.close();
  });
}
