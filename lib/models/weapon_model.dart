// lib/models/weapon_model.dart
// Modelo de armas. OJO: nada de "final" a machete aquí, porque las cargas
// mágicas de un arma se gastan en pleno combate y el árbol de widgets
// necesita poder mutarlas sin reconstruir el universo entero.

class WeaponDamage {
  String baseDice;
  String baseType;

  WeaponDamage({
    required this.baseDice,
    required this.baseType,
  });

  factory WeaponDamage.fromJson(Map<String, dynamic> json) {
    return WeaponDamage(
      baseDice: json['base_dice'] ?? '0d0',
      baseType: json['base_type'] ?? 'desconocido',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_dice': baseDice,
      'base_type': baseType,
    };
  }
}

class ConditionalDamage {
  String trigger;
  String dice;
  String type;

  ConditionalDamage({
    required this.trigger,
    required this.dice,
    required this.type,
  });

  factory ConditionalDamage.fromJson(Map<String, dynamic> json) {
    return ConditionalDamage(
      trigger: json['trigger'] ?? '',
      dice: json['dice'] ?? '0d0',
      type: json['type'] ?? 'desconocido',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigger': trigger,
      'dice': dice,
      'type': type,
    };
  }
}

class MagicCharges {
  bool hasCharges;
  int max;
  int current; // mutable: se consume al usar el arma, no puede ser final.

  MagicCharges({
    required this.hasCharges,
    required this.max,
    required this.current,
  });

  factory MagicCharges.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MagicCharges(hasCharges: false, max: 0, current: 0);
    }
    return MagicCharges(
      hasCharges: json['has_charges'] ?? false,
      max: json['max'] ?? 0,
      current: json['current'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_charges': hasCharges,
      'max': max,
      'current': current,
    };
  }

  void consumeCharge() {
    if (current > 0) current--;
  }

  void restoreAll() {
    current = max;
  }
}

class Weapon {
  String id; // clave estable para persistencia — nunca usar el nombre para esto.
  String name;
  int attackBonus;
  WeaponDamage damage;
  List<ConditionalDamage> conditionalDamage;
  List<String> properties;
  String homebrewEffect;
  MagicCharges magicCharges;
  // Fase 5 — Protocolo de Dados: qué le cuenta la historia al jugador
  // según si el ataque acierta o falla.
  String successDescription;
  String failureDescription;
  // Paridad con Ability: lore/flavor del arma y resumen táctico, para que
  // TurnTab pueda mostrarlas igual que hace con conjuros y rasgos (antes
  // el modelo no traía estos campos y _weaponToEntry no tenía nada que
  // reenviar). Nullable como en Ability: un arma sin lore homebrew no
  // debe forzar texto vacío en la UI.
  String? loreDescription;
  String? tacticalSummary;
  // Fase 2 — Armas Únicas: objetos mágicos/legendarios que no se acumulan.
  // Si es true, la UI oculta el stepper de cantidad (siempre vale 1).
  bool isUnique;

  Weapon({
    required this.id,
    required this.name,
    required this.attackBonus,
    required this.damage,
    required this.conditionalDamage,
    required this.properties,
    required this.homebrewEffect,
    required this.magicCharges,
    required this.successDescription,
    required this.failureDescription,
    this.loreDescription,
    this.tacticalSummary,
    this.isUnique = false,
  });

  factory Weapon.fromJson(Map<String, dynamic> json) {
    final rawConditional = (json['conditional_damage'] as List<dynamic>?) ?? [];
    final rawProperties = (json['properties'] as List<dynamic>?) ?? [];
    final name = json['name'] ?? 'Arma sin nombre';

    return Weapon(
      // Red de seguridad: si el JSON viniera sin "id" (no debería pasar,
      // pero por si un homebrewer despistado se lo salta), generamos uno
      // estable a partir del nombre en vez de reventar el parseo.
      id: json['id']?.toString() ?? 'weapon_${name.hashCode}',
      name: name,
      attackBonus: json['attack_bonus'] ?? 0,
      damage: WeaponDamage.fromJson(json['damage'] ?? {}),
      conditionalDamage: rawConditional
          .map((e) => ConditionalDamage.fromJson(e as Map<String, dynamic>))
          .toList(),
      properties: rawProperties.map((e) => e.toString()).toList(),
      homebrewEffect: json['homebrew_effect'] ?? '',
      magicCharges: MagicCharges.fromJson(json['magic_charges']),
      successDescription: json['success_description'] ?? '',
      failureDescription: json['failure_description'] ?? '',
      loreDescription: json['lore_description'] as String?,
      tacticalSummary: json['tactical_summary'] as String?,
      isUnique: json['is_unique'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'attack_bonus': attackBonus,
      'damage': damage.toJson(),
      'conditional_damage': conditionalDamage.map((c) => c.toJson()).toList(),
      'properties': properties,
      'homebrew_effect': homebrewEffect,
      'magic_charges': magicCharges.toJson(),
      'success_description': successDescription,
      'failure_description': failureDescription,
      'lore_description': loreDescription,
      'tactical_summary': tacticalSummary,
      'is_unique': isUnique,
    };
  }
}