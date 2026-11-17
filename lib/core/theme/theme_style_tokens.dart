import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Tokens de estilo que un tema puede variar además de color y geometría
/// básica. Todos los valores por defecto reproducen el comportamiento
/// previo a que los temas controlaran estas cosas.

/// Radios y elevaciones de los componentes Material (diálogos, inputs...).
@immutable
class ShapeTokens {
  const ShapeTokens({
    this.dialogRadius = AppRadii.lg,
    this.sheetRadius = AppRadii.lg,
    this.inputRadius = AppRadii.md,
    this.tooltipRadius = AppRadii.sm,
    this.fabRadius = AppRadii.lg,
    this.pillRadius = AppRadii.pill,
    this.overlayElevation = 0,
  });

  final double dialogRadius;
  final double sheetRadius;
  final double inputRadius;
  final double tooltipRadius;
  final double fabRadius;
  final double pillRadius;

  /// Elevación de diálogos, menús y hojas.
  final double overlayElevation;

  static ShapeTokens lerp(ShapeTokens a, ShapeTokens b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return ShapeTokens(
      dialogRadius: l(a.dialogRadius, b.dialogRadius),
      sheetRadius: l(a.sheetRadius, b.sheetRadius),
      inputRadius: l(a.inputRadius, b.inputRadius),
      tooltipRadius: l(a.tooltipRadius, b.tooltipRadius),
      fabRadius: l(a.fabRadius, b.fabRadius),
      pillRadius: t >= 0.5 ? b.pillRadius : a.pillRadius,
      overlayElevation: l(a.overlayElevation, b.overlayElevation),
    );
  }
}

/// Familia de iconos del HUD.
enum IconStyle { rounded, sharp, outlined }

/// Silueta del medallón del dado.
enum DiceMedallionShape { hexagon, circle, diamond, square }

/// Iconografía y dados.
@immutable
class IconTokens {
  const IconTokens({
    this.style = IconStyle.rounded,
    this.diceShape = DiceMedallionShape.hexagon,
    this.diceNumberWeight = FontWeight.w800,
    this.diceNumberSpacing = 0,
  });

  final IconStyle style;
  final DiceMedallionShape diceShape;
  final FontWeight diceNumberWeight;
  final double diceNumberSpacing;

  static IconTokens lerp(IconTokens a, IconTokens b, double t) =>
      t >= 0.5 ? b : a;
}

/// Ritmo de las animaciones.
@immutable
class MotionTokens {
  const MotionTokens({
    this.durationScale = 1.0,
    this.dialCurve = Curves.easeOutCubic,
    this.resolveCurve = Curves.easeOutBack,
  });

  /// Multiplicador de las duraciones de animación (1 = actual).
  final double durationScale;
  final Curve dialCurve;
  final Curve resolveCurve;

  Duration scale(Duration d) =>
      Duration(microseconds: (d.inMicroseconds * durationScale).round());

  static MotionTokens lerp(MotionTokens a, MotionTokens b, double t) =>
      MotionTokens(
        durationScale:
            a.durationScale + (b.durationScale - a.durationScale) * t,
        dialCurve: t >= 0.5 ? b.dialCurve : a.dialCurve,
        resolveCurve: t >= 0.5 ? b.resolveCurve : a.resolveCurve,
      );
}

/// Densidad: escala el relleno de tarjetas y botones.
@immutable
class DensityTokens {
  const DensityTokens({this.scale = 1.0});

  /// 1 = actual; <1 más denso, >1 más holgado.
  final double scale;

  static DensityTokens lerp(DensityTokens a, DensityTokens b, double t) =>
      DensityTokens(scale: a.scale + (b.scale - a.scale) * t);
}

/// Intensidad de la trama de fondo.
@immutable
class BackgroundTokens {
  const BackgroundTokens({this.patternOpacity = 1.0, this.patternScale = 1.0});

  /// Multiplicador del alfa de la trama (0 la apaga).
  final double patternOpacity;

  /// Multiplicador del tamaño de la trama.
  final double patternScale;

  static BackgroundTokens lerp(
    BackgroundTokens a,
    BackgroundTokens b,
    double t,
  ) => BackgroundTokens(
    patternOpacity:
        a.patternOpacity + (b.patternOpacity - a.patternOpacity) * t,
    patternScale: a.patternScale + (b.patternScale - a.patternScale) * t,
  );
}

/// Relleno de las tarjetas.
enum CardGradientStyle {
  /// Superficie elevada arriba → superficie abajo (actual).
  raisedToSurface,

  /// Color plano.
  flat,

  /// Superficie arriba → elevada abajo.
  surfaceToRaised,
}

@immutable
class CardTokens {
  const CardTokens({
    this.gradient = CardGradientStyle.raisedToSurface,
    this.highlightAlpha = 0.55,
    this.toneStripe = true,
    this.doubleBorder = false,
  });

  final CardGradientStyle gradient;

  /// Alfa del filo de luz del canto superior.
  final double highlightAlpha;

  /// Franja de tono lateral de la tarjeta.
  final bool toneStripe;

  /// Segundo filete interior, como el marco doble de un códice.
  final bool doubleBorder;

  static CardTokens lerp(CardTokens a, CardTokens b, double t) => CardTokens(
    gradient: t >= 0.5 ? b.gradient : a.gradient,
    highlightAlpha:
        a.highlightAlpha + (b.highlightAlpha - a.highlightAlpha) * t,
    toneStripe: t >= 0.5 ? b.toneStripe : a.toneStripe,
    doubleBorder: t >= 0.5 ? b.doubleBorder : a.doubleBorder,
  );
}

/// Estructura de las cabeceras de sección.
enum HeaderStyle {
  /// Icono + título + trazo con glifo del pip (actual).
  ornament,

  /// Banda con el degradado de cabecera detrás del título.
  plate,

  /// Línea gruesa del color de rol bajo el título.
  underline,

  /// Esquinas en L alrededor del título.
  brackets,

  /// Solo icono y texto, sin adorno.
  minimal,
}

/// Aspecto de los botones rellenos.
enum ButtonStyleKind {
  /// Relleno del color de acento (actual).
  filled,

  /// Relleno tenue del acento con texto de acento.
  tonal,

  /// Solo contorno.
  outlined,

  /// Sin relleno ni contorno.
  flat,
}

/// Aspecto de las barras de medidor (PG, movimiento).
enum BarStyle {
  /// Barra continua con degradado (actual).
  smooth,

  /// Barra dividida en segmentos.
  segmented,

  /// Línea fina sin marco.
  thin,
}

/// Estilos estructurales de componentes que varían por tema.
@immutable
class ComponentTokens {
  const ComponentTokens({
    this.header = HeaderStyle.ornament,
    this.button = ButtonStyleKind.filled,
    this.bar = BarStyle.smooth,
    this.barGlow = false,
    this.secondaryButton,
  });

  final HeaderStyle header;
  final ButtonStyleKind button;
  final BarStyle bar;

  /// Halo del color de la barra y filete de metal brillante alrededor.
  final bool barGlow;

  /// Aspecto de los botones secundarios (contorno). `null` = el de siempre.
  final ButtonStyleKind? secondaryButton;

  static ComponentTokens lerp(ComponentTokens a, ComponentTokens b, double t) =>
      t >= 0.5 ? b : a;
}
