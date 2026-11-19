// Ajustes: lo que se usa una vez por sesión o menos.
//
// Tema (claro/oscuro, forma, color principal y secundario), combate, fichas (importar, crear, corregir
// con IA) y datos (exportar/respaldo, eliminar la ficha activa).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/accent_presets.dart';
import '../../core/theme/clean_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ui/clean_kit.dart';
import '../../state/character_store.dart';
import '../../state/skin_controller.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import '../skin/hsv_color_picker_dialog.dart';
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
        const CleanSectionTitle('Tema'),
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
              Text('Forma', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              for (final style in CleanThemeStyle.values)
                _ThemeStyleTile(
                  style: style,
                  brightness: theme.brightness,
                  selected: skin.themeStyle == style,
                  onTap: () => skin.setThemeStyle(style),
                ),
              const SizedBox(height: AppSpacing.md),
              Text('Color principal', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final preset in AccentPresets.all)
                    _AccentSwatch(
                      key: ValueKey('accent-${preset.label}'),
                      label: preset.label,
                      color: preset.color,
                      selected: skin.accentColor == preset.color,
                      onTap: () => skin.setAccentColor(preset.color),
                    ),
                  _CustomColorButton(
                    key: const ValueKey('accent-custom'),
                    current: skin.accentColor,
                    selected: AccentPresets.matching(skin.accentColor) == null,
                    onPicked: skin.setAccentColor,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Color secundario', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Conjuros, ranuras y detalles. Te sugerimos colores que '
                'combinan con el principal.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _AccentSwatch(
                    key: const ValueKey('secondary-auto'),
                    label: 'Automático (sigue al principal)',
                    color: skin.secondaryRecommendations.first.color,
                    selected: !skin.hasCustomSecondary,
                    onTap: skin.clearCustomSecondary,
                    icon: Icons.auto_awesome_rounded,
                  ),
                  for (final rec in skin.secondaryRecommendations.skip(1))
                    _AccentSwatch(
                      key: ValueKey('secondary-${rec.label}'),
                      label: rec.label,
                      color: rec.color,
                      selected:
                          skin.hasCustomSecondary &&
                          skin.secondaryColor == rec.color,
                      onTap: () => skin.setSecondaryColor(rec.color),
                    ),
                  _CustomColorButton(
                    key: const ValueKey('secondary-custom'),
                    current: skin.secondaryColor,
                    selected:
                        skin.hasCustomSecondary &&
                        !skin.secondaryRecommendations.any(
                          (r) => r.color == skin.secondaryColor,
                        ),
                    onPicked: skin.setSecondaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const CleanSectionTitle('Combate'),
        CleanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Lista de acciones', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<bool>(
                key: const ValueKey('settings-density'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Vista Guiada')),
                  ButtonSegment(value: true, label: Text('Vista Compacta')),
                ],
                selected: {skin.compactHud},
                onSelectionChanged: (s) => skin.setCompactHud(s.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                skin.compactHud
                    ? 'Filas densas: nombre y datos en una línea.'
                    : 'Con explicación en llano y el tipo de acción.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                  key: const ValueKey('settings-export'),
                  icon: Icons.save_alt_rounded,
                  title: 'Exportar ficha a archivo',
                  subtitle: character.basicInfo.name,
                  onTap: () => exportCharacterFile(context, character),
                ),
                tile(
                  key: const ValueKey('settings-copy'),
                  icon: Icons.copy_rounded,
                  title: 'Copiar ficha (JSON)',
                  subtitle: 'Al portapapeles, para pegarla donde quieras',
                  onTap: () => copyCharacterToClipboard(context, character),
                ),
                tile(
                  key: const ValueKey('settings-backup'),
                  icon: Icons.backup_rounded,
                  title: 'Respaldar todas las fichas',
                  subtitle: 'Archivo con todo tu roster',
                  onTap: () => exportRosterBackup(context, store.roster),
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

/// Una forma: muestra con la silueta pintada en los colores actuales,
/// nombre y una línea de qué es.
class _ThemeStyleTile extends StatelessWidget {
  const _ThemeStyleTile({
    required this.style,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  final CleanThemeStyle style;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = style.shape(brightness);
    return ListTile(
      key: ValueKey('theme-style-${style.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 52,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerHigh,
          shape: shape.surface(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.primary,
                  shape: shape.surface(8).copyWith(side: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.secondary,
                  shape: shape.surface(8).copyWith(side: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(style.label),
      subtitle: Text(style.tagline),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                : null,
          ),
          child: icon == null ? null : Icon(icon, size: 18, color: onColor),
        ),
      ),
    );
  }
}

/// Botón "otro color": abre el selector libre (tono, saturación, brillo).
class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    super.key,
    required this.current,
    required this.selected,
    required this.onPicked,
  });

  final Color current;
  final bool selected;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Otro color',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final picked = await showDialog<Color>(
            context: context,
            builder: (_) => HsvColorPickerDialog(initialColor: current),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? current : null,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outline,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Icon(
            Icons.colorize_rounded,
            size: 18,
            color: selected
                ? (ThemeData.estimateBrightnessForColor(current) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
