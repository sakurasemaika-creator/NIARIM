package com.niarim.niarim

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Build
import android.util.Log
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal object CommunityNotices {
    private const val ALL = "push_notifications_enabled"
    private const val ACTIVE_OWNER = "push_notice_owner"
    private const val OWNER_EXTRA = "com.niarim.niarim.NOTICE_OWNER"
    private const val CHANNEL = "niarim_activity_notifications"
    private const val MY_WORKS = "/community/my-works"
    private const val MISSIONS = "/creator-missions"
    private val ownerId = Regex("N[a-f0-9]{32}")
    private val eventId = Regex("[A-Za-z0-9_-]{1,120}")
    private val workId = Regex("[A-Za-z0-9_-]{11}")
    private val workRoute = Regex("/community/work/[A-Za-z0-9_-]{11}")
    private val isoDate = Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{3})?Z")
    private const val DAY_MS = 86_400_000L
    private var database: NoticeDatabase? = null

    private class NoticeDatabase(context: Context) :
        SQLiteOpenHelper(context, "niarim-notice-history.db", null, 2) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE shown (
                    owner TEXT NOT NULL, identity TEXT NOT NULL, created INTEGER NOT NULL,
                    PRIMARY KEY (owner, identity)
                ) WITHOUT ROWID
            """.trimIndent())
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion < 2) db.execSQL("DROP TABLE IF EXISTS first_seen")
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun db(context: Context) =
        (database ?: NoticeDatabase(context.applicationContext).also { database = it }).writableDatabase

    private data class Notice(val category: String?, val body: Int)

    private val notices = mapOf(
        "workPosted" to Notice("publication", R.string.push_work_posted),
        "workPublicationConfirmed" to Notice("publication", R.string.push_work_published),
        "scheduledRelease" to Notice("publication", R.string.push_scheduled_release),
        "mission_achievement" to Notice(null, R.string.push_mission_achievement),
    )

    private fun enabled(context: Context, category: String?): Boolean =
        prefs(context).getBoolean("flutter.$ALL", true) &&
            (category == null || prefs(context).getBoolean("flutter.push_notice_$category", true))

    fun publicationEnabled(context: Context) = enabled(context, "publication")

    private fun date(raw: String): Long? {
        if (!isoDate.matches(raw)) return null
        val pattern = if (raw.contains('.')) "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" else "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return SimpleDateFormat(pattern, Locale.ROOT).apply {
            isLenient = false
            timeZone = TimeZone.getTimeZone("UTC")
        }.parse(raw)?.time
    }

    private fun routeValid(kind: String, route: String) = when (kind) {
        "workPosted" -> route == MY_WORKS
        "mission_achievement" -> route == MISSIONS
        else -> workRoute.matches(route)
    }

    @Synchronized
    fun receive(context: Context, data: Map<String, String>) {
        if (data["niarimNoticeVersion"] != "1") return
        val kind = data["type"] ?: return
        val notice = notices[kind] ?: return
        val owner = data["owner"]?.takeIf(ownerId::matches) ?: return
        if (owner != prefs(context).getString("flutter.$ACTIVE_OWNER", null)) return
        val event = data["eventId"]?.takeIf(eventId::matches) ?: return
        val display = data["displayKey"] ?: return
        if (display != event && !(notice.category == "publication" &&
            display.startsWith("post:") && workId.matches(display.removePrefix("post:")))) return
        val route = data["targetRoute"]?.takeIf { routeValid(kind, it) } ?: return
        try {
            val now = System.currentTimeMillis()
            val whenMs = date(data["occurredAt"] ?: return) ?: return
            if (whenMs <= 0 || whenMs > now + DAY_MS) return
            show(context, owner, display, route, notice, whenMs)
        } catch (error: Exception) {
            Log.w("CommunityNotices", "Notification unavailable: ${error.javaClass.simpleName}")
        }
    }

    @Synchronized
    fun showPost(context: Context, owner: String, work: String, scheduled: Boolean) {
        if (!ownerId.matches(owner) || !workId.matches(work)) return
        val display = if (scheduled) "reserved:$work" else "post:$work"
        val body = if (scheduled) R.string.push_work_reserved else R.string.push_work_posted
        show(context, owner, display, "/community/work/$work", Notice("publication", body),
            System.currentTimeMillis())
    }

    private fun show(context: Context, owner: String, display: String, route: String,
                     notice: Notice, whenMs: Long) {
        if (!enabled(context, notice.category)) return
        val active = prefs(context).getString("flutter.$ACTIVE_OWNER", null)
        if (active != null && active != owner) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, context.getString(R.string.push_activity_channel),
                NotificationManager.IMPORTANCE_DEFAULT
            ))
            if (manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return
        }
        val database = db(context)
        // FCM display receipts only need to outlive its one-day message TTL.
        val now = System.currentTimeMillis()
        database.delete("shown", "created < ?", arrayOf((now - 7 * DAY_MS).toString()))
        val added = database.insertWithOnConflict("shown", null, ContentValues().apply {
            put("owner", owner)
            put("identity", display)
            put("created", now)
        }, SQLiteDatabase.CONFLICT_IGNORE)
        if (added == -1L) return

        val intent = Intent(context, MainActivity::class.java).apply {
            action = "${context.packageName}.NOTICE.$owner.$display"
            putExtra(WIDGET_ROUTE_EXTRA, route)
            putExtra(OWNER_EXTRA, owner)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val configuredLanguage = prefs(context).getString("flutter.language", null)
        val locale = configuredLanguage?.let { Locale.forLanguageTag(it.replace('_', '-')) }
            ?: context.resources.configuration.locales[0]
        val localized = context.createConfigurationContext(
            Configuration(context.resources.configuration).apply { setLocale(locale) },
        )
        val body = localized.getString(notice.body)
        val timestamp = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, locale)
            .format(Date(whenMs))
        val text = "$body · $timestamp"
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else @Suppress("DEPRECATION") Notification.Builder(context)
        manager.notify("niarim.notice.$owner.$display", 0, builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("NIARIM")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setWhen(whenMs)
            .setShowWhen(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build())
    }

    fun tappedRoute(context: Context, intent: Intent?): String? {
        val route = intent?.getStringExtra(WIDGET_ROUTE_EXTRA) ?: return null
        val owner = intent.getStringExtra(OWNER_EXTRA) ?: return route // Existing home widgets.
        return route.takeIf {
            owner == prefs(context).getString("flutter.$ACTIVE_OWNER", null) &&
                (route == MY_WORKS || route == MISSIONS || workRoute.matches(route))
        }
    }

    fun clearOtherAccounts(context: Context, owner: String?) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        for (notice in manager.activeNotifications) {
            val tag = notice.tag ?: continue
            if (tag.startsWith("niarim.notice.") &&
                (owner == null || !tag.startsWith("niarim.notice.$owner."))) {
                manager.cancel(tag, notice.id)
            }
        }
    }
}
