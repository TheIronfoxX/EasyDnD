// Página de detalle de una habilidad del editor (Etapa 4c).
//
// A diferencia de los diálogos de ítem de competencias/ranuras (que
// arman un resultado y lo commitean al confirmar), esta página muta
// la habilidad EN EL LUGAR, igual que las secciones de campos
// sueltos: no hay botón "guardar habilidad" — el commit a la ficha
// real sigue siendo el "Guardar" del editor entero. Con tantos campos,
// un "cancelar descarta" anidado habría sido una segunda confirmación
// dentro de un flujo que ya tiene la suya en el shell.
//
// La economía de acciones (acción/adicional/reacción/pasiva) se
// cambia acá con un dropdown y se refleja en el listado al volver.

import 'package:flutter/material.dart';

import '../../domain/models/ability.dart';
import 'editor_fields.dart';

/// Categorías de la economía de acciones, por la clave del shape.
/// La comparte el listado de la sección para sus headers.
const Map<String, String> kAbilityCategoryLabels = {
  'action': 'Acción',
  'bonusAction': 'Acción adicional',
  'reaction': 'Reacción',
  'passive': 'Pasiva',
};

/// Labels de attack_type para el dropdown (largos y
/// autoexplicativos: qué significan se entiende a la primera).
const Map<String, String> kAttackTypeLabels = {
  'attack': 'Ataque — tirás vos para impactar',
  'save': 'Salvación — el objetivo tira contra tu CD',
  'none': 'Sin tirada enfrentada',
};

/// Versión corta para los subtítulos del listado.
const Map<String, String> kAttackTypeShortLabels = {
  'attack': 'Ataque',
  'save': 'Salvación',
  'none': 'Sin tirada',
};

/// Etiquetas de rol táctico de las pasivas (agrupa el HUD debajo de
/// ellas). Texto libre en el shape: un valor raro se muestra crudo.
const List<String> kTacticalRoles = ['Ofensivo', 'Defensivo', 'Utilidad'];

class EditorAbilityPage extends StatefulWidget {
  const EditorAbilityPage({
    super.key,
    required this.abilities,
    required this.ability,
    required this.category,
    required this.isNew,
  });

  /// Las cuatro listas del borrador: cambiar de categoría acá
  /// re-ubica la habilidad al toque.
  final AbilitiesByAction abilities;

  /// La habilidad editada, mutada en el lugar.
  final Ability ability;

  /// Categoría desde la que se abrió (el estado local arranca acá y
  /// sigue al dropdown).
  final String category;

  /// Solo para el título de la AppBar.
  final bool isNew;

  @override
  State<EditorAbilityPage> createState() => _EditorAbilityPageState();
}

class _EditorAbilityPageState extends State<EditorAbilityPage> {
  late String _category = widget.category;

  void _changeCategory(String? newCategory) {
    if (newCategory == null || newCategory == _category) return;
    setState(() {
      // La saca de donde esté y la agrega a la lista nueva. Por
      // IDENTIDAD y no por id: todavía no se guardó y dos habilidades
      // homebrew pueden llamarse igual — pero no ser la misma.
      for (final list in [
        widget.abilities.action,
        widget.abilities.bonusAction,
        widget.abilities.reaction,
        widget.abilities.passive,
      ]) {
        list.removeWhere((a) => identical(a, widget.ability));
      }
      widget.abilities.listFor(newCategory).add(widget.ability);
      _category = newCategory;
      // El rol táctico solo aplica a pasivas; si deja de serlo, el
      // modelo lo ignora y se conserva el valor por si vuelve.
    });
  }

