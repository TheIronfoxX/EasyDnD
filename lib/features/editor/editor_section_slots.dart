// Sección "Ranuras de conjuro" del editor: por nivel de conjuro, el
// total de ranuras y cuántas quedan disponibles.
//
// El nivel de una ranura es su identidad (el HUD busca por nivel, ver
// SpellSlots.forLevel), así que:
//   - El alta solo ofrece niveles que la ficha NO tiene todavía
//     (1 a 9): no se puede duplicar un nivel, el dropdown directamente
//     no lo lista.
//   - Editar una ranura puede cambiarle el nivel, pero solo a otro
//     nivel libre (el propio sigue en la lista para no perder la
//     selección).
//   - Tras cada cambio la lista se reordena por nivel: se lee mejor y
//     el orden no significa nada para el HUD.
//
// "Disponibles ahora" es el análogo de las PG actuales: estado que en
// pleno combate baja el HUD — pero acá se edita a propósito (fichas
// importadas con las ranuras mal, o empezar la sesión ya gastado).

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

class EditorSectionSlots extends StatefulWidget {
  const EditorSectionSlots({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionSlots> createState() => _EditorSectionSlotsState();
}

class _EditorSectionSlotsState extends State<EditorSectionSlots> {
  /// Niveles 1-9 que la ficha todavía no tiene.
  List<int> _freeLevels() {
    final taken = widget.draft.spellSlots.slots.map((s) => s.level).toSet();
    return [
      for (var level = 1; level <= 9; level++)
        if (!taken.contains(level)) level,
    ];
  }

  void _add() {
    if (_freeLevels().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ficha ya tiene ranuras de los 9 niveles.'),
        ),
      );
      return;
    }
    _edit();
  }

  /// Abre el diálogo de alta/edición. Como el de competencias: cancelar
  /// no toca el borrador, el resultado se inserta recién al confirmar.
  Future<void> _edit({int? index}) async {
    final slots = widget.draft.spellSlots.slots;
    final editing = index != null;

    // Niveles elegibles: los libres, más el propio si es edición
    // (incluido un nivel fuera de 1-9 que trajera una ficha rara — el
    // dropdown no puede quedarse sin el valor actual).
    final options = {..._freeLevels(), if (editing) slots[index].level}.toList()
      ..sort();

    final result = await showDialog<SpellSlot>(
      context: context,
      builder: (_) => _SlotDialog(
        initial: editing
            ? slots[index]
            : SpellSlot(level: options.first, max: 1, current: 1),
        availableLevels: options,
        isNew: !editing,
      ),
    );
    if (result == null) return;
    setState(() {
      if (editing) {
        slots[index] = result;
      } else {
        slots.add(result);
      }
      slots.sort((a, b) => a.level.compareTo(b.level));
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.draft.spellSlots.slots;

    return EditorSectionScaffold(
      title: 'Ranuras de conjuro',
      help:
          'Por nivel de conjuro: cuántas ranuras en total y cuántas '
          'quedan. El alta solo ofrece niveles que la ficha todavía no '
          'tiene.',
      onAdd: _add,
      addLabel: 'Agregar nivel',
      children: [
        if (slots.isEmpty)
          const EditorEmptyHint(
            'Sin ranuras: la ficha no lanza conjuros (o todavía no las '
            'cargaron).',
          ),
        for (var i = 0; i < slots.length; i++)
          ListTile(
            leading: CircleAvatar(
              maxRadius: 16,
              child: Text('${slots[i].level}'),
            ),
            title: Text('Nivel ${slots[i].level}'),
            subtitle: Text(
              '${slots[i].current} de ${slots[i].max} '
              'disponibles',
            ),
            trailing: IconButton(
              tooltip: 'Borrar nivel',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () =>
                  setState(() => widget.draft.spellSlots.slots.removeAt(i)),
            ),
            onTap: () => _edit(index: i),
          ),
      ],
    );
  }
}

/// Diálogo de alta/edición de un nivel de ranura. Igual que el de
/// competencias: retorna la SpellSlot para insertar o null al cancelar.
class _SlotDialog extends StatefulWidget {
  const _SlotDialog({
    required this.initial,
    required this.availableLevels,
    required this.isNew,
  });

  final SpellSlot initial;

  /// Niveles elegibles (ver [_EditorSectionSlotsState._edit]).
  final List<int> availableLevels;

  /// True = alta nueva (solo cambia el título del diálogo).
  final bool isNew;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _level = widget.initial.level;
  late int _max = widget.initial.max;
  late int _current = widget.initial.current;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop(SpellSlot(level: _level, max: _max, current: _current));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Nuevo nivel de ranura' : 'Editar ranuras'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _level,
              items: [
                for (final level in widget.availableLevels)
                  DropdownMenuItem(value: level, child: Text('Nivel $level')),
              ],
              decoration: const InputDecoration(
                labelText: 'Nivel de conjuro',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value != null) setState(() => _level = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Ranuras totales',
              value: _max,
              onChanged: (value) {
                if (value != null) _max = value;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Disponibles ahora',
              value: _current,
              validator: (text) {
                final parsed = int.tryParse(text ?? '');
                if (parsed != null && parsed > _max) {
                  return 'No puede superar las totales ($_max).';
                }
                return null;
              },
              onChanged: (value) {
                if (value != null) _current = value;
              },
            ),
          ],
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
