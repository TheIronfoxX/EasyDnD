// Clase del catálogo SRD 5e. Puro Dart (sin Flutter).
// Los atributos usan los slugs en español del catálogo: fue, des, con, int, sab, car.

/// Recurso con usos limitados de un rasgo (Furia, Ki, etc.).
class SrdClassResource {
  final String name;
  final String maxFormula;
  final String recovery; // 'short_rest' | 'long_rest'

  const SrdClassResource({
    required this.name,
    required this.maxFormula,
    required this.recovery,
  });

  factory SrdClassResource.fromJson(Map<String, dynamic> json) {
    return SrdClassResource(
      name: json['name'] as String? ?? '',
      maxFormula: json['max_formula'] as String? ?? '',
      recovery: json['recovery'] as String? ?? 'long_rest',
    );
  }
}

/// Rasgo inicial (niveles 1 a 3) de una clase.
class SrdClassFeature {
  final String name;
  final int level;
  final String actionType; // 'action' | 'bonus_action' | 'reaction' | 'passive'
  final String? tacticalRole; // solo en pasivas
  final String description;
  final SrdClassResource? resource;

  const SrdClassFeature({
    required this.name,
    required this.level,
    required this.actionType,
    this.tacticalRole,
    required this.description,
    this.resource,
  });

  factory SrdClassFeature.fromJson(Map<String, dynamic> json) {
    final res = json['resource'];
    return SrdClassFeature(
      name: json['name'] as String? ?? '',
      level: ((json['level'] as num?) ?? 1).toInt(),
      actionType: json['action_type'] as String? ?? 'passive',
      tacticalRole: json['tactical_role'] as String?,
      description: json['description'] as String? ?? '',
      resource: res is Map<String, dynamic> ? SrdClassResource.fromJson(res) : null,
    );
  }
}

/// Una clase del SRD 5e.
class SrdClass {
  final String id;
  final String name;
  final int hitDie;
  final List<String> primaryAbilities;
  final List<String> savingThrows;
  final int skillChoicesCount;
  final List<String> skillOptions;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final String spellcastingType; // 'full' | 'half' | 'third' | 'pact' | 'none'
  final String? spellcastingAbility; // 'int' | 'sab' | 'car' | null
  final String? spellListTag;
  final List<SrdClassFeature> coreFeatures;

  const SrdClass({
    required this.id,
    required this.name,
    required this.hitDie,
    this.primaryAbilities = const [],
    this.savingThrows = const [],
    this.skillChoicesCount = 0,
    this.skillOptions = const [],
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.spellcastingType = 'none',
    this.spellcastingAbility,
    this.spellListTag,
    this.coreFeatures = const [],
  });

  bool get isSpellcaster => spellcastingType != 'none';

  factory SrdClass.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        ((json[key] as List<dynamic>?) ?? const []).map((e) => e as String).toList();
    return SrdClass(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      hitDie: ((json['hit_die'] as num?) ?? 8).toInt(),
      primaryAbilities: strings('primary_abilities'),
      savingThrows: strings('saving_throws'),
      skillChoicesCount: ((json['skill_choices_count'] as num?) ?? 0).toInt(),
      skillOptions: strings('skill_options'),
      armorProficiencies: strings('armor_proficiencies'),
      weaponProficiencies: strings('weapon_proficiencies'),
      spellcastingType: json['spellcasting_type'] as String? ?? 'none',
      spellcastingAbility: json['spellcasting_ability'] as String?,
      spellListTag: json['spell_list_tag'] as String?,
      coreFeatures: ((json['core_features'] as List<dynamic>?) ?? const [])
          .map((e) => SrdClassFeature.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
