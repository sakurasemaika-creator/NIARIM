plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// GitHub Actions / local environment inject private signing materials via environment
// variables. Never commit keystores or passwords to this repository.
val niarimDebugKeystorePath = System.getenv("NIARIM_DEBUG_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
val niarimDebugStorePassword = System.getenv("NIARIM_DEBUG_STORE_PASSWORD")?.takeIf { it.isNotBlank() }
val niarimUploadKeystorePath = System.getenv("NIARIM_UPLOAD_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
val niarimUploadStorePassword = System.getenv("NIARIM_UPLOAD_STORE_PASSWORD")?.takeIf { it.isNotBlank() }

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
        // TODO: Specify your own unique Application ID
        // (https://developer.android.com/studio/build/application-id.html).
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

    // Dedicated keys: CI debug APKs must keep one certificate across runs;
    // Play upload releases use a DIFFERENT key. Google Play signs delivered
    // APKs with its own app-signing key, whose SHA-1 must also be registered.
    signingConfigs {
        if (niarimDebugKeystorePath != null && niarimDebugStorePassword != null) {
            getByName("debug") {
                storeFile = file(niarimDebugKeystorePath)
                storePassword = niarimDebugStorePassword
                keyAlias = "niarim_ci_debug"
                keyPassword = niarimDebugStorePassword
            }
        }
        if (niarimUploadKeystorePath != null && niarimUploadStorePassword != null) {
            create("niarimUpload") {
                storeFile = file(niarimUploadKeystorePath)
                storePassword = niarimUploadStorePassword
                keyAlias = "niarim_upload"
                keyPassword = niarimUploadStorePassword
            }
        }
    }

    buildTypes {
        release {
            // Never ship a release signed with a temporary CI debug key.
            // An unsigned local release is prevented below; CI also fails closed
            // until the persistent upload key has been configured.
            signingConfig = signingConfigs.findByName("niarimUpload")

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
                "proguard-rules.pro",
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

// Fail closed for release builds when the upload keystore is unavailable.
// Flutter invokes assembleRelease / bundleRelease; ordinary analysis and debug
// builds remain available without release secrets.
val niarimReleaseRequested = gradle.startParameter.taskNames.any { task ->
    val simpleName = task.substringAfterLast(':').lowercase()
    (simpleName.startsWith("assemble") ||
        simpleName.startsWith("bundle") ||
        simpleName.startsWith("package")) && simpleName.contains("release")
}
if (niarimReleaseRequested && android.signingConfigs.findByName("niarimUpload") == null) {
    throw org.gradle.api.GradleException(
        "NIARIM release signing is not configured. Set NIARIM_UPLOAD_KEYSTORE_PATH " +
            "and NIARIM_UPLOAD_STORE_PASSWORD; never fall back to the debug key.",
    )
}
