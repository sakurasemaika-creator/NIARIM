import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/asset_tags.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/screens/canvas/widgets/asset_search_bar.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('タグの正規化', () {
    test('前後空白・空文字・重複（大小無視）を落とす', () {
      expect(normalizeTags(['  影  ', '影', 'カゲ', '', '   ']), ['影', 'カゲ']);
      expect(normalizeTags(['Hair', 'hair', 'HAIR']), ['Hair']);
    });

    test('1件あたりの長さと件数の上限を適用する', () {
      final long = 'あ' * 40;
      expect(normalizeTags([long]).single.length, kAssetTagMaxLength);
      final many = List<String>.generate(30, (i) => 'tag$i');
      expect(normalizeTags(many), hasLength(kAssetTagMaxCount));
    });

    test('カンマ・読点・空白のどれでも区切れる', () {
      expect(splitTagInput('影, ハイライト、背景  線画'), ['影', 'ハイライト', '背景', '線画']);
    });

    test('返り値は変更不可（呼び出し側の書き換え事故を防ぐ）', () {
      expect(() => normalizeTags(['a']).add('b'), throwsUnsupportedError);
    });
  });

  group('保存済みJSONからの復元', () {
    test('キーが無い旧データは空リストになる', () {
      expect(parseTags(null), isEmpty);
      // タグ導入前に保存されたJSONにはキー自体が無い
      expect(Tone.fromJson({'id': 'T1', 'name': 'a'}).tags, isEmpty);
    });

    test('型が壊れていても落ちず、文字列以外は捨てる', () {
      expect(parseTags('影'), isEmpty);
      expect(parseTags([1, '影', null, true]), ['影']);
    });

    test('Brush/Tone/Stampがタグ込みでJSON往復する', () {
      const tags = ['影', 'hair'];
      final tone = const Tone(id: 'T1', name: 'a', tags: tags);
      expect(Tone.fromJson(tone.toJson()).tags, tags);

      final stamp = const Stamp(id: 'S1', name: 'a', tags: tags);
      expect(Stamp.fromJson(stamp.toJson()).tags, tags);

      final brush = const Brush(
        id: 'B1',
        name: 'a',
        size: 5,
        opacity: 100,
        spacing: 1,
        blurRadius: 0,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        pressureMode: PressureMode.off,
        pressureStrength: 0,
        fadeMode: FadeMode.off,
        strokeDecay: false,
        mixingMode: BrushMixingMode.off,
        mixingRate: 0,
        tags: tags,
      );
      expect(Brush.fromJson(brush.toJson()).tags, tags);
    });
  });

  group('検索の一致判定', () {
    test('キーワード検索は名前だけを見る', () {
      expect(
        assetMatchesSearch(
          name: 'Gペン',
          tags: const ['影'],
          mode: AssetSearchMode.keyword,
          query: 'ペン',
        ),
        isTrue,
      );
      expect(
        assetMatchesSearch(
          name: 'Gペン',
          tags: const ['影'],
          mode: AssetSearchMode.keyword,
          query: '影',
        ),
        isFalse,
      );
    });

    test('タグ検索はタグだけを見る（部分一致・大小無視）', () {
      expect(
        assetMatchesSearch(
          name: 'Gペン',
          tags: const ['Hair'],
          mode: AssetSearchMode.tag,
          query: 'hai',
        ),
        isTrue,
      );
      expect(
        assetMatchesSearch(
          name: 'Gペン',
          tags: const ['Hair'],
          mode: AssetSearchMode.tag,
          query: 'ペン',
        ),
        isFalse,
      );
    });

    test('空クエリはどちらの方式でも常に一致（＝絞り込み無し）', () {
      for (final mode in AssetSearchMode.values) {
        expect(
          assetMatchesSearch(
            name: 'x',
            tags: const [],
            mode: mode,
            query: '   ',
          ),
          isTrue,
        );
      }
    });
  });

  group('サービスのタグAPI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('組み込み素材にもタグを付けられる（お気に入りと同じ扱い）', () async {
      final s = ToneService();
      await s.init();
      final builtIn = s.tones.first;
      expect(s.isBuiltIn(builtIn.id), isTrue);
      s.setTags(builtIn.id, ['影', '影', '  ']);
      expect(s.tones.first.tags, ['影']);
    });

    test('タグは再起動後も復元される', () async {
      final s1 = StampService();
      await s1.init();
      s1.setTags(s1.stamps.first.id, ['吹き出し', 'ふきだし']);
      await Future<void>.delayed(Duration.zero);

      final s2 = StampService();
      await s2.init();
      expect(s2.stamps.first.tags, ['吹き出し', 'ふきだし']);
    });

    test('allTags()は使用件数の多い順、同数なら名前順で返す', () async {
      final s = BrushService();
      await s.init();
      final ids = s.brushes.map((b) => b.id).toList();
      s.setTags(ids[0], ['共通', 'zzz']);
      s.setTags(ids[1], ['共通', 'aaa']);
      s.setTags(ids[2], ['共通']);
      expect(s.allTags(), ['共通', 'aaa', 'zzz']);
    });

    test('表記ゆれ（大小違い）は1件に数え、最初の表記を代表にする', () async {
      final s = BrushService();
      await s.init();
      final ids = s.brushes.map((b) => b.id).toList();
      s.setTags(ids[0], ['Hair']);
      s.setTags(ids[1], ['hair']);
      expect(s.allTags(), ['Hair']);
    });

    test('存在しないIDへのsetTagsは何もしない', () async {
      final s = ToneService();
      await s.init();
      final before = s.tones.map((t) => t.tags).toList();
      s.setTags('存在しないID', ['影']);
      expect(s.tones.map((t) => t.tags).toList(), before);
    });
  });
}
