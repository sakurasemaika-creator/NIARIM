package com.niarim.niarim

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * .niashare受信フロー（仕様書06）： 他アプリ/ファイラーから.niashareファイルをタップして開いた際、
 * IntentのデータURIをMethodChannel経由でFlutter側（ShareIntentService）へ渡す。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.niarim.niarim/share_intent"
    private val widgetChannelName = "com.niarim.niarim/home_widget_route"
    private val hwVideoEncoderChannelName = "com.niarim.niarim/hw_video_encoder"
    private var methodChannel: MethodChannel? = null
    private var widgetChannel: MethodChannel? = null
    private var pendingUri: String? = null
    // ホーム画面ウィジェットのタップで指定されたアプリ内ルート。
    // Flutter側が起動しきる前にIntentが届くため、いったん保持して
    // getInitialRouteで取りに来てもらう（共有ファイルURIと同じ方式）。
    private var pendingWidgetRoute: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val maxSharedFileBytes = 128 * 1024 * 1024

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUri = extractUri(intent)
        pendingWidgetRoute = intent?.getStringExtra(WIDGET_ROUTE_EXTRA)
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
                    if (uriStr == null) {
                        result.error("INVALID_URI", "URIが指定されていません", null)
                        return@setMethodCallHandler
                    }
                    thread(name = "shared-file-reader") {
                        try {
                            val bytes = readSharedFile(Uri.parse(uriStr))
                            mainHandler.post { result.success(bytes) }
                        } catch (_: SharedFileTooLargeException) {
                            mainHandler.post {
                                result.error("FILE_TOO_LARGE", "共有ファイルがサイズ上限を超えています", null)
                            }
                        } catch (_: Exception) {
                            mainHandler.post {
                                result.error("READ_FAILED", "共有ファイルを読み込めません", null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // MP4書き出し用ハードウェアH.264エンコーダー呼び出し（仕様書13：
        // GPLライセンス・特許ロイヤリティ対応のためFFmpeg/libx264を使わない）。
        // MediaCodec/MediaMuxerの処理はUIスレッドをブロックしないよう
        // 別スレッドで実行し、結果はメインスレッドへ戻してから応答する。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hwVideoEncoderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "encodeMp4" -> {
                        @Suppress("UNCHECKED_CAST")
                        val framePaths = call.argument<List<String>>("framePaths")
                        val fps = call.argument<Int>("fps")
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val outputPath = call.argument<String>("outputPath")
                        if (
                            framePaths == null ||
                                fps == null ||
                                width == null ||
                                height == null ||
                                outputPath == null
                        ) {
                            result.error(
                                "INVALID_ARGS",
                                "framePaths/fps/width/height/outputPathが不足しています",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        thread(name = "hw-video-encoder") {
                            try {
                                HardwareVideoEncoder.encode(
                                    framePaths,
                                    fps,
                                    width,
                                    height,
                                    outputPath,
                                )
                                mainHandler.post { result.success(null) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("ENCODE_FAILED", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ホーム画面ウィジェットのタップで開くルートをFlutterへ渡す。
        widgetChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    result.success(pendingWidgetRoute)
                    pendingWidgetRoute = null
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
        val route = intent.getStringExtra(WIDGET_ROUTE_EXTRA)
        if (route != null) {
            widgetChannel?.invokeMethod("onWidgetRoute", route)
        }
    }

    private fun extractUri(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_VIEW) {
            val uri = intent.data ?: return null
            if (uri.scheme == "content" || uri.scheme == "file") return uri.toString()
        }
        return null
    }

    private fun readSharedFile(uri: Uri): ByteArray {
        if (uri.scheme != "content" && uri.scheme != "file") {
            throw IllegalArgumentException("unsupported URI scheme")
        }
        val stream =
            contentResolver.openInputStream(uri)
                ?: throw IllegalArgumentException("input stream unavailable")
        return stream.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxSharedFileBytes) throw SharedFileTooLargeException()
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        }
    }

    private class SharedFileTooLargeException : Exception()
}
