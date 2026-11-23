// 設定を変えたとき、その変更がアプリ全体へそろって効くか（全面監査の
// D029の画面ごとの「前・設定・後」、D034の設定のmutation）。
//
// 設定ごとに、変える前のホーム（BEFORE）、変えた値を出している設定の画面
// （SETTINGS）、起動し直した後のホーム・設定・ヘルプ（AFTER）を撮り、
// build/visual-closure/ の manifest.json に足す（PDFは
// tool/build_visual_closure_pdf.py）。起動し直した後の画面がどれも変える前と
// 違うこと（1画面だけ変わる半端な状態でないこと）と、例外・はみ出しが
// 無いことを確かめる。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';

final _out = Directory('build/visual-closure');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-settings-mutation-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('設定を変える前・設定の画面・起動し直した後', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final themes = ThemeService();
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(themes.init);
    AppThemePreset builtIn(String id) =>
        themes.presets.firstWhere((p) => p.id == id);
    final blueDark = builtIn('blue_dark');
    final custom = builtIn('default_light').copyWith(
      id: 'custom_mutation',
      name: '自作（差し色と文字色を別に）',
      accentTextColor: const Color(0xFF1F7A3A),
    );
    themes.dispose();

    final base = <String, Object>{
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    };
    final mutations =
        <
          ({
            String id,
            String name,
            Map<String, Object> prefs,
            double textScale,
            String settingsRoute,
          })
        >[
          (
            id: 'theme_blue_dark',
            name: 'テーマ：レッド（ライト）→ブルー（ダーク）',
            prefs: {'theme_current_json': jsonEncode(blueDark.toJson())},
            textScale: 1,
            settingsRoute: '/settings/theme',
          ),
          (
            id: 'theme_custom_accent_text',
            name: 'テーマ：自作（アクセントの文字・アイコン色を緑に）',
            prefs: {'theme_current_json': jsonEncode(custom.toJson())},
            textScale: 1,
            settingsRoute: '/settings/theme',
          ),
          (
            id: 'language_fr',
            name: '表示言語：日本語→フランス語',
            prefs: {'language': 'fr'},
            textScale: 1,
            settingsRoute: '/settings',
          ),
          (
            id: 'language_ko',
            name: '表示言語：日本語→韓国語',
            prefs: {'language': 'ko'},
            textScale: 1,
            settingsRoute: '/settings',
          ),
          (
            id: 'text_scale_2',
            name: '端末の文字の大きさ：1倍→2倍',
            prefs: const {},
            textScale: 2,
            settingsRoute: '/settings',
          ),
        ];

    Future<Uint8List> shot(
      Map<String, Object> prefs,
      double textScale,
      String route,
      String label,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues(prefs);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      appRouter.go(route);
      final providers = await tester.runAsync(buildAppProviders);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(providers: providers!, child: const NiarimApp()),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull, reason: label);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
      await tester.pumpWidget(const SizedBox.shrink());
      return png;
    }

    String save(String name, Uint8List png) {
      final path = '${_out.path}/settings/$name.png';
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png);
      return path;
    }

    final manifestFile = File('${_out.path}/manifest.json');
    final manifest = manifestFile.existsSync()
        ? (jsonDecode(manifestFile.readAsStringSync()) as List)
              .cast<Map<String, dynamic>>()
              .where((m) => m['kind'] != 'setting')
              .toList()
        : <Map<String, dynamic>>[];

    const afterRoutes = ['/home', '/settings', '/help'];
    final before = {
      for (final route in afterRoutes)
        route: await shot(base, 1, route, 'before $route'),
    };
    final beforePaths = {
      for (final route in afterRoutes)
        route: save('_before${route.replaceAll('/', '_')}', before[route]!),
    };
    for (final m in mutations) {
      final prefs = {...base, ...m.prefs};
      final settings = save(
        '${m.id}_settings',
        await shot(prefs, m.textScale, m.settingsRoute, '${m.id} settings'),
      );
      for (final route in afterRoutes) {
        final after = await shot(prefs, m.textScale, route, '${m.id} $route');
        expect(
          after,
          isNot(equals(before[route])),
          reason: '${m.id}: $route looks the same after the change',
        );
        final path = save('${m.id}_after${route.replaceAll('/', '_')}', after);
        manifest.add({
          'kind': 'setting',
          'id': '${m.id} $route',
          'name': m.name,
          'settings':
              '設定の画面：${m.settingsRoute}（${File(settings).uri.pathSegments.last}）, '
              '変えた値：${m.prefs.keys.isEmpty ? 'textScale=${m.textScale}' : m.prefs.keys.join(', ')}, '
              '後の画面：$route（起動し直した後）',
          'before': beforePaths[route],
          'after': path,
          'settingsImage': settings,
        });
      }
    }
    manifestFile
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  });
}
