// Selector de color libre HSV (Etapa 6b).
//
// Es el heredero del HsvColorPickerDialog de la app vieja, pero sin
// saber nada de providers ni del modo claro/oscuro: recibe un color y
// devuelve el elegido por `Navigator.pop`. Quien lo abre (la pantalla de
// apariencia) decide qué hacer con él.
//
// Los colores de la UI salen del tema; los gradientes de tono,
// saturación y brillo son colores puros por definición (el espectro),
// no decisiones de diseño.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class HsvColorPickerDialog extends StatefulWidget {
  const HsvColorPickerDialog({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<HsvColorPickerDialog> createState() => _HsvColorPickerDialogState();
}

class _HsvColorPickerDialogState extends State<HsvColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = _hsv.toColor();

    return AlertDialog(
      title: const Text('Color personalizado'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Tono'),
            _GradientSlider(
              value: _hsv.hue,
              min: 0,
              max: 360,
              gradientColors: const [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('Saturación'),
            _GradientSlider(
              value: _hsv.saturation,
              min: 0,
              max: 1,
              gradientColors: [
                Colors.white,
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('Brillo'),
            _GradientSlider(
              value: _hsv.value,
              min: 0,
              max: 1,
              gradientColors: [
                Colors.black,
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(currentColor),
          child: Text(
            'Usar este color',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Slider con un degradado pintado detrás y el track real transparente.
/// El Slider de Material queda encima del gradiente, invisible salvo por
/// el thumb, para que el jugador arrastre sobre el color real.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.gradientColors,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              gradient: LinearGradient(colors: gradientColors),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 14,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
