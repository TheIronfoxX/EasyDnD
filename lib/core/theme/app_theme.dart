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

import 'clean_theme.dart';

import 'app_palette.dart';
import 'app_theme_colors.dart';
import 'custom_theme.dart';
import 'app_fonts.dart';
import 'design_tokens.dart';
import 'font_presets.dart';
import 'tactical_theme_tokens.dart';
import 'theme_style_tokens.dart';
import 'theme_presets.dart';

class AppTheme {
  AppTheme._(); // clase estática: no se instancia.

  /// Acento de fábrica: el oro sepia de la app vieja. Es el valor inicial
  /// del skin hasta que el jugador elija otro.
  static const Color defaultAccent = Color(0xFFC9A227);

  /// Modo claro: Pergamino salvo que se pida otro tema claro.
  static ThemeData light({
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
    AppThemePreset preset = AppThemePreset.defaultLight,
  }) => build(preset: preset, accent: accent, fontPreset: fontPreset);

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
    return fromParts(
      brightness: resolved.brightness,
      palette: resolved.palette,
      tactical: resolved.tactical,
      accent: accent,
      fontPreset: fontPreset,
    );
  }

  /// Tema limpio: el único diseño de la app desde el rework para
  /// novatos. Fondo liso, tarjetas sin borde, Inter en todo y el acento
  /// del jugador ([defaultAccent] si no eligió).
  static ThemeData clean({required Brightness brightness, Color? accent}) {
    final color = accent ?? defaultAccent;
    final palette = CleanTheme.palette(brightness);
    final base = fromParts(
      brightness: brightness,
      palette: palette,
      tactical: CleanTheme.tokens(brightness, color),
      accent: color,
      fontPreset: FontPresets.table,
    );
    const noSide = BorderSide.none;
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(shape: const Border()),
      cardTheme: base.cardTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: noSide,
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: palette.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: palette.surface,
        indicatorShape: const StadiumBorder(),
      ),
    );
  }

  /// Tema de un tema propio del editor ([CustomTheme]).
  static ThemeData fromCustom(
    CustomTheme custom, {
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
  }) => fromParts(
    brightness: custom.brightness,
    palette: custom.palette,
    tactical: custom.tactical,
    accent: accent,
    fontPreset: fontPreset,
  );

  /// Tema a partir de sus piezas: brillo, paleta estructural y tokens de
  /// skin. Es el camino común de los temas del catálogo y de los propios.
  /// Sin [accent] se usa el color principal de los tokens.
  static ThemeData fromParts({
    required Brightness brightness,
    required AppPalette palette,
    required TacticalThemeTokens tactical,
    Color? accent,
    FontPreset fontPreset = FontPresets.defaultPreset,
  }) {
    final themeBrightness = brightness;
    final accentColor = accent ?? tactical.primary;

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
    // La forma de botones y chips la decide la skin (esquinas, biseles,
    // cristal asimétrico, píldora...).
    final buttonShape = tactical.buttonShape;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg * tactical.density.scale,
      vertical: AppSpacing.md * tactical.density.scale,
    );
    const buttonText = TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final shapes = tactical.shapes;
    RoundedRectangleBorder rounded(double r) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: hairline,
    );
    final cardShape = rounded(AppRadii.lg);
    final dialogShape = rounded(shapes.dialogRadius);

    // Los botones rellenos cambian de estructura según el tema: sólido,
    // tonal, solo contorno o planos.
    final filledStyle = switch (tactical.components.button) {
      ButtonStyleKind.filled => ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(buttonText),
        padding: WidgetStatePropertyAll(buttonPadding),
      ),
      ButtonStyleKind.tonal => ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(buttonText),
        padding: WidgetStatePropertyAll(buttonPadding),
        backgroundColor: WidgetStatePropertyAll(
          accentColor.withValues(alpha: 0.20),
        ),
        foregroundColor: WidgetStatePropertyAll(accentColor),
        elevation: const WidgetStatePropertyAll(0),
      ),
      ButtonStyleKind.outlined => ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(buttonText),
        padding: WidgetStatePropertyAll(buttonPadding),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(accentColor),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(
          BorderSide(color: accentColor, width: tactical.borderWidth),
        ),
      ),
      ButtonStyleKind.flat => ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(buttonText),
        padding: WidgetStatePropertyAll(buttonPadding),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(accentColor),
        elevation: const WidgetStatePropertyAll(0),
      ),
    };

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
        elevation: shapes.overlayElevation,
        shape: dialogShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(shapes.sheetRadius),
          ),
          side: hairline,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: shapes.overlayElevation,
        shape: dialogShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surfaceElevated.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.inputRadius),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.inputRadius),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.inputRadius),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: shapes.overlayElevation,
        shape: rounded(shapes.inputRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentColor.withValues(alpha: 0.18),
        indicatorShape: buttonShape,
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
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              shape: tactical.buttonShape,
              textStyle: buttonText,
              side: BorderSide(
                color: tactical.metalBorder,
                width: tactical.borderWidth,
              ),
              padding: buttonPadding,
            ).copyWith(
              // Secundarios tonales: relleno tenue del acento.
              backgroundColor:
                  tactical.components.secondaryButton == ButtonStyleKind.tonal
                  ? WidgetStatePropertyAll(accentColor.withValues(alpha: 0.16))
                  : null,
              foregroundColor:
                  tactical.components.secondaryButton == ButtonStyleKind.tonal
                  ? WidgetStatePropertyAll(accentColor)
                  : null,
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceElevated.withValues(alpha: 0.55),
        selectedColor: accentColor.withValues(alpha: 0.22),
        checkmarkColor: accentColor,
        side: BorderSide(color: palette.border, width: tactical.borderWidth),
        shape: tactical.buttonShape,
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
          borderRadius: BorderRadius.circular(shapes.tooltipRadius),
          border: Border.all(color: tactical.metalBorder),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.fabRadius),
        ),
      ),
      dividerColor: palette.border,
      extensions: [AppThemeColors.fromPalette(palette), tactical],
      textTheme: _typography(base.textTheme, fontPreset, tactical.headerFont)
          .apply(
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
  static TextTheme _typography(
    TextTheme base,
    FontPreset preset,
    HeaderFontStyle header,
  ) {
    final withBody = base.apply(fontFamily: preset.bodyFamily);

    // La familia de cabeceras de la skin solo manda con el preset "Diario"
    // (display = Cinzel); "Mesa" y "Consola" son elección explícita del
    // jugador y se respetan. Tracking y peso valen siempre.
    final skinOwnsHeaders = preset.displayFamily == AppFonts.cinzel;

    TextStyle? display(TextStyle? style, {double extra = 0}) => style?.copyWith(
      fontFamily: skinOwnsHeaders ? header.family : preset.displayFamily,
      letterSpacing: header.letterSpacing + extra,
      fontWeight: header.weight,
    );

    return withBody.copyWith(
      displayLarge: display(withBody.displayLarge, extra: 0.1),
      displayMedium: display(withBody.displayMedium, extra: 0.1),
      displaySmall: display(withBody.displaySmall, extra: 0.1),
      headlineLarge: display(withBody.headlineLarge, extra: 0.1),
      headlineMedium: display(withBody.headlineMedium, extra: 0.1),
      headlineSmall: display(withBody.headlineSmall, extra: 0.1),
      titleLarge: display(withBody.titleLarge),
      titleMedium: display(withBody.titleMedium),
      titleSmall: display(withBody.titleSmall),
    );
  }
}
