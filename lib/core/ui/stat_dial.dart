// Instrumentos numéricos del rework estético: [StatDial] (lectura),
// [TacticalStepper] (−/+ compacto) y [ResourcePips] (cargas ● ● ○).
//
// Todos los números usan cifras tabulares (ver telemetry.dart) para que
// los cambios en combate no muevan el layout.

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/tactical_theme_tokens.dart';
import '../theme/theme_style_tokens.dart';
import 'pip_shape.dart';
import '../theme/telemetry.dart';

/// Instrumento de lectura: icono, valor grande y etiqueta. Se estira al
/// ancho que le dé el padre. Con [onTap] se comporta como botón.
class StatDial extends StatelessWidget {
  const StatDial({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone,
    this.onTap,
    this.emphasized = false,
    this.richValue = false,
  });

  final String label;
  final String value;

  /// Pinta el valor como texto enriquecido. Para lecturas derivadas que
  /// repiten un número ya visible en otra parte de la pantalla.
  final bool richValue;
  final IconData? icon;

  /// Color de rol del instrumento. `null` = neutro.
  final Color? tone;
  final VoidCallback? onTap;

  /// Valor más grande: para el dato estrella de una fila (la CA).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;
    final tone = this.tone;
    final valueStyle =
        (emphasized ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w800, color: tone)
            .tabular;

    return AnimatedContainer(
      duration: AppDurations.normal,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: tone == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.40)
            : Color.alphaBlend(
                tone.withValues(alpha: 0.10),
                scheme.surfaceContainerHighest.withValues(alpha: 0.40),
              ),
        shape: tactical.insetBorder(
          tone == null
              ? tactical.metalBorder.withValues(alpha: 0.75)
              : tone.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: tactical.insetShape,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: tone ?? scheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.xs),
                ],
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: richValue
                      ? Text.rich(
                          TextSpan(text: value),
                          key: ValueKey(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: valueStyle,
                        )
                      : Text(
                          value,
                          key: ValueKey(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: valueStyle,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paso −/+ compacto dentro de una cápsula con borde metálico. El centro
/// es libre ([child]): un número, pips, una etiqueta. Un callback null
/// deshabilita su botón.
class TacticalStepper extends StatelessWidget {
  const TacticalStepper({
    super.key,
    required this.onDecrement,
    required this.onIncrement,
    this.child,
    this.decrementTooltip,
    this.incrementTooltip,
    this.decrementKey,
    this.incrementKey,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
    this.tone,
  });

  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final Widget? child;
  final String? decrementTooltip;
  final String? incrementTooltip;
  final Key? decrementKey;
  final Key? incrementKey;
  final IconData decrementIcon;
  final IconData incrementIcon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tactical = context.tactical;

    Widget button(
      IconData icon,
      VoidCallback? onPressed,
      String? tooltip,
      Key? key,
    ) {
      return IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: tone ?? scheme.primary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
        shape: tactical.buttonBorder(
          tactical.metalBorder.withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(decrementIcon, onDecrement, decrementTooltip, decrementKey),
          if (child != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: child,
            ),
          button(incrementIcon, onIncrement, incrementTooltip, incrementKey),
        ],
      ),
    );
  }
}

/// Cargas como puntos: llenos los disponibles, huecos los gastados
/// (● ● ○). Con más de [maxPips] se degrada a una barra fina, que escala
/// sin romper la fila.
class ResourcePips extends StatelessWidget {
  const ResourcePips({
    super.key,
    required this.current,
    required this.max,
    this.color,
    this.size = 9,
    this.maxPips = 10,
  });

  final int current;
  final int max;
  final Color? color;
  final double size;
  final int maxPips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = current <= 0 ? scheme.error : (color ?? scheme.primary);
    if (max <= 0) return const SizedBox.shrink();

    if (max > maxPips) {
      return SizedBox(
        width: 56,
        child: TweenAnimationBuilder<double>(
          duration: AppDurations.normal,
          tween: Tween(end: (current / max).clamp(0.0, 1.0)),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 5,
            color: tone,
            borderRadius: BorderRadius.circular(
              context.tactical.shapes.pillRadius,
            ),
          ),
        ),
      );
    }

    final shape = context.tactical.pipShape;
    return ExcludeSemantics(
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (var i = 0; i < max; i++)
            PipGlyph(
              shape: shape,
              filled: i < current,
              color: tone,
              size: size,
              outline: scheme.outline,
            ),
        ],
      ),
    );
  }
}

