// Pestaña "Mochila": monedero, equipo, compañeros e historia.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_palette.dart';
import '../../core/theme/telemetry.dart';
import '../../core/ui/tactical_card.dart';
import '../../domain/models/character.dart';
import 'editor_dialog_companion.dart';
import 'editor_dialog_item.dart';
import 'editor_fields.dart';
import 'editor_srd_pickers.dart';

class EditorTabMochila extends StatefulWidget {
  const EditorTabMochila({
    super.key,
    required this.draft,
    required this.onChanged,
  });

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
      builder: (_) =>
          MundaneItemDialog(initial: index == null ? null : items[index]),
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
        description:
            'CA ${armor.category == 'escudo' ? '+' : ''}${armor.baseAc} · ${armor.category}'
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
      builder: (_) =>
          CompanionDialog(initial: index == null ? null : companions[index]),
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

    final tactical = context.tactical;

    // Una fila por moneda: insignia metálica con la sigla + el stepper.
    Widget coin(
      String id,
      String label,
      String badge,
      Color metal,
      int value,
      ValueChanged<int> set,
    ) => TacticalCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      tone: metal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _CoinBadge(label: badge, metal: metal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
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
          ),
        ],
      ),
    );

    return ListView(
      key: const Key('list-mochila'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ----------------------------- monedero ----------------------------
        const EditorBlockTitle('Monedero'),
        coin(
          'coin-pp',
          'Platino (pp)',
          'PP',
          tactical.coinPlatinum,
          purse.platinum,
          (v) => purse.platinum = v,
        ),
        coin(
          'coin-po',
          'Oro (po)',
          'PO',
          tactical.coinGold,
          purse.gold,
          (v) => purse.gold = v,
        ),
        coin(
          'coin-pe',
          'Electro (pe)',
          'PE',
          tactical.coinElectrum,
          purse.electrum,
          (v) => purse.electrum = v,
        ),
        coin(
          'coin-pl',
          'Plata (pp)',
          'PP',
          tactical.coinSilver,
          purse.silver,
          (v) => purse.silver = v,
        ),
        coin(
          'coin-pc',
          'Cobre (pc)',
          'PC',
          tactical.coinCopper,
          purse.copper,
          (v) => purse.copper = v,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Equivalente total: ${_formatGold(purse.totalInGold)} po',
            style: theme.textTheme.bodySmall
                ?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                )
                .tabular,
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
        if (items.isEmpty)
          const EditorEmptyHint('La ficha no trae objetos todavía.'),
        for (var i = 0; i < items.length; i++)
          TacticalCard(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              leading: EditorIconPlate(
                icon: Icons.backpack_outlined,
                tone: theme.colorScheme.primary,
              ),
              title: Text(
                items[i].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
        if (companions.isEmpty)
          const EditorEmptyHint('La ficha no trae compañeros todavía.'),
        for (var i = 0; i < companions.length; i++)
          TacticalCard(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            tone: tactical.heal,
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tactical.heal.withValues(alpha: 0.15),
                  border: Border.all(
                    color: tactical.heal.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  companions[i].hasHp ? '${companions[i].currentHp}' : '—',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(
                        color: tactical.heal,
                        fontWeight: FontWeight.w800,
                      )
                      .tabular,
                ),
              ),
              title: Text(
                companions[i].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
        TacticalCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('lore-expansion'),
              title: const Text('Historia y personalidad'),
              subtitle: Text(_loreSubtitle(draft)),
              childrenPadding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final field
                    in <(String, String, String, ValueChanged<String>)>[
                      (
                        'Trasfondo',
                        lore.backstory,
                        'De dónde viene y qué lo trajo hasta acá',
                        (v) => lore.backstory = v,
                      ),
                      (
                        'Rasgos de personalidad',
                        lore.personalityTraits,
                        'Cómo se comporta',
                        (v) => lore.personalityTraits = v,
                      ),
                      (
                        'Ideales',
                        lore.ideals,
                        'Lo que defiende incluso cuando le cuesta',
                        (v) => lore.ideals = v,
                      ),
                      (
                        'Vínculos',
                        lore.bonds,
                        'Personas, lugares o promesas',
                        (v) => lore.bonds = v,
                      ),
                      (
                        'Defectos',
                        lore.flaws,
                        'La grieta que lo mete en problemas',
                        (v) => lore.flaws = v,
                      ),
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
        ),
      ],
    );
  }

  static String _loreSubtitle(CharacterModel draft) {
    final lore = draft.loreInfo;
    final filled = [
      lore.backstory,
      lore.personalityTraits,
      lore.ideals,
      lore.bonds,
      lore.flaws,
    ].where((t) => t.trim().isNotEmpty).length;
    return filled == 0 ? 'sin completar' : '$filled de 5 campos';
  }
}

/// Insignia metálica de una moneda: disco con degradado del metal, canto
/// brillante y la sigla grabada (PP, PO, PE, PC).
class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.label, required this.metal});

  final String label;
  final Color metal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.35),
      metal,
    );
    final onMetal =
        ThemeData.estimateBrightnessForColor(metal) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, metal, Color.alphaBlend(Colors.black26, metal)],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(color: highlight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: metal.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: onMetal,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
