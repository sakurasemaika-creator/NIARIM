// プライバシーポリシーの第2条に足した「生成AI・機械学習の学習データとして
// 利用しない」条項が、7言語とも同じ文で第2条の本文の後に出ることを確かめる。
//
// この条項は以前、画面のDartファイルに7言語の表を手で持っていて、同梱
// フォントの検査（ARBだけを読む）に入らず、ハングルの「델」「학」・簡体字の
// 「训」「练」が端末のフォントで出ていた。ARBへ移しても文が変わらないこと
// を見張る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/privacy_policy_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clauses = <String, String>{
  'ja': '開発者は、ユーザーが作成または投稿したコンテンツ、プロジェクトデータその他の制作データを、生成AIモデルその他の機械学習モデルの学習データとして利用しません。',
  'en': 'The developer does not use content created or published by users, project data, or other creation data as training data for generative AI models or other machine-learning models.',
  'es': 'El desarrollador no utiliza el contenido creado o publicado por los usuarios, los datos de proyectos ni otros datos de creación como datos de entrenamiento para modelos de IA generativa u otros modelos de aprendizaje automático.',
  'fr': "Le développeur n’utilise pas les contenus créés ou publiés par les utilisateurs, les données de projet ni les autres données de création comme données d’entraînement pour des modèles d’IA générative ou d’autres modèles d’apprentissage automatique.",
  'ko': '개발자는 사용자가 제작하거나 게시한 콘텐츠, 프로젝트 데이터 및 기타 제작 데이터를 생성형 AI 모델 또는 기타 머신러닝 모델의 학습 데이터로 사용하지 않습니다.',
  'zh': '开发者不会将用户创作或发布的内容、项目数据及其他创作数据，用作生成式 AI 模型或其他机器学习模型的训练数据。',
  'zh_Hant': '開發者不會將使用者創作或發布的內容、專案資料及其他創作資料，用作生成式 AI 模型或其他機器學習模型的訓練資料。',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in _clauses.entries) {
    testWidgets('学習データの条項が第2条の後に出る（${entry.key}）', (tester) async {
      final locale = entry.key == 'zh_Hant'
          ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
          : Locale(entry.key);
      final premium = PremiumService();
      addTearDown(premium.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 20000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AdvertisingService>(
          create: (_) => AdvertisingService(premiumService: premium),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PrivacyPolicyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final clause = find.text(entry.value);
      expect(clause, findsOneWidget);
      final art2 = find.text(l10n.privacyPolicyArt2Body);
      final art3 = find.text(l10n.privacyPolicyArt3Title);
      expect(
        tester.getTopLeft(clause).dy,
        greaterThan(tester.getTopLeft(art2).dy),
      );
      expect(
        tester.getTopLeft(clause).dy,
        lessThan(tester.getTopLeft(art3).dy),
      );
    });
  }
}
