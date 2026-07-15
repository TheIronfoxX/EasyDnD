// Economía de acciones: acción, acción adicional, reacción y pasivas.
// Desde la Fase 5, las habilidades de acción/bonus/reacción llevan además
// los datos necesarios para resolverlas en el Protocolo de Dados: a qué
// estadística está ligado su modificador (relatedStat) y qué le cuenta la
// historia al jugador según el resultado de la tirada. Las pasivas nunca
// se tiran, así que esos campos les llegan vacíos y no pasa nada.
//
// Fase 6: soporte de conjuros escalables. Un conjuro puede subirse de nivel
// al lanzarlo (ej. Bola de Fuego a nivel 3, 4 o 5), lo que aumenta su daño
// según scalingFormula por cada nivel por encima de baseLevel. damageDice
// es el dado base de daño/efecto (viene del JSON, cada hechizo trae el
// suyo — no hay una fórmula global, cada uno mete sus propios modificadores).
//
// Fase 8: Sistema Universal de Cargas. Hasta ahora solo Weapon tenía
// magicCharges (objetos mágicos con usos limitados, ej. una varita de
// 3 cargas). Reutilizamos la misma clase MagicCharges de weapon_model.dart
// en vez de duplicarla — el shape es idéntico (has_charges/max/current) y
// así longRest()/customRest() pueden tratar ambas fuentes de forma
// simétrica en character_provider.dart.
//
// Hotfix (Objetivo 4): igual que Weapon, Ability ahora lleva un "id"
// estable — sin él, character_provider.dart no tenía ninguna clave fiable
// bajo la que guardar sus cargas en SharedPreferences, así que se
// reseteaban en cada reinicio de la app. El nombre no sirve como clave
// porque dos habilidades homebrew podrían compartir nombre.

import 'weapon_model.dart' show MagicCharges;

// Hotfix (Blindaje del Escalado): antes, un "scaling_formula" mal escrito en
// el JSON (p.ej. "1d6 por nivel" en vez de "1d6") no fallaba al cargar la
// ficha — fallaba en silencio a mitad de combate, cuando resolution_modal.dart
// intentaba parsearlo y simplemente se rendía sin avisar a nadie (0 de daño
// extra, cero pistas de por qué). Esta validación vive aquí, en el modelo
// puro sin Flutter de por medio, porque el momento correcto para detectar un
// JSON roto es "al importar el personaje", no "cuando el mago tira Bola de
// Fuego nivel 5".
//
// El patrón acepta dos formas: dado con o sin bono plano ("1d6", "2d4+3",
// "8d6-2") o un plano puro sin dado ("+3", "-1", "4") para habilidades que
// escalan con un número fijo por nivel en vez de tirar dados extra.
// Debe mantenerse en sincronía con _parseDice en resolution_modal.dart —
// duplicado a propósito, porque este archivo no depende de Flutter y no
// debería importar un widget de UI solo para validar un string.
bool _looksLikeValidDiceOrFlat(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final diceMatch = RegExp(r'^\d+d\d+\s*([+-]\s*\d+)?$').hasMatch(trimmed);
  final flatMatch = RegExp(r'^[+-]?\s*\d+$').hasMatch(trimmed);
  return diceMatch || flatMatch;
}

/// Hotfix (Blindaje — cohesión de escalado): isScalable, baseLevel y
/// scalingFormula siempre viajaban juntos pero como tres campos sueltos,
/// repetidos en Ability, en _TacticalEntry (turn_tab.dart) y en los
/// parámetros de showResolutionModal (resolution_modal.dart). Bundle aquí
/// para que "el escalado" sea un concepto, no tres variables que hay que
/// acordarse de mantener sincronizadas a mano.
///
/// Deliberadamente NO se propaga a turn_tab.dart ni a resolution_modal.dart:
/// Ability expone getters/setters de compatibilidad (más abajo) que hacen
/// que el resto del código siga leyendo/escribiendo ability.isScalable,
/// ability.baseLevel y ability.scalingFormula exactamente como antes — sin
/// tocar una sola línea fuera de este archivo, y sin arriesgarse a romper
/// algo como serialization_extensions.dart, que no tengo delante.
class SpellScaling {
  final bool isScalable;
  final int baseLevel;
  final String? formula; // dado que se suma por cada nivel por encima de baseLevel, ej. "1d6".

