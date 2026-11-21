import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/asset_tags.dart';
import 'package:niarim/screens/canvas/widgets/asset_search_bar.dart';
import 'package:niarim/widgets/asset_tag_label.dart';

/// 各ロケールのAppLocalizationsを取り出す。
Future<AppLocalizations> _l10nFor(Locale locale) async =>
    AppLocalizations.delegate.load(locale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locales = AppLocalizations.supportedLocales;

  test('対応7言語すべてが読み込める', () {
    expect(locales, hasLength(7));
  });

  test('全ての既定タグが全言語で翻訳されている（キーが素通ししていない）', () async {
    for (final locale in locales) {
      final l10n = await _l10nFor(locale);
      for (final key in AssetTagKeys.all) {
        final label = localizeAssetTag(l10n, key);
        expect(label, isNot(startsWith('@')), reason: '$locale で $key が未翻訳のまま');
        expect(label.trim(), isNotEmpty, reason: '$locale の $key が空');
      }
    }
  });

  test('同じ言語の中で既定タグの訳が重複していない', () async {
    // 重複すると、タグ検索のチップが2つ同じ名前で並び、
    // delocalizeAssetTagがどちらのキーへ戻すか決められなくなる。
    for (final locale in locales) {
      final l10n = await _l10nFor(locale);
      final labels = <String, String>{};
      for (final key in AssetTagKeys.all) {
        final label = localizeAssetTag(l10n, key).toLowerCase();
        expect(
          labels[label],
          isNull,
          reason: '$locale で「$label」が $key と ${labels[label]} で重複',
        );
        labels[label] = key;
      }
    }
  });

  test('表示文言→キーの往復が全言語で成り立つ', () async {
    for (final locale in locales) {
      final l10n = await _l10nFor(locale);
      for (final key in AssetTagKeys.all) {
        expect(
          delocalizeAssetTag(l10n, localizeAssetTag(l10n, key)),
          key,
          reason: '$locale で $key の往復が壊れている',
        );
      }
    }
  });

  test('大文字小文字を無視して既定タグへ戻せる', () async {
    final en = await _l10nFor(const Locale('en'));
    // 候補チップではなく手入力した場合も既定タグとして扱いたい。
    expect(delocalizeAssetTag(en, 'PIXEL ART'), AssetTagKeys.pixelArt);
    expect(delocalizeAssetTag(en, '  line art  '), AssetTagKeys.lineArt);
  });

  test('利用者独自のタグはキーへ変換されずそのまま残る', () async {
    final ja = await _l10nFor(const Locale('ja'));
    expect(delocalizeAssetTag(ja, '案件A'), '案件A');
    expect(localizeAssetTag(ja, '案件A'), '案件A');
  });

  test('利用者は@始まりのタグを作れない（キーの名前空間を守る）', () {
    expect(splitTagInput('@pixelart @@x 通常タグ'), ['pixelart', 'x', '通常タグ']);
  });

  test('未知のキーは@を落として読める形で表示する', () async {
    final ja = await _l10nFor(const Locale('ja'));
    expect(localizeAssetTag(ja, '@future_tag'), 'future_tag');
  });

  test('英語UIで「pixel」と打つとドット絵タグの素材が引ける', () async {
    final en = await _l10nFor(const Locale('en'));
    // 保存されているのはキーなので、表示文言へ直してから突き合わせる。
    final tags = localizeAssetTags(en, [AssetTagKeys.pixelArt]);
    expect(
      assetMatchesSearch(
        name: 'Tone0007',
        tags: tags,
        mode: AssetSearchMode.tag,
        query: 'pixel',
      ),
      isTrue,
    );
    // 日本語の「ドット絵」では引けない（英語UIなので当然）。
    expect(
      assetMatchesSearch(
        name: 'Tone0007',
        tags: tags,
        mode: AssetSearchMode.tag,
        query: 'ドット絵',
      ),
      isFalse,
    );
  });
}
