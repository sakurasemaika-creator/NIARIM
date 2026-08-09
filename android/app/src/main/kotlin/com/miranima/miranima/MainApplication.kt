package com.miranima.miranima

import android.app.Application
import java.io.PrintWriter
import java.io.StringWriter

/**
 * 【診断用・一時的】実機での起動時クラッシュの原因調査用。adbが無くても
 * クラッシュ内容を確認できるよう、未捕捉例外を横取りしてCrashActivityへ
 * スタックトレースを表示する。原因特定後、この仕組み（本ファイル・
 * CrashActivity.kt・AndroidManifest.xmlの関連設定）は削除すること。
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                CrashActivity.launch(applicationContext, sw.toString())
                // CrashActivityの起動（Activity遷移）が実際に処理される猶予を与える。
                Thread.sleep(500)
            } catch (_: Throwable) {
                // クラッシュ画面の表示自体に失敗しても、元のクラッシュ処理は継続する。
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
