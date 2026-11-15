// Forma de los indicadores de carga (pips) y glifos de ornamento.
//
// Cada skin elige su forma ([PipShape]): círculo, rombo, cuadrado, hoja o
// estrella de cuatro puntas. [pipPath] devuelve el contorno en un
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
      duration: duration,
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
