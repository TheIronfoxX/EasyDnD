// Los 6 atributos base del personaje y las competencias derivadas
// (skills). Son datos de ficha: no cambian en pleno combate como el HP,
// así que no hace falta la cautela mutable de Weapon — pero tampoco
// son const porque vienen parseadas de un JSON.
//
// Rework v2: cada clase trae su PROPIO toJson() — en la app vieja
// vivían en extensiones de serialization_extensions.dart, que era una
// fuente más de serialización divergente.

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
      value: ((json['value'] as num?) ?? 10).toInt(),
      mod: ((json['mod'] as num?) ?? 0).toInt(),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'mod': mod,
      'description': description,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'str': str.toJson(),
      'dex': dex.toJson(),
      'con': con.toJson(),
      'int': intelligence.toJson(),
      'wis': wis.toJson(),
      'cha': cha.toJson(),
    };
  }

  /// Orden estándar para pintar la cuadrícula de la pestaña Stats.
  List<AbilityScore> get asList => [str, dex, con, intelligence, wis, cha];
}

/// Una competencia derivada (Arcanos, Sigilo...) que ya trae su
/// modificador final calculado desde el JSON — no se recalcula a
/// partir de relatedStat + competencia porque la ficha no trae la
/// tabla de competencias. relatedStat solo agrupa visualmente.
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
      modifier: ((json['modifier'] as num?) ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'related_stat': relatedStat,
      'modifier': modifier,
    };
  }

  /// Modificador formateado con signo explícito: "+10", "+0", "-1".
  String get modifierFormatted => modifier >= 0 ? '+$modifier' : '$modifier';
}
