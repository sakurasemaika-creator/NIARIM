import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **文字サイズを大きくした状態で**ダイアログ・シート・メニューを開き、
/// レイアウトが破綻しないことを検証する。
///
/// `test/text_scale_layout_test.dart`は1.3倍・2.0倍で全ルートを巡回するが、
/// **ダイアログを1つも開いていない**。一方`showDialog`／
/// `showModalBottomSheet`はlib配下に200箇所以上あり、1.0倍でも
/// 「ジェスチャー選択シートが77pxオーバーフロー」
/// 「クイックツールの追加が654pxオーバーフロー」という実バグが見つかっている。
/// 文字が1.3倍になれば同じ場所がさらに厳しくなる。
///
/// CLAUDE.mdの通り、textScalerによる破綻は**実機で画面が真っ白になる**
/// ところまで行くことがあるため、ここを空けたままにしない。
///
/// 1.0倍の網羅は`test/dialog_screenshot_audit_test.dart`が担当。こちらは
/// 「拡大しても壊れないか」だけを見るので、PNGは残さず速度を優先する。
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('文字サイズ1.3倍でもダイアログ・シートが破綻しない', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_use_tooltips_seen': <String>[
        'autofill_mark',
        'bucket_tool',
        'pen_subtool_stamp',
        'pen_subtool_tone',
        'pen_tool',
        'quick_tool',
        'ruler_tool',
        'text_tool',
        'timeline_preview_fullscreen',
      ],
    });
    FilePicker.platform = _FakeFilePicker();
    final tempDir = Directory.systemTemp.createTempSync('niarim_dlg_scale_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // 一般的なスマホ相当（360x760dp）。狭い端末ほど文字拡大の影響が出る。
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // オーバーフローは例外として飛ぶ。どこで何が起きたかを残すため、
    // 握りつぶさずに集める。
    final problems = <String>{};
    var currentContext = '';
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      final what =
          RegExp(
            r'(overflowed by [\d.]+ pixels on the \w+)',
          ).firstMatch(text)?.group(1) ??
          text.split('\n').first;
      // オーバーフローは毎フレーム飛ぶので、同じ内容は1件に畳む。
      // 畳まないと数万件溜まってテストが極端に遅くなる。
      final entry = '$currentContext: $what';
      if (problems.length < 200) problems.add(entry);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    Future<void> settle({int rounds = 4}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();

    final launch = find.byIcon(Icons.brush_outlined);
    if (launch.evaluate().isNotEmpty) {
      await tester.tap(launch.first, warnIfMissed: false);
      await settle();
      final firstLaunch = find.text('はじめる');
      if (firstLaunch.evaluate().isNotEmpty) {
        await tester.tap(firstLaunch.first, warnIfMissed: false);
        await settle();
      }
    }

    final service = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => service.createProject(
        name: 'text-scale-dialog',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;

    int barrierCount() => find.byType(ModalBarrier).evaluate().length;

    const tapCandidateTypes = <Type>{
      ElevatedButton,
      OutlinedButton,
      TextButton,
      IconButton,
      FloatingActionButton,
      ListTile,
      CheckboxListTile,
      SwitchListTile,
      RadioListTile,
      ActionChip,
      FilterChip,
      ChoiceChip,
      InputChip,
      PopupMenuButton,
    };
    const skipLabels = <String>{'共有', 'シェア', 'ライセンス', 'を開く'};

    String? labelOf(Element element) {
      String? found;
      void visit(Element el) {
        if (found != null) return;
        final w = el.widget;
        if (w is Text && (w.data?.trim().isNotEmpty ?? false)) {
          found = w.data!.trim();
          return;
        }
        if (w is Icon && w.icon != null) found ??= 'icon${w.icon!.codePoint}';
        el.visitChildren(visit);
      }

      element.visitChildren(visit);
      return found;
    }

    Future<void> sweep(String routeName, String route) async {
      final tried = <String>{};
      final base = barrierCount();
      for (var step = 0; step < 60; step++) {
        Element? target;
        var label = '';
        var index = 0;
        for (final element in tester.allElements) {
          final widget = element.widget;
          if (!tapCandidateTypes.contains(widget.runtimeType)) continue;
          final modalRoute = ModalRoute.of(element);
          if (modalRoute == null || !modalRoute.isCurrent) continue;
          var hasAncestor = false;
          element.visitAncestorElements((a) {
            if (tapCandidateTypes.contains(a.widget.runtimeType)) {
              hasAncestor = true;
            }
            return true;
          });
          if (hasAncestor) continue;
          final text = labelOf(element) ?? '';
          if (skipLabels.any((s) => text.contains(s))) continue;
          final id = '${widget.runtimeType}:${text.isEmpty ? '#$index' : text}';
          index++;
          if (!tried.contains(id)) {
            target = element;
            label = text.isEmpty ? widget.runtimeType.toString() : text;
          }
        }
        if (target == null) break;
        tried.add(
          '${target.widget.runtimeType}:${label.isEmpty ? '#0' : label}',
        );

        currentContext = '$routeName / "$label"';
        try {
          await tester.tap(
            find.byElementPredicate((el) => el == target),
            warnIfMissed: false,
          );
        } catch (_) {
          continue;
        }
        await settle(rounds: 3);
        tester.takeException();

        if (barrierCount() > base) {
          var guard = 0;
          while (barrierCount() > base && guard < 6) {
            try {
              final nav = Navigator.of(
                tester.element(find.byType(Scaffold).first),
              );
              if (!nav.canPop()) break;
              nav.pop();
            } catch (_) {
              break;
            }
            await settle(rounds: 3);
            tester.takeException();
            guard++;
          }
          if (barrierCount() > base) {
            appRouter.go(route);
            await settle(rounds: 3);
            tester.takeException();
            if (barrierCount() > base) break;
          }
        }
      }
      currentContext = '';
    }

    for (final entry in <({String name, String route})>[
      (name: 'home', route: '/home'),
      (name: 'new_project', route: '/new-project'),
      (name: 'project_detail', route: '/project/${project.id}'),
      (name: 'export', route: '/export/${project.id}'),
      (name: 'save_tree', route: '/save-tree/${project.id}'),
      (name: 'autofill_presets', route: '/autofill-presets'),
      (name: 'community', route: '/community'),
      (name: 'premium', route: '/premium'),
      (name: 'settings', route: '/settings'),
      (name: 'settings_bucket', route: '/settings/bucket'),
      (name: 'settings_fonts', route: '/settings/fonts'),
      (name: 'settings_gestures', route: '/settings/gestures'),
      (name: 'settings_pen', route: '/settings/pen'),
      (name: 'settings_performance', route: '/settings/performance'),
      (name: 'settings_shortcuts', route: '/settings/shortcuts'),
      (name: 'settings_theme', route: '/settings/theme'),
      (name: 'settings_transfer', route: '/settings/transfer'),
      (name: 'settings_watermark', route: '/settings/watermark'),
      (name: 'settings_widget', route: '/settings/widget'),
      (name: 'settings_workspace', route: '/settings/workspace'),
      (name: 'storage', route: '/storage'),
      (name: 'trash', route: '/trash'),
    ]) {
      appRouter.go(entry.route);
      await settle();
      tester.takeException();
      await sweep(entry.name, entry.route);
    }

    // expect()の前にFlutterError.onErrorを必ず元へ戻す。戻さないまま
    // expectで落ちると、Flutterのテストバインディングが
    // 「A test overrode FlutterError.onError but ...」という別の
    // アサーションを投げ、本当の原因（どこが何pxはみ出したか）が
    // 見えなくなる。
    FlutterError.onError = previousOnError;
    final unique = problems.toList()..sort();
    expect(
      unique,
      isEmpty,
      reason:
          '文字サイズ1.3倍でダイアログ・シートのレイアウトが破綻している:\n'
          '${unique.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
