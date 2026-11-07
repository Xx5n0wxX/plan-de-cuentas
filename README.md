# Microapp: Plan de Cuentas (Gestión Financiera Personal)

Aplicación multiplataforma (Windows y Android) desarrollada en **Flutter (Dart)** diseñada a medida para reemplazar el mantenimiento manual de planillas de Google Sheets.

---

## 🚀 Funcionalidades Principales

### 1. 🏪 Libreta de Fiado (Negocio de Barrio)
- **Anotar en 3 segundos:** Botón de acceso directo para ingresar compras fiadas del día (monto, fecha y nota opcional).
- **Marcador en tiempo real:** Visualización instantánea del total acumulado y saldo adeudado.
- **Abonos Parciales o Totales:** Permite abonar una parte (ej. pagar \$100.000 de una cuenta de \$146.060), mostrando de inmediato el saldo restante que queda debiendo (\$46.060) y arrastrándolo automáticamente.

### 2. 🔴 Préstamos Erika (Prioridad Alta)
- **Seguimiento Correlativo:** Registro detallado de préstamos (1 al 8 precargados desde la planilla real).
- **Contador de Cuotas (\$X/5\$):** Barra de progreso visual, monto por cuota y saldo total a devolver.
- **Pagar Cuota con 1 Clic:** Descuenta el saldo pendiente, avanza el contador de cuotas y genera el egreso en el balance mensual.

### 3. 💳 Otras Deudas y Familiares
- Seguimiento de préstamos familiares como **Falabella Papá** (cuotas 1/3 de \$50.000) y **Mamá** (\$108.000).

### 4. 📊 Dashboard Inteligente & Alerta de Déficit ("Menos Gastos")
- Selector dinámico de mes y año (sin necesidad de crear hojas nuevas).
- **Alerta de Déficit Financiero:** Si los compromisos superan los ingresos mensuales (como ocurrió en Febrero), emite una advertencia visual destacada.
- Gráfico circular de distribución de gastos por categoría (`fl_chart`).

### 5. 👥 Módulo de Gastos Compartidos (Opcional)
- Desactivado por defecto (modo soltero).
- Puede activarse en cualquier momento desde *Ajustes*, permitiendo personalizar el nombre de la persona (roommate, familiar, etc.) y los porcentajes de división (50/50 o personalizado).

---

## 💻 Cómo Ejecutar y Probar

### En Windows (PC):
1. **Navegador / App Web PWA:**
   Abre [http://localhost:8080](http://localhost:8080) en Chrome o Edge.
   *(Puedes hacer clic en el ícono de instalar en la barra del navegador para usarla como ventana nativa en Windows).*
2. **Modo Desarrollo:**
   ```powershell
   flutter run -d chrome
   ```

### En Android (Móvil):
1. Desde tu celular conectado al mismo Wi-Fi, abre en el navegador:
   `http://192.168.1.2:8080`
   Toca el menú de Chrome y selecciona **"Agregar a la pantalla principal"** o **"Instalar aplicación"**.
2. O compilar APK nativo:
   ```powershell
   flutter build apk
   ```

---

## ☁️ Conexión con Firebase Cloud Firestore
La aplicación implementa persistencia local *Offline-First* inmediata con `shared_preferences`. Para sincronizar entre múltiples dispositivos mediante Firebase:
1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Ejecuta `flutterfire configure` en esta carpeta para vincular las credenciales de tu proyecto.
