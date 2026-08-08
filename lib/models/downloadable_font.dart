import 'dart:convert';
import 'package:flutter/services.dart';

/// テキストツール用の「追加フリーフォント」カタログ（オンデマンド
/// ダウンロード方式。仕様書15）。
///
/// Google Fonts配布分（SIL Open Font License / Apache License 2.0 /
/// Ubuntu Font License、いずれも個人・商用問わず無償で利用可能）の
/// 全ファミリー（約2000書体）を対象とする。初期インストール容量を
/// 抑えるため実体（TTF/OTF）はアプリに同梱せず、カタログ情報
/// （フォント名・ダウンロードURL等のテキストデータのみ）を
/// `assets/font_catalog/font_catalog.json`としてアプリに同梱し、
/// 選んだフォントだけをGitHub上のgoogle/fontsリポジトリ（OFL等の
/// 配布元そのもの）から取得する。ダウンロード後はFontService.
/// importBundledFont()経由でユーザーフォントと同じ仕組みで端末内に
/// 保存・登録されるため、以降はオフラインでも利用できる
/// （再ダウンロードは不要）。
class DownloadableFontEntry {
  /// FontService内で安定的に使うID（FontAsset.id・フォントファミリー名の
  /// 元になるため、後から変更しないこと）。カタログ生成スクリプト
  /// （scripts/build_font_catalog.py）で"dlfont_<ディレクトリ名>"の
  /// 形式で採番している。
  final String id;
  final String displayName;
  final String fileName;
  final String sourceUrl;

  /// Google Fontsのカテゴリ分類（原文英語）。
  /// SANS_SERIF / SERIF / DISPLAY / HANDWRITING / MONOSPACE。
  final String category;
  final String license;

  const DownloadableFontEntry({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sourceUrl,
    required this.category,
    required this.license,
  });

  factory DownloadableFontEntry.fromJson(Map<String, dynamic> j) => DownloadableFontEntry(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        fileName: j['fileName'] as String,
        sourceUrl: j['sourceUrl'] as String,
        category: j['category'] as String? ?? 'SANS_SERIF',
        license: j['license'] as String? ?? 'SIL Open Font License 1.1',
      );
}

/// カテゴリ（原文英語）→フィルターチップ表示用の日本語ラベル。
const kFontCategoryLabels = {
  'SANS_SERIF': 'ゴシック',
  'SERIF': '明朝・セリフ',
  'DISPLAY': '装飾',
  'HANDWRITING': '手書き風',
  'MONOSPACE': '等幅',
};

/// `assets/font_catalog/font_catalog.json`を読み込み、
/// [DownloadableFontEntry]のリストとして返す。
Future<List<DownloadableFontEntry>> loadDownloadableFontCatalog() async {
  try {
    final raw = await rootBundle.loadString('assets/font_catalog/font_catalog.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DownloadableFontEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
}
