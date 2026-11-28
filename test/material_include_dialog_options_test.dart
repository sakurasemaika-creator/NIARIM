import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

/// 作品の素材を読み込まずに返す素材の一覧。
class _Materials extends MaterialService {
  _Materials(this.types);

  final List<MaterialType> types;

  @override
  Future<void> ensureLoaded(String projectId) async {}

  @override
  List<MaterialAsset> materialsOf(String projectId) => [
    for (final (i, type) in types.indexed)
      MaterialAsset(
        id: 'Material000$i',
        originalFileName: 'm$i.bin',
        type: type,
        sizeBytes: 1,
        addedAt: DateTime(2026),
      ),
  ];
}

final _work = Project(
  id: 'work',
  name: 'Walk',
  fps: 12,
  durationSeconds: 1,
  backgroundColor: 0xFFFFFFFF,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  totalWorkSeconds: 0,
);

/// 共有ファイルを作る前の確認で、作品にある種類の素材だけを同梱の選択に
/// 出す。素材の無い作品では「素材の同梱」を聞かず、作成の確認だけにする
/// （以前は素材の無い作品でも画像・動画・音声の同梱を選ばせた。Linuxの
/// 実画面で発見、P1-14）。
void main() {
  Future<AppLocalizations> pumpApp(
    WidgetTester tester,
    List<MaterialType> types,
    void Function(BuildContext context) onOpen,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MaterialService>.value(
        value: _Materials(types),
        child: MaterialApp(
          theme: ThemeService().themeData,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () => onOpen(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.byKey(const Key('open'))))!;
  }

  testWidgets('a work without materials is not asked about bundling them', (
    tester,
  ) async {
    NiashareIncludeOptions? built;
    final l10n = await pumpApp(
      tester,
      const [],
      (context) => runNiashareFlow(
        context,
        _work,
        build: (options) async {
          built = options;
          throw const FileSystemException('stop before sharing');
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('niashareIncludeDialog'));
    expect(dialog, findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text(l10n.projectListMaterialIncludeTitle), findsNothing);
    expect(find.text(l10n.projectListMaterialIncludeHint), findsNothing);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(l10n.projectListCreateShareAction),
      ),
      findsOneWidget,
    );
    // 追加フォントの扱いの説明は残す。
    expect(find.text(l10n.projectListShareFontNamesHint), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    await tester.pumpAndSettle();
    expect(built?.materialTypes, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('only the kinds of material the work has can be bundled', (
    tester,
  ) async {
    NiashareIncludeOptions? built;
    final l10n = await pumpApp(
      tester,
      const [MaterialType.audio, MaterialType.audio],
      (context) => runNiashareFlow(
        context,
        _work,
        build: (options) async {
          built = options;
          throw const FileSystemException('stop before sharing');
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.projectListMaterialIncludeTitle), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text(l10n.projectListMaterialAudio), findsOneWidget);
    expect(find.text(l10n.projectListMaterialImage), findsNothing);
    expect(find.text(l10n.projectListMaterialVideo), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonCreate));
    await tester.pumpAndSettle();
    expect(built?.materialTypes, {MaterialType.audio});
    await tester.pump(const Duration(seconds: 5));
  });
}
