import 'package:flutter/material.dart';

import '../screens/biometric_lock_screen.dart';
import '../services/biometric_service.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    BiometricService.instance.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BiometricService.instance,
      builder: (context, _) {
        final bio = BiometricService.instance;
        return Stack(
          children: [
            widget.child,
            if (bio.isAppLocked)
              Positioned.fill(
                child: BiometricLockScreen(
                  onUnlocked: () {
                    bio.unlockApp();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
