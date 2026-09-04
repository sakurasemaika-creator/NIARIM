import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_tags.dart';
import '../models/tone.dart';

class ToneFolder {
  final String id;
  final String name;
  final bool isFavorite;
  ToneFolder({required this.id, required this.name, this.isFavorite = false});

  ToneFolder copyWith({String? name, bool? isFavorite}) => ToneFolder(
    id: id,
    name: name ?? this.name,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isFavorite': isFavorite,
  };

  factory ToneFolder.fromJson(Map<String, dynamic> j) => ToneFolder(
    id: j['id'] as String,
    name: j['name'] as String,
    isFavorite: j['isFavorite'] as bool? ?? false,
  );
}

/// トーン管理サービス。SharedPreferencesへ永続化する
/// （端末単位。プロジェクトファイルには含めない）。従来はインメモリのみで、
/// お気に入り・追加・削除・編集のすべてがアプリ再起動のたびに失われていた
/// （Task#83で修正）。自作トーン・フォルダ管理・読み込み/書き出しは
/// Task#84で追加した。テクスチャ画像はアプリ全体の`Tones/`フォルダへ
/// コピーして保存する。
class ToneService extends ChangeNotifier {
  static const _prefsKey = 'tones';
  static const _foldersKey = 'tone_folders';

  final List<Tone> _tones = [];
  final List<ToneFolder> _folders = [];
  Tone? _currentTone;
  // バケツ塗りと投げ縄塗りはそれぞれ独立して最後に使用したトーンを保持
  Tone? _lastBucketTone;
  Tone? _lastLassoTone;
  // 投げ縄塗り：ベタ塗り／トーンの選択状態
  bool _lassoUseTone = false;
  // バケツ塗り：ベタ塗り／トーンの選択状態
  bool _bucketUseTone = false;

  List<Tone> get tones => List.unmodifiable(_tones);
  List<ToneFolder> get folders => List.unmodifiable(_folders);
  Tone? get currentTone => _currentTone;
  Tone? get lastBucketTone => _lastBucketTone;
  Tone? get lastLassoTone => _lastLassoTone;
  bool get lassoUseTone => _lassoUseTone;
  bool get bucketUseTone => _bucketUseTone;

  void setLassoUseTone(bool value) {
    _lassoUseTone = value;
    notifyListeners();
  }

  void setBucketUseTone(bool value) {
    _bucketUseTone = value;
    notifyListeners();
  }

