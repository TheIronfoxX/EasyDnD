// Forma del tema limpio: lo poco que cambia de silueta entre los tres
// temas de Ajustes (ver [CleanThemeStyle]).
//
// Los widgets no eligen radios a mano para sus superficies: piden
// `context.cleanShape.radius(16)` (16 = el radio del tema Limpio) y el
// tema lo escala. Así Grimorio sale más recto y Escarcha a medio camino
// sin tocar cada pantalla.

import 'package:flutter/material.dart';

@immutable
class CleanShape extends ThemeExtension<CleanShape> {
  const CleanShape({
    this.cornerScale = 1.0,
    this.beveled = false,
    this.outline,
  });

  /// Multiplica los radios de referencia (los del tema Limpio).
  final double cornerScale;

  /// Esquinas cortadas en diagonal en vez de redondeadas.
  final bool beveled;

  /// Borde fino de las tarjetas; null = sin borde.
  final BorderSide? outline;

  /// Radio escalado a partir del radio de referencia [base].
  double r(double base) => base * cornerScale;

  BorderRadius radius(double base) => BorderRadius.circular(r(base));

  /// Silueta de una superficie (tarjeta, fila, mosaico) con radio de
  /// referencia [base]; incluye el borde del tema si lo tiene.
  OutlinedBorder surface(double base) {
    final side = outline ?? BorderSide.none;
    return beveled
        ? BeveledRectangleBorder(borderRadius: radius(base), side: side)
        : RoundedRectangleBorder(borderRadius: radius(base), side: side);
  }

  /// Decoración de un contenedor con la silueta del tema.
  ShapeDecoration decoration(double base, {required Color color}) =>
      ShapeDecoration(color: color, shape: surface(base));

  @override
  CleanShape copyWith({
    double? cornerScale,
    bool? beveled,
    BorderSide? outline,
  }) => CleanShape(
    cornerScale: cornerScale ?? this.cornerScale,
    beveled: beveled ?? this.beveled,
    outline: outline ?? this.outline,
  );

  @override
  CleanShape lerp(ThemeExtension<CleanShape>? other, double t) {
    if (other is! CleanShape) return this;
    return CleanShape(
      cornerScale: cornerScale + (other.cornerScale - cornerScale) * t,
      beveled: t < 0.5 ? beveled : other.beveled,
      outline: t < 0.5 ? outline : other.outline,
    );
  }
}

extension CleanShapeX on BuildContext {
  /// Forma del tema activo; sin extensión (temas viejos) = la de Limpio.
  CleanShape get cleanShape =>
      Theme.of(this).extension<CleanShape>() ?? const CleanShape();
}
