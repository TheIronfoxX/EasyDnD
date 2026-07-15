// Las 6 estadísticas base del personaje. Son datos de ficha: no cambian
// en pleno combate como el HP, así que no hace falta la misma cautela
// mutable que en weapon_model — pero tampoco las hacemos const porque
// vienen parseadas de un JSON, no son literales del código fuente.

class AbilityScore {
  String name;
  int value;
  int mod;
  String description;

  AbilityScore({
    required this.name,
    required this.value,
    required this.mod,
    required this.description,
  });

  factory AbilityScore.fromJson(Map<String, dynamic> json) {
    return AbilityScore(
      name: json['name'] ?? '???',
      value: json['value'] ?? 10,
      mod: json['mod'] ?? 0,
      description: json['description'] ?? '',
    );
  }

  /// Modificador formateado con signo explícito: "+5", "+0", "-1".
  String get modFormatted => mod >= 0 ? '+$mod' : '$mod';
}

class StatsBlock {
  AbilityScore str;
  AbilityScore dex;
  AbilityScore con;
  AbilityScore intelligence; // "int" es palabra reservada en Dart.
  AbilityScore wis;
  AbilityScore cha;

  StatsBlock({
    required this.str,
    required this.dex,
    required this.con,
    required this.intelligence,
    required this.wis,
    required this.cha,
  });

  factory StatsBlock.fromJson(Map<String, dynamic> json) {
    AbilityScore parse(String key) =>
        AbilityScore.fromJson((json[key] as Map<String, dynamic>?) ?? {});

    return StatsBlock(
      str: parse('str'),
      dex: parse('dex'),
      con: parse('con'),
      intelligence: parse('int'),
      wis: parse('wis'),
      cha: parse('cha'),
    );
  }

  /// Orden estándar para pintar la cuadrícula de la pestaña Stats.
  List<AbilityScore> get asList => [str, dex, con, intelligence, wis, cha];
}

// Fase 8 — Matriz de Habilidades: a diferencia de AbilityScore (los 6
// atributos base), una Skill es una competencia derivada (Arcanos,
// Sigilo...) que ya trae su modificador final calculado desde el JSON —
// no lo recalculamos a partir de relatedStat + proficiency porque esa
// tabla de competencias todavía no existe en la ficha. relatedStat solo
// se usa hoy para elegir el icono/agrupación visual en stats_tab.dart.
class Skill {
  String name;
  String relatedStat; // 'str', 'dex', 'con', 'int', 'wis', 'cha'.
  int modifier;

  Skill({
    required this.name,
    required this.relatedStat,
    required this.modifier,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      name: json['name'] ?? 'Habilidad sin nombre',
      relatedStat: json['related_stat'] ?? '',
      modifier: json['modifier'] ?? 0,
    );
  }

  /// Modificador formateado con signo explícito: "+10", "+0", "-1".
  String get modifierFormatted => modifier >= 0 ? '+$modifier' : '$modifier';
}