  const SpellScaling({this.isScalable = false, this.baseLevel = 0, this.formula});

  static const SpellScaling none = SpellScaling();

  /// true si isScalable=true Y formula tiene un formato realmente
  /// resoluble (dado o plano) — ver _looksLikeValidDiceOrFlat.
  bool get hasResolvableScaling =>
      isScalable && formula != null && _looksLikeValidDiceOrFlat(formula!);

  SpellScaling copyWith({bool? isScalable, int? baseLevel, String? formula}) {
    return SpellScaling(
      isScalable: isScalable ?? this.isScalable,
      baseLevel: baseLevel ?? this.baseLevel,
      formula: formula ?? this.formula,
    );
  }
}

class Ability {
  String id; // clave estable para persistencia — nunca usar el nombre para esto.
  String name;
  String type;
  String relatedStat; // clave de StatsBlock: 'str', 'dex', 'con', 'int', 'wis', 'cha'.
  // Aviso "CD de Salvación": distingue si el objetivo tira contra la CD del
  // lanzador ('save', ej. Bola de Fuego) de si es el lanzador quien tira
  // para impactar ('attack', ej. Rayo de Escarcha) o de si no hay tirada
  // enfrentada ('none', ej. Escudo). Vive en el JSON como "attack_type".
  // Por defecto 'attack' para no cambiar el comportamiento de fichas que
  // no traigan esta clave todavía (pre-hotfix CD de Salvación).
  String attackType;

  /// true si esta habilidad/hechizo obliga al objetivo a tirar salvación
  /// contra la CD del lanzador — es lo que decide si resolution_modal.dart
  /// pinta el aviso fijo de CD de Salvación.
  bool get isSavingThrowType => attackType == 'save';
  String successDescription;
  String failureDescription;
  String? damageDice; // dado base de daño/efecto, ej. "8d6". Null si la habilidad no inflige daño (p.ej. Escudo).
  // Fase 7 — Inteligencia Táctica: texto de rol (sabor) y resumen mecánico
  // rápido, ambos opcionales. Si el JSON no los trae, el modal simplemente
  // no pinta esos bloques.
  String? loreDescription;
  String? tacticalSummary;
  // Fase 12 — Clasificación Táctica: solo relevante para pasivas
  // ("passive" en el JSON). Agrupa la pasiva en el HUD bajo una etiqueta
  // de rol táctico (p.ej. "Ofensivo", "Defensivo", "Utilidad"). Las
  // habilidades de acción/bonus/reacción no lo usan y llega null sin que
  // pase nada — mismo patrón que loreDescription/tacticalSummary.
  String? tacticalRole;
  // Fase 8: cargas propias de la habilidad (independientes de las ranuras
  // de conjuro). Si el JSON no trae "magic_charges", MagicCharges.fromJson
  // devuelve hasCharges=false y el resto del código simplemente ignora el
  // contador — mismo comportamiento que ya tenía Weapon.
  MagicCharges magicCharges;

  /// Fase 8.2 — el trío isScalable/baseLevel/scalingFormula ahora vive
  /// junto en un SpellScaling. Los getters/setters de abajo son la
  /// fachada de compatibilidad: todo lo que ya leía o escribía
  /// ability.isScalable, ability.baseLevel o ability.scalingFormula
  /// (turn_tab.dart, serialization_extensions.dart, tests futuros...)
  /// sigue funcionando exactamente igual, sin tocar nada fuera de este
  /// archivo.
  SpellScaling scaling;

  bool get isScalable => scaling.isScalable;
  set isScalable(bool value) => scaling = scaling.copyWith(isScalable: value);

  int get baseLevel => scaling.baseLevel;
  set baseLevel(int value) => scaling = scaling.copyWith(baseLevel: value);

  String? get scalingFormula => scaling.formula;
  set scalingFormula(String? value) => scaling = SpellScaling(
        isScalable: scaling.isScalable,
        baseLevel: scaling.baseLevel,
        formula: value,
      );

