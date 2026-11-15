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

  /// Grimorio (oscuro por defecto): obsidiana profunda y bronce oscuro.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF0F0D0A),
    surface: Color(0xFF19150F),
    surfaceElevated: Color(0xFF272016),
    border: Color(0xFF403524),
    textPrimary: Color(0xFFEFE5D2),
    textSecondary: Color(0xFFA99879),
    danger: Color(0xFFD2594A),
    success: Color(0xFF86B56B),
  );

  /// Pergamino (claro por defecto): papel cálido y tinta sepia.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF3E9D5),
    surface: Color(0xFFFBF6EA),
    surfaceElevated: Color(0xFFEDE0C7),
    border: Color(0xFFD3BF99),
    textPrimary: Color(0xFF2A2216),
    textSecondary: Color(0xFF6A5A42),
    danger: Color(0xFFA93A2B),
    success: Color(0xFF4A7434),
  );

  /// Forja Arcana: azul pizarra abisal y acero frío.
  static const AppPalette forge = AppPalette(
    background: Color(0xFF0A0F16),
    surface: Color(0xFF111923),
    surfaceElevated: Color(0xFF1B2633),
    border: Color(0xFF2D3D50),
    textPrimary: Color(0xFFE3ECF5),
    textSecondary: Color(0xFF8FA3BA),
    danger: Color(0xFFE56E62),
    success: Color(0xFF6FC89C),
  );

  /// Sangre y Hierro: carbón volcánico y hierro templado.
  static const AppPalette blood = AppPalette(
    background: Color(0xFF100C0C),
    surface: Color(0xFF1A1414),
    surfaceElevated: Color(0xFF271D1C),
    border: Color(0xFF43312F),
    textPrimary: Color(0xFFF1E5E0),
    textSecondary: Color(0xFFAB948E),
    danger: Color(0xFFFF6A55),
    success: Color(0xFF93B56B),
  );

  /// Senda Silvestre: bosque nocturno y corteza oscura.
  static const AppPalette wild = AppPalette(
    background: Color(0xFF0A100C),
    surface: Color(0xFF121A14),
    surfaceElevated: Color(0xFF1C281E),
    border: Color(0xFF304233),
    textPrimary: Color(0xFFE5EEDE),
    textSecondary: Color(0xFF95A78F),
    danger: Color(0xFFE2705A),
    success: Color(0xFF7CD69B),
  );

  /// Velo Astral: violeta noche / índigo profundo, texto lavanda suave.
  static const AppPalette astral = AppPalette(
    background: Color(0xFF0C0919),
    surface: Color(0xFF151030),
    surfaceElevated: Color(0xFF211A48),
    border: Color(0xFF3B3274),
    textPrimary: Color(0xFFE9E3FA),
    textSecondary: Color(0xFFA99FD0),
    danger: Color(0xFFFF6F8F),
    success: Color(0xFF72E3AE),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
