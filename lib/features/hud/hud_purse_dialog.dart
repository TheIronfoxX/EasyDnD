// Diálogo para agregar o gastar dinero desde el HUD.
//
// Se elige la denominación (platino, oro, electro, plata o cobre) y la
// cantidad. Al gastar, el tope es lo que hay en esa denominación: no se
// convierte entre monedas (misma política que el store).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/models/character.dart';

/// Resultado del diálogo: qué denominación y cuánto.
typedef CurrencyChoice = ({CurrencyType type, int amount});

/// Etiqueta y sigla de cada denominación, en orden de valor.
const Map<CurrencyType, (String, String)> kCurrencyLabels = {
  CurrencyType.platinum: ('Platino', 'pp'),
  CurrencyType.gold: ('Oro', 'po'),
  CurrencyType.electrum: ('Electro', 'pe'),
  CurrencyType.silver: ('Plata', 'pp'),
  CurrencyType.copper: ('Cobre', 'pc'),
};

int currencyAmount(Purse purse, CurrencyType type) => switch (type) {
  CurrencyType.platinum => purse.platinum,
  CurrencyType.gold => purse.gold,
  CurrencyType.electrum => purse.electrum,
  CurrencyType.silver => purse.silver,
  CurrencyType.copper => purse.copper,
};

Future<CurrencyChoice?> showPurseDialog(
  BuildContext context, {
  required bool spend,
  required Purse purse,
}) {
  return showDialog<CurrencyChoice>(
    context: context,
    builder: (_) => _PurseDialog(spend: spend, purse: purse),
  );
}

class _PurseDialog extends StatefulWidget {
  const _PurseDialog({required this.spend, required this.purse});

  final bool spend;
  final Purse purse;

  @override
  State<_PurseDialog> createState() => _PurseDialogState();
}

class _PurseDialogState extends State<_PurseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '1');
  CurrencyType _type = CurrencyType.gold;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _available => currencyAmount(widget.purse, _type);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.tryParse(_controller.text.trim());
    if (amount == null) return;
    Navigator.of(context).pop((type: _type, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spend = widget.spend;

    return AlertDialog(
      title: Text(spend ? 'Gastar dinero' : 'Agregar dinero'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in kCurrencyLabels.entries)
                    ChoiceChip(
                      key: Key('currency-${entry.key.name}'),
                      label: Text('${entry.value.$1} (${entry.value.$2})'),
                      selected: _type == entry.key,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('currency-amount'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  border: const OutlineInputBorder(),
                  helperText: spend ? 'Tenés $_available' : null,
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null) return 'Escribí un número entero.';
                  if (parsed < 1) return 'Tiene que ser al menos 1.';
                  if (spend && parsed > _available) {
                    return 'No te alcanza: tenés $_available.';
                  }
                  return null;
                },
              ),
              if (spend)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'No se convierte entre monedas: se descuenta solo de '
                    'la denominación elegida.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(spend ? 'Gastar' : 'Agregar'),
        ),
      ],
    );
  }
}
