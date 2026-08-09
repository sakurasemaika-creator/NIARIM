plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.miranima.miranima"
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
        applicationId = "com.miranima.miranima"
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
            // 原因をusage.txt（R8が実際に除去したクラス一覧）で調査した結果、
            // com.miranima.miranima.HardwareVideoEncoder（Kotlinのobject）の
            // シングルトンインスタンスフィールドがR8に除去されていたことが
            // 判明した。proguard-rules.proに`-keep class
            // com.miranima.miranima.** { *; }`を追加して修正済み。ただし
            // この修正込みでのR8有効ビルドの実機起動確認はまだ済んでいない
            // ため、次のビルドで改めて実機確認が必要。
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
