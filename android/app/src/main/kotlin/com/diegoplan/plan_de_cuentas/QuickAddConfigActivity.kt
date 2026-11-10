package com.diegoplan.plan_de_cuentas

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * Pantalla de configuración del widget. Se muestra al agregar uno a la pantalla de inicio.
 * Cada instancia del widget guarda su acción elegida por clave `AppWidgetId`.
 */
class QuickAddConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Resultado por defecto en cancelado por si el usuario presiona atrás.
        appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        setResult(RESULT_CANCELED)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#10131A"))
            setPadding(dp(24), dp(32), dp(24), dp(24))
        }

        val title = TextView(this).apply {
            text = "¿Qué quieres hacer con este widget?"
            setTextColor(Color.WHITE)
            textSize = 20f
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(title, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        val subtitle = TextView(this).apply {
            text = "Elige la acción que ejecutará al tocarlo."
            setTextColor(Color.parseColor("#9AA3B2"))
            textSize = 13f
            setPadding(0, dp(6), 0, dp(18))
        }
        root.addView(subtitle, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        for ((action, label) in QuickAddAction.all) {
            val btn = Button(this).apply {
                text = label
                setTextColor(Color.parseColor("#10131A"))
                setBackgroundColor(Color.parseColor("#0F9D58"))
                textSize = 15f
                isAllCaps = false
                setOnClickListener { chooseAction(action) }
            }
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(54),
            ).apply { bottomMargin = dp(12) }
            root.addView(btn, params)
        }

        val scroll = ScrollView(this).apply { addView(root) }
        setContentView(scroll)
    }

    private fun chooseAction(action: String) {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Toast.makeText(this, "Widget inválido", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        val prefs = getSharedPreferences(QuickAddAction.PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(QuickAddAction.prefKey(appWidgetId), action).apply()

        val manager = AppWidgetManager.getInstance(this)
        QuickAddWidgetProvider.updateWidget(this, manager, appWidgetId)

        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, result)
        Toast.makeText(
            this,
            "Widget configurado: ${QuickAddAction.labelOf(action)}",
            Toast.LENGTH_SHORT,
        ).show()
        finish()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
