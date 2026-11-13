import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_error_reporter.dart';

import '../engine/brush_texture_cache.dart';
import '../models/asset_tags.dart';
import '../models/brush.dart';
import '../models/brush_presets_extension.dart';
import '../utils/duplicate_name.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

/// ブラシ管理サービス。
/// SharedPreferencesへ永続化する（端末単位。プロジェクトファイルには含めない）。
/// お気に入り・並び替え・複製・削除・パラメータ編集の内容を保持する。
/// 自作ブラシ（画像からの新規作成）・フォルダ管理・読み込み/書き出しにも対応し、
/// カスタム画像はアプリ全体の`Brushes/`フォルダへコピーして保存する。
class BrushService extends ChangeNotifier {
  static const _prefsKey = 'brushes';
  static const _currentIdKey = 'brushes_current_id';
  static const _foldersKey = 'brush_folders';

  /// 組み込みブラシで、利用者がキャンバスから変えた太さ・不透明度。
  ///
  /// 組み込みブラシの定義は起動のたびに最新へそろえる（[init]）ので、
  /// 利用者が変えた値は定義と分けて覚える。こうしておくと、触っていない
  /// 組み込みブラシは後の版で既定の太さが変わればそれに従い、触った
  /// ブラシだけが利用者の値を保つ。自作・複製のブラシはブラシ自身に書く。
  static const _builtInWorkingKey = 'brush_builtin_working_values';

  /// このサービスが持つ保存のキー。引き継ぎ（.niatra）の「端末保存データ」
  /// （保存をまるごと移す項目）では扱わない：ブラシは「ブラシ」の項目が
  /// [mergeTransferred]で一覧と突き合わせて取り込む。保存を直接書き換えると、
  /// 動いている一覧の次の保存で戻り、起動し直すとこの端末にしか無いブラシが
  /// 消える。
  static const Set<String> savedPreferenceKeys = {
    _prefsKey,
    _currentIdKey,
    _foldersKey,
    _builtInWorkingKey,
  };

  /// 保存の中の、この版では読めなかった項目（そのままの文字列）。
  ///
  /// 一覧には出さないが、保存し直すときに末尾へ残す。ブラシの一覧は
  /// キャンバスで太さを変えるだけでも保存し直すので、読めた分だけを書くと、
  /// 後の版でなら読めたかもしれない自作のブラシがその場で消える。
  final List<String> _unreadableEntries = [];

  /// フォルダの保存の中の、この版では読めなかった項目（同じく末尾へ残す）。
  final List<String> _unreadableFolderEntries = [];
  final Map<String, ({double? size, int? opacity})> _builtInWorking = {};

  // スライダーは動かしている間ずっと値を知らせる。そのたびに全ブラシを
  // 保存すると設定ファイル全体の書き込みが1秒に数十回走るので、覚えた値は
  // 操作の終わり（[commitRememberedValues]）にまとめて保存する。
  bool _rememberListDirty = false;
  bool _rememberWorkingDirty = false;

  final List<Brush> _brushes = [];
  final List<BrushFolder> _folders = [];
  Brush? _currentBrush;
  Color _currentColor = const Color(0xFF000000);

  List<Brush> get brushes => List.unmodifiable(_brushes);
  List<BrushFolder> get folders => List.unmodifiable(_folders);
  Brush? get currentBrush => _currentBrush;
  Color get currentColor => _currentColor;

  void setCurrentColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  /// Read-only definitions used for preset-fidelity regression tests.
  static List<Brush> get builtInBrushes => List.unmodifiable(_defaultBrushes());