  /// Opciones de un dropdown con la caja de escape: si el valor
  /// actual de la ficha no coincide con ninguna opción conocida (stat
  /// o attack_type custom de una ficha vieja), se agrega crudo para
  /// no romper el dropdown ni pisar el dato en silencio.
  List<DropdownMenuItem<String>> _itemsWith(
    Map<String, String> options,
    String current,
  ) {
    return [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      if (current.isNotEmpty && !options.containsKey(current))
        DropdownMenuItem(value: current, child: Text(current)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ability = widget.ability;
    final charges = ability.magicCharges;

    return EditorSectionScaffold(
      title: widget.isNew ? 'Nueva habilidad' : 'Editar habilidad',
      help: 'Todo lo que tocás entra al borrador al momento; el commit '
          'a la ficha real sigue siendo el "Guardar" del editor.',
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('ability-category'),
          initialValue: _category,
          items: [
            for (final entry in kAbilityCategoryLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          decoration: const InputDecoration(
            labelText: 'Economía de acciones',
            border: OutlineInputBorder(),
          ),
          onChanged: _changeCategory,
        ),
        EditorTextField(
          label: 'Nombre',
          initialValue: ability.name,
          onChanged: (value) => ability.name = value,
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('ability-related-stat'),
          initialValue: ability.relatedStat,
          items: _itemsWith(
            {'': '(ninguno)', ...kStatLabels},
            ability.relatedStat,
          ),
          decoration: const InputDecoration(
            labelText: 'Atributo para el modificador',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => ability.relatedStat = value ?? '',
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('ability-attack-type'),
          initialValue: ability.attackType,
          items: _itemsWith(kAttackTypeLabels, ability.attackType),
          decoration: const InputDecoration(
            labelText: 'Tipo de tirada',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              ability.attackType = value ?? ability.attackType,
        ),
        EditorDiceField(
          label: 'Dados de daño',
          initialValue: ability.damageDice ?? '',
          hint: 'Ej.: 8d6 o 1d8+3 (vacío = no hace daño)',
          onChanged: (value) => ability.damageDice =
              value.trim().isEmpty ? null : value.trim(),
        ),
        if (_category == 'passive')
          DropdownButtonFormField<String>(
            key: const ValueKey('ability-tactical-role'),
            initialValue: ability.tacticalRole,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('(sin clasificar)'),
              ),
              for (final role in kTacticalRoles)
                DropdownMenuItem(value: role, child: Text(role)),
              if (ability.tacticalRole != null &&
                  !kTacticalRoles.contains(ability.tacticalRole))
                DropdownMenuItem(
                  value: ability.tacticalRole,
                  child: Text(ability.tacticalRole!),
                ),
            ],
            decoration: const InputDecoration(
              labelText: 'Rol táctico (pasivas)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => ability.tacticalRole = value,
          ),
        EditorTextField(
          label: 'Si funciona…',
          hint: 'Qué le contás al jugador cuando sale bien',
          initialValue: ability.successDescription,
          maxLines: 3,
          onChanged: (value) => ability.successDescription = value,
        ),
        EditorTextField(
          label: 'Si falla…',
          hint: 'Qué le contás al jugador cuando sale mal',
          initialValue: ability.failureDescription,
          maxLines: 3,
          onChanged: (value) => ability.failureDescription = value,
        ),
        EditorTextField(
          label: 'Sabor / lore (opcional)',
          initialValue: ability.loreDescription ?? '',
          maxLines: 3,
          onChanged: (value) => ability.loreDescription =
              value.trim().isEmpty ? null : value.trim(),
        ),
        EditorTextField(
          label: 'Resumen mecánico (opcional)',
          initialValue: ability.tacticalSummary ?? '',
          maxLines: 2,
          onChanged: (value) => ability.tacticalSummary =
              value.trim().isEmpty ? null : value.trim(),
        ),
        EditorMagicCharges(charges: charges),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Escala con el nivel'),
          subtitle: const Text(
            'Ej.: Bola de Fuego — nivel base 4, +1d6 por nivel extra',
          ),
          value: ability.isScalable,
          onChanged: (value) => setState(() => ability.isScalable = value),
        ),
        if (ability.isScalable)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EditorIntField(
                    label: 'Nivel base',
                    value: ability.baseLevel,
                    onChanged: (value) {
                      if (value != null) ability.baseLevel = value;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EditorDiceField(
                    label: 'Dado extra por nivel',
                    initialValue: ability.scalingFormula ?? '',
                    onChanged: (value) => ability.scalingFormula =
                        value.trim().isEmpty ? null : value.trim(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
