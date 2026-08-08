package com.miranima.miranima

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer

/**
 * Android標準のMediaCodec（端末内蔵ハードウェアH.264エンコーダー）と
 * MediaMuxerによるMP4生成（仕様書13：ライセンス・特許ロイヤリティ対応）。
 *
 * 従来はFFmpeg（ffmpeg_kit_flutter_new_min_gpl、libx264を含むGPLビルド）で
 * MP4を生成していたが、以下2点の論点があったため、端末内蔵の
 * ハードウェアエンコーダーを直接呼び出す方式へ変更した。
 * 1. libx264はGPLライセンスであり、アプリへ組み込んで配布する場合の
 *    コピーレフト（対応ソースコード開示義務等）への対応が必要だった
 * 2. アプリが自前のソフトウェアエンコーダーでH.264を生成する場合、
 *    H.264規格自体の特許ロイヤリティ（Via Licensing Allianceが管理する
 *    AVC特許プール）の当事者になり得る。ハードウェアエンコーダーは
 *    端末メーカー・OSベンダー側で特許処理済みという前提に乗れるため、
 *    アプリ側の特許論点を回避できる
 *
 * フレームはPNG連番ファイルのパス一覧（[framePaths]、表示順）として渡し、
 * 各フレームを指定fpsぶんの一定間隔でPTS（プレゼンテーションタイム
 * スタンプ）を明示的に割り当ててエンコードする（MediaCodecの
 * Surface入力＋Canvas描画方式は内部的に壁時計時刻でPTSが決まり
 * 一定fpsを保証できないため、Image API経由のバッファ入力方式を採用）。
 * 同一パスを複数回指定すれば静止フレームの複製（エンドカード等）として
 * 扱われる。
 */
object HardwareVideoEncoder {
    private const val MIME_TYPE = "video/avc"
    private const val TIMEOUT_US = 10_000L
    private const val I_FRAME_INTERVAL = 2

