/// 広告表示・アプリ内課金の有効化タイミングを一元管理する。
///
/// 税務上の都合により、指定日時（端末のローカル時刻基準）より前は
/// 広告SDK（AdMob）の初期化・表示、およびアプリ内課金（in_app_purchase）
/// のストア接続・購入操作を一切行わない。この間は「リリース記念
/// キャンペーン」として、全ユーザーへプレミアム機能を無料で開放する
/// （エンドカード・書き出し時間制限等の無料版の機能制限も含めて解除
/// される。PremiumService.isPremiumを参照）。金銭のやり取りは一切
/// 発生しないため税務上の位置づけは変わらない。詳細はPremiumServiceの
/// クラスコメントを参照。
///
/// 有効化後は本ファイルを削除し、AdvertisingService・PremiumService・
/// PremiumScreenから参照を外すこと。
final DateTime kMonetizationEnabledFrom = DateTime(2027, 1, 1);

bool get isMonetizationEnabled => !DateTime.now().isBefore(kMonetizationEnabledFrom);
