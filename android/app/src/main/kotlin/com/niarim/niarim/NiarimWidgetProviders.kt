package com.niarim.niarim

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.io.File

/**
 * ホーム画面ウィジェットの共通実装。
 *
 * ## なぜ静止画なのか
 *
 * ウィジェットは`RemoteViews`で描画され、使えるのはImageView/TextView等の 限られた部品だけで、**動画再生もWebViewも一切できない**。そのため
 * 「作品を動かして見せる」ことは原理的に不可能で、フレーム1枚の静止画を 出してタップでアプリを開く形にしている。
 *
 * ## 設定値の受け取り方
 *
 * Flutter側（home_widgetパッケージ）が書いた`SharedPreferences`を読む。
 * home_widgetはアプリ本体の`FlutterSharedPreferences`ではなく
 * **`HomeWidgetPreferences`という専用のプリファレンス**へ、Dartで渡した キーそのままで保存する（`flutter.`接頭辞は付かない）。
 */
internal const val PREFS_NAME = "HomeWidgetPreferences"

internal fun prefs(context: Context) =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

internal fun prefString(context: Context, key: String, fallback: String = ""): String =
    prefs(context).getString(key, fallback) ?: fallback

/**
 * 色（ARGB）を読む。
 *
 * **Dartのintは32bitに収まらないとlongとして保存される**。ARGBは不透明色 なら必ず0x80000000以上（例：0xFFFF5C7A =
 * 4294925434）になり、Int32の 範囲を超えるため、home_widgetは`putLong`で書く。`getInt`だけで読むと
 * 常にClassCastExceptionになり、**背景色の設定が一度も反映されない**。 longとintの両方を見て、下位32bitをそのままARGBとして解釈する。
 */
internal fun prefColor(context: Context, key: String, fallback: Int): Int {
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
 * 決めて`SharedPreferences`へ書いたものをそのまま使う。ネイティブ側で ルートを組み立てるとDartと二重管理になり、片方の変更に気付けないため。
 */
internal fun launchIntent(context: Context, route: String): PendingIntent {
    val intent =
        Intent(context, MainActivity::class.java).apply {
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
internal const val FALLBACK_BACKGROUND = 0xFFFF5C7A.toInt()

/** アイコン・文字の既定色。既定テーマの「メニュー背景色」＝白で、 アクセント色の背景の上でいちばん読みやすい。 */
internal const val FALLBACK_FOREGROUND = 0xFFFFFFFF.toInt()

/**
 * アプリが書き出したPNGを読む。パスが空・ファイルが無い・デコードに失敗 （書き込み途中のファイルを読んだ等）のいずれでもnullを返し、呼び出し側で フォールバック表示へ倒せるようにする。
 */
internal fun decodeWidgetBitmap(path: String): Bitmap? {
    if (path.isEmpty()) return null
    val file = File(path)
    if (!file.exists()) return null
    return BitmapFactory.decodeFile(file.absolutePath)
}

/** 好きな作品のフレーム1枚を出し、タップでその作品を開くウィジェット。 */
class NiarimArtworkWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val background = prefColor(context, "backgroundColor_artwork", FALLBACK_BACKGROUND)
        val route = prefString(context, "routeArtwork", "/")
        val name = prefString(context, "projectName")
        val thumbnail = prefString(context, "thumbnailPath")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_artwork)
            views.setInt(R.id.widget_root, "setBackgroundColor", background)
            views.setTextViewText(R.id.widget_title, name)
            // 作品が未選択・サムネイル未生成でも空のウィジェットにしない
            // （選び直せるようアプリは開ける状態にしておく）。
            val bitmap = decodeWidgetBitmap(thumbnail)
            if (bitmap != null) views.setImageViewBitmap(R.id.widget_image, bitmap)
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, route))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/**
 * ショートカット系ウィジェットの共通処理。
 *
 * ## 見た目はアプリ側が焼いた画像
 *
 * 「起動画面にある2つのボタンと同じデザイン」（角丸＋2色グラデーション＋ 影＋Materialアイコン＋見出しフォントKuramubon）は、`RemoteViews`では
 * どれも指定できない。`setBackgroundColor`は単色しか受け付けず、 `GradientDrawable`はリソースに静的に書いた色しか使えず、`setTypeface`は
 * assetのフォントを読めない。そのため意匠はアプリ側 （`shortcut_widget_renderer.dart`）が1枚のPNGへ焼き、ここではその画像を
 * `fitCenter`で出すだけにしている。
 *
 * 画像がまだ無いとき（アプリを一度も起動せずにウィジェットを置いた等）は、 従来どおりアイコン＋ラベル＋単色背景へ倒す。
 *
 * **privateにしないこと**。サブクラスはマニフェストの`<receiver>`から クラス名で参照されるため必ずpublicで、Kotlinは「publicなサブクラスが
 * private/internalな親クラスを露出する」ことを禁じている （`'public' subclass exposes its 'private-in-file'
 * supertype`）。
 */
