// 全部の画面（Routerの全ルート）を、全面監査の表示の組み合わせ（24の幅×
// スマホ/PC×7言語＝336）で開き、レイアウトの例外（はみ出し・描けない
// 部品）が1つも出ないことを確かめる（全面監査のD030・V）。
//
// 言語とスマホ/PCの組ごとに、各画面を1回開き、24の幅へ窓の大きさを変えて
// 描き直す。セルごとの結果は build/route-matrix/route_matrix.json に残す
// （全セルの結果の記録）。問題のあったセルだけ画像を撮る。
//
// 時間がかかる（1言語で十数分、7言語で約2時間）ので、言語ごとに1つのtestに
// してあり、`--dart-define=NIARIM_ROUTE_MATRIX=true`を付けたときだけ動く
// （GitHubの全件のCIの1つの分割の時間に入らない）。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';

const _widths = [
  320, 360, 375, 390, 430, 480, 520, 559, 560, 600, 640, 641, //
  700, 759, 760, 834, 900, 1024, 1180, 1280, 1366, 1440, 1600, 1920,
];
const _languages = ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es'];
const _enabled = bool.fromEnvironment('NIARIM_ROUTE_MATRIX');
const _phoneHeight = 844.0;
const _pcHeight = 900.0;

final _out = Directory('build/route-matrix');

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