/// Barra de medidor animada (PG, movimiento): el relleno se desliza al
/// nuevo valor y lleva un degradado sutil del color de rol. [value] va de
/// 0 a 1.
class VitalBar extends StatelessWidget {
  const VitalBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 12,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tactical = context.tactical;
    final style = tactical.components.bar;
    final barHeight = style == BarStyle.thin ? height.clamp(3.0, 6.0) : height;
    final radius = BorderRadius.circular(
      style == BarStyle.segmented
          ? 2.0
          : tactical.shapes.pillRadius.clamp(0.0, barHeight / 2),
    );

    final fill = TweenAnimationBuilder<double>(
      duration: tactical.motion.scale(const Duration(milliseconds: 420)),
      curve: tactical.motion.dialCurve,
      tween: Tween(end: value.clamp(0.0, 1.0)),
      builder: (context, fraction, child) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: child,
      ),
      child: AnimatedContainer(
        duration: AppDurations.normal,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: style == BarStyle.smooth ? null : color,
          gradient: style == BarStyle.smooth
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      tactical.metalHighlight.withValues(alpha: 0.28),
                      color,
                    ),
                    color,
                    Color.alphaBlend(
                      scheme.shadow.withValues(alpha: 0.22),
                      color,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );

    final glow = tactical.components.barGlow && style != BarStyle.thin;
    return Container(
      height: barHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.40),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
        color: style == BarStyle.thin
            ? color.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: radius,
        border: style == BarStyle.thin
            ? null
            : Border.all(
                color: glow
                    ? tactical.metalHighlight.withValues(alpha: 0.7)
                    : tactical.metalBorder.withValues(alpha: 0.6),
              ),
      ),
      child: style == BarStyle.segmented
          ? Stack(
              fit: StackFit.expand,
              children: [
                fill,
                // Las muescas cortan la barra en segmentos.
                CustomPaint(
                  painter: _SegmentPainter(
                    gap: scheme.surfaceContainerHighest,
                    step: barHeight * 1.8,
                  ),
                ),
              ],
            )
          : fill,
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({required this.gap, required this.step});

  final Color gap;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gap
      ..strokeWidth = 2;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter old) => old.gap != gap || old.step != step;
}

/// Escudo de Clase de Armadura: la silueta lleva el número adentro y la
/// etiqueta debajo. Es el dato defensivo estrella de la cabecera vital.
class ArmorShield extends StatelessWidget {
  const ArmorShield({
    super.key,
    required this.value,
    this.label = 'CA',
    this.size = 64,
  });

  final String value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 1.12,
          child: CustomPaint(
            painter: _ShieldPainter(
              fillTop: tactical.surfaceRaised,
              fillBottom: scheme.surface,
              border: scheme.primary,
              highlight: tactical.metalHighlight,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: size * 0.10),
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        )
                        .tabular,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter({
    required this.fillTop,
    required this.fillBottom,
    required this.border,
    required this.highlight,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..lineTo(w * 0.94, h * 0.16)
      ..lineTo(w * 0.94, h * 0.50)
      ..cubicTo(w * 0.94, h * 0.76, w * 0.72, h * 0.90, w * 0.5, h * 0.98)
      ..cubicTo(w * 0.28, h * 0.90, w * 0.06, h * 0.76, w * 0.06, h * 0.50)
      ..lineTo(w * 0.06, h * 0.16)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(border.withValues(alpha: 0.18), fillTop),
            fillBottom,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = border,
    );
    // Brillo del canto superior izquierdo.
    canvas.drawLine(
      Offset(w * 0.14, h * 0.20),
      Offset(w * 0.5, h * 0.085),
      Paint()
        ..strokeWidth = 1
        ..color = highlight.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) =>
      oldDelegate.fillTop != fillTop ||
      oldDelegate.fillBottom != fillBottom ||
      oldDelegate.border != border ||
      oldDelegate.highlight != highlight;
}
