// Paleta táctica (rework estético): tokens semánticos de JUEGO.
//
// [AppThemeColors] describe la estructura (fondo, superficie, tinta);
// esta extensión describe el significado en mesa: qué color es un arma,
// un conjuro, una habilidad activa, una curación o un daño, más el
// "metal" de los bordes, la superficie elevada de las tarjetas y el
// degradado de las cabeceras.
//
// Cada tema del catálogo ([AppThemePreset]) trae su propia instancia,
// así una tarjeta de conjuro es violeta en Grimorio y azul hielo en
// Forja Arcana sin que el widget se entere. Los widgets la leen con
// `context.tactical`.

import 'package:flutter/material.dart';

import 'theme_presets.dart';

@immutable
class TacticalPalette extends ThemeExtension<TacticalPalette> {
  const TacticalPalette({
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
  });

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

  /// Borde "metálico" de tarjetas e instrumentos.
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

  /// Degradado de cabecera listo para un BoxDecoration.
  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerEnd],
  );

  @override
  TacticalPalette copyWith({
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
  }) {
    return TacticalPalette(
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
    );
  }

  @override
  TacticalPalette lerp(ThemeExtension<TacticalPalette>? other, double t) {
    if (other is! TacticalPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return TacticalPalette(
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
    );
  }
}

/// Azúcar sintáctico: `context.tactical.spell`.
///
/// Si el árbol no instala la extensión (un MaterialApp pelado, como en
/// algunos tests) cae a la paleta de fábrica del brillo actual en vez de
/// reventar.
extension TacticalPaletteX on BuildContext {
  TacticalPalette get tactical {
    final theme = Theme.of(this);
    return theme.extension<TacticalPalette>() ??
        AppThemePreset.forBrightness(theme.brightness).tactical;
  }
}
