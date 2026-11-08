import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import 'add_fiado_dialog.dart';
import 'add_transaction_dialog.dart';

/// Hoja modal de acciones rápidas activada por el Floating Action Button (+)
class QuickActionBottomSheet extends StatelessWidget {
  final ValueChanged<String>? onNavigate;

  const QuickActionBottomSheet({super.key, this.onNavigate});

  static Future<void> show(
    BuildContext context, {
    ValueChanged<String>? onNavigate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickActionBottomSheet(onNavigate: onNavigate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asa de arrastre
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AppTheme.primaryTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acciones Rápidas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Registra movimientos o apuntes al instante',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Opciones de acción
            _buildActionTile(
              context: context,
              icon: Icons.trending_down_rounded,
              color: Colors.redAccent,
              iconBgColor: Colors.red.shade50,
              iconColor: Colors.red.shade700,
              title: 'Nuevo Gasto',
              subtitle: 'Añadir gasto personal o compartido del mes',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const AddTransactionDialog(
                    initialType: TransactionType.expense,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context: context,
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF10B981),
              iconBgColor: Colors.teal.shade50,
              iconColor: AppTheme.primaryTeal,
              title: 'Nuevo Ingreso',
              subtitle: 'Registrar sueldo, honorarios o abonos',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const AddTransactionDialog(
                    initialType: TransactionType.income,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context: context,
              icon: Icons.storefront_outlined,
              color: Colors.amber.shade700,
              iconBgColor: Colors.amber.shade50,
              iconColor: Colors.amber.shade900,
              title: 'Anotar a la Libreta / Fiado',
              subtitle: 'Registrar compra fiada en almacén de barrio',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const AddFiadoDialog(),
                );
              },
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context: context,
              icon: Icons.shopping_cart_outlined,
              color: Colors.blue.shade600,
              iconBgColor: Colors.blue.shade50,
              iconColor: Colors.blue.shade700,
              title: 'Lista de Compras',
              subtitle: 'Abrir lista inteligente de compras',
              onTap: () {
                Navigator.pop(context);
                if (onNavigate != null) {
                  onNavigate!('shoppingList');
                }
              },
            ),
            const SizedBox(height: 10),

            _buildActionTile(
              context: context,
              icon: Icons.widgets_outlined,
              color: AppTheme.primaryTeal,
              iconBgColor: AppTheme.primaryTeal.withValues(alpha: 0.1),
              iconColor: AppTheme.primaryTeal,
              title: 'Personalizar Módulos (Arma tu Plan)',
              subtitle: 'Activa o desactiva los 10 módulos de la app',
              onTap: () {
                Navigator.pop(context);
                if (onNavigate != null) {
                  onNavigate!('modules_hub');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.25) : iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
