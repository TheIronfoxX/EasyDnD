// Categoría de un poder (habilidad, rasgo o conjuro) para la lista
// sencilla del HUD: Daño, Defensa, Apoyo o Utilidad.
//
// Orden de prioridad:
//   1. `powerRole` (lo pone la IA de preparación o el jugador);
//   2. `tacticalRole` de las pasivas (Ofensivo/Defensivo/Utilidad);
//   3. deducción: dados de daño → Daño; dados de curación → Apoyo;
//      palabras clave del texto → Defensa/Apoyo; si no, Utilidad.
//
// Sin Flutter: es dominio puro y se prueba sin widgets.

import 'models/ability.dart';

enum PowerCategory {
  damage('Daño'),
  defense('Defensa'),
  support('Apoyo'),
  utility('Utilidad');

  const PowerCategory(this.label);

  /// Etiqueta visible y valor guardado en `power_role`.
  final String label;

  /// Acepta la etiqueta exacta y variantes razonables ("daño", "soporte",
  /// "Ofensivo"...). `null` si no reconoce el texto.
  static PowerCategory? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase();
    if (v == null || v.isEmpty) return null;
    return switch (v) {
      'daño' || 'dano' || 'ofensivo' || 'ofensiva' => PowerCategory.damage,
      'defensa' || 'defensivo' || 'defensiva' => PowerCategory.defense,
      'apoyo' || 'soporte' || 'curación' || 'curacion' => PowerCategory.support,
      'utilidad' => PowerCategory.utility,
      _ => null,
    };
  }
}

const _defenseWords = [
  'clase de armadura',
  ' ca ',
  '+5 a la ca',
  'tu ca',
  'protege',
  'protección',
  'resistencia al daño',
  'resistencia a',
  'reduce el daño',
  'escudo',
];

const _supportWords = [
  'aliado',
  'aliada',
  'curas',
  'recupera',
  'puntos de golpe temporales',
  'bendic',
  'inspiración',
];

PowerCategory categoryOf(Ability ability) {
  final explicit = PowerCategory.tryParse(ability.powerRole);
  if (explicit != null) return explicit;

  final role = PowerCategory.tryParse(ability.tacticalRole);
  if (role != null) return role;

  if ((ability.damageDice?.trim().isNotEmpty ?? false)) {
    return PowerCategory.damage;
  }
  if ((ability.healDice?.trim().isNotEmpty ?? false)) {
    return PowerCategory.support;
  }

  final text =
      ' ${[ability.name, ability.tacticalSummary, ability.successDescription, ability.loreDescription].whereType<String>().join(' ').toLowerCase()} ';
  if (_defenseWords.any(text.contains)) return PowerCategory.defense;
  if (_supportWords.any(text.contains)) return PowerCategory.support;
  return PowerCategory.utility;
}

/// Frase en llano para la lista: la de la IA si existe; si no, la
/// primera frase de la descripción narrativa o del efecto (se leen
/// mejor que el resumen táctico, que va lleno de jerga) y, como último
/// recurso, el resumen táctico.
String plainSummaryOf(Ability ability) {
  for (final candidate in [
    ability.plainSummary,
    ability.loreDescription,
    ability.successDescription,
    ability.tacticalSummary,
  ]) {
    final text = candidate?.trim() ?? '';
    if (text.isNotEmpty) return _firstSentence(text);
  }
  return '';
}

String _firstSentence(String text) {
  final match = RegExp(r'^(.+?[.!?])(\s|$)').firstMatch(text);
  final sentence = (match?.group(1) ?? text).trim();
  return sentence.length > 140 ? '${sentence.substring(0, 137)}…' : sentence;
}
