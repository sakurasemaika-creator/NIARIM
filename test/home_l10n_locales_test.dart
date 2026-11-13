// ホームの手書きの表・日本語と英語だけの文をARBへ移したことの見張り。
//
// 以前は languageCode で分けた表で、スペイン語・フランス語は英語、繁体字は
// 簡体字（'zh'の行）、ダイアログ・メニューの多くは日本語以外すべて英語だった。
// 本物のアプリを起動処理から組み立ててホームを開き、各言語の文を確かめる。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 言語ごとに、画面に出るはずの文。
const _expected = <String, Map<String, String>>{
  'es': {
    'received': 'Recibidos',
    'created': 'Creados por mí',
    'createdEmpty': 'Todavía no has creado archivos compartidos',
    'createdProject': 'Proyecto creado',
    'receivedShare': 'Archivo compartido recibido',
    'createdShare': 'Archivo compartido creado por ti',
    'exportedWork': 'Obra exportada',
    'cut2': '2 elementos cortados',
    'copied1': '1 elemento copiado',
    'clear': 'Borrar',
    'open': 'Abrir',
    'thumbnail': 'Cambiar miniatura',
  },
  'fr': {
    'received': 'Reçus',
    'created': 'Créés par moi',
    'createdEmpty': 'Vous n’avez encore créé aucun fichier partagé',
    'createdProject': 'Projet créé',
    'receivedShare': 'Fichier partagé reçu',
    'createdShare': 'Fichier partagé créé par vous',
    'exportedWork': 'Œuvre exportée',
    'cut2': '2 éléments coupés',
    'copied1': '1 élément copié',
    'clear': 'Effacer',
    'open': 'Ouvrir',
    'thumbnail': 'Changer la miniature',
  },
  'ko': {
    'received': '받은 파일',
    'created': '내가 만든 파일',
    'createdEmpty': '생성한 공유 파일이 없습니다',
    'createdProject': '내 프로젝트',
    'receivedShare': '받은 공유 파일',
    'createdShare': '내가 만든 공유 파일',
    'exportedWork': '내보낸 작품',
    'cut2': '2개 항목 잘라냄',
    'copied1': '1개 항목 복사함',
    'clear': '지우기',
    'open': '열기',
    'thumbnail': '썸네일 변경',
  },
  'zh': {
    'received': '收到的文件',
    'created': '我创建的文件',
    'createdEmpty': '尚未创建共享文件',
    'createdProject': '创建的项目',
    'receivedShare': '收到的共享文件',
    'createdShare': '我创建的共享文件',
    'exportedWork': '导出的作品',
    'cut2': '已剪切2项',
    'copied1': '已复制1项',
    'clear': '清除',
    'open': '打开',
    'thumbnail': '更换缩略图',
  },
  'zh_Hant': {
    'received': '收到的檔案',
    'created': '我建立的檔案',
    'createdEmpty': '尚未建立分享檔案',
    'createdProject': '建立的專案',
    'receivedShare': '收到的共享檔案',
    'createdShare': '我建立的共享檔案',
    'exportedWork': '匯出的作品',
    'cut2': '已剪下2項',
    'copied1': '已複製1項',
    'clear': '清除',
    'open': '開啟',
    'thumbnail': '更換縮圖',
  },
};

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<void> _openHome(WidgetTester tester, String language) async {
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': language,
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  final dir = Directory.systemTemp.createTempSync('home-l10n-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1000);
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 後始末の途中で保存が走っていても、テストの結果は変えない。
    }
  });
  ExportStorage.invalidate();
  Directory('${dir.path}/exports').createSync();
  await tester.runAsync(
    () => ExportEngine.listExportedFiles(forceRefresh: true),
  );
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await _frames(tester);
  await _settleIo(tester);
}

Future<void> _showTab(WidgetTester tester, int index) async {
  tester
      .widget<TabBarView>(find.byType(TabBarView))
      .controller!
      .animateTo(index);
  await _frames(tester, 8);
  await _settleIo(tester, 2);
}

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

Widget _localized(String language, Widget child) => MaterialApp(
  locale: localeFromLanguageCode(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final MapEntry(key: language, value: expected) in _expected.entries) {
    testWidgets('$language: 共有の切り替え・空の表示・ゴミ箱の種類がその言語で出る', (tester) async {
      await _openHome(tester, language);

      await _showTab(tester, 2);
      expect(
        _text(tester, find.byKey(const Key('sharedReceivedFilter'))),
        expected['received'],
      );
      expect(
        _text(tester, find.byKey(const Key('sharedOutgoingFilter'))),
        expected['created'],
      );
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await _frames(tester);
      await _settleIo(tester, 2);
      expect(find.text(expected['createdEmpty']!), findsOneWidget);

      await _showTab(tester, 3);
      for (final (kind, label) in [
        ('createdProject', expected['createdProject']!),
        ('receivedShare', expected['receivedShare']!),
        ('createdShare', expected['createdShare']!),
        ('exportedWork', expected['exportedWork']!),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('trashKind_$kind')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$language trashKind_$kind',
        );
      }
    });

    testWidgets('$language: コピー・切り取りの帯の件数とボタン', (tester) async {
      Future<void> show({required int count, required bool cut}) =>
          tester.pumpWidget(
            _localized(
              language,
              HomeClipboardToolbar(
                itemCount: count,
                isCut: cut,
                onPaste: () {},
                onClear: () {},
              ),
            ),
          );
      await show(count: 2, cut: true);
      await tester.pump();
      expect(find.text(expected['cut2']!), findsOneWidget);
      expect(find.text(expected['clear']!), findsOneWidget);
      await show(count: 1, cut: false);
      await tester.pump();
      expect(find.text(expected['copied1']!), findsOneWidget);
    });

    testWidgets('$language: 書き出した作品のメニュー', (tester) async {
      await tester.pumpWidget(
        _localized(
          language,
          ExportedWorkCard(
            name: 'clip.mp4',
            metadata: '',
            icon: Icons.movie_outlined,
            moveLabel: 'move',
            shareLabel: 'share',
            deleteLabel: 'delete',
            onOpen: () {},
            onMove: () {},
            onShare: () {},
            onDelete: () {},
            onChangeThumbnail: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
      await tester.pumpAndSettle();
      expect(find.text(expected['open']!), findsOneWidget);
      expect(find.text(expected['thumbnail']!), findsOneWidget);
    });
  }
}