  static List<Tone> _defaultTones() => [
    const Tone(
      id: 'Tone0001',
      name: '網点 10%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0002',
      name: '網点 30%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0003',
      name: '網点 50%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0004',
      name: '網点 70%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0005',
      name: 'ライン 細',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0006',
      name: 'ライン 太',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    // ピクセルモード用トーン（1ピクセルごとに市松模様／格子柄／散らし
    // 配置になっているトーン）。procedural_texture.dartの
    // generateBuiltInToneTextureが名前に「市松」「格子」「散らし」を
    // 含むかで判定する。「散らし」は格子（縦横の線がつながって網目状）
    // とは逆に、1ピクセルずつ上下左右を1px空けて独立させたもの。
    // 「ドット」という表記は丸い水玉模様と誤認されるため使わず、
    // 四角い1ピクセル単位のパターンには「ピクセル」を使う
    // （brush.dartのpixelMode改称と同じ理由・同じ命名規則）。
    const Tone(
      id: 'Tone0007',
      name: 'ピクセル市松（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    const Tone(
      id: 'Tone0008',
      name: 'ピクセル格子（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    const Tone(
      id: 'Tone0009',
      name: 'ピクセル散らし（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    // ストッキング・タイツ：デニール数が低いほど生地が薄く目が細かい
    // ため、パターンの格子間隔を詰めて再現する（procedural_texture.dartの
    // generateBuiltInToneTextureが名前の「デニール」数値を読み取って
    // 密度を決める）。デニール数が最も低いものは格子間隔を最小にし、
    // 意図的に細かすぎてモアレが出るくらいの密度にしている。
    const Tone(
      id: 'Tone0010',
      name: 'ストッキング 10デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    const Tone(
      id: 'Tone0011',
      name: 'ストッキング 20デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    const Tone(
      id: 'Tone0012',
      name: 'ストッキング 30デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    const Tone(
      id: 'Tone0013',
      name: 'タイツ 40デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    const Tone(
      id: 'Tone0014',
      name: 'タイツ 60デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    const Tone(
      id: 'Tone0015',
      name: 'タイツ 80デニール',
      tags: [AssetTagKeys.clothing, AssetTagKeys.mesh],
    ),
    // ディザリングプリセット：Bayerオーダードディザ行列による、ドット絵・
    // レトロゲーム風の規則的な階調表現（procedural_texture.dartの
    // generateBuiltInToneTextureが名前の「ピクセルディザ」と「%」数値・
    // 「(粗)」の有無で判定する）。網点（円が段々大きくなる連続的な
    // 階調表現）とは異なり、行列内の固定パターンで塗るか塗らないかを
    // 決めるため、ピクセルモードでの塗り分けに向く。4×4行列（16段階の
    // うち代表的な7段階）と、より粗く単位が大きい2×2行列（4段階の
    // うち代表的な3段階）の2系統を用意する。
    const Tone(
      id: 'Tone0016',
      name: 'ピクセルディザ 12%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0017',
      name: 'ピクセルディザ 25%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0018',
      name: 'ピクセルディザ 37%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0019',
      name: 'ピクセルディザ 50%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0020',
      name: 'ピクセルディザ 62%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0021',
      name: 'ピクセルディザ 75%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0022',
      name: 'ピクセルディザ 87%（4×4）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0023',
      name: 'ピクセルディザ(粗) 25%（2×2）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0024',
      name: 'ピクセルディザ(粗) 50%（2×2）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0025',
      name: 'ピクセルディザ(粗) 75%（2×2）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    // ── ここから下は「よくあるイラスト制作ソフトなら入っている定番」を
    // 一般的な幾何・数式から起こしたもの。既製品のパターン画像は使わず、
    // すべてprocedural_texture.dartが計算で生成する。
    //
    // 網点の中間段階。既存は10/30/50/70%の4段階しか無く、影の濃さを
    // 詰めたいときに刻みが粗すぎた。
    const Tone(
      id: 'Tone0026',
      name: '網点 20%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0027',
      name: '網点 40%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0028',
      name: '網点 60%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0029',
      name: '網点 80%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0030',
      name: '網点 90%',
      tags: [AssetTagKeys.halftone, AssetTagKeys.shadow],
    ),
    // 線トーンの向き違い。既存は横線の細/太だけだった。
    const Tone(
      id: 'Tone0031',
      name: 'ライン 縦細',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0032',
      name: 'ライン 縦太',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0033',
      name: 'ライン 斜め細',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    const Tone(
      id: 'Tone0034',
      name: 'ライン 斜め太',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow],
    ),
    // クロスハッチ：線を交差させる陰影表現。ペン画・銅版画風の質感に。
    const Tone(
      id: 'Tone0035',
      name: 'クロスハッチ 細',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0036',
      name: 'クロスハッチ 中',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0037',
      name: 'クロスハッチ 太',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0038',
      name: 'クロスハッチ 斜め細',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0039',
      name: 'クロスハッチ 斜め太',
      tags: [AssetTagKeys.line, AssetTagKeys.shadow, AssetTagKeys.analog],
    ),
    // 砂目：アナログのスクリーントーンでは定番の、ざらついた不規則な粒。
    // 粒の大きさ違いで3種類。
    const Tone(
      id: 'Tone0040',
      name: '砂目 細',
      tags: [AssetTagKeys.texture, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0041',
      name: '砂目 中',
      tags: [AssetTagKeys.texture, AssetTagKeys.analog],
    ),
    const Tone(
      id: 'Tone0042',
      name: '砂目 粗',
      tags: [AssetTagKeys.texture, AssetTagKeys.analog],
    ),
    // 背景・小物向けの幾何パターン。
    const Tone(
      id: 'Tone0043',
      name: '同心円',
      tags: [AssetTagKeys.background, AssetTagKeys.pattern],
    ),
    const Tone(
      id: 'Tone0044',
      name: '波線',
      tags: [AssetTagKeys.background, AssetTagKeys.pattern],
    ),
    const Tone(
      id: 'Tone0045',
      name: 'レンガ',
      tags: [AssetTagKeys.background, AssetTagKeys.pattern],
    ),
    const Tone(
      id: 'Tone0046',
      name: '方眼 細',
      tags: [AssetTagKeys.background, AssetTagKeys.pattern],
    ),
    const Tone(
      id: 'Tone0047',
      name: '方眼 太',
      tags: [AssetTagKeys.background, AssetTagKeys.pattern],
    ),
    // ── ピクセルモード用の追加分 ──
    // 1px単位の縞。市松・格子・散らしと違い、向きを選べる。
    const Tone(
      id: 'Tone0048',
      name: 'ピクセル横縞（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    const Tone(
      id: 'Tone0049',
      name: 'ピクセル縦縞（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    const Tone(
      id: 'Tone0050',
      name: 'ピクセル斜め縞（1px）',
      tags: [AssetTagKeys.pixelArt],
    ),
    // 1px単位のノイズ。規則的なディザと違って不規則なので、砂・岩肌・
    // 汚れなどの表現に向く。
    const Tone(
      id: 'Tone0051',
      name: 'ピクセル砂目 25%',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.texture],
    ),
    const Tone(
      id: 'Tone0052',
      name: 'ピクセル砂目 50%',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.texture],
    ),
    const Tone(
      id: 'Tone0053',
      name: 'ピクセル砂目 75%',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.texture],
    ),
    const Tone(id: 'Tone0054', name: 'ピクセルレンガ', tags: [AssetTagKeys.pixelArt]),
    // 8×8 Bayer行列によるディザ。4×4（16段階）より刻みが4倍細かいので、
    // なだらかなグラデーションをドット絵として落とし込める。
    const Tone(
      id: 'Tone0055',
      name: 'ピクセルディザ(細) 6%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0056',
      name: 'ピクセルディザ(細) 19%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0057',
      name: 'ピクセルディザ(細) 31%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0058',
      name: 'ピクセルディザ(細) 44%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0059',
      name: 'ピクセルディザ(細) 56%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0060',
      name: 'ピクセルディザ(細) 69%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0061',
      name: 'ピクセルディザ(細) 81%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
    const Tone(
      id: 'Tone0062',
      name: 'ピクセルディザ(細) 94%（8×8）',
      tags: [AssetTagKeys.pixelArt, AssetTagKeys.gradient],
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _tones.clear();
    if (raw == null) {
      _tones.addAll(_defaultTones());
      await _persist();
    } else {
      _tones.addAll(
        raw.map((s) => Tone.fromJson(jsonDecode(s) as Map<String, dynamic>)),
      );
      // 既存ユーザーにも新規追加した初期トーン（ピクセルモード2種）を
      // 反映する（既に同名IDのトーンが存在する場合は追加しない）。
      final existingIds = _tones.map((t) => t.id).toSet();
      final missing = _defaultTones().where((t) => !existingIds.contains(t.id));
      var changed = false;
      if (missing.isNotEmpty) {
        _tones.addAll(missing);
        changed = true;
      }
      // 「ドット○○（1px）」は「ピクセル○○（1px）」へ改称した（「ドット」が
      // 丸い水玉模様と誤認されるため）。旧名のまま残っている既存ユーザーの
      // トーンをIDで特定して更新する。
      final defaults = {for (final t in _defaultTones()) t.id: t};
      for (int i = 0; i < _tones.length; i++) {
        final fresh = defaults[_tones[i].id];
        if (fresh != null &&
            _tones[i].name != fresh.name &&
            _tones[i].name.contains('ドット')) {
          _tones[i] = _tones[i].copyWith(name: fresh.name);
          changed = true;
        }
      }
      // 既定タグを日本語リテラルで保存していた版からの移行。
      for (int i = 0; i < _tones.length; i++) {
        final migrated = migrateLegacyTags(_tones[i].tags);
        if (!identical(migrated, _tones[i].tags)) {
          _tones[i] = _tones[i].copyWith(tags: migrated);
          changed = true;
        }
      }
      // 組み込み素材へ後から既定タグを付けたので、保存済みデータにも
      // 反映する。**利用者が自分で付けたタグは絶対に上書きしない**ため、
      // タグが1件も無いものだけを対象にする（タグを意図的に全部外した
      // 状態は「まだ付けていない」と区別できないが、既定タグが戻るだけで
      // 実害が無く、上書きで消してしまう害のほうが大きい）。
      final defaultTags = {
        for (final t in _defaultTones())
          if (t.tags.isNotEmpty) t.id: t.tags,
      };
      for (int i = 0; i < _tones.length; i++) {
        final tags = defaultTags[_tones[i].id];
        if (tags != null && _tones[i].tags.isEmpty) {
          _tones[i] = _tones[i].copyWith(tags: tags);
          changed = true;
        }
      }
      if (changed) await _persist();
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
        foldersRaw.map(
          (s) => ToneFolder.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
    }
    _currentTone = _tones.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _tones.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _foldersKey,
      _folders.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  void selectTone(String id) {
    _currentTone = _tones.firstWhere((t) => t.id == id);
    notifyListeners();
  }

  void setLastBucketTone(Tone tone) {
    _lastBucketTone = tone;
    notifyListeners();
  }

  void setLastLassoTone(Tone tone) {
    _lastLassoTone = tone;
    notifyListeners();
  }

  /// トーンへ分類用タグを設定する（既存のタグ列を置き換える）。
  ///
  /// お気に入りと同様、**組み込みトーンにも付けられる**。編集・削除は
  /// できなくても「どう分類したいか」は利用者の都合であり、そこを縛ると
  /// タグ機能がほとんど使えなくなるため（`updateXxx`のような
  /// `isBuiltIn`ガードは意図的に置いていない）。
  void setTags(String id, List<String> tags) {
    final idx = _tones.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _tones[idx] = _tones[idx].copyWith(tags: normalizeTags(tags));
    notifyListeners();
    _persist();
  }

  /// 登録されている全タグを、使われている件数の多い順（同数なら名前順）で
  /// 返す。タグ検索の候補チップに使う。表記ゆれで別タグ扱いにならないよう、
  /// 大文字小文字を無視して数え、代表表記は最初に見つかったものを使う。
  List<String> allTags() {
    final count = <String, int>{};
    final display = <String, String>{};
    for (final e in _tones) {
      for (final tag in e.tags) {
        final key = tag.toLowerCase();
        count[key] = (count[key] ?? 0) + 1;
        display.putIfAbsent(key, () => tag);
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = count[b]!.compareTo(count[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final k in keys) display[k]!];
  }

  void toggleFavorite(String id) {
    final idx = _tones.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tones[idx] = _tones[idx].copyWith(isFavorite: !_tones[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  // プリインストールされている初期実装トーン（_defaultTones()の9件）は
  // 編集・削除の対象外とする（複製したものは別IDになるため、複製後の
  // 編集・削除は可能）。
  static final Set<String> _builtInIds = _defaultTones()
      .map((t) => t.id)
      .toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  void addTone(Tone tone) {
    _tones.add(tone);
    notifyListeners();
    _persist();
  }

  /// [id]のトーンを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool deleteTone(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _tones.indexWhere((t) => t.id == id);
    if (idx < 0) return false;
    if (_tones[idx].isFavorite) return false;
    _tones.removeAt(idx);
    notifyListeners();
    _persist();
    return true;
  }

  void updateTone(Tone tone) {
    if (isBuiltIn(tone.id)) return;
    final idx = _tones.indexWhere((t) => t.id == tone.id);
    if (idx >= 0) {
      _tones[idx] = tone;
      notifyListeners();
      _persist();
    }
  }

  /// トーン一覧の表示順をドラッグで並べ替える（ブラシと同じ操作方法）。
  void reorderTone(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final tone = _tones.removeAt(oldIndex);
    _tones.insert(newIndex, tone);
    notifyListeners();
    _persist();
  }

  /// [id]のトーンを複製する（名前の末尾に「のコピー」を付けて追加）。
  /// プリインストールのトーンも複製自体は可能（複製後の新しいIDは
  /// プリインストール扱いにならない）。
  void duplicateTone(String id) {
    final tone = _tones.firstWhere((t) => t.id == id);
    final newId = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    _tones.add(
      tone.copyWith(id: newId, name: '${tone.name} (コピー)', isFavorite: false),
    );
    notifyListeners();
    _persist();
  }

  // ─── フォルダ管理 ─────────────────────────────────────────

  Future<ToneFolder> createFolder(String name) async {
    final folder = ToneFolder(
      id: 'ToneFolder${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    _folders.add(folder);
    notifyListeners();
    await _persistFolders();
    return folder;
  }

  void renameFolder(String id, String name) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(name: name);
    notifyListeners();
    _persistFolders();
  }

  void toggleFolderFavorite(String id) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(
      isFavorite: !_folders[idx].isFavorite,
    );
    notifyListeners();
    _persistFolders();
  }

  void reorderFolder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final folder = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, folder);
    notifyListeners();
    _persistFolders();
  }

  void deleteFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    for (int i = 0; i < _tones.length; i++) {
      if (_tones[i].folderId == id) {
        _tones[i] = _tones[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
    _persistFolders();
    _persist();
  }

  void moveToFolder(String toneId, String? folderId) {
    final idx = _tones.indexWhere((t) => t.id == toneId);
    if (idx < 0) return;
    _tones[idx] = _tones[idx].copyWith(folderId: folderId);
    notifyListeners();
    _persist();
  }

  // ─── 自作トーン（画像からの新規作成） ──────────────────────────

  Future<Directory> _tonesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Tones');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Tone> createToneFromImage(String sourcePath, {String? name}) async {
    final id = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _tonesDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final tone = Tone(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作トーン',
      texturePath: destPath,
    );
    addTone(tone);
    return tone;
  }

  // ─── 読み込み・書き出し（個別ファイル単位） ───────────────────

  static const _bundleDataFile = 'data.json';

  Future<File> exportTone(String id) async {
    final tone = _tones.firstWhere((t) => t.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = tone.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.niatone';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
      ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(tone.toJson()))),
    );
    final texturePath = tone.texturePath;
    if (texturePath != null && File(texturePath).existsSync()) {
      final bytes = await File(texturePath).readAsBytes();
      final ext = texturePath.split('.').last;
      encoder.addArchiveFile(ArchiveFile('image.$ext', bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  Future<Tone> importToneFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final imported = Tone.fromJson(json);
    final id = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files
        .where((f) => f.name.startsWith('image.'))
        .firstOrNull;
    String? newTexturePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _tonesDir();
      newTexturePath = '${dir.path}/$id.$ext';
      await File(newTexturePath).writeAsBytes(imageFile.content as List<int>);
    }
    // texturePathは元端末のパスをそのまま引き継げないため、copyWith（??で
    // nullを無視する実装）を使わず、常にnewTexturePath（nullなら未設定）で
    // 明示的に上書きする。
    final tone = Tone(
      id: id,
      name: imported.name,
      texturePath: newTexturePath,
      isFavorite: imported.isFavorite,
    );
    addTone(tone);
    return tone;
  }
}