  static List<Brush> _defaultBrushes() => [
    const Brush(
      id: 'Brush0001',
      name: 'ペン',
      size: 5,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 50,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 20, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.basic],
    ),
    const Brush(
      id: 'Brush0002',
      name: 'Gペン',
      size: 3,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 60,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 10, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 10, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.weak,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.mainLine],
    ),
    const Brush(
      id: 'Brush0003',
      name: 'エアブラシ',
      size: 30,
      opacity: 40,
      spacing: 3,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 30, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 50, strong: 50),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 50),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.paint, AssetTagKeys.blur],
    ),
    const Brush(
      id: 'Brush0004',
      name: '混色ブラシ',
      size: 15,
      opacity: 80,
      spacing: 8,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 40, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 10, strong: 10),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          weakRate: 50,
          strongRate: 50,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 10),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          rate: 50,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.paint, AssetTagKeys.mixing],
    ),
    // マーカーペン：チゼル（斜め切り）先端の太めの半透明ペン先
    // （重ね塗りで色が濃くなる）。calligraphyAngle: 0（ペン先の扁平な
    // 向きを水平に固定）により、横に引くと細く・縦に引くと太くなる
    // 実物のチゼルマーカー特有の見た目を再現する。あわせて、実物の
    // マーカーのようにインクがだんだん掠れて薄くなっていく様子を、
    // ストローク減衰機能（strokeDecay）で表現する。フェルトペンは
    // 筆圧の影響をほぼ受けないため、筆圧反映はOFFにする。
    const Brush(
      id: 'Brush0005',
      name: 'マーカーペン',
      size: 20,
      opacity: 65,
      spacing: 5,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: true, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          weakRate: 15,
          strongRate: 15,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: true, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          rate: 15,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: true,
      calligraphyAngle: 0.0,
      tags: [AssetTagKeys.paint, AssetTagKeys.analog],
    ),
    // カリグラフィー：ペン先の角度を45度に固定した扁平ブラシ
    // （calligraphyAngle）。進行方向によって線の太さが変わる
    // カリグラフィーペン特有の見た目になる。
    const Brush(
      id: 'Brush0006',
      name: 'カリグラフィー',
      size: 14,
      opacity: 100,
      spacing: 4,
      stabilization: true,
      stabilizationStrength: 40,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      calligraphyAngle: 45.0,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.decoration],
    ),
    // ── ここから下は、よくあるイラスト制作ソフトに入っている定番の
    // 描き味を、既存のブラシパラメータの組み合わせで再現したもの。
    // 新しい描画機能は要らず、設定値の妙で作れるものだけを選んである。
    //
    // 鉛筆：芯が紙の凹凸に擦れてふちがざらつく質感を、ふち滲み
    // （edgeJitter）を強めにかけて再現する。筆圧で濃さと太さが同時に
    // 変わるのが実物に近い。
    const Brush(
      id: 'Brush0007',
      name: '鉛筆',
      size: 4,
      opacity: 85,
      spacing: 2,
      stabilization: true,
      stabilizationStrength: 30,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 15, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 15, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: true, weak: 70, strong: 70),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: true, value: 70),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.rough, AssetTagKeys.analog],
    ),
    // 丸ペン：主線用。細く硬く、筆圧で太さがはっきり出る。
    // 手ブレ補正は強めにして、長い曲線を一息で引けるようにする。
    const Brush(
      id: 'Brush0008',
      name: '丸ペン',
      size: 2,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 75,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 5, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.weak,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.mainLine],
    ),
    // 平筆：ペン先を90度に固定した扁平ブラシ。縦に引くと細く・横に引くと
    // 太くなる（カリグラフィーの角度違い）。塗りの面を作るのに向く。
    const Brush(
      id: 'Brush0009',
      name: '平筆',
      size: 26,
      opacity: 90,
      spacing: 3,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 40, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 5, strong: 5),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          weakRate: 25,
          strongRate: 25,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 5),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: true,
          mode: BrushMixingMode.oil,
          rate: 25,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      calligraphyAngle: 90.0,
      tags: [AssetTagKeys.paint, AssetTagKeys.analog],
    ),
    // 水彩：水彩風混色。透明な絵の具が重なるほど深くなり、乾くと縁に
    // 色が溜まり紙の目が出る。濃さは絵具量で決めるので不透明度は100。
    const Brush(
      id: 'Brush0010',
      name: '水彩',
      size: 24,
      opacity: 100,
      spacing: 4,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 25, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 25, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 30, strong: 30),
        edgeJitter: PressureRangeSetting(enabled: true, weak: 40, strong: 40),
        mixing: PressureMixingOnSetting(
          enabled: true,
          mode: BrushMixingMode.watercolor,
          weakRate: 30,
          strongRate: 30,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 30),
        edgeJitter: FixedBrushSetting(enabled: true, value: 40),
        mixing: PressureMixingOffSetting(
          enabled: true,
          mode: BrushMixingMode.watercolor,
          rate: 30,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.paint, AssetTagKeys.mixing, AssetTagKeys.analog],
    ),
    // ぼかし：ぼかし半径を最大近くまで上げ、輪郭を持たない柔らかい影を
    // 置くための筆。頬の赤み・光のにじみなどに。
    const Brush(
      id: 'Brush0011',
      name: 'ぼかし',
      size: 40,
      opacity: 25,
      spacing: 4,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 20, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 90, strong: 90),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 90),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.paint, AssetTagKeys.blur],
    ),
    // チョーク／木炭：粒が散ってざらつく質感。散布（scatter）と密度を
    // 上げ、ふち滲みも最大にして粉っぽさを出す。
    const Brush(
      id: 'Brush0012',
      name: 'チョーク',
      size: 18,
      opacity: 70,
      spacing: 3,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 30, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: true, weak: 100, strong: 100),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: true, value: 100),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      density: 1.8,
      scatter: 0.35,
      tags: [AssetTagKeys.paint, AssetTagKeys.rough, AssetTagKeys.analog],
    ),
    // スプレー（ハイライトの粒・雪・星などの散布用）。間隔を広く取って
    // 粒を独立させ、進行方向へ大きく散らす。
    const Brush(
      id: 'Brush0013',
      name: 'スプレー',
      size: 22,
      opacity: 55,
      spacing: 10,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 40, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 20, strong: 20),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 20),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      density: 2.5,
      scatter: 0.9,
      tags: [AssetTagKeys.effect, AssetTagKeys.blur],
    ),
    // ピクセルペン：ドット絵用。アンチエイリアスの無い硬い1px単位の線に
    // なるよう、ピクセルモードをONにしてぼかしと筆圧を切る。
    const Brush(
      id: 'Brush0014',
      name: 'ピクセルペン',
      size: 3,
      opacity: 100,
      spacing: 1,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: true,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.pixelArt],
    ),
    // 面相筆：入り抜き（fadeMode）を強くかけ、線の始まりと終わりが自然に
    // 細くなる筆。まつ毛・髪の毛先・和風の線に向く。
    const Brush(
      id: 'Brush0015',
      name: '面相筆',
      size: 8,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 55,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 10, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.strong,
      strokeDecay: false,
      tags: [AssetTagKeys.lineArt, AssetTagKeys.taper],
    ),
    // グリッターペン：大きめの輝点を広く散らす装飾用ペン。
    // 粒を独立して見せるため間隔と散布を大きめにし、わずかなぼかしで
    // 強い反射光のようなきらめきを作る。
    const Brush(
      id: 'Brush0016',
      tipShape: BrushTipShape.hexagon,
      name: 'グリッターペン',
      size: 14,
      opacity: 90,
      spacing: 18,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 65, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 0),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      density: 1.2,
      scatter: 0.9,
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
    // ラメペン：グリッターより細かい粒を高密度で線に沿わせるペン。
    // 散布幅を抑え、細かな反射粒が連続してきらめく質感にする。
    const Brush(
      id: 'Brush0017',
      name: 'ラメペン',
      size: 5,
      opacity: 76,
      spacing: 4,
      stabilization: true,
      stabilizationStrength: 20,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 75, strong: 100),
        blur: PressureRangeSetting(enabled: true, weak: 1, strong: 1),
        edgeJitter: PressureRangeSetting(enabled: true, weak: 30, strong: 30),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: true, value: 1),
        edgeJitter: FixedBrushSetting(enabled: true, value: 30),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      density: 2.8,
      scatter: 0.45,
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
    // チェーン（太）：工事・係留用の頑丈な鎖を想定。リンクは肉厚で
    // やや角張った縦長楕円、間隔も詰めて「重量感」と噛み合いを優先する。
    const Brush(
      id: 'Brush0018',
      tipShape: BrushTipShape.chainLink,
      tipSpacingFactor: .68,
      chainAspect: .64,
      chainThickness: .25,
      name: 'チェーン（太）',
      size: 34,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 35,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [
        AssetTagKeys.decoration,
        AssetTagKeys.background,
        AssetTagKeys.clothing,
      ],
    ),
    // チェーン（中）：メンズアクセサリー向け。太よりリンクを細長くし、
    // 肉厚を少し抑えて輪郭がシャープに見えるバランス。
    const Brush(
      id: 'Brush0019',
      tipShape: BrushTipShape.chainLink,
      tipSpacingFactor: .72,
      chainAspect: .56,
      chainThickness: .19,
      name: 'チェーン（中）',
      size: 22,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 40,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
    // チェーン（細）：華奢なネックレス用。小さく細いリンクを高密度に並べる。
    const Brush(
      id: 'Brush0020',
      tipShape: BrushTipShape.chainLink,
      tipSpacingFactor: .76,
      chainAspect: .50,
      chainThickness: .14,
      name: 'チェーン（細）',
      size: 12,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 48,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      rotation: true,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
    // ボールチェーン：小球を等間隔でつなぐ細身の装飾チェーン。
    const Brush(
      id: 'Brush0021',
      tipShape: BrushTipShape.ballChain,
      tipSpacingFactor: 1.35,
      name: 'ボールチェーン',
      size: 7,
      opacity: 100,
      spacing: 1,
      stabilization: true,
      stabilizationStrength: 42,
      pixelMode: false,
      pressureOn: BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      rotation: false,
      density: 1.0,
      scatter: 0,
      tags: [AssetTagKeys.decoration, AssetTagKeys.clothing],
    ),
    ...brushExtensionPresets(),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.readStringList(_prefsKey);
    _brushes.clear();
    _unreadableEntries.clear();
    _readBuiltInWorking(prefs);
    if (raw == null) {
      // 初回起動：初期ブラシ一式を投入して即座に永続化する。
      // 読めない型の値が入っているとき（保存はあるが一覧として読めない）は
      // 既定の内容で動かすだけで、保存は書き換えない（自作のブラシが
      // 入っているかもしれない保存を、起動しただけで消さない）。
      _brushes.addAll(_defaultBrushes().map(_withWorkingValues));
      if (!prefs.containsKey(_prefsKey)) await _persist();
    } else {
      // 1件ずつ読む。壊れた1件（途中で切れた・項目の欠けた保存）で全体を
      // 読めなくすると、起動の初期化が毎回同じ所で失敗して二度と起動
      // できない。読めない分は記録して一覧には出さず、保存には残す
      // （[_unreadableEntries]）。
      var dropped = false;
      final seen = <String>{};
      for (final entry in raw) {
        try {
          final brush = Brush.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          );
          if (!seen.add(brush.id)) {
            dropped = true;
            continue;
          }
          _brushes.add(brush);
        } catch (error, stack) {
          _unreadableEntries.add(entry);
          AppErrorReporter.record(error, stack);
        }
      }
      // 既存ユーザーにも新規追加した初期ブラシ（マーカーペン・カリグラフィー）を
      // 反映する（既に同じIDのブラシが存在する場合は追加しない）。
      final existingIds = _brushes.map((b) => b.id).toSet();
      final missing = _defaultBrushes().where(
        (b) => !existingIds.contains(b.id),
      );
      bool needsPersist = dropped;
      if (missing.isNotEmpty) {
        _brushes.addAll(missing);
        needsPersist = true;
      }
      // Built-in presets are ordinary, non-editable setting bundles. Refresh
      // their definitions uniformly while preserving the user's organization.
      // User-created copies keep all their own settings.
      final defaults = {for (final b in _defaultBrushes()) b.id: b};
      for (var i = 0; i < _brushes.length; i++) {
        final stored = _brushes[i], definition = defaults[_brushes[i].id];
        if (definition == null) continue;
        final current = _withWorkingValues(
          definition.copyWith(
            isFavorite: stored.isFavorite,
            folderId: stored.folderId,
            tags: stored.tags,
          ),
        );
        if (jsonEncode(current.toJson()) != jsonEncode(stored.toJson())) {
          _brushes[i] = current;
          needsPersist = true;
        }
      }
      // 既定タグを日本語リテラルで保存していた版からの移行。
      for (int i = 0; i < _brushes.length; i++) {
        final migrated = migrateLegacyTags(_brushes[i].tags);
        if (!identical(migrated, _brushes[i].tags)) {
          _brushes[i] = _brushes[i].copyWith(tags: migrated);
          needsPersist = true;
        }
      }
      // 組み込みブラシへ後から既定タグを付けたので、保存済みデータにも
      // 反映する。**利用者が自分で付けたタグは絶対に上書きしない**ため、
      // タグが1件も無いものだけを対象にする（タグを意図的に全部外した
      // 状態は「まだ付けていない」と区別できないが、既定タグが戻るだけで
      // 実害が無く、上書きで消してしまう害のほうが大きい）。
      final defaultTags = {
        for (final b in _defaultBrushes())
          if (b.tags.isNotEmpty) b.id: b.tags,
      };
      for (int i = 0; i < _brushes.length; i++) {
        final tags = defaultTags[_brushes[i].id];
        if (tags != null && _brushes[i].tags.isEmpty) {
          _brushes[i] = _brushes[i].copyWith(tags: tags);
          needsPersist = true;
        }
      }
      if (needsPersist) {
        await _persist();
      }
    }
    final foldersRaw = prefs.readStringList(_foldersKey);
    _folders.clear();
    _unreadableFolderEntries.clear();
    if (foldersRaw != null) {
      for (final entry in foldersRaw) {
        try {
          _folders.add(
            BrushFolder.fromJson(jsonDecode(entry) as Map<String, dynamic>),
          );
        } catch (error, stack) {
          _unreadableFolderEntries.add(entry);
          AppErrorReporter.record(error, stack);
        }
      }
    }
    final currentId = prefs.readString(_currentIdKey);
    _currentBrush =
        _brushes.where((b) => b.id == currentId).firstOrNull ??
        _brushes.firstOrNull;
    _preloadTextureIfNeeded(_currentBrush);
  }

  /// 自作ブラシ画像（[Brush.customImagePath]）を事前デコードしてキャッシュへ
  /// 入れる。DrawingEngineの描画ホットパスは同期処理のため、実際に描画する
  /// 前（選択時・作成時・復元時）に済ませておく必要がある（失敗しても
  /// キャッシュが空のままフォールバックされるだけなので待たない）。
  void _preloadTextureIfNeeded(Brush? brush) {
    final paths = brush?.resolvedCustomImagePaths ?? const <String>[];
    if (paths.isNotEmpty) {
      // ignore: unawaited_futures
      preloadBrushTextures(paths, mode: brush!.imageInkMode);
    }
  }

  Future<void> _persist() async {
    final working = _rememberWorkingDirty;
    _rememberListDirty = false;
    _rememberWorkingDirty = false;
    if (working) await _persistBuiltInWorking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, [
      for (final brush in _brushes) jsonEncode(brush.toJson()),
      ..._unreadableEntries,
    ]);
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, [
      for (final folder in _folders) jsonEncode(folder.toJson()),
      ..._unreadableFolderEntries,
    ]);
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _currentBrush?.id;
    if (id == null) {
      await prefs.remove(_currentIdKey);
    } else {
      await prefs.setString(_currentIdKey, id);
    }
  }

  void selectBrush(String id) {
    final brush = _brushes.where((b) => b.id == id).firstOrNull;
    if (brush == null) return;
    // ignore: unawaited_futures
    commitRememberedValues();
    _currentBrush = brush;
    _preloadTextureIfNeeded(_currentBrush);
    notifyListeners();
    _persistCurrent();
  }

  /// 使っているブラシの太さを変える。
  ///
  /// [remember]が真（キャンバスのスライダー・数値入力）なら、その値を
  /// ブラシごとに覚える：別のブラシへ切り替えて戻っても、起動し直しても
  /// 同じ太さで、一覧にも出る。早替えツールや自動操作の再生のように
  /// 一時的に太さを当てるだけのときは偽にする（そのブラシで覚えている
  /// 値は書き換えない）。
  void updateCurrentBrushSize(double size, {bool remember = true}) {
    final current = _currentBrush;
    if (current == null || !size.isFinite || size <= 0) return;
    _currentBrush = current.copyWith(size: size);
    if (remember) _rememberWorkingValues(current.id, size: size);
    notifyListeners();
  }

  /// 使っているブラシの不透明度を変える。[remember]は
  /// [updateCurrentBrushSize]と同じ。
  void updateCurrentBrushOpacity(int opacity, {bool remember = true}) {
    final current = _currentBrush;
    if (current == null) return;
    final value = opacity.clamp(0, 100);
    _currentBrush = current.copyWith(opacity: value);
    if (remember) _rememberWorkingValues(current.id, opacity: value);
    notifyListeners();
  }

  void _rememberWorkingValues(String id, {double? size, int? opacity}) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    // 太さ・不透明度だけを書く（使っているブラシの写しを丸ごと書き戻すと、
    // 一覧の側で変えたお気に入り・タグ・フォルダを古い値で上書きする）。
    _brushes[idx] = _brushes[idx].copyWith(size: size, opacity: opacity);
    _rememberListDirty = true;
    final definition = _builtInDefinitions[id];
    if (definition == null) return;
    // 組み込みブラシは、定義と違う値だけを覚える。定義と同じ値へ戻した
    // 項目は覚えから外し、後の版で既定が変わればそれに従う。
    final before = _builtInWorking[id];
    final keptSize = size ?? before?.size;
    final keptOpacity = opacity ?? before?.opacity;
    final next = (
      size: keptSize == definition.size ? null : keptSize,
      opacity: keptOpacity == definition.opacity ? null : keptOpacity,
    );
    if (next.size == null && next.opacity == null) {
      if (_builtInWorking.remove(id) != null) _rememberWorkingDirty = true;
    } else if (next != before) {
      _builtInWorking[id] = next;
      _rememberWorkingDirty = true;
    }
  }

  /// 組み込みブラシに、利用者が変えて覚えている太さ・不透明度があるか。
  bool hasRememberedBuiltInValues(String id) => _builtInWorking.containsKey(id);

  /// 組み込みブラシの太さ・不透明度を定義の値（既定）へ戻し、覚えを消す。
  void resetRememberedBuiltInValues(String id) {
    final definition = _builtInDefinitions[id];
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (definition == null || idx < 0) return;
    if (_builtInWorking.remove(id) != null) _rememberWorkingDirty = true;
    _brushes[idx] = _brushes[idx].copyWith(
      size: definition.size,
      opacity: definition.opacity,
    );
    if (_currentBrush?.id == id) {
      _currentBrush = _currentBrush!.copyWith(
        size: definition.size,
        opacity: definition.opacity,
      );
    }
    notifyListeners();
    _persist();
  }

  /// 覚えた太さ・不透明度のうち、まだ保存していない分を保存する。
  ///
  /// スライダーを離したとき・数字を打ったとき・±を押したときに画面が呼ぶ。
  /// 呼び忘れても失わないよう、ブラシの切り替え・アプリが裏へ回るとき・
  /// 破棄のときにも呼ぶ。
  Future<void> commitRememberedValues() async {
    if (!_rememberListDirty && !_rememberWorkingDirty) return;
    await _persist();
  }

  Brush _withWorkingValues(Brush brush) {
    final kept = _builtInWorking[brush.id];
    if (kept == null) return brush;
    return brush.copyWith(size: kept.size, opacity: kept.opacity);
  }

  /// 保存してある組み込みブラシの太さ・不透明度を読む。読めない保存
  /// （壊れた文字列・数でない値・今は無いブラシ）は使わない。起動は止めず、
  /// 保存も書き換えない（覚えた値を次に変えたときに、読めた分だけで保存
  /// し直される）。
  void _readBuiltInWorking(SharedPreferences prefs) {
    _builtInWorking.clear();
    final raw = prefs.readString(_builtInWorkingKey);
    if (raw == null) return;
    try {
      _builtInWorking.addAll(_builtInWorkingFrom(jsonDecode(raw)));
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      _builtInWorking.clear();
    }
  }

  /// 覚えた太さ・不透明度の保存の形（[_builtInWorkingJson]）から読む。
  /// 今は無いブラシ・数でない値は使わない。全体が読めなければ投げる。
  Map<String, ({double? size, int? opacity})> _builtInWorkingFrom(
    Object? decoded,
  ) {
    if (decoded is! Map) throw const FormatException('not a map');
    final result = <String, ({double? size, int? opacity})>{};
    for (final entry in decoded.entries) {
      final id = entry.key;
      final value = entry.value;
      if (id is! String || !isBuiltIn(id) || value is! Map) continue;
      final rawSize = value['size'];
      final rawOpacity = value['opacity'];
      final size = rawSize is num && rawSize.isFinite && rawSize > 0
          ? rawSize.toDouble()
          : null;
      final opacity = rawOpacity is num && rawOpacity.isFinite
          ? rawOpacity.round().clamp(0, 100)
          : null;
      if (size == null && opacity == null) continue;
      result[id] = (size: size, opacity: opacity);
    }
    return result;
  }

  Map<String, Map<String, num>> _builtInWorkingJson() => {
    for (final entry in _builtInWorking.entries)
      entry.key: {
        if (entry.value.size != null) 'size': entry.value.size!,
        if (entry.value.opacity != null) 'opacity': entry.value.opacity!,
      },
  };

  /// 組み込みブラシで覚えている太さ・不透明度（保存と同じ形）。引き継ぎの
  /// 書き出しに使う。
  Map<String, Map<String, num>> rememberedBuiltInValuesForTransfer() =>
      _builtInWorkingJson();

  Future<void> _persistBuiltInWorking() async {
    final prefs = await SharedPreferences.getInstance();
    if (_builtInWorking.isEmpty) {
      await prefs.remove(_builtInWorkingKey);
      return;
    }
    await prefs.setString(
      _builtInWorkingKey,
      jsonEncode(_builtInWorkingJson()),
    );
  }

  @override
  void dispose() {
    // まだ保存していない覚えを落とさない。
    // ignore: unawaited_futures
    commitRememberedValues();
    super.dispose();
  }

  // プリインストールされている初期実装ブラシ（_defaultBrushes()の6件）は
  // 編集・削除の対象外とする（複製したものは対象外の複製元とは別IDになる
  // ため、複製後の編集・削除は可能）。
  static final Map<String, Brush> _builtInDefinitions = {
    for (final brush in _defaultBrushes()) brush.id: brush,
  };

  bool isBuiltIn(String id) => _builtInDefinitions.containsKey(id);

  void addBrush(Brush brush) {
    _brushes.add(brush);
    _preloadTextureIfNeeded(brush);
    notifyListeners();
    _persist();
  }

  /// 引き継ぎ（.niatra）で受け取ったブラシとフォルダを、この端末の一覧へ
  /// 合わせて保存する。この端末の内容は黙って失わない（決まりは
  /// [mergeTransferredItems]）：
  /// - 組み込みブラシは足さず、中身はこの版の定義のまま。お気に入り・タグ・
  ///   フォルダだけを合わせる。覚えた太さ・不透明度はこの端末で覚えている
  ///   値を残し、覚えていない項目だけ受け取った値にする（受け取った値は
  ///   [rememberedBuiltInValues]〔元の端末の保存と同じ形〕から、それが無い
  ///   古いファイルでは、受け取ったブラシの値のうち定義と違うもの）。
  /// - 自作のブラシは、同じIDで中身が違えばこの端末のブラシを残し、受け取った
  ///   ブラシを「名前 (コピー)」として足す。太さ・不透明度（キャンバスで
  ///   変えて覚える値）は同じIDのブラシの違いには数えず、この端末の値のまま
  ///   （前に足した複製で変えた値も同じ）。この端末に無いIDのブラシは、
  ///   太さ・不透明度まで同じブラシが読み込む前からあるときだけ足さない
  ///   （もう1台で複製して太さだけを変えたブラシも届く）。ただし前の
  ///   読み込みでそのブラシの中身を持ったこの端末のブラシは、太さ・
  ///   不透明度が違っても同じブラシ（[TransferCopyRecord.holdersOf]）。
  /// - フォルダは無いものだけ足す（同じIDはこの端末の名前のまま）。行き先の
  ///   フォルダがこの端末に無いブラシはフォルダなし。
  /// - 画像を受け取れなかったブラシは、同じIDのブラシがこの端末で使っている
  ///   画像があればそれを使う。画像は置いた場所ではなく中身で比べる。
  /// - 同じ中身が既にあって足さなかったブラシのお気に入り・タグ・フォルダは、
  ///   そのブラシへ合わせる。
  /// - [currentBrushId]（元の端末で使っていたブラシ）は、そのブラシの中身を
  ///   持つことになったこの端末のブラシを、合わせた後の一覧にあるときだけ
  ///   選ぶ。
  /// [placed]には、受け取ったブラシのIDごとに、合わせた後でその中身を持つ
  /// この端末のブラシのIDを書く（早替えツール・ショートカットなどが指す
  /// ブラシを合わせるため。[transferredBrushId]）。
  /// 変えた一覧だけを保存する。
  Future<void> mergeTransferred(
    List<Brush> incoming, {
    required TransferCopyNames copyNames,
    List<BrushFolder> folders = const [],
    Object? rememberedBuiltInValues,
    String? currentBrushId,
    Map<String, String>? placed,
  }) async {
    var foldersChanged = false;
    for (final folder in folders) {
      if (_folders.any((f) => f.id == folder.id)) continue;
      _folders.add(folder);
      foldersChanged = true;
    }
    final folderIds = {for (final f in _folders) f.id};

    Map<String, ({double? size, int? opacity})>? remembered;
    if (rememberedBuiltInValues != null) {
      try {
        remembered = _builtInWorkingFrom(rememberedBuiltInValues);
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }

    final resolved = <Brush>[];
    var workingChanged = false;
    for (final brush in incoming) {
      final definition = _builtInDefinitions[brush.id];
      if (definition != null) {
        final theirs = remembered != null
            ? remembered[brush.id]
            : _differenceFromDefinition(definition, brush);
        final mine = _builtInWorking[brush.id];
        final next = (
          size: mine?.size ?? theirs?.size,
          opacity: mine?.opacity ?? theirs?.opacity,
        );
        if (next != mine && (next.size != null || next.opacity != null)) {
          _builtInWorking[brush.id] = next;
          workingChanged = true;
        }
      }
      final local = _brushes.where((b) => b.id == brush.id).firstOrNull;
      final json = brush.toJson();
      if (!folderIds.contains(brush.folderId)) json['folderId'] = null;
      if (local != null &&
          !_hasImageFile(brush) &&
          _hasImageFile(local) &&
          definition == null) {
        json['customImagePath'] = local.customImagePath;
        json['customImagePaths'] = local.customImagePaths;
      }
      resolved.add(Brush.fromJson(json));
    }

    final before = List<Brush>.of(_brushes);
    // 画像は置いた場所ではなく中身で比べる。
    final images = await TransferImageDigests.read([
      for (final b in [..._brushes, ...resolved]) ...b.resolvedCustomImagePaths,
    ]);
    Map<String, dynamic> withoutOrganization(Brush b) => b.toJson()
      ..remove('id')
      ..remove('name')
      ..remove('isFavorite')
      ..remove('tags')
      ..remove('folderId')
      ..remove('customImagePath')
      ..remove('customImagePaths')
      ..['images'] = [
        for (final path in b.resolvedCustomImagePaths) images.of(path),
      ];
    final where = placed ?? <String, String>{};
    // 前の読み込みでもう1台の版を足した複製（足した後でこの端末で太さ・
    // 不透明度・名前を変えた複製を、この端末で作った自分の複製と取り違えずに
    // 見つける）。
    final copies = await TransferCopyRecord.read(TransferCopyRecord.brushes);
    final listChanged = mergeTransferredItems(
      _brushes,
      resolved,
      TransferMergeRules<Brush>(
        idOf: (b) => b.id,
        nameOf: (b) => b.name,
        // 太さ・不透明度はキャンバスで変えるたびに覚える値（組み込みの
        // ブラシの覚えた値と同じ）で、同じブラシの違いには数えない
        // （この端末の値のまま）。
        contentOf: (b) => withoutOrganization(b)
          ..remove('size')
          ..remove('opacity'),
        // 別のIDのブラシは、太さ・不透明度だけを変えた複製も別のブラシ。
        duplicateContentOf: withoutOrganization,
        organizationOf: (b) =>
            (favorite: b.isFavorite, tags: b.tags, folderId: b.folderId),
        withOrganization: (b, o) => Brush.fromJson({
          ...b.toJson(),
          'isFavorite': o.favorite,
          'tags': o.tags,
          'folderId': o.folderId,
        }),
        asCopy: (b, id, name) =>
            Brush.fromJson({...b.toJson(), 'id': id, 'name': name}),
        newId: (attempt) =>
            'Brush${DateTime.now().microsecondsSinceEpoch}_$attempt',
        copyNames: copyNames,
        shippedOf: (id) => _builtInDefinitions[id],
        organizationOnly: isBuiltIn,
      ),
      placed: where,
      copies: copies,
    );
    await copies.save();
    if (workingChanged) {
      for (var i = 0; i < _brushes.length; i++) {
        if (isBuiltIn(_brushes[i].id)) {
          _brushes[i] = _withWorkingValues(_brushes[i]);
        }
      }
    }

    // 使っているブラシの一覧の項目が変わったら、写しをそろえる。
    final current = _currentBrush;
    var currentChanged = false;
    if (current != null) {
      final now = _brushes.where((b) => b.id == current.id).firstOrNull;
      final was = before.where((b) => b.id == current.id).firstOrNull;
      if (now != null && !identical(now, was)) {
        _currentBrush = now;
        _preloadTextureIfNeeded(now);
      }
    }
    final chosenId = transferredBrushId(currentBrushId, where);
    final chosen = _brushes.where((b) => b.id == chosenId).firstOrNull;
    if (chosen != null && chosen.id != _currentBrush?.id) {
      _currentBrush = chosen;
      _preloadTextureIfNeeded(chosen);
      currentChanged = true;
    }

    if (!listChanged && !workingChanged && !foldersChanged && !currentChanged) {
      return;
    }
    _rememberWorkingDirty = _rememberWorkingDirty || workingChanged;
    notifyListeners();
    if (foldersChanged) await _persistFolders();
    if (currentChanged) await _persistCurrent();
    if (listChanged || workingChanged) await _persist();
  }

  /// 画像を使うブラシで、その画像のファイルがこの端末にあるか。
  static bool _hasImageFile(Brush brush) {
    final paths = brush.resolvedCustomImagePaths;
    if (paths.isEmpty) return false;
    try {
      return paths.every((path) => File(path).existsSync());
    } on UnsupportedError {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  /// 受け取った組み込みブラシの太さ・不透明度のうち、定義と違うもの。
  ({double? size, int? opacity})? _differenceFromDefinition(
    Brush definition,
    Brush brush,
  ) {
    final size = brush.size.isFinite && brush.size > 0
        ? brush.size
        : definition.size;
    final opacity = brush.opacity.clamp(0, 100);
    final kept = (
      size: size == definition.size ? null : size,
      opacity: opacity == definition.opacity ? null : opacity,
    );
    return kept.size == null && kept.opacity == null ? null : kept;
  }

  /// [id]のブラシを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool deleteBrush(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx < 0) return false;
    if (_brushes[idx].isFavorite) return false;
    _brushes.removeAt(idx);
    // 使っていたブラシを消したら、隣のブラシへ移る（消したブラシで
    // 描き続け、一覧ではどれも選ばれていない状態にしない）。
    if (_currentBrush?.id == id) {
      _currentBrush = _brushes.isEmpty
          ? null
          : _brushes[idx.clamp(0, _brushes.length - 1)];
      _preloadTextureIfNeeded(_currentBrush);
      _persistCurrent();
    }
    notifyListeners();
    _persist();
    return true;
  }

  /// [id]のブラシを複製して一覧の最後に足し、新しいIDを返す。名前は
  /// [name]（画面が「名前 (コピー 2)」のように言語と番号を付けて渡す）。
  /// 省略すると日本語の形で、複製の複製も元の名前に番号を付ける
  /// （[fallbackCopyName]）。
  String? duplicateBrush(String id, {String? name}) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx < 0) return null;
    final brush = _brushes[idx];
    var newId = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    while (_brushes.any((b) => b.id == newId)) {
      newId = '${newId}_';
    }
    _brushes.add(
      brush.copyWith(
        id: newId,
        name:
            name ??
            fallbackCopyName(brush.name, [for (final b in _brushes) b.name]),
      ),
    );
    notifyListeners();
    _persist();
    return newId;
  }

  /// ブラシへ分類用タグを設定する（既存のタグ列を置き換える）。
  ///
  /// お気に入りと同様、**組み込みブラシにも付けられる**。編集・削除は
  /// できなくても「どう分類したいか」は利用者の都合であり、そこを縛ると
  /// タグ機能がほとんど使えなくなるため（`updateXxx`のような
  /// `isBuiltIn`ガードは意図的に置いていない）。
  void setTags(String id, List<String> tags) {
    final idx = _brushes.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _brushes[idx] = _brushes[idx].copyWith(tags: normalizeTags(tags));
    notifyListeners();
    _persist();
  }

  /// 登録されている全タグを、使われている件数の多い順（同数なら名前順）で
  /// 返す。タグ検索の候補チップに使う。表記ゆれで別タグ扱いにならないよう、
  /// 大文字小文字を無視して数え、代表表記は最初に見つかったものを使う。
  List<String> allTags() {
    final count = <String, int>{};
    final display = <String, String>{};
    for (final e in _brushes) {
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

  void toggleFavoriteBrush(String id) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _brushes[idx] = _brushes[idx].copyWith(
        isFavorite: !_brushes[idx].isFavorite,
      );
      notifyListeners();
      _persist();
    }
  }

  void reorderBrush(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final brush = _brushes.removeAt(oldIndex);
    _brushes.insert(newIndex, brush);
    notifyListeners();
    _persist();
  }

  void updateBrush(Brush brush) {
    if (isBuiltIn(brush.id)) return;
    final idx = _brushes.indexWhere((b) => b.id == brush.id);
    if (idx >= 0) {
      _brushes[idx] = brush;
      if (_currentBrush?.id == brush.id) _currentBrush = brush;
      _preloadTextureIfNeeded(brush);
      notifyListeners();
      _persist();
    }
  }

  // ─── フォルダ管理 ─────────────────────────────────────────────────────

  Future<BrushFolder> createFolder(String name) async {
    final folder = BrushFolder(
      id: 'BrushFolder${DateTime.now().millisecondsSinceEpoch}',
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

  /// フォルダを削除する。中の素材はルート（フォルダなし）へ戻す。
  void deleteFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    for (int i = 0; i < _brushes.length; i++) {
      if (_brushes[i].folderId == id) {
        _brushes[i] = _brushes[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
    _persistFolders();
    _persist();
  }

  void moveToFolder(String brushId, String? folderId) {
    final idx = _brushes.indexWhere((b) => b.id == brushId);
    if (idx < 0) return;
    _brushes[idx] = _brushes[idx].copyWith(folderId: folderId);
    notifyListeners();
    _persist();
  }

  // ─── 自作ブラシ（画像からの新規作成） ────────────────────────────────────

  Future<Directory> _brushesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Brushes');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copy user-selected materials into the brush storage before saving paths.
  Future<List<String>> importBrushImages(Iterable<String> sourcePaths) async {
    final directory = await _brushesDir();
    final prefix = DateTime.now().microsecondsSinceEpoch;
    final result = <String>[];
    for (final source in sourcePaths) {
      final extension = source
          .split('.')
          .last
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final destination =
          '${directory.path}/material_${prefix}_${result.length}.$extension';
      await File(source).copy(destination);
      result.add(destination);
    }
    return result;
  }

  /// [sourcePath]の画像ファイルを取り込み、新規ブラシとして追加する。
  Future<Brush> createBrushFromImage(String sourcePath, {String? name}) async {
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _brushesDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final brush = Brush(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作ブラシ',
      size: 10,
      opacity: 100,
      spacing: 10,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      pressureOn: const BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 20, strong: 100),
        opacity: PressureRangeSetting(enabled: false, weak: 50, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 50),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          weakRate: 0,
          strongRate: 0,
        ),
      ),
      pressureOff: const BrushPressureOffSettings(
        blur: FixedBrushSetting(enabled: false, value: 0),
        edgeJitter: FixedBrushSetting(enabled: false, value: 50),
        mixing: PressureMixingOffSetting(
          enabled: false,
          mode: BrushMixingMode.oil,
          rate: 0,
        ),
      ),
      fadeMode: FadeMode.off,
      strokeDecay: false,
      customImagePath: destPath,
    );
    addBrush(brush);
    return brush;
  }

  // ─── QR共有（画像を使わないブラシの全設定） ────────────────────────
  static const brushQrPrefix = 'niarim:brush:v1:';

  // QR v1 compact schema: preserve every model field while replacing verbose
  // (nested) JSON object keys with positional arrays. Both sides use the
  // built-in Brush.toJson schema from this app version. A future incompatible
  // schema change must bump brushQrPrefix, not silently reinterpret a QR.
  static Object? _packBrushQr(Object? value, Object? schema) {
    if (schema is Map && value is Map) {
      return [
        for (final key in schema.keys) _packBrushQr(value[key], schema[key]),
      ];
    }
    return value;
  }

  static Object? _unpackBrushQr(Object? value, Object? schema) {
    if (schema is Map) {
      if (value is! List || value.length != schema.length) {
        throw const FormatException('Brush QR schema mismatch');
      }
      final result = <String, dynamic>{};
      var index = 0;
      for (final entry in schema.entries) {
        result[entry.key.toString()] = _unpackBrushQr(
          value[index++],
          entry.value,
        );
      }
      return result;
    }
    return value;
  }

  /// Returns null for custom-image brushes or payloads too dense to scan.
  /// ZIP-style file export remains the lossless route for all brushes.
  String? exportBrushQrPayload(String id, {int maxChars = 900}) {
    final brush = _brushes.firstWhere((b) => b.id == id);
    if (brush.resolvedCustomImagePaths.isNotEmpty) return null;
    final data = Map<String, dynamic>.from(brush.toJson())
      ..['id'] = ''
      ..['folderId'] = null
      ..['isFavorite'] = false
      ..['customImagePath'] = null
      ..['customImagePaths'] = <String>[];
    final schema = _builtInDefinitions.values.first.toJson();
    final compact = _packBrushQr(data, schema);
    final packed = base64UrlEncode(
      gzip.encode(utf8.encode(jsonEncode(compact))),
    );
    final payload = '$brushQrPrefix$packed';
    return payload.length <= maxChars ? payload : null;
  }

  /// Decode a versioned QR string and install a new editable brush. Never
  /// trust device-specific paths or IDs included in imported JSON.
  Brush importBrushQrPayload(String payload) {
    final text = payload.trim();
    if (!text.startsWith(brushQrPrefix) || text.length > 900) {
      throw const FormatException('Unsupported brush QR payload');
    }
    final compressed = base64Url.decode(text.substring(brushQrPrefix.length));
    final bytes = gzip.decode(compressed);
    if (bytes.length > 32768) {
      throw const FormatException('Brush QR data too large');
    }
    final schema = _builtInDefinitions.values.first.toJson();
    final decoded = _unpackBrushQr(jsonDecode(utf8.decode(bytes)), schema);
    if (decoded is! Map<String, dynamic> ||
        decoded['customImagePath'] != null ||
        (decoded['customImagePaths'] is List &&
            (decoded['customImagePaths'] as List).isNotEmpty)) {
      throw const FormatException('Brush QR data is invalid');
    }
    final incoming = Brush.fromJson(decoded);
    var id = 'Brush${DateTime.now().microsecondsSinceEpoch}';
    while (_brushes.any((b) => b.id == id)) {
      id = '${id}_';
    }
    final imported = Brush.fromJson(
      Map<String, dynamic>.from(incoming.toJson())
        ..['id'] = id
        ..['folderId'] = null
        ..['isFavorite'] = false
        ..['customImagePath'] = null
        ..['customImagePaths'] = <String>[],
    );
    addBrush(imported);
    return imported;
  }

  // ─── 読み込み・書き出し（個別ファイル単位） ──────────────────────────────

  static const _bundleDataFile = 'data.json';

  /// ブラシ1件を`.niabrush`ファイル（ZIP：data.json＋カスタム画像）として
  /// 書き出す。共有シートで送るためのFileを返す。
  Future<File> exportBrush(String id) async {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = brush.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return exportBrushToPath(id, '${base.path}/$safeName.niabrush');
  }

  /// [exportBrush]と同じproduction archiveを明示した保存先へ書き出す。
  /// テストではpath_providerを介さず実`.niabrush`をround-tripできる。
  Future<File> exportBrushToPath(String id, String filePath) async {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
      ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(brush.toJson()))),
    );
    final imagePaths = brush.resolvedCustomImagePaths;
    for (var index = 0; index < imagePaths.length; index++) {
      final imagePath = imagePaths[index];
      if (!File(imagePath).existsSync()) continue;
      final bytes = await File(imagePath).readAsBytes();
      final ext = imagePath.split('.').last;
      final name = 'images/${index.toString().padLeft(3, '0')}.$ext';
      encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  /// `.niabrush`ファイルを読み込み、新規ブラシとして追加する。
  Future<Brush> importBrushFile(
    String filePath, {
    String? imagesDirectory,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final imported = Brush.fromJson(json);
    final id = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    final variantFiles =
        archive.files
            .where((f) => f.isFile && f.name.startsWith('images/'))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final legacyImageFile = archive.files
        .where((f) => f.isFile && f.name.startsWith('image.'))
        .firstOrNull;
    final imageFiles = variantFiles.isNotEmpty
        ? variantFiles
        : <ArchiveFile>[?legacyImageFile];
    final newImagePaths = <String>[];
    if (imageFiles.isNotEmpty) {
      final dir = imagesDirectory == null
          ? await _brushesDir()
          : (Directory(imagesDirectory)..createSync(recursive: true));
      for (var index = 0; index < imageFiles.length; index++) {
        final imageFile = imageFiles[index];
        final ext = imageFile.name.split('.').last;
        final suffix = imageFiles.length == 1
            ? ''
            : '_${index.toString().padLeft(3, '0')}';
        final newImagePath = '${dir.path}/$id$suffix.$ext';
        await File(newImagePath).writeAsBytes(imageFile.content as List<int>);
        newImagePaths.add(newImagePath);
      }
    }
    // 元端末固有のID・フォルダ・画像パスだけ差し替え、それ以外の
    // rotation/density/scatter/fade/edgeJitter/pixelColor等は全て保持する。
    final restoredJson = Map<String, dynamic>.from(imported.toJson())
      ..['id'] = id
      ..['folderId'] = null
      ..['customImagePath'] = newImagePaths.length == 1
          ? newImagePaths.first
          : null
      ..['customImagePaths'] = newImagePaths;
    final brush = Brush.fromJson(restoredJson);
    addBrush(brush);
    return brush;
  }
}

class BrushFolder {
  final String id;
  final String name;
  final bool isFavorite;

  BrushFolder({required this.id, required this.name, this.isFavorite = false});

  BrushFolder copyWith({String? name, bool? isFavorite}) => BrushFolder(
    id: id,
    name: name ?? this.name,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isFavorite': isFavorite,
  };

  factory BrushFolder.fromJson(Map<String, dynamic> j) => BrushFolder(
    id: j['id'] as String,
    name: j['name'] as String,
    isFavorite: j['isFavorite'] as bool? ?? false,
  );
}
