// Paso 1 — Identidad, raza y clase.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/class_catalog.dart';
import '../../domain/character_builder_engine.dart';
import 'creation_draft_controller.dart';
import 'creation_widgets.dart';

class CreationStepIdentity extends StatefulWidget {
  const CreationStepIdentity({super.key, required this.draft, required this.classes});

  final CreationDraftController draft;
  final List<SrdClass> classes;

  @override
  State<CreationStepIdentity> createState() => _CreationStepIdentityState();
}

class _CreationStepIdentityState extends State<CreationStepIdentity> {
  // Los controllers nacen del borrador: al volver con "Atrás" el paso se
  // reconstruye y los textos reaparecen tal como estaban.
  late final _name = TextEditingController(text: widget.draft.name);
  late final _race = TextEditingController(text: widget.draft.race);
  late final _subclass = TextEditingController(text: widget.draft.subclass);
  late final _background = TextEditingController(text: widget.draft.background);

  @override
  void dispose() {
    _name.dispose();
    _race.dispose();
    _subclass.dispose();
    _background.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cls = draft.srdClass;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Identidad y clase', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('creation-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
              onChanged: draft.setName,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: Text('Nivel', style: theme.textTheme.titleSmall)),
                CreationStepper(
                  keyPrefix: 'level',
                  value: '${draft.level}',
                  onDec: draft.level > 1 ? () => draft.setLevel(draft.level - 1) : null,
                  onInc: draft.level < 20 ? () => draft.setLevel(draft.level + 1) : null,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('Velocidad (pies)', style: theme.textTheme.titleSmall)),
                CreationStepper(
                  keyPrefix: 'speed',
                  value: '${draft.speed}',
                  onDec: draft.speed > 5 ? () => draft.setSpeed(draft.speed - 5) : null,
                  onInc: draft.speed < 120 ? () => draft.setSpeed(draft.speed + 5) : null,
                ),
              ],
            ),
            const CreationSectionTitle('Clase'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in widget.classes)
                  ChoiceChip(
                    key: Key('class-${c.id}'),
                    label: Text(c.name),
                    selected: cls?.id == c.id,
                    onSelected: (_) => draft.selectClass(c),
                  ),
              ],
            ),
            if (cls != null) _ClassCard(cls: cls),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('creation-subclass'),
              controller: _subclass,
              decoration: const InputDecoration(labelText: 'Subclase (opcional)'),
              onChanged: draft.setSubclass,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('creation-race'),
              controller: _race,
              decoration: const InputDecoration(labelText: 'Raza / especie'),
              onChanged: draft.setRace,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('creation-background'),
              controller: _background,
              decoration: const InputDecoration(labelText: 'Trasfondo'),
              onChanged: draft.setBackground,
            ),
          ],
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls});

  final SrdClass cls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String names(List<String> keys) => keys.map((k) => kAbilityNames[k] ?? k).join(', ');
    return Card(
      key: const Key('class-card'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cls.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Dado de golpe: d${cls.hitDie}', style: theme.textTheme.bodyMedium),
            Text('Salvaciones: ${names(cls.savingThrows)}', style: theme.textTheme.bodyMedium),
            Text('Característica principal: ${names(cls.primaryAbilities)}',
                style: theme.textTheme.bodyMedium),
            if (cls.isSpellcaster)
              Text('Lanza conjuros con ${kAbilityNames[cls.spellcastingAbility] ?? ''}',
                  style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
