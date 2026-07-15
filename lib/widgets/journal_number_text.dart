import 'package:flutter/material.dart';

/// Números grandes con look "tinta de diario": serif, sin glow, sin
/// tracking exagerado. No puede ser const: el color y el tamaño llegan
/// desde fuera (tema dinámico / datos del modelo).
class JournalNumberText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  const JournalNumberText({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 44,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}
