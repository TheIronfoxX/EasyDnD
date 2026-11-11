import 'package:flutter/material.dart';

/// Pantalla provisoria de la Etapa 1 del rework.
///
/// Existe solo para que la app compile, corra y el test de humo tenga
/// algo que verificar mientras se construyen las capas siguientes.
/// La reemplaza la StartupGate en la Etapa 5 (HUD); borrar este archivo
/// es parte del checklist de esa etapa.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EasyDnD', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Rework en curso · Etapa 1/7 — fundaciones',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
