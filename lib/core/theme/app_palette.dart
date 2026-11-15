// Paleta semántica de EasyDnD (Etapa 6; dirección "pergamino" en 8b).
//
// Los nombres describen ROLES, no colores: background, surface,
// textPrimary... Así un skin futuro puede cambiar los valores sin que
// ningún widget se entere.
//
// La identidad es "pergamino oscuro": superficies cálidas (marrón/oliva
// apagado, no azul-grisáceo), tinta crema y bordes gastados, con el oro
// sepia del acento como firma. El modo claro es la cara de papel: crema
// envejecida y tinta marrón.
//
// danger y success se mantienen reconocibles en ambos modos (terracota y
// musgo), pero templados para no romper la calidez del conjunto.

import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;
  final Color success;

  static const AppPalette dark = AppPalette(
    background: Color(0xFF131009),
    surface: Color(0xFF1D1810),
    surfaceElevated: Color(0xFF282117),
    border: Color(0xFF3B3223),
    textPrimary: Color(0xFFEDE3D0),
    textSecondary: Color(0xFFA08F74),
    danger: Color(0xFFC9553F),
    success: Color(0xFF7FA968),
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFF3E9D5),
    surface: Color(0xFFFBF6EA),
    surfaceElevated: Color(0xFFEDE0C7),
    border: Color(0xFFD8C6A4),
    textPrimary: Color(0xFF2A2216),
    textSecondary: Color(0xFF6D5D45),
    danger: Color(0xFFB23E2E),
    success: Color(0xFF4F7A38),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
