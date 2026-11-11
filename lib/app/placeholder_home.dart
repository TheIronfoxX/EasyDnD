import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/character_store.dart';
import '../features/editor/character_editor_screen.dart';
import '../features/import/import_wizard_screen.dart';

/// Pantalla provisoria de las etapas 1-4 del rework.
///
/// Existe para que la app compile, corra y los tests de humo tengan algo
/// que verificar mientras se construyen las capas siguientes. Desde la
/// Etapa 3 da entrada al wizard de importación y desde la 4 al editor
/// manual (para probarlos en dispositivo sin esperar el HUD).
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
                'Rework en curso · Etapa 4/7 — editor manual',
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
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CharacterEditorScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Crear ficha a mano'),
              ),
              if (active != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CharacterEditorScreen(
                        character: active,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text('Editar a ${active.basicInfo.name} a mano'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
