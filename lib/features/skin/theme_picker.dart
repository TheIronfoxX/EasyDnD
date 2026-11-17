// Selector visual de skins (rework estético): una ficha por tema del
// catálogo, pintada con sus propios tokens (color principal, forma de
// tarjeta y de controles, grosor de borde y forma de pip).
//
// Ya no está a la vista: es el menú escondido de temas prehechos, que se
// abre con una pulsación larga sobre el título de Mis temas
// ([showThemePickerSheet]).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/pip_shape.dart';
import '../../core/ui/tactical_card.dart';
import '../../state/skin_controller.dart';

/// Abre el selector de temas como hoja inferior.
Future<void> showThemePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SingleChildScrollView(
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

/// Selector de skins: una ficha por tema con su nombre, su color
/// principal, sus pips y la forma de su tarjeta, más la descripción del
/// tema activo.
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
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 3 : 2;
            final cell =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final preset in AppThemePreset.values)
                  SizedBox(
                    width: cell,
                    child: _ThemeSwatch(
                      preset: preset,
                      selected: preset == active,
                      onTap: () => skin.setThemePreset(preset),
                    ),
                  ),
              ],
            );
          },
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

/// Ficha de un tema. Se pinta con los tokens DEL TEMA QUE REPRESENTA (no
/// con los del activo): su fondo, su forma de tarjeta, su borde, su color
/// principal y su forma de pip.
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
    final tokens = preset.tactical;
    final palette = preset.palette;
    final onPrimary =
        ThemeData.estimateBrightnessForColor(tokens.primary) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: 'Tema ${preset.label}',
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tokens.surfaceRaised, palette.background],
            ),
            shape: tokens.cardBorder(
              selected ? tokens.primary : tokens.metalBorder,
              width: selected ? tokens.borderWidth + 1.4 : tokens.borderWidth,
            ),
            shadows: selected ? tokens.cardShadows(Colors.black) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('theme-swatch-${preset.id}'),
              onTap: onTap,
              customBorder: tokens.cardShape,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Muestra del color principal, con la forma de
                        // los controles del tema.
                        Container(
                          width: 30,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: tokens.primary,
                            shape: tokens.buttonShape,
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: onPrimary,
                                )
                              : null,
                        ),
                        const Spacer(),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: PipGlyph(
                              shape: tokens.pipShape,
                              filled: i < 2,
                              color: tokens.primary,
                              outline: tokens.metalBorder,
                              size: 9,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      preset.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
