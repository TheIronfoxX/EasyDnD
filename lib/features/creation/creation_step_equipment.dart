// Paso 4 — Equipo y grimorio SRD.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/equipment_catalog.dart';
import '../../data/spell_catalog.dart';
import '../../domain/character_builder_engine.dart';
import 'creation_draft_controller.dart';
import 'creation_step_proficiencies.dart';
import 'creation_widgets.dart';

class CreationStepEquipment extends StatelessWidget {
  const CreationStepEquipment({
    super.key,
    required this.draft,
    required this.weapons,
    required this.armors,
    required this.spells,
  });

  final CreationDraftController draft;
  final List<SrdWeapon> weapons;
  final List<SrdArmor> armors;
  final List<SrdSpell> spells;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cls = draft.srdClass!;
        final stats = draft.stats!;

        Widget badge(bool proficient) => Text(
              proficient ? 'Competente' : 'Sin competencia',
              style: theme.textTheme.labelSmall?.copyWith(
                color: proficient ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            );

        final maxLevel = draft.maxSpellLevel;
        final classSpells = <SrdSpell>[
          if (cls.spellListTag != null)
            ...SpellCatalog.forClass(cls.spellListTag!, spells).where((s) => s.level <= maxLevel),
        ]..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Equipo y grimorio', style: theme.textTheme.titleLarge),
            CreationStatsSummary(stats: stats),
            const CreationSectionTitle('Armaduras', subtitle: 'Una armadura y un escudo como máximo'),
            for (final a in armors)
              CheckboxListTile(
                key: Key('armor-${a.id}'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(a.name),
                subtitle: Text(
                  'CA ${a.category == 'escudo' ? '+' : ''}${a.baseAc} · ${a.category}'
                  '${a.stealthDisadvantage ? ' · Sigilo con desventaja' : ''}',
                ),
                secondary: badge(CharacterBuilderEngine.isArmorProficient(cls, a)),
                value: draft.armors.any((x) => x.id == a.id),
                onChanged: (_) => draft.toggleArmor(a),
              ),
            const CreationSectionTitle('Armas'),
            for (final w in weapons)
              CheckboxListTile(
                key: Key('weapon-${w.id}'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(w.name),
                subtitle: Text(
                  '${w.damageDice ?? '—'} ${w.damageType ?? ''} · ${w.category} · ${w.properties.join(', ')}',
                ),
                secondary: badge(CharacterBuilderEngine.isWeaponProficient(cls, w)),
                value: draft.weapons.any((x) => x.id == w.id),
                onChanged: (_) => draft.toggleWeapon(w),
              ),
            if (cls.isSpellcaster) ...[
              CreationSectionTitle(
                'Grimorio',
                subtitle: maxLevel == 0
                    ? 'Solo trucos a este nivel'
                    : 'Conjuros de ${cls.name} hasta nivel $maxLevel',
              ),
              for (final s in classSpells)
                CheckboxListTile(
                  key: Key('spell-${s.englishName}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(s.name),
                  subtitle: Text('${s.level == 0 ? 'Truco' : 'Nivel ${s.level}'} · ${s.school}'),
                  value: draft.spells.any((x) => x.name == s.name),
                  onChanged: (_) => draft.toggleSpell(s),
                ),
            ],
          ],
        );
      },
    );
  }
}
