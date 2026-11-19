// Presets de acento (Etapa 6b).
//
// Son solo datos: un nombre para el jugador y el color que se aplica al
// `primary` del tema. El preset "Oro" es el sepia de la app vieja, así
// que la primera opción siempre reproduce el look de siempre.
//
// El picker HSV queda para quien quiera salirse de la lista: el
// SkinController no distingue entre preset y color libre.

import 'package:flutter/material.dart';

import 'app_theme.dart';

@immutable
class AccentPreset {
  const AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

abstract final class AccentPresets {
  static const List<AccentPreset> all = [
    AccentPreset('Rojo', AppTheme.defaultAccent),
    AccentPreset('Oro', AppTheme.goldAccent),
    AccentPreset('Acero', Color(0xFF5B8DEF)),
    AccentPreset('Arcana', Color(0xFF9B7BFF)),
    AccentPreset('Bosque', Color(0xFF57B87A)),
    AccentPreset('Brasa', Color(0xFFE0704F)),
    AccentPreset('Rosa', Color(0xFFE0679B)),
  ];

  /// El preset que coincide exactamente con [color], si hay uno. Con un
  /// color libre devuelve null y ningún swatch queda marcado.
  static AccentPreset? matching(Color color) {
    for (final preset in all) {
      if (preset.color == color) return preset;
    }
    return null;
  }
}
