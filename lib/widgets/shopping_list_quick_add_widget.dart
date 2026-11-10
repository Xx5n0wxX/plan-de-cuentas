/// Placeholder durante la Fase 2 (widget nativo de ingreso rápido).
///
/// El widget se implementa en Android de forma nativa
/// (`android/app/src/main/kotlin/.../QuickAddWidgetProvider.kt` y los
/// `layout/quick_add_widget_info.xml`) y el overlay nativo registra sus
/// comandos en `pending_quick_add.json`, que consume
/// [QuickAddInboxService] al arrancar la app.
///
/// Por decisión de alcance, este archivo no añade código a la UI de Flutter;
/// queda aquí como referencia documental para futuras iteraciones.
library;
