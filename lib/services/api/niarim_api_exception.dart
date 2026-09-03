/// 作品広場バックエンドの呼び出しが失敗したことを表す例外。
///
/// バックエンド（`backend/src/lib/response.ts`）は失敗時に
/// `{"error": "...", "code": "..."}` というJSONを返す。[code]はサーバーが
/// 付けた機械可読な識別子（`UNAUTHORIZED`・`VIDEO_NOT_FOUND`・
/// `DAILY_LIMIT_EXCEEDED`等）で、UI側の出し分けに使う。付いていない場合は
/// nullになる。
class NiarimApiException implements Exception {
  /// HTTPステータスコード。通信自体が成立しなかった場合は0。
  final int statusCode;

  /// 表示・ログ用のメッセージ（サーバーの`error`フィールド、または
  /// 通信エラーの内容）。
  final String message;

  /// サーバーが付けた機械可読なコード（無い場合はnull）。
  final String? code;

  const NiarimApiException(this.statusCode, this.message, {this.code});

  /// 通信自体が成立しなかった（圏外・タイムアウト・DNS失敗等）。
  const NiarimApiException.network(this.message)
    : statusCode = 0,
      code = 'NETWORK';

  /// 通信レイヤーの失敗（サーバーからの応答が無い）かどうか。
  /// 「時間をおいて再試行してください」といった案内の出し分けに使う。
  bool get isNetworkError => statusCode == 0;

  /// ログインが必要／IDトークンが失効している。
  bool get isUnauthorized => statusCode == 401;

  /// 権限が無い（他人の作品を消そうとした等）。
  bool get isForbidden => statusCode == 403;

  /// 対象が存在しない。
  bool get isNotFound => statusCode == 404;

  /// 投稿上限・通報レート制限等に引っかかった。
  bool get isRateLimited => statusCode == 429;

  /// サーバー側の障害。時間をおけば直る可能性がある。
  bool get isServerError => statusCode >= 500;

  @override
  String toString() =>
      'NiarimApiException($statusCode${code == null ? '' : ' $code'}): $message';
}
