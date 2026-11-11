import 'package:flutter/material.dart';

/// Tema base de la Etapa 1: lo mínimo para que toda la app tenga una
/// apariencia coherente mientras se construye el resto del rework.
///
/// OJO: esto es andamio, no el design system. En la Etapa 6 este
/// archivo se reemplaza por el sistema real (tokens de color, espaciado
/// y tipografía, skins seleccionables y un ThemeExtension con los
/// colores de fase). Hasta ese momento rige una regla: los widgets NO
/// hardcodean colores — siempre salen de `Theme.of(context)`, para que
/// el rework de estética no requiera tocar pantallas (la lección del
/// modo claro roto de la app vieja).
class AppTheme {
  AppTheme._(); // clase estática: no se instancia.

  /// Azul muy oscuro que la app vieja usaba de fondo (AppColors.background).
  /// Sirve de semilla para que Material 3 genere la paleta completa en
  /// ambos modos — un solo lugar para cambiar el ADN cromático.
  static const Color _seed = Color(0xFF0A0E17);

  static ThemeData light() => _fromSeed(Brightness.light);
  static ThemeData dark() => _fromSeed(Brightness.dark);

  static ThemeData _fromSeed(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
    );
  }
}
