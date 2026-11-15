// Economía de acciones: acción, acción adicional, reacción y pasivas.
// Las habilidades de acción/bonus/reacción llevan los datos necesarios
// para resolverlas en el Protocolo de Dados: a qué estadística está
// ligado su modificador (relatedStat), qué le cuenta la historia al
// jugador según el resultado, y desde la Fase 8 también cargas propias
// (usos limitados por descanso, ej. "Furia 2/descanso").
//
// Rework v2 — serialización ÚNICA. En la app vieja había DOS toJson()
// para Ability: el método de instancia de este archivo (que NO
// serializaba magic_charges) y la extensión AbilityJson de
// serialization_extensions.dart (que sí las serializaba pero perdía
// tactical_role). En Dart el método de instancia siempre le gana a la
// extensión, así que la extensión era código muerto y LAS CARGAS DE LAS
// HABILIDADES SE RESETEABAN A TOPE EN CADA REINICIO sin que nadie se
// enterara. Acá existe un solo toJson(), completo, y el test de
// roundtrip (test/models_test.dart) vigila que no vuelva a pasar.

import '../../core/dice.dart';
import 'weapon.dart' show MagicCharges;

/// El trío isScalable/baseLevel/scalingFormula viajaba como tres campos
/// sueltos repetidos por todo el código. Bundle acá para que "el
/// escalado" sea un concepto y no tres variables que hay que mantener
/// sincronizadas a mano.
class SpellScaling {
  final bool isScalable;
  final int baseLevel;

  /// Dado que se suma por cada nivel por encima de baseLevel, ej.
  /// "1d6" (Bola de Fuego a nivel 4 tira 8d6, a nivel 5 tira 9d6).
  final String? formula;

  const SpellScaling({this.isScalable = false, this.baseLevel = 0, this.formula});

  static const SpellScaling none = SpellScaling();

  /// true si isScalable es true Y la fórmula tiene un formato realmente
  /// resoluble (dado o plano). Un "scaling_formula" mal escrito en el
  /// JSON de la IA no falla al importar — falla en silencio a mitad de
  /// combate; esto permite detectarlo antes, al importar.
  bool get hasResolvableScaling =>
      isScalable && formula != null && DiceExpression.tryParse(formula!) != null;

  SpellScaling copyWith({bool? isScalable, int? baseLevel, String? formula}) {
    return SpellScaling(
      isScalable: isScalable ?? this.isScalable,
      baseLevel: baseLevel ?? this.baseLevel,
      formula: formula ?? this.formula,
    );
  }
}

class Ability {
  /// Clave estable para persistencia — nunca usar el nombre para esto
  /// (dos habilidades homebrew pueden compartir nombre).
  String id;
  String name;
  String type;
  String relatedStat; // 'str' | 'dex' | 'con' | 'int' | 'wis' | 'cha'.

  /// Distingue si el objetivo tira contra la CD del lanzador ('save',
  /// ej. Bola de Fuego) de si es el lanzador quien tira para impactar
  /// ('attack', ej. Rayo de Escarcha) o si no hay tirada enfrentada
  /// ('none', ej. Escudo).
  String attackType;

  /// true si esta habilidad obliga al objetivo a tirar salvación contra
  /// la CD del lanzador — decide si el modal de dados pinta el aviso de
  /// CD de Salvación.
  bool get isSavingThrowType => attackType == 'save';

  /// Clasificación semántica de la habilidad.
  bool get isSpell => type == 'spell';
  bool get isCantrip => isSpell && baseLevel == 0;
  bool get isLeveledSpell => isSpell && baseLevel > 0;
  bool get isTrait => !isSpell;

  String successDescription;
  String failureDescription;

  /// Dado base de daño/efecto, ej. "8d6". Null si la habilidad no
  /// inflige daño (p.ej. Escudo).
  String? damageDice;

  /// Texto de rol (sabor) y resumen mecánico rápido. Opcionales: si el
  /// JSON no los trae, el modal simplemente no pinta esos bloques.
  String? loreDescription;
  String? tacticalSummary;

