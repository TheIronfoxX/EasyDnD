// Tema de EasyDnD (Etapa 6; estética "pergamino oscuro" en 8b).
//
// Reemplaza el andamio de la Etapa 1. La fuente de verdad de los colores
// es [AppPalette]; el acento (primary/secondary) y la familia tipográfica
// los elige el jugador vía [SkinController]. Material 3 arma el resto de
// la paleta a partir del acento con `ColorScheme.fromSeed`, y después
// pisamos las superficies con nuestros roles para conservar el look de
// panel cálido.
//
// La 8b suma la capa "pergamino": tarjetas con borde gastado, campos
// rellenos, diálogos y snackbars con el mismo tratamiento, y títulos con
// algo de tracking para que la serif respire. Todo sigue saliendo de la
// paleta y del acento; acá no hay colores sueltos.
//
// Regla de siempre: los widgets NO hardcodean colores ni fuentes. Leen
// `Theme.of(context)` o `context.appColors` y este archivo decide.

import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'design_tokens.dart';
import 'font_presets.dart';
import 'theme_presets.dart';

class AppTheme {
  AppTheme._(); // clase estática: no se instancia.

  /// Acento de fábrica: el oro sepia de la app vieja. Es el valor inicial
  /// del skin hasta que el jugador elija otro.
  static const Color defaultAccent = Color(0xFFC9A227);

  /// Modo claro: siempre el tema Pergamino.
  static ThemeData light({
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
  }) => build(
    brightness: Brightness.light,
    accent: accent,
    fontPreset: fontPreset,
  );

  /// Modo oscuro: Grimorio salvo que se pida otro tema oscuro.
  static ThemeData dark({
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
    AppThemePreset preset = AppThemePreset.defaultDark,
  }) => build(preset: preset, accent: accent, fontPreset: fontPreset);

  /// Tema completo para un preset del catálogo, un acento y una
  /// tipografía. Sin [preset] se usa el de fábrica de [brightness]
  /// (Grimorio u Pergamino); sin [accent], el acento de firma del tema.
  static ThemeData build({
    Brightness? brightness,
    AppThemePreset? preset,
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
  }) {
    final resolved =
        preset ?? AppThemePreset.forBrightness(brightness ?? Brightness.dark);
    final themeBrightness = resolved.brightness;
    final palette = resolved.palette;
    final tactical = resolved.tactical;
    final accentColor = accent ?? resolved.accent;

    // El acento lo puede elegir el jugador: no podemos confiar en el
    // onPrimary que inventa el seed. Lo resolvemos por contraste real.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    // El acento manda en primary/secondary; las superficies y textos
    // salen de la paleta semántica, no del algoritmo de M3.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: themeBrightness,
        ).copyWith(
          primary: accentColor,
          onPrimary: onAccent,
          secondary: accentColor,
          onSecondary: onAccent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceElevated,
          surfaceContainerHighest: palette.surfaceElevated,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.border,
          outlineVariant: palette.border,
          error: palette.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: themeBrightness,
      colorScheme: scheme,
    );

    final hairline = BorderSide(color: palette.border);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    const buttonText = TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: hairline,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: hairline),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
          side: hairline,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surfaceElevated.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: hairline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentColor.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accentColor : palette.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? accentColor : palette.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: tactical.metalBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceElevated.withValues(alpha: 0.55),
        selectedColor: accentColor.withValues(alpha: 0.22),
        checkmarkColor: accentColor,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accentColor,
        unselectedLabelColor: palette.textSecondary,
        indicatorColor: accentColor,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: palette.border,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        subtitleTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 12.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: palette.surfaceElevated,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tactical.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: tactical.metalBorder),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      dividerColor: palette.border,
      extensions: [AppThemeColors.fromPalette(palette), tactical],
      textTheme: _typography(base.textTheme, fontPreset).apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
    );
  }

  /// Aplica el preset tipográfico: primero la familia de cuerpo a todo
  /// el TextTheme, después pisa los títulos con la familia de display
  /// (en "Diario", Cinzel arriba e Inter abajo). `null` en cualquiera de
  /// las dos significa la familia por defecto de la plataforma.
  ///
  /// Los títulos llevan un poco de tracking: la serif gana aire y se lee
  /// como grabado en piedra, que es la intención del look pergamino.
  static TextTheme _typography(TextTheme base, FontPreset preset) {
    final withBody = base.apply(fontFamily: preset.bodyFamily);

    TextStyle? display(TextStyle? style, {double tracking = 0.4}) => style
        ?.copyWith(fontFamily: preset.displayFamily, letterSpacing: tracking);

    return withBody.copyWith(
      displayLarge: display(withBody.displayLarge),
      displayMedium: display(withBody.displayMedium),
      displaySmall: display(withBody.displaySmall),
      headlineLarge: display(withBody.headlineLarge),
      headlineMedium: display(withBody.headlineMedium),
      headlineSmall: display(withBody.headlineSmall),
      titleLarge: display(withBody.titleLarge, tracking: 0.3),
      titleMedium: display(withBody.titleMedium, tracking: 0.3),
      titleSmall: display(withBody.titleSmall, tracking: 0.3),
    );
  }
}
