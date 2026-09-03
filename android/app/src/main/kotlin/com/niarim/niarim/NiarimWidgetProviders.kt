package com.niarim.niarim

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

/**
 * ホーム画面ウィジェットの共通実装。
 *
 * ## なぜ静止画なのか
 *
 * ウィジェットは`RemoteViews`で描画され、使えるのはImageView/TextView等の
 * 限られた部品だけで、**動画再生もWebViewも一切できない**。そのため
 * 「作品を動かして見せる」ことは原理的に不可能で、フレーム1枚の静止画を
 * 出してタップでアプリを開く形にしている。
 *
 * ## 設定値の受け取り方
 *
 * Flutter側（home_widgetパッケージ）が書いた`SharedPreferences`を読む。
 * home_widgetはアプリ本体の`FlutterSharedPreferences`ではなく
 * **`HomeWidgetPreferences`という専用のプリファレンス**へ、Dartで渡した
 * キーそのままで保存する（`flutter.`接頭辞は付かない）。
 */
private const val PREFS_NAME = "HomeWidgetPreferences"

private fun prefs(context: Context) =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

private fun prefString(context: Context, key: String, fallback: String = ""): String =
    prefs(context).getString(key, fallback) ?: fallback

/**
 * 色（ARGB）を読む。
 *
 * **Dartのintは32bitに収まらないとlongとして保存される**。ARGBは不透明色
 * なら必ず0x80000000以上（例：0xFFFF5C7A = 4294925434）になり、Int32の
 * 範囲を超えるため、home_widgetは`putLong`で書く。`getInt`だけで読むと
 * 常にClassCastExceptionになり、**背景色の設定が一度も反映されない**。
 * longとintの両方を見て、下位32bitをそのままARGBとして解釈する。
 */
private fun prefColor(context: Context, key: String, fallback: Int): Int {
    val p = prefs(context)
    return try {
        if (!p.contains(key)) fallback else p.getLong(key, fallback.toLong()).toInt()
    } catch (_: ClassCastException) {
        try {
            p.getInt(key, fallback)
        } catch (_: ClassCastException) {
            fallback
        }
    }
}

/**
 * ウィジェットのタップで開くアプリ内ルートを、MainActivityへextraで渡す。
 *
 * ルート文字列はDart側（`home_widget_service.dart`の`homeWidgetRoute`）が
 * 決めて`SharedPreferences`へ書いたものをそのまま使う。ネイティブ側で
 * ルートを組み立てるとDartと二重管理になり、片方の変更に気付けないため。
 */
private fun launchIntent(context: Context, route: String): PendingIntent {
    val intent = Intent(context, MainActivity::class.java).apply {
        action = Intent.ACTION_MAIN
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra(WIDGET_ROUTE_EXTRA, route)
        // extraだけが違う同一Intentは既存のPendingIntentが再利用されて
        // しまうため、ルートごとに別のrequestCodeを与えて取り違えを防ぐ。
        data = android.net.Uri.parse("niarim://widget$route")
    }
    return PendingIntent.getActivity(
        context,
        route.hashCode(),
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

const val WIDGET_ROUTE_EXTRA = "niarim_widget_route"

/** アプリのテーマ既定色（テーマ追従が読めなかった場合の保険）。 */
private const val FALLBACK_BACKGROUND = 0xFFFF5C7A.toInt()

/** 好きな作品のフレーム1枚を出し、タップでその作品を開くウィジェット。 */
class NiarimArtworkWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val background = prefColor(context, "backgroundColor", FALLBACK_BACKGROUND)
        val route = prefString(context, "routeArtwork", "/")
        val name = prefString(context, "projectName")
        val thumbnail = prefString(context, "thumbnailPath")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_artwork)
            views.setInt(R.id.widget_root, "setBackgroundColor", background)
            views.setTextViewText(R.id.widget_title, name)
            // 作品が未選択・サムネイル未生成でも空のウィジェットにしない
            // （選び直せるようアプリは開ける状態にしておく）。
            val file = if (thumbnail.isNotEmpty()) File(thumbnail) else null
            if (file != null && file.exists()) {
                val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                if (bitmap != null) views.setImageViewBitmap(R.id.widget_image, bitmap)
            }
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, route))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** ショートカット系ウィジェットの共通処理。 */
private abstract class ShortcutWidgetProvider : AppWidgetProvider() {
    abstract val routeKey: String
    abstract val fallbackRoute: String
    abstract val labelResId: Int
    abstract val iconResId: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val background = prefColor(context, "backgroundColor", FALLBACK_BACKGROUND)
        val route = prefString(context, routeKey, fallbackRoute)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_shortcut)
            views.setInt(R.id.widget_root, "setBackgroundColor", background)
            views.setTextViewText(R.id.widget_label, context.getString(labelResId))
            views.setImageViewResource(R.id.widget_icon, iconResId)
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, route))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** ワンタップで「作品をつくる」へ。 */
class NiarimCreateWidgetProvider : ShortcutWidgetProvider() {
    override val routeKey = "routeCreate"
    override val fallbackRoute = "/new-project"
    override val labelResId = R.string.widget_create_label
    override val iconResId = R.drawable.ic_widget_create
}

/** ワンタップで「作品広場」へ。 */
class NiarimPlazaWidgetProvider : ShortcutWidgetProvider() {
    override val routeKey = "routePlaza"
    override val fallbackRoute = "/community"
    override val labelResId = R.string.widget_plaza_label
    override val iconResId = R.drawable.ic_widget_plaza
}