abstract class ShortcutWidgetProvider : AppWidgetProvider() {
    abstract val colorKey: String
    abstract val foregroundKey: String
    abstract val imageKey: String
    abstract val wideImageKey: String
    abstract val tallImageKey: String
    abstract val routeKey: String
    abstract val fallbackRoute: String
    abstract val labelResId: Int
    abstract val iconResId: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val background = prefColor(context, colorKey, FALLBACK_BACKGROUND)
        val foreground = prefColor(context, foregroundKey, FALLBACK_FOREGROUND)
        val route = prefString(context, routeKey, fallbackRoute)
        for (id in appWidgetIds) {
            // 意匠は正方形・横長・縦長の3通りが焼かれている。実際に置かれた
            // マスの縦横比に近いものを選ぶと、fitCenterでも余白が最小になる。
            val design =
                decodeWidgetBitmap(prefString(context, imageKeyFor(context, appWidgetManager, id)))
            val views = RemoteViews(context.packageName, R.layout.widget_shortcut)
            if (design != null) {
                // 画像自体が角丸・グラデーション・影を持つので、土台は
                // 透明にしないと画像の外側に四角い色板が残ってしまう。
                views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                views.setImageViewBitmap(R.id.widget_image, design)
                views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                views.setViewVisibility(R.id.widget_fallback, View.GONE)
            } else {
                views.setInt(R.id.widget_root, "setBackgroundColor", background)
                views.setViewVisibility(R.id.widget_image, View.GONE)
                views.setViewVisibility(R.id.widget_fallback, View.VISIBLE)
                views.setTextViewText(R.id.widget_label, context.getString(labelResId))
                views.setTextColor(R.id.widget_label, foreground)
                views.setImageViewResource(R.id.widget_icon, iconResId)
                views.setInt(R.id.widget_icon, "setColorFilter", foreground)
            }
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, route))
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /**
     * リサイズされたら意匠を選び直す。
     *
     * `onUpdate`はリサイズでは呼ばれない（`updatePeriodMillis`と明示的な 更新要求のときだけ）ため、これが無いと横長へ広げても正方形の画像が
     * 中央に小さく残ったままになる。
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    /**
     * このウィジェットが今どのくらいの縦横比で置かれているかから、読むべき 画像のキーを決める。
     *
     * `getAppWidgetOptions()`は縦向き・横向きそれぞれの想定サイズを返す
     * （縦向きでは幅がMIN_WIDTH・高さがMAX_HEIGHT、横向きでは幅がMAX_WIDTH・ 高さがMIN_HEIGHT）ので、今の画面の向きに合う組を使う。値が取れない
     * 端末・ランチャーでは正方形へ倒す。
     */
    private fun imageKeyFor(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): String {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val landscape =
            context.resources.configuration.orientation ==
                android.content.res.Configuration.ORIENTATION_LANDSCAPE
        val width =
            options.getInt(
                if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
                else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
            )
        val height =
            options.getInt(
                if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            )
        if (width <= 0 || height <= 0) return imageKey
        val ratio = width.toFloat() / height.toFloat()
        // 正方形(1.0)と横長(2.0)・縦長(0.5)の対数中点で切り替える。
        return when {
            ratio >= 1.41f -> wideImageKey
            ratio <= 0.71f -> tallImageKey
            else -> imageKey
        }
    }
}

/** ワンタップで「作品をつくる」へ。 */
class NiarimCreateWidgetProvider : ShortcutWidgetProvider() {
    override val colorKey = "backgroundColor_create"
    override val foregroundKey = "foregroundColor_create"
    override val imageKey = "shortcutImage_create"
    override val wideImageKey = "shortcutImageWide_create"
    override val tallImageKey = "shortcutImageTall_create"
    override val routeKey = "routeCreate"
    override val fallbackRoute = "/new-project"
    override val labelResId = R.string.widget_create_label
    override val iconResId = R.drawable.ic_widget_create
}

/** ワンタップで「作品広場」へ。 */
class NiarimPlazaWidgetProvider : ShortcutWidgetProvider() {
    override val colorKey = "backgroundColor_plaza"
    override val foregroundKey = "foregroundColor_plaza"
    override val imageKey = "shortcutImage_plaza"
    override val wideImageKey = "shortcutImageWide_plaza"
    override val tallImageKey = "shortcutImageTall_plaza"
    override val routeKey = "routePlaza"
    override val fallbackRoute = "/community"
    override val labelResId = R.string.widget_plaza_label
    override val iconResId = R.drawable.ic_widget_plaza
}
