// Pantalla de apariencia / skin (Etapa 6b).
//
// Es el único lugar donde el jugador toca el tema: modo claro/oscuro,
// presets de acento y color libre con el picker HSV. Todo pasa por
// [SkinController], que persiste y reconstruye el MaterialApp; esta
// pantalla solo refleja su estado (watch) y le manda cambios.
//
// Nada de colores fijos acá: los presets viven en AccentPresets y el
// resto sale del tema activo, así que la pantalla se ve bien en ambos
// modos y con cualquier acento.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/accent_presets.dart';
import '../../core/theme/design_tokens.dart';
import '../../state/skin_controller.dart';
import 'hsv_color_picker_dialog.dart';

class SkinScreen extends StatelessWidget {
  const SkinScreen({super.key});

  Future<void> _pickCustomColor(BuildContext context) async {
    final skin = context.read<SkinController>();
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => HsvColorPickerDialog(initialColor: skin.accentColor),
    );
    if (picked != null) await skin.setAccentColor(picked);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinController>();
    final theme = Theme.of(context);
    final selectedPreset = AccentPresets.matching(skin.accentColor);

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SectionTitle('Modo'),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
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
            onSelectionChanged: (selection) =>
                skin.setDarkMode(selection.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionTitle('Color de acento'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'El color se usa en botones, iconos y la barra inferior. '
            'Los presets son un atajo; abajo podés elegir cualquier color.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in AccentPresets.all)
                _AccentSwatch(
                  preset: preset,
                  selected: preset == selectedPreset,
                  onTap: () => skin.setAccentColor(preset.color),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _pickCustomColor(context),
              icon: const Icon(Icons.palette_outlined),
              label: Text(
                selectedPreset == null
                    ? 'Cambiar color personalizado'
                    : 'Elegir color personalizado',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ThemePreview(accent: skin.accentColor),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Swatch circular de un preset. El borde y la tilde se resuelven con el
/// tema; el relleno es el color del preset, que es justamente lo que se
/// está eligiendo.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAccent =
        ThemeData.estimateBrightnessForColor(preset.color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: preset.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Acento ${preset.label}',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: preset.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 20, color: onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista previa en vivo: botones y textos con el acento actual, para que
/// el jugador vea el resultado sin salir de la pantalla.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Vista previa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Así se ven los controles con el skin actual.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Atacar')),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Descansar'),
                ),
                Chip(
                  avatar: Icon(Icons.bolt_rounded, color: accent, size: 18),
                  label: const Text('Recurso'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
