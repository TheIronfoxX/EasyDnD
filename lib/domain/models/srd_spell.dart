// Conjuro del catálogo SRD 5e. Puro Dart (sin Flutter) para que el
// Nivel20Mapper pueda cruzar conjuros sin depender de rootBundle.

import 'ability.dart';

/// Un conjuro del catálogo del SRD 5e.
class SrdSpell {
  final String name;
  final String englishName;
  final int level;
  final String school;
  final String castingTime;
  final String range;
  final String attackType;
  final String? damageDice;
  final String? damageType;
  final bool isScalable;
  final String? scalingFormula;
  final String description;

  /// IDs de clase (en español) que tienen el conjuro en su lista, ej. `mago`.
  final List<String> classes;

  const SrdSpell({
    required this.name,
    required this.englishName,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.attackType,
    this.damageDice,
    this.damageType,
    this.isScalable = false,
    this.scalingFormula,
    required this.description,
    this.classes = const [],
  });

  factory SrdSpell.fromJson(Map<String, dynamic> json) {
    return SrdSpell(
      name: json['name'] as String? ?? 'Sin nombre',
      englishName: json['english_name'] as String? ?? '',
      level: ((json['level'] as num?) ?? 0).toInt(),
      school: json['school'] as String? ?? 'Evocación',
      castingTime: json['casting_time'] as String? ?? '1 acción',
      range: json['range'] as String? ?? '',
      attackType: json['attack_type'] as String? ?? 'attack',
      damageDice: json['damage_dice'] as String?,
      damageType: json['damage_type'] as String?,
      isScalable: json['is_scalable'] as bool? ?? false,
      scalingFormula: json['scaling_formula'] as String?,
      description: json['description'] as String? ?? '',
      classes: ((json['classes'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Convierte el conjuro del catálogo a una [Ability] del modelo de EasyDnD,
  /// lista para jugarse en el HUD o guardarse en la ficha.
  ///
  /// Devuelve también la categoría de economía de acciones resuelta
  /// ('action'/'bonusAction'/'reaction'): [Ability] no tiene ese campo
  /// (es estructural, ver [AbilitiesByAction.listFor]), así que viaja
  /// aparte para que el llamador sepa en qué lista insertarla.
  (Ability, String) toAbility({
    String relatedStat = 'int',
    String? preferredActionCategory,
  }) {
    // Si el tiempo de lanzamiento contiene "adicional" o "bonus",
    // se recomienda para acción adicional; si contiene "reacción", reacción.
    final lowerTime = castingTime.toLowerCase();
    final resolvedActionType = preferredActionCategory ??
        (lowerTime.contains('adicional') || lowerTime.contains('bonus')
            ? 'bonusAction'
            : lowerTime.contains('reacción') || lowerTime.contains('reaction')
                ? 'reaction'
                : 'action');

    final ability = Ability(
      id: 'spell_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: 'spell',
      relatedStat: relatedStat,
      successDescription: damageDice != null && damageDice!.isNotEmpty
          ? 'Impacta e inflige $damageDice ${damageType ?? ""}.'.trim()
          : 'El conjuro surte efecto.',
      failureDescription: attackType == 'save'
          ? 'El objetivo supera la salvación.'
          : 'El conjuro falla.',
      attackType: attackType,
      isScalable: isScalable,
      baseLevel: level,
      scalingFormula: scalingFormula,
      damageDice: damageDice,
      loreDescription: description,
      tacticalSummary: '$school · $castingTime · $range',
    );
    return (ability, resolvedActionType);
  }
}

/// Nombre normalizado para cruzar conjuros: minúsculas, sin tildes, sin
/// signos y con espacios colapsados ("Tormenta  de HIELO" == "tormenta de hielo").
String normalizeSpellName(String input) {
  var t = input.toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

