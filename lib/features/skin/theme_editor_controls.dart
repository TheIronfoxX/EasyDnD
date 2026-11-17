// Controles reutilizables del editor de temas: fila de color, deslizador,
// selector de enum, interruptor y editor de forma. No saben de temas;
// solo pintan un valor y avisan cuando cambia.

import 'package:flutter/material.dart';

import '../../core/theme/custom_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'hsv_color_picker_dialog.dart';

/// Color editable: muestra la muestra y el hex; tocar abre el picker HSV.
class ThemeColorRow extends StatelessWidget {
  const ThemeColorRow({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final Color color;
  final ValueChanged<Color> onChanged;

  String get _hex =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: hint == null ? null : Text(hint!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hex,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
      onTap: () async {
        final picked = await showDialog<Color>(
          context: context,
          builder: (_) => HsvColorPickerDialog(initialColor: color),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Deslizador con etiqueta y valor.
class ThemeSliderRow extends StatelessWidget {
  const ThemeSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = format?.call(value) ?? value.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                shown,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: shown,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Selector de un valor de una lista (enum u opciones con nombre).
class ThemeChoiceRow<T> extends StatelessWidget {
  const ThemeChoiceRow({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: DropdownButtonFormField<T>(
        // La clave fuerza a releer el valor si cambia desde fuera.
        key: ValueKey(selected),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final v in values)
            DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Interruptor con título y explicación.
class ThemeSwitchRow extends StatelessWidget {
  const ThemeSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: hint == null ? null : Text(hint!),
      value: value,
      onChanged: onChanged,
    );
  }
}

const _shapeKindLabels = {
  ShapeKind.rounded: 'Redondeada',
  ShapeKind.beveled: 'Biselada',
  ShapeKind.continuous: 'Continua (squircle)',
  ShapeKind.stadium: 'Píldora',
};

/// Forma de un elemento: tipo, radio común y, si se pide, un radio por
/// esquina.
class ThemeShapeEditor extends StatefulWidget {
  const ThemeShapeEditor({
    super.key,
    required this.label,
    required this.spec,
    required this.onChanged,
  });

  final String label;
  final ShapeSpec spec;
  final ValueChanged<ShapeSpec> onChanged;

  @override
  State<ThemeShapeEditor> createState() => _ThemeShapeEditorState();
}

class _ThemeShapeEditorState extends State<ThemeShapeEditor> {
  late bool _perCorner = !widget.spec.isUniform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = widget.spec;
    String px(double v) => '${v.round()} px';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          ThemeChoiceRow<ShapeKind>(
            label: 'Tipo',
            values: ShapeKind.values,
            selected: spec.kind,
            labelOf: (k) => _shapeKindLabels[k]!,
            onChanged: (k) => widget.onChanged(spec.copyWith(kind: k)),
          ),
          if (spec.kind != ShapeKind.stadium) ...[
            if (!_perCorner)
              ThemeSliderRow(
                label: 'Radio de esquinas',
                value: spec.topLeft,
                min: 0,
                max: 40,
                divisions: 40,
                format: px,
                onChanged: (v) => widget.onChanged(spec.withRadius(v)),
              )
            else ...[
              for (final (name, value, apply) in [
                (
                  'Arriba izquierda',
                  spec.topLeft,
                  (double v) => spec.copyWith(topLeft: v),
                ),
                (
                  'Arriba derecha',
                  spec.topRight,
                  (double v) => spec.copyWith(topRight: v),
                ),
                (
                  'Abajo derecha',
                  spec.bottomRight,
                  (double v) => spec.copyWith(bottomRight: v),
                ),
                (
                  'Abajo izquierda',
                  spec.bottomLeft,
                  (double v) => spec.copyWith(bottomLeft: v),
                ),
              ])
                ThemeSliderRow(
                  label: name,
                  value: value,
                  min: 0,
                  max: 40,
                  divisions: 40,
                  format: px,
                  onChanged: (v) => widget.onChanged(apply(v)),
                ),
            ],
            ThemeSwitchRow(
              label: 'Esquinas independientes',
              value: _perCorner,
              onChanged: (v) {
                setState(() => _perCorner = v);
                if (!v) widget.onChanged(spec.withRadius(spec.topLeft));
              },
            ),
          ],
        ],
      ),
    );
  }
}
