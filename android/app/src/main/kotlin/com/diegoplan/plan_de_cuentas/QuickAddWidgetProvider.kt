package com.diegoplan.plan_de_cuentas

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == QuickAddAction.CLICK_ACTION) {
            val actionId = intent.getStringExtra(QuickAddAction.EXTRA_ACTION_ID) ?: return
            val overlay = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, actionId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            try {
                context.startActivity(overlay)
            } catch (_: Exception) {
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences(QuickAddAction.PREF_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (id in appWidgetIds) {
            editor.remove(QuickAddAction.prefKey(id))
        }
        editor.apply()
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val prefs = context.getSharedPreferences(QuickAddAction.PREF_NAME, Context.MODE_PRIVATE)
            val action = prefs.getString(QuickAddAction.prefKey(appWidgetId), null)
                ?: QuickAddAction.ADD_SHOPPING_ITEM

            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)
            views.setTextViewText(R.id.widget_label, QuickAddAction.labelOf(action))

            val overlayIntent = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, action)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pending = PendingIntent.getActivity(
                context,
                appWidgetId,
                overlayIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
