// Cuadrícula de espacios de conjuro: un mosaico por nivel, separados y en
// tres columnas. Se usa en Combate y en la pantalla de Conjuros.
//
// Cada mosaico: el nivel en grande, `actual/máx` y una barrita partida en
// tramos (uno por espacio). Tocar un tramo lleno lo gasta; uno vacío lo
// recupera. Tocar el mosaico gasta uno (o, sin ninguno, recupera uno).
// Con espacios, el mosaico se tiñe del color de conjuro; agotado, queda
// apagado.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/clean_shape.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/theme/telemetry.dart';
import '../../../domain/models/character.dart';
import '../../../state/character_store.dart';

class SpellSlotsGrid extends StatelessWidget {
  const SpellSlotsGrid({super.key, required this.character});

  static const _columns = 3;

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final slots = [...character.spellSlots.slots]
      ..sort((a, b) => a.level.compareTo(b.level));
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in slots)
              SizedBox(
                width: width,
                child: _SlotTile(
                  key: ValueKey('slot-level-${s.level}'),
                  level: s.level,
                  current: s.current,
                  max: s.max,
                  onSpend: () => store.consumeSpellSlot(s.level),
                  onRecover: () => store.restoreSpellSlot(s.level),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    super.key,
    required this.level,
    required this.current,
    required this.max,
    required this.onSpend,
    required this.onRecover,
  });

  final int level;
  final int current;
  final int max;
  final VoidCallback onSpend;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.tactical.spell;
    final shape = context.cleanShape;
    final left = current > 0;
    final muted = scheme.onSurfaceVariant;
    return Material(
      color: left
          ? Color.alphaBlend(tone.withValues(alpha: 0.08), scheme.surface)
          : scheme.surface,
      shape: shape
          .surface(18)
          .copyWith(
            side: BorderSide(
              color: left
                  ? tone.withValues(alpha: 0.35)
                  : scheme.outline.withValues(alpha: 0.5),
            ),
          ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: left ? onSpend : onRecover,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$level',
                    style: theme.textTheme.headlineSmall?.tabular.copyWith(
                      color: left ? tone : muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'NV',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$current/$max',
                    style: theme.textTheme.labelMedium?.tabular.copyWith(
                      color: left ? scheme.onSurface : muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (var i = 0; i < max; i++)
                    Expanded(
                      child: Tooltip(
                        message: i < current
                            ? 'Gastar espacio de nivel $level'
                            : 'Recuperar espacio de nivel $level',
                        child: InkWell(
                          borderRadius: shape.radius(6),
                          onTap: i < current ? onSpend : onRecover,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            child: AnimatedContainer(
                              duration: AppDurations.fast,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: shape.radius(6),
                                color: i < current
                                    ? tone
                                    : scheme.onSurface.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
