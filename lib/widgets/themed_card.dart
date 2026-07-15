import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';

/// Tarjeta base "Panel Táctico": ya no es un wireframe con borde sólido.
/// Ahora simula cristal/metal pulido: el fondo se tiñe con un 5% del color
/// de acento sobre la superficie base, y en vez de un borde de 1.5px se usa
/// un resplandor (BoxShadow) muy difuminado y de baja opacidad alrededor de
/// la tarjeta, más un filo interior casi imperceptible para dar sensación
/// de profundidad. El accentColor llega por parámetro, así que jamás puede
/// ser const de verdad.
class ThemedCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const ThemedCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(16), // literal fijo, aquí sí vale const.
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // Fondo "cristal": la superficie base bañada con un 5% del acento.
        color: Color.alphaBlend(accentColor.withOpacity(0.05), context.appColors.surface),
        borderRadius: BorderRadius.circular(12),
        // Filo casi invisible, solo para separar el panel del fondo.
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
        boxShadow: [
          // Resplandor tecnológico del acento, muy difuminado.
          BoxShadow(
            color: accentColor.withOpacity(0.18),
            blurRadius: 22,
            spreadRadius: -2,
          ),
          // Sombra de profundidad hacia el fondo, para separar del resto del HUD.
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}