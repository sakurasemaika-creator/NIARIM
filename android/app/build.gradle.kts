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

            // 【診断目的で一時的に再有効化】R8有効時のリリースビルドが実機
            // （Android 16）で起動直後にクラッシュする不具合の原因調査用。
            // R8無効ビルドは実機で正常起動を確認済みのため、このビルド自体は
            // 実機へインストールせず、build/app/outputs/mapping/release/
            // usage.txt（R8が実際に除去したクラス一覧）をCI artifactとして
            // 取得し、除去されているクラスを特定した上でkeepルールを直す
            // 目的のみに使う。詳細はdocs/AI設計書/12_実装チェックリスト.md
            // の追記を参照。
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
