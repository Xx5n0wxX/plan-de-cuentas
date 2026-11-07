import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/modular_models.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import 'dashboard_view.dart';
import 'erika_view.dart';
import 'fiado_view.dart';
import 'modular_views.dart';
import 'settings_view.dart';
import 'transactions_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedRoute = 'dashboard';
  StreamSubscription<bool>? _revocationSub;

  @override
  void initState() {
    super.initState();
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
    });
  }

  Future<void> _checkInAppUpdates() async {
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
      case 'modules_hub':
        return ModulesHubView(onOpenModule: _navigateToRoute);
      case 'settings':
        return const SettingsView();
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

    // Construir lista de rutas activas para escritorio
    final activeModuleMetas = AppModuleMeta.catalog
        .where((m) => provider.isModuleActive(m.id))
        .toList();

    final desktopRoutes = <String>[
      'dashboard',
      ...activeModuleMetas.map((m) => m.id),
      'modules_hub',
      'settings',
    ];

    if (!desktopRoutes.contains(_selectedRoute)) {
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
                      ...activeModuleMetas.map(
                        (m) => NavigationRailDestination(
                          icon: Icon(m.icon),
                          selectedIcon: Icon(m.selectedIcon),
                          label: Text(m.shortLabel),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          label: Text('${activeModuleMetas.length}'),
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

    // DISEÑO MÓVIL: Barra inferior compacta con acceso a Inicio, Movimientos, Módulos y Ajustes
    final mobilePrimaryRoutes = <String>[
      'dashboard',
      AppModuleId.monthlyFlow,
      if (provider.isModuleActive(AppModuleId.openAccounts))
        AppModuleId.openAccounts
      else if (provider.isModuleActive(AppModuleId.loans))
        AppModuleId.loans,
      'modules_hub',
      'settings',
    ];

    int mobileIndex = mobilePrimaryRoutes.indexOf(_selectedRoute);
    if (mobileIndex == -1) {
      // Si está viendo un módulo abierto desde el hub de Módulos, resaltar "Módulos"
      mobileIndex = mobilePrimaryRoutes.indexOf('modules_hub');
    }

    return Scaffold(
      body: _buildScreenForRoute(_selectedRoute),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex < 0 ? 0 : mobileIndex,
        onDestinationSelected: (idx) =>
            _navigateToRoute(mobilePrimaryRoutes[idx]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          if (mobilePrimaryRoutes.contains(AppModuleId.openAccounts))
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Libretas',
            )
          else if (mobilePrimaryRoutes.contains(AppModuleId.loans))
            const NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: 'Préstamos',
            ),
          NavigationDestination(
            icon: Badge(
              label: Text('${activeModuleMetas.length}'),
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
