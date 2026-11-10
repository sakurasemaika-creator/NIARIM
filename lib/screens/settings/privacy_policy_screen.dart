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
/// 利用しない」条項も7言語（ARB）で同じ位置に表示する。
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
                    l10n.privacyPolicyArt2AiTrainingClause,
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
