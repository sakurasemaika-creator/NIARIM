# リリースビルドのAPK容量削減（R8による未使用コード除去・難読化）向けの
# 追加keepルール（仕様書01：低スペック端末対応）。
#
# FlutterのDartコード自体はAOTコンパイルされたネイティブコードであり、
# ここでのR8処理（Java/Kotlinバイトコードのみが対象）の影響を受けない。
# そのためアプリの見た目・機能はこの設定変更では変わらない。対象は
# プラグインのAndroid側実装（Java/Kotlinのグルーコード）のみ。
#
# 主要プラグインの多くはAAR内にconsumer-proguard-rules.txtを同梱しており
# 通常は追加設定なしで動作するが、リフレクション・JNIを利用するものは
# 明示的なkeepが無いと難読化・除去で壊れる可能性があるため、念のため
# 保守的にkeepしておく。

# google_mobile_ads（広告SDK。公式ドキュメント推奨のkeepルール）
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}

# ffmpeg_kit_flutter_new_min_gpl（動画書き出し。JNIネイティブメソッドを使用）。
# 旧ffmpeg_kit_flutter_min_gplのcom.arthenica.**パッケージから移行した際、
# 新パッケージ（com.antonkarpenko.**。プラグイン本体・依存するネイティブ
# ライブラリcom.antonkarpenko:ffmpeg-kit-min-gplともに同名前空間）への
# keepルール更新が漏れており、リリースビルドでJNIブリッジ・セッション
# 管理クラスがR8に除去され起動時クラッシュを起こしていた（実機確認）。
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.antonkarpenko.smartexception.** { *; }

# in_app_purchase（課金。Play Billingとの連携でリフレクションを使用する場合がある）
-keep class com.android.billingclient.** { *; }

# video_player（メディア再生。内部でAndroidX Media3
# （旧ExoPlayer2のcom.google.android.exoplayer2.**から移行済み）を使用）
-keep class androidx.media3.** { *; }

# share_plus（共有シート。dev.fluttercommunity.plus.share名前空間）
-keep class dev.fluttercommunity.plus.share.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# 標準的な注意事項：Flutter Plugin Registrant・エンジン本体はFlutter Gradle
# Pluginが既定のkeepルールを自動適用するため、ここでの追加指定は不要。
