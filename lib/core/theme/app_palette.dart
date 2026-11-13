// Paleta semántica de EasyDnD (Etapa 6).
//
// Los nombres describen ROLES, no colores: background, surface,
// textPrimary... Así un skin futuro puede cambiar los valores sin que
// ningún widget se entere. Los valores oscuros son los de la app vieja
// ("panel táctico" azul-grisáceo); los claros son su contrapartida
// exacta para el modo día.
//
// danger y success se mantienen iguales en ambos modos: ya tienen
// contraste suficiente sobre fondo oscuro y claro.

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
    background: Color(0xFF0A0E17),
    surface: Color(0xFF171E28),
    surfaceElevated: Color(0xFF1F2733),
    border: Color(0xFF2A3441),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFF8C96A6),
    danger: Color(0xFFD9534F),
    success: Color(0xFF5CB88A),
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEFF1F4),
    border: Color(0xFFD9DEE5),
    textPrimary: Color(0xFF1A1D23),
    textSecondary: Color(0xFF5B6472),
    danger: Color(0xFFD9534F),
    success: Color(0xFF5CB88A),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
