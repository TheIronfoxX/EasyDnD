// Sección "Recursos" del editor: los pools de puntos genéricos (Ki,
// Hechicería, Furia por día, Inspiración Bárdica...) que el personaje
// gasta y recupera fuera de las ranuras de conjuro.
//
// Se identifican por NOMBRE y no por id estable: el jugador los crea
// libremente y dos fichas pueden tener un recurso con el mismo nombre
// sin que sea un conflicto (ver ResourcePoint). Por eso el diálogo
// retorna el recurso listo y la página lo inserta/reemplaza — igual
// que competencias y ranuras.
//
// Los "usos restantes" son estado de combate, pero acá se editan a
// propósito (empezar la sesión ya gastado, importaciones mal cargadas).
// El tope arrastra el current si estaba lleno y lo recorta si queda por
// encima, nunca al revés.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

class EditorSectionResources extends StatefulWidget {
  const EditorSectionResources({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionResources> createState() => _EditorSectionResourcesState();
}

class _EditorSectionResourcesState extends State<EditorSectionResources> {
  Future<void> _edit({int? index}) async {
    final resources = widget.draft.resources;
    final result = await showDialog<ResourcePoint>(
      context: context,
      builder: (_) =>
          _ResourceDialog(initial: index == null ? null : resources[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        resources.add(result);
      } else {
        resources[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resources = widget.draft.resources;

    return EditorSectionScaffold(
      title: 'Recursos',
      help:
          'Pools de puntos que se gastan y se recuperan fuera de las '
          'ranuras de conjuro: Ki, Hechicería, Furia... El nombre es la '
          'identidad — podés tener dos recursos con el mismo nombre sin '
          'que choquen.',
      onAdd: () => _edit(),
      addLabel: 'Agregar recurso',
      children: [
        if (resources.isEmpty)
          const EditorEmptyHint('La ficha no trae recursos todavía.'),
        for (var i = 0; i < resources.length; i++)
          ListTile(
            leading: CircleAvatar(
              maxRadius: 16,
              child: Text('${resources[i].current}'),
            ),
            title: Text(resources[i].name),
            subtitle: Text(
              '${resources[i].current} de ${resources[i].max} '
              'usos',
            ),
            trailing: IconButton(
              tooltip: 'Borrar recurso',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () =>
                  setState(() => widget.draft.resources.removeAt(i)),
            ),
            onTap: () => _edit(index: i),
          ),
      ],
    );
  }
}

/// Diálogo de alta/edición de un recurso. Retorna el ResourcePoint
/// listo para insertar, o null al cancelar (nunca muta el borrador).
class _ResourceDialog extends StatefulWidget {
  const _ResourceDialog({this.initial});

  /// Null = alta nueva.
  final ResourcePoint? initial;

  @override
  State<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends State<_ResourceDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.initial?.name ?? '';
  late int _max = widget.initial?.max ?? 1;
  late int _current = widget.initial?.current ?? 1;

  /// El tope puede recortar/arrastrar el current: el campo visible va
  /// con controller porque initialValue no se refresca solo.
  late final TextEditingController _currentController;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController(text: _current.toString());
  }

  @override
  void dispose() {
    _currentController.dispose();
    super.dispose();
  }

  void _setMax(int value) {
    setState(() {
      // Si estaba lleno, sigue lleno; si estaba gastado, se respeta —
      // salvo que quede por encima del tope nuevo.
      final wasFull = _current >= _max;
      _max = value;
      if (wasFull || _current > value) {
        _current = value;
        _currentController.text = '$value';
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop(ResourcePoint(name: _name.trim(), current: _current, max: _max));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo recurso' : 'Editar recurso'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _name = value,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Poné un nombre.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Tope de usos',
              value: _max,
              onChanged: (value) {
                if (value != null) _setMax(value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Usos restantes',
              value: _current,
              controller: _currentController,
              hint: 'estado de combate',
              validator: (text) {
                final parsed = int.tryParse(text ?? '');
                if (parsed != null && parsed > _max) {
                  return 'No puede superar el tope ($_max).';
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
