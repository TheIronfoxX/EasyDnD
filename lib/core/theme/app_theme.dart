// Tema de EasyDnD (Etapa 6): tokens de diseño + paleta semántica.
//
// Reemplaza el andamio de la Etapa 1. La fuente de verdad de los colores
// es [AppPalette]; el acento (primary/secondary) lo elige el jugador vía
// [SkinController]. Material 3 arma el resto de la paleta a partir del
// acento con `ColorScheme.fromSeed`, y después pisamos las superficies
// con nuestros roles para conservar el look de panel táctico.
//
// Regla de siempre: los widgets NO hardcodean colores. Leen
// `Theme.of(context)` o `context.appColors` y este archivo decide.

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._(); // clase estática: no se instancia.

  /// Acento de fábrica: el sepia de la app vieja. Es el valor inicial
  /// del skin hasta que el jugador elija otro.
  static const Color defaultAccent = Color(0xFFC9A227);

  static ThemeData light({Color accent = defaultAccent}) =>
      build(brightness: Brightness.light, accent: accent);

  static ThemeData dark({Color accent = defaultAccent}) =>
      build(brightness: Brightness.dark, accent: accent);

  /// Tema completo para una luminosidad y un acento dados.
  static ThemeData build({
    required Brightness brightness,
    Color accent = defaultAccent,
  }) {
    final palette = AppPalette.of(brightness);

    // El acento lo elige el jugador: no podemos confiar en el onPrimary
    // que inventa el seed. Lo resolvemos por contraste real.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;

    // El acento manda en primary/secondary; las superficies y textos
    // salen de la paleta semántica, no del algoritmo de M3.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          secondary: accent,
          onSecondary: onAccent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          surfaceContainerHighest: palette.surfaceElevated,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.border,
          error: palette.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : palette.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? accent : palette.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      dividerColor: palette.border,
      extensions: [AppThemeColors.fromPalette(palette)],
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
    );
  }
}
