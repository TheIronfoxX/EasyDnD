// Presets tipográficos (Etapa 6c; familias reales desde la 8a).
//
// El skin elige una familia para el cuerpo y otra para los títulos. Las
// familias son las empaquetadas en `assets/fonts` (ver [AppFonts]): la
// app es offline y, en la web, CanvasKit no resuelve las genéricas
// 'serif'/'monospace', así que no se usan.
//
// "Diario" mezcla títulos Cinzel con cuerpo Inter (el look de la app
// vieja, ahora de verdad); "Mesa" es Inter de punta a punta, neutra;
// "Consola" es JetBrains Mono, cómoda para números y mesas tácticas.

import 'package:flutter/foundation.dart';

import 'app_fonts.dart';

@immutable
class FontPreset {
  const FontPreset({
    required this.id,
    required this.label,
    required this.description,
    this.bodyFamily,
    this.displayFamily,
  });

  /// Identificador estable para persistir (no cambia si cambia el label).
  final String id;
  final String label;
  final String description;
  final String? bodyFamily;
  final String? displayFamily;
}

abstract final class FontPresets {
  static const FontPreset journal = FontPreset(
    id: 'diario',
    label: 'Diario',
    description:
        'Títulos en Cinzel y cuerpo en Inter, como un libro de aventuras.',
    bodyFamily: AppFonts.inter,
    displayFamily: AppFonts.cinzel,
  );

  static const FontPreset table = FontPreset(
    id: 'mesa',
    label: 'Mesa',
    description: 'Inter de punta a punta: neutra y muy legible.',
    bodyFamily: AppFonts.inter,
    displayFamily: AppFonts.inter,
  );

  static const FontPreset console = FontPreset(
    id: 'consola',
    label: 'Consola',
    description: 'JetBrains Mono, ideal para números y mesas tácticas.',
    bodyFamily: AppFonts.jetBrainsMono,
    displayFamily: AppFonts.jetBrainsMono,
  );

  static const List<FontPreset> all = [journal, table, console];

  /// Por defecto "Diario": es la identidad de la app y se nota desde el
  /// primer arranque. Quien ya eligió otro preset lo conserva (persistido).
  static const FontPreset defaultPreset = journal;

  /// Resuelve un id guardado. Un id desconocido o ausente cae al preset
  /// por defecto (así una preferencia vieja nunca deja la app sin tema).
  static FontPreset byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return defaultPreset;
  }
}
