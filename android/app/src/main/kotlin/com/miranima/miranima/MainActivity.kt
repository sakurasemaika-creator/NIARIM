package com.miranima.miranima

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * .mirashare受信フロー（仕様書06）：
 * 他アプリ/ファイラーから.mirashareファイルをタップして開いた際、
 * IntentのデータURIをMethodChannel経由でFlutter側（ShareIntentService）へ渡す。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.miranima.miranima/share_intent"
    private val hwVideoEncoderChannelName = "com.miranima.miranima/hw_video_encoder"
    private var methodChannel: MethodChannel? = null
    private var pendingUri: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())

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
                        if (framePaths == null || fps == null || width == null || height == null || outputPath == null) {
                            result.error("INVALID_ARGS", "framePaths/fps/width/height/outputPathが不足しています", null)
                            return@setMethodCallHandler
                        }
                        thread(name = "hw-video-encoder") {
                            try {
                                HardwareVideoEncoder.encode(framePaths, fps, width, height, outputPath)
                                mainHandler.post { result.success(null) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("ENCODE_FAILED", e.message, null) }
                            }
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
