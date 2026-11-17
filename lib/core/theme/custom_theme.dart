// Tema propio del jugador (editor de temas).
//
// Un [CustomTheme] describe TODO lo que define un tema del catálogo
// ([AppThemePreset]): brillo, paleta estructural, tipografía de firma y
// cada token de [TacticalThemeTokens] (colores de juego, geometría,
// sombra, trama, pips, cabeceras, iconos, movimiento, densidad, fondo,
// tarjetas y componentes). Es inmutable y viaja a JSON plano para
// guardarse en SharedPreferences vía SkinController.
//
// Las formas (OutlinedBorder) se modelan como [ShapeSpec]: un tipo
// (redondeada, biselada, continua, píldora) y un radio por esquina. Así
// se editan con controles simples y se reconstruyen sin perder las
// esquinas asimétricas de los temas que las usan.
//
// Los JSON viejos o incompletos caen a los valores del tema oscuro de
// fábrica campo por campo: un tema guardado nunca deja la app sin skin.

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_palette.dart';
import 'tactical_theme_tokens.dart';
import 'theme_presets.dart';
import 'theme_style_tokens.dart';

/// Tipo de forma de tarjetas, placas y botones.
enum ShapeKind { rounded, beveled, continuous, stadium }

/// Forma editable: tipo + radio por esquina (en sentido horario desde
/// arriba a la izquierda).
@immutable
class ShapeSpec {
  const ShapeSpec({
    this.kind = ShapeKind.rounded,
    this.topLeft = 10,
    this.topRight = 10,
    this.bottomRight = 10,
    this.bottomLeft = 10,
  });

  const ShapeSpec.all(this.kind, double radius)
    : topLeft = radius,
      topRight = radius,
      bottomRight = radius,
      bottomLeft = radius;

  final ShapeKind kind;
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  /// true si las cuatro esquinas miden lo mismo.
  bool get isUniform =>
      topLeft == topRight && topLeft == bottomRight && topLeft == bottomLeft;

  BorderRadius get _radius => BorderRadius.only(
    topLeft: Radius.circular(topLeft),
    topRight: Radius.circular(topRight),
    bottomRight: Radius.circular(bottomRight),
    bottomLeft: Radius.circular(bottomLeft),
  );

  OutlinedBorder toBorder() => switch (kind) {
    ShapeKind.rounded => RoundedRectangleBorder(borderRadius: _radius),
    ShapeKind.beveled => BeveledRectangleBorder(borderRadius: _radius),
    ShapeKind.continuous => ContinuousRectangleBorder(borderRadius: _radius),
    ShapeKind.stadium => const StadiumBorder(),
  };

  /// Lee la forma de un borde existente. Formas desconocidas caen a una
  /// redondeada de 10.
  static ShapeSpec fromBorder(OutlinedBorder border) {
    (ShapeKind, BorderRadiusGeometry)? parts = switch (border) {
      RoundedRectangleBorder(:final borderRadius) => (
        ShapeKind.rounded,
        borderRadius,
      ),
      BeveledRectangleBorder(:final borderRadius) => (
        ShapeKind.beveled,
        borderRadius,
      ),
      ContinuousRectangleBorder(:final borderRadius) => (
        ShapeKind.continuous,
        borderRadius,
      ),
      _ => null,
    };
    if (border is StadiumBorder) {
      return const ShapeSpec.all(ShapeKind.stadium, 999);
    }
    if (parts == null) return const ShapeSpec();
    final r = parts.$2.resolve(TextDirection.ltr);
    return ShapeSpec(
      kind: parts.$1,
      topLeft: r.topLeft.x,
      topRight: r.topRight.x,
      bottomRight: r.bottomRight.x,
      bottomLeft: r.bottomLeft.x,
    );
  }

  ShapeSpec copyWith({
    ShapeKind? kind,
    double? topLeft,
    double? topRight,
    double? bottomRight,
    double? bottomLeft,
  }) => ShapeSpec(
    kind: kind ?? this.kind,
    topLeft: topLeft ?? this.topLeft,
    topRight: topRight ?? this.topRight,
    bottomRight: bottomRight ?? this.bottomRight,
    bottomLeft: bottomLeft ?? this.bottomLeft,
  );

