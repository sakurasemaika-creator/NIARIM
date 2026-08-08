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

            // 【一時的に無効化】本来はAPK容量削減（仕様書01：低スペック端末
            // 対応）のためR8を有効にしたいが、R8有効時のリリースビルドが
            // 実機（Android 16）で起動直後にクラッシュする不具合が発生し、
            // 複数回のkeepルール調査・修正を試みても解消できなかった。
            // デバッグビルド（R8無効）は同一端末で正常に起動することを
            // 確認済みのため、R8が原因である可能性が高いと判断し、実機で
            // 動作するアプリを優先して一旦無効化する。原因調査は
            // build/app/outputs/mapping/release/usage.txt
            // （R8が実際に除去したクラス一覧）を用いて別途進める。
            // 詳細はdocs/AI設計書/12_実装チェックリスト.mdの追記を参照。
            isMinifyEnabled = false
            isShrinkResources = false
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
