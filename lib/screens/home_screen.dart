import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/modular_models.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/ota_restart_dialog.dart';
import '../widgets/quick_action_bottom_sheet.dart';
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

    // Rutas base para escritorio
    final desktopRoutes = <String>[
      'dashboard',
      'debts_hub',
      'plans_hub',
      'modules_hub',
      'settings',
    ];

    if (!desktopRoutes.contains(_selectedRoute) &&
        !AppModuleMeta.catalog.any((m) => m.id == _selectedRoute)) {
      _selectedRoute = 'dashboard';
    }

    if (isDesktop) {
      final selectedIdx = desktopRoutes.indexOf(_selectedRoute);
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
                    selectedIndex: selectedIdx < 0 ? 0 : selectedIdx,
                    onDestinationSelected: (index) =>
                        _navigateToRoute(desktopRoutes[index]),
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
                        icon: Icon(Icons.account_balance_outlined),
                        selectedIcon: Icon(Icons.account_balance),
                        label: Text('Compromisos'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.savings_outlined),
                        selectedIcon: Icon(Icons.savings),
                        label: Text('Metas'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          label: Text('${provider.activeModules.length + 1}'),
                          child: const Icon(Icons.widgets_outlined),
                        ),
                        selectedIcon: const Icon(Icons.widgets),
                        label: const Text('Módulos'),
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

    // DISEÑO MÓVIL: 5 Pestañas Principales + Botón Flotante Central (+)
    final mobilePrimaryRoutes = <String>[
      'dashboard',
      'debts_hub',
      'plans_hub',
      'modules_hub',
      'settings',
    ];

    int mobileIndex = mobilePrimaryRoutes.indexOf(_selectedRoute);
    if (mobileIndex == -1) {
      if (_selectedRoute == AppModuleId.loans ||
          _selectedRoute == AppModuleId.openAccounts ||
          _selectedRoute == AppModuleId.creditCards ||
          _selectedRoute == AppModuleId.receivables) {
        mobileIndex = 1; // Compromisos
      } else if (_selectedRoute == AppModuleId.savingsGoals ||
          _selectedRoute == AppModuleId.sharedExpenses ||
          _selectedRoute == AppModuleId.subscriptions) {
        mobileIndex = 2; // Metas
      } else if (_selectedRoute == AppModuleId.monthlyFlow ||
          _selectedRoute == AppModuleId.dailyBudget ||
          _selectedRoute == AppModuleId.shoppingList) {
        mobileIndex = 3; // Módulos
      } else {
        mobileIndex = 0; // Inicio
      }
    }

    return Scaffold(
      body: _buildScreenForRoute(_selectedRoute),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickActionBottomSheet.show(
          context,
          onNavigate: _navigateToRoute,
        ),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        tooltip: 'Acciones Rápidas (+)',
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (idx) =>
            _navigateToRoute(mobilePrimaryRoutes[idx]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Compromisos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${provider.activeModules.length + 1}'),
              child: const Icon(Icons.widgets_outlined),
            ),
            selectedIcon: const Icon(Icons.widgets),
            label: 'Módulos',
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
