package com.diegoplan.plan_de_cuentas

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

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

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, QuickAddWidgetProvider::class.java)
            ) ?: return
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)

            // Cargar datos financieros más recientes
            val data = loadFinancialData(context)
            val month = data.optString("monthName", "Mes actual")
            val balance = data.optString("balance", "$ 0")
            val income = data.optString("income", "▲ $ 0")
            val expenses = data.optString("expenses", "▼ $ 0")
            val isDeficit = data.optBoolean("isDeficit", false)
            val shoppingBadge = data.optString("shoppingBadge", "🛒 0 items")

            // Poblar textos e indicadores
            views.setTextViewText(R.id.widget_month_badge, month)
            views.setTextViewText(R.id.widget_balance_amount, balance)
            val balanceColor = if (isDeficit) Color.parseColor("#F04438") else Color.parseColor("#12B76A")
            views.setTextColor(R.id.widget_balance_amount, balanceColor)

            views.setTextViewText(R.id.widget_income_text, income)
            views.setTextViewText(R.id.widget_expense_text, expenses)
            views.setTextViewText(R.id.widget_shopping_badge, shoppingBadge)

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // 1. Tocar el cuerpo o cabecera del widget abre la app completa
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val appPending = PendingIntent.getActivity(
                context,
                appWidgetId * 10,
                appIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.widget_header, appPending)
            views.setOnClickPendingIntent(R.id.widget_balance_container, appPending)

            // 2. Botón [- Gasto]: abre overlay para registrar gasto
            val expenseIntent = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, QuickAddAction.ADD_TRANSACTION)
                putExtra("transaction_type", "expense")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val expensePending = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 1,
                expenseIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.btn_quick_expense, expensePending)

            // 3. Botón [+ Ingreso]: abre overlay para registrar ingreso
            val incomeIntent = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, QuickAddAction.ADD_TRANSACTION)
                putExtra("transaction_type", "income")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val incomePending = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 2,
                incomeIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.btn_quick_income, incomePending)

            // 4. Botón [🛒 Lista]: abre overlay para agregar producto a la lista de compras
            val shoppingIntent = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, QuickAddAction.ADD_SHOPPING_ITEM)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val shoppingPending = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 3,
                shoppingIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.btn_quick_shopping, shoppingPending)

            // 5. Botón [📋 Fiado]: abre overlay para registrar en libretas / fiado
            val fiadoIntent = Intent(context, QuickAddOverlayActivity::class.java).apply {
                putExtra(QuickAddAction.EXTRA_ACTION_ID, QuickAddAction.ADD_FIADO)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val fiadoPending = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 4,
                fiadoIntent,
                flags,
            )
            views.setOnClickPendingIntent(R.id.btn_quick_fiado, fiadoPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun loadFinancialData(context: Context): JSONObject {
            val candidates = listOf(
                File(context.filesDir, "widget_financial_data.json"),
                File(File(context.filesDir.parentFile, "app_flutter"), "widget_financial_data.json")
            )
            for (f in candidates) {
                try {
                    if (f.exists()) {
                        val text = f.readText().trim()
                        if (text.isNotEmpty()) return JSONObject(text)
                    }
                } catch (_: Exception) {
                }
            }
            return JSONObject()
        }
    }
}
