import 'package:flutter/material.dart';

/// Simula una tipografía tipo matriz de puntos usando fuente monoespaciada,
/// tracking amplio y un resplandor (glow) del color de acento actual.
/// No puede ser const: el color y el tamaño vienen de fuera y cambian.
class DotMatrixText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  const DotMatrixText({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 48,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    // El constructor de arriba es const porque solo depende de sus propios
    // parámetros (patrón estándar de StatelessWidget), pero el Text de abajo
    // NO lo es: su TextStyle depende de "color", que es una variable de
    // instancia que llega desde fuera (theme dinámico / datos del modelo).
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 4,
        shadows: [
          Shadow(color: color.withOpacity(0.6), blurRadius: 18),
          Shadow(color: color.withOpacity(0.3), blurRadius: 36),
        ],
      ),
    );
  }
}
