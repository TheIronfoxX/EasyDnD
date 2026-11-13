// Pestaña Inventario (Etapa 5d).
//
// La vista de equipo del personaje activo: armas (con cantidad y cargas),
// objetos mundanos, bolsa y compañeros. Es la contracara de solo lectura
// del editor: acá el jugador consulta y ajusta lo que cambia en mesa
// (copias de un arma, unidades de un objeto, PG de una mascota), pero no
// edita la ficha.
//
// Mismo contrato que el resto del HUD: los métodos del store se llaman
// sin validar antes y se autoprotegen; el shell escucha el ChangeNotifier
// y vuelve a pintar la pestaña con los valores ya actualizados.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/character.dart';
import '../../domain/models/weapon.dart';
import '../../state/character_store.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';

class HudInventoryTab extends StatelessWidget {
  const HudInventoryTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        _WeaponsSection(character: character),
        _ItemsSection(character: character),
        _PurseSection(character: character),
        _CompanionsSection(character: character),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Armas: daño, cantidad de copias y cargas mágicas.
// ---------------------------------------------------------------------

class _WeaponsSection extends StatelessWidget {
  const _WeaponsSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final weapons = character.inventory.weapons;

    return HudSectionCard(
      icon: Icons.gavel_rounded,
      title: 'Armas',
      child: weapons.isEmpty
          ? const HudEmptyHint('La ficha no trae armas.')
          : Column(
              children: [
                for (final weapon in weapons)
                  _WeaponRow(weapon: weapon, store: store),
              ],
            ),
    );
  }
}

class _WeaponRow extends StatelessWidget {
  const _WeaponRow({required this.weapon, required this.store});

  final Weapon weapon;
  final CharacterStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charges = weapon.magicCharges.hasCharges
        ? _ChargePill(
            current: weapon.magicCharges.current,
            max: weapon.magicCharges.max,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: const Icon(Icons.gavel_rounded, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weapon.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _weaponSubtitle(weapon),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (charges != null) ...[const SizedBox(height: 6), charges],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (weapon.isUnique)
            const _UnitBadge(label: 'Única')
          else
            _QuantityStepper(
              value: weapon.quantity,
              decrementTooltip: 'Restar una copia de ${weapon.name}',
              incrementTooltip: 'Sumar una copia de ${weapon.name}',
              onDecrement: weapon.quantity > 0
                  ? () => store.decrementQuantity(weapon.id)
                  : null,
              onIncrement: () => store.incrementQuantity(weapon.id),
            ),
        ],
      ),
    );
  }

  /// "Ataque +5 · 1d8+3 cortante", el mismo resumen que usa el editor.
  static String _weaponSubtitle(Weapon weapon) {
    final bonus = weapon.attackBonus >= 0
        ? '+${weapon.attackBonus}'
        : '${weapon.attackBonus}';
    return 'Ataque $bonus · ${weapon.damage.baseDice} ${weapon.damage.baseType}';
  }
}

class _ChargePill extends StatelessWidget {
  const _ChargePill({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = current <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: depleted
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$current/$max cargas',
        style: theme.textTheme.labelSmall?.copyWith(
          color: depleted
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Objetos mundanos (cantidad ajustable, sin borrar desde el HUD).
// ---------------------------------------------------------------------

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final items = character.inventory.mundaneItems;

    return HudSectionCard(
      icon: Icons.backpack_rounded,
      title: 'Objetos',
      child: items.isEmpty
          ? const HudEmptyHint('La ficha no trae objetos.')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _ItemRow(item: items[i], index: i, store: store),
              ],
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.index,
    required this.store,
  });

  final MundaneItem item;
  final int index;
  final CharacterStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = item.description.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _QuantityStepper(
            value: item.quantity,
            decrementTooltip: 'Restar una unidad de ${item.name}',
            incrementTooltip: 'Sumar una unidad de ${item.name}',
            onDecrement: item.quantity > 0
                ? () =>
                      store.updateMundaneItemQuantity(index, item.quantity - 1)
                : null,
            onIncrement: () =>
                store.updateMundaneItemQuantity(index, item.quantity + 1),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Bolsa: tres stacks independientes + equivalencia en oro.
// ---------------------------------------------------------------------

class _PurseSection extends StatelessWidget {
  const _PurseSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purse = character.purse;

    return HudSectionCard(
      icon: Icons.payments_rounded,
      title: 'Bolsa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: HudStatTile(
                  icon: Icons.monetization_on_rounded,
                  label: 'Oro',
                  value: '${purse.gold} po',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.circle_rounded,
                  label: 'Plata',
                  value: '${purse.silver} pp',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.circle_outlined,
                  label: 'Cobre',
                  value: '${purse.copper} pc',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Equivale a ${_formatGold(purse.totalInGold)} po',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 15.0 → "15", 15.5 → "15.5", 15.52 → "15.52": sin ceros de relleno.
  static String _formatGold(double total) {
    if (total == total.roundToDouble()) return total.toInt().toString();
    return total.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

// ---------------------------------------------------------------------
// Compañeros: PG gestionables en mesa (o apoyo invulnerable).
// ---------------------------------------------------------------------

class _CompanionsSection extends StatelessWidget {
  const _CompanionsSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final companions = character.companions;

    return HudSectionCard(
      icon: Icons.pets_rounded,
      title: 'Compañeros',
      child: companions.isEmpty
          ? const HudEmptyHint('La ficha no trae compañeros.')
          : Column(
              children: [
                for (var i = 0; i < companions.length; i++)
                  _CompanionRow(
                    companion: companions[i],
                    index: i,
                    store: store,
                  ),
              ],
            ),
    );
  }
}

class _CompanionRow extends StatelessWidget {
  const _CompanionRow({
    required this.companion,
    required this.index,
    required this.store,
  });

  final Companion companion;
  final int index;
  final CharacterStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = companion.type.trim();
    final subtitle = [
      if (type.isNotEmpty) type,
      if (!companion.hasHp) 'Apoyo invulnerable',
      'CA ${companion.ac}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.tertiaryContainer,
                foregroundColor: theme.colorScheme.onTertiaryContainer,
                child: const Icon(Icons.pets_rounded, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (companion.hasHp)
                Text(
                  '${companion.currentHp}/${companion.maxHp} PG',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (companion.hasHp) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: companion.maxHp <= 0
                  ? 0
                  : (companion.currentHp / companion.maxHp).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Quitar 1 PG a ${companion.name}',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: companion.currentHp <= 0
                      ? null
                      : () => store.updateCompanionHp(index, -1),
                ),
                IconButton(
                  tooltip: 'Curar 1 PG a ${companion.name}',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: companion.currentHp >= companion.maxHp
                      ? null
                      : () => store.updateCompanionHp(index, 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas compartidas por las filas del inventario.
// ---------------------------------------------------------------------

/// "− ×3 +": ajuste rápido de copias/unidades. Los botones se
/// deshabilitan en los extremos, pero el store igual clampea.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final String decrementTooltip;
  final String incrementTooltip;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: decrementTooltip,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          onPressed: onDecrement,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 30),
          child: Text(
            '×$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: incrementTooltip,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
