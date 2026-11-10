package com.diegoplan.plan_de_cuentas

/**
 * Clave única por acción quick-add que usa el overlay y el buzon pendiente.
 * El valor debe coincidir exactamente con el switch de `_consumePendingQuickAdd()` en Dart.
 */
object QuickAddAction {
    const val ADD_SHOPPING_ITEM = "add_shopping_item"
    const val ADD_FIADO = "add_fiado"
    const val ADD_TRANSACTION = "add_transaction"
    const val ADD_CREDIT_CARD_PAYMENT = "add_credit_card_payment"
    const val ADD_SAVINGS_DEPOSIT = "add_savings_deposit"
    const val ADD_ANT_EXPENSE = "add_ant_expense"

    /** Opciones visibles en la configuración del widget (en orden). */
    val all: List<Pair<String, String>> = listOf(
        ADD_SHOPPING_ITEM to "Lista de Compras",
        ADD_FIADO to "Libretas / Fiado",
        ADD_TRANSACTION to "Transacción Rápida",
        ADD_CREDIT_CARD_PAYMENT to "Pago Tarjeta",
        ADD_SAVINGS_DEPOSIT to "Meta de Ahorro",
        ADD_ANT_EXPENSE to "Gasto Hormiga",
    )

    fun labelOf(action: String?): String =
        all.firstOrNull { it.first == action }?.second ?: "Ingreso rápido"

    const val PREF_NAME = "QuickAddPrefs"
    fun prefKey(appWidgetId: Int) = "action_$appWidgetId"

    const val EXTRA_ACTION_ID = "quick_add_action_id"
    const val EXTRA_APP_WIDGET_ID = "quick_add_app_widget_id"
    const val CLICK_ACTION = "com.diegoplan.plan_de_cuentas.QUICK_ADD_WIDGET_CLICK"
}
