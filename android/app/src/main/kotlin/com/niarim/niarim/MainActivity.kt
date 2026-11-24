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
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
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
    private val textToSpeechChannelName = "com.niarim.niarim/text_to_speech"
    private var textToSpeech: TextToSpeech? = null
    private var textToSpeechReady = false
    private var textToSpeechInitializing = false
    private val textToSpeechReadyCallbacks = mutableListOf<(TextToSpeech?) -> Unit>()
    private val pendingSpeechResults = mutableMapOf<String, MethodChannel.Result>()
    private val pendingSpeechFiles = mutableMapOf<String, File>()
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
                        val audioPath = call.argument<String>("audioPath")
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
                                val audioIncluded =
                                    HardwareVideoEncoder.encode(
                                        framePaths,
                                        fps,
                                        width,
                                        height,
                                        outputPath,
                                        audioPath,
                                    )
                                mainHandler.post { result.success(audioIncluded) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("ENCODE_FAILED", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }


        // NIARIM does not bundle or redistribute speech engines or voice models.
        // Only offline voices already installed by the user's Android TTS provider
        // are exposed here; each provider's own commercial-use terms still apply.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textToSpeechChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "offlineVoices" -> withTextToSpeech { engine ->
                        if (engine == null) {
                            result.error(
                                "TTS_UNAVAILABLE",
                                "Android text-to-speech is unavailable",
                                null,
                            )
                        } else {
                            val voices = engine.voices
                                ?.filter { !it.isNetworkConnectionRequired }
                                ?.sortedWith(compareBy({ it.locale.toLanguageTag() }, { it.name }))
                                ?.map {
                                    mapOf(
                                        "name" to it.name,
                                        "locale" to it.locale.toLanguageTag(),
                                        "quality" to it.quality,
                                    )
                                } ?: emptyList()
                            result.success(voices)
                        }
                    }
                    "synthesizeToFile" -> {
                        val text = call.argument<String>("text")?.trim()
                        val voiceName = call.argument<String>("voiceName")
                        val outputPath = call.argument<String>("outputPath")
                        val rate = (call.argument<Double>("rate") ?: 1.0)
                            .toFloat().coerceIn(0.5f, 2.0f)
                        val pitch = (call.argument<Double>("pitch") ?: 1.0)
                            .toFloat().coerceIn(0.5f, 2.0f)
                        if (text.isNullOrBlank() ||
                            voiceName.isNullOrBlank() ||
                            outputPath.isNullOrBlank()
                        ) {
                            result.error("INVALID_ARGS", "text, voiceName and outputPath are required", null)
                            return@setMethodCallHandler
                        }
                        if (text.length > 3500) {
                            result.error("TEXT_TOO_LONG", "Text exceeds the supported request limit", null)
                            return@setMethodCallHandler
                        }
                        val target = try {
                            File(outputPath).canonicalFile
                        } catch (_: Exception) {
                            result.error("INVALID_PATH", "Invalid output path", null)
                            return@setMethodCallHandler
                        }
                        val cacheRoot = cacheDir.canonicalFile.path + File.separator
                        if (!target.path.startsWith(cacheRoot)) {
                            result.error("INVALID_PATH", "Speech output must stay inside the app cache", null)
                            return@setMethodCallHandler
                        }
                        withTextToSpeech { engine ->
                            if (engine == null) {
                                result.error("TTS_UNAVAILABLE", "Android text-to-speech is unavailable", null)
                                return@withTextToSpeech
                            }
                            val voice = engine.voices?.firstOrNull {
                                it.name == voiceName && !it.isNetworkConnectionRequired
                            }
                            if (voice == null) {
                                result.error("VOICE_UNAVAILABLE", "The selected offline voice is no longer available", null)
                                return@withTextToSpeech
                            }
                            if (pendingSpeechResults.isNotEmpty()) {
                                result.error("TTS_BUSY", "Another speech generation is in progress", null)
                                return@withTextToSpeech
                            }
                            try {
                                target.parentFile?.mkdirs()
                                if (target.exists()) target.delete()
                                engine.voice = voice
                                engine.setSpeechRate(rate)
                                engine.setPitch(pitch)
                                val utteranceId = "niarim_" + System.nanoTime()
                                pendingSpeechResults[utteranceId] = result
                                pendingSpeechFiles[utteranceId] = target
                                val status = engine.synthesizeToFile(
                                    text,
                                    Bundle(),
                                    target,
                                    utteranceId,
                                )
                                if (status != TextToSpeech.SUCCESS) {
                                    pendingSpeechResults.remove(utteranceId)
                                    pendingSpeechFiles.remove(utteranceId)?.delete()
                                    result.error("TTS_QUEUE_FAILED", "The voice engine rejected the request", null)
                                }
                            } catch (error: Exception) {
                                pendingSpeechResults.values.remove(result)
                                result.error("TTS_FAILED", error.message ?: "Speech generation failed", null)
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

    private fun withTextToSpeech(callback: (TextToSpeech?) -> Unit) {
        val ready = textToSpeech
        if (textToSpeechReady && ready != null) {
            callback(ready)
            return
        }
        textToSpeechReadyCallbacks.add(callback)
        if (textToSpeechInitializing) return
        textToSpeechInitializing = true
        try {
            textToSpeech = TextToSpeech(this) { status ->
                mainHandler.post {
                    textToSpeechInitializing = false
                    val engine = textToSpeech
                    if (status == TextToSpeech.SUCCESS && engine != null) {
                        textToSpeechReady = true
                        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                            override fun onStart(utteranceId: String) {}

                            override fun onDone(utteranceId: String) {
                                mainHandler.post {
                                    val pending = pendingSpeechResults.remove(utteranceId)
                                        ?: return@post
                                    val file = pendingSpeechFiles.remove(utteranceId)
                                    if (file != null && file.exists() && file.length() > 44L) {
                                        pending.success(file.absolutePath)
                                    } else {
                                        file?.delete()
                                        pending.error(
                                            "TTS_EMPTY_OUTPUT",
                                            "The voice engine returned an empty audio file",
                                            null,
                                        )
                                    }
                                }
                            }

                            override fun onError(utteranceId: String) {
                                mainHandler.post {
                                    pendingSpeechFiles.remove(utteranceId)?.delete()
                                    pendingSpeechResults.remove(utteranceId)?.error(
                                        "TTS_SYNTHESIS_FAILED",
                                        "The selected voice could not synthesize the text",
                                        null,
                                    )
                                }
                            }
                        })
                    } else {
                        engine?.shutdown()
                        textToSpeech = null
                        textToSpeechReady = false
                    }
                    val callbacks = textToSpeechReadyCallbacks.toList()
                    textToSpeechReadyCallbacks.clear()
                    callbacks.forEach {
                        it(if (textToSpeechReady) textToSpeech else null)
                    }
                }
            }
        } catch (_: Exception) {
            textToSpeechInitializing = false
            textToSpeech = null
            val callbacks = textToSpeechReadyCallbacks.toList()
            textToSpeechReadyCallbacks.clear()
            callbacks.forEach { it(null) }
        }
    }

    override fun onDestroy() {
        pendingSpeechResults.values.forEach {
            it.error("ACTIVITY_DESTROYED", "Speech generation was interrupted", null)
        }
        pendingSpeechResults.clear()
        pendingSpeechFiles.values.forEach { it.delete() }
        pendingSpeechFiles.clear()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
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
