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

import '../../core/theme/design_tokens.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import '../skin/skin_screen.dart';

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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
            ],
          ),
        ),
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
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary.withValues(alpha: 0.14),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.casino_rounded,
                              size: 40,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'EasyDnD',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tu hoja de personaje viva para la mesa. '
                          'Combate, inventario y dados, sin perder de vista '
                          'lo importante.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton.icon(
                          onPressed: () => _openImport(context),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Importar desde Nivel20'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonalIcon(
                          onPressed: () => _openEditor(context),
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Ficha en blanco'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Todo queda guardado en este dispositivo: la app '
                          'funciona sin conexión.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: IconButton(
                  tooltip: 'Apariencia',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => _openSkin(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
