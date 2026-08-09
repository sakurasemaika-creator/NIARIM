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

# 自作コード（com.miranima.miranima配下）。usage.txtでの実機起動時
# クラッシュ原因調査により、HardwareVideoEncoder（Kotlinのobject）の
# シングルトンインスタンスフィールド（INSTANCE）がR8に除去されている
# ことが判明した。MainActivity.ktはMethodChannelハンドラー（ラムダ式）
# 内からこのオブジェクトを呼び出しているが、R8の到達可能性解析がこの
# パターンを正しく追跡できず「未使用」と誤判定していたと考えられる。
# INSTANCEフィールドが無い状態でMainActivityのクラスが読み込まれる際
# （＝アプリ起動時）にNoSuchFieldErrorが発生し、起動直後のクラッシュを
# 起こしていた（usage.txtで確認）。自作コードは全体でも小規模なため、
# 個別の除去パターンを追いかけるのではなく丸ごとkeepすることで、同種の
# 問題が今後別のクラスで再発することも防ぐ。
-keep class com.miranima.miranima.** { *; }

# google_mobile_ads（広告SDK。公式ドキュメント推奨のkeepルール）
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}

# WorkManager（google_mobile_adsが内部でバックグラウンド処理に使用。
# 実機のバグレポート（AndroidRuntimeのFATAL EXCEPTION）で、以下の例外に
# より起動直後にクラッシュしていたことを確認した：
#   java.lang.RuntimeException: Unable to get provider
#   androidx.startup.InitializationProvider: ...
#   Failed to create an instance of androidx.work.impl.WorkDatabase
# androidx.startup.InitializationProviderはContentProviderとして
# Application.onCreate()より前（handleBindApplication時）に初期化される
# ため、通常の未捕捉例外ハンドラーでは捕捉できない。WorkManagerが内部で
# 使うRoom生成クラス（WorkDatabase実装）がR8の最適化（class merging等）
# で壊れることによる既知の問題。
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**

# ffmpeg_kit_flutter_new_video（WebM/VP9書き出し専用。JNIネイティブ
# メソッドを使用）。旧ffmpeg_kit_flutter_min_gplのcom.arthenica.**
# パッケージから移行した際、新パッケージ（com.antonkarpenko.**）への
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
