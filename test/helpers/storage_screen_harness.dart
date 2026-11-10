import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_use_tooltips.dart';
import 'load_app_fonts.dart';

/// 容量削減の画面を、集計の進み方を1手ずつ決められるサービスで載せるための
/// 道具（実時間を待たずに、欄ごとの状態を作る）。
const storageBreakdownRetryKey = ValueKey<String>('storageBreakdownRetry');
const storageDeviceRetryKey = ValueKey<String>('storageDeviceRetry');

StorageBreakdown storageBreakdownOf({
  int cache = 123,
  int trash = 0,
  Set<StorageCategory> incomplete = const {},
}) => StorageBreakdown({
  StorageCategory.materials: 2048,
  StorageCategory.projectData: 4096,
  StorageCategory.trash: trash,
  StorageCategory.exports: 0,
  StorageCategory.customAssets: 0,
  StorageCategory.cache: cache,
}, incomplete: incomplete);

const storageTestDevice = DeviceSpaceInfo(
  totalBytes: 1000 * 1024 * 1024,
  freeBytes: 400 * 1024 * 1024,
);

/// 呼ばれるたびに、テストが後から答える`Completer`を1つ足す。
class ScriptedStorage extends StorageInfoService {
  final scans = <Completer<StorageBreakdown>>[];

  /// 集計ごとの「走っている集計を待たずに始め直す」の指定。
  final freshScans = <bool>[];
  final deviceQueries = <Completer<DeviceSpaceInfo?>>[];
  StorageBreakdown? rememberedBreakdown;
  DeviceSpaceInfo? rememberedDevice;
  int invalidations = 0;
  int cacheClears = 0;

  @override
  StorageBreakdown? get lastBreakdown => rememberedBreakdown;

  @override
  DeviceSpaceInfo? get lastDeviceSpace => rememberedDevice;

  @override
  void invalidate() {
    invalidations++;
    rememberedBreakdown = null;
    rememberedDevice = null;
  }

  @override
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds, {
    bool fresh = false,
  }) {
    final scan = Completer<StorageBreakdown>();
    scans.add(scan);
    freshScans.add(fresh);
    return scan.future;
  }

  @override
  Future<DeviceSpaceInfo?> deviceSpace() {
    final query = Completer<DeviceSpaceInfo?>();
    deviceQueries.add(query);
    return query.future;
  }

  /// nullでなければ、キャッシュの削除はこれが終わるまで続く。
  Completer<int>? clearing;

  @override
  Future<int> clearCache() async {
    cacheClears++;
    return clearing?.future ?? 123;
  }
}

/// 起動処理と同じProviderを作る（言語は日本語、スマホの配置）。
Future<List<SingleChildWidget>> bootstrapStorageScreen(
  WidgetTester tester,
) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': 'ja',
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return (await tester.runAsync(buildAppProviders))!;
}

/// 本番と同じテーマ・スクロールの振る舞いで、画面だけを載せる。
Future<AppLocalizations> showStorageScreen(
  WidgetTester tester,
  List<SingleChildWidget> providers,
  StorageInfoService service, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MultiProvider(
      key: UniqueKey(),
      providers: providers,
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: context.watch<ThemeService>().themeData,
          scrollBehavior: const AppScrollBehavior(),
          locale: localeFromLanguageCode('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: StorageScreen(service: service),
        ),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.of(tester.element(find.byType(StorageScreen)))!;
}

Finder storageTile(String title) =>
    find.widgetWithText(ListTile, title, skipOffstage: false);

/// キーボードのフォーカスが[target]の中にあるか。
bool focusIsWithin(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || target.evaluate().isEmpty) return false;
  final element = tester.element(target);
  if (focused == element) return true;
  var within = false;
  focused.visitAncestorElements((ancestor) {
    within = ancestor == element;
    return !within;
  });
  return within;
}

/// Tabキーを、フォーカスが[target]の中へ入るまで押す。入らなければfalse。
Future<bool> tabTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20; i++) {
    if (focusIsWithin(tester, target)) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  return focusIsWithin(tester, target);
}
