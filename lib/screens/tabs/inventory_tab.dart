// lib/screens/tabs/inventory_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weapon_model.dart';
import '../../models/character_model.dart' show CurrencyType, Purse, MundaneItem;
import '../../providers/character_provider.dart';
import '../../theme/theme_notifier.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/themed_card.dart';

/// Hotfix (Objetivo 2): vuelve a StatelessWidget. La cantidad por ítem ya
/// no vive en un Map local de este widget (se perdía al reiniciar la
/// app) — ahora vive y se persiste en CharacterProvider.
///
/// Paso 1 (Vertical Slice) — Gestión de Oro: la bolsa del personaje es la
/// primera tarjeta dentro de la lista (ya no una cabecera fija), así que
/// se desplaza junto con el resto del inventario.
class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final weapons = provider.character.inventory.weapons;
    final mundaneItems = provider.character.inventory.mundaneItems;
    final purse = provider.character.purse;
    final accent = context.watch<ThemeNotifier>().accentColor;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              _PurseCard(purse: purse, accent: accent),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'ARMAS',
                accent: accent,
                onAdd: () => _openAddWeaponDialog(context, accent),
              ),
              const SizedBox(height: 10),
              if (weapons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Sin armas todavía. Toca "+" para añadir una.',
                    style: TextStyle(
                      color: context.appColors.textSecondary.withOpacity(0.8),
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                    ),
                  ),
                )
              else
                ...weapons.map(
                  (weapon) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _WeaponCard(
                      weapon: weapon,
                      accent: accent,
                      quantity: provider.quantityFor(weapon.id),
                      onIncrement: () => provider.incrementQuantity(weapon.id),
                      onDecrement: () => provider.decrementQuantity(weapon.id),
                      onRemove: () => provider.removeWeapon(weapon.id),
                    ),
                  ),
                ),
              // Mundane Items Inventory: sección propia bajo la lista de
              // armas. Se oculta entera (ni siquiera la cabecera) si el
              // personaje no trae objetos mundanos.
              _MundaneItemsSection(items: mundaneItems, accent: accent),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paso 7 (Vertical Slice) — Constructores rápidos de inventario.
