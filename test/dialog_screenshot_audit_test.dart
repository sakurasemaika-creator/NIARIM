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
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/screens/canvas/widgets/panel_close_bar.dart';
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ中のダイアログ・ボトムシート・ポップアップメニューを、
/// **実際に開いて1枚ずつPNGへ焼く**監査。
///
/// ルート単位のスクリーンショット監査（`all_routes_screenshot_audit_test`）は
/// 1ルートにつき1状態しか撮らないため、`showDialog`／
/// `showModalBottomSheet`／`showMenu`で開く画面（lib配下に200箇所以上ある）は
/// ほぼ撮れていなかった。テストが緑でも見た目の不具合は残りうる
/// （実際に7言語のウィジェット意匠を焼いて目視したときに1件見つかっている）
/// ため、開いた状態を機械的に全部焼き出して目視できるようにする。
///
/// このテスト自身は「開いても例外が出ないこと」「PNGが撮れること」だけを
/// 検証する。**見た目の良し悪しは人間（またはAI）が
/// `build/dialog-screenshots/`の画像を見て判断する**という分担にしてある。
/// 一覧は`_index.txt`に「ルート / 開いた操作のラベル / ファイル名」で残る。
///
/// ダイアログの中身はタップしない（確認ダイアログの「削除」を押して
/// データを壊さないため）。開いたら撮って必ずpopで閉じる。
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

  testWidgets('全ルートでダイアログ・シート・メニューを開いてPNGへ焼く', (tester) async {
    // 初回吹き出しは画面全体に透明バリアを敷き、直後の操作を吸ってしまう。
    // 全キーを表示済みにしておく（キーは
    // `grep -rho "tooltipKey: '[^']*'" lib/` で洗い出せる）。
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
    final tempDir = Directory.systemTemp.createTempSync('niarim_dialog_audit_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> loadFonts() async {
      await tester.runAsync(() async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest.listAssets();
        Future<void> loadFamily(String family, String needle) async {
          final matches = assets.where((a) => a.contains(needle)).toList();
          if (matches.isEmpty) return;
          final loader = FontLoader(family)
            ..addFont(rootBundle.load(matches.first));
          await loader.load();
        }

        Future<void> loadSdkMaterialIcons() async {
          final flutterRoot = Platform.environment['FLUTTER_ROOT'];
          if (flutterRoot == null) return;
          final file = File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/'
            'MaterialIcons-Regular.otf',
          );
          if (!file.existsSync()) return;
          final data = ByteData.sublistView(
            Uint8List.fromList(await file.readAsBytes()),
          );
          final loader = FontLoader('MaterialIcons')
            ..addFont(Future<ByteData>.value(data));
          await loader.load();
        }

        await Future.wait([
          loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
          loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
          loadFamily('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
          loadFamily('FontAwesomeSolid', 'fa-solid-900.ttf'),
          loadFamily('FontAwesomeRegular', 'fa-regular-400.ttf'),
          loadFamily('FontAwesomeBrands', 'fa-brands-400.ttf'),
          loadSdkMaterialIcons(),
        ]);
      });
    }

    Future<void> settle({int rounds = 6}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
    }

    await loadFonts();
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();

    final out = Directory('build/dialog-screenshots')
      ..createSync(recursive: true);
    // 前回の実行結果が混ざらないよう毎回作り直す。
    for (final f in out.listSync()) {
      f.deleteSync(recursive: true);
    }
    // アプリ側の問題（例外・PNGが撮れない）はfailures、監査側が到達
    // できなかっただけのものはgapsへ分ける。後者でテストを落とすと
    // 「アプリが壊れている」と誤読されるため。
    final failures = <String>[];
    final gaps = <String>[];
    final index = <String>[];

    Future<bool> capture(String name) async {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return false;
      try {
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data?.buffer.asUint8List();
        });
        if (bytes == null || bytes.isEmpty) return false;
        await tester.runAsync(
          () => File('${out.path}/$name.png').writeAsBytes(bytes),
        );
        return true;
      } catch (e) {
        failures.add('$name: capture failed: $e');
        return false;
      }
    }

    // モーダル（ダイアログ・ボトムシート・ポップアップメニュー）は
    // いずれもModalBarrierを1枚差し込む。Dialog/BottomSheetの型で
    // 判定するとshowMenuを取りこぼすため、バリアの枚数で見る。
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

    // 押すとアプリの外へ出る・共有シートが開く等、テスト環境で扱えない
    // ものだけを避ける。確認ダイアログを開く「削除」等はむしろ撮りたい
    // ので除外しない（中身はタップしないので安全）。
    const skipLabels = <String>{'共有', 'シェア', 'ライセンス', 'を開く'};

    String? textOf(Element e) {
      String? found;
      void visit(Element el) {
        if (found != null) return;
        final w = el.widget;
        if (w is Text && (w.data?.trim().isNotEmpty ?? false)) {
          found = w.data!.trim();
          return;
        }
        el.visitChildren(visit);
      }

      e.visitChildren(visit);
      return found;
    }

    String? iconOf(Element e) {
      String? found;
      void visit(Element el) {
        if (found != null) return;
        final w = el.widget;
        if (w is Icon && w.icon != null) {
          found = 'icon${w.icon!.codePoint}';
          return;
        }
        el.visitChildren(visit);
      }

      e.visitChildren(visit);
      return found;
    }

    String sanitize(String s) {
      final cleaned = s.replaceAll(RegExp(r'[^0-9A-Za-zぁ-んァ-ヶ一-龠ー]'), '_');
      return cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
    }

    /// [routeName]の画面上の操作要素を順に押し、モーダルが開いたら焼く。
    final diag = <String>[];

    /// [within]を渡すと、その型のウィジェットの配下にある操作要素だけを
    /// 対象にする。キャンバスのパネルのように「開いた状態を作ってから
    /// その中だけを掃く」ために使う（画面全体を対象にすると、木構造で
    /// 後ろにいるツールバーのボタンを押して画面ごと離脱してしまう）。
    Future<void> sweep(
      String routeName,
      String reentryRoute, {
      int maxSteps = 150,
      Type? within,
      Set<String>? sharedTried,
    }) async {
      final tried = sharedTried ?? <String>{};
      final baseBarriers = barrierCount();
      var shot = 0;
      var taps = 0;
      var stop = 'maxSteps到達';

      for (var step = 0; step < maxSteps; step++) {
        Element? target;
        var label = '';
        var targetId = '';
        var i = 0;
        // **木構造で最後の未試行**を選ぶ。キャンバスのレイヤーパネル等は
        // オーバーレイとして後から描かれる＝木の後方にいるため、先頭から
        // 選ぶとツールバーのボタンばかり押してパネルの中身まで到達できず、
        // layer_panel（14箇所）・filter_panel（8箇所）等のダイアログが
        // 1枚も撮れなかった。
        for (final e in tester.allElements) {
          final w = e.widget;
          if (!tapCandidateTypes.contains(w.runtimeType)) continue;
          final route = ModalRoute.of(e);
          if (route == null || !route.isCurrent) continue;
          var hasAncestor = false;
          var insideScope = within == null;
          e.visitAncestorElements((a) {
            if (tapCandidateTypes.contains(a.widget.runtimeType)) {
              hasAncestor = true;
            }
            if (within != null && a.widget.runtimeType == within) {
              insideScope = true;
            }
            return true;
          });
          if (hasAncestor || !insideScope) continue;
          final l = textOf(e) ?? iconOf(e) ?? '';
          if (skipLabels.any((s) => l.contains(s))) continue;
          final id = '${w.runtimeType}:${l.isEmpty ? '#$i' : l}';
          i++;
          if (!tried.contains(id)) {
            target = e;
            targetId = id;
            label = l.isEmpty ? w.runtimeType.toString() : l;
          }
        }
        if (target != null) tried.add(targetId);
        if (target == null) {
          stop = '候補切れ(${tried.length}件試行)';
          break;
        }

        final finder = find.byElementPredicate((el) => el == target);
        try {
          await tester.tap(finder, warnIfMissed: false);
          taps++;
        } catch (_) {
          continue;
        }
        await settle(rounds: 3);
        final ex = tester.takeException();
        if (ex != null) {
          failures.add('$routeName / "$label" のタップで例外: $ex');
        }

        if (barrierCount() > baseBarriers) {
          shot++;
          final name =
              '${routeName}__${shot.toString().padLeft(2, '0')}_'
              '${sanitize(label)}';
          if (await capture(name)) {
            index.add('$routeName\t$label\t$name.png');
          } else {
            failures.add('$name: PNGを撮れなかった');
          }
          // 開いたものは必ず閉じる。中身は一切タップしない。
          var guard = 0;
          while (barrierCount() > baseBarriers && guard < 6) {
            try {
              final nav = Navigator.of(
                tester.element(find.byType(Scaffold).first),
              );
              if (!nav.canPop()) break;
              nav.pop();
            } catch (_) {
              break;
            }
            await settle(rounds: 4);
            tester.takeException();
            guard++;
          }
          if (barrierCount() > baseBarriers) {
            // popで閉じ切れないモーダルに当たったら、そのルートへ入り直して
            // 続行する（1件で打ち切ると以降のダイアログが全部撮れなくなる）。
            appRouter.go(reentryRoute);
            await settle(rounds: 4);
            tester.takeException();
            if (barrierCount() > baseBarriers) {
              stop = '"$label"を閉じられず打ち切り';
              break;
            }
          }
        }
      }
      diag.add('$routeName: タップ$taps件 / モーダル$shot件 / 停止理由=$stop');
    }

    // 起動画面からホームへ入る。
    final launch = find.byIcon(Icons.brush_outlined);
    if (launch.evaluate().isNotEmpty) {
      await tester.tap(launch.first);
      await settle();
      final firstLaunch = find.text('はじめる');
      if (firstLaunch.evaluate().isNotEmpty) {
        await tester.tap(firstLaunch.first);
        await settle();
      }
    } else {
      appRouter.go('/home');
      await settle();
    }

    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'dialog-audit',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;

    final routes = <({String name, String route})>[
      (name: 'home', route: '/home'),
      (name: 'new_project', route: '/new-project'),
      (name: 'project_detail', route: '/project/${project.id}'),
      (name: 'canvas', route: '/canvas/${project.id}'),
      (name: 'timeline', route: '/timeline/${project.id}'),
      (name: 'materials', route: '/materials/${project.id}'),
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
      (name: 'tips', route: '/tips'),
    ];

    for (final entry in routes) {
      try {
        appRouter.go(entry.route);
        await settle();
        tester.takeException();
        await sweep(entry.name, entry.route);
      } catch (e) {
        failures.add('${entry.name}: 巡回に失敗: $e');
      }
    }

    // ── キャンバスのパネル内部を個別に掃く ───────────────────────────
    // ツールバーのボタンは「押すとパネルが開く」ものと「押すと画面ごと
    // 離脱する」もの（タイムラインへ移動等）が混在していて、汎用スイープ
    // だと後者を踏んで1タップで終わってしまう（診断で canvas: タップ1件と
    // 出ていた）。パネルを1つずつ開き、**そのパネルの配下だけ**を対象に
    // 掃くことで、layer_panel（14箇所）・filter_panel（8箇所）等の
    // ダイアログへ到達させる。
    Future<void> closeOpenPanel() async {
      final bar = find.byType(PanelCenterCloseBar);
      if (bar.evaluate().isEmpty) return;
      try {
        await tester.tap(bar.first, warnIfMissed: false);
      } catch (_) {
        return;
      }
      await settle(rounds: 3);
      tester.takeException();
    }

    Future<void> sweepPanel(IconData icon, Type panelType, String name) async {
      appRouter.go('/canvas/${project.id}');
      await settle();
      tester.takeException();
      await closeOpenPanel();

      final control = find.byIcon(icon);
      if (control.evaluate().isEmpty) {
        gaps.add('canvas/$name: ツールバーにアイコン${icon.codePoint}が無い');
        return;
      }
      // ツールバーは横スクロールする。表示範囲の外だとタップがヒット
      // テストに当たらず「押したのに開かない」形で失敗する。
      try {
        await tester.ensureVisible(control.first);
        await tester.pump(const Duration(milliseconds: 120));
      } on StateError {
        // Scrollableの外（オーバーレイ上のボタン等）はそのままでよい。
      }
      try {
        await tester.tap(control.first, warnIfMissed: false);
      } catch (_) {
        return;
      }
      await settle();
      tester.takeException();
      if (find.byType(panelType).evaluate().isEmpty) {
        gaps.add('canvas/$name: パネルが開かなかった');
        return;
      }
      await sweep('canvas_$name', '/canvas/${project.id}', within: panelType);
    }

    // オニオンスキンと演出フィルターのパネルは**ツールバーではなく
    // 設定シート（歯車）の中のListTile**から開く。ツールバーのアイコンを
    // 探しても見つからない（Icons.loopはクイックツールで、これを
    // オニオンスキンだと思って叩くと別のパネルが開く）。
    Future<void> sweepPanelViaSettingsSheet(
      IconData tileIcon,
      Type panelType,
      String name,
    ) async {
      appRouter.go('/canvas/${project.id}');
      await settle();
      tester.takeException();
      await closeOpenPanel();

      final gear = find.byIcon(Icons.settings);
      if (gear.evaluate().isEmpty) {
        gaps.add('canvas/$name: 設定シートの歯車が見つからない');
        return;
      }
      try {
        await tester.ensureVisible(gear.first);
        await tester.pump(const Duration(milliseconds: 120));
      } on StateError {
        // Scrollableの外ならそのままでよい。
      }
      await tester.tap(gear.first, warnIfMissed: false);
      await settle();
      tester.takeException();

      final tile = find.byIcon(tileIcon);
      if (tile.evaluate().isEmpty) {
        gaps.add('canvas/$name: 設定シートに該当項目が無い');
        return;
      }
      // 設定シートは縦に長く、下の項目は画面外にある。
      try {
        await tester.ensureVisible(tile.last);
        await tester.pump(const Duration(milliseconds: 120));
      } on StateError {
        // 同上。
      }
      await tester.tap(tile.last, warnIfMissed: false);
      await settle();
      tester.takeException();
      if (find.byType(panelType).evaluate().isEmpty) {
        gaps.add('canvas/$name: パネルが開かなかった');
        return;
      }
      await sweep('canvas_$name', '/canvas/${project.id}', within: panelType);
    }

    for (final entry in <({IconData icon, Type type, String name})>[
      (icon: Icons.layers, type: LayerPanel, name: 'layer'),
      (icon: Icons.tune, type: BrushPanel, name: 'brush'),
      (icon: Icons.loop, type: QuickToolPanel, name: 'quicktool'),
    ]) {
      try {
        await sweepPanel(entry.icon, entry.type, entry.name);
      } catch (e) {
        failures.add('canvas/${entry.name}: 巡回に失敗: $e');
      }
    }
    for (final entry in <({IconData icon, Type type, String name})>[
      (icon: Icons.layers_outlined, type: OnionSkinPanel, name: 'onion'),
      (icon: Icons.blur_on, type: FilterPanel, name: 'filter'),
    ]) {
      try {
        await sweepPanelViaSettingsSheet(entry.icon, entry.type, entry.name);
      } catch (e) {
        failures.add('canvas/${entry.name}: 巡回に失敗: $e');
      }
    }

    await tester.runAsync(
      () => File('${out.path}/_index.txt').writeAsString(
        '${index.length}件のモーダルを撮影\n\n'
        '${diag.join('\n')}\n\n'
        '${index.join('\n')}\n',
      ),
    );
    await tester.runAsync(
      () => File('${out.path}/_gaps.txt').writeAsString(
        gaps.isEmpty
            ? '到達できなかった箇所は無し\n'
            : '監査が到達できなかった箇所（アプリの不具合ではない）\n\n'
                  '${gaps.join('\n')}\n',
      ),
    );
    await tester.runAsync(
      () => File(
        '${out.path}/_failures.txt',
      ).writeAsString(failures.isEmpty ? 'PASS\n' : failures.join('\n')),
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(
      index.length,
      greaterThan(30),
      reason: '撮れたモーダルが少なすぎる（${index.length}件）',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
