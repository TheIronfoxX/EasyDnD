// Catálogo de skins tácticas (rework estético): seis temas con
// personalidad propia.
//
// Un tema es un paquete completo: la paleta estructural ([AppPalette]) y
// los tokens de skin ([TacticalThemeTokens]): colores de juego, geometría
// de tarjetas y botones, grosor de borde, sombra, trama de fondo, forma
// de los pips y tipografía de cabeceras. El color principal del tema se
// usa mientras el jugador no haya elegido un acento propio en Apariencia.
//
// Contrato con el modo claro/oscuro: "Pergamino" ES el modo claro y los
// otros cinco son oscuros. El toggle de siempre alterna entre Pergamino
// y el último tema oscuro elegido (ver SkinController).

import 'package:flutter/material.dart';
import 'app_fonts.dart';

import 'app_palette.dart';
import 'tactical_theme_tokens.dart';

enum AppThemePreset {
  grimorio(
    id: 'grimorio',
    label: 'Grimorio',
    tagline:
        'Obsidiana profunda, latón y oro viejo. Esquinas de filete fino y marco de códice.',
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    tactical: TacticalThemeTokens(
      primary: Color(0xFFC9A227),
      weapon: Color(0xFFDB955C),
      spell: Color(0xFFAA94E8),
      ability: Color(0xFF5FBBA7),
      heal: Color(0xFF86B56B),
      damage: Color(0xFFDD6450),
      metalBorder: Color(0xFF5C4B2D),
      metalHighlight: Color(0xFFE9CB6E),
      surfaceRaised: Color(0xFF2B2318),
      headerStart: Color(0xFF30260F),
      headerEnd: Color(0xFF14110C),
      coinPlatinum: Color(0xFFCBD5DE),
      coinGold: Color(0xFFDDB33C),
      coinElectrum: Color(0xFFBCC7A2),
      coinSilver: Color(0xFFAEB7BF),
      coinCopper: Color(0xFFC77E4C),
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      insetShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      buttonShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      borderWidth: 1.0,
      shadowStyle: ShadowStyle.softWarm,
      backgroundPattern: BackgroundPatternStyle.codexFrame,
      pipShape: PipShape.circle,
      headerFont: HeaderFontStyle(
        family: AppFonts.cinzel,
        letterSpacing: 0.3,
        weight: FontWeight.w700,
      ),
    ),
  ),
  pergamino(
    id: 'pergamino',
    label: 'Pergamino',
    tagline:
        'Pergamino cálido, tinta sepia y cobre. Viñeta suave y pauta tenue.',
    brightness: Brightness.light,
    palette: AppPalette.light,
    tactical: TacticalThemeTokens(
      primary: Color(0xFF9A5B24),
      weapon: Color(0xFF8C4F2B),
      spell: Color(0xFF6A4EA8),
      ability: Color(0xFF2C776F),
      heal: Color(0xFF4A7434),
      damage: Color(0xFFA93A2B),
      metalBorder: Color(0xFFB99C68),
      metalHighlight: Color(0xFFFFFFFF),
      surfaceRaised: Color(0xFFFFFBF2),
      headerStart: Color(0xFFE9D9B8),
      headerEnd: Color(0xFFF6EEDC),
      coinPlatinum: Color(0xFF75828F),
      coinGold: Color(0xFFA07A10),
      coinElectrum: Color(0xFF76855A),
      coinSilver: Color(0xFF747D86),
      coinCopper: Color(0xFF9A5A2E),
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      insetShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      buttonShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      borderWidth: 1.0,
      shadowStyle: ShadowStyle.softWarm,
      backgroundPattern: BackgroundPatternStyle.parchmentRules,
      pipShape: PipShape.circle,
      headerFont: HeaderFontStyle(
        family: AppFonts.cinzel,
        letterSpacing: 0.2,
        weight: FontWeight.w600,
      ),
    ),
  ),
  veloAstral(
    id: 'velo_astral',
    label: 'Velo Astral',
    tagline:
        'Amatista vibrante sobre índigo profundo. Cristal tallado y constelaciones.',
    brightness: Brightness.dark,
    palette: AppPalette.astral,
    tactical: TacticalThemeTokens(
      primary: Color(0xFFB366FF),
      weapon: Color(0xFFFFB86B),
      spell: Color(0xFF8FA8FF),
      ability: Color(0xFF4FE0C8),
      heal: Color(0xFF8BE36F),
      damage: Color(0xFFFF6F8F),
      metalBorder: Color(0xFF5A4AA8),
      metalHighlight: Color(0xFFD6B2FF),
      surfaceRaised: Color(0xFF2A2158),
      headerStart: Color(0xFF35246B),
      headerEnd: Color(0xFF100B24),
      coinPlatinum: Color(0xFFD9D4F0),
      coinGold: Color(0xFFE3BE55),
      coinElectrum: Color(0xFFC4CBA9),
      coinSilver: Color(0xFFB9B6D0),
      coinCopper: Color(0xFFD08A5A),
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
      ),
      insetShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
          topRight: Radius.circular(3),
          bottomLeft: Radius.circular(3),
        ),
      ),
      buttonShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
      ),
      borderWidth: 1.0,
      shadowStyle: ShadowStyle.hudGlow,
      backgroundPattern: BackgroundPatternStyle.constellations,
      pipShape: PipShape.star,
      headerFont: HeaderFontStyle(
        family: AppFonts.cinzel,
        letterSpacing: 0.8,
        weight: FontWeight.w600,
      ),
    ),
  ),
  forjaArcana(
    id: 'forja_arcana',
    label: 'Forja Arcana',
    tagline:
        'Azul pizarra abisal, acero frío y cian etéreo. Biseles y retícula técnica.',
    brightness: Brightness.dark,
    palette: AppPalette.forge,
    tactical: TacticalThemeTokens(
      primary: Color(0xFF4FD8E8),
      weapon: Color(0xFFAEC0D4),
      spell: Color(0xFF93A5FF),
      ability: Color(0xFFF0BA5C),
      heal: Color(0xFF6FD3A0),
      damage: Color(0xFFF0766A),
      metalBorder: Color(0xFF41576E),
      metalHighlight: Color(0xFFA2EDF6),
      surfaceRaised: Color(0xFF213041),
      headerStart: Color(0xFF14303F),
      headerEnd: Color(0xFF0D141D),
      coinPlatinum: Color(0xFFD3DEE8),
      coinGold: Color(0xFFE0BA4A),
      coinElectrum: Color(0xFFBFCBA8),
      coinSilver: Color(0xFFB2BCC6),
      coinCopper: Color(0xFFCB8455),
      cardShape: BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      insetShape: BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(7)),
      ),
      buttonShape: BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      borderWidth: 1.2,
      shadowStyle: ShadowStyle.hudGlow,
      backgroundPattern: BackgroundPatternStyle.astrolabeGrid,
      pipShape: PipShape.diamond,
      headerFont: HeaderFontStyle(
        family: AppFonts.inter,
        letterSpacing: 1.6,
        weight: FontWeight.w700,
      ),
    ),
  ),
  sangreYHierro(
    id: 'sangre_y_hierro',
    label: 'Sangre y Hierro',
    tagline:
        'Carbón volcánico, hierro templado y carmesí. Bordes gruesos y sombra dura.',
    brightness: Brightness.dark,
    palette: AppPalette.blood,
    tactical: TacticalThemeTokens(
      primary: Color(0xFFE5534B),
      weapon: Color(0xFFBCC3CB),
      spell: Color(0xFFC890E2),
      ability: Color(0xFFF0A63E),
      heal: Color(0xFF93B56B),
      damage: Color(0xFFFF6A55),
      metalBorder: Color(0xFF5E4743),
      metalHighlight: Color(0xFFF3AF52),
      surfaceRaised: Color(0xFF2E2221),
      headerStart: Color(0xFF3F1B18),
      headerEnd: Color(0xFF151010),
      coinPlatinum: Color(0xFFCFD6DC),
      coinGold: Color(0xFFE0B040),
      coinElectrum: Color(0xFFBEC5A0),
      coinSilver: Color(0xFFB3B8BD),
      coinCopper: Color(0xFFCE7F4E),
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      insetShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      buttonShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      borderWidth: 1.8,
      shadowStyle: ShadowStyle.hardMartial,
      backgroundPattern: BackgroundPatternStyle.forgedDiagonal,
      pipShape: PipShape.square,
      headerFont: HeaderFontStyle(
        family: AppFonts.inter,
        letterSpacing: 0.8,
        weight: FontWeight.w800,
      ),
    ),
  ),
  sendaSilvestre(
    id: 'senda_silvestre',
    label: 'Senda Silvestre',
    tagline:
        'Bosque nocturno, corteza oscura y esmeralda. Píldoras y nervaduras orgánicas.',
    brightness: Brightness.dark,
    palette: AppPalette.wild,
    tactical: TacticalThemeTokens(
      primary: Color(0xFF52C78E),
      weapon: Color(0xFFCDAA70),
      spell: Color(0xFF84BAEA),
      ability: Color(0xFFE6D58A),
      heal: Color(0xFF7CD69B),
      damage: Color(0xFFE2705A),
      metalBorder: Color(0xFF4C5E40),
      metalHighlight: Color(0xFFE8D992),
      surfaceRaised: Color(0xFF233225),
      headerStart: Color(0xFF1B3626),
      headerEnd: Color(0xFF0E1510),
      coinPlatinum: Color(0xFFCDD8D4),
      coinGold: Color(0xFFDDBB52),
      coinElectrum: Color(0xFFC0CCA2),
      coinSilver: Color(0xFFAFBAB6),
      coinCopper: Color(0xFFC88454),
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      insetShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      buttonShape: StadiumBorder(),
      borderWidth: 1.2,
      shadowStyle: ShadowStyle.softWarm,
      backgroundPattern: BackgroundPatternStyle.organicVeins,
      pipShape: PipShape.leaf,
      headerFont: HeaderFontStyle(
        family: AppFonts.cinzel,
        letterSpacing: 0.3,
        weight: FontWeight.w500,
      ),
    ),
  );

  const AppThemePreset({
    required this.id,
    required this.label,
    required this.tagline,
    required this.brightness,
    required this.palette,
    required this.tactical,
  });

  /// Identificador estable para persistir (no cambia si cambia el label).
  final String id;
  final String label;
  final String tagline;
  final Brightness brightness;
  final AppPalette palette;

  final TacticalThemeTokens tactical;

  /// Color principal del tema: el `primary` mientras el jugador no elija
  /// un acento propio.
  Color get accent => tactical.primary;

  bool get isDark => brightness == Brightness.dark;

  /// Tema oscuro de fábrica (y destino de cualquier id desconocido).
  static const AppThemePreset defaultDark = grimorio;

  /// El único tema claro: es lo que significa "modo claro".
  static const AppThemePreset defaultLight = pergamino;

  static AppThemePreset forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? defaultDark : defaultLight;

  /// Resuelve un id guardado; null si no existe en este build.
  static AppThemePreset? byId(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