  /// Solo relevante para pasivas: agrupa el HUD bajo una etiqueta de
  /// rol táctico ("Ofensivo", "Defensivo", "Utilidad"). Las habilidades
  /// de acción/bonus/reacción no lo usan y llega null sin que pase nada.
  String? tacticalRole;

  /// Cargas propias de la habilidad (independientes de las ranuras de
  /// conjuro). Sin "magic_charges" en el JSON, queda hasCharges=false y
  /// el resto del código ignora el contador — mismo comportamiento que
  /// Weapon.
  MagicCharges magicCharges;

  /// Nombre del [ResourcePoint] de la ficha que esta habilidad gasta al
  /// usarse (Ki, Furia, Inspiración Bárdica...). Null = no gasta
  /// recursos compartidos (fichas viejas). Se une por nombre, igual que
  /// el resto de la app identifica los recursos.
  String? resourceName;

  /// Puntos que gasta de [resourceName] por uso. Solo tiene sentido si
  /// hay resourceName.
  int resourceCost;

  /// Dado de curación (ej. "1d10+3"), separado de [damageDice] para que
  /// la hoja de resolución muestre una tirada de curación diferenciada.
  String? healDice;

  /// true si el conjuro o poder exige mantener concentración. Solo se
  /// escribe en el JSON de habilidades activas y solo cuando es true:
  /// las fichas viejas no cambian.
  bool concentration;

  SpellScaling scaling;

  // Fachada de compatibilidad sobre el bundle SpellScaling: el resto
  // del código sigue leyendo ability.isScalable / baseLevel /
  // scalingFormula sin saber que ahora viven agrupados.
  bool get isScalable => scaling.isScalable;
  set isScalable(bool value) => scaling = scaling.copyWith(isScalable: value);

  int get baseLevel => scaling.baseLevel;
  set baseLevel(int value) => scaling = scaling.copyWith(baseLevel: value);

  String? get scalingFormula => scaling.formula;
  set scalingFormula(String? value) => scaling = scaling.copyWith(formula: value);

  /// true si el escalado configurado realmente se puede resolver en
  /// combate (ver SpellScaling.hasResolvableScaling).
  bool get hasResolvableScaling => scaling.hasResolvableScaling;

  Ability({
    required this.id,
    required this.name,
    required this.type,
    required this.relatedStat,
    required this.successDescription,
    required this.failureDescription,
    this.attackType = 'attack',
    bool isScalable = false,
    int baseLevel = 0,
    String? scalingFormula,
    this.damageDice,
    this.loreDescription,
    this.tacticalSummary,
    this.tacticalRole,
    MagicCharges? magicCharges,
    this.resourceName,
    this.resourceCost = 1,
    this.healDice,
    this.concentration = false,
    SpellScaling? scaling,
  })  : scaling = scaling ??
            SpellScaling(
              isScalable: isScalable,
              baseLevel: baseLevel,
              formula: scalingFormula,
            ),
        magicCharges = magicCharges ?? MagicCharges.fromJson(null);

