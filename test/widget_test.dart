import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plan_de_cuentas/main.dart';
import 'package:plan_de_cuentas/providers/auth_provider.dart';
import 'package:plan_de_cuentas/providers/finance_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es_CL', null);
  });

  testWidgets('Desktop mode strictly enforces QR-only access without Google/Guest login', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ],
        child: const PlanDeCuentasApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Desktop QR-Only Lock is displayed and direct login buttons are absent
    expect(find.textContaining('Modo Escritorio Protegido'), findsOneWidget);
    expect(find.text('Esperando escaneo desde tu celular...'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsNothing);
    expect(find.text('Usar en modo local (sin cuenta)'), findsNothing);
  });

  testWidgets('Mobile mode renders login screen and allows entry to clean HomeScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ],
        child: const PlanDeCuentasApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Mobile Login Screen appears with Google Button
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Usar en modo local (sin cuenta)'), findsOneWidget);

    // Tap "Usar en modo local"
    final guestBtn = find.text('Usar en modo local (sin cuenta)');
    await tester.ensureVisible(guestBtn);
    await tester.tap(guestBtn);
    await tester.pumpAndSettle();

    // Now Home Screen appears in clean zero state
    expect(find.text('Saldo Disponible Real'), findsOneWidget);
    expect(find.text('Compromisos y Deudas'), findsWidgets);
  });
}
