// Modelos de arma. OJO: nada de "final" a machete aquí, porque las
// cargas mágicas y la cantidad se gastan o cambian en pleno combate y
// el árbol de widgets necesita poder mutarlas sin reconstruir el
// universo entero.
//
// Rework v2 — la cantidad vive DENTRO del arma. En la app vieja era un
// mapa global del provider indexado por weaponId (clave
// `weapon_quantity_<id>` en SharedPreferences), compartido entre
// todos los personajes del roster: dos fichas con el mismo arma se
// pisaban la cantidad entre sí. Ahora viaja serializada dentro de cada
// ficha, namespaceada de facto. La migración desde las claves viejas la
// hace RosterRepository al arrancar.

/// Daño base de un arma ("1d8+3" de tipo "cortante").
class WeaponDamage {
  String baseDice;
  String baseType;

  WeaponDamage({required this.baseDice, required this.baseType});

  factory WeaponDamage.fromJson(Map<String, dynamic> json) {
    return WeaponDamage(
      baseDice: json['base_dice'] ?? '0d0',
      baseType: json['base_type'] ?? 'desconocido',
    );
  }

  Map<String, dynamic> toJson() {
    return {'base_dice': baseDice, 'base_type': baseType};
  }
}

/// Daño condicional ("1d6 de fuego si el objetivo ya está quemado").
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
    // Acepta también las claves "condition"/"damage_dice"/"damage_type":
    // es el shape que el prompt de IA y el Nivel20Mapper escribían antes,
    // y que degradaba el daño a "0d0"/"desconocido" al leerlo.
    return ConditionalDamage(
      trigger: (json['trigger'] ?? json['condition'] ?? '') as String,
      dice: (json['dice'] ?? json['damage_dice'] ?? '0d0') as String,
      type: (json['type'] ?? json['damage_type'] ?? 'desconocido') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'trigger': trigger, 'dice': dice, 'type': type};
  }
}

/// Sistema Universal de Cargas: usos limitados de un objeto mágico
/// (una varita de 3 cargas, una habilidad de 2 usos por descanso...).
/// Compartida por Weapon y Ability a propósito: el shape JSON es
/// idéntico (has_charges/max/current) y así los descansos pueden
/// tratar ambas fuentes de forma simétrica.
class MagicCharges {
  bool hasCharges;
  int max;
  int current; // mutable: se consume al usar, no puede ser final.

  MagicCharges({
    required this.hasCharges,
    required this.max,
    required this.current,
  });

  /// Null-tolerante a propósito: la mayoría de las armas/habilidades no
  /// tienen cargas y el JSON directamente no trae la clave.
  factory MagicCharges.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MagicCharges(hasCharges: false, max: 0, current: 0);
    }
    return MagicCharges(
      hasCharges: json['has_charges'] ?? false,
      max: ((json['max'] as num?) ?? 0).toInt(),
      current: ((json['current'] as num?) ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'has_charges': hasCharges, 'max': max, 'current': current};
  }

  void consumeCharge() {
    if (current > 0) current--;
  }

  void restoreAll() {
    current = max;
  }
}

class Weapon {
  /// Clave estable para persistencia — nunca usar el nombre para esto
  /// (dos armas homebrew pueden compartir nombre).
  String id;
  String name;
  int attackBonus;
  WeaponDamage damage;
  List<ConditionalDamage> conditionalDamage;
  List<String> properties;
  String homebrewEffect;
  MagicCharges magicCharges;

  /// Qué le cuenta la historia al jugador según si el ataque acierta
  /// o falla (Protocolo de Dados).
  String successDescription;
  String failureDescription;

  /// Lore/flavor del arma y resumen táctico rápido. Nullable: un arma
  /// sin lore homebrew no debe forzar texto vacío en la UI.
  String? loreDescription;
  String? tacticalSummary;

  /// Armas únicas: objetos mágicos/legendarios que no se acumulan. Si
  /// es true, la UI oculta el stepper de cantidad (siempre vale 1).
  bool isUnique;

  /// Cantidad de copias de esta arma en el inventario DEL PERSONAJE al
  /// que pertenece (ver comentario de archivo). Los objetos únicos
  /// siempre valen 1, se fuerza tanto al leer como al escribir.
  int quantity;

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
    this.quantity = 1,
  });

  factory Weapon.fromJson(Map<String, dynamic> json) {
    final rawConditional = (json['conditional_damage'] as List<dynamic>?) ?? [];
    final rawProperties = (json['properties'] as List<dynamic>?) ?? [];
    final name = json['name'] ?? 'Arma sin nombre';
    // Se lee antes que quantity porque un arma única siempre vale 1.
    final isUnique = json['is_unique'] ?? false;

    return Weapon(
      // Red de seguridad: si el JSON viniera sin "id" (no debería
      // pasar, pero por si un homebrewer despistado se lo salta), se
      // genera uno estable a partir del nombre en vez de reventar el
      // parseo.
      id: json['id']?.toString() ?? 'weapon_${name.hashCode}',
      name: name,
      attackBonus: ((json['attack_bonus'] as num?) ?? 0).toInt(),
      damage: WeaponDamage.fromJson(
        (json['damage'] as Map<String, dynamic>?) ?? {},
      ),
      conditionalDamage: rawConditional
          .map((e) => ConditionalDamage.fromJson(e as Map<String, dynamic>))
          .toList(),
      properties: rawProperties.map((e) => e.toString()).toList(),
      homebrewEffect: json['homebrew_effect'] ?? '',
      magicCharges: MagicCharges.fromJson(
        json['magic_charges'] as Map<String, dynamic>?,
      ),
      successDescription: json['success_description'] ?? '',
      failureDescription: json['failure_description'] ?? '',
      loreDescription: json['lore_description'] as String?,
      tacticalSummary: json['tactical_summary'] as String?,
      isUnique: isUnique,
      // Rework v2: fichas de la app vieja no traen "quantity" — la
      // migración de RosterRepository la inyecta desde las claves
      // legacy. Para fichas nuevas el default es 1.
      quantity: isUnique ? 1 : ((json['quantity'] as num?) ?? 1).toInt(),
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
      'quantity': isUnique ? 1 : quantity,
    };
  }
}