  /// Las cuatro esquinas al mismo radio.
  ShapeSpec withRadius(double r) =>
      copyWith(topLeft: r, topRight: r, bottomRight: r, bottomLeft: r);

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'tl': topLeft,
    'tr': topRight,
    'br': bottomRight,
    'bl': bottomLeft,
  };

  static ShapeSpec fromJson(Object? json, ShapeSpec fallback) {
    if (json is! Map) return fallback;
    double d(String k, double f) => (json[k] as num?)?.toDouble() ?? f;
    return ShapeSpec(
      kind: _enumByName(ShapeKind.values, json['kind'], fallback.kind),
      topLeft: d('tl', fallback.topLeft),
      topRight: d('tr', fallback.topRight),
      bottomRight: d('br', fallback.bottomRight),
      bottomLeft: d('bl', fallback.bottomLeft),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShapeSpec &&
      other.kind == kind &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode =>
      Object.hash(kind, topLeft, topRight, bottomRight, bottomLeft);
}

/// Curvas de animación que el editor ofrece, con nombre estable para el
/// JSON.
abstract final class ThemeCurves {
  static const Map<String, Curve> all = {
    'linear': Curves.linear,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'easeOutCubic': Curves.easeOutCubic,
    'easeInOutCubic': Curves.easeInOutCubic,
    'easeOutQuart': Curves.easeOutQuart,
    'easeOutQuint': Curves.easeOutQuint,
    'easeOutExpo': Curves.easeOutExpo,
    'easeInOutSine': Curves.easeInOutSine,
    'easeOutBack': Curves.easeOutBack,
    'elasticOut': Curves.elasticOut,
    'bounceOut': Curves.bounceOut,
  };

  static String nameOf(Curve curve, String fallback) {
    for (final e in all.entries) {
      if (identical(e.value, curve) || e.value == curve) return e.key;
    }
    return fallback;
  }

  static Curve byName(Object? name, Curve fallback) => all[name] ?? fallback;
}

/// Familias tipográficas empaquetadas que pueden ir en las cabeceras.
const List<String> kHeaderFontFamilies = [
  AppFonts.cinzel,
  AppFonts.inter,
  AppFonts.jetBrainsMono,
  AppFonts.uncialAntiqua,
  AppFonts.crimsonText,
  AppFonts.almendra,
];

@immutable
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.fontPresetId,
    required this.palette,
    required this.tactical,
  });

  final String id;
  final String name;
  final Brightness brightness;

  /// Preset tipográfico de firma (ver FontPresets): se aplica al activar.
  final String fontPresetId;
  final AppPalette palette;
  final TacticalThemeTokens tactical;

  bool get isDark => brightness == Brightness.dark;
  Color get accent => tactical.primary;

  /// Copia exacta de un tema del catálogo, con id y nombre nuevos.
  factory CustomTheme.fromPreset(
    AppThemePreset preset, {
    required String id,
    String? name,
  }) => CustomTheme(
    id: id,
    name: name ?? preset.label,
    brightness: preset.brightness,
    fontPresetId: preset.fontPresetId,
    palette: preset.palette,
    tactical: preset.tactical,
  );

  CustomTheme copyWith({
    String? id,
    String? name,
    Brightness? brightness,
    String? fontPresetId,
    AppPalette? palette,
    TacticalThemeTokens? tactical,
  }) => CustomTheme(
    id: id ?? this.id,
    name: name ?? this.name,
    brightness: brightness ?? this.brightness,
    fontPresetId: fontPresetId ?? this.fontPresetId,
    palette: palette ?? this.palette,
    tactical: tactical ?? this.tactical,
  );

  // -------------------------------------------------------------------
  // Atajos del editor sencillo.
  // -------------------------------------------------------------------

  /// Rehace la paleta a partir de un solo color de fondo: superficies,
  /// bordes, textos, metal y cabecera salen de su tono, escalonados hacia
  /// la luz (tema oscuro) o hacia la sombra (tema claro). El brillo del
  /// tema se deduce del propio fondo.
  CustomTheme withBackground(Color background) {
    final hsl = HSLColor.fromColor(background);
    final dark = hsl.lightness < 0.5;
    // Paso de luminosidad: en oscuro se aclara, en claro se oscurece.
    Color step(double amount, {double? saturation}) {
      final l = (hsl.lightness + (dark ? amount : -amount)).clamp(0.0, 1.0);
      return hsl
          .withLightness(l)
          .withSaturation((saturation ?? hsl.saturation).clamp(0.0, 1.0))
          .toColor();
    }

    final textPrimary = hsl
        .withLightness(dark ? 0.92 : 0.12)
        .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
        .toColor();
    final textSecondary = hsl
        .withLightness(dark ? 0.68 : 0.36)
        .withSaturation((hsl.saturation * 0.3).clamp(0.0, 1.0))
        .toColor();

    return copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      palette: palette.copyWith(
        background: background,
        surface: step(0.04),
        surfaceElevated: step(0.09),
        border: step(0.22),
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
      tactical: tactical.copyWith(
        surfaceRaised: step(0.08),
        metalBorder: step(0.24),
        metalHighlight: dark ? step(0.45) : const Color(0xFFFFFFFF),
        headerStart: Color.alphaBlend(
          tactical.primary.withValues(alpha: 0.18),
          step(0.06),
        ),
        headerEnd: background,
      ),
    );
  }

  /// Redondez única para tarjetas, placas (algo menos) y botones. Respeta
  /// el tipo de forma de cada uno salvo la píldora, que no tiene radio.
  CustomTheme withRoundness(double radius) {
    OutlinedBorder apply(OutlinedBorder border, double r) {
      final spec = ShapeSpec.fromBorder(border);
      if (spec.kind == ShapeKind.stadium) return border;
      return spec.withRadius(r).toBorder();
    }

    return copyWith(
      tactical: tactical.copyWith(
        cardShape: apply(tactical.cardShape, radius),
        insetShape: apply(tactical.insetShape, radius * 0.75),
        buttonShape: apply(tactical.buttonShape, radius),
      ),
    );
  }

  /// Redondez actual (la de las tarjetas), para el deslizador sencillo.
  double get roundness => ShapeSpec.fromBorder(tactical.cardShape).topLeft;

  // -------------------------------------------------------------------
  // JSON
  // -------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    final t = tactical;
    int c(Color color) => color.toARGB32();
    return {
      'id': id,
      'name': name,
      'brightness': brightness.name,
      'font_preset': fontPresetId,
      'palette': {
        'background': c(palette.background),
        'surface': c(palette.surface),
        'surface_elevated': c(palette.surfaceElevated),
        'border': c(palette.border),
        'text_primary': c(palette.textPrimary),
        'text_secondary': c(palette.textSecondary),
        'danger': c(palette.danger),
        'success': c(palette.success),
      },
      'colors': {
        'primary': c(t.primary),
        'weapon': c(t.weapon),
        'spell': c(t.spell),
        'ability': c(t.ability),
        'heal': c(t.heal),
        'damage': c(t.damage),
        'metal_border': c(t.metalBorder),
        'metal_highlight': c(t.metalHighlight),
        'surface_raised': c(t.surfaceRaised),
        'header_start': c(t.headerStart),
        'header_end': c(t.headerEnd),
        'coin_platinum': c(t.coinPlatinum),
        'coin_gold': c(t.coinGold),
        'coin_electrum': c(t.coinElectrum),
        'coin_silver': c(t.coinSilver),
        'coin_copper': c(t.coinCopper),
      },
      'card_shape': ShapeSpec.fromBorder(t.cardShape).toJson(),
      'inset_shape': ShapeSpec.fromBorder(t.insetShape).toJson(),
      'button_shape': ShapeSpec.fromBorder(t.buttonShape).toJson(),
      'border_width': t.borderWidth,
      'shadow': t.shadowStyle.name,
      'pattern': t.backgroundPattern.name,
      'pip': t.pipShape.name,
      'header_font': {
        'family': t.headerFont.family,
        'letter_spacing': t.headerFont.letterSpacing,
        'weight': t.headerFont.weight.value,
      },
      'shapes': {
        'dialog': t.shapes.dialogRadius,
        'sheet': t.shapes.sheetRadius,
        'input': t.shapes.inputRadius,
        'tooltip': t.shapes.tooltipRadius,
        'fab': t.shapes.fabRadius,
        'pill': t.shapes.pillRadius,
        'overlay_elevation': t.shapes.overlayElevation,
      },
      'icons': {
        'style': t.icons.style.name,
        'dice_shape': t.icons.diceShape.name,
        'dice_weight': t.icons.diceNumberWeight.value,
        'dice_spacing': t.icons.diceNumberSpacing,
      },
      'motion': {
        'duration_scale': t.motion.durationScale,
        'dial_curve': ThemeCurves.nameOf(t.motion.dialCurve, 'easeOutCubic'),
        'resolve_curve': ThemeCurves.nameOf(
          t.motion.resolveCurve,
          'easeOutBack',
        ),
      },
      'density': t.density.scale,
      'background': {
        'opacity': t.background.patternOpacity,
        'scale': t.background.patternScale,
      },
      'cards': {
        'gradient': t.cards.gradient.name,
        'highlight_alpha': t.cards.highlightAlpha,
        'tone_stripe': t.cards.toneStripe,
        'double_border': t.cards.doubleBorder,
      },
      'components': {
        'header': t.components.header.name,
        'button': t.components.button.name,
        'bar': t.components.bar.name,
        'bar_glow': t.components.barGlow,
        'secondary_button': t.components.secondaryButton?.name,
      },
    };
  }

  /// Lee un tema guardado. Cada campo ausente o inválido cae al valor
  /// del tema de fábrica del mismo brillo.
  static CustomTheme fromJson(Map<String, dynamic> json) {
    final brightness = json['brightness'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final base = AppThemePreset.forBrightness(brightness);
    final bp = base.palette;
    final bt = base.tactical;

    Map<String, dynamic> sub(String key) {
      final v = json[key];
      return v is Map ? v.cast<String, dynamic>() : const {};
    }

    Color col(Map<String, dynamic> m, String k, Color f) {
      final v = m[k];
      return v is int ? Color(v) : f;
    }

    double num_(Map<String, dynamic> m, String k, double f) =>
        (m[k] as num?)?.toDouble() ?? f;

    bool flag(Map<String, dynamic> m, String k, bool f) =>
        m[k] is bool ? m[k] as bool : f;

    final p = sub('palette');
    final c = sub('colors');
    final hf = sub('header_font');
    final sh = sub('shapes');
    final ic = sub('icons');
    final mo = sub('motion');
    final bg = sub('background');
    final ca = sub('cards');
    final co = sub('components');

    final palette = AppPalette(
      background: col(p, 'background', bp.background),
      surface: col(p, 'surface', bp.surface),
      surfaceElevated: col(p, 'surface_elevated', bp.surfaceElevated),
      border: col(p, 'border', bp.border),
      textPrimary: col(p, 'text_primary', bp.textPrimary),
      textSecondary: col(p, 'text_secondary', bp.textSecondary),
      danger: col(p, 'danger', bp.danger),
      success: col(p, 'success', bp.success),
    );

    final tactical = TacticalThemeTokens(
      primary: col(c, 'primary', bt.primary),
      weapon: col(c, 'weapon', bt.weapon),
      spell: col(c, 'spell', bt.spell),
      ability: col(c, 'ability', bt.ability),
      heal: col(c, 'heal', bt.heal),
      damage: col(c, 'damage', bt.damage),
      metalBorder: col(c, 'metal_border', bt.metalBorder),
      metalHighlight: col(c, 'metal_highlight', bt.metalHighlight),
      surfaceRaised: col(c, 'surface_raised', bt.surfaceRaised),
      headerStart: col(c, 'header_start', bt.headerStart),
      headerEnd: col(c, 'header_end', bt.headerEnd),
      coinPlatinum: col(c, 'coin_platinum', bt.coinPlatinum),
      coinGold: col(c, 'coin_gold', bt.coinGold),
      coinElectrum: col(c, 'coin_electrum', bt.coinElectrum),
      coinSilver: col(c, 'coin_silver', bt.coinSilver),
      coinCopper: col(c, 'coin_copper', bt.coinCopper),
      cardShape: ShapeSpec.fromJson(
        json['card_shape'],
        ShapeSpec.fromBorder(bt.cardShape),
      ).toBorder(),
      insetShape: ShapeSpec.fromJson(
        json['inset_shape'],
        ShapeSpec.fromBorder(bt.insetShape),
      ).toBorder(),
      buttonShape: ShapeSpec.fromJson(
        json['button_shape'],
        ShapeSpec.fromBorder(bt.buttonShape),
      ).toBorder(),
      borderWidth: num_(json, 'border_width', bt.borderWidth),
      shadowStyle: _enumByName(
        ShadowStyle.values,
        json['shadow'],
        bt.shadowStyle,
      ),
      backgroundPattern: _enumByName(
        BackgroundPatternStyle.values,
        json['pattern'],
        bt.backgroundPattern,
      ),
      pipShape: _enumByName(PipShape.values, json['pip'], bt.pipShape),
      headerFont: HeaderFontStyle(
        family: kHeaderFontFamilies.contains(hf['family'])
            ? hf['family'] as String
            : bt.headerFont.family,
        letterSpacing: num_(hf, 'letter_spacing', bt.headerFont.letterSpacing),
        weight: _weight(hf['weight'], bt.headerFont.weight),
      ),
      shapes: ShapeTokens(
        dialogRadius: num_(sh, 'dialog', bt.shapes.dialogRadius),
        sheetRadius: num_(sh, 'sheet', bt.shapes.sheetRadius),
        inputRadius: num_(sh, 'input', bt.shapes.inputRadius),
        tooltipRadius: num_(sh, 'tooltip', bt.shapes.tooltipRadius),
        fabRadius: num_(sh, 'fab', bt.shapes.fabRadius),
        pillRadius: num_(sh, 'pill', bt.shapes.pillRadius),
        overlayElevation: num_(
          sh,
          'overlay_elevation',
          bt.shapes.overlayElevation,
        ),
      ),
      icons: IconTokens(
        style: _enumByName(IconStyle.values, ic['style'], bt.icons.style),
        diceShape: _enumByName(
          DiceMedallionShape.values,
          ic['dice_shape'],
          bt.icons.diceShape,
        ),
        diceNumberWeight: _weight(ic['dice_weight'], bt.icons.diceNumberWeight),
        diceNumberSpacing: num_(ic, 'dice_spacing', bt.icons.diceNumberSpacing),
      ),
      motion: MotionTokens(
        durationScale: num_(mo, 'duration_scale', bt.motion.durationScale),
        dialCurve: ThemeCurves.byName(mo['dial_curve'], bt.motion.dialCurve),
        resolveCurve: ThemeCurves.byName(
          mo['resolve_curve'],
          bt.motion.resolveCurve,
        ),
      ),
      density: DensityTokens(scale: num_(json, 'density', bt.density.scale)),
      background: BackgroundTokens(
        patternOpacity: num_(bg, 'opacity', bt.background.patternOpacity),
        patternScale: num_(bg, 'scale', bt.background.patternScale),
      ),
      cards: CardTokens(
        gradient: _enumByName(
          CardGradientStyle.values,
          ca['gradient'],
          bt.cards.gradient,
        ),
        highlightAlpha: num_(ca, 'highlight_alpha', bt.cards.highlightAlpha),
        toneStripe: flag(ca, 'tone_stripe', bt.cards.toneStripe),
        doubleBorder: flag(ca, 'double_border', bt.cards.doubleBorder),
      ),
      components: ComponentTokens(
        header: _enumByName(
          HeaderStyle.values,
          co['header'],
          bt.components.header,
        ),
        button: _enumByName(
          ButtonStyleKind.values,
          co['button'],
          bt.components.button,
        ),
        bar: _enumByName(BarStyle.values, co['bar'], bt.components.bar),
        barGlow: flag(co, 'bar_glow', bt.components.barGlow),
        secondaryButton: co.containsKey('secondary_button')
            ? _enumByNameOrNull(ButtonStyleKind.values, co['secondary_button'])
            : bt.components.secondaryButton,
      ),
    );

    final name = json['name'];
    final id = json['id'];
    return CustomTheme(
      id: id is String && id.isNotEmpty ? id : 'custom_legacy',
      name: name is String && name.trim().isNotEmpty ? name : 'Mi tema',
      brightness: brightness,
      fontPresetId: json['font_preset'] is String
          ? json['font_preset'] as String
          : base.fontPresetId,
      palette: palette,
      tactical: tactical,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

FontWeight _weight(Object? value, FontWeight fallback) {
  if (value is! int) return fallback;
  for (final w in FontWeight.values) {
    if (w.value == value) return w;
  }
  return fallback;
}
