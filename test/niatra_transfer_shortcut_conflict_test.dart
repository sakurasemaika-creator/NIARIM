import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/transfer_screen.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/niatra_transfer_device.dart';
import 'helpers/pump_real_async.dart';

/// もう1台のショートカットのうち、この端末で同じキーを別の操作に使っている
/// ものは足さない（1つのキーに2つの操作を付けない。この端末のキーはその
/// まま）が、黙って捨てずに読み込みの知らせで名前とキーを出す。同じキーで
/// 同じ操作をするショートカットがこの端末にあれば、足したのと同じなので
/// 知らせない。

/// 選ぶと決まった.niatraを返すファイル選択。
class _PickNiatra extends FilePicker {
  _PickNiatra(this.bytes);

  final Uint8List bytes;

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
  }) async => FilePickerResult([
    PlatformFile(name: 'moved.niatra', size: bytes.length, bytes: bytes),
  ]);
}

/// もう1台：Ctrl+EでGペン、Ctrl+Rで再生。
final _gPen = ShortcutBinding(
  id: 'sc_gpen',
  label: 'G pen',
  keyId: LogicalKeyboardKey.keyE.keyId,
  control: true,
  toolKey: 'pen',
);
final _play = ShortcutBinding(
  id: 'sc_play_a',
  label: 'Play',
  keyId: LogicalKeyboardKey.keyR.keyId,
  control: true,
  command: ShortcutCommand.playPause,
);

/// この端末：Ctrl+Eで消しゴム、Ctrl+Rで再生（IDは別）。
final _eraser = ShortcutBinding(
  id: 'sc_eraser',
  label: 'Eraser',
  keyId: LogicalKeyboardKey.keyE.keyId,
  control: true,
  toolKey: 'eraser',
);
final _playHere = ShortcutBinding(
  id: 'sc_play_b',
  label: 'Play',
  keyId: LogicalKeyboardKey.keyR.keyId,
  control: true,
  command: ShortcutCommand.playPause,
);

/// もう1台の.niatra（端末保存データにショートカット）。
Future<Uint8List> _otherDeviceFile() async {
  SharedPreferences.setMockInitialValues({'language': 'ja'});
  final other = await TransferDevice.start();
  other.shortcut.addBinding(_gPen);
  other.shortcut.addBinding(_play);
  await settleTransfer();
  return other.export();
}

Map<String, Object> _thisDevice() => {
  'language': 'ja',
  'first_launch': false,
  firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  'shortcut_bindings': [
    jsonEncode(_eraser.toJson()),
    jsonEncode(_playHere.toJson()),
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  FilePicker? previousPicker;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_shortcut_conflict_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => temp.path);
    try {
      previousPicker = FilePicker.platform;
    } catch (_) {
      previousPicker = null;
    }
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    if (previousPicker != null) FilePicker.platform = previousPicker!;
    await settleTransfer();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a shortcut whose keys this device uses for another action is not '
      'added and is reported; one that does the same here is not', () async {
    final bytes = await _otherDeviceFile();
    SharedPreferences.setMockInitialValues(_thisDevice());
    final here = await TransferDevice.start();
    final report = TransferImportReport();
    await here.import(
      bytes,
      Directory('${temp.path}/i1')..createSync(),
      report: report,
    );

    final byKey = {for (final b in here.shortcut.bindings) b.comboLabel: b.id};
    expect(byKey['Ctrl+E'], 'sc_eraser', reason: 'この端末のキーはそのまま');
    expect(byKey['Ctrl+R'], 'sc_play_b');
    expect(
      here.shortcut.bindings.where((b) => b.id == 'sc_gpen'),
      isEmpty,
      reason: '1つのキーに2つの操作を付けない',
    );
    expect(
      [for (final b in report.notAddedShortcuts) '${b.label}|${b.comboLabel}'],
      ['G pen|Ctrl+E'],
      reason: '足さなかったショートカットを知らせる（同じ操作のものは知らせない）',
    );

    final again = TransferImportReport();
    await here.import(
      bytes,
      Directory('${temp.path}/i2')..createSync(),
      report: again,
    );
    expect(
      [for (final b in again.notAddedShortcuts) b.id],
      ['sc_gpen'],
      reason: '読み直しても足さず、同じように知らせる',
    );
  });

  test('a shortcut that runs an automation this device has in another '
      'version runs the copy that holds the other device\'s version', () async {
    CustomAutomation automation(String command) => CustomAutomation(
      id: 'auto_fill',
      name: 'Fill',
      steps: [
        CustomAutomationStep(
          id: '${command}_step',
          surface: CustomAutomationSurface.canvas,
          command: command,
          label: command,
        ),
      ],
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 3),
    );
    final runFill = ShortcutBinding(
      id: 'sc_fill',
      label: 'Fill',
      keyId: LogicalKeyboardKey.keyK.keyId,
      control: true,
      automationId: 'auto_fill',
    );
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'custom_automations_v1': [jsonEncode(automation('fill').toJson())],
      'shortcut_bindings': [jsonEncode(runFill.toJson())],
    });
    final other = await TransferDevice.start();
    final bytes = await other.export();

    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'custom_automations_v1': [jsonEncode(automation('blur').toJson())],
    });
    final here = await TransferDevice.start();
    await here.import(bytes, Directory('${temp.path}/i3')..createSync());
    final copy = here.automation.items
        .where((a) => a.name == 'Fill (コピー)')
        .firstOrNull;
    expect(copy?.steps.single.command, 'fill', reason: 'もう1台の版を複製として足す');
    expect(
      here.shortcut.bindings
          .where((b) => b.id == 'sc_fill')
          .map((b) => b.automationId),
      [copy?.id],
      reason: 'ショートカットは、もう1台の版を持つ複製を動かす',
    );
  });

  testWidgets('the transfer screen names the shortcut it did not add and its '
      'keys', (tester) async {
    final bytes = (await tester.runAsync(_otherDeviceFile))!;
    SharedPreferences.setMockInitialValues(_thisDevice());
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TransferScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.element(find.byType(TransferScreen));
    final l10n = AppLocalizations.of(screen)!;
    FilePicker.platform = _PickNiatra(bytes);

    await tester.tap(find.text(l10n.transferImport));
    Finder bar() =>
        find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
    for (var i = 0; i < 100 && bar().evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    final text = [
      for (final e in bar().evaluate()) (e.widget as Text).data ?? '',
    ].join('\n');
    expect(text, contains('G pen'), reason: '足さなかったショートカットの名前');
    expect(text, contains('Ctrl+E'), reason: 'そのキー');
    expect(
      screen
          .read<ShortcutService>()
          .bindings
          .where((b) => b.comboLabel == 'Ctrl+E')
          .map((b) => b.id),
      ['sc_eraser'],
    );
    ScaffoldMessenger.of(screen).clearSnackBars();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
