import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/advertising_service.dart';
import '../../config/font_fallback.dart';

/// プライバシーポリシー画面。
///
/// Web版（NIARIM-web）のプライバシーポリシーを共通の正本として扱う。
/// 既存の第1〜9条はAppLocalizationsの7言語本文を表示し、Web版で
/// 2026-09-04に第2条へ追加した「生成AI・機械学習の学習データとして
/// 利用しない」条項も7言語で同じ位置に表示する。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _PolicyBody(),
            SizedBox(height: 16),
            _PrivacyOptionsButton(),
          ],
        ),
      ),
    );
  }
}

/// EEA・英国・スイス等、CMP対象地域のユーザーにのみ表示する
/// 「広告の同意設定を変更」ボタン。
class _PrivacyOptionsButton extends StatelessWidget {
  const _PrivacyOptionsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final advertisingService = context.watch<AdvertisingService>();
    return FutureBuilder<PrivacyOptionsRequirementStatus>(
      future: advertisingService.privacyOptionsRequirementStatus(),
      builder: (context, snapshot) {
        if (snapshot.data != PrivacyOptionsRequirementStatus.required) {
          return const SizedBox.shrink();
        }
        return OutlinedButton.icon(
          onPressed: () => advertisingService.showPrivacyOptionsForm(),
          icon: const Icon(Icons.tune),
          label: Text(l10n.privacyPolicyAdConsentButton),
        );
      },
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (l10n.privacyPolicyArt1Title, l10n.privacyPolicyArt1Body),
      (l10n.privacyPolicyArt2Title, l10n.privacyPolicyArt2Body),
      (l10n.privacyPolicyArt3Title, l10n.privacyPolicyArt3Body),
      (l10n.privacyPolicyArt4Title, l10n.privacyPolicyArt4Body),
      (l10n.privacyPolicyArt5Title, l10n.privacyPolicyArt5Body),
      (l10n.privacyPolicyArt6Title, l10n.privacyPolicyArt6Body),
      (l10n.privacyPolicyArt7Title, l10n.privacyPolicyArt7Body),
      (l10n.privacyPolicyArt8Title, l10n.privacyPolicyArt8Body),
      (l10n.privacyPolicyArt9Title, l10n.privacyPolicyArt9Body),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sections[i].$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sections[i].$2,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                if (i == 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    _aiTrainingNonUseClause(context),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// NIARIM-web /privacy/ 第2条の最新追記と同内容。
/// Web側の正本（日本語）の意味を保った7言語表記。
String _aiTrainingNonUseClause(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode.toLowerCase();

  if (language == 'ja') {
    return '開発者は、ユーザーが作成または投稿したコンテンツ、プロジェクトデータその他の制作データを、生成AIモデルその他の機械学習モデルの学習データとして利用しません。';
  }
  if (language == 'ko') {
    return '개발자는 사용자가 제작하거나 게시한 콘텐츠, 프로젝트 데이터 및 기타 제작 데이터를 생성형 AI 모델 또는 기타 머신러닝 모델의 학습 데이터로 사용하지 않습니다.';
  }
  if (language == 'fr') {
    return "Le développeur n’utilise pas les contenus créés ou publiés par les utilisateurs, les données de projet ni les autres données de création comme données d’entraînement pour des modèles d’IA générative ou d’autres modèles d’apprentissage automatique.";
  }
  if (language == 'es') {
    return 'El desarrollador no utiliza el contenido creado o publicado por los usuarios, los datos de proyectos ni otros datos de creación como datos de entrenamiento para modelos de IA generativa u otros modelos de aprendizaje automático.';
  }
  if (language == 'zh') {
    final region = (locale.countryCode ?? '').toUpperCase();
    final isTraditional =
        locale.scriptCode?.toLowerCase() == 'hant' ||
        region == 'TW' ||
        region == 'HK' ||
        region == 'MO';
    if (isTraditional) {
      return '開發者不會將使用者創作或發布的內容、專案資料及其他創作資料，用作生成式 AI 模型或其他機器學習模型的訓練資料。';
    }
    return '开发者不会将用户创作或发布的内容、项目数据及其他创作数据，用作生成式 AI 模型或其他机器学习模型的训练数据。';
  }

  return 'The developer does not use content created or published by users, project data, or other creation data as training data for generative AI models or other machine-learning models.';
}