///
/// Cabecera de sección reutilizable: título + botón de "Añadir" bien
/// visible (círculo con "+", mismo lenguaje que el resto del HUD). La
/// usan tanto la sección de Armas como la de Objetos Mundanos para que
/// el patrón de "cómo se añade algo nuevo" sea idéntico en toda la
/// pestaña.
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.title,
    required this.accent,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.15),
                border: Border.all(color: accent.withOpacity(0.5), width: 1),
              ),
              child: Icon(Icons.add, color: accent, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paso 7 — Diálogo de "Añadir Arma". Recoge nombre, bonificador de
/// ataque y el dado/tipo de daño base — lo mínimo para que el arma
/// aparezca operativa en Turno e Inventario. El resto de campos
/// (propiedades, daño condicional, efecto homebrew, cargas mágicas,
/// descripciones de éxito/fallo) arrancan vacíos/por defecto y el
/// jugador los puede rellenar más tarde editando la ficha.
void _openAddWeaponDialog(BuildContext context, Color accent) {
  final nameController = TextEditingController();
  final attackBonusController = TextEditingController(text: '0');
  final diceController = TextEditingController();
  final typeController = TextEditingController();
  final provider = context.read<CharacterProvider>();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.appColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Nueva arma',
        style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
              decoration: InputDecoration(
                hintText: 'Nombre',
                hintStyle: TextStyle(color: context.appColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: attackBonusController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Bonificador de ataque (ej. 5)',
                hintStyle: TextStyle(color: context.appColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: diceController,
                    style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Dado (ej. 1d8+3)',
                      hintStyle: TextStyle(color: context.appColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: typeController,
                    style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
                    decoration: InputDecoration(
                      hintText: 'Tipo (ej. cortante)',
                      hintStyle: TextStyle(color: context.appColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('Cancelar', style: TextStyle(color: context.appColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              Navigator.pop(dialogContext);
              return;
            }
            final attackBonus = int.tryParse(attackBonusController.text.trim()) ?? 0;
            final dice = diceController.text.trim();
            final type = typeController.text.trim();

            provider.addNewWeapon(
              Weapon(
                // Id estable a partir de la hora de creación — nunca se
                // repite entre dos altas rápidas, ni siquiera si el
                // jugador teclea el mismo nombre dos veces.
                id: 'weapon_${DateTime.now().microsecondsSinceEpoch}',
                name: name,
                attackBonus: attackBonus,
                damage: WeaponDamage(
                  baseDice: dice.isEmpty ? '1d4' : dice,
                  baseType: type.isEmpty ? 'contundente' : type,
                ),
                conditionalDamage: const [],
                properties: const [],
                homebrewEffect: '',
                magicCharges: MagicCharges(hasCharges: false, max: 0, current: 0),
                successDescription: '',
                failureDescription: '',
              ),
            );
            Navigator.pop(dialogContext);
          },
          child: Text('Añadir', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

/// Mundane Items Inventory.
///
/// Sección para objetos no mágicos (raciones, cuerda, antorchas,
/// herramientas...) bajo la lista de armas. Cabecera con botón "+" para
/// añadir un objeto nuevo; si la lista está vacía, muestra un mensaje
/// indicativo en vez de ocultarse del todo, para que el jugador sepa que
/// puede añadir objetos aunque no tenga ninguno todavía.
class _MundaneItemsSection extends StatelessWidget {
  final List<MundaneItem> items;
  final Color accent;

  const _MundaneItemsSection({required this.items, required this.accent});

  void _openAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final provider = context.read<CharacterProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Nuevo objeto',
          style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
              decoration: InputDecoration(
                hintText: 'Nombre',
                hintStyle: TextStyle(color: context.appColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
              decoration: InputDecoration(
                hintText: 'Descripción (opcional)',
                hintStyle: TextStyle(color: context.appColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: context.appColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                // Paso 7 — Constructor rápido: si el jugador no se para a
                // escribir un nombre, no bloqueamos el alta — le damos un
                // placeholder editable después ("Nuevo Objeto").
                provider.addEmptyMundaneItem();
              } else {
                provider.addMundaneItem(
                  name: name,
                  description: descController.text.trim(),
                );
              }
              Navigator.pop(dialogContext);
            },
            child: Text('Añadir', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'OBJETOS MUNDANOS',
            accent: accent,
            onAdd: () => _openAddItemDialog(context),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Sin objetos mundanos todavía. Toca "+" para añadir raciones, cuerda, herramientas...',
                style: TextStyle(
                  color: context.appColors.textSecondary.withOpacity(0.8),
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                ),
              ),
            )
          else
            ...items.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MundaneItemCard(
                      item: entry.value,
                      accent: accent,
                      onIncrement: () => context
                          .read<CharacterProvider>()
                          .updateMundaneItemQuantity(entry.key, entry.value.quantity + 1),
                      onDecrement: () => context
                          .read<CharacterProvider>()
                          .updateMundaneItemQuantity(entry.key, entry.value.quantity - 1),
                      onRemove: () => context.read<CharacterProvider>().removeMundaneItem(entry.key),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Tarjeta de un objeto mundano individual: nombre, descripción (si
/// tiene), stepper +/- de cantidad y un botón de papelera para
/// eliminarlo del inventario. Mismo tratamiento visual (ThemedCard) que
/// _WeaponCard y _ResourceCard.
class _MundaneItemCard extends StatelessWidget {
  final MundaneItem item;
  final Color accent;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _MundaneItemCard({
    required this.item,
    required this.accent,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, color: context.appColors.textSecondary, size: 18),
                ),
              ),
            ],
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13,
                fontFamily: 'serif',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CANTIDAD',
                style: TextStyle(color: context.appColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'serif'),
              ),
              Row(
                children: [
                  _StepperButton(icon: Icons.remove, accent: accent, onTap: onDecrement),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                  ),
                  _StepperButton(icon: Icons.add, accent: accent, onTap: onIncrement),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de cabecera con las tres denominaciones de moneda (oro, plata,
/// cobre). Cada fila tiene su propio stepper +/-, un tap para fijar un
/// valor exacto y una pulsación larga para una transacción rápida con
/// importes preestablecidos (útil al repartir botín tras un combate).
class _PurseCard extends StatelessWidget {
  final Purse purse;
  final Color accent;

  const _PurseCard({required this.purse, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'BOLSA',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'serif',
                ),
              ),
              const Spacer(),
              Text(
                '≈ ${purse.totalInGold.toStringAsFixed(1)} po',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CurrencyRow(
            type: CurrencyType.gold,
            label: 'ORO',
            suffix: 'po',
            value: purse.gold,
            color: const Color(0xFFD4AF37),
          ),
          const SizedBox(height: 10),
          _CurrencyRow(
            type: CurrencyType.silver,
            label: 'PLATA',
            suffix: 'pp',
            value: purse.silver,
            color: const Color(0xFFC0C0C0),
          ),
          const SizedBox(height: 10),
          _CurrencyRow(
            type: CurrencyType.copper,
            label: 'COBRE',
            suffix: 'pc',
            value: purse.copper,
            color: const Color(0xFFB87333),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Toca la cantidad para fijar un valor exacto · mantén pulsado para una transacción rápida',
              style: TextStyle(
                color: context.appColors.textSecondary.withOpacity(0.7),
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final CurrencyType type;
  final String label;
  final String suffix;
  final int value;
  final Color color;

  const _CurrencyRow({
    required this.type,
    required this.label,
    required this.suffix,
    required this.value,
    required this.color,
  });

  void _openEditDialog(BuildContext context) {
    final controller = TextEditingController(text: '$value');
    final provider = context.read<CharacterProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Fijar $label',
          style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'serif'),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: context.appColors.textPrimary, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Cantidad exacta de $suffix',
            hintStyle: TextStyle(color: context.appColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color.withOpacity(0.4))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: context.appColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null) {
                provider.setCurrency(type, parsed);
              }
              Navigator.pop(dialogContext);
            },
            child: Text('Guardar', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openQuickTransactionSheet(BuildContext context) {
    final provider = context.read<CharacterProvider>();
    const presets = [1, 5, 10, 50, 100];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transacción rápida — $label',
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'GANAR',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'serif'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    return ActionChip(
                      label: Text('+$p', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      backgroundColor: color.withOpacity(0.15),
                      side: BorderSide(color: color.withOpacity(0.4)),
                      onPressed: () {
                        provider.addCurrency(type, p);
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'GASTAR',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'serif'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    return ActionChip(
                      label: Text('-$p', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      backgroundColor: Colors.redAccent.withOpacity(0.12),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.35)),
                      onPressed: () {
                        provider.spendCurrency(type, p);
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                fontFamily: 'serif',
              ),
            ),
          ],
        ),
        Row(
          children: [
            _StepperButton(icon: Icons.remove, accent: color, onTap: () => provider.spendCurrency(type, 1)),
            GestureDetector(
              onTap: () => _openEditDialog(context),
              onLongPress: () => _openQuickTransactionSheet(context),
              child: Container(
                width: 78,
                alignment: Alignment.center,
                child: Text(
                  '$value $suffix',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                ),
              ),
            ),
            _StepperButton(icon: Icons.add, accent: color, onTap: () => provider.addCurrency(type, 1)),
          ],
        ),
      ],
    );
  }
}

class _WeaponCard extends StatelessWidget {
  final Weapon weapon;
  final Color accent;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _WeaponCard({
    required this.weapon,
    required this.accent,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        weapon.name,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                    ),
                    if (weapon.isUnique) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.auto_awesome, size: 15, color: accent),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${weapon.attackBonus}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4, right: 4),
                  child: Icon(Icons.delete_outline, color: context.appColors.textSecondary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fase 11: stepper táctico de cantidad. Vive justo debajo del
          // nombre, en su propia fila, para que sea igual de accesible en
          // armas de una mano que en munición apilada a futuro.
          // Fase 2: si el arma es única, no tiene sentido acumularla — se
          // oculta el stepper por completo en vez de mostrar +/- inertes.
          if (!weapon.isUnique)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANTIDAD',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'serif'),
                ),
                Row(
                  children: [
                    _StepperButton(icon: Icons.remove, accent: accent, onTap: onDecrement),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                      ),
                    ),
                    _StepperButton(icon: Icons.add, accent: accent, onTap: onIncrement),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ÚNICA',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'serif'),
                ),
                Text(
                  '×1',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            '${weapon.damage.baseDice} (${weapon.damage.baseType})',
            style: TextStyle(color: context.appColors.textPrimary, fontSize: 15, fontFamily: 'serif'),
          ),
          if (weapon.conditionalDamage.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...weapon.conditionalDamage.map(
              (c) => Text(
                '+ ${c.dice} ${c.type} — ${c.trigger}',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                ),
              ),
            ),
          ],
          if (weapon.properties.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: weapon.properties
                  .map((p) => Chip(
                        label: Text(p, style: const TextStyle(fontSize: 12, fontFamily: 'serif')),
                        backgroundColor: context.appColors.surfaceLight,
                        side: BorderSide(color: context.appColors.border),
                      ))
                  .toList(),
            ),
          ],
          if (weapon.homebrewEffect.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              weapon.homebrewEffect,
              style: TextStyle(color: accent, fontSize: 13, fontStyle: FontStyle.italic, fontFamily: 'serif'),
            ),
          ],
          if (weapon.magicCharges.hasCharges) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Cargas: ',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontFamily: 'serif'),
                ),
                ...List.generate(weapon.magicCharges.max, (i) {
                  final filled = i < weapon.magicCharges.current;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      filled ? Icons.circle : Icons.circle_outlined,
                      size: 14,
                      color: filled ? accent : context.appColors.border,
                    ),
                  );
                }),
                const Spacer(),
                TextButton(
                  onPressed: weapon.magicCharges.current > 0
                      ? () => context.read<CharacterProvider>().consumeWeaponCharge(weapon)
                      : null,
                  child: Text('Gastar carga', style: TextStyle(color: accent, fontFamily: 'serif')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón circular translúcido de [-]/[+] — mismo lenguaje visual que
/// _HpActionButton del header (fondo al 15-20% del acento, sin bordes
/// duros), pero un poco más compacto para caber junto al número.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.15),
          ),
          child: Icon(icon, color: accent, size: 16),
        ),
      ),
    );
  }
}