/// The rows and columns that do not fit (where their widget is created).
List<String> _overflowing() {
  final found = <String>{};
  void visit(Element element) {
    // FirstThatFits lays out every shape to measure it and draws only the
    // first that fits: the shapes it does not draw may overflow.
    if (element.widget.runtimeType.toString() == '_FirstThatFitsLayout') {
      return;
    }
    final ro = element.renderObject;
    if (element is RenderObjectElement &&
        ro is RenderFlex &&
        ro.attached &&
        ro.toStringShort().contains('OVERFLOWING')) {
      final created = element.widget is Flex
          ? (element.debugGetCreatorChain(4))
          : element.widget.runtimeType.toString();
      found.add('overflowing ${ro.direction.name}: $created');
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in _languages) {
    testWidgets(
      '$language: every screen at 24 widths, phone and PC',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'first_launch': false,
          'language': language,
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        });
        FilePicker.platform = _FakeFilePicker();
        final temp = Directory.systemTemp.createTempSync('niarim-matrix-');
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pathChannel,
          (_) async => temp.path,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pathChannel,
            null,
          );
          if (temp.existsSync()) temp.deleteSync(recursive: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, _phoneHeight);
        addTearDown(tester.view.reset);
        await loadAppFonts(tester);

        var cell = 'start';
        final problems = <String, List<String>>{};
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.toString();
          final what =
              RegExp(
                r'overflowed by [\d.]+ pixels on the \w+',
              ).firstMatch(text)?.group(0) ??
              text.split('\n').first;
          final where = RegExp(
            r'(lib/[^\s:]+\.dart:\d+)',
          ).firstMatch(text)?.group(1);
          problems
              .putIfAbsent(cell, () => [])
              .add(where == null ? what : '$what ($where)');
        };
        addTearDown(() => FlutterError.onError = original);

        appRouter.go('/home');
        final providers = await tester.runAsync(buildAppProviders);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MultiProvider(
              providers: providers!,
              child: const NiarimApp(),
            ),
          ),
        );
        Future<void> settle([int rounds = 6]) async {
          for (var i = 0; i < rounds; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
          }
          await tester.pump();
        }

        await settle();
        final context = tester.element(find.byType(Scaffold).first);
        final projects = context.read<ProjectService>();
        final settings = context.read<SettingsService>();
        final project = (await tester.runAsync(
          () => projects.createProject(
            name: 'Matrix',
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 320,
            exportHeight: 180,
          ),
        ))!;
        final community = context.read<CommunityService>();
        final workId = community.works.isEmpty
            ? null
            : community.works.first.id;
        final routes = [
          '/',
          '/home',
          '/shared',
          '/trash',
          '/community',
          if (workId != null) '/community/work/$workId',
          '/new-project',
          '/project/${project.id}',
          '/canvas/${project.id}',
          '/timeline/${project.id}',
          '/export/${project.id}',
          '/settings',
          '/settings/gestures',
          '/settings/shortcuts',
          '/settings/performance',
          '/settings/pen',
          '/settings/bucket',
          '/settings/workspace',
          '/settings/transfer',
          '/settings/widget',
          '/settings/widget/artwork',
          '/settings/widget/artwork/${project.id}',
          '/settings/theme',
          '/settings/watermark',
          '/help',
          '/tips',
          '/premium',
          '/rewards',
          '/earn-coins',
          '/membership',
          '/creator-missions',
          '/autofill-presets',
          '/save-tree/${project.id}',
          '/materials/${project.id}',
          '/settings/fonts',
          '/settings/error-log',
          '/settings/license',
          '/settings/privacy-policy',
          '/storage',
        ];

        final results = <Map<String, Object?>>[];
        final shots = Directory('${_out.path}/failed');
        Future<void> shoot(String name) async {
          final box =
              boundary.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (box == null) return;
          final png = await tester
              .runAsync(() async {
                final image = await box.toImage();
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                return data?.buffer.asUint8List();
              })
              .timeout(const Duration(seconds: 20), onTimeout: () => null);
          if (png == null) return;
          shots.createSync(recursive: true);
          File('${shots.path}/$name.png').writeAsBytesSync(png);
        }

        // Only the first few failing cells of a screen are photographed.
        final shotsPerRoute = <String, int>{};
        for (final pc in [false, true]) {
          await tester.runAsync(() => settings.setForcePcMode(pc));
          final height = pc ? _pcHeight : _phoneHeight;
          for (final route in routes) {
            final routeName = route
                .replaceAll(project.id, ':id')
                .replaceAll(workId ?? '\u0000', ':work');
            tester.view.physicalSize = Size(390, height);
            cell = '$language ${pc ? 'PC' : 'SP'} $routeName open';
            appRouter.go(route);
            await settle();
            debugPrint('matrix $language ${pc ? 'PC' : 'SP'} $routeName');
            for (final width in _widths) {
              cell = '$language ${pc ? 'PC' : 'SP'} ${width}px $routeName';
              tester.view.physicalSize = Size(width.toDouble(), height);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 50));
              final thrown = tester.takeException();
              if (thrown != null) {
                problems.putIfAbsent(cell, () => []).add('$thrown');
              }
              // A row or column reports its overflow only the first time, so
              // the overflow is looked up in every cell.
              for (final flex in _overflowing()) {
                problems.putIfAbsent(cell, () => []).add(flex);
              }
              final found = problems[cell] ?? const <String>[];
              results.add({
                'language': language,
                'mode': pc ? 'PC' : 'SP',
                'width': width,
                'height': height,
                'route': routeName,
                'problems': found,
              });
              final shotKey = '${pc ? 'PC' : 'SP'} $routeName';
              if (found.isNotEmpty && (shotsPerRoute[shotKey] ?? 0) < 3) {
                shotsPerRoute[shotKey] = (shotsPerRoute[shotKey] ?? 0) + 1;
                await shoot(
                  '${language}_${pc ? 'pc' : 'sp'}_${width}_'
                  '${routeName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}',
                );
              }
            }
          }
        }
        await tester.runAsync(() => settings.setForcePcMode(null));
        appRouter.go('/');
        await settle(2);

        _out.createSync(recursive: true);
        File(
          '${_out.path}/route_matrix_$language.json',
        ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
        final failed = {
          for (final e in problems.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        };
        expect(
          failed,
          isEmpty,
          reason: [
            for (final e in failed.entries) '${e.key}: ${e.value.join('; ')}',
          ].take(80).join('\n'),
        );
        expect(results, hasLength(2 * routes.length * _widths.length));
      },
      timeout: const Timeout(Duration(minutes: 100)),
      skip: !_enabled,
    );
  }
}
