plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.niarim.niarim"
    // google_mobile_ads 7.x系はcompileSdk 36を要求するため、Flutter側の既定値が
    // それより低い場合に備えて下限を明示する。
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.niarim.niarim"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_mobile_ads 7.x系はminSdk 24を要求するため、Flutter側の既定値が
        // それより低い場合に備えて下限を明示する。
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // APK容量削減（仕様書01：低スペック端末対応）。R8はJava/Kotlinの
            // プラグイングルーコードのみを対象とし、FlutterのDartコード
            // （AOTコンパイル済みネイティブコード）には影響しないため、
            // アプリの見た目・機能は変わらない。
            //
            // 【経緯】実機（Android 16）で起動直後にクラッシュする不具合の
            // 原因をusage.txt（R8が実際に除去したクラス一覧）・実機バグ
            // レポートで段階的に調査し、(1)com.niarim.niarim.HardwareVideoEncoder
            // （Kotlinのobject）のシングルトンインスタンスフィールド除去、
            // (2)google_mobile_ads内部が使うWorkManager/RoomのWorkDatabase
            // 実装クラス破壊（Application.onCreate()より前のContentProvider
            // 初期化時点で起きるため通常の例外ハンドラーでは捕捉不能だった）、
            // の2つがそれぞれ原因と判明した。proguard-rules.proへのkeepルール
            // 追加（自作コード一式・androidx.work/androidx.room/
            // androidx.startup）で両方修正し、修正込みのR8有効ビルドを
            // ユーザーが実機に再インストールして起動・書き出しとも正常に
            // 動作することを確認済み（詳細は12_実装チェックリスト.md
            // 「R8起動時クラッシュの真の原因を実機バグレポートで特定」の節）。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
