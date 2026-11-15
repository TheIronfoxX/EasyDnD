// Paso 3 — Competencias y estadísticas vitales (con resumen en vivo).

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/character_builder_engine.dart';
import 'creation_draft_controller.dart';
import 'creation_widgets.dart';

class CreationStepProficiencies extends StatefulWidget {
  const CreationStepProficiencies({super.key, required this.draft});

  final CreationDraftController draft;

  @override
  State<CreationStepProficiencies> createState() => _CreationStepProficienciesState();
}

class _CreationStepProficienciesState extends State<CreationStepProficiencies> {
  late final _hp = TextEditingController(text: widget.draft.customHpMax?.toString() ?? '');

  @override
  void dispose() {
    _hp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cls = draft.srdClass!;
        final stats = draft.stats!;
        final custom = draft.customHpMax != null;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Competencias y vida', style: theme.textTheme.titleLarge),
            CreationSectionTitle(
              'Habilidades de ${cls.name}',
              subtitle: 'Elige ${cls.skillChoicesCount} · quedan ${draft.skillChoicesLeft}',
            ),
            for (final skill in cls.skillOptions)
              CheckboxListTile(
                key: Key('skill-$skill'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(skill),
                subtitle: Text(kAbilityNames[kSkillAbilities[skill]] ?? ''),
                secondary: Text(signed(stats.skills[skill] ?? 0)),
                value: draft.skillProficiencies.contains(skill),
                onChanged: (draft.skillProficiencies.contains(skill) || draft.skillChoicesLeft > 0)
                    ? (_) => draft.toggleSkill(skill)
                    : null,
              ),
            if (draft.expertiseSlots > 0) ...[
              CreationSectionTitle(
                'Pericia',
                subtitle: 'Doble competencia en ${draft.expertiseSlots} de tus habilidades',
              ),
              if (draft.skillProficiencies.isEmpty)
                Text('Elige primero tus habilidades.', style: theme.textTheme.bodySmall),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final s in draft.skillProficiencies)
                    FilterChip(
                      key: Key('expertise-$s'),
                      label: Text(s),
                      selected: draft.expertiseSkills.contains(s),
                      onSelected: (_) => draft.toggleExpertise(s),
                    ),
                ],
              ),
            ],
            const CreationSectionTitle('Puntos de golpe'),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  key: const Key('hp-average'),
                  label: const Text('PG medios'),
                  selected: !custom,
                  onSelected: (_) {
                    _hp.clear();
                    draft.setCustomHpMax(null);
                  },
                ),
                ChoiceChip(
                  key: const Key('hp-custom'),
                  label: const Text('Valor personalizado'),
                  selected: custom,
                  onSelected: (_) {
                    _hp.text = '${stats.hpMax}';
                    draft.setCustomHpMax(stats.hpMax);
                  },
                ),
              ],
            ),
            if (custom)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextField(
                  key: const Key('hp-custom-field'),
                  controller: _hp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PG máximos (tirados)'),
                  onChanged: (t) {
                    final n = int.tryParse(t);
                    if (n != null && n > 0) draft.setCustomHpMax(n);
                  },
                ),
              ),
            const CreationSectionTitle('Resumen'),
            CreationStatsSummary(stats: stats),
          ],
        );
      },
    );
  }
}

/// Tarjeta con PG, CA, Iniciativa, Percepción pasiva y Salvaciones.
class CreationStatsSummary extends StatelessWidget {
  const CreationStatsSummary({super.key, required this.stats});

  final ComputedStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(String key, String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, key: Key('stat-$key'), style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        );

    return Card(
      key: const Key('stats-summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                tile('hp', 'PG', '${stats.hpMax}'),
                tile('ac', 'CA', '${stats.ac}'),
                tile('init', 'Iniciativa', signed(stats.initiative)),
                tile('perception', 'Percepción pasiva', '${stats.passivePerception}'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Salvaciones', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final k in kAbilityKeys)
                  Chip(
                    key: Key('save-$k'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: stats.savingThrowProficiencies.contains(k)
                        ? scheme.primaryContainer
                        : null,
                    label: Text(
                      '${kAbilityNames[k]!.substring(0, 3).toUpperCase()} ${signed(stats.savingThrows[k]!)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
