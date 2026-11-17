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
import 'pip_shape.dart';

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
                  scale: tactical.background.patternScale,
                  intensity: tactical.background.patternOpacity,
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
    this.scale = 1.0,
    this.intensity = 1.0,
  });

  final BackgroundPatternStyle style;
  final Color ink;
  final Color accent;
  final Color shade;

  /// Multiplicador del tamaño de la trama (1 = original).
  final double scale;

  /// Intensidad de la trama del tema (1 = la de fábrica, >1 más marcada).
  final double intensity;

  /// Factor base: las tramas son ~1.5× más presentes que antes de que el
  /// fondo fuera un rasgo propio de cada tema.
  static const _boost = 1.5;

  /// Alfa final de un trazo: base × intensidad del tema, siempre en 0–1.
  double _a(double base) => (base * intensity * _boost).clamp(0.0, 1.0);

  Paint _line(Color color, double alpha, [double width = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color.withValues(alpha: _a(alpha));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (scale != 1.0) {
      canvas.scale(scale);
      size = Size(size.width / scale, size.height / scale);
    }
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
      case BackgroundPatternStyle.frostCrystals:
        _frost(canvas, size);
      case BackgroundPatternStyle.cryptArches:
        _arches(canvas, size);
      case BackgroundPatternStyle.dragonScales:
        _scales(canvas, size);
      case BackgroundPatternStyle.deepWaves:
        _waves(canvas, size);
      case BackgroundPatternStyle.brickWall:
        _bricks(canvas, size);
      case BackgroundPatternStyle.vellumDots:
        _dots(canvas, size);
      case BackgroundPatternStyle.glitchNoise:
        _glitch(canvas, size);
      case BackgroundPatternStyle.skzooPaws:
        _skzoo(canvas, size);
      case BackgroundPatternStyle.purpleOcean:
        _purpleOcean(canvas, size);
      case BackgroundPatternStyle.citrusGrove:
        _citrus(canvas, size);
      case BackgroundPatternStyle.kitsuneSmoke:
        _kitsune(canvas, size);
      case BackgroundPatternStyle.silkSmoke:
        _silk(canvas, size);
      case BackgroundPatternStyle.bambooHeraldry:
        _bambooHeraldry(canvas, size);
      case BackgroundPatternStyle.eclipseOrbits:
        _eclipseOrbits(canvas, size);
      case BackgroundPatternStyle.bandAndBuns:
        _bandAndBuns(canvas, size);
      case BackgroundPatternStyle.runicLattice:
        _runicLattice(canvas, size);
      case BackgroundPatternStyle.elvenFiligree:
        _elvenFiligree(canvas, size);
    }
  }

  // Filigrana Maldita: damasco de tela noble. Celosía de ogivas apuntadas
  // (óvalos con cúspide, como un bordado élfico) y, dentro de cada una, una
  // hoja central con volutas simétricas y rombos. Sobre sarga fina, con
  // constelaciones tenues de fondete. Acento = cerúleo, tinta = bronce.
  // Solo geometría abstracta.
  void _elvenFiligree(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Resplandor del acento en la cabecera.
    final glow = Rect.fromLTWH(0, 0, w, h * 0.5);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: _a(0.08)),
            accent.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    // Sarga: diagonales finísimas, como el tejido de la tela.
    final twill = _line(ink, 0.04, 0.6);
    for (var d = -h; d < w; d += 6) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), twill);
    }

    // Constelaciones de fondete (debajo del damasco).
    final starLine = _line(accent, 0.10, 0.8);
    final starFill = Paint()..color = accent.withValues(alpha: _a(0.26));
    final starWarm = Paint()..color = ink.withValues(alpha: _a(0.34));
    final rnd = math.Random(21);
    for (var gy = 0.0; gy < h; gy += 210) {
      for (var gx = 0.0; gx < w; gx += 250) {
        final pts = <Offset>[];
        var p = Offset(
          gx + 20 + rnd.nextDouble() * 150,
          gy + 20 + rnd.nextDouble() * 120,
        );
        final n = 4 + rnd.nextInt(3);
        for (var i = 0; i < n; i++) {
          pts.add(p);
          p += Offset(
            (rnd.nextDouble() - 0.35) * 70,
            (rnd.nextDouble() - 0.4) * 60,
          );
        }
        final line = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final q in pts.skip(1)) {
          line.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(line, starLine);
        for (var i = 0; i < pts.length; i++) {
          final big = i % 3 == 0;
          final r = big ? 5.5 : 2.6;
          final c = pts[i];
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - r * 1.6)
              ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
              ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 1.6)
              ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
              ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 1.6)
              ..close(),
            big ? starWarm : starFill,
          );
        }
      }
    }

    // Damasco: ogivas de 2*cw x 2*ch, centros en (i*cw, j*ch) con i+j par.
    final cw = (w / 6).clamp(64.0, 96.0);
    final ch = cw * 1.5;
    final ogee = _line(accent, 0.15, 1.2);
    final ogeeIn = _line(accent, 0.08, 0.8);
    final motif = _line(accent, 0.19, 1.0);
    final motifSoft = _line(ink, 0.24, 0.9);
    final nodeWarm = Paint()..color = ink.withValues(alpha: _a(0.6));
    final nodeCool = Paint()..color = accent.withValues(alpha: _a(0.5));

    // Medio contorno de la ogiva (cuadrante superior derecho); se espeja.
    Path quadrant(double sx, double sy, double k) {
      final path = Path()..moveTo(0, -ch * k * sy);
      path.cubicTo(
        0,
        -ch * 0.45 * k * sy,
        cw * k * sx,
        -ch * 0.55 * k * sy,
        cw * k * sx,
        0,
      );
      return path;
    }

    // Espiral desde [c] con radio [r0]; [dir] ±1 sentido de giro.
    Path spiral(Offset c, double r0, double start, double dir) {
      final path = Path();
      for (var i = 0; i <= 36; i++) {
        final t = i / 36;
        final an = start + dir * t * 2.5 * math.pi;
        final r = r0 * (1 - 0.86 * t);
        final pt = Offset(c.dx + r * math.cos(an), c.dy + r * math.sin(an));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      return path;
    }

    // Motivo interior en coordenadas locales (mitad derecha); se espeja.
    final half = Path();
    // Hoja central (almendra) como dos arcos.
    final leaf = Path()
      ..moveTo(0, -ch * 0.62)
      ..quadraticBezierTo(cw * 0.34, -ch * 0.12, 0, ch * 0.62)
      ..quadraticBezierTo(-cw * 0.34, -ch * 0.12, 0, -ch * 0.62);
    final leafIn = Path()
      ..moveTo(0, -ch * 0.46)
      ..quadraticBezierTo(cw * 0.2, -ch * 0.1, 0, ch * 0.46)
      ..quadraticBezierTo(-cw * 0.2, -ch * 0.1, 0, -ch * 0.46);
    // Volutas: tallo desde el centro que se enrosca hacia fuera.
    final c1 = Offset(cw * 0.5, -ch * 0.24);
    final c2 = Offset(cw * 0.44, ch * 0.3);
    half
      ..moveTo(0, -ch * 0.02)
      ..quadraticBezierTo(cw * 0.1, -ch * 0.3, c1.dx - cw * 0.2, c1.dy)
      ..moveTo(0, ch * 0.02)
      ..quadraticBezierTo(cw * 0.12, ch * 0.28, c2.dx - cw * 0.17, c2.dy);
    final curl1 = spiral(c1, cw * 0.2, math.pi, 1);
    final curl2 = spiral(c2, cw * 0.17, math.pi, -1);

    for (var j = -1; j * ch <= h + ch; j++) {
      for (var i = -1; i * cw <= w + cw; i++) {
        if ((i + j).isOdd) continue;
        final cx = i * cw;
        final cy = j * ch;
        canvas.save();
        canvas.translate(cx, cy);
        // Contorno de la ogiva, doble filo.
        for (final sx in const [1.0, -1.0]) {
          for (final sy in const [1.0, -1.0]) {
            canvas.drawPath(quadrant(sx, sy, 1.0), ogee);
            canvas.drawPath(quadrant(sx, sy, 0.84), ogeeIn);
          }
        }
        canvas.drawPath(leaf, motif);
        canvas.drawPath(leafIn, motifSoft);
        for (final sx in const [1.0, -1.0]) {
          canvas.save();
          canvas.scale(sx, 1);
          canvas.drawPath(half, motifSoft);
          canvas.drawPath(curl1, motif);
          canvas.drawPath(curl2, motif);
          canvas.restore();
        }
        // Rombo central y cúspides.
        for (final c in [
          (Offset.zero, 4.0, nodeWarm),
          (Offset(0, -ch), 3.0, nodeCool),
          (Offset(0, ch), 3.0, nodeCool),
          (Offset(cw, 0), 3.0, nodeCool),
          (Offset(-cw, 0), 3.0, nodeCool),
        ]) {
          final o = c.$1;
          final r = c.$2;
          canvas.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - r * 1.5)
              ..lineTo(o.dx + r, o.dy)
              ..lineTo(o.dx, o.dy + r * 1.5)
              ..lineTo(o.dx - r, o.dy)
              ..close(),
            c.$3,
          );
        }
        canvas.restore();
      }
    }
  }

  // Cresta de Forja: retícula angular de trazos rectos a 45° y 60° (tallas
  // rúnicas enanas), rombos macizos en las intersecciones, brasa tenue en
  // la base y grano de piedra determinista. Acento = naranja fragua,
  // tinta = bronce envejecido. Solo geometría.
  void _runicLattice(Canvas canvas, Size size) {
    final glow = Rect.fromLTWH(0, size.height * 0.6, size.width, size.height);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accent.withValues(alpha: _a(0.07)),
            accent.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    const step = 72.0;
    final lineInk = _line(ink, 0.16, 1);
    final lineAccent = _line(accent, 0.10, 1);
    // Diagonales a 45° en ambos sentidos.
    for (var d = -size.height; d < size.width; d += step) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        lineInk,
      );
      canvas.drawLine(
        Offset(d + size.height, 0),
        Offset(d, size.height),
        lineInk,
      );
    }
    // Diagonales a 60° respecto a la horizontal, más espaciadas.
    final run = size.height / math.tan(math.pi / 3);
    for (var d = -run; d < size.width + run; d += step * 2.4) {
      canvas.drawLine(Offset(d, size.height), Offset(d + run, 0), lineAccent);
      canvas.drawLine(Offset(d + run, size.height), Offset(d, 0), lineAccent);
    }
    // Rombos macizos escalonados.
    final node = Paint()..color = accent.withValues(alpha: _a(0.22));
    final nodeLine = _line(ink, 0.30, 1);
    const r = 5.0;
    var row = 0;
    for (var y = step; y < size.height; y += step * 2, row++) {
      for (var x = row.isOdd ? step * 2 : step; x < size.width; x += step * 4) {
        final path = Path()
          ..moveTo(x, y - r)
          ..lineTo(x + r, y)
          ..lineTo(x, y + r)
          ..lineTo(x - r, y)
          ..close();
        canvas.drawPath(path, node);
        canvas.drawPath(path, nodeLine);
      }
    }
    // Grano de piedra/acero: motas mínimas con semilla fija.
    final rnd = math.Random(15);
    final grain = Paint()..color = ink.withValues(alpha: _a(0.20));
    final count = (size.width * size.height / 900).clamp(0, 1200).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height,
          1.2,
          1.2,
        ),
        grain,
      );
    }
  }

  // Maldición Nacida (Choso): niebla violeta tenue arriba, filas escalonadas
  // de doble banda horizontal (marca del puente nasal), dos círculos
  // simétricos con eje vertical y líneas verticales segmentadas.
  // Acento = violeta maldito, tinta = pátina violeta. Solo geometría.
  void _bandAndBuns(Canvas canvas, Size size) {
    final mist = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: size.height * 0.6,
    );
    canvas.drawRect(
      mist,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: _a(0.10)),
            accent.withValues(alpha: 0),
          ],
        ).createShader(mist),
    );
    // Dobles bandas escalonadas.
    final band = _line(ink, 0.18, 1.2);
    var row = 0;
    for (var y = 36.0; y < size.height; y += 58, row++) {
      for (var x = (row.isOdd ? 52.0 : 12.0); x < size.width; x += 104) {
        canvas.drawLine(Offset(x, y), Offset(x + 34, y), band);
        canvas.drawLine(Offset(x + 5, y + 5), Offset(x + 29, y + 5), band);
      }
    }
    // Dos moños: círculos simétricos con eje central, y su reflejo abajo.
    final cx = size.width / 2;
    final r = math.min(size.width, size.height) * 0.05;
    final dx = r * 2.6;
    for (final (cy, k) in [
      (size.height * 0.2, 1.0),
      (size.height * 0.86, 0.5),
    ]) {
      final ring = _line(accent, 0.30 * k, 1.2);
      final inner = _line(ink, 0.30 * k, 1);
      for (final sx in [-1.0, 1.0]) {
        final c = Offset(cx + sx * dx, cy);
        canvas.drawCircle(c, r, ring);
        canvas.drawCircle(c, r * 0.45, inner);
      }
      canvas.drawLine(Offset(cx, cy - r * 2), Offset(cx, cy + r * 2), inner);
    }
    // Líneas verticales segmentadas en los márgenes.
    final seg = _line(accent, 0.16, 1);
    for (final x in [size.width * 0.06, size.width * 0.94]) {
      for (var y = size.height * 0.3; y < size.height * 0.75; y += 14) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 8), seg);
      }
    }
  }

  // Eclipse Sombrío: arcos concéntricos de eclipse saliendo por la esquina
  // superior derecha, un disco oscuro con corona y un aro orbital inclinado
  // abajo a la izquierda, más un campo disperso de destellos de cuatro
  // puntas. Acento = cian astral, tinta = bronce apagado. Sin figuras.
  void _eclipseOrbits(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.86, size.height * 0.12);
    final base = math.min(size.width, size.height);
    for (var i = 1; i <= 6; i++) {
      canvas.drawCircle(
        c,
        base * (0.10 + i * 0.075),
        _line(accent, 0.12 - i * 0.012, 1),
      );
    }
    // Corona: disco oscuro con filo luminoso.
    canvas.drawCircle(
      c,
      base * 0.085,
      Paint()..color = shade.withValues(alpha: _a(0.5)),
    );
    canvas.drawCircle(c, base * 0.085, _line(accent, 0.34, 1.4));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: base * 0.095),
      -math.pi * 0.9,
      math.pi * 0.7,
      false,
      _line(accent, 0.45, 1.6),
    );
    // Aro orbital inclinado con un satélite.
    final o = Offset(size.width * 0.12, size.height * 0.86);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(-0.45);
    final ring = Rect.fromCenter(
      center: Offset.zero,
      width: base * 0.9,
      height: base * 0.26,
    );
    canvas.drawOval(ring, _line(ink, 0.22, 1));
    canvas.drawOval(ring.deflate(9), _line(ink, 0.10, 1));
    canvas.drawCircle(
      Offset(ring.width / 2, 0),
      3,
      Paint()..color = accent.withValues(alpha: _a(0.5)),
    );
    canvas.restore();
    // Lluvia fina: hilos verticales que se desvanecen hacia abajo.
    final drip = math.Random(5);
    for (var x = 12.0; x < size.width; x += 18 + drip.nextDouble() * 34) {
      final y = drip.nextDouble() * size.height * 0.7;
      final len = 40 + drip.nextDouble() * 160;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + len),
        Paint()
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0),
              accent.withValues(alpha: _a(0.16)),
              accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(x, y, 1, len)),
      );
    }
    // Cortes: pequeños grupos de tres tajos paralelos.
    final cut = _line(ink, 0.2, 1);
    for (final f in [(0.22, 0.30), (0.7, 0.62)]) {
      final o = Offset(size.width * f.$1, size.height * f.$2);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          o + Offset(i * 9.0, 0),
          o + Offset(i * 9.0 + 26, 54),
          cut,
        );
      }
    }
    // Destellos de cuatro puntas.
    final rng = math.Random(21);
    final glint = Paint()..color = accent.withValues(alpha: _a(0.30));
    final warm = Paint()..color = ink.withValues(alpha: _a(0.30));
    for (var gx = 0; gx * 150.0 < size.width + 150; gx++) {
      for (var gy = 0; gy * 150.0 < size.height + 150; gy++) {
        if (rng.nextDouble() < 0.45) continue;
        final p = Offset(
          gx * 150.0 + rng.nextDouble() * 140,
          gy * 150.0 + rng.nextDouble() * 140,
        );
        _glint(
          canvas,
          p,
          2 + rng.nextDouble() * 4.5,
          rng.nextBool() ? glint : warm,
        );
      }
    }
  }

  // Destello de cuatro puntas: rombo cóncavo.
  void _glint(Canvas canvas, Offset c, double r, Paint paint) {
    final k = r * 0.22;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + k, c.dy - k)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + k, c.dy + k)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - k, c.dy + k)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - k, c.dy - k)
      ..close();
    canvas.drawPath(path, paint);
  }

  // Panda Blindado: celosía de bambú (columnas verticales segmentadas con
  // nudos), trazos heráldicos diagonales y destellos de estrella de ocho
  // puntas. Acento = jade, tinta = oro antiguo. Todo geométrico, sin figuras.
  void _bambooHeraldry(Canvas canvas, Size size) {
    const gap = 46.0;
    const seg = 34.0;
    final cane = _line(accent, 0.10, 1.2);
    final node = _line(ink, 0.30, 1.6);
    var col = 0;
    for (var x = gap / 2; x < size.width; x += gap, col++) {
      final shift = (col % 2) * (seg / 2);
      for (var y = -shift; y < size.height; y += seg + 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + seg), cane);
        canvas.drawLine(
          Offset(x - 3, y + seg + 3),
          Offset(x + 3, y + seg + 3),
          node,
        );
      }
    }
    // Trazos heráldicos: diagonales finas cada cierto paso.
    final slash = _line(ink, 0.12, 1);
    for (var d = -size.height; d < size.width; d += 138) {
      canvas.drawLine(
        Offset(d, size.height),
        Offset(d + size.height, 0),
        slash,
      );
    }
    // Destellos de estrella de ocho puntas en rejilla dispersa.
    final rng = math.Random(15);
    final star = _line(ink, 0.32, 1);
    final fill = Paint()..color = ink.withValues(alpha: _a(0.10));
    for (var gx = 0; gx * 230.0 < size.width + 230; gx++) {
      for (var gy = 0; gy * 230.0 < size.height + 230; gy++) {
        final c = Offset(
          gx * 230.0 + 40 + rng.nextDouble() * 150,
          gy * 230.0 + 40 + rng.nextDouble() * 150,
        );
        _octagram(canvas, c, 7 + rng.nextDouble() * 7, star, fill);
      }
    }
  }

  // Estrella de ocho puntas: dos cuadrados superpuestos y girados 45°.
  void _octagram(Canvas canvas, Offset c, double r, Paint line, Paint fill) {
    final path = Path();
    for (var q = 0; q < 2; q++) {
      for (var i = 0; i < 4; i++) {
        final a = math.pi / 2 * i + q * math.pi / 4 - math.pi / 4;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
  }

  // Señal perdida: scanlines, barras de glitch con separación RGB (roja del
  // acento + copia desplazada en tinta), estática y rayas diagonales rojas.
  void _glitch(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final scan = _line(ink, 0.10, 1);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
    final red = Paint()..color = accent.withValues(alpha: _a(0.16));
    final cold = Paint()..color = ink.withValues(alpha: _a(0.22));
    final count = (size.width * size.height / 16000).clamp(12, 34).toInt();
    for (var n = 0; n < count; n++) {
      final w = 40 + rng.nextDouble() * 180;
      final h = 2 + rng.nextDouble() * 8;
      final x = rng.nextDouble() * size.width - 20;
      final y = rng.nextDouble() * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), red);
      canvas.drawRect(Rect.fromLTWH(x + 3, y + 1.5, w, h), cold);
      // Algunos bloques se repiten desplazados, como un frame que salta.
      if (n % 5 == 0) {
        canvas.drawRect(Rect.fromLTWH(x - 24, y + h + 6, w * 0.6, h), red);
      }
    }
    final dot = Paint()..color = ink.withValues(alpha: _a(0.25));
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.8,
        dot,
      );
    }
    // Rayas diagonales de aviso en la esquina superior izquierda.
    final slash = _line(accent, 0.32, 3);
    for (var d = 14.0; d <= 140; d += 14) {
      canvas.drawLine(Offset(d, 0), Offset(0, d), slash);
    }
  }

  // Zoo: huellas y cabecitas de animal en rejilla desfasada. Siluetas
  // genéricas de trazo fino (lobo, conejo, perrito, osito, zorro, cerdito).
  void _skzoo(Canvas canvas, Size size) {
    const cell = 88.0;
    final paw = _line(accent, 0.24, 1.2);
    final head = _line(ink, 0.34, 1.2);
    var row = 0;
    for (var y = cell / 2; y < size.height + cell; y += cell * 0.9) {
      final shift = row.isOdd ? cell / 2 : 0.0;
      var col = 0;
      for (var x = cell / 2 - shift; x < size.width + cell; x += cell) {
        final id = row * 7 + col * 3;
        final angle = ((id * 37) % 60 - 30) * math.pi / 180;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        if (id % 3 == 0) {
          _animalHead(canvas, id ~/ 3 % 6, head);
        } else {
          _pawPrint(canvas, paw);
        }
        canvas.restore();
        col++;
      }
      row++;
    }
  }

  void _pawPrint(Canvas canvas, Paint paint) {
    canvas.drawOval(const Rect.fromLTWH(-8, -1, 16, 13), paint);
    for (final r in const [
      Rect.fromLTWH(-14, -8, 6, 8),
      Rect.fromLTWH(-8, -15, 6, 9),
      Rect.fromLTWH(2, -15, 6, 9),
      Rect.fromLTWH(8, -8, 6, 8),
    ]) {
      canvas.drawOval(r, paint);
    }
  }

  void _animalHead(Canvas canvas, int kind, Paint paint) {
    canvas.drawCircle(Offset.zero, 11, paint);
    Path tri(double sx) => Path()
      ..moveTo(sx * 9, -6)
      ..lineTo(sx * 9, -20)
      ..lineTo(sx * 2, -10);
    switch (kind) {
      case 0: // lobo: orejas en punta
        canvas.drawPath(tri(-1), paint);
        canvas.drawPath(tri(1), paint);
      case 1: // conejo: orejas largas
        canvas.drawOval(const Rect.fromLTWH(-9, -32, 6, 20), paint);
        canvas.drawOval(const Rect.fromLTWH(3, -32, 6, 20), paint);
      case 2: // perrito: orejas caídas
        canvas.drawOval(const Rect.fromLTWH(-17, -8, 8, 16), paint);
        canvas.drawOval(const Rect.fromLTWH(9, -8, 8, 16), paint);
      case 3: // osito: orejas redondas
        canvas.drawCircle(const Offset(-9, -9), 5, paint);
        canvas.drawCircle(const Offset(9, -9), 5, paint);
      case 4: // zorro: orejas anchas
        canvas.drawPath(
          Path()
            ..moveTo(-11, -4)
            ..lineTo(-8, -22)
            ..lineTo(0, -10),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(11, -4)
            ..lineTo(8, -22)
            ..lineTo(0, -10),
          paint,
        );
      case 6: // quokka: orejas redondas pequeñas y sonrisa
        canvas.drawCircle(const Offset(-8, -9), 4, paint);
        canvas.drawCircle(const Offset(8, -9), 4, paint);
        canvas.drawArc(
          const Rect.fromLTWH(-5, 0, 10, 7),
          0,
          math.pi,
          false,
          paint,
        );
        canvas.drawOval(const Rect.fromLTWH(-2, -1.5, 4, 3), paint);
      default: // cerdito: orejitas dobladas y hocico
        canvas.drawPath(
          Path()
            ..moveTo(-10, -5)
            ..lineTo(-9, -15)
            ..lineTo(-3, -9),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, -5)
            ..lineTo(9, -15)
            ..lineTo(3, -9),
          paint,
        );
        canvas.drawOval(const Rect.fromLTWH(-5, 1, 10, 7), paint);
    }
    final eye = Paint()..color = paint.color;
    canvas.drawCircle(const Offset(-4, -2), 1.1, eye);
    canvas.drawCircle(const Offset(4, -2), 1.1, eye);
  }

  // Mar de luces: bokeh de círculos blandos, más denso abajo (el público),
  // con chispas y unos pocos corazones de contorno fino.
  void _purpleOcean(Canvas canvas, Size size) {
    final rng = math.Random(21);
    final count = (size.width * size.height / 9000).clamp(18, 60).toInt();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = size.height * (1 - math.pow(rng.nextDouble(), 1.8));
      final r = 6 + math.pow(rng.nextDouble(), 2) * 34;
      final a = 0.10 + rng.nextDouble() * 0.10;
      final center = Offset(x.toDouble(), y.toDouble());
      canvas.drawCircle(
        center,
        r.toDouble(),
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: _a(a)),
              accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r.toDouble())),
      );
    }
    // Constelaciones sobre el público: estrellas en la mitad alta unidas
    // a su vecina más cercana, y un grupo fijo de siete estrellas.
    final stars = [
      for (var i = 0; i < 22; i++)
        Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height * 0.6,
        ),
    ];
    final link = _line(accent, 0.20, 0.9);
    for (var i = 0; i < stars.length; i++) {
      double best = 130;
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
    final starPaint = Paint()..color = ink.withValues(alpha: _a(0.75));
    for (var i = 0; i < stars.length; i++) {
      canvas.drawCircle(stars[i], i % 4 == 0 ? 1.9 : 1.2, starPaint);
    }
    final seven = [
      for (final n in const [
        Offset(0.60, 0.07),
        Offset(0.68, 0.10),
        Offset(0.76, 0.12),
        Offset(0.83, 0.16),
        Offset(0.84, 0.25),
        Offset(0.92, 0.27),
        Offset(0.93, 0.17),
      ])
        Offset(n.dx * size.width, n.dy * size.height),
    ];
    final sevenLink = _line(accent, 0.40, 1.1);
    for (var i = 0; i < seven.length - 1; i++) {
      canvas.drawLine(seven[i], seven[i + 1], sevenLink);
    }
    canvas.drawLine(seven[3], seven[6], sevenLink);
    final sevenStar = Paint()..color = accent.withValues(alpha: _a(0.9));
    for (final p in seven) {
      canvas.drawCircle(p, 2.3, sevenStar);
    }
    final heart = _line(accent, 0.30, 1);
    for (var i = 0; i < 6; i++) {
      final s = 10 + rng.nextDouble() * 8;
      canvas.save();
      canvas.translate(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.7,
      );
      canvas.drawPath(pipPath(PipShape.heart, s), heart);
      canvas.restore();
    }
  }

  // Cítricos: rodajas (acento) y hojas (tinta) repartidas en rejilla
  // desfasada con rotación determinista.
  void _citrus(Canvas canvas, Size size) {
    const cell = 96.0;
    final peel = _line(accent, 0.30, 1.4);
    final segment = _line(accent, 0.20, 1);
    final leaf = _line(ink, 0.55, 1.4);
    final vein = _line(ink, 0.35, 1);
    var row = 0;
    for (var y = cell / 2; y < size.height + cell; y += cell * 0.85) {
      final shift = row.isOdd ? cell / 2 : 0.0;
      var col = 0;
      for (var x = cell / 2 - shift; x < size.width + cell; x += cell) {
        final id = row * 5 + col * 3;
        final angle = ((id * 29) % 90) * math.pi / 180;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        final kind = id % 6;
        if (kind == 4 || kind == 5) {
          // Conejito y quokka (Minsung), de trazo fino.
          _animalHead(canvas, kind == 4 ? 1 : 6, _line(accent, 0.45, 1.3));
        } else if (kind.isEven) {
          // Rodaja: corteza, anillo interior y ocho gajos.
          canvas.drawCircle(Offset.zero, 15, peel);
          canvas.drawCircle(Offset.zero, 11, segment);
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4;
            canvas.drawLine(
              Offset(math.cos(a), math.sin(a)) * 2,
              Offset(math.cos(a), math.sin(a)) * 11,
              segment,
            );
          }
        } else {
          // Hoja: dos arcos y nervio central.
          canvas.drawPath(
            Path()
              ..moveTo(-14, 0)
              ..quadraticBezierTo(0, -14, 14, 0)
              ..quadraticBezierTo(0, 14, -14, 0),
            leaf,
          );
          canvas.drawLine(const Offset(-14, 0), const Offset(11, 0), vein);
        }
        canvas.restore();
        col++;
      }
      row++;
    }
  }

  // Corrientes de humo: S largas con estelas paralelas que cruzan la
  // pantalla; compartido por las skins de Kael y Nix.
  void _smokeStreams(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final streams = (h / 170).clamp(3, 7).toInt();
    for (var n = 0; n < streams; n++) {
      final y0 = h * (0.12 + 0.9 * n / streams);
      final amp = 36.0 + (n % 3) * 18;
      final strong = n.isEven;
      for (var k = 0; k < 3; k++) {
        final dy = k * 9.0;
        final path = Path()
          ..moveTo(-20, y0 + dy + amp)
          ..cubicTo(
            w * 0.25,
            y0 + dy - amp * 1.4,
            w * 0.5,
            y0 + dy + amp * 1.6,
            w * 0.75,
            y0 + dy - amp * 0.4,
          )
          ..cubicTo(
            w * 0.88,
            y0 + dy - amp * 1.2,
            w * 0.98,
            y0 + dy - amp * 0.2,
            w + 20,
            y0 + dy - amp * 0.9,
          );
        canvas.drawPath(
          path,
          _line(
            k == 0 && strong ? accent : ink,
            k == 0 ? (strong ? 0.22 : 0.40) : 0.20 - k * 0.05,
            k == 0 ? 1.4 : 0.9,
          ),
        );
      }
    }
  }

  // Kitsune: una luna carmesí a medio salir por la esquina superior
  // derecha (halo radial y anillos finos) y corrientes largas de humo que
  // cruzan la pantalla en diagonal, cada una con su estela paralela. Sin
  // motivos repetidos: composición única que escala con el lienzo.
  void _kitsune(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.min(w, h) * 0.55;
    final moon = Offset(w * 0.92, h * 0.06);

    // Halo de la luna.
    canvas.drawCircle(
      moon,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: _a(0.16)),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: r * 1.9)),
    );
    // Disco y anillos concéntricos.
    canvas.drawCircle(
      moon,
      r,
      Paint()..color = accent.withValues(alpha: _a(0.05)),
    );
    canvas.drawCircle(moon, r, _line(accent, 0.30, 1.6));
    canvas.drawCircle(moon, r * 1.12, _line(ink, 0.45, 1));
    canvas.drawCircle(moon, r * 1.3, _line(ink, 0.25, 1));

    _smokeStreams(canvas, size);

    // Marca de agua: máscara kitsune muy tenue, a medio salir por abajo a
    // la izquierda.
    _kitsuneMask(canvas, Offset(w * 0.14, h * 0.9), math.min(w, h) * 0.55);

    // Viñeta inferior: el humo se pierde en la sombra.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shade.withValues(alpha: 0), shade.withValues(alpha: 0.25)],
        ).createShader(rect),
    );
  }

  // Seda: un sol carmesí a medio salir por la esquina superior izquierda
  // (halo, disco y anillos finos), las mismas corrientes de humo que Kael y,
  // abajo a la derecha, la máscara de bardo. Sobrio y sin confeti.
  void _silk(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.min(w, h) * 0.5;
    final sun = Offset(w * 0.08, h * 0.06);
    canvas.drawCircle(
      sun,
      r * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: _a(0.14)),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 1.8)),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()..color = accent.withValues(alpha: _a(0.05)),
    );
    canvas.drawCircle(sun, r, _line(accent, 0.30, 1.6));
    canvas.drawCircle(sun, r * 1.12, _line(ink, 0.35, 1));
    canvas.drawCircle(sun, r * 1.3, _line(ink, 0.2, 1));

    _smokeStreams(canvas, size);

    _bardMask(canvas, Offset(w * 0.86, h * 0.9), math.min(w, h) * 0.5);
  }

  // Máscara de bardo: la silueta de la de Kael ladeada, con ojos de media
  // luna (pillina), sonrisa ancha, espirales en las mejillas, rayo en la
  // frente y borlas colgando de las orejas. [m] es la mitad del ancho.
  void _bardMask(Canvas canvas, Offset c, double m) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.2);
    Offset p(double x, double y) => Offset(x * m, y * m);
    final face = Path()
      ..moveTo(p(-0.95, -0.95).dx, p(-0.95, -0.95).dy)
      ..lineTo(p(-0.55, -0.55).dx, p(-0.55, -0.55).dy)
      ..quadraticBezierTo(
        0,
        p(0, -0.78).dy,
        p(0.55, -0.55).dx,
        p(0.55, -0.55).dy,
      )
      ..lineTo(p(0.95, -0.95).dx, p(0.95, -0.95).dy)
      ..quadraticBezierTo(
        p(1.0, -0.1).dx,
        p(1.0, -0.1).dy,
        p(0.62, 0.3).dx,
        p(0.62, 0.3).dy,
      )
      ..lineTo(0, m)
      ..lineTo(p(-0.62, 0.3).dx, p(-0.62, 0.3).dy)
      ..quadraticBezierTo(
        p(-1.0, -0.1).dx,
        p(-1.0, -0.1).dy,
        p(-0.95, -0.95).dx,
        p(-0.95, -0.95).dy,
      )
      ..close();
    canvas.drawPath(face, Paint()..color = accent.withValues(alpha: _a(0.04)));
    canvas.drawPath(face, _line(ink, 0.40, 1.4));

    final mark = _line(accent, 0.42, 2);
    final soft = _line(accent, 0.30, 1.4);
    for (final s in [-1.0, 1.0]) {
      // Ojo de media luna.
      canvas.drawPath(
        Path()
          ..moveTo(p(s * 0.50, -0.02).dx, p(s * 0.50, -0.02).dy)
          ..quadraticBezierTo(
            p(s * 0.30, -0.28).dx,
            p(s * 0.30, -0.28).dy,
            p(s * 0.10, -0.02).dx,
            p(s * 0.10, -0.02).dy,
          ),
        mark,
      );
      // Espiral de mejilla.
      final cheek = p(s * 0.70, 0.10);
      canvas.drawCircle(cheek, m * 0.11, soft);
      canvas.drawCircle(cheek, m * 0.05, soft);
      canvas.drawLine(cheek, cheek + p(s * 0.11, 0), soft);
      // Borla de la oreja.
      final top = p(s * 0.95, -0.95);
      final end = top + p(s * 0.06, 0.55);
      canvas.drawLine(top, end, soft);
      canvas.drawCircle(
        end,
        m * 0.05,
        Paint()..color = accent.withValues(alpha: _a(0.40)),
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(end, end + p(i * 0.04, 0.16), soft);
      }
    }
    // Sonrisa ancha.
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.34, 0.34).dx, p(-0.34, 0.34).dy)
        ..quadraticBezierTo(
          0,
          p(0, 0.72).dy,
          p(0.34, 0.34).dx,
          p(0.34, 0.34).dy,
        ),
      mark,
    );
    // Rayo en la frente.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.05, -0.66).dx, p(0.05, -0.66).dy)
        ..lineTo(p(-0.06, -0.48).dx, p(-0.06, -0.48).dy)
        ..lineTo(p(0.06, -0.48).dx, p(0.06, -0.48).dy)
        ..lineTo(p(-0.04, -0.30).dx, p(-0.04, -0.30).dy),
      _line(accent, 0.38, 1.8),
    );
    canvas.restore();
  }

  // Máscara kitsune de perfil frontal: orejas en punta, ojos rasgados,
  // marcas de mejilla y hocico afilado. [m] es la mitad del ancho.
  void _kitsuneMask(Canvas canvas, Offset c, double m) {
    Offset p(double x, double y) => c + Offset(x * m, y * m);
    final face = Path()
      ..moveTo(p(-0.95, -0.95).dx, p(-0.95, -0.95).dy)
      ..lineTo(p(-0.55, -0.55).dx, p(-0.55, -0.55).dy)
      ..quadraticBezierTo(
        p(0, -0.78).dx,
        p(0, -0.78).dy,
        p(0.55, -0.55).dx,
        p(0.55, -0.55).dy,
      )
      ..lineTo(p(0.95, -0.95).dx, p(0.95, -0.95).dy)
      ..quadraticBezierTo(
        p(1.0, -0.1).dx,
        p(1.0, -0.1).dy,
        p(0.62, 0.3).dx,
        p(0.62, 0.3).dy,
      )
      ..lineTo(p(0, 1.0).dx, p(0, 1.0).dy)
      ..lineTo(p(-0.62, 0.3).dx, p(-0.62, 0.3).dy)
      ..quadraticBezierTo(
        p(-1.0, -0.1).dx,
        p(-1.0, -0.1).dy,
        p(-0.95, -0.95).dx,
        p(-0.95, -0.95).dy,
      )
      ..close();
    canvas.drawPath(face, Paint()..color = ink.withValues(alpha: _a(0.05)));
    canvas.drawPath(face, _line(ink, 0.40, 1.4));
    final mark = _line(accent, 0.38, 2);
    for (final s in [-1.0, 1.0]) {
      // Ojo rasgado y tres marcas de mejilla.
      canvas.drawLine(p(s * 0.52, -0.12), p(s * 0.14, 0.08), mark);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          p(s * 0.92, 0.0 + i * 0.13),
          p(s * (0.66 - i * 0.05), 0.12 + i * 0.13),
          _line(accent, 0.26, 1.4),
        );
      }
    }
    canvas.drawLine(p(0, -0.62), p(0, -0.3), mark);
    canvas.drawCircle(
      p(0, 0.9),
      m * 0.04,
      Paint()..color = accent.withValues(alpha: _a(0.4)),
    );
  }

  // Retícula de puntos tenues, como papel punteado.
  void _dots(Canvas canvas, Size size) {
    final dot = Paint()..color = ink.withValues(alpha: _a(0.45));
    const step = 28.0;
    for (var y = step; y < size.height; y += step) {
      for (var x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  // Copos de seis brazos deterministas.
  void _frost(Canvas canvas, Size size) {
    final rng = math.Random(3);
    final count = (size.width * size.height / 26000).clamp(8, 28).toInt();
    final arm = _line(accent, 0.18, 0.9);
    for (var n = 0; n < count; n++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = 8 + rng.nextDouble() * 14;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c, c + dir * r, arm);
        final mid = c + dir * (r * 0.6);
        final side = Offset(-dir.dy, dir.dx) * (r * 0.25);
        canvas.drawLine(mid - side, mid + side, arm);
      }
    }
  }

  // Hilera de arcos apuntados góticos arriba, con sombra de cripta.
  void _arches(Canvas canvas, Size size) {
    final line = _line(ink, 0.30, 1);
    const w = 64.0;
    const h = 80.0;
    for (var x = 0.0; x < size.width; x += w) {
      final p = Path()
        ..moveTo(x, h)
        ..lineTo(x, h * 0.45)
        ..quadraticBezierTo(x, 0, x + w / 2, 0)
        ..quadraticBezierTo(x + w, 0, x + w, h * 0.45)
        ..lineTo(x + w, h);
      canvas.drawPath(p, line);
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            shade.withValues(alpha: _a(0.18)),
            shade.withValues(alpha: _a(0)),
          ],
          stops: const [0, 0.5],
        ).createShader(rect),
    );
  }

  // Escamas: semicírculos que se solapan en filas desfasadas.
  void _scales(Canvas canvas, Size size) {
    final scale = _line(ink, 0.22, 1);
    final glint = _line(accent, 0.10, 1);
    const r = 20.0;
    var row = 0;
    for (var y = 0.0; y < size.height + r; y += r * 0.8) {
      final shift = row.isEven ? 0.0 : r;
      for (var x = -r + shift; x < size.width + r; x += r * 2) {
        final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
        canvas.drawArc(rect, 0, math.pi, false, row % 3 == 0 ? glint : scale);
      }
      row++;
    }
  }

  // Ondulaciones horizontales con fase cambiante.
  void _waves(Canvas canvas, Size size) {
    final wave = _line(accent, 0.12, 1);
    final deep = _line(ink, 0.26, 0.8);
    var i = 0;
    for (var y = 28.0; y < size.height; y += 34) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += 4) {
        path.lineTo(x, y + math.sin(x / 38 + i * 0.9) * 5);
      }
      canvas.drawPath(path, i.isEven ? wave : deep);
      i++;
    }
  }

  // Ladrillos en aparejo a soga: hiladas con medio ladrillo de desfase,
  // cada ladrillo con su tono, filo de luz arriba y sombra abajo; algunos
  // con musgo y grietas, de forma determinista.
  void _bricks(Canvas canvas, Size size) {
    final mortar = _line(ink, 0.34, 2);
    final lit = _line(ink, 0.30, 1);
    final dark = _line(shade, 0.22, 1);
    final moss = Paint()..color = accent.withValues(alpha: _a(0.10));
    final crack = _line(shade, 0.30, 1);
    const bw = 56.0;
    const bh = 24.0;
    var row = 0;
    for (var y = 0.0; y < size.height; y += bh) {
      final shift = row.isEven ? 0.0 : bw / 2;
      for (var x = -shift; x < size.width; x += bw) {
        final id = row * 31 + (x / bw).floor() * 17;
        final tone = (id.abs() % 5) / 4; // 0..1, determinista.
        final brick = Rect.fromLTWH(x + 1, y + 1, bw - 2, bh - 2);
        canvas.drawRect(
          brick,
          Paint()..color = shade.withValues(alpha: _a(0.04 + tone * 0.10)),
        );
        // Biselado: luz arriba-izquierda, sombra abajo-derecha.
        canvas.drawLine(brick.topLeft, brick.topRight, lit);
        canvas.drawLine(brick.topLeft, brick.bottomLeft, lit);
        canvas.drawLine(brick.bottomLeft, brick.bottomRight, dark);
        canvas.drawLine(brick.topRight, brick.bottomRight, dark);
        if (id.abs() % 11 == 0) canvas.drawRect(brick, moss);
        if (id.abs() % 13 == 0) {
          canvas.drawPath(
            Path()
              ..moveTo(x + bw * 0.3, y + 1)
              ..lineTo(x + bw * 0.38, y + bh * 0.45)
              ..lineTo(x + bw * 0.33, y + bh - 1),
            crack,
          );
        }
      }
      canvas.drawLine(Offset(0, y), Offset(size.width, y), mortar);
      for (var x = -shift; x < size.width; x += bw) {
        canvas.drawLine(Offset(x, y), Offset(x, y + bh), mortar);
      }
      row++;
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
      canvas.drawCircle(
        p,
        1.8,
        Paint()..color = accent.withValues(alpha: _a(0.5)),
      );
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
          colors: [
            shade.withValues(alpha: _a(0)),
            shade.withValues(alpha: _a(0.10)),
          ],
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
        Paint()..color = accent.withValues(alpha: _a(big ? 0.5 : 0.32)),
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
      old.shade != shade ||
      old.scale != scale ||
      old.intensity != intensity;
}
