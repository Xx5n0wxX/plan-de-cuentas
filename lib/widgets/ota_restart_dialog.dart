import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

/// Diálogo que avisa que hay una actualización rápida (OTA) lista y permite
/// cerrar la app en 1 toque para aplicarla al volver a abrirla.
Future<void> showOtaRestartDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.bolt, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(child: Text('Actualización lista')),
        ],
      ),
      content: const Text(
        'Se descargó una nueva versión de Plan de Cuentas.\n\n'
        'Presiona "Reiniciar ahora": la app se cerrará y, al volver a abrirla, '
        'ya tendrás las novedades. Tus datos no se modifican.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Más tarde'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          onPressed: () => AppUpdateService.closeAppToApplyPatch(),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reiniciar ahora'),
        ),
      ],
    ),
  );
}
