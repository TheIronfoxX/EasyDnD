// Pestaña "Grimorio": conjuros (todos activos: la ficha no tiene noción
// de "preparado"), ranuras 1-9 con steppers y recursos gastables.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import 'editor_ability_page.dart';
import 'editor_fields.dart';
import 'editor_tab_arsenal.dart' show categoryOf, kCategoryChipLabels, reclassifyAbility;
import 'spell_picker_sheet.dart';

/// Recargas de un recurso: clave del shape → etiqueta.
const Map<String, String> kRecoveryLabels = {
  'short_rest': 'Descanso corto',
  'long_rest': 'Descanso largo',
  'manual': 'Manual',
};

class EditorTabGrimorio extends StatefulWidget {
  const EditorTabGrimorio({super.key, required this.draft, required this.onChanged});

  final CharacterModel draft;
  final VoidCallback onChanged;

  @override
  State<EditorTabGrimorio> createState() => _EditorTabGrimorioState();
}

class _EditorTabGrimorioState extends State<EditorTabGrimorio> {
  void _touch() {
    setState(() {});
    widget.onChanged();
  }

  // ------------------------------ conjuros -----------------------------

  Future<void> _addSrdSpell() async {
    final result = await showSpellPickerSheet(context);
    if (!mounted || result == null) return;
    final (ability, category) = result;
    widget.draft.abilitiesByAction.listFor(category).add(ability);
    _touch();
  }

  Future<void> _addHomebrewSpell() async {
    final result = await showDialog<(Ability, String)>(
      context: context,
      builder: (_) => const _HomebrewSpellDialog(),
    );
    if (result == null) return;
    widget.draft.abilitiesByAction.listFor(result.$2).add(result.$1);
    _touch();
  }

  Future<void> _openSpell(Ability ability) async {
    final abilities = widget.draft.abilitiesByAction;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorAbilityPage(
          abilities: abilities,
          ability: ability,
          category: categoryOf(abilities, ability),
          isNew: false,
        ),
      ),
    );
    if (mounted) _touch();
  }

  // ------------------------------ ranuras ------------------------------

  void _setSlotMax(int level, int value) {
    final slots = widget.draft.spellSlots.slots;
    final existing = widget.draft.spellSlots.forLevel(level);
    if (value <= 0) {
      slots.removeWhere((s) => s.level == level);
    } else if (existing == null) {
      slots
        ..add(SpellSlot(level: level, max: value, current: value))
        ..sort((a, b) => a.level.compareTo(b.level));
    } else {
      // Si estaba llena sigue llena; si estaba gastada se respeta, salvo
      // que quede por encima del tope nuevo (current <= max siempre).
      final wasFull = existing.current >= existing.max;
      existing.max = value;
      if (wasFull || existing.current > value) existing.current = value;
    }
    _touch();
  }

  // ------------------------------ recursos -----------------------------

  void _addResource() {
    widget.draft.resources.add(
      ResourcePoint(name: 'Nuevo recurso', current: 1, max: 1),
    );
    _touch();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final theme = Theme.of(context);
    final spells = draft.abilitiesByAction.all.where((a) => a.isSpell).toList()
      ..sort((a, b) => a.baseLevel.compareTo(b.baseLevel));
    final resources = draft.resources;

    return ListView(
      key: const Key('list-grimorio'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        EditorBlockTitle('Conjuros · ${spells.length}'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              key: const Key('add-srd-spell'),
              onPressed: _addSrdSpell,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('+ Conjuro SRD'),
            ),
            OutlinedButton.icon(
              key: const Key('add-homebrew-spell'),
              onPressed: _addHomebrewSpell,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('+ Conjuro casero'),
            ),
          ],
        ),
        if (spells.isEmpty) const EditorEmptyHint('La ficha no trae conjuros todavía.'),
        for (final spell in spells)
          _SpellCard(
            key: ObjectKey(spell),
            spell: spell,
            category: categoryOf(draft.abilitiesByAction, spell),
            onReclassify: (target) {
              reclassifyAbility(draft.abilitiesByAction, spell, target);
              _touch();
            },
            onOpen: () => _openSpell(spell),
            onDelete: () {
              for (final key in ['action', 'bonusAction', 'reaction', 'passive']) {
                draft.abilitiesByAction.listFor(key).removeWhere((a) => identical(a, spell));
              }
              _touch();
            },
            onChanged: _touch,
          ),

        // ------------------------------ ranuras ----------------------------
        const EditorBlockTitle('Ranuras de conjuro'),
        LayoutBuilder(
          builder: (context, constraints) {
            final cell = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var level = 1; level <= 9; level++)
                  SizedBox(
                    width: cell,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EditorStepperField(
                          id: 'slot-$level',
                          label: 'Nivel $level',
                          value: draft.spellSlots.forLevel(level)?.max ?? 0,
                          onChanged: (v) => _setSlotMax(level, v ?? 0),
                        ),
                        if (draft.spellSlots.forLevel(level) != null)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: Text(
                              '${draft.spellSlots.forLevel(level)!.current} de '
                              '${draft.spellSlots.forLevel(level)!.max} disponibles',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),

        // ------------------------------ recursos ---------------------------
        EditorBlockTitle(
          'Recursos',
          trailing: TextButton.icon(
            key: const Key('add-resource'),
            onPressed: _addResource,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar recurso'),
          ),
        ),
        if (resources.isEmpty) const EditorEmptyHint('La ficha no trae recursos todavía.'),
        for (var i = 0; i < resources.length; i++)
          _ResourceCard(
            key: ObjectKey(resources[i]),
            index: i,
            resource: resources[i],
            onDelete: () {
              resources.removeAt(i);
              _touch();
            },
            onChanged: _touch,
          ),
      ],
    );
  }
}

