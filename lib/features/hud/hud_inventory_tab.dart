// Pestaña Mochila: subpestañas Equipo (armas y objetos), Dinero y Notas.
//
// Es la contracara de solo lectura del editor: acá el jugador consulta y
// ajusta lo que cambia en mesa (copias de un arma, unidades de un
// objeto, monedas), pero no edita la ficha.
//
// Mismo contrato que el resto del HUD: los métodos del store se llaman
// sin validar antes y se autoprotegen; el shell escucha el ChangeNotifier
// y vuelve a pintar la pestaña con los valores ya actualizados.

import 'package:flutter/material.dart';
import '../../core/ui/app_icons.dart';
import 'package:provider/provider.dart';

import '../../domain/models/character.dart';
import '../../domain/models/weapon.dart';
import '../../state/character_store.dart';
import 'hud_dialogs.dart';
import 'hud_purse_dialog.dart';
import '../editor/editor_dialog_item.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

// ---------------------------------------------------------------------
// Armas: daño, cantidad de copias y cargas mágicas.
// ---------------------------------------------------------------------

class HudWeaponsSection extends StatelessWidget {
  const HudWeaponsSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final weapons = character.inventory.weapons;

    return HudSectionCard(
      icon: AppIcons.of(context).weapon,
      title: 'Armas',
      tone: context.tactical.weapon,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: 'Agregar arma',
        onPressed: () => _showAddWeaponDialog(context, store),
      ),
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

    return _TapRow(
      key: ValueKey('weapon-row-${weapon.id}'),
      onTap: () => _showWeaponSheet(context, weapon.id),
      child: Row(
        children: [
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
          if (!weapon.isUnique && weapon.quantity != 1)
            _QuantityLabel(weapon.quantity),
          const _RowChevron(),
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
    final tone = depleted ? context.tactical.damage : context.tactical.weapon;

    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.tactical.shapes.pillRadius),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$current/$max cargas',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: tone, fontWeight: FontWeight.w700)
                .tabular,
          ),
          const SizedBox(width: 6),
          ResourcePips(current: current, max: max, color: tone, size: 7),
        ],
      ),
    );
  }
}

Future<void> _showAddWeaponDialog(
  BuildContext context,
  CharacterStore store,
) async {
  final weapon = await showAddWeaponDialog(context);
  if (weapon == null) return;
  store.addNewWeapon(weapon);
}

/// Sin confirmación previa (a diferencia de borrar una ficha): el
/// snackbar con "Deshacer" es la red de seguridad para una acción que
/// se revierte con un toque.
void _removeWeaponWithUndo(
  BuildContext context,
  Weapon weapon,
  CharacterStore store,
) {
  store.removeWeapon(weapon.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Se eliminó "${weapon.name}".'),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () => store.addNewWeapon(weapon),
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// Objetos mundanos (cantidad ajustable, sin borrar desde el HUD).
// ---------------------------------------------------------------------

class HudItemsSection extends StatelessWidget {
  const HudItemsSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final items = character.inventory.mundaneItems;

    return HudSectionCard(
      icon: AppIcons.of(context).backpack,
      title: 'Objetos',
      trailing: TextButton.icon(
        key: const Key('hud-add-item'),
        onPressed: () => _addItem(context, store),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Agregar objeto'),
      ),
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

Future<void> _addItem(BuildContext context, CharacterStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  final item = await showDialog<MundaneItem>(
    context: context,
    builder: (_) => const MundaneItemDialog(),
  );
  if (item == null) return;
  store.addMundaneItem(
    name: item.name,
    description: item.description,
    quantity: item.quantity,
  );
  messenger.showSnackBar(SnackBar(content: Text('Agregaste "${item.name}".')));
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

    return _TapRow(
      key: ValueKey('item-row-$index'),
      onTap: () => _showItemSheet(context, index),
      child: Row(
        children: [
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
          if (item.quantity != 1) _QuantityLabel(item.quantity),
          const _RowChevron(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Bolsa: tres stacks independientes + equivalencia en oro.
// ---------------------------------------------------------------------

class HudPurseSection extends StatelessWidget {
  const HudPurseSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purse = character.purse;

    final tactical = context.tactical;

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
                  tone: tactical.coinGold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.circle_rounded,
                  label: 'Plata',
                  value: '${purse.silver} pp',
                  tone: tactical.coinSilver,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.circle_outlined,
                  label: 'Cobre',
                  value: '${purse.copper} pc',
                  tone: tactical.coinCopper,
                ),
              ),
            ],
          ),
          if (purse.platinum > 0 || purse.electrum > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: purse.platinum > 0
                      ? HudStatTile(
                          icon: Icons.diamond_outlined,
                          label: 'Platino',
                          value: '${purse.platinum} pp',
                          tone: tactical.coinPlatinum,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: purse.electrum > 0
                      ? HudStatTile(
                          icon: Icons.hexagon_outlined,
                          label: 'Electro',
                          value: '${purse.electrum} pe',
                          tone: tactical.coinElectrum,
                        )
                      : const SizedBox.shrink(),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Equivale a ${_formatGold(purse.totalInGold)} po',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('hud-spend-money'),
                  onPressed: () => _change(context, spend: true),
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Gastar dinero'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('hud-add-money'),
                  onPressed: () => _change(context, spend: false),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar dinero'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _change(BuildContext context, {required bool spend}) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showPurseDialog(
      context,
      spend: spend,
      purse: character.purse,
    );
    if (choice == null) return;

    final (name, suffix) = kCurrencyLabels[choice.type]!;
    if (spend) {
      store.spendCurrency(choice.type, choice.amount);
    } else {
      store.addCurrency(choice.type, choice.amount);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${spend ? 'Gastaste' : 'Agregaste'} ${choice.amount} $suffix '
          '($name).',
        ),
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

    return TacticalStepper(
      decrementTooltip: decrementTooltip,
      incrementTooltip: incrementTooltip,
      onDecrement: onDecrement,
      onIncrement: onIncrement,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 30),
        child: Text(
          '×$value',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)
              .tabular,
        ),
      ),
    );
  }
}

/// Fila tocable del inventario: el detalle (cantidad, quitar) vive en
/// una hoja aparte para que la lista sea solo nombres.
class _TapRow extends StatelessWidget {
  const _TapRow({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: child,
      ),
    );
  }
}

class _QuantityLabel extends StatelessWidget {
  const _QuantityLabel(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        '×$value',
        style: theme.textTheme.titleSmall
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: value <= 0 ? theme.colorScheme.error : null,
            )
            .tabular,
      ),
    );
  }
}

