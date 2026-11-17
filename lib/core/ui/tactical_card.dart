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
import '../theme/theme_style_tokens.dart';
import 'pip_shape.dart';

/// Tarjeta base: degradado de superficie elevada, forma, borde y sombra de
/// la skin y un filo de luz en el canto superior. Con [tone] suma una
/// franja lateral y tiñe el borde (arma / conjuro / habilidad...).
class TacticalCard extends StatelessWidget {
  const TacticalCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.tone,
    this.onTap,
  });

  final Widget child;

  /// `null` = relleno estándar escalado por la densidad del tema.
  final EdgeInsetsGeometry? padding;
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
      duration: tactical.motion.scale(AppDurations.normal),
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        // Tema limpio (sin sombras): superficie lisa, sin borde.
        shape: tactical.shadowStyle == ShadowStyle.none
            ? tactical.cardShape
            : tactical.cardBorder(borderColor),
        gradient: switch (tactical.cards.gradient) {
          CardGradientStyle.flat => null,
          CardGradientStyle.raisedToSurface => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tactical.surfaceRaised, scheme.surface],
          ),
          CardGradientStyle.surfaceToRaised => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, tactical.surfaceRaised],
          ),
        },
        color: tactical.cards.gradient == CardGradientStyle.flat
            ? scheme.surface
            : null,
        shadows: tactical.cardShadows(scheme.shadow),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: tactical.cardShape,
          child: Stack(
            children: [
              Padding(
                padding:
                    padding ??
                    EdgeInsets.all(AppSpacing.lg * tactical.density.scale),
                child: child,
              ),
              if (tactical.cards.doubleBorder)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: tactical.cardShape.copyWith(
                            side: BorderSide(
                              color: borderColor.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                            alpha: tactical.cards.highlightAlpha,
                          ),
                          tactical.metalHighlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (tone != null && tactical.cards.toneStripe)
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

    final row = ConstrainedBox(
      // Con o sin acción a la derecha el encabezado mide lo mismo: las
      // tarjetas vecinas quedan alineadas.
      constraints: BoxConstraints(
        minHeight: (dense ? 28 : 36) * tactical.density.scale,
      ),
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
    );

    switch (tactical.components.header) {
      case HeaderStyle.ornament:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
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
      case HeaderStyle.plate:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: ShapeDecoration(
            gradient: tactical.headerGradient,
            shape: tactical.insetBorder(
              color.withValues(alpha: 0.5),
              width: tactical.borderWidth,
            ),
          ),
          child: row,
        );
      case HeaderStyle.underline:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            const SizedBox(height: AppSpacing.xs),
            Container(height: tactical.borderWidth + 1.5, color: color),
          ],
        );
      case HeaderStyle.brackets:
        return CustomPaint(
          foregroundPainter: _BracketPainter(
            color: color,
            width: tactical.borderWidth + 0.5,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: row,
          ),
        );
      case HeaderStyle.minimal:
        return row;
    }
  }
}

/// Esquinas en L para la cabecera de estilo "brackets".
class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    const arm = 8.0;
    for (final (origin, dx, dy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ]) {
      canvas.drawLine(origin, origin + Offset(dx * arm, 0), paint);
      canvas.drawLine(origin, origin + Offset(0, dy * arm), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color || old.width != width;
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
