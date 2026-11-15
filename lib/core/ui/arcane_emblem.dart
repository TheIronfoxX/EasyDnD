// Emblema geométrico arcano de la portada (rework estético).
//
// Un CustomPainter liviano y estático: anillos concéntricos, marcas de
// compás, un hexagrama y la silueta de un d20 en el centro. Sin
// animación a propósito — la bienvenida tiene que ser instantánea.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tactical_theme_tokens.dart';

class ArcaneEmblem extends StatelessWidget {
  const ArcaneEmblem({super.key, this.size = 132});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tactical = context.tactical;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EmblemPainter(
          accent: scheme.primary,
          metal: tactical.metalBorder,
          glow: tactical.metalHighlight,
          core: tactical.surfaceRaised,
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter({
    required this.accent,
    required this.metal,
    required this.glow,
    required this.core,
  });

  final Color accent;
  final Color metal;
  final Color glow;
  final Color core;

  Path _polygon(Offset center, double radius, int sides, double rotation) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotation + i * 2 * math.pi / sides;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;

    // Halo.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Anillos.
    canvas.drawCircle(center, r * 0.92, stroke(metal, 1));
    canvas.drawCircle(
      center,
      r * 0.80,
      stroke(accent.withValues(alpha: 0.7), 1.4),
    );
    canvas.drawCircle(center, r * 0.50, stroke(metal, 1));

    // Marcas de compás entre los dos anillos exteriores.
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final major = i % 6 == 0;
      canvas.drawLine(
        center + dir * r * (major ? 0.80 : 0.84),
        center + dir * r * 0.92,
        stroke(major ? accent : metal, major ? 1.6 : 1),
      );
    }

    // Hexagrama: dos triángulos opuestos.
    final star = stroke(accent.withValues(alpha: 0.55), 1.2)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_polygon(center, r * 0.80, 3, -math.pi / 2), star);
    canvas.drawPath(_polygon(center, r * 0.80, 3, math.pi / 2), star);

    // Núcleo: un d20 visto de frente (hexágono + triángulo interior).
    final hex = _polygon(center, r * 0.40, 6, -math.pi / 2);
    canvas.drawPath(hex, Paint()..color = core);
    canvas.drawPath(hex, stroke(accent, 1.8)..strokeJoin = StrokeJoin.round);

    final inner = <Offset>[
      for (var i = 0; i < 3; i++)
        center +
            Offset(
                  math.cos(-math.pi / 2 + i * 2 * math.pi / 3),
                  math.sin(-math.pi / 2 + i * 2 * math.pi / 3),
                ) *
                r *
                0.22,
    ];
    final facet = stroke(glow.withValues(alpha: 0.75), 1.1)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..addPolygon(inner, true), facet);
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final vertex =
          center + Offset(math.cos(angle), math.sin(angle)) * r * 0.40;
      // Cada vértice del hexágono se une a los dos vértices más
      // cercanos del triángulo interior: las caras del icosaedro.
      final a = inner[(i ~/ 2) % 3];
      final b = inner[((i + 1) ~/ 2) % 3];
      canvas.drawLine(vertex, a, facet);
      if (b != a) canvas.drawLine(vertex, b, facet);
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.metal != metal ||
      oldDelegate.glow != glow ||
      oldDelegate.core != core;
}