  /// true si el escalado configurado en este conjuro/habilidad realmente se
  /// puede resolver en combate (isScalable=true Y scalingFormula con un
  /// formato parseable). false si isScalable dice "sí escala" pero el JSON
  /// trae basura en scalingFormula — así una pantalla de ficha o un test
  /// pueden detectarlo sin repetir el regex a mano.
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
    SpellScaling? scaling,
  })  : scaling = scaling ??
            SpellScaling(isScalable: isScalable, baseLevel: baseLevel, formula: scalingFormula),
        magicCharges = magicCharges ?? MagicCharges.fromJson(null);

  factory Ability.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? 'Habilidad sin nombre';
    final id = json['id']?.toString() ?? 'ability_${name.hashCode}';
    final isScalable = json['is_scalable'] ?? false;
    final scalingFormula = json['scaling_formula'] as String?;

    // Hotfix (Blindaje del Escalado): si la habilidad dice que escala pero
    // la fórmula no tiene un formato reconocible, no reventamos el parseo
    // de toda la ficha por un solo campo del homebrewer — pero SÍ lo
    // delatamos aquí, al importar, en vez de dejar que se descubra en
    // combate cuando el escalado resulte mudo sin explicación.
    if (isScalable && scalingFormula != null && !_looksLikeValidDiceOrFlat(scalingFormula)) {
      // ignore: avoid_print
      print(
        '[Ability.fromJson] AVISO: "$name" (id=$id) trae scaling_formula '
        '"$scalingFormula" que no es ni notación de dado ("1d6", "2d4+3") '
        'ni un plano ("+3"). El escalado se resolverá como si no subiera '
        'de daño en combate — revisa el JSON de origen.',
      );
    }

    return Ability(
      // Red de seguridad: si el JSON viniera sin "id" (no debería pasar,
      // pero por si un homebrewer despistado se lo salta), generamos uno
      // estable a partir del nombre en vez de reventar el parseo — mismo
      // patrón que Weapon.fromJson.
      id: id,
      name: name,
      type: json['type'] ?? 'trait',
      relatedStat: json['related_stat'] ?? '',
      successDescription: json['success_description'] ?? '',
      failureDescription: json['failure_description'] ?? '',
      // Fallback seguro: fichas anteriores a este hotfix no traen
      // "attack_type" — se asumen de ataque (comportamiento previo, sin
      // aviso de CD de Salvación).
      attackType: json['attack_type'] ?? 'attack',
      isScalable: isScalable,
      baseLevel: json['base_level'] ?? 0,
      scalingFormula: scalingFormula,
      damageDice: json['damage_dice'],
      loreDescription: json['lore_description'],
      tacticalSummary: json['tactical_summary'],
      // Solo se espera en pasivas; si la habilidad es de acción/bonus/
      // reacción el JSON simplemente no lo trae y queda en null.
      tacticalRole: json['tactical_role'],
      magicCharges: MagicCharges.fromJson(json['magic_charges']),
    );
  }

  /// Serialización de vuelta a JSON. NOTA: magicCharges se deja fuera a
  /// propósito — no tengo weapon_model.dart delante para confirmar si
  /// MagicCharges ya expone su propio toJson() y con qué shape exacto.
  /// Si lo tiene, añade aquí algo como
  /// 'magic_charges': magicCharges.hasCharges ? magicCharges.toJson() : null.
  /// Si además ya existe un toJson() de Ability en serialization_extensions.dart
  /// (los comentarios del archivo lo mencionan como fichero aparte), añade
  /// 'tactical_role': tacticalRole también ahí para no tener dos fuentes de
  /// verdad divergentes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'related_stat': relatedStat,
      'success_description': successDescription,
      'failure_description': failureDescription,
      'attack_type': attackType,
      'damage_dice': damageDice,
      'lore_description': loreDescription,
      'tactical_summary': tacticalSummary,
      'tactical_role': tacticalRole,
      'is_scalable': isScalable,
      'base_level': baseLevel,
      'scaling_formula': scalingFormula,
    };
  }
}

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
}