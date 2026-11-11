import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/character_store.dart';
import '../features/import/import_wizard_screen.dart';

/// Pantalla provisoria de las etapas 1-4 del rework.
///
/// Existe para que la app compile, corra y los tests de humo tengan algo
/// que verificar mientras se construyen las capas siguientes. Desde la
/// Etapa 3 también da entrada manual al wizard de importación (para
/// probarlo en dispositivo sin esperar el HUD).
///
/// La reemplaza la StartupGate en la Etapa 5 (HUD); borrar este archivo
/// es parte del checklist de esa etapa.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<CharacterStore>();
    final active = store.activeCharacter;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('EasyDnD', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Rework en curso · Etapa 3/7 — importación IA',
                style: theme.textTheme.bodyMedium,
              ),
              if (active != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Ficha activa: ${active.basicInfo.name} '
                  '(${store.roster.length} en el roster)',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportWizardScreen(),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Importar ficha con IA'),
              ),
              if (active != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ImportWizardScreen(
                          replaceIndex: store.activeIndex,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.published_with_changes_rounded),
                    label: Text(
                        'Corregir a ${active.basicInfo.name} con IA'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
