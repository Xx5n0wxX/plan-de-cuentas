import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/modular_models.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../services/local_notification_service.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/ota_restart_dialog.dart';
import 'dashboard_view.dart';
import 'debts_hub_view.dart';
import 'erika_view.dart';
import 'fiado_view.dart';
import 'modular_views.dart';
import 'plans_hub_view.dart';
import 'settings_view.dart';
import 'transactions_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedRoute = 'dashboard';
  StreamSubscription<bool>? _revocationSub;
  bool _otaDialogShown = false;
  bool _checkingOta = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app desde segundo plano, revisar si llegó un parche nuevo.
    if (state == AppLifecycleState.resumed) {
      _checkInAppUpdates();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final finance = context.read<FinanceProvider>();
      final vid = auth.vaultId;
      if (auth.isAuthenticated && vid != null && vid.isNotEmpty) {
        finance.startLiveSync(vid, isLinkedDesktop: auth.isLinkedDesktop);

        if (auth.isLinkedDesktop && auth.user?.linkedDeviceId != null) {
          _revocationSub = finance.syncService
              .watchIsDeviceStillLinked(auth.user!.linkedDeviceId!)
              .listen((stillLinked) {
            if (!stillLinked && mounted) {
              finance.stopLiveSync();
              auth.signOut();
            }
          }, onError: (_) {});
        }
      }
      _checkInAppUpdates();
      LocalNotificationService.instance
          .syncAndScheduleReminders(finance)
          .catchError((_) => 0);
    });
  }

  Future<void> _checkInAppUpdates() async {
    // 1. Si Shorebird está activo (Android con motor de parches OTA):
    if (AppUpdateService.isShorebirdAvailable) {
      if (_otaDialogShown || _checkingOta) return;
      _checkingOta = true;
      try {
        // Cubre ambos casos: parche pendiente de descarga, o ya descargado
        // en segundo plano por el motor (auto_update) esperando reinicio.
        final ready = await AppUpdateService.prepareShorebirdPatch();
        if (ready && mounted && !_otaDialogShown) {
          _otaDialogShown = true;
          await showOtaRestartDialog(context);
        }
      } catch (_) {
      } finally {
        _checkingOta = false;
      }
      return;
    }

    // 2. Si no es Shorebird (Windows o Web), usar el flujo tradicional:
    final remote = await AppUpdateService.checkRemoteVersion();
    if (!mounted || remote == null) return;
    if (AppUpdateService.isUpdateAvailable(remote)) {
      _showUpdateModal(remote);
    }
  }

  void _showUpdateModal(AppVersionInfo remote) {
    showDialog(
      context: context,
      barrierDismissible: !remote.forceUpdate,
      builder: (_) => AppUpdateDialog(remote: remote),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revocationSub?.cancel();
    super.dispose();
  }

  void _navigateToRoute(String routeId) {
    setState(() => _selectedRoute = routeId);
  }

  /// pestañas principales (Fase 5): Inicio / Flujo / Deudas / Metas / Ajustes
  static const List<String> _primaryTabRoutes = [
    'dashboard',
    AppModuleId.monthlyFlow,
    'debts_hub',
    'plans_hub',
    'settings',
  ];

  /// rutas extra aceptadas sin ser pestañas (ej. catálogo lanzado desde Ajustes)
  static const List<String> _extraRoutes = ['modules_hub'];

  /// índice de la pestaña que resalta la ruta (home, flujo, hubs y settings)
  int _tabIndexForRoute(String route) {
    if (route == 'dashboard') return 0;
    if (route == AppModuleId.monthlyFlow ||
        route == AppModuleId.dailyBudget ||
        route == AppModuleId.shoppingList) {
      return 1;
    }
    if (route == 'debts_hub' ||
        route == AppModuleId.loans ||
        route == AppModuleId.openAccounts ||
        route == AppModuleId.creditCards ||
        route == AppModuleId.receivables) {
      return 2;
    }
    if (route == 'plans_hub' ||
        route == AppModuleId.savingsGoals ||
        route == AppModuleId.sharedExpenses ||
        route == AppModuleId.subscriptions) {
      return 3;
    }
    return 4; // 'settings' y 'modules_hub'
  }

  Widget _buildScreenForRoute(String routeId) {
    switch (routeId) {
      case 'dashboard':
        return DashboardView(onNavigateToModule: _navigateToRoute);
      case 'debts_hub':
        return DebtsHubView(onOpenModule: _navigateToRoute);
      case 'plans_hub':
        return PlansHubView(onOpenModule: _navigateToRoute);
      case 'modules_hub':
        return ModulesHubView(onOpenModule: _navigateToRoute);
      case 'settings':
        return SettingsView(onNavigateToRoute: _navigateToRoute);
      // Módulos específicos para navegación directa
      case AppModuleId.monthlyFlow:
        return const TransactionsView();
      case AppModuleId.loans:
        return const ErikaView();
      case AppModuleId.openAccounts:
        return const FiadoView();
      case AppModuleId.sharedExpenses:
        return const SharedExpensesModuleView();
      case AppModuleId.receivables:
        return const ReceivablesModuleView();
      case AppModuleId.savingsGoals:
        return const SavingsGoalsModuleView();
      case AppModuleId.subscriptions:
        return const SubscriptionsModuleView();
      case AppModuleId.dailyBudget:
        return const DailyBudgetModuleView();
      case AppModuleId.creditCards:
        return const CreditCardsModuleView();
      case AppModuleId.shoppingList:
        return const ShoppingListModuleView();
      default:
        return DashboardView(onNavigateToModule: _navigateToRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_primaryTabRoutes.contains(_selectedRoute) &&
        !_extraRoutes.contains(_selectedRoute) &&
        !AppModuleMeta.catalog.any((m) => m.id == _selectedRoute)) {
      _selectedRoute = 'dashboard';
    }

    // GATE FOR MODULE ROUTES (Fase 3): cualquier módulo que no esté activo
    // se redirige al Dashboard antes de pintar. ModulesHub/DebtsHub/PlansHub
    // y Settings quedan siempre accesibles.
    if (AppModuleMeta.catalog.any((m) => m.id == _selectedRoute) &&
        !provider.isModuleActive(_selectedRoute)) {
      _selectedRoute = 'dashboard';
    }

    if (isDesktop) {
      final selectedIdx = _tabIndexForRoute(_selectedRoute);
      return Scaffold(
        body: Row(
          children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: selectedIdx,
                    onDestinationSelected: (index) =>
                        _navigateToRoute(_primaryTabRoutes[index]),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet,
                                color: Colors.teal, size: 26),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Plan de Cuentas',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Inicio'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.payments_outlined),
                        selectedIcon: Icon(Icons.payments),
                        label: Text('Flujo'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.account_balance_outlined),
                        selectedIcon: Icon(Icons.account_balance),
                        label: Text('Deudas'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.rocket_launch_outlined),
                        selectedIcon: Icon(Icons.rocket_launch),
                        label: Text('Metas'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Ajustes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _buildScreenForRoute(_selectedRoute),
            ),
          ],
        ),
      );
    }

    // DISEÑO MÓVIL: 4 pestañas de categoría + Ajustes
    final mobileIndex = _tabIndexForRoute(_selectedRoute);

    return Scaffold(
      body: _buildScreenForRoute(_selectedRoute),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (idx) =>
            _navigateToRoute(_primaryTabRoutes[idx]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Flujo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Deudas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch),
            label: 'Metas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
