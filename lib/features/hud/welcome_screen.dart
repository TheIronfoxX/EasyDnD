// Bienvenida de EasyDnD: el estado "roster vacío" de la Etapa 5.
//
// No es un onboarding de marketing: es la pantalla que resuelve la
// única decisión que importa cuando todavía no hay fichas — cómo entra
// la primera. Las dos vías son las mismas que ya existen en la app
// (importación con IA y editor manual), no un flujo paralelo nuevo.
//
// Cuando el roster tiene fichas esta pantalla no se muestra: la
// StartupGate va directo al HUD.

import 'package:flutter/material.dart';

import '../../core/ui/tactical_background.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/ui/arcane_emblem.dart';
import '../../core/ui/tactical_card.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import '../skin/skin_screen.dart';
import '../skin/theme_picker.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openImport(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ImportWizardScreen()));
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CharacterEditorScreen()),
    );
  }

  void _openSkin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SkinScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.75),
            radius: 1.15,
            colors: [tactical.headerStart, theme.scaffoldBackgroundColor],
          ),
        ),
        child: TacticalScaffoldBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: ArcaneEmblem()),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'EasyDnD',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const _TitleRule(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Tu hoja de personaje viva para la mesa. '
                            'Combate, inventario y dados, sin perder de vista '
                            'lo importante.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          // Vía principal: la que usa casi todo el mundo.
                          TacticalCard(
                            tone: scheme.primary,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Traé tu personaje ya armado: pegá el enlace '
                                  'o los datos y la ficha queda lista para '
                                  'jugar.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.icon(
                                  onPressed: () => _openImport(context),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Importar desde Nivel20'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Vía secundaria: empezar de cero en el taller.
                          OutlinedButton.icon(
                            onPressed: () => _openEditor(context),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text('Ficha en blanco'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Todo queda guardado en este dispositivo: la '
                                  'app funciona sin conexión.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Temas',
                        icon: const Icon(Icons.auto_awesome_mosaic_rounded),
                        onPressed: () => showThemePickerSheet(context),
                      ),
                      IconButton(
                        tooltip: 'Apariencia',
                        icon: const Icon(Icons.palette_outlined),
                        onPressed: () => _openSkin(context),
                      ),
                    ],
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

/// Filete bajo el título: dos trazos que se desvanecen y un rombo central.
class _TitleRule extends StatelessWidget {
  const _TitleRule();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    Widget stroke({required bool reversed}) => Container(
      width: 64,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reversed ? Alignment.centerRight : Alignment.centerLeft,
          end: reversed ? Alignment.centerLeft : Alignment.centerRight,
          colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.8)],
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        stroke(reversed: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(width: 6, height: 6, color: accent),
          ),
        ),
        stroke(reversed: true),
      ],
    );
  }
}
