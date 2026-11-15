// Catálogo de temas (rework estético): cinco paletas curadas.
//
// Un tema es un paquete completo: la paleta estructural ([AppPalette]),
// los tokens de juego ([TacticalPalette]) y un acento de firma. El
// jugador elige el tema en el selector de muestras; el acento de firma
// se usa mientras no haya elegido uno propio en Apariencia.
//
// Contrato con el modo claro/oscuro: "Pergamino" ES el modo claro y los
// otros cuatro son oscuros. El toggle de siempre alterna entre Pergamino
// y el último tema oscuro elegido (ver SkinController).

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'tactical_palette.dart';

enum AppThemePreset {
  grimorio(
    id: 'grimorio',
    label: 'Grimorio',
    tagline: 'Obsidiana profunda, bronce oscuro y oro viejo.',
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    accent: Color(0xFFC9A227),
    tactical: TacticalPalette(
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
    ),
  ),
  pergamino(
    id: 'pergamino',
    label: 'Pergamino',
    tagline: 'Pergamino cálido, tinta sepia y cobre oscuro.',
    brightness: Brightness.light,
    palette: AppPalette.light,
    accent: Color(0xFF9A5B24),
    tactical: TacticalPalette(
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
    ),
  ),
  forjaArcana(
    id: 'forja_arcana',
    label: 'Forja Arcana',
    tagline: 'Azul pizarra abisal, acero frío y cian etéreo.',
    brightness: Brightness.dark,
    palette: AppPalette.forge,
    accent: Color(0xFF4FD8E8),
    tactical: TacticalPalette(
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
    ),
  ),
  sangreYHierro(
    id: 'sangre_y_hierro',
    label: 'Sangre y Hierro',
    tagline: 'Carbón volcánico, hierro templado, carmesí y ámbar.',
    brightness: Brightness.dark,
    palette: AppPalette.blood,
    accent: Color(0xFFE5534B),
    tactical: TacticalPalette(
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
    ),
  ),
  sendaSilvestre(
    id: 'senda_silvestre',
    label: 'Senda Silvestre',
    tagline: 'Bosque nocturno, corteza oscura, esmeralda y oro pálido.',
    brightness: Brightness.dark,
    palette: AppPalette.wild,
    accent: Color(0xFF52C78E),
    tactical: TacticalPalette(
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
    ),
  );

  const AppThemePreset({
    required this.id,
    required this.label,
    required this.tagline,
    required this.brightness,
    required this.palette,
    required this.accent,
    required this.tactical,
  });

  /// Identificador estable para persistir (no cambia si cambia el label).
  final String id;
  final String label;
  final String tagline;
  final Brightness brightness;
  final AppPalette palette;

  /// Acento de firma: el `primary` del tema mientras el jugador no elija
  /// un color propio.
  final Color accent;
  final TacticalPalette tactical;

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
