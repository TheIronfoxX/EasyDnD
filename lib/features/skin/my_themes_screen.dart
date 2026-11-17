// Mis temas: la lista de temas propios del jugador.
//
// Tocar un tema lo activa; su menú permite editarlo, duplicarlo o
// borrarlo, y el botón flotante crea uno nuevo a partir de lo que se ve
// ahora. El catálogo de temas prehechos ya no está a la vista: se abre
// con una pulsación larga sobre el título de esta pantalla.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/custom_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ui/pip_shape.dart';
import '../../core/ui/tactical_background.dart';
import '../../state/skin_controller.dart';
import 'theme_editor_screen.dart';
import 'theme_picker.dart';

Future<void> openMyThemes(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const MyThemesScreen()));

enum _ThemeAction { edit, duplicate, delete }

class MyThemesScreen extends StatelessWidget {
  const MyThemesScreen({super.key});

  Future<void> _newTheme(BuildContext context) => openThemeEditor(
    context,
    context.read<SkinController>().draftFromActive(),
  );

  Future<void> _onAction(
    BuildContext context,
    _ThemeAction action,
    CustomTheme theme,
  ) async {
    final skin = context.read<SkinController>();
    switch (action) {
      case _ThemeAction.edit:
        await openThemeEditor(context, theme);
      case _ThemeAction.duplicate:
        await skin.duplicateCustomTheme(theme.id);
      case _ThemeAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Borrar tema'),
            content: Text('¿Borrar "${theme.name}"? No se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-theme'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Borrar'),
              ),
            ],
          ),
        );
        if (ok == true) await skin.deleteCustomTheme(theme.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinController>();
    final themes = skin.customThemes;
    final active = skin.activeCustomTheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Pulsación larga en el título: catálogo de temas prehechos.
        title: GestureDetector(
          key: const ValueKey('hidden-presets'),
          onLongPress: () => showThemePickerSheet(context),
          child: const Text('Mis temas'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-theme'),
        onPressed: () => _newTheme(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo tema'),
      ),
      body: TacticalScaffoldBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            96,
          ),
          children: [
            Text(
              'Ahora: ${skin.activeThemeName}',
              key: const ValueKey('active-theme-name'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (themes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(
                      Icons.brush_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Todavía no tienes temas propios.\n'
                      'Crea uno: parte de lo que ves ahora y cambia lo que '
                      'quieras.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final t in themes)
                _ThemeTile(
                  theme: t,
                  active: active?.id == t.id,
                  onTap: () => skin.activateCustomTheme(t.id),
                  onAction: (a) => _onAction(context, a, t),
                ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.active,
    required this.onTap,
    required this.onAction,
  });

  final CustomTheme theme;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<_ThemeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final scheme = appTheme.colorScheme;
    final t = theme.tactical;
    final p = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(
            color: active ? scheme.primary : scheme.outline,
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('custom-theme-${theme.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Muestra pintada con los colores del propio tema.
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: ShapeDecoration(
                    color: p.background,
                    shape: t.cardBorder(t.metalBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(height: 10, color: t.primary),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final c in [t.weapon, t.spell, t.ability])
                            PipGlyph(
                              shape: t.pipShape,
                              filled: true,
                              color: c,
                              size: 11,
                            ),
                        ],
                      ),
                      Container(height: 4, color: t.heal),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        theme.isDark ? 'Oscuro' : 'Claro',
                        style: appTheme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
                PopupMenuButton<_ThemeAction>(
                  tooltip: 'Opciones de ${theme.name}',
                  onSelected: onAction,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ThemeAction.edit,
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: _ThemeAction.duplicate,
                      child: Text('Duplicar'),
                    ),
                    PopupMenuItem(
                      value: _ThemeAction.delete,
                      child: Text('Borrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
