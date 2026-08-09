package com.miranima.miranima

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * 【診断用・一時的】未捕捉例外のスタックトレースをそのまま画面表示する
 * だけの最小限の画面。adbが使えない環境での実機クラッシュ調査用。
 * 原因特定後、本ファイル・MainApplication.ktのハンドラー設定・
 * AndroidManifest.xmlの関連宣言は削除すること。
 */
class CrashActivity : Activity() {
    companion object {
        private const val EXTRA_TRACE = "trace"

        fun launch(context: Context, trace: String) {
            val intent = Intent(context, CrashActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            intent.putExtra(EXTRA_TRACE, trace)
            context.startActivity(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trace = intent.getStringExtra(EXTRA_TRACE) ?: "(トレースを取得できませんでした)"

        val textView = TextView(this).apply {
            text = trace
            textSize = 11f
            setPadding(24, 24, 24, 24)
            setTextIsSelectable(true)
            movementMethod = ScrollingMovementMethod()
        }
        val scrollView = ScrollView(this).apply {
            addView(textView)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
        }
        val copyButton = Button(this).apply {
            text = "コピー"
            setOnClickListener {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("crash", trace))
                Toast.makeText(this@CrashActivity, "クリップボードへコピーしました", Toast.LENGTH_SHORT).show()
            }
        }
        val closeButton = Button(this).apply {
            text = "閉じる"
            setOnClickListener { finishAndRemoveTask() }
        }
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(copyButton)
            addView(closeButton)
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(scrollView)
            addView(buttonRow)
        }
        setContentView(root)
    }
}
