import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_notifier.dart'; // ajusta esta ruta si theme_notifier.dart vive en otra carpeta
import '../theme/app_theme_extension.dart';

/// Diálogo de selección de color libre. Nada de presets: el usuario mueve
/// Tono / Saturación / Brillo y consigue cualquier color del espectro RGB.
/// Todo aquí es dinámico (depende del color inicial y de lo que el usuario
/// mueva), así que nada de const en el árbol interno.
///
/// Fase 5: además del color, el diálogo ahora también lee y controla el
/// modo claro/oscuro a través de ThemeNotifier (context.watch/read). El
/// diálogo NO guarda su propio estado de tema — solo refleja y modifica
/// el de ThemeNotifier, que es quien de verdad manda en toda la app.
class HsvColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const HsvColorPickerDialog({super.key, required this.initialColor});

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
    final currentColor = _hsv.toColor();

    // isDarkMode no es un color, así que sigue viniendo de ThemeNotifier
    // (watch() para que el icono del interruptor se repinte al tocarlo).
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final surfaceColor = context.appColors.surface;
    final borderColor = context.appColors.border;
    final textPrimary = context.appColors.textPrimary;
    final textSecondary = context.appColors.textSecondary;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // AlertDialog no tiene AppBar propia, así que el interruptor de tema
      // va en la fila del título, a la derecha del texto.
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Color de acento',
            style: TextStyle(fontFamily: 'serif', color: textPrimary),
          ),
          IconButton(
            tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textSecondary,
            ),
            onPressed: () => context.read<ThemeNotifier>().toggleThemeMode(),
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
            ),
            const SizedBox(height: 18),
            _Label(text: 'Tono', color: textSecondary),
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
            const SizedBox(height: 10),
            _Label(text: 'Saturación', color: textSecondary),
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
            const SizedBox(height: 10),
            _Label(text: 'Brillo', color: textSecondary),
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
          child: Text('Cancelar', style: TextStyle(fontFamily: 'serif', color: textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(currentColor),
          child: Text('Usar este color', style: TextStyle(fontFamily: 'serif', color: currentColor)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'serif'),
        ),
      ),
    );
  }
}

/// Slider con un degradado pintado detrás y el track real transparente.
/// El truco: el Slider de Material se pone encima del gradiente, invisible
/// salvo por el thumb, para que el usuario arrastre sobre el color real.
/// (Sin cambios respecto a la versión original: los gradientes de H/S/B
/// son colores puros y funcionan igual en ambos modos.)
class _GradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.gradientColors,
    required this.onChanged,
  });

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
              borderRadius: BorderRadius.circular(7),
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
