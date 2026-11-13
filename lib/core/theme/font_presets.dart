// Presets tipográficos (Etapa 6c).
//
// El skin elige una familia para el cuerpo y otra para los títulos. Acá
// usamos familias genéricas que Android y la web resuelven sin descargar
// nada: la app es offline y no queremos que el primer arranque dependa de
// una fuente remota ni inflar el repo con binarios.
//
// "Diario" mezcla títulos serif con cuerpo sans (el look de la app
// vieja); "Mesa" es el sistema de punta a punta; "Consola" es
// monoespaciada, cómoda para números y mesas tácticas.
//
// `null` significa "la familia por defecto de la plataforma".

import 'package:flutter/material.dart';

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
    description: 'Títulos serif y cuerpo sans, como un libro de aventuras.',
    displayFamily: 'serif',
  );

  static const FontPreset table = FontPreset(
    id: 'mesa',
    label: 'Mesa',
    description: 'La sans del sistema: neutra y muy legible.',
  );

  static const FontPreset console = FontPreset(
    id: 'consola',
    label: 'Consola',
    description: 'Monoespaciada, ideal para números y mesas tácticas.',
    bodyFamily: 'monospace',
    displayFamily: 'monospace',
  );

  static const List<FontPreset> all = [journal, table, console];

  static const FontPreset defaultPreset = table;

  /// Resuelve un id guardado. Un id desconocido o ausente cae al preset
  /// por defecto (así una preferencia vieja nunca deja la app sin tema).
  static FontPreset byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return defaultPreset;
  }
}
