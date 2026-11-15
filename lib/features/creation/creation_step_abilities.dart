// Paso 2 — Características: método, bonos raciales y totales en vivo.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/character_builder_engine.dart';
import 'creation_draft_controller.dart';
import 'creation_widgets.dart';

class CreationStepAbilities extends StatelessWidget {
  const CreationStepAbilities({super.key, required this.draft});

  final CreationDraftController draft;

  static const _methodLabels = {
    AbilityMethod.standardArray: 'Array estándar',
    AbilityMethod.pointBuy: 'Compra de puntos',
    AbilityMethod.rolled: 'Tirada 4d6',
    AbilityMethod.manual: 'Manual',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Características', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in _methodLabels.entries)
                  ChoiceChip(
                    key: Key('method-${e.key.name}'),
                    label: Text(e.value),
                    selected: draft.method == e.key,
                    onSelected: (_) => draft.setMethod(e.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (draft.method == AbilityMethod.pointBuy)
              Text(
                'Puntos restantes: ${draft.pointsRemaining} / ${CreationDraftController.pointBuyBudget}',
                key: const Key('points-remaining'),
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
              ),
            if (draft.method == AbilityMethod.rolled)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const Key('roll-abilities'),
                  onPressed: draft.rollAbilityScores,
                  icon: const Icon(Icons.casino_rounded),
                  label: const Text('Tirar 4d6 (descartar el menor)'),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final k in kAbilityKeys) _AbilityRow(draft: draft, abilityKey: k),
          ],
        );
      },
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.draft, required this.abilityKey});

  final CreationDraftController draft;
  final String abilityKey;

  Widget _baseControl() {
    final k = abilityKey;
    final v = draft.baseScores[k]!;
    switch (draft.method) {
      case AbilityMethod.standardArray:
        return DropdownButton<int>(
          key: Key('base-$k-dropdown'),
          value: v,
          underline: const SizedBox.shrink(),
          items: [
            for (final n in CreationDraftController.standardArray)
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (n) {
            if (n != null) draft.setBaseScore(k, n);
          },
        );
      case AbilityMethod.pointBuy:
        const cost = CreationDraftController.pointBuyCost;
        final canInc = v < 15 && draft.pointsRemaining >= cost[v + 1]! - cost[v]!;
        return CreationStepper(
          keyPrefix: 'base-$k',
          value: '$v',
          onDec: v > 8 ? () => draft.setBaseScore(k, v - 1) : null,
          onInc: canInc ? () => draft.setBaseScore(k, v + 1) : null,
        );
      case AbilityMethod.rolled:
        return Text('$v', key: Key('base-$k-value'));
      case AbilityMethod.manual:
        return CreationStepper(
          keyPrefix: 'base-$k',
          value: '$v',
          onDec: v > 1 ? () => draft.setBaseScore(k, v - 1) : null,
          onInc: v < 30 ? () => draft.setBaseScore(k, v + 1) : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final racial = draft.racialBonuses[abilityKey]!;
    final total = draft.baseScores[abilityKey]! + racial;
    final mod = CharacterBuilderEngine.modifier(total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(kAbilityNames[abilityKey]!, style: theme.textTheme.titleSmall),
          ),
          Expanded(flex: 4, child: Align(alignment: Alignment.centerLeft, child: _baseControl())),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CreationStepper(
                keyPrefix: 'racial-$abilityKey',
                value: signed(racial),
                onDec: racial > -5 ? () => draft.setRacialBonus(abilityKey, racial - 1) : null,
                onInc: racial < 5 ? () => draft.setRacialBonus(abilityKey, racial + 1) : null,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$total (${signed(mod)})',
              key: Key('total-$abilityKey'),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
