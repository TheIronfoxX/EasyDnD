// Tokens de skin táctica (rework estético): el paquete visual completo de
// un tema, más allá de la paleta.
//
// [AppThemeColors] describe la estructura (fondo, superficie, tinta);
// esta extensión describe el CARÁCTER de cada skin:
//   * colores de juego: arma, conjuro, habilidad, curación, daño, metal,
//     superficies elevadas, degradados de cabecera y monedas;
//   * geometría: forma de tarjetas y botones (OutlinedBorder), grosor de
//     borde y estilo de sombra;
//   * atmósfera: trama de fondo y forma de los indicadores de carga;
//   * tipografía de cabeceras.
//
// Cada preset de [AppThemePreset] trae su instancia; los widgets la leen
// con `context.tactical` y nunca deciden formas ni colores por su cuenta.

import 'package:flutter/material.dart';

import 'theme_presets.dart';

/// Trama de fondo atmosférica de una skin (ver TacticalScaffoldBackground).
enum BackgroundPatternStyle {
  /// Marco geométrico de códice: filete doble y esquinas ornamentales.
  codexFrame,

  /// Viñeta suave y líneas de pauta tenues de papel.
  parchmentRules,

  /// Constelaciones: estrellas sueltas unidas por trazos finos.
  constellations,

  /// Retícula técnica con círculos de astrolabio.
  astrolabeGrid,

  /// Trama diagonal forjada.
  forgedDiagonal,

  /// Nervaduras orgánicas.
  organicVeins,
}

/// Forma de los indicadores de carga (pips).
enum PipShape { circle, diamond, square, leaf, star }

/// Estilo de sombra de las tarjetas.
enum ShadowStyle {
  /// Difusa y cálida.
  softWarm,

  /// Brillo de HUD: halo del color principal.
  hudGlow,

  /// Dura y marcial: desplazada, sin difuminar.
  hardMartial,
}

/// Tipografía de cabeceras. [family] solo se aplica con el preset
/// tipográfico "Diario" (los otros presets del jugador mandan); el
/// tracking y el peso valen siempre.
@immutable
class HeaderFontStyle {
  const HeaderFontStyle({
    required this.family,
    required this.letterSpacing,
    required this.weight,
  });

  final String family;
  final double letterSpacing;
  final FontWeight weight;
}

@immutable
class TacticalThemeTokens extends ThemeExtension<TacticalThemeTokens> {
  const TacticalThemeTokens({
    required this.primary,
    required this.weapon,
    required this.spell,
    required this.ability,
    required this.heal,
    required this.damage,
    required this.metalBorder,
    required this.metalHighlight,
    required this.surfaceRaised,
    required this.headerStart,
    required this.headerEnd,
    required this.coinPlatinum,
    required this.coinGold,
    required this.coinElectrum,
    required this.coinSilver,
    required this.coinCopper,
    required this.cardShape,
    required this.insetShape,
    required this.buttonShape,
    required this.borderWidth,
    required this.shadowStyle,
    required this.backgroundPattern,
    required this.pipShape,
    required this.headerFont,
  });

  /// Color principal de la skin (el acento de firma).
  final Color primary;

  /// Armas y ataques físicos.
  final Color weapon;

  /// Conjuros y trucos.
  final Color spell;

  /// Habilidades activas no-conjuro (rasgos con recurso, maniobras).
  final Color ability;

  /// Curación y recuperación.
  final Color heal;

  /// Daño recibido o infligido, críticos en contra, pifias.
  final Color damage;

  /// Borde "metálico" o "místico" de tarjetas e instrumentos.
  final Color metalBorder;

  /// Brillo del canto superior de las tarjetas (iluminación tonal).
  final Color metalHighlight;

  /// Superficie elevada: el tope del degradado de una tarjeta.
  final Color surfaceRaised;

  /// Extremos del degradado de cabeceras (AppBar del HUD, portada).
  final Color headerStart;
  final Color headerEnd;

  /// Metales de la bolsa de monedas.
  final Color coinPlatinum;
  final Color coinGold;
  final Color coinElectrum;
  final Color coinSilver;
  final Color coinCopper;

  /// Forma de las tarjetas (sin borde: el borde lo pone [cardBorder]).
  final OutlinedBorder cardShape;

  /// Forma de los elementos internos (instrumentos, placas, celdas).
  final OutlinedBorder insetShape;

  /// Forma de botones y chips.
  final OutlinedBorder buttonShape;

  /// Grosor del borde de tarjetas e instrumentos.
  final double borderWidth;
  final ShadowStyle shadowStyle;
  final BackgroundPatternStyle backgroundPattern;
  final PipShape pipShape;
  final HeaderFontStyle headerFont;

