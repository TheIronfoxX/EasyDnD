// Diálogos del tablero de combate (Etapa 5): cantidades de daño y
// curación, dados de golpe, descansos, condiciones y borrado de fichas.
//
// Todos devuelven el resultado y NO mutan el store: la pantalla decide
// cuándo aplicar. Es la misma separación que usa el editor entre
// diálogo y borrador, acá entre diálogo y ficha real.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dnd_rules.dart';

/// Lo que el jugador marcó en el descanso personalizado.
class CustomRestChoice {
  const CustomRestChoice({
    required this.healMax,
    required this.restoreSpells,
    required this.restoreCharges,
  });

  final bool healMax;
  final bool restoreSpells;
  final bool restoreCharges;

  bool get isEmpty => !healMax && !restoreSpells && !restoreCharges;
}

/// Diálogo numérico genérico (daño, curación, dados de golpe). Devuelve
/// un entero positivo, o null al cancelar.
Future<int?> showAmountDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? description,
  int initialAmount = 1,
  int? maxAmount,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      description: description,
      initialAmount: initialAmount,
      maxAmount: maxAmount,
    ),
  );
}

/// Confirmación de borrado de una ficha. Devuelve true solo si el
/// jugador confirma: eliminar del roster no se puede deshacer.
Future<bool> showDeleteCharacterDialog(
  BuildContext context, {
  required String name,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Eliminar ficha'),
        content: Text(
          '¿Seguro que querés eliminar "$name"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Confirmación del descanso largo. Devuelve true solo si el jugador
/// confirma.
Future<bool> showLongRestDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Descanso largo?'),
      content: const Text(
        'La ficha recupera:\n'
        '• Vida al máximo.\n'
        '• Todas las ranuras de conjuro.\n'
        '• Todas las cargas de armas y habilidades.\n'
        '• La mitad de los dados de golpe (redondeando para arriba).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Descansar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Descanso personalizado: el jugador elige qué recuperar. Devuelve
/// null al cancelar.
Future<CustomRestChoice?> showCustomRestDialog(BuildContext context) {
  return showDialog<CustomRestChoice>(
    context: context,
    builder: (_) => const _CustomRestDialog(),
  );
}

/// Selector de condiciones. Lista las del catálogo que todavía no están
/// activas y permite escribir una condición casera. Devuelve el nombre
/// elegido, o null al cancelar.
Future<String?> showConditionPicker(
  BuildContext context, {
  required List<String> activeConditions,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ConditionPickerDialog(activeConditions: activeConditions),
  );
}

// ---------------------------------------------------------------------
// Implementaciones privadas.
// ---------------------------------------------------------------------

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialAmount,
    this.description,
    this.maxAmount,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String? description;
  final int initialAmount;
  final int? maxAmount;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialAmount.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.tryParse(_controller.text.trim());
    if (amount == null) return;
    Navigator.of(context).pop(amount);
  }

  /// Atajos que tienen sentido para el tope actual (nunca ofrecer 10
  /// dados si solo quedan 2).
  List<int> get _quickAmounts {
    const candidates = [1, 5, 10];
    return [
      for (final amount in candidates)
        if (widget.maxAmount == null || amount <= widget.maxAmount!) amount,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.maxAmount;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.description != null) ...[
              Text(widget.description!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
                helperText: maxAmount == null ? null : 'Máximo: $maxAmount',
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null) return 'Escribí un número entero.';
                if (parsed < 1) return 'Tiene que ser al menos 1.';
                if (maxAmount != null && parsed > maxAmount) {
                  return 'No puede superar $maxAmount.';
                }
                return null;
              },
            ),
            if (_quickAmounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final amount in _quickAmounts)
                    ActionChip(
                      label: Text('$amount'),
                      onPressed: () {
                        _controller.text = '$amount';
                        _controller.selection = TextSelection.collapsed(
                          offset: _controller.text.length,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _CustomRestDialog extends StatefulWidget {
  const _CustomRestDialog();

  @override
  State<_CustomRestDialog> createState() => _CustomRestDialogState();
}

class _CustomRestDialogState extends State<_CustomRestDialog> {
  bool _healMax = false;
  bool _restoreSpells = false;
  bool _restoreCharges = false;

  bool get _anythingSelected => _healMax || _restoreSpells || _restoreCharges;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Descanso personalizado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vida al máximo'),
            value: _healMax,
            onChanged: (value) => setState(() => _healMax = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ranuras de conjuro'),
            value: _restoreSpells,
            onChanged: (value) =>
                setState(() => _restoreSpells = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cargas de armas y habilidades'),
            value: _restoreCharges,
            onChanged: (value) =>
                setState(() => _restoreCharges = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _anythingSelected
              ? () => Navigator.of(context).pop(
                  CustomRestChoice(
                    healMax: _healMax,
                    restoreSpells: _restoreSpells,
                    restoreCharges: _restoreCharges,
                  ),
                )
              : null,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _ConditionPickerDialog extends StatefulWidget {
  const _ConditionPickerDialog({required this.activeConditions});

  final List<String> activeConditions;

  @override
  State<_ConditionPickerDialog> createState() => _ConditionPickerDialogState();
}

class _ConditionPickerDialogState extends State<_ConditionPickerDialog> {
  final _customController = TextEditingController();
  String? _error;

  List<String> get _availableCatalog => [
    for (final name in DndRules.conditions.keys)
      if (!widget.activeConditions.contains(name)) name,
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustom() {
    final name = _customController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribí un nombre.');
      return;
    }
    if (widget.activeConditions.contains(name)) {
      setState(() => _error = 'Esa condición ya está activa.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Agregar condición'),
      content: SizedBox(
        width: 380,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _customController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Condición personalizada',
                hintText: 'Ej.: Bendecido por la luna',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Agregar condición personalizada',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _addCustom,
                ),
              ),
              onSubmitted: (_) => _addCustom(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _availableCatalog.isEmpty
                  ? const Center(
                      child: Text(
                        'Ya están todas las condiciones del '
                        'catálogo. Podés escribir una propia.',
                      ),
                    )
                  : ListView(
                      children: [
                        for (final name in _availableCatalog)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(name),
                            subtitle: Text(
                              DndRules.conditions[name]!.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () => Navigator.of(context).pop(name),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
