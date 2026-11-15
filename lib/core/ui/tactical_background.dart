// Fondo atmosférico de las skins (rework estético).
//
// [TacticalScaffoldBackground] pinta la trama del tema activo DETRÁS de
// su hijo: un CustomPainter estático (se dibuja una vez y queda en su
// RepaintBoundary), sin animaciones, así no mantiene frames programados
// ni bloquea `pumpAndSettle`. Ignora los toques.
//
// Cada [BackgroundPatternStyle] tiene su dibujo; todos usan colores del
// tema con alfa bajo para no competir con el contenido.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tactical_theme_tokens.dart';

class TacticalScaffoldBackground extends StatelessWidget {
  const TacticalScaffoldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tactical = context.tactical;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PatternPainter(
                  style: tactical.backgroundPattern,
                  ink: tactical.metalBorder,
                  accent: tactical.primary,
                  shade: scheme.shadow,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.style,
    required this.ink,
    required this.accent,
    required this.shade,
  });

  final BackgroundPatternStyle style;
  final Color ink;
  final Color accent;
  final Color shade;

  Paint _line(Color color, double alpha, [double width = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color.withValues(alpha: alpha);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (style) {
      case BackgroundPatternStyle.codexFrame:
        _codexFrame(canvas, size);
      case BackgroundPatternStyle.parchmentRules:
        _parchment(canvas, size);
      case BackgroundPatternStyle.constellations:
        _constellations(canvas, size);
      case BackgroundPatternStyle.astrolabeGrid:
        _astrolabe(canvas, size);
      case BackgroundPatternStyle.forgedDiagonal:
        _forged(canvas, size);
      case BackgroundPatternStyle.organicVeins:
        _veins(canvas, size);
    }
  }

  // Marco doble con esquinas ornamentales, como la guarda de un códice.
  void _codexFrame(Canvas canvas, Size size) {
    const inset = 10.0;
    final outer = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final inner = outer.deflate(5);
    canvas.drawRect(outer, _line(accent, 0.22, 1));
    canvas.drawRect(inner, _line(ink, 0.35, 0.8));
    final corner = _line(accent, 0.45, 1.2);
    const arm = 22.0;
    for (final (origin, dx, dy) in [
      (outer.topLeft, 1.0, 1.0),
      (outer.topRight, -1.0, 1.0),
      (outer.bottomLeft, 1.0, -1.0),
      (outer.bottomRight, -1.0, -1.0),
    ]) {
      final p = origin + Offset(dx * 9, dy * 9);
      canvas.drawLine(p, p + Offset(dx * arm, 0), corner);
      canvas.drawLine(p, p + Offset(0, dy * arm), corner);
      canvas.drawCircle(p, 1.8, Paint()..color = accent.withValues(alpha: 0.5));
    }
  }

  // Viñeta en los bordes y líneas de pauta tenues.
  void _parchment(Canvas canvas, Size size) {
    final rules = _line(ink, 0.16, 0.8);
    for (var y = 56.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rules);
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.05,
          colors: [shade.withValues(alpha: 0), shade.withValues(alpha: 0.10)],
          stops: const [0.62, 1],
        ).createShader(rect),
    );
  }

  // Estrellas deterministas unidas por trazos finos.
  void _constellations(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final area = size.width * size.height;
    final count = (area / 14000).clamp(14, 60).toInt();
    final stars = [
      for (var i = 0; i < count; i++)
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
    ];
    final link = _line(accent, 0.16, 0.8);
    for (var i = 0; i < stars.length; i++) {
      // Une cada estrella con su vecina más cercana si está a mano.
      double best = 150;
      Offset? target;
      for (var j = 0; j < stars.length; j++) {
        if (i == j) continue;
        final d = (stars[i] - stars[j]).distance;
        if (d < best) {
          best = d;
          target = stars[j];
        }
      }
      if (target != null) canvas.drawLine(stars[i], target, link);
    }
    for (var i = 0; i < stars.length; i++) {
      final big = i % 5 == 0;
      canvas.drawCircle(
        stars[i],
        big ? 1.9 : 1.1,
        Paint()..color = accent.withValues(alpha: big ? 0.5 : 0.32),
      );
    }
  }

  // Retícula técnica con anillos de astrolabio en una esquina.
  void _astrolabe(Canvas canvas, Size size) {
    final grid = _line(ink, 0.18, 0.7);
    const step = 32.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final center = Offset(size.width * 0.92, size.height * 0.10);
    final ring = _line(accent, 0.20, 1);
    for (final r in [46.0, 74.0, 112.0]) {
      canvas.drawCircle(center, r, ring);
    }
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * 74, center + dir * 84, ring);
    }
  }

  // Trama diagonal forjada: rayas a 45° con un paso irregular.
  void _forged(Canvas canvas, Size size) {
    final thin = _line(ink, 0.18, 1);
    final bold = _line(accent, 0.10, 2);
    var i = 0;
    for (var d = -size.height; d < size.width; d += 26) {
      final p = i.isEven ? thin : bold;
      canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), p);
      i++;
    }
  }

  // Nervaduras: curvas largas con ramas, deterministas.
  void _veins(Canvas canvas, Size size) {
    final vein = _line(accent, 0.14, 1.1);
    final branch = _line(ink, 0.22, 0.8);
    final rng = math.Random(5);
    for (var n = 0; n < 4; n++) {
      final x0 = size.width * (0.1 + 0.25 * n) + rng.nextDouble() * 20;
      final path = Path()..moveTo(x0, size.height + 10);
      var x = x0;
      var y = size.height + 10;
      final branches = <Offset>[];
      while (y > -20) {
        final nx = x + (rng.nextDouble() - 0.5) * 70;
        final ny = y - 90 - rng.nextDouble() * 40;
        path.quadraticBezierTo(x + (nx - x) * 0.2 + 24, (y + ny) / 2, nx, ny);
        branches.add(Offset(nx, ny));
        x = nx;
        y = ny;
      }
      canvas.drawPath(path, vein);
      for (final b in branches) {
        final side = rng.nextBool() ? 1.0 : -1.0;
        final tip = b + Offset(side * (28 + rng.nextDouble() * 26), -26);
        canvas.drawPath(
          Path()
            ..moveTo(b.dx, b.dy)
            ..quadraticBezierTo(b.dx + side * 10, b.dy - 22, tip.dx, tip.dy),
          branch,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.style != style ||
      old.ink != ink ||
      old.accent != accent ||
      old.shade != shade;
}
