// Bienvenida: el estado "roster vacío".
//
// Resuelve la única decisión que importa cuando todavía no hay fichas —
// cómo entra la primera— con tres vías grandes y claras: importar desde
// Nivel20, importar un archivo JSON (una ficha exportada o un respaldo
// completo) o empezar una ficha en blanco. Arriba a la derecha, Ajustes
// (claro/oscuro y color).
//
// Cuando el roster tiene fichas esta pantalla no se muestra: la
// StartupGate va directo al HUD.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/ui/clean_kit.dart';
import '../../state/character_store.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import 'hud_backup_actions.dart';
import 'settings_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => pushPage<void>(context, const SettingsScreen()),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'EasyDnD',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tu personaje de D&D, fácil y a mano en la mesa.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '¿Cómo quieres traer tu personaje?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                NavRowCard(
                  key: const ValueKey('welcome-nivel20'),
                  icon: Icons.download_rounded,
                  title: 'Importar desde Nivel20',
                  subtitle: 'Pega el enlace o los datos de tu ficha',
                  onTap: () =>
                      pushPage<void>(context, const ImportWizardScreen()),
                ),
                NavRowCard(
                  key: const ValueKey('welcome-json'),
                  icon: Icons.upload_file_rounded,
                  title: 'Importar archivo JSON',
                  subtitle: 'Una ficha exportada o un respaldo completo',
                  onTap: () =>
                      importFromFile(context, context.read<CharacterStore>()),
                ),
                NavRowCard(
                  key: const ValueKey('welcome-blank'),
                  icon: Icons.person_add_rounded,
                  title: 'Ficha en blanco',
                  subtitle: 'Créala tú desde cero',
                  onTap: () =>
                      pushPage<void>(context, const CharacterEditorScreen()),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Todo se guarda en este dispositivo: la app funciona sin '
                  'conexión.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
