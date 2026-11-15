// Pestaña "Arsenal": armas (con daño condicional en línea y alta desde
// el catálogo SRD) y rasgos por economía de acción, reclasificables en
// un toque — lo que más hace falta tras importar de Nivel20, que vuelca
// muchos rasgos como pasivos.

import 'package:flutter/material.dart';

import '../../core/dnd_rules.dart';
import '../../data/class_catalog.dart';
import '../../domain/models/srd_spell.dart' show normalizeSpellName;
import '../../domain/character_builder_engine.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import '../../domain/models/weapon.dart';
import '../../core/theme/design_tokens.dart';
import 'editor_ability_page.dart';
import 'editor_ability_templates.dart';
import 'editor_fields.dart';
import 'editor_srd_pickers.dart';
import 'editor_weapon_page.dart';

/// Chips de reclasificación: clave del shape → etiqueta corta.
const Map<String, String> kCategoryChipLabels = {
  'action': 'Acción',
  'bonusAction': 'Adicional',
  'reaction': 'Reacción',
  'passive': 'Pasiva',
};

/// Mueve [ability] a [category] conservando su id (y la identidad del
/// objeto). Compartido por el Arsenal y el Grimorio.
void reclassifyAbility(AbilitiesByAction abilities, Ability ability, String category) {
  for (final list in [
    abilities.action,
    abilities.bonusAction,
    abilities.reaction,
    abilities.passive,
  ]) {
    list.removeWhere((a) => identical(a, ability));
  }
  abilities.listFor(category).add(ability);
  if (category == 'passive' && (ability.tacticalRole ?? '').isEmpty) {
    ability.tacticalRole = 'Utilidad';
  }
}

/// Categoría de economía de acciones donde vive [ability] hoy.
String categoryOf(AbilitiesByAction abilities, Ability ability) {
  for (final key in kCategoryChipLabels.keys) {
    if (abilities.listFor(key).any((a) => identical(a, ability))) return key;
  }
  return 'action';
}

class EditorTabArsenal extends StatefulWidget {
  const EditorTabArsenal({super.key, required this.draft, required this.onChanged});

  final CharacterModel draft;
  final VoidCallback onChanged;

  @override
  State<EditorTabArsenal> createState() => _EditorTabArsenalState();
}

class _EditorTabArsenalState extends State<EditorTabArsenal> {
  /// null = todas las categorías.
  String? _filter;

  void _touch() {
    setState(() {});
    widget.onChanged();
  }

  // ------------------------------- armas -------------------------------

  Future<void> _addSrdWeapon() async {
    final srd = await showSrdWeaponPicker(context);
    if (srd == null || !mounted) return;
    final draft = widget.draft;
    final basic = draft.basicInfo;

    // Clase conocida por el texto libre ("Pícaro 3", "Mago (Evocación)")
    // para saber si domina el arma; si no se reconoce, se asume que sí.
    final classes = await ClassCatalog.load();
    final text = normalizeSpellName(basic.characterClass);
    SrdClass? cls;
    for (final c in classes) {
      if (text.contains(normalizeSpellName(c.name))) cls = c;
    }
    final weapon = CharacterBuilderEngine.buildWeaponFromMods(
      srd,
      strMod: draft.stats.str.mod,
      dexMod: draft.stats.dex.mod,
      proficiencyBonus: DndRules.proficiencyBonusFor(basic.level),
      proficient: cls == null || CharacterBuilderEngine.isWeaponProficient(cls, srd),
    );
    // Un id único por alta: la misma arma SRD puede entrar dos veces.
    weapon.id = 'weapon_${DateTime.now().microsecondsSinceEpoch}';
    draft.inventory.weapons.add(weapon);
    _touch();
  }

  void _addHomebrewWeapon() {
    final weapon = Weapon(
      id: 'weapon_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Arma sin nombre',
      attackBonus: 0,
      damage: WeaponDamage(baseDice: '1d6', baseType: 'cortante'),
      conditionalDamage: [],
      properties: [],
      homebrewEffect: '',
      magicCharges: MagicCharges(hasCharges: false, max: 0, current: 0),
      successDescription: '',
      failureDescription: '',
    );
    widget.draft.inventory.weapons.add(weapon);
    _openWeapon(weapon, isNew: true);
  }