class _RowChevron extends StatelessWidget {
  const _RowChevron();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs),
    child: Icon(
      Icons.chevron_right_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

// ---------------------------------------------------------------------
// Hojas de detalle: cantidad y quitar. Escuchan el store para reflejar
// cada toque del stepper sin cerrarse.
// ---------------------------------------------------------------------

Future<void> _showWeaponSheet(BuildContext context, String weaponId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final store = sheetContext.watch<CharacterStore>();
      final weapon = store.activeCharacter?.inventory.weapons
          .where((w) => w.id == weaponId)
          .firstOrNull;
      if (weapon == null) return const SizedBox(height: 120);
      return _DetailSheet(
        title: weapon.name,
        description: _WeaponRow._weaponSubtitle(weapon),
        quantity: weapon.isUnique
            ? null
            : _QuantityStepper(
                value: weapon.quantity,
                decrementTooltip: 'Restar una copia de ${weapon.name}',
                incrementTooltip: 'Sumar una copia de ${weapon.name}',
                onDecrement: weapon.quantity > 0
                    ? () => store.decrementQuantity(weapon.id)
                    : null,
                onIncrement: () => store.incrementQuantity(weapon.id),
              ),
        removeLabel: 'Eliminar arma',
        onRemove: () {
          Navigator.of(sheetContext).pop();
          _removeWeaponWithUndo(context, weapon, store);
        },
      );
    },
  );
}

Future<void> _showItemSheet(BuildContext context, int index) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final store = sheetContext.watch<CharacterStore>();
      final items = store.activeCharacter?.inventory.mundaneItems ?? const [];
      if (index >= items.length) return const SizedBox(height: 120);
      final item = items[index];
      return _DetailSheet(
        title: item.name,
        description: item.description.trim(),
        quantity: _QuantityStepper(
          value: item.quantity,
          decrementTooltip: 'Restar una unidad de ${item.name}',
          incrementTooltip: 'Sumar una unidad de ${item.name}',
          onDecrement: item.quantity > 0
              ? () => store.updateMundaneItemQuantity(index, item.quantity - 1)
              : null,
          onIncrement: () =>
              store.updateMundaneItemQuantity(index, item.quantity + 1),
        ),
      );
    },
  );
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.title,
    required this.description,
    this.quantity,
    this.removeLabel,
    this.onRemove,
  });

  final String title;
  final String description;
  final Widget? quantity;
  final String? removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (quantity != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const Expanded(child: Text('Cantidad')),
                quantity!,
              ],
            ),
          ],
          if (onRemove != null) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(removeLabel ?? 'Eliminar'),
            ),
          ],
        ],
      ),
    );
  }
}
