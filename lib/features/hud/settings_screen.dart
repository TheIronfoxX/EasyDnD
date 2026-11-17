// Ajustes: lo que se usa una vez por sesión o menos.
//
// Apariencia (claro/oscuro y color), fichas (importar, crear, corregir
// con IA) y datos (exportar/respaldo, eliminar la ficha activa).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/accent_presets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ui/clean_kit.dart';
import '../../state/character_store.dart';
import '../../state/skin_controller.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import 'hud_backup_actions.dart';
import 'hud_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteActive(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final character = store.activeCharacter;
    if (character == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final index = store.activeIndex;
    final name = character.basicInfo.name;

    final confirmed = await showDeleteCharacterDialog(context, name: name);
    if (!confirmed) return;
    store.deleteCharacter(index);
    navigator.pop();
    if (store.roster.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ficha de $name eliminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = context.watch<SkinController>();
    final store = context.watch<CharacterStore>();
    final character = store.activeCharacter;

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
      bool destructive = false,
      Key? key,
    }) {
      final color = destructive ? theme.colorScheme.error : null;
      return ListTile(
        key: key,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: onTap,
      );
    }

    return CleanPage(
      title: 'Ajustes',
      children: [
        const CleanSectionTitle('Apariencia'),
        CleanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                key: const ValueKey('settings-mode'),
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Oscuro'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Claro'),
                  ),
                ],
                selected: {skin.isDarkMode},
                onSelectionChanged: (s) => skin.setDarkMode(s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Color', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final preset in AccentPresets.all)
                    Tooltip(
                      message: preset.label,
                      child: InkWell(
                        key: ValueKey('accent-${preset.label}'),
                        customBorder: const CircleBorder(),
                        onTap: () => skin.setAccentColor(preset.color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: preset.color,
                            shape: BoxShape.circle,
                            border: skin.accentColor == preset.color
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const CleanSectionTitle('Fichas'),
        CleanCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              tile(
                key: const ValueKey('settings-import'),
                icon: Icons.download_rounded,
                title: 'Importar desde Nivel20',
                onTap: () =>
                    pushPage<void>(context, const ImportWizardScreen()),
              ),
              tile(
                key: const ValueKey('settings-json'),
                icon: Icons.upload_file_rounded,
                title: 'Importar archivo JSON',
                subtitle: 'Una ficha exportada o un respaldo completo',
                onTap: () => importFromFile(context, store),
              ),
              tile(
                key: const ValueKey('settings-new'),
                icon: Icons.note_add_rounded,
                title: 'Ficha en blanco',
                onTap: () =>
                    pushPage<void>(context, const CharacterEditorScreen()),
              ),
              if (character != null)
                tile(
                  key: const ValueKey('settings-ai-fix'),
                  icon: Icons.auto_fix_high_rounded,
                  title: 'Corregir con IA',
                  subtitle: 'Reenvía la ficha a la IA para arreglarla',
                  onTap: () => pushPage<void>(
                    context,
                    ImportWizardScreen(replaceIndex: store.activeIndex),
                  ),
                ),
            ],
          ),
        ),
        if (character != null) ...[
          const CleanSectionTitle('Datos'),
          CleanCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                tile(
                  key: const ValueKey('settings-backup'),
                  icon: Icons.save_alt_rounded,
                  title: 'Exportar y respaldo',
                  onTap: () => showBackupSheet(context, character),
                ),
                tile(
                  key: const ValueKey('settings-delete'),
                  icon: Icons.delete_outline_rounded,
                  title: 'Eliminar ficha',
                  subtitle: character.basicInfo.name,
                  destructive: true,
                  onTap: () => _deleteActive(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