class _SpellCard extends StatelessWidget {
  const _SpellCard({
    super.key,
    required this.spell,
    required this.category,
    required this.onReclassify,
    required this.onOpen,
    required this.onDelete,
    required this.onChanged,
  });

  final Ability spell;

  /// Economía de acciones donde vive hoy ('action', 'bonusAction'...).
  final String category;
  final ValueChanged<String> onReclassify;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('spell-card-${spell.id}'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spell.name, style: theme.textTheme.titleSmall),
                        Text(
                          spell.baseLevel == 0 ? 'Truco' : 'Nivel ${spell.baseLevel}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar conjuro',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                // Un conjuro no es pasivo: solo las tres categorías activas.
                for (final e in kCategoryChipLabels.entries)
                  if (e.key != 'passive')
                    ChoiceChip(
                      key: Key('cat-${spell.id}-${e.key}'),
                      label: Text(e.value),
                      selected: category == e.key,
                      onSelected: (_) => onReclassify(e.key),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EditorDiceField(
                    label: 'Dados de daño',
                    initialValue: spell.damageDice ?? '',
                    onChanged: (v) => spell.damageDice = v.trim().isEmpty ? null : v,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: Key('spell-type-${spell.id}'),
                    initialValue: kAttackTypeShortLabels.containsKey(spell.attackType)
                        ? spell.attackType
                        : 'attack',
                    decoration: const InputDecoration(
                      labelText: 'Tirada',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in kAttackTypeShortLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        spell.attackType = v;
                        onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorTextField(
              key: Key('summary-${spell.id}'),
              label: 'Resumen táctico',
              initialValue: spell.tacticalSummary ?? '',
              maxLines: 3,
              minLines: 1,
              onChanged: (v) => spell.tacticalSummary = v.trim().isEmpty ? null : v,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    super.key,
    required this.index,
    required this.resource,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final ResourcePoint resource;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: EditorTextField(
                    key: Key('res-$index-name'),
                    label: 'Nombre',
                    initialValue: resource.name,
                    onChanged: (v) => resource.name = v,
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar recurso',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorStepperField(
              id: 'res-$index-max',
              label: 'Tope de usos',
              value: resource.max,
              onChanged: (v) {
                if (v == null) return;
                // Lleno sigue lleno; gastado se respeta salvo que pase el tope.
                final wasFull = resource.current >= resource.max;
                resource.max = v;
                if (wasFull || resource.current > v) resource.current = v;
                onChanged();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorStepperField(
              id: 'res-$index-cur',
              label: 'Usos restantes',
              value: resource.current,
              max: resource.max,
              onChanged: (v) {
                if (v != null) {
                  resource.current = min(v, resource.max);
                  onChanged();
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: Key('res-$index-recovery'),
              initialValue: kRecoveryLabels.containsKey(resource.recovery)
                  ? resource.recovery
                  : 'manual',
              decoration: const InputDecoration(
                labelText: 'Recarga',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in kRecoveryLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) {
                  resource.recovery = v;
                  onChanged();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta rápida de un conjuro casero: queda como `type: 'spell'`, así el
/// resto de la app lo trata igual que uno del catálogo.
class _HomebrewSpellDialog extends StatefulWidget {
  const _HomebrewSpellDialog();

  @override
  State<_HomebrewSpellDialog> createState() => _HomebrewSpellDialogState();
}

class _HomebrewSpellDialogState extends State<_HomebrewSpellDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _level = 1;
  String _dice = '';
  String _attackType = 'save';
  String _category = 'action';
  String _summary = '';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final dice = _dice.trim();
    Navigator.of(context).pop((
      Ability(
        id: 'spell_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.trim(),
        type: 'spell',
        relatedStat: 'int',
        successDescription: '',
        failureDescription: '',
        attackType: _attackType,
        baseLevel: _level,
        damageDice: dice.isEmpty ? null : dice,
        tacticalSummary: _summary.trim().isEmpty ? null : _summary.trim(),
      ),
      _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo conjuro casero'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('homebrew-spell-name'),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _name = v,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Poné un nombre.' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              EditorStepperField(
                id: 'homebrew-level',
                label: 'Nivel (0 = truco)',
                value: _level,
                max: 9,
                onChanged: (v) => setState(() => _level = v ?? _level),
              ),
              const SizedBox(height: AppSpacing.sm),
              EditorDiceField(
                label: 'Dados de daño',
                initialValue: _dice,
                onChanged: (v) => _dice = v,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _attackType,
                decoration: const InputDecoration(
                  labelText: 'Tirada',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in kAttackTypeShortLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => _attackType = v ?? _attackType,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('homebrew-category'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Se lanza como',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in kCategoryChipLabels.entries)
                    if (e.key != 'passive')
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => _category = v ?? _category,
              ),
              const SizedBox(height: AppSpacing.sm),
              EditorTextField(
                label: 'Resumen táctico',
                initialValue: '',
                maxLines: 3,
                minLines: 1,
                onChanged: (v) => _summary = v,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