    fun encode(framePaths: List<String>, fps: Int, width: Int, height: Int, outputPath: String) {
        if (framePaths.isEmpty()) throw IllegalArgumentException("framePaths is empty")
        if (fps <= 0) throw IllegalArgumentException("fps must be positive")

        // H.264エンコーダーは奇数幅・高さを受け付けない端末があるため2の倍数へ切り上げる
        val encWidth = (width + 1) / 2 * 2
        val encHeight = (height + 1) / 2 * 2

        val format = MediaFormat.createVideoFormat(MIME_TYPE, encWidth, encHeight).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
            )
            setInteger(MediaFormat.KEY_BIT_RATE, estimateBitRate(encWidth, encHeight, fps))
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }

        val codec = MediaCodec.createEncoderByType(MIME_TYPE)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerTrackIndex = -1
        var muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()
        val frameDurationUs = 1_000_000L / fps
        var nextFrameToSubmit = 0
        var inputDone = false
        var outputDone = false

        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inputIndex >= 0) {
                        if (nextFrameToSubmit < framePaths.size) {
                            val bitmap = BitmapFactory.decodeFile(framePaths[nextFrameToSubmit])
                                ?: throw IllegalStateException(
                                    "フレーム画像を読み込めません: ${framePaths[nextFrameToSubmit]}"
                                )
                            val image: Image = codec.getInputImage(inputIndex)
                                ?: throw IllegalStateException("端末がImage入力に対応していません")
                            writeBitmapToYuvImage(bitmap, image, encWidth, encHeight)
                            bitmap.recycle()
                            val pts = nextFrameToSubmit.toLong() * frameDurationUs
                            codec.queueInputBuffer(inputIndex, 0, 0, pts, 0)
                            nextFrameToSubmit++
                        } else {
                            codec.queueInputBuffer(
                                inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                when {
                    outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> { /* 次のループへ */ }
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (muxerStarted) throw IllegalStateException("フォーマット変更が複数回発生しました")
                        muxerTrackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outputIndex == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> { /* 旧API。Image API使用時は無視してよい */ }
                    outputIndex >= 0 -> {
                        val encodedData = codec.getOutputBuffer(outputIndex)
                            ?: throw IllegalStateException("出力バッファを取得できません")
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            bufferInfo.size = 0
                        }
                        if (bufferInfo.size != 0 && muxerStarted) {
                            encodedData.position(bufferInfo.offset)
                            encodedData.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(muxerTrackIndex, encodedData, bufferInfo)
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
        } finally {
            try {
                codec.stop()
            } catch (_: Exception) {
            }
            codec.release()
            if (muxerStarted) {
                try {
                    muxer.stop()
                } catch (_: Exception) {
                }
            }
            muxer.release()
        }
    }

    /**
     * ビットレートの簡易見積り（画素数×fps×経験的係数、H.264の一般的な
     * 目安である0.1 bit/pixelを採用）。書き出し品質と容量のバランスを取る。
     */
    private fun estimateBitRate(width: Int, height: Int, fps: Int): Int {
        val pixelsPerSecond = width.toLong() * height.toLong() * fps
        return (pixelsPerSecond * 0.1).toLong().coerceAtLeast(1_000_000L).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    /**
     * ARGB_8888のBitmapを、MediaCodecのImage入力バッファ（YUV420。プレーンの
     * 行ストライド・画素ストライドは端末実装依存のため、Image APIが返す
     * plane情報に従って書き込む）へBT.601変換して書き込む。
     */
    private fun writeBitmapToYuvImage(bitmap: Bitmap, image: Image, width: Int, height: Int) {
        val argb = IntArray(width * height)
        if (bitmap.width == width && bitmap.height == height) {
            bitmap.getPixels(argb, 0, width, 0, 0, width, height)
        } else {
            // フレーム画像サイズがエンコード解像度（2の倍数への切り上げ）と
            // 異なる場合は、黒背景へ左上詰めで描画してから読み出す
            val padded = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(padded)
            canvas.drawColor(Color.BLACK)
            canvas.drawBitmap(bitmap, 0f, 0f, null)
            padded.getPixels(argb, 0, width, 0, 0, width, height)
            padded.recycle()
        }

        val planes = image.planes
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val yRowStride = yPlane.rowStride
        val yPixelStride = yPlane.pixelStride
        val uRowStride = uPlane.rowStride
        val uPixelStride = uPlane.pixelStride
        val vRowStride = vPlane.rowStride
        val vPixelStride = vPlane.pixelStride

        // 行単位でY値をまとめて計算し、画素ストライドが1（プレーナー配置）の
        // 行はバルクコピーで書き込むことで、全画素を1つずつput()するより
        // 高速化する（低スペック端末対応、仕様書01）。
        val yRow = ByteArray(width)
        for (row in 0 until height) {
            val rowBase = row * width
            for (col in 0 until width) {
                yRow[col] = rgbToY(argb[rowBase + col])
            }
            val yRowOffset = row * yRowStride
            if (yPixelStride == 1) {
                yBuffer.position(yRowOffset)
                yBuffer.put(yRow, 0, width)
            } else {
                for (col in 0 until width) {
                    yBuffer.put(yRowOffset + col * yPixelStride, yRow[col])
                }
            }
        }

        val chromaWidth = width / 2
        val chromaHeight = height / 2
        val uRow = ByteArray(chromaWidth)
        val vRow = ByteArray(chromaWidth)
        for (cRow in 0 until chromaHeight) {
            val row = cRow * 2
            val rowBase = row * width
            for (cCol in 0 until chromaWidth) {
                val col = cCol * 2
                val pixel = argb[rowBase + col]
                uRow[cCol] = rgbToU(pixel)
                vRow[cCol] = rgbToV(pixel)
            }
            val uRowOffset = cRow * uRowStride
            val vRowOffset = cRow * vRowStride
            if (uPixelStride == 1) {
                uBuffer.position(uRowOffset)
                uBuffer.put(uRow, 0, chromaWidth)
            } else {
                for (cCol in 0 until chromaWidth) {
                    uBuffer.put(uRowOffset + cCol * uPixelStride, uRow[cCol])
                }
            }
            if (vPixelStride == 1) {
                vBuffer.position(vRowOffset)
                vBuffer.put(vRow, 0, chromaWidth)
            } else {
                for (cCol in 0 until chromaWidth) {
                    vBuffer.put(vRowOffset + cCol * vPixelStride, vRow[cCol])
                }
            }
        }
    }

    private fun rgbToY(argbPixel: Int): Byte {
        val r = (argbPixel shr 16) and 0xFF
        val g = (argbPixel shr 8) and 0xFF
        val b = argbPixel and 0xFF
        val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
        return y.coerceIn(0, 255).toByte()
    }

    private fun rgbToU(argbPixel: Int): Byte {
        val r = (argbPixel shr 16) and 0xFF
        val g = (argbPixel shr 8) and 0xFF
        val b = argbPixel and 0xFF
        val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
        return u.coerceIn(0, 255).toByte()
    }

    private fun rgbToV(argbPixel: Int): Byte {
        val r = (argbPixel shr 16) and 0xFF
        val g = (argbPixel shr 8) and 0xFF
        val b = argbPixel and 0xFF
        val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
        return v.coerceIn(0, 255).toByte()
    }
}
