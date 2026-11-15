// Armas y armaduras del catálogo SRD 5e. Puro Dart (sin Flutter).

/// Un arma del SRD 5e.
class SrdWeapon {
  final String id;
  final String name;
  final String category; // 'sencilla' | 'marcial'
  final String rangeType; // 'melee' | 'ranged'
  final String? damageDice;
  final String? damageType;
  final List<String> properties;
  final String? versatileDice;
  final String rangeText;

  const SrdWeapon({
    required this.id,
    required this.name,
    required this.category,
    required this.rangeType,
    this.damageDice,
    this.damageType,
    this.properties = const [],
    this.versatileDice,
    this.rangeText = '',
  });

  bool hasProperty(String property) => properties.contains(property);

  factory SrdWeapon.fromJson(Map<String, dynamic> json) {
    return SrdWeapon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      category: json['category'] as String? ?? 'sencilla',
      rangeType: json['range_type'] as String? ?? 'melee',
      damageDice: json['damage_dice'] as String?,
      damageType: json['damage_type'] as String?,
      properties: ((json['properties'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
      versatileDice: json['versatile_dice'] as String?,
      rangeText: json['range_text'] as String? ?? '',
    );
  }
}

/// Una armadura (o escudo) del SRD 5e.
class SrdArmor {
  final String id;
  final String name;
  final String category; // 'ligera' | 'media' | 'pesada' | 'escudo'
  final int baseAc;
  final bool addDex;
  final int? maxDexBonus;
  final int? minStrength;
  final bool stealthDisadvantage;

  const SrdArmor({
    required this.id,
    required this.name,
    required this.category,
    required this.baseAc,
    this.addDex = false,
    this.maxDexBonus,
    this.minStrength,
    this.stealthDisadvantage = false,
  });

  factory SrdArmor.fromJson(Map<String, dynamic> json) {
    return SrdArmor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      category: json['category'] as String? ?? 'ligera',
      baseAc: ((json['base_ac'] as num?) ?? 10).toInt(),
      addDex: json['add_dex'] as bool? ?? false,
      maxDexBonus: (json['max_dex_bonus'] as num?)?.toInt(),
      minStrength: (json['min_strength'] as num?)?.toInt(),
      stealthDisadvantage: json['stealth_disadvantage'] as bool? ?? false,
    );
  }
}
