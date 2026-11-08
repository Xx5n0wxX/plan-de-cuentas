import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/finance_provider.dart';
import 'screens/auth_wrapper.dart';
import 'services/biometric_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CL', null);
  try {
    await LocalNotificationService.instance.init();
  } catch (e) {
    debugPrint('Local notifications init notice: $e');
  }

  try {
    await BiometricService.instance.init();
  } catch (e) {
    debugPrint('Biometric init notice: $e');
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initializeApp info/error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider.value(value: BiometricService.instance),
      ],
      child: const PlanDeCuentasApp(),
    ),
  );
}

class PlanDeCuentasApp extends StatelessWidget {
  const PlanDeCuentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return MaterialApp(
      title: 'Plan de Cuentas',
      debugShowCheckedModeBanner: false,
      themeMode: provider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        if (isAndroid) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.black,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: ColoredBox(
              color: Colors.black,
              child: SafeArea(
                top: true,
                bottom: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: const AuthWrapper(),
    );
  }
}
