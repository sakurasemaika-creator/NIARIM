import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// alphaが立っている画素の割合（0.0〜1.0）。
double _inkRatio(Uint8List rgba) {
  var n = 0;
  for (int i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n / (rgba.length / 4);
}

/// パターンの同一性を比較するためのキー（alphaチャンネルの並び）。
String _alphaSignature(Uint8List rgba) {
  final sb = StringBuffer();
  for (int i = 3; i < rgba.length; i += 4) {
    sb.write(rgba[i] == 0 ? '0' : '1');
  }
  return sb.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('組み込みトーン', () {
    test('すべて描画され、白紙にも塗りつぶしにもならない', () async {
      final service = ToneService();
      await service.init();
      expect(service.tones.length, greaterThanOrEqualTo(62));

      for (final tone in service.tones) {
        final ratio = _inkRatio(generateBuiltInToneTexture(tone));
        // 0なら何も描かれておらず、1なら全面ベタでトーンとして機能しない。
        // どちらも「名前の分岐に失敗して意図した模様が出ていない」サイン。
        expect(ratio, greaterThan(0.0), reason: '${tone.name} は何も描画されていない');
        expect(ratio, lessThan(1.0), reason: '${tone.name} が全面ベタ');
      }
    });

    // アルゴリズムの定義上どうしても一致してしまう組み合わせ。
    //
    // 4×4 Bayer行列のオーダードディザは、閾値がちょうど25%・50%のとき、
    // 定義から次の模様と厳密に一致する：
    //   - 25%：閾値未満になる4マス（値0〜3）は行・列とも偶数位置に来るため、
    //     2px間隔の格子点＝「ピクセル散らし」と同じ配置になる。
    //   - 50%：閾値未満になる8マスは (x+y) が偶数の位置に一致するため、
    //     「ピクセル市松」と同じ配置になる。
    //
    // どちらも実装ミスではなく数学的な必然。利用者から見ると「散らし」
    // 「市松」という形の名前で探す人と、「25%」「50%」という濃さで探す人が
    // いるため、どちらの入口も残す判断をしている。
    // Dartのコレクションは`==`が同一性比較なので、集合どうしを直接
    // 比較しても一致しない。名前を並べ替えて連結した文字列で突き合わせる。
    // Dartのコレクションは`==`が同一性比較なので集合どうしを直接比較できない。
    // 名前を並べ替えて連結した文字列へ正規化して突き合わせる。許可リスト側も
    // 同じ関数で正規化し、並び順を書き手が推測しなくて済むようにしておく
    // （手で並べた順がString.compareToの順序と食い違って一致しない、という
    // 取り違えを実際にやったため）。
    String key(List<String> names) => (names.toList()..sort()).join('|');
    final knownIdenticalPairs = {
      key(['ピクセル散らし（1px）', 'ピクセルディザ 25%（4×4）']),
      key(['ピクセル市松（1px）', 'ピクセルディザ 50%（4×4）']),
    };

    test('名前の判定順序が正しく、別々の模様になっている', () async {
      final service = ToneService();
      await service.init();
      // 「ピクセルディザ」は「ピクセル」を、「ピクセル格子」は「格子」を
      // 含む、といった包含関係があるため、判定順序を間違えると別のトーンが
      // 同じ模様になる。全件の模様を突き合わせ、上記の既知の一致を除いて
      // 重複が無いことを確かめる。
      final groups = <String, List<String>>{};
      for (final tone in service.tones) {
        groups
            .putIfAbsent(
              _alphaSignature(generateBuiltInToneTexture(tone)),
              () => [],
            )
            .add(tone.name);
      }
      final unexpected = groups.values
          .where((g) => g.length > 1)
          .where((g) => !knownIdenticalPairs.contains(key(g)))
          .map((g) => g.join(' == '))
          .toList();
      expect(unexpected, isEmpty, reason: '同じ模様になっているトーンがある（名前の判定順序を確認すること）');
    });

    test('模様は毎回同じ（砂目系が乱数で変わらない）', () async {
      final service = ToneService();
      await service.init();
      for (final tone in service.tones.where((t) => t.name.contains('砂目'))) {
        final a = _alphaSignature(generateBuiltInToneTexture(tone));
        final b = _alphaSignature(generateBuiltInToneTexture(tone));
        expect(a, b, reason: '${tone.name} が生成のたびに変わっている');
      }
    });

    test('網点は指定した割合が濃いほどインクが増える', () async {
      final service = ToneService();
      await service.init();
      final dots = service.tones.where((t) => t.name.startsWith('網点')).toList();
      expect(dots.length, greaterThanOrEqualTo(9));
      final ratios = [
        for (final t in dots)
          (
            percent: int.parse(RegExp(r'(\d+)%').firstMatch(t.name)!.group(1)!),
            ink: _inkRatio(generateBuiltInToneTexture(t)),
          ),
      ]..sort((a, b) => a.percent.compareTo(b.percent));
      for (int i = 1; i < ratios.length; i++) {
        expect(
          ratios[i].ink,
          greaterThan(ratios[i - 1].ink),
          reason:
              '網点 ${ratios[i].percent}% が '
              '${ratios[i - 1].percent}% より濃くない',
        );
      }
    });

    test('ピクセルディザは指定した割合とインク量がおおむね一致する', () async {
      final service = ToneService();
      await service.init();
      for (final tone in service.tones.where(
        (t) => t.name.contains('ピクセルディザ'),
      )) {
        final percent = int.parse(
          RegExp(r'(\d+)%').firstMatch(tone.name)!.group(1)!,
        );
        final ink = _inkRatio(generateBuiltInToneTexture(tone));
        // Bayer行列の段階数の都合で丸め誤差が出るため許容幅を持たせる。
        expect(
          (ink - percent / 100.0).abs(),
          lessThan(0.13),
          reason: '${tone.name} の実測インク量が $ink',
        );
      }
    });
  });

  group('組み込みスタンプ', () {
    test('すべて図形が描画され、別々の形になっている', () async {
      final service = StampService();
      await service.init();
      expect(service.stamps.length, greaterThanOrEqualTo(24));

      final seen = <String, String>{};
      for (final stamp in service.stamps) {
        final rgba = await generateBuiltInStampTexture(stamp);
        final ratio = _inkRatio(rgba);
        expect(ratio, greaterThan(0.0), reason: '${stamp.name} が空');
        expect(ratio, lessThan(1.0), reason: '${stamp.name} が全面ベタ');
        final sig = _alphaSignature(rgba);
        final dup = seen[sig];
        expect(
          dup,
          isNull,
          reason:
              '「${stamp.name}」と「$dup」が同じ形になっている'
              '（_shapePathForNameの判定順序を確認すること）',
        );
        seen[sig] = stamp.name;
      }
    });
  });

  group('組み込みブラシ', () {
    test('IDと名前が重複していない', () async {
      final service = BrushService();
      await service.init();
      expect(service.brushes.length, greaterThanOrEqualTo(15));
      expect(
        service.brushes.map((b) => b.id).toSet(),
        hasLength(service.brushes.length),
      );
      expect(
        service.brushes.map((b) => b.name).toSet(),
        hasLength(service.brushes.length),
      );
    });

    test('設定値がUIの許容範囲に収まっている', () async {
      final service = BrushService();
      await service.init();
      for (final b in service.brushes) {
        expect(b.size, inInclusiveRange(1, 200), reason: b.name);
        expect(b.opacity, inInclusiveRange(1, 100), reason: b.name);
        expect(b.spacing, inInclusiveRange(1, 50), reason: b.name);
        expect(b.blurRadius, inInclusiveRange(0, 100), reason: b.name);
        expect(b.density, inInclusiveRange(0.1, 5.0), reason: b.name);
        expect(b.scatter, inInclusiveRange(0.0, 1.0), reason: b.name);
        expect(b.edgeJitterStrength, inInclusiveRange(0, 100), reason: b.name);
        final angle = b.calligraphyAngle;
        if (angle != null) {
          expect(angle, inInclusiveRange(0.0, 360.0), reason: b.name);
        }
      }
    });
  });

  group('プリセットの既定タグ', () {
    test('全ての組み込み素材に既定タグが付いている', () async {
      final tone = ToneService();
      final stamp = StampService();
      final brush = BrushService();
      await tone.init();
      await stamp.init();
      await brush.init();
      for (final t in tone.tones) {
        expect(t.tags, isNotEmpty, reason: 'トーン「${t.name}」にタグが無い');
      }
      for (final e in stamp.stamps) {
        expect(e.tags, isNotEmpty, reason: 'スタンプ「${e.name}」にタグが無い');
      }
      for (final b in brush.brushes) {
        expect(b.tags, isNotEmpty, reason: 'ブラシ「${b.name}」にタグが無い');
      }
    });

    test('タグ検索で意図した素材が引ける', () async {
      final tone = ToneService();
      await tone.init();
      // ドット絵向けのトーンだけを「ドット絵」タグで引けること。
      final pixel = tone.tones.where((t) => t.tags.contains('ドット絵'));
      expect(pixel, isNotEmpty);
      expect(
        pixel.every((t) => t.name.contains('ピクセル')),
        isTrue,
        reason: 'ドット絵タグに非ピクセルのトーンが混ざっている',
      );
    });
  });

  group('既存ユーザーへの反映', () {
    test('保存済みデータへ後から足した組み込み素材がマージされる', () async {
      // 「古い版で保存された状態」を、組み込み素材が1件だけの保存データで
      // 模擬する。init()が不足分を補ってくれないと、既存ユーザーは新しい
      // プリセットを一生受け取れない。
      Future<void> check(
        Future<int> Function() countAfterInit,
        String label,
      ) async {
        expect(await countAfterInit(), greaterThanOrEqualTo(2), reason: label);
      }

      SharedPreferences.setMockInitialValues({
        'stamps': ['{"id":"Stamp0001","name":"三角形"}'],
      });
      await check(() async {
        final s = StampService();
        await s.init();
        return s.stamps.length;
      }, 'StampService');

      SharedPreferences.setMockInitialValues({
        'tones': ['{"id":"Tone0001","name":"網点 10%"}'],
      });
      await check(() async {
        final s = ToneService();
        await s.init();
        return s.tones.length;
      }, 'ToneService');
    });

    test('タグ未設定の保存済み素材へ既定タグが後から付く', () async {
      SharedPreferences.setMockInitialValues({
        'tones': ['{"id":"Tone0001","name":"網点 10%"}'],
      });
      final s = ToneService();
      await s.init();
      expect(s.tones.firstWhere((t) => t.id == 'Tone0001').tags, isNotEmpty);
    });

    test('利用者が付けたタグは既定タグで上書きされない', () async {
      SharedPreferences.setMockInitialValues({
        'tones': ['{"id":"Tone0001","name":"網点 10%","tags":["自分のタグ"]}'],
      });
      final s = ToneService();
      await s.init();
      expect(s.tones.firstWhere((t) => t.id == 'Tone0001').tags, ['自分のタグ']);
    });
  });
}