  Future<void> _openWeapon(Weapon weapon, {bool isNew = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorWeaponPage(weapon: weapon, isNew: isNew),
      ),
    );
    if (mounted) _touch();
  }

  // ------------------------------ rasgos -------------------------------

  /// "+ Habilidad": plantilla SRD (con su recurso vinculado) o casera.
  Future<void> _addTrait() async {
    final pick = await showAbilityTemplatePicker(context);
    if (pick == null || !mounted) return;
    final template = pick.template;
    if (template == null) {
      _addHomebrewTrait();
      return;
    }

    final draft = widget.draft;
    final level = draft.basicInfo.level;
    final ability = template.build(
      level: level,
      mods: {
        for (final key in const ['str', 'dex', 'con', 'int', 'wis', 'cha'])
          key: draft.stats.modFor(key),
      },
      proficiency: DndRules.proficiencyBonusFor(level),
      resources: draft.resources,
    );
    draft.abilitiesByAction.listFor(template.category).add(ability);
    _touch();
    _openAbility(ability, isNew: true);
  }

  void _addHomebrewTrait() {
    final ability = Ability(
      id: 'ability_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Habilidad sin nombre',
      type: 'trait',
      relatedStat: '',
      successDescription: '',
      failureDescription: '',
    );
    widget.draft.abilitiesByAction.action.add(ability);
    _openAbility(ability, isNew: true);
  }

  Future<void> _openAbility(Ability ability, {bool isNew = false}) async {
    final abilities = widget.draft.abilitiesByAction;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorAbilityPage(
          abilities: abilities,
          ability: ability,
          resources: widget.draft.resources,
          category: categoryOf(abilities, ability),
          isNew: isNew,
        ),
      ),
    );
    if (mounted) _touch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weapons = widget.draft.inventory.weapons;
    final abilities = widget.draft.abilitiesByAction;

    return ListView(
      key: const Key('list-arsenal'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        EditorBlockTitle('Armas · ${weapons.length}'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              key: const Key('add-srd-weapon'),
              onPressed: _addSrdWeapon,
              icon: const Icon(Icons.add_rounded),
              label: const Text('+ Arma SRD'),
            ),
            OutlinedButton.icon(
              key: const Key('add-homebrew-weapon'),
              onPressed: _addHomebrewWeapon,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Arma casera'),
            ),
          ],
        ),
        if (weapons.isEmpty) const EditorEmptyHint('La ficha no trae armas todavía.'),
        for (var i = 0; i < weapons.length; i++)
          _WeaponCard(
            key: ObjectKey(weapons[i]),
            weapon: weapons[i],
            onOpen: () => _openWeapon(weapons[i]),
            onDelete: () {
              weapons.removeAt(i);
              _touch();
            },
            onChanged: _touch,
          ),
        EditorBlockTitle(
          'Rasgos y dotes',
          trailing: TextButton.icon(
            key: const Key('add-trait'),
            onPressed: _addTrait,
            icon: const Icon(Icons.add_rounded),
            label: const Text('+ Habilidad'),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              key: const Key('filter-all'),
              label: const Text('Todas'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final e in kCategoryChipLabels.entries)
              ChoiceChip(
                key: Key('filter-${e.key}'),
                label: Text('${e.value} · ${abilities.listFor(e.key).where((a) => !a.isSpell).length}'),
                selected: _filter == e.key,
                onSelected: (_) => setState(() => _filter = e.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in kCategoryChipLabels.entries)
          if (_filter == null || _filter == entry.key)
            for (final ability in abilities.listFor(entry.key).where((a) => !a.isSpell).toList())
              _TraitCard(
                key: ObjectKey(ability),
                ability: ability,
                category: entry.key,
                onReclassify: (target) {
                  reclassifyAbility(abilities, ability, target);
                  _touch();
                },
                onOpen: () => _openAbility(ability),
                onDelete: () {
                  abilities.listFor(entry.key).remove(ability);
                  _touch();
                },
              ),
        if (abilities.all.where((a) => !a.isSpell).isEmpty)
          Text(
            'No hay rasgos todavía.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
      ],
    );
  }
}

class _WeaponCard extends StatefulWidget {
  const _WeaponCard({
    super.key,
    required this.weapon,
    required this.onOpen,
    required this.onDelete,
    required this.onChanged,
  });

  final Weapon weapon;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_WeaponCard> createState() => _WeaponCardState();
}

class _WeaponCardState extends State<_WeaponCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = widget.weapon;
    final bonus = w.attackBonus >= 0 ? '+${w.attackBonus}' : '${w.attackBonus}';
    return Card(
      key: Key('weapon-card-${w.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onOpen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name, style: theme.textTheme.titleSmall),
                        Text(
                          'Ataque $bonus · ${w.damage.baseDice} ${w.damage.baseType}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar arma',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            for (final c in w.conditionalDamage)
              Padding(
                key: ObjectKey(c),
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: EditorTextField(
                        label: 'Condición',
                        initialValue: c.trigger,
                        onChanged: (v) => c.trigger = v,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: EditorDiceField(
                        label: 'Dados',
                        initialValue: c.dice,
                        onChanged: (v) => c.dice = v,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: EditorTextField(
                        label: 'Tipo',
                        initialValue: c.type,
                        onChanged: (v) => c.type = v,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar daño condicional',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        w.conditionalDamage.remove(c);
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('add-conditional-${w.id}'),
                onPressed: () {
                  w.conditionalDamage.add(
                    ConditionalDamage(trigger: '', dice: '1d6', type: 'fuego'),
                  );
                  widget.onChanged();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Daño condicional'),
              ),
            ),
            EditorTextField(
              key: Key('weapon-summary-${w.id}'),
              label: 'Resumen táctico',
              initialValue: w.tacticalSummary ?? '',
              onChanged: (v) => w.tacticalSummary = v.trim().isEmpty ? null : v,
            ),
          ],
        ),
      ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({
    super.key,
    required this.ability,
    required this.category,
    required this.onReclassify,
    required this.onOpen,
    required this.onDelete,
  });

  final Ability ability;
  final String category;
  final ValueChanged<String> onReclassify;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('trait-card-${ability.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    child: Text(ability.name, style: theme.textTheme.titleSmall),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar habilidad',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final e in kCategoryChipLabels.entries)
                  ChoiceChip(
                    key: Key('cat-${ability.id}-${e.key}'),
                    label: Text(e.value),
                    selected: category == e.key,
                    onSelected: (_) => onReclassify(e.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorTextField(
              key: Key('summary-${ability.id}'),
              label: 'Resumen táctico',
              initialValue: ability.tacticalSummary ?? '',
              maxLines: 3,
              minLines: 1,
              onChanged: (v) => ability.tacticalSummary = v.trim().isEmpty ? null : v,
            ),
          ],
        ),
      ),
    );
  }
}
