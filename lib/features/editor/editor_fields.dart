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

/// Labels en español de los seis atributos, indexados por la clave del
/// shape. Lo comparten las secciones que muestran o preguntan por un
/// stat relacionado (atributos, competencias, habilidades).
const Map<String, String> kStatLabels = {
  'str': 'Fuerza',
  'dex': 'Destreza',
  'con': 'Constitución',
  'int': 'Inteligencia',
  'wis': 'Sabiduría',
  'cha': 'Carisma',
};

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
          ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
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
    if (DiceFormula.tryParse(text) == null) {
      return 'Notación de dado inválida. Ejemplos: "2d6+3", "1d8", "+5".';
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
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
            padding: const EdgeInsets.only(left: 12),
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, onAdd == null ? 32 : 96),
          children: [
            if (help != null) ...[
              Text(
                help!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final child in children) ...[
              child,
              const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
