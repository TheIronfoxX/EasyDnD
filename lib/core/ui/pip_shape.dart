// Forma de los indicadores de carga (pips) y glifos de ornamento.
//
// Cada skin elige su forma ([PipShape]): círculo, rombo, cuadrado, hoja o
// estrella de cuatro puntas o llama. [pipPath] devuelve el contorno en un
// cuadrado de lado [size]; [PipGlyph] lo pinta animando el relleno, y lo
// reutilizan los ornamentos de los encabezados.

import 'package:flutter/material.dart';

import '../theme/tactical_theme_tokens.dart';

/// Contorno de un pip de [shape] dentro del cuadrado `size × size`.
Path pipPath(PipShape shape, double size) {
  final c = size / 2;
  switch (shape) {
    case PipShape.circle:
      return Path()..addOval(Rect.fromLTWH(0, 0, size, size));
    case PipShape.diamond:
      return Path()
        ..moveTo(c, 0)
        ..lineTo(size, c)
        ..lineTo(c, size)
        ..lineTo(0, c)
        ..close();
    case PipShape.square:
      return Path()..addRect(Rect.fromLTWH(0.5, 0.5, size - 1, size - 1));
    case PipShape.leaf:
      // Hoja: dos arcos que se juntan en las puntas de una diagonal.
      return Path()
        ..moveTo(size * 0.08, size * 0.92)
        ..quadraticBezierTo(size * 0.02, size * 0.25, size * 0.92, size * 0.08)
        ..quadraticBezierTo(size * 0.98, size * 0.75, size * 0.08, size * 0.92)
        ..close();
    case PipShape.star:
      // Estrella de cuatro puntas (✦): lados cóncavos.
      final k = size * 0.16;
      return Path()
        ..moveTo(c, 0)
        ..quadraticBezierTo(c + k, c - k, size, c)
        ..quadraticBezierTo(c + k, c + k, c, size)
        ..quadraticBezierTo(c - k, c + k, 0, c)
        ..quadraticBezierTo(c - k, c - k, c, 0)
        ..close();
    case PipShape.bolt:
      // Rayo en zigzag.
      return Path()
        ..moveTo(size * 0.62, 0)
        ..lineTo(size * 0.12, size * 0.56)
        ..lineTo(size * 0.45, size * 0.56)
        ..lineTo(size * 0.34, size)
        ..lineTo(size * 0.88, size * 0.40)
        ..lineTo(size * 0.55, size * 0.40)
        ..close();
    case PipShape.paw:
      // Huella: almohadilla grande y cuatro dedos.
      return Path()
        ..addOval(
          Rect.fromLTWH(size * 0.24, size * 0.48, size * 0.52, size * 0.46),
        )
        ..addOval(
          Rect.fromLTWH(size * 0.04, size * 0.36, size * 0.2, size * 0.26),
        )
        ..addOval(
          Rect.fromLTWH(size * 0.24, size * 0.08, size * 0.2, size * 0.28),
        )
        ..addOval(
          Rect.fromLTWH(size * 0.56, size * 0.08, size * 0.2, size * 0.28),
        )
        ..addOval(
          Rect.fromLTWH(size * 0.76, size * 0.36, size * 0.2, size * 0.26),
        );
    case PipShape.flame:
      // Llama: gota con la punta curvada y un segundo lengüetazo a la izquierda.
      return Path()
        ..moveTo(size * 0.58, 0)
        ..cubicTo(
          size * 0.56,
          size * 0.26,
          size * 0.96,
          size * 0.40,
          size * 0.88,
          size * 0.68,
        )
        ..cubicTo(size * 0.84, size * 0.90, size * 0.66, size, c, size)
        ..cubicTo(
          size * 0.30,
          size,
          size * 0.12,
          size * 0.88,
          size * 0.12,
          size * 0.66,
        )
        ..cubicTo(
          size * 0.12,
          size * 0.48,
          size * 0.28,
          size * 0.38,
          size * 0.32,
          size * 0.22,
        )
        ..cubicTo(
          size * 0.38,
          size * 0.12,
          size * 0.50,
          size * 0.08,
          size * 0.58,
          0,
        )
        ..close();
    case PipShape.heart:
      // Corazón: dos lóbulos arriba y punta abajo.
      return Path()
        ..moveTo(c, size * 0.94)
        ..cubicTo(
          size * 0.02,
          size * 0.62,
          0,
          size * 0.22,
          size * 0.26,
          size * 0.12,
        )
        ..cubicTo(size * 0.40, size * 0.08, c, size * 0.2, c, size * 0.3)
        ..cubicTo(
          c,
          size * 0.2,
          size * 0.60,
          size * 0.08,
          size * 0.74,
          size * 0.12,
        )
        ..cubicTo(size, size * 0.22, size * 0.98, size * 0.62, c, size * 0.94)
        ..close();
  }
}

/// Un pip: contorno siempre visible y relleno que aparece/desaparece con
/// una transición corta. Estático salvo el cambio de [filled].
class PipGlyph extends StatelessWidget {
  const PipGlyph({
    super.key,
    required this.shape,
    required this.filled,
    required this.color,
    this.size = 9,
    this.outline,
    this.duration = const Duration(milliseconds: 250),
  });

  final PipShape shape;
  final bool filled;
  final Color color;
  final double size;

  /// Color del contorno cuando está vacío. `null` = [color] atenuado.
  final Color? outline;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final empty = outline ?? Theme.of(context).colorScheme.outline;
    return TweenAnimationBuilder<double>(
      duration: context.tactical.motion.scale(duration),
      curve: Curves.easeOut,
      tween: Tween(end: filled ? 1 : 0),
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _PipPainter(
          path: pipPath(shape, size),
          fill: color,
          empty: empty,
          t: t,
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter({
    required this.path,
    required this.fill,
    required this.empty,
    required this.t,
  });

  final Path path;
  final Color fill;
  final Color empty;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t > 0) {
      canvas.drawPath(path, Paint()..color = fill.withValues(alpha: t));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(empty, fill, t)!,
    );
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.t != t || old.fill != fill || old.empty != empty || old.path != path;
}
