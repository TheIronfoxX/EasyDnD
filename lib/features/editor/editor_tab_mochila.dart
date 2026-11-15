// Pestaña "Mochila": monedero, equipo, compañeros e historia.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/models/character.dart';
import 'editor_dialog_companion.dart';
import 'editor_dialog_item.dart';
import 'editor_fields.dart';
import 'editor_srd_pickers.dart';

class EditorTabMochila extends StatefulWidget {
  const EditorTabMochila({super.key, required this.draft, required this.onChanged});

  final CharacterModel draft;
  final VoidCallback onChanged;

  @override
  State<EditorTabMochila> createState() => _EditorTabMochilaState();
}

class _EditorTabMochilaState extends State<EditorTabMochila> {
  void _touch() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editItem({int? index}) async {
    final items = widget.draft.inventory.mundaneItems;
    final result = await showDialog<MundaneItem>(
      context: context,
      builder: (_) => MundaneItemDialog(initial: index == null ? null : items[index]),
    );
    if (result == null) return;
    if (index == null) {
      items.add(result);
    } else {
      items[index] = result;
    }
    _touch();
  }

  Future<void> _addSrdArmor() async {
    final armor = await showSrdArmorPicker(context);
    if (armor == null) return;
    widget.draft.inventory.mundaneItems.add(
      MundaneItem(
        name: armor.name,
        description: 'CA ${armor.category == 'escudo' ? '+' : ''}${armor.baseAc} · ${armor.category}'
            '${armor.stealthDisadvantage ? ' · desventaja en Sigilo' : ''}',
        quantity: 1,
      ),
    );
    _touch();
  }

  Future<void> _editCompanion({int? index}) async {
    final companions = widget.draft.companions;
    final result = await showDialog<Companion>(
      context: context,
      builder: (_) => CompanionDialog(initial: index == null ? null : companions[index]),
    );
    if (result == null) return;
    if (index == null) {
      companions.add(result);
    } else {
      companions[index] = result;
    }
    _touch();
  }

  static String _companionSubtitle(Companion c) => [
        if (c.type.isNotEmpty) c.type,
        c.hasHp ? '${c.currentHp}/${c.maxHp} PG' : 'invulnerable',
        'CA ${c.ac}',
      ].join(' · ');

  static String _formatGold(double total) {
    if (total == total.roundToDouble()) return total.toInt().toString();
    return total.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final theme = Theme.of(context);
    final purse = draft.purse;
    final items = draft.inventory.mundaneItems;
    final companions = draft.companions;
    final lore = draft.loreInfo;

    Widget coin(String id, String label, int value, ValueChanged<int> set) => SizedBox(
          width: 190,
          child: EditorStepperField(
            id: id,
            label: label,
            value: value,
            onChanged: (v) {
              if (v != null) {
                set(v);
                _touch();
              }
            },
          ),
        );

    return ListView(
      key: const Key('list-mochila'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ----------------------------- monedero ----------------------------
        const EditorBlockTitle('Monedero'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            coin('coin-pp', 'Platino (pp)', purse.platinum, (v) => purse.platinum = v),
            coin('coin-po', 'Oro (po)', purse.gold, (v) => purse.gold = v),
            coin('coin-pe', 'Electro (pe)', purse.electrum, (v) => purse.electrum = v),
            coin('coin-pl', 'Plata (pp)', purse.silver, (v) => purse.silver = v),
            coin('coin-pc', 'Cobre (pc)', purse.copper, (v) => purse.copper = v),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Equivalente total: ${_formatGold(purse.totalInGold)} po',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),

        // ------------------------------ equipo -----------------------------
        EditorBlockTitle('Equipo · ${items.length}'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              key: const Key('add-srd-armor'),
              onPressed: _addSrdArmor,
              icon: const Icon(Icons.shield_rounded),
              label: const Text('+ Armadura / Escudo SRD'),
            ),
            OutlinedButton.icon(
              key: const Key('add-item'),
              onPressed: () => _editItem(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar objeto'),
            ),
          ],
        ),
        if (items.isEmpty) const EditorEmptyHint('La ficha no trae objetos todavía.'),
        for (var i = 0; i < items.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backpack_outlined),
            title: Text(items[i].name),
            subtitle: Text(
              items[i].description.isEmpty
                  ? '×${items[i].quantity}'
                  : '${items[i].description} · ×${items[i].quantity}',
            ),
            trailing: IconButton(
              tooltip: 'Borrar objeto',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                items.removeAt(i);
                _touch();
              },
            ),
            onTap: () => _editItem(index: i),
          ),

        // --------------------------- compañeros ----------------------------
        EditorBlockTitle(
          'Compañeros · ${companions.length}',
          trailing: TextButton.icon(
            key: const Key('add-companion'),
            onPressed: () => _editCompanion(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar compañero'),
          ),
        ),
        if (companions.isEmpty) const EditorEmptyHint('La ficha no trae compañeros todavía.'),
        for (var i = 0; i < companions.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                maxRadius: 16,
                child: Text(companions[i].hasHp ? '${companions[i].currentHp}' : '—'),
              ),
              title: Text(companions[i].name),
              subtitle: Text(_companionSubtitle(companions[i])),
              trailing: IconButton(
                tooltip: 'Borrar compañero',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {
                  companions.removeAt(i);
                  _touch();
                },
              ),
              onTap: () => _editCompanion(index: i),
            ),
          ),

        // ------------------------------ historia ---------------------------
        const SizedBox(height: AppSpacing.md),
        Card(
          child: ExpansionTile(
            key: const Key('lore-expansion'),
            title: const Text('Historia y personalidad'),
            subtitle: Text(_loreSubtitle(draft)),
            childrenPadding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final field in <(String, String, String, ValueChanged<String>)>[
                ('Trasfondo', lore.backstory, 'De dónde viene y qué lo trajo hasta acá', (v) => lore.backstory = v),
                ('Rasgos de personalidad', lore.personalityTraits, 'Cómo se comporta', (v) => lore.personalityTraits = v),
                ('Ideales', lore.ideals, 'Lo que defiende incluso cuando le cuesta', (v) => lore.ideals = v),
                ('Vínculos', lore.bonds, 'Personas, lugares o promesas', (v) => lore.bonds = v),
                ('Defectos', lore.flaws, 'La grieta que lo mete en problemas', (v) => lore.flaws = v),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: EditorTextField(
                    label: field.$1,
                    initialValue: field.$2,
                    hint: field.$3,
                    maxLines: 4,
                    minLines: 2,
                    onChanged: (v) {
                      field.$4(v);
                      widget.onChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _loreSubtitle(CharacterModel draft) {
    final lore = draft.loreInfo;
    final filled = [lore.backstory, lore.personalityTraits, lore.ideals, lore.bonds, lore.flaws]
        .where((t) => t.trim().isNotEmpty)
        .length;
    return filled == 0 ? 'sin completar' : '$filled de 5 campos';
  }
}
