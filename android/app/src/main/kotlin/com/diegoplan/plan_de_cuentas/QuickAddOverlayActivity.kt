package com.diegoplan.plan_de_cuentas

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant

/**
 * Pantalla nativa de ingreso rápido estilo "bottom sheet". No abre la app principal;
 * al guardar, acumula la entrada en `pending_quick_add.json` y cierra.
 * Flutter la consume al próximo arranque desde `_consumePendingQuickAdd()`.
 */
class QuickAddOverlayActivity : Activity() {

    private lateinit var action: String

    private lateinit var amountInput: EditText
    private lateinit var titleInput: EditText
    private lateinit var categorySpinner: Spinner

    private var transactionTypeIsIncome = false
    private var transactionTypeButtons: Pair<Button, Button>? = null
    private var cards: List<Pair<String, String>> = emptyList()
    private var goals: List<Pair<String, String>> = emptyList()
    private var antCategories: List<Pair<String, String>> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        action = intent.getStringExtra(QuickAddAction.EXTRA_ACTION_ID)
            ?: QuickAddAction.ADD_SHOPPING_ITEM

        loadMeta()

        val root = buildUi()
        setContentView(root)

        // Teclado listo para el monto/nombre.
        (amountInput.takeIf { it.isEnabled } ?: titleInput).requestFocus()
        root.post { showKeyboard() }
    }

    // ---------------------------------------------------------------------
    // UI
    // ---------------------------------------------------------------------

    private fun buildUi(): View {
        val cardBg = Color.parseColor("#1C212B")
        val accent = Color.parseColor("#0F9D58")
        val muted = Color.parseColor("#9AA3B2")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#80000000"))
            setPadding(dp(16), dp(80), dp(16), dp(24))
            gravity = Gravity.CENTER_HORIZONTAL
            setOnClickListener { finish() }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(cardBg)
            setPadding(dp(18), dp(16), dp(18), dp(16))
            setOnClickListener { /* prevent dismissal when touching card */ }
        }
        val cardParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )

        // Encabezado: acción + cerrar
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = QuickAddAction.labelOf(action)
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(typeface, Typeface.BOLD)
        }
        val close = TextView(this).apply {
            text = "✕"
            setTextColor(muted)
            textSize = 22f
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dp(12), dp(4), dp(12), dp(4))
            setOnClickListener { finish() }
        }
        header.addView(title, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(close)
        card.addView(header)

        // Campos según la acción
        addBody(card, muted)
        // Acciones de selección (tarjetas/metas/categorías) o notas comunes
        addSecondary(card, muted)

        // Footer: Cancelar / Guardar
        val footerSpacing = dp(12)
        val cancel = Button(this).apply {
            text = "Cancelar"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#2A303B"))
            setOnClickListener { finish() }
        }
        val save = Button(this).apply {
            text = "Guardar"
            setTextColor(Color.parseColor("#0A0F0D"))
            setBackgroundColor(accent)
            setTypeface(typeface, Typeface.BOLD)
            setOnClickListener { save() }
        }
        val footer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, footerSpacing, 0, 0)
        }
        val half = LinearLayout.LayoutParams(0, dp(50), 1f).apply { rightMargin = dp(8) }
        footer.addView(cancel, half)
        footer.addView(save, LinearLayout.LayoutParams(0, dp(50), 1f))
        card.addView(footer)

        root.addView(card, cardParams)
        return root
    }

    private fun addBody(card: LinearLayout, muted: Int) {
        val amountNeeded = action != QuickAddAction.ADD_SHOPPING_ITEM

        // Campo principal de monto (no aplica a shopping)
        amountInput = EditText(this).apply {
            if (amountNeeded) {
                hint = if (action == QuickAddAction.ADD_TRANSACTION) "Monto" else "Monto"
                inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                setSingleLine(true)
                textSize = 24f
            } else {
                visibility = View.GONE
            }
            setTextColor(Color.WHITE)
            setHintTextColor(muted)
        }
        card.addView(amountInput, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        // Campo de texto: título / producto
        titleInput = EditText(this).apply {
            hint = when (action) {
                QuickAddAction.ADD_SHOPPING_ITEM -> "Producto (ej. Leche entera)"
                QuickAddAction.ADD_ANT_EXPENSE -> "Detalle (qué fue)"
                QuickAddAction.ADD_TRANSACTION -> "Descripción (ej. Almuerzo)"
                QuickAddAction.ADD_FIADO -> "Detalle (opcional)"
                else -> "Detalle"
            }
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            setSingleLine(true)
            setTextColor(Color.WHITE)
            setHintTextColor(muted)
        }
        card.addView(titleInput, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
    }

    private fun addSecondary(card: LinearLayout, muted: Int) {
        val label = TextView(this).apply {
            text = "Categoría / Selección"
            setTextColor(muted)
            textSize = 12f
            setPadding(0, dp(14), 0, dp(4))
        }

        when (action) {
            QuickAddAction.ADD_TRANSACTION -> {
                buildTypeToggle(card, muted)
                val items = listOf(
                    "General", "Alimentación", "Transporte", "Salud",
                    "Ocio", "Servicios", "Educación", "Hogar", "Ingresos", "Otros",
                )
                categorySpinner = buildPlainSpinner(items, muted)
                card.addView(label)
                card.addView(categorySpinner)
            }
            QuickAddAction.ADD_ANT_EXPENSE -> {
                antCategories = loadPairs("antCategories")
                if (antCategories.isEmpty()) {
                    antCategories = listOf("widget-default" to "General")
                }
                categorySpinner = buildPairSpinner(antCategories, muted)
                card.addView(emphasizeLabel("Categoría"))
                card.addView(categorySpinner)
            }
            QuickAddAction.ADD_CREDIT_CARD_PAYMENT -> {
                cards = loadPairs("cards")
                categorySpinner = buildPairSpinner(
                    cards.ifEmpty { listOf("" to "— Sin tarjetas —") },
                    muted,
                )
                card.addView(emphasizeLabel("Tarjeta"))
                card.addView(categorySpinner)
                if (cards.isEmpty()) warnNeedApp()
            }
            QuickAddAction.ADD_SAVINGS_DEPOSIT -> {
                goals = loadPairs("goals")
                categorySpinner = buildPairSpinner(
                    goals.ifEmpty { listOf("" to "— Sin metas —") },
                    muted,
                )
                card.addView(emphasizeLabel("Meta"))
                card.addView(categorySpinner)
                if (goals.isEmpty()) warnNeedApp()
            }
        }
    }

    private fun buildTypeToggle(parent: LinearLayout, muted: Int) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(10), 0, 0)
        }
        val btnG = Button(this).apply {
            text = "Gasto"
            isAllCaps = false
            setOnClickListener { transactionTypeIsIncome = false; syncTypeToggle() }
        }
        val btnI = Button(this).apply {
            text = "Ingreso"
            isAllCaps = false
            setOnClickListener { transactionTypeIsIncome = true; syncTypeToggle() }
        }
        val half = LinearLayout.LayoutParams(0, dp(46), 1f)
        row.addView(btnG, half)
        row.addView(btnI, half)
        parent.addView(row)
        transactionTypeButtons = btnG to btnI
        syncTypeToggle()
    }

    private fun syncTypeToggle() {
        val (g, i) = transactionTypeButtons ?: return
        val dark = Color.parseColor("#0F9D58")
        val muted = Color.parseColor("#2A303B")
        if (transactionTypeIsIncome) {
            g.setBackgroundColor(muted); i.setBackgroundColor(dark)
        } else {
            g.setBackgroundColor(dark); i.setBackgroundColor(muted)
        }
    }

    private fun emphasizeLabel(text: String): TextView = TextView(this).apply {
        this.text = text
        setTextColor(Color.parseColor("#9AA3B2"))
        textSize = 12f
        setPadding(0, dp(14), 0, dp(4))
    }

    private fun buildPlainSpinner(items: List<String>, muted: Int): Spinner {
        val spinner = Spinner(this)
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, items)
        spinner.adapter = adapter
        spinner.setBackgroundColor(Color.parseColor("#2A303B"))
        return spinner
    }

    private fun buildPairSpinner(items: List<Pair<String, String>>, muted: Int): Spinner {
        val spinner = Spinner(this)
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            items.map { it.second },
        )
        spinner.adapter = adapter
        spinner.setBackgroundColor(Color.parseColor("#2A303B"))
        return spinner
    }

    private fun warnNeedApp() {
        // Aviso global en el formulario: el usuario no tiene datos sincronizados todavía.
        val warn = TextView(this).apply {
            text = "Consejo: abre la app alguna vez para sincronizar tus tarjetas, metas y categorías."
            setTextColor(Color.parseColor("#E0B84B"))
            textSize = 11f
            setPadding(0, dp(8), 0, 0)
        }
        (amountInput.parent as? LinearLayout)?.addView(warn)
    }

    // ---------------------------------------------------------------------
    // Datos (pending_quick_add.json / quick_add_meta.json)
    // ---------------------------------------------------------------------

    private fun loadMeta() {
        val candidates = listOf(
            File(filesDir, "quick_add_meta.json"),
            File(File(filesDir.parentFile, "app_flutter"), "quick_add_meta.json")
        )
        val file = candidates.firstOrNull { it.exists() } ?: return
        try {
            val json = JSONObject(file.readText())
            cards = pairsFrom(json.optJSONArray("cards"), "cards")
            goals = pairsFrom(json.optJSONArray("goals"), "goals")
            antCategories = pairsFrom(json.optJSONArray("antCategories"), "antCategories")
        } catch (_: Exception) {
            // Meta inválida: overlay funciona pero los selectores quedan vacíos.
        }
    }

    private fun loadPairs(key: String): List<Pair<String, String>> = when (key) {
        "cards" -> cards
        "goals" -> goals
        else -> antCategories
    }

    private fun pairsFrom(array: JSONArray?, @Suppress("UNUSED_PARAMETER") key: String): List<Pair<String, String>> {
        if (array == null) return emptyList()
        val out = mutableListOf<Pair<String, String>>()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val id = item.optString("id").takeIf { it.isNotEmpty() } ?: continue
            val name = item.optString("name").ifEmpty { "Sin nombre" }
            out.add(id to name)
        }
        return out
    }

    private fun save() {
        val titleText = titleInput.text?.toString()?.trim().orEmpty()
        val amount = parseAmount(amountInput.text?.toString())

        val needsAmount = action != QuickAddAction.ADD_SHOPPING_ITEM
        if (needsAmount && amount <= 0.0) {
            toast("Ingresa un monto mayor a 0")
            return
        }
        if (action == QuickAddAction.ADD_SHOPPING_ITEM && titleText.isEmpty()) {
            toast("Escribe el producto")
            return
        }

        val fields = JSONObject()
        when (action) {
            QuickAddAction.ADD_SHOPPING_ITEM -> {
                fields.put("title", titleText)
                fields.put("note", titleText)
                fields.put("amount", 0.0)
            }
            QuickAddAction.ADD_FIADO -> {
                fields.put("amount", amount)
                fields.put("note", titleText)
            }
            QuickAddAction.ADD_TRANSACTION -> {
                fields.put("amount", amount)
                fields.put("type", if (transactionTypeIsIncome) "income" else "expense")
                fields.put("category", selectedLabel())
                fields.put("title", titleText.ifEmpty { "Transacción rápida" })
                fields.put("note", titleText)
            }
            QuickAddAction.ADD_CREDIT_CARD_PAYMENT -> {
                fields.put("amount", amount)
                fields.put("cardId", selectedPair(cards).first.ifEmpty { "" })
                fields.put("note", titleText)
            }
            QuickAddAction.ADD_SAVINGS_DEPOSIT -> {
                fields.put("amount", amount)
                fields.put("goalId", selectedPair(goals).first.ifEmpty { "" })
                fields.put("note", titleText)
            }
            QuickAddAction.ADD_ANT_EXPENSE -> {
                val (categoryId, categoryName) = selectedPair(antCategories)
                fields.put("amount", amount)
                fields.put("categoryId", categoryId)
                fields.put("categoryName", categoryName)
                fields.put("title", titleText.ifEmpty { categoryName })
                fields.put("note", titleText)
            }
        }

        appendPending(action, fields)
        toast("Guardado pendiente; se aplicará al abrir Plan de Cuentas")
        finish()
    }

    private fun selectedLabel(): String {
        val spinner = categorySpinner
        if (!::categorySpinner.isInitialized) return "General"
        return spinner.selectedItem?.toString() ?: "General"
    }

    private fun selectedPair(pairs: List<Pair<String, String>>): Pair<String, String> {
        if (!::categorySpinner.isInitialized) return "" to ""
        val idx = categorySpinner.selectedItemPosition.coerceAtLeast(0)
        return pairs.getOrElse(idx) { "" to "" }
    }

    private fun parseAmount(raw: String?): Double {
        if (raw.isNullOrBlank()) return 0.0
        return raw.replace(",", ".").replace(" ", "").toDoubleOrNull() ?: 0.0
    }

    private fun appendPending(actionValue: String, fields: JSONObject) {
        val candidates = listOf(
            File(filesDir, "pending_quick_add.json"),
            File(File(filesDir.parentFile, "app_flutter"), "pending_quick_add.json")
        )
        val entries = JSONArray()
        for (f in candidates) {
            try {
                if (f.exists()) {
                    val raw = f.readText().trim()
                    if (raw.isNotEmpty()) {
                        val decoded = JSONObject(raw)
                        val list = decoded.optJSONArray("entries")
                        if (list != null && list.length() > 0) {
                            for (i in 0 until list.length()) entries.put(list.getJSONObject(i))
                            break
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }

        val entry = JSONObject()
        entry.put("action", actionValue)
        entry.put("fields", fields)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            entry.put("queuedAt", Instant.now().toEpochMilli())
        } else {
            entry.put("queuedAt", System.currentTimeMillis())
        }
        entries.put(entry)

        val doc = JSONObject()
        doc.put("version", 1)
        doc.put("entries", entries)
        val payload = doc.toString()

        for (f in candidates) {
            try {
                val parent = f.parentFile
                if (parent != null && !parent.exists()) parent.mkdirs()
                f.writeText(payload)
            } catch (_: Exception) {
            }
        }
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun showKeyboard() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        val target = amountInput.takeIf { it.isEnabled } ?: titleInput
        imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
