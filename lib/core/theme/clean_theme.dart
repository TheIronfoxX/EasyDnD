// Tema limpio (rework de interfaz para novatos).
//
// Un único diseño base que el jugador ajusta en el editor de Ajustes con
// cuatro mandos independientes:
//   - modo claro u oscuro (decide el fondo: neutros fijos, no dependen
//     de nada más),
//   - forma ([CleanThemeStyle]: la silueta de tarjetas y botones),
//   - color principal (el acento),
//   - color secundario (magia, ranuras y detalles; con recomendaciones
//     derivadas del principal en [SecondaryColors]).
// Tipografía y fondo liso sin trama son los mismos siempre. El catálogo
// viejo de presets y los temas propios siguen en el código pero no se
// ofrecen (ver ADR-0007).
//
// Se monta sobre los mismos [AppPalette] y [TacticalThemeTokens] que el
// resto de temas para que las pantallas que todavía leen
// `context.tactical` (colores de rol, formas) sigan funcionando.

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_palette.dart';
import 'clean_shape.dart';
import 'design_tokens.dart';
import 'tactical_theme_tokens.dart';
import 'theme_style_tokens.dart';

/// Las tres formas que ofrece el editor de Ajustes. Solo cambian la
/// silueta; los colores se eligen aparte. [limpio] es la de fábrica.
enum CleanThemeStyle {
  limpio(
    id: 'limpio',
    label: 'Limpio',
    tagline: 'Muy redondeado, botones en píldora.',
  ),
  grimorio(
    id: 'grimorio',
    label: 'Grimorio',
    tagline: 'Esquinas rectas con filete fino, como un libro.',
    cornerScale: 0.4,
    outlined: true,
  ),
  escarcha(
    id: 'escarcha',
    label: 'Escarcha',
    tagline: 'Esquinas talladas en diagonal, como cristal.',
    cornerScale: 0.6,
    beveled: true,
  );

  const CleanThemeStyle({
    required this.id,
    required this.label,
    required this.tagline,
    this.cornerScale = 1.0,
    this.beveled = false,
    this.outlined = false,
  });

  /// Identificador estable para persistir.
  final String id;
  final String label;
  final String tagline;

  /// Silueta: escala de radios (1 = Limpio), esquinas en bisel y filete
  /// fino en las tarjetas.
  final double cornerScale;
  final bool beveled;
  final bool outlined;

  static const CleanThemeStyle defaultStyle = limpio;

  /// Extensión de forma para ese modo (el filete toma el borde neutro).
  CleanShape shape(Brightness b) => CleanShape(
    cornerScale: cornerScale,
    beveled: beveled,
    outline: outlined ? BorderSide(color: CleanTheme.palette(b).border) : null,
  );

  /// Resuelve un id guardado; cualquier id desconocido cae al de fábrica.
  static CleanThemeStyle byId(String? id) {
    for (final style in values) {
      if (style.id == id) return style;
    }
    return defaultStyle;
  }
}

/// Recomendaciones de color secundario a partir del principal: armonías
/// clásicas de la rueda de color, con la luminosidad ajustada al modo
/// para que se lean bien sobre el fondo.
abstract final class SecondaryColors {
  /// Giros de tono (en grados) de cada recomendación, en orden de
  /// preferencia: complementario, análogos y tríada.
  static const List<({String label, double shift})> harmonies = [
    (label: 'Complementario', shift: 180),
    (label: 'Análogo cálido', shift: -35),
    (label: 'Análogo frío', shift: 35),
    (label: 'Tríada', shift: 120),
    (label: 'Tríada opuesta', shift: 240),
  ];

  static List<({String label, Color color})> recommend(
    Color primary,
    Brightness brightness,
  ) => [
    for (final h in harmonies)
      (label: h.label, color: _shift(primary, h.shift, brightness)),
  ];

  /// La primera recomendación: el secundario mientras el jugador no
  /// elija uno.
  static Color auto(Color primary, Brightness brightness) =>
      _shift(primary, harmonies.first.shift, brightness);

