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

class EditorSectionItems extends StatefulWidget {
  const EditorSectionItems({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionItems> createState() => _EditorSectionItemsState();
}

class _EditorSectionItemsState extends State<EditorSectionItems> {
  Future<void> _edit({int? index}) async {
    final items = widget.draft.inventory.mundaneItems;
    final result = await showDialog<MundaneItem>(
      context: context,
      builder: (_) =>
          _MundaneItemDialog(initial: index == null ? null : items[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        items.add(result);
      } else {
        items[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purse = widget.draft.purse;
    final items = widget.draft.inventory.mundaneItems;

    return EditorSectionScaffold(
      title: 'Objetos y monedas',
      help:
          'La bolsa y los objetos comunes. Las tres monedas son stacks '
          'separados a propósito: no se convierten solas. El total en po '
          'es solo una referencia.',
      onAdd: () => _edit(),
      addLabel: 'Agregar objeto',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditorIntField(
                label: 'Oro (po)',
                value: purse.gold,
                onChanged: (value) => setState(() {
                  if (value != null) purse.gold = value;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EditorIntField(
                label: 'Plata (pp)',
                value: purse.silver,
                onChanged: (value) => setState(() {
                  if (value != null) purse.silver = value;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EditorIntField(
                label: 'Cobre (pc)',
                value: purse.copper,
                onChanged: (value) => setState(() {
                  if (value != null) purse.copper = value;
                }),
              ),
            ),
          ],
        ),
        Text(
          'Equivalente total: ${_formatGold(purse.totalInGold)} po',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'OBJETOS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
        if (items.isEmpty)
          const EditorEmptyHint('La ficha no trae objetos todavía.'),
        for (var i = 0; i < items.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backpack_outlined),
            title: Text(items[i].name),
            subtitle: Text(_itemSubtitle(items[i])),
            trailing: IconButton(
              tooltip: 'Borrar objeto',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(
                () => widget.draft.inventory.mundaneItems.removeAt(i),
              ),
            ),
            onTap: () => _edit(index: i),
          ),
      ],
    );
  }

  static String _itemSubtitle(MundaneItem item) {
    final quantity = '×${item.quantity}';
    if (item.description.isEmpty) return quantity;
    return '${item.description} · $quantity';
  }

  /// 15.0 → "15", 15.5 → "15.5", 15.25 → "15.25": sin ceros de relleno.
  static String _formatGold(double total) {
    if (total == total.roundToDouble()) return total.toInt().toString();
    return total.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

/// Diálogo de alta/edición de un objeto mundano. Retorna el objeto
/// listo para insertar o null al cancelar.
class _MundaneItemDialog extends StatefulWidget {
  const _MundaneItemDialog({this.initial});

  /// Null = alta nueva.
  final MundaneItem? initial;

  @override
  State<_MundaneItemDialog> createState() => _MundaneItemDialogState();
}

class _MundaneItemDialogState extends State<_MundaneItemDialog> {
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
