/// 広告表示・アプリ内課金の有効化タイミングを一元管理する。
///
/// 税務上の都合により、指定日時（端末のローカル時刻基準）より前は
/// 広告SDK（AdMob）の初期化・表示、およびアプリ内課金（in_app_purchase）
/// のストア接続・購入操作を一切行わない。無料版の機能制限
/// （エンドカード・書き出し時間制限等）自体は通常通り有効なままとする
/// （課金導線のみを停止する）。
///
/// 有効化後は本ファイルを削除し、AdvertisingService・PremiumService・
/// PremiumScreenから参照を外すこと。
final DateTime kMonetizationEnabledFrom = DateTime(2027, 1, 1);

bool get isMonetizationEnabled => !DateTime.now().isBefore(kMonetizationEnabledFrom);