  static Color _shift(Color primary, double degrees, Brightness b) {
    final hsl = HSLColor.fromColor(primary);
    final hue = (hsl.hue + degrees) % 360;
    // Un principal gris (saturación ~0) no tiene tono que girar: se le
    // da algo de color para que el secundario se distinga.
    final saturation = hsl.saturation.clamp(0.45, 0.85).toDouble();
    final lightness = b == Brightness.dark ? 0.66 : 0.42;
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }
}

abstract final class CleanTheme {
  /// Color principal de fábrica: rojo señal.
  static const Color defaultAccent = Color(0xFFE5242C);

  // Neutros fijos (estilo Nothing): negro/blanco y grises. El fondo solo
  // depende del modo claro/oscuro.
  static const AppPalette darkPalette = AppPalette(
    background: Color(0xFF121316),
    surface: Color(0xFF1B1D22),
    surfaceElevated: Color(0xFF262930),
    border: Color(0xFF33363F),
    textPrimary: Color(0xFFECEDF0),
    textSecondary: Color(0xFF9A9DA6),
    danger: Color(0xFFFF3B30),
    success: Color(0xFF4CD964),
  );

  static const AppPalette lightPalette = AppPalette(
    background: Color(0xFFF4F3F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEAE8E3),
    border: Color(0xFFDAD7D0),
    textPrimary: Color(0xFF1B1C1F),
    textSecondary: Color(0xFF6A6C73),
    danger: Color(0xFFD71921),
    success: Color(0xFF1F8F3A),
  );

  static AppPalette palette(Brightness b) =>
      b == Brightness.dark ? darkPalette : lightPalette;

  static const _round16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _round12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
  );

  /// Tokens planos: sin degradados, filos de luz, franjas, marcos ni
  /// tramas de fondo. Los colores de rol se conservan (daño, curación,
  /// arma...) porque comunican; el de conjuro es el [secondary] del
  /// jugador.
  static TacticalThemeTokens tokens(
    Brightness b,
    Color accent,
    Color secondary,
  ) {
    final dark = b == Brightness.dark;
    final p = palette(b);
    return TacticalThemeTokens(
      primary: accent,
      weapon: dark ? const Color(0xFFE8875A) : const Color(0xFFB4532A),
      spell: secondary,
      ability: dark ? const Color(0xFF4FB8A6) : const Color(0xFF1F7E70),
      heal: p.success,
      damage: p.danger,
      metalBorder: p.border,
      metalHighlight: p.surface,
      surfaceRaised: p.surface,
      headerStart: p.background,
      headerEnd: p.background,
      coinPlatinum: dark ? const Color(0xFFCBD5DE) : const Color(0xFF6B7883),
      coinGold: dark ? const Color(0xFFE2B843) : const Color(0xFF9C760E),
      coinElectrum: dark ? const Color(0xFFBCC7A2) : const Color(0xFF6E7D50),
      coinSilver: dark ? const Color(0xFFB4BCC4) : const Color(0xFF6E7780),
      coinCopper: dark ? const Color(0xFFD08A58) : const Color(0xFF9A5A2E),
      cardShape: _round16,
      insetShape: _round12,
      buttonShape: _round12,
      borderWidth: 1.0,
      shadowStyle: ShadowStyle.none,
      backgroundPattern: BackgroundPatternStyle.vellumDots,
      pipShape: PipShape.circle,
      headerFont: const HeaderFontStyle(
        family: AppFonts.inter,
        letterSpacing: 0,
        weight: FontWeight.w700,
      ),
      shapes: const ShapeTokens(
        dialogRadius: 16,
        sheetRadius: 20,
        inputRadius: AppRadii.md,
      ),
      background: const BackgroundTokens(patternOpacity: 0),
      cards: const CardTokens(
        gradient: CardGradientStyle.flat,
        highlightAlpha: 0,
        toneStripe: false,
        doubleBorder: false,
      ),
      components: const ComponentTokens(header: HeaderStyle.minimal),
    );
  }
}
