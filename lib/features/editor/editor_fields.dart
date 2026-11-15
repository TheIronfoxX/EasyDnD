// Campos reutilizables de los formularios del editor manual (Etapa 4).
//
// Patrón común a todos: TextFormField con initialValue (el estado vive
// en el FormField, sin controllers que administrar ni liberar) que
// escribe directo al BORRADOR vía onChanged. Los cambios no tocan el
// roster: la pantalla del editor decide cuándo commitear.
//
// Los campos numéricos son tolerantes mientras se tipea: mientras lo
// tecleado no sea un entero válido, el borrador conserva el último
// valor válido; el validador del guardado es la red de seguridad final.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dice.dart';
import '../../domain/models/weapon.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/design_tokens.dart';

// Reexportado para las secciones del editor que ya lo importaban desde
// acá; la fuente de verdad vive en core/dnd_rules.dart.
export '../../core/dnd_rules.dart' show kStatLabels;

/// Campo de texto simple (nombre, raza, descripciones...).
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.autocorrect = true,
    this.monospace = false,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final bool autocorrect;

  /// Texto largo en monospace (notaciones, JSON crudo...).
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      style: monospace
          ? theme.textTheme.bodyMedium?.copyWith(
              fontFamily: AppFonts.jetBrainsMono,
            )
          : null,
      onChanged: onChanged,
    );
  }
}

/// Campo de número entero. [onChanged] recibe null únicamente cuando
/// [allowEmpty] es true y el campo quedó vacío (para nullables como
/// spell_save_dc); mientras lo tecleado no parsea, el borrador retiene
/// el último valor válido.
class EditorIntField extends StatelessWidget {
  const EditorIntField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.allowEmpty = false,
    this.allowNegative = false,
    this.validator,
    this.controller,
  });

  final String label;

  /// Valor actual del borrador; solo alimenta el initialValue cuando
  /// no hay [controller].
  final int? value;

  /// Controller opcional para casos en los que el programa tiene que
  /// pisar el texto visible (ej. tope de cargas que arrastra los usos
  /// restantes). Con controller, [value] es solo documentación.
  final TextEditingController? controller;

  /// Si es null mientras se tipea basura, el borrador no se toca.
  final ValueChanged<int?> onChanged;

  /// True = el campo puede quedar vacío (y entonces onChanged recibe
  /// null). Para números nullables del shape.
  final bool allowEmpty;

  /// True = acepta un "-" (mods. negativos, bonos de ataque...).
  final bool allowNegative;

  /// Validación que corre al confirmar el Form contenedor (la usan
  /// los diálogos de ítem, ej. ranuras: disponibles no puede superar
  /// el máximo). Las páginas sueltas no la necesitan: el validador
  /// del guardado es su red de seguridad.
  final FormFieldValidator<String>? validator;

  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      // initialValue y controller son mutuamente excluyentes en el
      // TextFormField: con controller manda el controller.
      initialValue: controller == null ? value?.toString() ?? '' : null,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'^-?\d*$' : r'^\d*$'),
        ),
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) {
        if (text.isEmpty) {
          if (allowEmpty) onChanged(null);
          return;
        }
        final parsed = int.tryParse(text);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

/// Campo de notación de dado ("2d6+3", "+5", "1d8") con validación EN
/// VIVO: si lo tecleado no parsea con DiceFormula, el campo lo avisa
/// en rojo al toque — el mismo formato que el HUD necesitará para
/// tirarlo después (un dado mal escrito falla en silencio a mitad de
/// combate, preferimos que se vea acá). Vacío = sin error: muchos
/// efectos no tiran dado.
class EditorDiceField extends StatefulWidget {
  const EditorDiceField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<EditorDiceField> createState() => _EditorDiceFieldState();
}

class _EditorDiceFieldState extends State<EditorDiceField> {
  String? _error;

  void _handleChanged(String text) {
    setState(() {
      _error = _validate(text);
    });
    widget.onChanged(text);
  }

  String? _validate(String text) {
    if (text.trim().isEmpty) return null;
    if (DiceExpression.tryParse(text) == null) {
      return 'Notación de dado inválida. Ejemplos: "2d6+3", "1d8", "2d8+4d6", "+5".';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.initialValue,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        errorText: _error,
        errorMaxLines: 2,
      ),
      autocorrect: false,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.jetBrainsMono),
      onChanged: _handleChanged,
    );
  }
}

/// Bloque "usos limitados por descanso" que comparten habilidades y
/// armas mágicas (el shape de MagicCharges es el mismo a propósito).
/// Muta las cargas en el lugar y mantiene la coherencia de siempre:
/// prender el switch sin tope arranca 1/1; bajar el tope recorta los
/// usos restantes; subirlo no regala usos (si estaba gastado, sigue
/// gastado).
class EditorMagicCharges extends StatefulWidget {
  const EditorMagicCharges({
    super.key,
    required this.charges,
    this.subtitle = 'Ej.: Furia, 2 usos por descanso largo',
  });

  /// Las cargas del ítem editado, mutadas en el lugar.
  final MagicCharges charges;

  final String subtitle;

  @override
  State<EditorMagicCharges> createState() => _EditorMagicChargesState();
}

