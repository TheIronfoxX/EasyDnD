// Página de detalle de un arma del editor (Etapa 4d).
//
// Igual que la página de habilidad (4c): muta el arma EN EL LUGAR, sin
// botón "guardar arma" — el commit a la ficha real sigue siendo el
// "Guardar" del editor entero. Con tantos campos, un "cancelar
// descarta" anidado habría sido una segunda confirmación dentro de un
// flujo que ya tiene la suya en el shell.
//
// El daño condicional va inline (no diálogo): es una lista corta de
// campos sueltos y así el usuario ve todos los triggers de un vistazo.
// Cada tarjeta se keyea por IDENTIDAD del objeto para que borrar una
// del medio no le herede el texto a la siguiente.
//
// El id del arma NO se edita: es la identidad estable que usa el HUD
// (y la que namespacea las cargas). El nombre puede repetirse entre dos
// homebrew sin problema.

import 'package:flutter/material.dart';

import '../../domain/models/weapon.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

class EditorWeaponPage extends StatefulWidget {
  const EditorWeaponPage({
    super.key,
    required this.weapon,
    required this.isNew,
  });

  /// El arma editada, mutada en el lugar.
  final Weapon weapon;

  /// Solo para el título de la AppBar.
  final bool isNew;

  @override
  State<EditorWeaponPage> createState() => _EditorWeaponPageState();
}

class _EditorWeaponPageState extends State<EditorWeaponPage> {
  /// Al marcar "única" la cantidad se fuerza a 1: el campo visible va
  /// con controller para poder pisarlo sin que quede texto viejo.
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: widget.weapon.quantity.toString());
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _addProperty() async {
    final property = await showDialog<String>(
      context: context,
      builder: (_) => const _PropertyDialog(),
    );
    if (property == null) return;
    setState(() => widget.weapon.properties.add(property));
  }

  void _addConditional() {
    setState(() {
      widget.weapon.conditionalDamage.add(
        ConditionalDamage(trigger: '', dice: '1d6', type: 'fuego'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weapon = widget.weapon;

    return EditorSectionScaffold(
      title: widget.isNew ? 'Nueva arma' : 'Editar arma',
      help:
          'Todo lo que tocás entra al borrador al momento; el commit '
          'a la ficha real sigue siendo el "Guardar" del editor.',
      children: [
        EditorTextField(
          label: 'Nombre',
          initialValue: weapon.name,
          onChanged: (value) => weapon.name = value,
        ),
        EditorIntField(
          label: 'Bono de ataque',
          value: weapon.attackBonus,
          allowNegative: true,
          hint: 'El total que se suma a la tirada de d20',
          onChanged: (value) =>
              weapon.attackBonus = value ?? weapon.attackBonus,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditorDiceField(
                label: 'Dados de daño base',
                initialValue: weapon.damage.baseDice,
                hint: 'Ej.: 1d8+3',
                onChanged: (value) => weapon.damage.baseDice = value,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EditorTextField(
                label: 'Tipo de daño base',
                initialValue: weapon.damage.baseType,
                hint: 'cortante, fuego...',
                onChanged: (value) => weapon.damage.baseType = value,
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Arma única'),
          subtitle: const Text(
            'Objeto mágico/legendario que no se acumula (siempre ×1)',
          ),
          value: weapon.isUnique,
          onChanged: (value) => setState(() {
            weapon.isUnique = value;
            if (value) {
              weapon.quantity = 1;
              _quantity.text = '1';
            }
          }),
        ),
        if (!weapon.isUnique)
          EditorIntField(
            label: 'Cantidad',
            value: weapon.quantity,
            controller: _quantity,
            hint: 'copias en el inventario de este personaje',
            onChanged: (value) {
              // Una pila de 0 armas no significa nada: se ignora.
              if (value != null && value > 0) weapon.quantity = value;
            },
          ),
        EditorMagicCharges(
          charges: weapon.magicCharges,
          subtitle:
              'Ej.: Varita de proyectiles — 3 cargas que se '
              'recuperan al descansar',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'DAÑO CONDICIONAL',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
        if (weapon.conditionalDamage.isEmpty)
          const EditorEmptyHint(
            'Sin daño condicional: el arma solo hace su daño base.',
          ),
        for (final conditional in weapon.conditionalDamage)
          Card(
            // Por IDENTIDAD: si se borra una tarjeta del medio, las
            // demás conservan su texto (con keys por índice se
            // pisarían entre sí).
            key: ObjectKey(conditional),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daño extra',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Borrar daño condicional',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(
                          () => weapon.conditionalDamage.remove(conditional),
                        ),
                      ),
                    ],
                  ),
                  EditorTextField(
                    label: 'Disparador',
                    initialValue: conditional.trigger,
                    hint: 'Ej.: si el objetivo ya está quemado',
                    onChanged: (value) => conditional.trigger = value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: EditorDiceField(
                          label: 'Dados',
                          initialValue: conditional.dice,
                          onChanged: (value) => conditional.dice = value,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EditorTextField(
                          label: 'Tipo',
                          initialValue: conditional.type,
                          hint: 'fuego, psíquico...',
                          onChanged: (value) => conditional.type = value,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addConditional,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar daño condicional'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'PROPIEDADES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
        if (weapon.properties.isEmpty)
          const EditorEmptyHint(
            'Sin propiedades: agregá "versátil", "a dos manos", etc.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final property in weapon.properties)
                InputChip(
                  label: Text(property),
                  onDeleted: () =>
                      setState(() => weapon.properties.remove(property)),
                ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addProperty,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar propiedad'),
          ),
        ),
        EditorTextField(
          label: 'Efecto homebrew (opcional)',
          initialValue: weapon.homebrewEffect,
          hint: 'Lo que hace el arma además del daño, en tus palabras',
          maxLines: 3,
          onChanged: (value) => weapon.homebrewEffect = value,
        ),
        EditorTextField(
          label: 'Si acierta…',
          initialValue: weapon.successDescription,
          hint: 'Qué le contás al jugador cuando impacta',
          maxLines: 3,
          onChanged: (value) => weapon.successDescription = value,
        ),
        EditorTextField(
          label: 'Si falla…',
          initialValue: weapon.failureDescription,
          hint: 'Qué le contás al jugador cuando yerra',
          maxLines: 3,
          onChanged: (value) => weapon.failureDescription = value,
        ),
        EditorTextField(
          label: 'Sabor / lore (opcional)',
          initialValue: weapon.loreDescription ?? '',
          maxLines: 3,
          onChanged: (value) => weapon.loreDescription = value.trim().isEmpty
              ? null
              : value.trim(),
        ),
        EditorTextField(
          label: 'Resumen táctico (opcional)',
          initialValue: weapon.tacticalSummary ?? '',
          maxLines: 2,
          onChanged: (value) => weapon.tacticalSummary = value.trim().isEmpty
              ? null
              : value.trim(),
        ),
      ],
    );
  }
}

/// Diálogo de una sola línea para agregar una propiedad ("versátil",
/// "arrojadiza"...). Retorna el texto ya recortado, o null al cancelar.
class _PropertyDialog extends StatefulWidget {
  const _PropertyDialog();

  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  final _formKey = GlobalKey<FormState>();
  String _value = '';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva propiedad'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          initialValue: '',
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Propiedad',
            hintText: 'Ej.: versátil (1d10), arrojadiza',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _value = value,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Escribí una propiedad.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}
