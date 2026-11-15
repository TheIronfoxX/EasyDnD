// Selector visual de temas (rework estético).
//
// Una fila de muestras circulares, una por tema del catálogo. Cada
// muestra se pinta con los colores DEL TEMA QUE REPRESENTA (no con el
// activo): fondo, borde metálico y un núcleo con su acento de firma.
//
// Se usa embebido en Apariencia y como hoja rápida desde la barra de la
// bienvenida y el menú del HUD ([showThemePickerSheet]).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/tactical_card.dart';
import '../../state/skin_controller.dart';

/// Abre el selector de temas como hoja inferior.
Future<void> showThemePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'Temas',
            ),
            SizedBox(height: AppSpacing.md),
            ThemeSwatchPicker(),
          ],
        ),
      ),
    ),
  );
}

/// Muestras de los temas + nombre y descripción del activo.
class ThemeSwatchPicker extends StatelessWidget {
  const ThemeSwatchPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinController>();
    final theme = Theme.of(context);
    final active = skin.themePreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in AppThemePreset.values)
              _ThemeSwatch(
                preset: preset,
                selected: preset == active,
                onTap: () => skin.setThemePreset(preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: AppDurations.normal,
          child: Column(
            key: ValueKey(active),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                active.label,
                key: const ValueKey('theme-active-label'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                active.tagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onAccent =
        ThemeData.estimateBrightnessForColor(preset.accent) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: 'Tema ${preset.label}',
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey('theme-swatch-${preset.id}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: AnimatedContainer(
              duration: AppDurations.normal,
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    preset.tactical.surfaceRaised,
                    preset.palette.background,
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : preset.tactical.metalBorder,
                  width: selected ? 3 : 1.5,
                ),
              ),
              child: AnimatedContainer(
                duration: AppDurations.normal,
                width: selected ? 26 : 20,
                height: selected ? 26 : 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: preset.accent,
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 16, color: onAccent)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
