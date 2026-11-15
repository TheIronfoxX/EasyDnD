// Tipografía de telemetría (rework estético).
//
// Los números que cambian en combate (PG, CA, modificadores, ranuras,
// fórmulas de dados) usan cifras tabulares: todos los dígitos ocupan el
// mismo ancho, así "19 → 20" no hace bailar la fila. Es un feature de la
// fuente, no una familia distinta: los nombres y cabeceras siguen en la
// serif de display.

import 'package:flutter/painting.dart';

const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

extension TelemetryTextStyle on TextStyle {
  /// El mismo estilo con cifras tabulares.
  TextStyle get tabular => copyWith(fontFeatures: kTabularFigures);
}
