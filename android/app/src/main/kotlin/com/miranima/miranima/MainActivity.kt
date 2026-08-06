package com.miranima.miranima

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * .mirashare受信フロー（仕様書06）：
 * 他アプリ/ファイラーから.mirashareファイルをタップして開いた際、
 * IntentのデータURIをMethodChannel経由でFlutter側（ShareIntentService）へ渡す。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.miranima.miranima/share_intent"
    private var methodChannel: MethodChannel? = null
    private var pendingUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUri = extractUri(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUri" -> {
                    result.success(pendingUri)
                    pendingUri = null
                }
                "readUri" -> {
                    val uriStr = call.argument<String>("uri")
                    try {
                        val bytes = uriStr?.let { s ->
                            contentResolver.openInputStream(Uri.parse(s))?.use { it.readBytes() }
                        }
                        result.success(bytes)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = extractUri(intent)
        if (uri != null) {
            methodChannel?.invokeMethod("onSharedFile", uri)
        }
    }

    private fun extractUri(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_VIEW) {
            return intent.data?.toString()
        }
        return null
    }
}
