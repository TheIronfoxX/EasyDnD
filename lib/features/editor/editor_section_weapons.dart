// Sección "Armas" del editor: el inventario marcial del personaje.
//
// Tap abre la página de detalle (ver editor_weapon_page.dart, ~14
// campos); la basura borra directo sin confirmar — el borrador del
// editor cubre el arrepentimiento — y el FAB crea un arma con valores
// sensatos y la abre para completarla.
//
// La cantidad vive DENTRO del arma (rework v2): dos personajes con la
// misma arma no se pisan las copias entre sí.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import '../../domain/models/weapon.dart';
import 'editor_fields.dart';
import 'editor_weapon_page.dart';

class EditorSectionWeapons extends StatefulWidget {
  const EditorSectionWeapons({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionWeapons> createState() => _EditorSectionWeaponsState();
}

class _EditorSectionWeaponsState extends State<EditorSectionWeapons> {
  void _add() {
    final weapon = Weapon(
      // Id estable y único: la identidad del arma NUNCA se recalcula
      // del nombre (dos homebrew pueden llamarse igual) — el HUD y las
      // cargas cuelgan de este id.
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
    setState(() => widget.draft.inventory.weapons.add(weapon));
    _open(weapon: weapon, isNew: true);
  }

  Future<void> _open({required Weapon weapon, bool isNew = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorWeaponPage(weapon: weapon, isNew: isNew),
      ),
    );
    // Al volver pudo cambiar nombre, daño o cargas: refrescar la lista.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weapons = widget.draft.inventory.weapons;

    return EditorSectionScaffold(
      title: 'Armas',
      help:
          'Las armas del inventario con su bono de ataque y daño. Tocá '
          'una para editarla completa; el alta arranca con un arma simple '
          'y la completás en el detalle.',
      onAdd: _add,
      addLabel: 'Agregar arma',
      children: [
        if (weapons.isEmpty)
          const EditorEmptyHint('La ficha no trae armas todavía.'),
        for (var i = 0; i < weapons.length; i++)
          ListTile(
            leading: CircleAvatar(
              maxRadius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: const Icon(Icons.gavel_rounded, size: 18),
            ),
            title: Text(weapons[i].name),
            subtitle: Text(_subtitleFor(weapons[i])),
            trailing: IconButton(
              tooltip: 'Borrar arma',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () =>
                  setState(() => widget.draft.inventory.weapons.removeAt(i)),
            ),
            onTap: () => _open(weapon: weapons[i]),
          ),
      ],
    );
  }

  /// "Ataque +5 · 1d8+3 cortante · ×2 · 2/3 cargas" — un vistazo de lo
  /// que hace sin abrir el detalle.
  static String _subtitleFor(Weapon weapon) {
    final bonus = weapon.attackBonus >= 0
        ? '+${weapon.attackBonus}'
        : '${weapon.attackBonus}';
    final damage = '${weapon.damage.baseDice} ${weapon.damage.baseType}';
    return [
      'Ataque $bonus',
      damage,
      if (!weapon.isUnique && weapon.quantity != 1) '×${weapon.quantity}',
      if (weapon.magicCharges.hasCharges)
        '${weapon.magicCharges.current}/${weapon.magicCharges.max} cargas',
    ].join(' · ');
  }
}