  factory Ability.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? 'Habilidad sin nombre';
    return Ability(
      // Red de seguridad: id estable generado desde el nombre si el
      // JSON no lo trae, igual que Weapon.
      id: json['id']?.toString() ?? 'ability_${name.hashCode}',
      name: name,
      type: json['type'] ?? 'trait',
      relatedStat: json['related_stat'] ?? '',
      successDescription: json['success_description'] ?? '',
      failureDescription: json['failure_description'] ?? '',
      attackType: json['attack_type'] ?? 'attack',
      isScalable: json['is_scalable'] ?? false,
      baseLevel: ((json['base_level'] as num?) ?? 0).toInt(),
      scalingFormula: json['scaling_formula'] as String?,
      damageDice: json['damage_dice'] as String?,
      loreDescription: json['lore_description'] as String?,
      tacticalSummary: json['tactical_summary'] as String?,
      tacticalRole: json['tactical_role'] as String?,
      magicCharges: MagicCharges.fromJson(
        json['magic_charges'] as Map<String, dynamic>?,
      ),
      resourceName: _nonEmpty(json['resource_name']),
      resourceCost: ((json['resource_cost'] as num?) ?? 1).toInt().clamp(1, 99),
      healDice: _nonEmpty(json['heal_dice']),
      concentration: json['concentration'] == true,
    );
  }

  static String? _nonEmpty(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  /// LA serialización de Ability (ver comentario de archivo: es la
  /// única — no hay extensiones paralelas). Incluye magic_charges,
  /// que era justo lo que la versión vieja perdía.
  ///
  /// [category] ('action' | 'bonus_action' | 'reaction' | 'passive') aplica
  /// el esquema estricto: las pasivas omiten attack_type y damage_dice
  /// (conservan tactical_role) y las activas omiten tactical_role. Sin
  /// categoría (null) se escribe todo, para quien serializa una
  /// habilidad suelta.
  Map<String, dynamic> toJson({String? category}) {
    final isPassive = category == 'passive';
    final isActive = category != null && !isPassive;
    return {
      'id': id,
      'name': name,
      'type': type,
      'related_stat': relatedStat,
      'success_description': successDescription,
      'failure_description': failureDescription,
      if (!isPassive) 'attack_type': attackType,
      if (!isPassive) 'damage_dice': damageDice,
      'lore_description': loreDescription,
      'tactical_summary': tacticalSummary,
      if (!isActive) 'tactical_role': tacticalRole,
      'is_scalable': isScalable,
      'base_level': baseLevel,
      'scaling_formula': scalingFormula,
      'magic_charges': magicCharges.toJson(),
      // Recursos y curación: solo en habilidades activas (o sueltas), y
      // sin ruido si no se usan — así las fichas viejas no cambian.
      if (!isPassive && resourceName != null) ...{
        'resource_name': resourceName,
        'resource_cost': resourceCost,
      },
      if (!isPassive && healDice != null) 'heal_dice': healDice,
      if (!isPassive && concentration) 'concentration': true,
    };
  }
}

/// Las cuatro categorías de la economía de acciones. Shape JSON:
/// "abilities_by_action": { "action": [...], "bonus_action": [...],
/// "reaction": [...], "passive": [...] }.
class AbilitiesByAction {
  List<Ability> action;
  List<Ability> bonusAction;
  List<Ability> reaction;
  List<Ability> passive;

  AbilitiesByAction({
    required this.action,
    required this.bonusAction,
    required this.reaction,
    required this.passive,
  });

  static List<Ability> _parseList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((e) => Ability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  factory AbilitiesByAction.fromJson(Map<String, dynamic> json) {
    return AbilitiesByAction(
      action: _parseList(json['action']),
      bonusAction: _parseList(json['bonus_action']),
      reaction: _parseList(json['reaction']),
      passive: _parseList(json['passive']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.map((a) => a.toJson(category: 'action')).toList(),
      'bonus_action':
          bonusAction.map((a) => a.toJson(category: 'bonus_action')).toList(),
      'reaction': reaction.map((a) => a.toJson(category: 'reaction')).toList(),
      'passive': passive.map((a) => a.toJson(category: 'passive')).toList(),
    };
  }

  /// Las cuatro categorías aplanadas — para recorrerlas de una sola vez
  /// (descansos que restauran cargas, validador, editor).
  Iterable<Ability> get all sync* {
    yield* action;
    yield* bonusAction;
    yield* reaction;
    yield* passive;
  }

  /// La lista interna de una categoría. Cualquier valor desconocido cae
  /// en 'action' para que la UI no tenga que validar antes de llamar.
  List<Ability> listFor(String actionType) {
    switch (actionType) {
      case 'bonusAction':
        return bonusAction;
      case 'reaction':
        return reaction;
      case 'passive':
        return passive;
      case 'action':
      default:
        return action;
    }
  }
}
