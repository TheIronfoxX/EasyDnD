// Sección "Habilidades" del editor: el CRUD grande de la economía de
// acciones (acción / acción adicional / reacción / pasiva), que en la
// app vieja vivía dispersa en diálogos del HUD.
//
// El listado agrupa por categoría con headers; tocar una habilidad
// abre su página de detalle (ver editor_ability_page.dart) y la
// basura borra directo, sin confirmar — el borrador del editor cubre
// el arrepentimiento. El FAB crea en "Acción" (la categoría más común)
// y desde el detalle se puede mover a cualquier otra.

import 'package:flutter/material.dart';

import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import 'editor_ability_page.dart';
import 'editor_fields.dart';

class EditorSectionAbilities extends StatefulWidget {
  const EditorSectionAbilities({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionAbilities> createState() =>
      _EditorSectionAbilitiesState();
}

class _EditorSectionAbilitiesState extends State<EditorSectionAbilities> {
  void _add() {
    final ability = Ability(
      // Id estable y único: la identidad de la habilidad NUNCA se
      // recalcula del nombre (dos homebrew pueden llamarse igual) —
      // el HUD cuelga las cargas de este id.
      id: 'ability_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Habilidad sin nombre',
      type: 'trait',
      relatedStat: '',
      successDescription: '',
      failureDescription: '',
    );
    setState(() => widget.draft.abilitiesByAction.action.add(ability));
    _open(category: 'action', ability: ability, isNew: true);
  }

  Future<void> _open({
    required String category,
    required Ability ability,
    bool isNew = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorAbilityPage(
          abilities: widget.draft.abilitiesByAction,
          ability: ability,
          category: category,
          isNew: isNew,
        ),
      ),
    );
    // Al volver pudo haber cambiado de categoría: refrescar
    // contadores y headers.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final abilities = widget.draft.abilitiesByAction;

    return EditorSectionScaffold(
      title: 'Habilidades',
      help: 'Lo que la ficha puede hacer en su turno, por economía de '
          'acciones. Tocá una para editarla completa; el alta arranca '
          'en "Acción" y desde el detalle la movés de categoría.',
      onAdd: _add,
      addLabel: 'Agregar habilidad',
      children: [
        if (abilities.all.isEmpty)
          const EditorEmptyHint('La ficha no trae habilidades todavía.'),
        for (final entry in kAbilityCategoryLabels.entries)
          ..._categoryGroup(entry.key, entry.value),
      ],
    );
  }

  List<Widget> _categoryGroup(String key, String label) {
    final list = widget.draft.abilitiesByAction.listFor(key);
    if (list.isEmpty) return const [];

    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          '${label.toUpperCase()} · ${list.length}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
      ),
      for (var i = 0; i < list.length; i++)
        ListTile(
          dense: true,
          title: Text(list[i].name),
          subtitle: Text(_abilitySubtitle(list[i])),
          trailing: IconButton(
            tooltip: 'Borrar habilidad',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => setState(() => list.removeAt(i)),
          ),
          onTap: () => _open(category: key, ability: list[i]),
        ),
    ];
  }

  /// "Salvación · 8d6 · 2/3 usos" — un vistazo de qué hace sin abrir
  /// el detalle.
  static String _abilitySubtitle(Ability ability) {
    return [
      kAttackTypeShortLabels[ability.attackType] ?? ability.attackType,
      if ((ability.damageDice ?? '').isNotEmpty) ability.damageDice!,
      if (ability.magicCharges.hasCharges)
        '${ability.magicCharges.current}/${ability.magicCharges.max} usos',
    ].join(' · ');
  }
}
