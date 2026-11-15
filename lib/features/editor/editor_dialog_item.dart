// Sección "Objetos y monedas" del editor: la bolsa (po/pp/pc) y los
// objetos no mágicos del inventario (raciones, cuerda, antorchas...).
//
// Las monedas son tres contadores INDEPENDIENTES (Purse): no hay
// conversión automática entre denominaciones, para no imponer reglas de
// casa que el jugador no pidió. El total en po es solo referencia
// visual.
//
// Los objetos mundanos no tienen bonificadores ni cargas (a diferencia
// de las armas): nombre, descripción y cantidad. Tap abre el diálogo,
// basura borra directo y el FAB agrega.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

/// Diálogo de alta/edición de un objeto mundano. Retorna el objeto
/// listo para insertar o null al cancelar.
class MundaneItemDialog extends StatefulWidget {
  const MundaneItemDialog({super.key, this.initial});

  /// Null = alta nueva.
  final MundaneItem? initial;

  @override
  State<MundaneItemDialog> createState() => _MundaneItemDialogState();
}

class _MundaneItemDialogState extends State<MundaneItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.initial?.name ?? '';
  late String _description = widget.initial?.description ?? '';
  late int _quantity = widget.initial?.quantity ?? 1;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      MundaneItem(
        name: _name.trim(),
        description: _description.trim(),
        quantity: _quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo objeto' : 'Editar objeto'),
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
            TextFormField(
              initialValue: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Para qué sirve o cómo se ve',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => _description = value,
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Cantidad',
              value: _quantity,
              validator: (text) {
                final parsed = int.tryParse(text ?? '');
                if (parsed != null && parsed < 1) {
                  return 'Al menos 1: para borrarlo, usá la basura.';
                }
                return null;
              },
              onChanged: (value) {
                if (value != null) _quantity = value;
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
