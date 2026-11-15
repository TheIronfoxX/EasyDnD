// Primitivas de superficie del rework estético: [TacticalCard],
// [SectionHeader] y [TonePill].
//
// Son solo estructura visual — no saben de personajes ni de reglas — y
// todo (colores, forma, borde, sombra, ornamento) sale de los tokens de la
// skin activa (`context.tactical`), así los seis temas las visten sin
// tocar nada acá.

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/tactical_theme_tokens.dart';
import 'pip_shape.dart';

/// Tarjeta base: degradado de superficie elevada, forma, borde y sombra de
/// la skin y un filo de luz en el canto superior. Con [tone] suma una
/// franja lateral y tiñe el borde (arma / conjuro / habilidad...).
class TacticalCard extends StatelessWidget {
  const TacticalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.tone,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Color de rol. `null` = tarjeta neutra.
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tactical = context.tactical;
    final tone = this.tone;
    final borderColor = tone == null
        ? tactical.metalBorder
        : Color.alphaBlend(tone.withValues(alpha: 0.45), tactical.metalBorder);

    return AnimatedContainer(
      duration: AppDurations.normal,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: tactical.cardBorder(borderColor),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tactical.surfaceRaised, scheme.surface],
        ),
        shadows: tactical.cardShadows(scheme.shadow),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: tactical.cardShape,
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              // Filo de luz: iluminación tonal del canto superior.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tactical.metalHighlight.withValues(alpha: 0),
                          (tone ?? tactical.metalHighlight).withValues(
                            alpha: 0.55,
                          ),
                          tactical.metalHighlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (tone != null)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: tactical.borderWidth + 2,
                  child: IgnorePointer(child: ColoredBox(color: tone)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado de sección: placa con icono, título en la tipografía de
/// cabeceras de la skin, acción opcional y un ornamento lineal cuyo glifo
/// de arranque es la forma de pip del tema.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.tone,
    this.dense = false,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  /// Color del icono y del ornamento. `null` = color principal del tema.
  final Color? tone;

  /// Variante compacta para subsecciones (título más chico).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tactical = context.tactical;
    final color = tone ?? theme.colorScheme.primary;
    final titleStyle = dense
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          // Con o sin acción a la derecha el encabezado mide lo mismo: las
          // tarjetas vecinas quedan alineadas.
          constraints: BoxConstraints(minHeight: dense ? 28 : 36),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: ShapeDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: tactical.insetBorder(
                      color.withValues(alpha: 0.34),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, size: dense ? 14 : 16, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 7,
          child: CustomPaint(
            painter: _OrnamentPainter(
              color: color,
              fade: tactical.metalBorder,
              glyph: tactical.pipShape,
              width: tactical.borderWidth,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  const _OrnamentPainter({
    required this.color,
    required this.fade,
    required this.glyph,
    required this.width,
  });

  final Color color;
  final Color fade;

  /// Forma de la skin: el glifo de arranque es el mismo de sus pips.
  final PipShape glyph;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final glyphSize = size.height;
    canvas.drawPath(
      pipPath(glyph, glyphSize),
      Paint()..color = color.withValues(alpha: 0.85),
    );

    // Trazo que se desvanece hacia la derecha.
    final start = Offset(glyphSize + 4, size.height / 2);
    final end = Offset(size.width, size.height / 2);
    if (end.dx <= start.dx) return;
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = width.clamp(1, 2)
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.55),
            fade.withValues(alpha: 0.5),
            fade.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromPoints(start, end)),
    );
  }

  @override
  bool shouldRepaint(_OrnamentPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fade != fade ||
      oldDelegate.glyph != glyph ||
      oldDelegate.width != width;
}

/// Etiqueta tintada con un color de rol ("Truco", "Nv. 3"): toma la forma
/// de botón de la skin (píldora, bisel, cristal...). No es un botón.
class TonePill extends StatelessWidget {
  const TonePill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: tone.withValues(alpha: 0.14),
        shape: context.tactical.buttonBorder(
          tone.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
