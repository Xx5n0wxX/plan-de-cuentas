import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:plan_de_cuentas/screens/biometric_lock_screen.dart';
import 'package:plan_de_cuentas/services/biometric_service.dart';
import 'package:plan_de_cuentas/widgets/app_lock_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BiometricService.testDeviceSupported = true;
    BiometricService.testCanCheckBiometrics = true;
    BiometricService.testAvailableBiometrics = [BiometricType.fingerprint];
    BiometricService.testAuthSuccess = null;

    final bio = BiometricService.instance;
    await bio.init();
    await bio.setLockEnabled(false);
    await bio.setCustomPin(null);
  });

  group('BiometricService Unit Tests', () {
    test('Initialization defaults', () async {
      final bio = BiometricService.instance;
      expect(bio.isLockEnabled, isFalse);
      expect(bio.isAppLocked, isFalse);
      expect(bio.hasCustomPin, isFalse);
      expect(bio.biometricTypeDescription, contains('Huella'));
    });

    test('Enable and lock toggle', () async {
      final bio = BiometricService.instance;
      await bio.setLockEnabled(true);
      expect(bio.isLockEnabled, isTrue);

      bio.lockApp();
      expect(bio.isAppLocked, isTrue);

      bio.unlockApp();
      expect(bio.isAppLocked, isFalse);
    });

    test('Custom PIN setup, validation, and unlock', () async {
      final bio = BiometricService.instance;
      await bio.setLockEnabled(true);
      bio.lockApp();
      expect(bio.isAppLocked, isTrue);

      await bio.setCustomPin('4321');
      expect(bio.hasCustomPin, isTrue);

      // Wrong PIN
      expect(bio.verifyCustomPin('0000'), isFalse);
      expect(bio.isAppLocked, isTrue);

      // Correct PIN
      expect(bio.verifyCustomPin('4321'), isTrue);
      expect(bio.isAppLocked, isFalse);
    });

    test('Lifecycle state changes trigger background locking correctly without loop', () async {
      final bio = BiometricService.instance;
      await bio.setLockEnabled(true);
      await bio.setLockOnBackground(true);
      bio.unlockApp();
      expect(bio.isAppLocked, isFalse);

      // Simulate time passed while using app
      bio.lastUnlockTimestamp = DateTime.now().subtract(const Duration(seconds: 10));

      // Simulate normal background and resume: should lock
      bio.handleAppLifecycleState(AppLifecycleState.paused);
      bio.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(bio.isAppLocked, isTrue);

      // Unlock
      bio.unlockApp();
      expect(bio.isAppLocked, isFalse);

      // Immediate resume right after unlock (system biometric prompt dismissal) should NOT lock
      bio.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(bio.isAppLocked, isFalse);

      // If lockOnBackground is disabled, it should not lock
      await bio.setLockOnBackground(false);
      bio.handleAppLifecycleState(AppLifecycleState.paused);
      bio.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(bio.isAppLocked, isFalse);
    });

    test('Biometric authentication mock unlocks app', () async {
      final bio = BiometricService.instance;
      await bio.setLockEnabled(true);
      bio.lockApp();
      expect(bio.isAppLocked, isTrue);

      BiometricService.testAuthSuccess = true;
      final result = await bio.authenticate();
      expect(result, isTrue);
      expect(bio.isAppLocked, isFalse);
    });
  });

  group('Biometric Lock Widgets Tests', () {
    testWidgets('AppLockGate shows child when unlocked and lock screen when locked',
        (tester) async {
      final bio = BiometricService.instance;
      BiometricService.testAuthSuccess = false; // Simulate prompt dismissed/failed
      await bio.setLockEnabled(true);
      bio.lockApp();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: bio),
          ],
          child: const MaterialApp(
            home: AppLockGate(
              child: Scaffold(
                body: Text('Contenido Protegido Dashboard'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lock screen is rendered over child
      expect(find.byType(BiometricLockScreen), findsOneWidget);
      expect(find.text('Desbloquear con Huella'), findsOneWidget);

      // Now unlock
      bio.unlockApp();
      await tester.pumpAndSettle();

      // Lock screen gone, child visible
      expect(find.byType(BiometricLockScreen), findsNothing);
      expect(find.text('Contenido Protegido Dashboard'), findsOneWidget);
    });
  });
}
