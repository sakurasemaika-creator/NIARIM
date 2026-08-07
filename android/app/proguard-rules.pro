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

# ffmpeg_kit_flutter_min_gpl（動画書き出し。JNIネイティブメソッドを使用）
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }

# in_app_purchase（課金。Play Billingとの連携でリフレクションを使用する場合がある）
-keep class com.android.billingclient.** { *; }

# video_player / audioplayers（メディア再生。ExoPlayer関連）
-keep class com.google.android.exoplayer2.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# 標準的な注意事項：Flutter Plugin Registrant・エンジン本体はFlutter Gradle
# Pluginが既定のkeepルールを自動適用するため、ここでの追加指定は不要。
