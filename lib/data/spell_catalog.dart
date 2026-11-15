import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/models/ability.dart';

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

/// Repositorio de conjuros del catálogo local offline.
abstract final class SpellCatalog {
  static List<SrdSpell>? _cached;

  /// Carga el catálogo JSON de assets (o usa la lista en caché si ya se cargó).
  static Future<List<SrdSpell>> load([AssetBundle? bundle]) async {
    if (_cached != null) return _cached!;

    final actualBundle = bundle ?? rootBundle;
    try {
      final jsonStr = await actualBundle.loadString(
        'assets/srd/spells_5e.json',
      );
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cached = list
          .map((e) => SrdSpell.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cached = const [];
    }
    return _cached!;
  }

  /// Filtra los conjuros cargados por texto y/o nivel.
  static List<SrdSpell> search(
    List<SrdSpell> all, {
    String query = '',
    int? level,
  }) {
    final cleanQuery = _normalize(query);
    return all.where((spell) {
      if (level != null && spell.level != level) return false;
      if (cleanQuery.isEmpty) return true;

      final nameMatch = _normalize(spell.name).contains(cleanQuery);
      final englishMatch = _normalize(spell.englishName).contains(cleanQuery);
      final schoolMatch = _normalize(spell.school).contains(cleanQuery);
      return nameMatch || englishMatch || schoolMatch;
    }).toList();
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  /// Limpia la caché (útil para tests).
  static void clearCache() {
    _cached = null;
  }
}
