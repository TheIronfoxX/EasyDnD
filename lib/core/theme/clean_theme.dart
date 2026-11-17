// Tema limpio (rework de interfaz para novatos).
//
// Un único diseño base: superficies lisas, sin bordes ni ornamentos,
// tipografía Inter en todo y un solo acento elegido por el jugador. Es lo
// que la app usa siempre; el catálogo de presets y los temas propios
// siguen en el código pero ya no construyen el tema (ver ADR-0006).
//
// Se monta sobre los mismos [AppPalette] y [TacticalThemeTokens] que el
// resto de temas para que las pantallas que todavía leen
// `context.tactical` (colores de rol, formas) sigan funcionando.

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_palette.dart';
import 'design_tokens.dart';
import 'tactical_theme_tokens.dart';
import 'theme_style_tokens.dart';

abstract final class CleanTheme {
  static const AppPalette darkPalette = AppPalette(
    background: Color(0xFF121316),
    surface: Color(0xFF1C1D21),
    surfaceElevated: Color(0xFF26282D),
    border: Color(0xFF2C2E34),
    textPrimary: Color(0xFFECEDEF),
    textSecondary: Color(0xFFA2A6AE),
    danger: Color(0xFFE5604F),
    success: Color(0xFF5DBB75),
  );

  static const AppPalette lightPalette = AppPalette(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDEFF2),
    border: Color(0xFFE2E4E8),
    textPrimary: Color(0xFF17191D),
    textSecondary: Color(0xFF5E636C),
    danger: Color(0xFFC6402F),
    success: Color(0xFF2F8A4A),
  );

  static AppPalette palette(Brightness b) =>
      b == Brightness.dark ? darkPalette : lightPalette;

  static const _round16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _round12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  /// Tokens planos: sin degradados, filos de luz, franjas, marcos ni
  /// tramas de fondo. Los colores de rol se conservan (daño, curación,
  /// conjuro...) porque comunican, no decoran.
  static TacticalThemeTokens tokens(Brightness b, Color accent) {
    final dark = b == Brightness.dark;
    final p = palette(b);
    return TacticalThemeTokens(
      primary: accent,
      weapon: dark ? const Color(0xFFE8875A) : const Color(0xFFB4532A),
      spell: dark ? const Color(0xFF9C8CF0) : const Color(0xFF5B48C2),
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
        dialogRadius: 20,
        sheetRadius: 24,
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