  /// Degradado de cabecera listo para un BoxDecoration.
  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerEnd],
  );

  /// [cardShape] con el borde de la skin en el color dado.
  OutlinedBorder cardBorder(Color color, {double? width}) => cardShape.copyWith(
    side: BorderSide(color: color, width: width ?? borderWidth),
  );

  /// [insetShape] con borde.
  OutlinedBorder insetBorder(Color color, {double? width}) =>
      insetShape.copyWith(
        side: BorderSide(color: color, width: width ?? borderWidth),
      );

  /// [buttonShape] con borde.
  OutlinedBorder buttonBorder(Color color, {double? width}) =>
      buttonShape.copyWith(
        side: BorderSide(color: color, width: width ?? borderWidth),
      );

  /// Sombras de una tarjeta según el estilo de la skin.
  List<BoxShadow> cardShadows(Color shadow) => switch (shadowStyle) {
    ShadowStyle.softWarm => [
      BoxShadow(
        color: shadow.withValues(alpha: 0.18),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    ShadowStyle.hudGlow => [
      BoxShadow(
        color: primary.withValues(alpha: 0.20),
        blurRadius: 14,
        spreadRadius: -2,
      ),
    ],
    ShadowStyle.hardMartial => [
      BoxShadow(
        color: shadow.withValues(alpha: 0.55),
        offset: const Offset(3, 3),
      ),
    ],
  };

  @override
  TacticalThemeTokens copyWith({
    Color? primary,
    Color? weapon,
    Color? spell,
    Color? ability,
    Color? heal,
    Color? damage,
    Color? metalBorder,
    Color? metalHighlight,
    Color? surfaceRaised,
    Color? headerStart,
    Color? headerEnd,
    Color? coinPlatinum,
    Color? coinGold,
    Color? coinElectrum,
    Color? coinSilver,
    Color? coinCopper,
    OutlinedBorder? cardShape,
    OutlinedBorder? insetShape,
    OutlinedBorder? buttonShape,
    double? borderWidth,
    ShadowStyle? shadowStyle,
    BackgroundPatternStyle? backgroundPattern,
    PipShape? pipShape,
    HeaderFontStyle? headerFont,
  }) {
    return TacticalThemeTokens(
      primary: primary ?? this.primary,
      weapon: weapon ?? this.weapon,
      spell: spell ?? this.spell,
      ability: ability ?? this.ability,
      heal: heal ?? this.heal,
      damage: damage ?? this.damage,
      metalBorder: metalBorder ?? this.metalBorder,
      metalHighlight: metalHighlight ?? this.metalHighlight,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      headerStart: headerStart ?? this.headerStart,
      headerEnd: headerEnd ?? this.headerEnd,
      coinPlatinum: coinPlatinum ?? this.coinPlatinum,
      coinGold: coinGold ?? this.coinGold,
      coinElectrum: coinElectrum ?? this.coinElectrum,
      coinSilver: coinSilver ?? this.coinSilver,
      coinCopper: coinCopper ?? this.coinCopper,
      cardShape: cardShape ?? this.cardShape,
      insetShape: insetShape ?? this.insetShape,
      buttonShape: buttonShape ?? this.buttonShape,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowStyle: shadowStyle ?? this.shadowStyle,
      backgroundPattern: backgroundPattern ?? this.backgroundPattern,
      pipShape: pipShape ?? this.pipShape,
      headerFont: headerFont ?? this.headerFont,
    );
  }

  /// Los colores se interpolan; la geometría y los estilos discretos
  /// cambian a mitad de la transición (no hay "medio rombo").
  @override
  TacticalThemeTokens lerp(
    ThemeExtension<TacticalThemeTokens>? other,
    double t,
  ) {
    if (other is! TacticalThemeTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    final next = t >= 0.5;
    return TacticalThemeTokens(
      primary: mix(primary, other.primary),
      weapon: mix(weapon, other.weapon),
      spell: mix(spell, other.spell),
      ability: mix(ability, other.ability),
      heal: mix(heal, other.heal),
      damage: mix(damage, other.damage),
      metalBorder: mix(metalBorder, other.metalBorder),
      metalHighlight: mix(metalHighlight, other.metalHighlight),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      headerStart: mix(headerStart, other.headerStart),
      headerEnd: mix(headerEnd, other.headerEnd),
      coinPlatinum: mix(coinPlatinum, other.coinPlatinum),
      coinGold: mix(coinGold, other.coinGold),
      coinElectrum: mix(coinElectrum, other.coinElectrum),
      coinSilver: mix(coinSilver, other.coinSilver),
      coinCopper: mix(coinCopper, other.coinCopper),
      cardShape: next ? other.cardShape : cardShape,
      insetShape: next ? other.insetShape : insetShape,
      buttonShape: next ? other.buttonShape : buttonShape,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      shadowStyle: next ? other.shadowStyle : shadowStyle,
      backgroundPattern: next ? other.backgroundPattern : backgroundPattern,
      pipShape: next ? other.pipShape : pipShape,
      headerFont: next ? other.headerFont : headerFont,
    );
  }
}

/// Azúcar sintáctico: `context.tactical.spell`.
///
/// Si el árbol no instala la extensión (un MaterialApp pelado, como en
/// algunos tests) cae a los tokens de fábrica del brillo actual en vez
/// de reventar.
extension TacticalThemeTokensX on BuildContext {
  TacticalThemeTokens get tactical {
    final theme = Theme.of(this);
    return theme.extension<TacticalThemeTokens>() ??
        AppThemePreset.forBrightness(theme.brightness).tactical;
  }
}
