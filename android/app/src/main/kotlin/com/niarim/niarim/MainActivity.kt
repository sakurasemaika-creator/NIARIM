package com.niarim.niarim

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.File
import java.io.FileOutputStream
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
    private val postChannelName = "com.niarim.niarim/post_notification"
    private val videoFrameChannelName = "com.niarim.niarim/video_frame"
    private var pendingPostNotification: Triple<String, String, Boolean>? = null
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
        pendingWidgetRoute = CommunityNotices.tappedRoute(this, intent)
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

        // Publish completion notifications are local and have an explicit,
        // owner-only work-detail PendingIntent (works even on cold launch).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, postChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showSuccess" -> {
                        val videoId = call.argument<String>("workId")
                        val owner = call.argument<String>("owner")
                        val scheduled = call.argument<Boolean>("scheduled") ?: false
                        if (videoId == null || !Regex("^[A-Za-z0-9_-]{11}$").matches(videoId)) {
                            result.error("BAD_WORK_ID", "Invalid work ID", null)
                        } else {
                            if (owner != null) showPostNotification(owner, videoId, scheduled)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.niarim.niarim/activity_notice_history")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "filter" -> {
                        val owner = call.argument<String>("owner") ?: ""
                        val receipts = call.argument<List<Map<String, String>>>("receipts").orEmpty()
                        thread(name = "notice-history") {
                            try {
                                val filtered = CommunityNotices.filter(applicationContext, owner, receipts)
                                mainHandler.post { result.success(filtered) }
                            } catch (_: Exception) {
                                mainHandler.post { result.error("HISTORY_UNAVAILABLE", null, null) }
                            }
                        }
                    }
                    "clearOtherAccounts" -> {
                        CommunityNotices.clearOtherAccounts(this, call.argument<String>("owner"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, videoFrameChannelName)
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "動画が指定されていません", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "getVideoDuration", "extractFrame" -> thread(name = "thumbnail-frame") {
                        val retriever = MediaMetadataRetriever()
                        try {
                            retriever.setDataSource(path)
                            if (call.method == "getVideoDuration") {
                                val ms = retriever.extractMetadata(
                                    MediaMetadataRetriever.METADATA_KEY_DURATION
                                )?.toLongOrNull() ?: 0L
                                mainHandler.post { result.success(ms.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()) }
                            } else {
                                val ms = call.argument<Int>("timeMs") ?: 0
                                val frame = retriever.getFrameAtTime(
                                    ms.toLong().coerceAtLeast(0) * 1000,
                                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                                ) ?: throw IllegalArgumentException("動画から画像を抽出できません")
                                val scale = minOf(1.0, 1280.0 / maxOf(frame.width, frame.height))
                                val w = maxOf(1, (frame.width * scale).toInt())
                                val h = maxOf(1, (frame.height * scale).toInt())
                                val bitmap = if (scale < 1.0)
                                    Bitmap.createScaledBitmap(frame, w, h, true) else frame
                                val file = File(cacheDir, "niarim_video_frame_${System.nanoTime()}.jpg")
                                FileOutputStream(file).use { output ->
                                    if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output)) {
                                        throw IllegalStateException("サムネイルの生成に失敗しました")
                                    }
                                }
                                if (bitmap !== frame) bitmap.recycle()
                                frame.recycle()
                                mainHandler.post { result.success(file.absolutePath) }
                            }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error("FRAME_READ_FAILED", error.message, null)
                            }
                        } finally {
                            retriever.release()
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ホーム画面ウィジェットのタップで開くルートをFlutterへ渡す。
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
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
        val route = CommunityNotices.tappedRoute(this, intent)
        if (route != null) {
            widgetChannel?.invokeMethod("onWidgetRoute", route)
        }
    }

    private fun showPostNotification(
        owner: String, workId: String, scheduled: Boolean
    ) {
        if (!CommunityNotices.publicationEnabled(this)) return
        val record = Triple(owner, workId, scheduled)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            pendingPostNotification = record
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4311)
            return
        }
        postConfirmedNotification(record)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4311) return
        val pending = pendingPostNotification
        pendingPostNotification = null
        if (pending != null && grantResults.firstOrNull() ==
            PackageManager.PERMISSION_GRANTED) {
            postConfirmedNotification(pending)
        }
    }

    private fun postConfirmedNotification(item: Triple<String, String, Boolean>) {
        val (owner, workId, scheduled) = item
        thread(name = "post-notification") {
            try {
                CommunityNotices.showPost(applicationContext, owner, workId, scheduled)
            } catch (error: Exception) {
                android.util.Log.w("CommunityNotices", "Post notification unavailable: ${error.javaClass.simpleName}")
            }
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
