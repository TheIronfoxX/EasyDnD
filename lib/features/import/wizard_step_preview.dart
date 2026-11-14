// Paso 3 del wizard: revisar y confirmar.
//
// La ficha ya se construyó y validó (sin tocar el roster); acá se le
// muestra al jugador lo que va a entrar:
// - Resumen: quién es, números clave y cantidades de contenido.
// - Avisos del validador (los errores bloqueantes nunca llegan acá: el
//   paso 2 no deja avanzar con ellos).
// - Si hay avisos, el prompt de corrección listo para copiar: cierra el
//   circuito que en la app vieja quedaba a mano — el jugador vuelve al
//   paso anterior con la respuesta corregida y re-revisa ANTES de
//   importar.
//
// El commit (addCharacter / replaceCharacter) lo dispara la barra
// inferior de la pantalla; este paso no toca el store.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/ai_prompt.dart';
import '../../domain/character_validator.dart';
import '../../domain/models/character.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/design_tokens.dart';

class WizardStepPreview extends StatelessWidget {
  const WizardStepPreview({
    super.key,
    required this.result,
    required this.isReplace,
    this.replacedName,
    required this.onConfirm,
  });

  final CharacterValidationResult result;

  /// True: al confirmar se reemplaza la ficha existente en vez de añadir.
  final bool isReplace;
  final String? replacedName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = result.character!;
    final warnings = result.warnings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text('Revisá antes de confirmar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          isReplace
              ? 'Esta es la ficha que va a REEMPLAZAR a ${replacedName ?? 'tu personaje'}.'
              : 'Esta es la ficha que se va a añadir a tu roster.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),

        _SummaryCard(character: character),
        const SizedBox(height: AppSpacing.md),

        if (warnings.isEmpty)
          _NoWarningsCard(hasResources: character.resources.isNotEmpty)
        else ...[
          _WarningsCard(warnings: warnings),
          const SizedBox(height: AppSpacing.md),
          _CorrectionCard(warnings: warnings, result: result),
        ],
      ],
    );
  }
}

/// Resumen de la ficha: identidad + números clave + volumen de contenido.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final basic = character.basicInfo;
    final abilities = character.abilitiesByAction;

    final subtitle = [
      if (basic.race.isNotEmpty) basic.race,
      if (basic.characterClass.isNotEmpty) basic.characterClass,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    basic.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _Chip('Nivel ${basic.level}'),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(label: 'PG máx.', value: '${basic.hpMax}'),
                _StatChip(label: 'CA', value: '${basic.ac}'),
                _StatChip(label: 'Velocidad', value: '${basic.speed} m'),
                _StatChip(
                  label: 'CD salv.',
                  value: basic.spellSaveDc == null
                      ? '—'
                      : '${basic.spellSaveDc}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip('${character.inventory.weapons.length} armas'),
                _Chip('${character.inventory.mundaneItems.length} objetos'),
                _Chip('${abilities.action.length} de acción'),
                _Chip('${abilities.bonusAction.length} adicionales'),
                _Chip('${abilities.reaction.length} reacciones'),
                _Chip('${abilities.passive.length} pasivas'),
                _Chip('${character.resources.length} recursos'),
                if (character.spellSlots.slots.isNotEmpty)
                  const _Chip('lanzador de conjuros'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Número destacado con etiqueta arriba.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sin avisos: todo lo que la ficha declara, el HUD lo puede usar.
class _NoWarningsCard extends StatelessWidget {
  const _NoWarningsCard({required this.hasResources});

  /// Solo para variar el mensaje: una ficha sin recursos declarados es
  /// sospechosa en casi cualquier clase (suele significar que la IA no
  /// analizó las features), y avisarlo ayuda a detectar imports flojos.
  final bool hasResources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: scheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasResources
                  ? 'El validador no encontró avisos: la ficha está '
                        'completa y lista para el HUD.'
                  : 'El validador no encontró avisos. Igual fijate: la '
                        'ficha no declara ningún recurso gastable (Ki, '
                        'Inspiración, Furia...), y casi ninguna clase de 5e '
                        'tiene cero.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La lista de avisos: qué campo, qué pasa y qué fallback se aplicará.
class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<ValidationIssue> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Avisos (${warnings.length}) — la ficha entra igual',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warning.field,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.jetBrainsMono,
                              color: scheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            warning.message,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Prompt de corrección para los avisos detectados.
class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.warnings, required this.result});

  final List<ValidationIssue> warnings;
  final CharacterValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Mejor corregirlo antes?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Podés pedirle a tu IA que arregle estos avisos: copiá el '
              'prompt de corrección, pegalo en tu IA y volvé con la '
              'respuesta (Atrás → pegarla de nuevo → re-revisar). También '
              'podés importar así como está: los avisos no bloquean.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyCorrectionPrompt(context),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Copiar prompt de corrección'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCorrectionPrompt(BuildContext context) async {
    final characterJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(result.character!.toJson());
    final problems = warnings.map((w) => '${w.field}: ${w.message}').toList();
    final prompt = AiPrompt.forCorrection(characterJson, problems);

    await Clipboard.setData(ClipboardData(text: prompt));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Prompt de corrección copiado. Pegalo en tu IA y '
          'traé la respuesta al paso anterior.',
        ),
      ),
    );
  }
}