class _EditorMagicChargesState extends State<EditorMagicCharges> {
  /// El tope puede arrastrar/recortar el current: el campo visible va
  /// con controller porque initialValue no se refresca solo.
  late final TextEditingController _current;

  @override
  void initState() {
    super.initState();
    _current = TextEditingController(text: widget.charges.current.toString());
  }

  @override
  void dispose() {
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charges = widget.charges;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usos limitados por descanso'),
          subtitle: Text(widget.subtitle),
          value: charges.hasCharges,
          onChanged: (value) => setState(() {
            // Recién prendido sin tope configurado: arranca con un uso.
            if (value && charges.max == 0) {
              charges.max = 1;
              charges.current = 1;
              _current.text = '1';
            }
            charges.hasCharges = value;
          }),
        ),
        if (charges.hasCharges)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EditorIntField(
                    label: 'Tope de usos',
                    value: charges.max,
                    onChanged: (value) {
                      if (value == null) return;
                      // Misma semántica que setHpMax: si estaba lleno,
                      // sigue lleno; si estaba gastado, se respeta —
                      // salvo que quede por encima del tope nuevo.
                      final wasFull = charges.current >= charges.max;
                      charges.max = value;
                      if (wasFull || charges.current > value) {
                        charges.current = value;
                        _current.text = '$value';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EditorIntField(
                    label: 'Usos restantes',
                    value: charges.current,
                    controller: _current,
                    hint: 'estado de combate',
                    onChanged: (value) {
                      if (value != null) charges.current = value;
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Wrapper de página de sección: AppBar con el nombre de la sección y
/// cuerpo scrolleable con los campos apilados. Todas las secciones del
/// editor comparten esta piel para no repetir Scaffold trescientas
/// veces.
class EditorSectionScaffold extends StatelessWidget {
  const EditorSectionScaffold({
    super.key,
    required this.title,
    required this.children,
    this.help,
    this.onAdd,
    this.addLabel,
  });

  final String title;

  /// Texto de ayuda contextual que va arriba de todo, si la sección lo
  /// necesita (qué significa este bloque dentro de la ficha).
  final String? help;

  final List<Widget> children;

  /// Si no es null, la sección muestra un FAB extended para agregar
  /// ítems (competencias, ranuras, recursos, armas...).
  final VoidCallback? onAdd;

  /// Qué agrega el FAB (cada sección lo dice con sus palabras).
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel ?? 'Agregar'),
            ),
      body: SafeArea(
        child: ListView(
          // Con FAB el último ítem necesita lugar para no quedar tapado.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            onAdd == null ? AppSpacing.xxl : 96,
          ),
          children: [
            if (help != null) ...[
              Text(
                help!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final child in children) ...[
              child,
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vacío de las secciones de lista: una línea gris que explica
/// que todavía no hay nada, sin botones (el FAB ya es el llamado a
/// acción).
class EditorEmptyHint extends StatelessWidget {
  const EditorEmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// Campo numérico con botones − / +: el valor también se puede teclear
/// (misma tolerancia que [EditorIntField]). Los botones llevan las keys
/// `<id>-dec` / `<id>-inc` para los tests.
///
/// Con [allowEmpty] el valor puede ser null (campo vacío); el primer "+"
/// parte de [nullStart].
class EditorStepperField extends StatefulWidget {
  const EditorStepperField({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.allowEmpty = false,
    this.allowNegative = false,
    this.nullStart = 0,
  });

  final String id;
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int min;
  final int? max;
  final bool allowEmpty;
  final bool allowNegative;
  final int nullStart;

  @override
  State<EditorStepperField> createState() => _EditorStepperFieldState();
}

class _EditorStepperFieldState extends State<EditorStepperField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void didUpdateWidget(EditorStepperField old) {
    super.didUpdateWidget(old);
    // Solo se pisa el texto si el valor cambió desde afuera (por ej. el
    // tope arrastró los usos): mientras se teclea, el borrador conserva
    // el último valor válido y no se toca lo escrito.
    if (widget.value != old.value &&
        widget.value != int.tryParse(_controller.text)) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final base = widget.value ?? widget.nullStart;
    var next = base + delta;
    final lowest = widget.allowNegative ? (widget.min) : widget.min;
    if (next < lowest) next = lowest;
    final highest = widget.max;
    if (highest != null && next > highest) next = highest;
    _controller.text = '$next';
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Row(
      children: [
        IconButton(
          key: Key('${widget.id}-dec'),
          tooltip: 'Restar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: value != null && value <= widget.min
              ? null
              : () => _step(-1),
        ),
        Expanded(
          child: EditorIntField(
            label: widget.label,
            value: widget.value,
            controller: _controller,
            allowEmpty: widget.allowEmpty,
            allowNegative: widget.allowNegative,
            onChanged: widget.onChanged,
          ),
        ),
        IconButton(
          key: Key('${widget.id}-inc'),
          tooltip: 'Sumar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: widget.max != null && value != null && value >= widget.max!
              ? null
              : () => _step(1),
        ),
      ],
    );
  }
}

/// Encabezado de bloque dentro de una pestaña del taller.
class EditorBlockTitle extends StatelessWidget {
  const EditorBlockTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Ficha de solo lectura (Iniciativa, Percepción pasiva...).
class EditorReadout extends StatelessWidget {
  const EditorReadout({super.key, required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, key: Key('readout-$id'), style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
