// El modelo de ficha completa. Mismo shape JSON que la app vieja
// (basic_info, inventory, abilities_by_action, stats, spell_slots,
// skills, lore_info, purse, resources, turn_status, active_conditions,
// companions) para que la migración del roster viejo sea transparente;
// lo nuevo del rework v2 es:
//   - "schema_version: 2" en la raíz (versionado para migraciones
//     futuras, en vez de fallbacks silenciosos por todas partes).
//   - Las armas serializan su "quantity" (ver weapon.dart).
//   - Las habilidades serializan sus "magic_charges" (ver ability.dart).
//
// Nota de mutabilidad: casi nada es final a propósito — el HUD muta
// HP, cargas, ranuras y condiciones en pleno combate y confía en que
// el store notifique y persista después de cada cambio.

import 'dart:convert';
import 'dart:math';

import '../../core/dnd_rules.dart';
import 'ability.dart';
import 'stats.dart';
import 'weapon.dart';

// currentHp es mutable: sube y baja cada dos por tres en combate.
// Si esto fuera "final" el HUD se rompería en el primer golpe recibido.
class BasicInfo {
  String name;
  String race;
  String characterClass;
  int hpMax;
  int currentHp;
  int ac;

  /// Nivel de personaje. Vive en "basic_info" como "level". Fallback en
  /// dos pasos si el JSON no lo trae: se intenta extraer el número del
  /// texto de characterClass ("Artillero 6" → 6) y solo si tampoco hay
  /// número ahí se cae a 1.
  int level;

  /// Velocidad de movimiento base, en pies por turno.
  /// 30 por defecto (velocidad humana estándar) para fichas anteriores
  /// a este campo.
  int speed;

  /// Enlace a la ficha del personaje en Nivel20 (nivel20.com). Null si
  /// el jugador todavía no lo vinculó.
  String? nivel20Link;

  /// CD de Salvación de conjuros, ya resuelta (8 + competencia + mod.
  /// de la característica de lanzamiento). A propósito NO se recalcula
  /// en la app: ese cálculo asumía que todas las habilidades de tipo
  /// "save" comparten la misma característica de lanzamiento, lo que
  /// rompía con multiclase o homebrew. Este es el número que trae la
  /// ficha y la app confía en él. Null para no-lanzadores.
  int? spellSaveDc;

  /// Caras del dado de golpe de la clase (6/8/10/12 en 5e). Fallback:
  /// se infiere de characterClass (ver DndRules.hitDieSidesFromClass),
  /// o d8 si tampoco eso.
  int hitDieSides;

  /// Total de dados de golpe — uno por nivel de personaje.
  int hitDiceMax;

  /// Dados de golpe sin gastar. Baja con cada descanso corto y sube
  /// (hasta la mitad de hitDiceMax) con un descanso largo.
  int hitDiceCurrent;

  /// Alineamiento en texto libre ("Legal bueno"). Vacío si no se cargó.
  String alignment;

  BasicInfo({
    required this.name,
    required this.race,
    required this.characterClass,
    required this.hpMax,
    required this.currentHp,
    required this.ac,
    this.level = 1,
    this.speed = 30,
    this.nivel20Link,
    this.spellSaveDc,
    int? hitDieSides,
    int? hitDiceMax,
    int? hitDiceCurrent,
    this.alignment = '',
  })  : hitDieSides = hitDieSides ?? DndRules.hitDieSidesFromClass(characterClass),
        hitDiceMax = hitDiceMax ?? level,
        hitDiceCurrent = hitDiceCurrent ?? (hitDiceMax ?? level);

  /// Bonificador de competencia según nivel (ver DndRules).
  int get proficiencyBonus => DndRules.proficiencyBonusFor(level);

  /// Cambia el máximo de PG manteniendo la coherencia del estado de
  /// combate: la vida actual se recorta si queda por encima del nuevo
  /// tope, pero nunca se "cura" sola al subirlo (eso lo hace el
  /// jugador desde el HUD si le corresponde).
  void setHpMax(int value) {
    hpMax = value;
    if (currentHp > value) currentHp = value;
  }

  /// Cambia el nivel manteniendo coherentes los dados de golpe: si el
  /// total era exactamente el nivel viejo (el caso normal: un dado por
  /// nivel), acompaña al nuevo; los gastados se recortan si quedan por
  /// encima del total. Si el total era custom (homebrew), se respeta.
  void setLevel(int value) {
    if (hitDiceMax == level) hitDiceMax = value;
    if (hitDiceCurrent > hitDiceMax) hitDiceCurrent = hitDiceMax;
    level = value;
  }

  factory BasicInfo.fromJson(Map<String, dynamic> json) {
    final hpMax = ((json['hp_max'] as num?) ?? 1).toInt();
    final characterClass = json['characterClass'] ?? '';
    return BasicInfo(
      name: json['name'] ?? 'Aventurero sin nombre',
      race: json['race'] ?? '',
      characterClass: characterClass,
      hpMax: hpMax,
      // El JSON de origen no trae hp_current: se arranca a full vida.
      currentHp: ((json['hp_current'] as num?) ?? hpMax).toInt(),
      ac: ((json['ac'] as num?) ?? 10).toInt(),
      level: (json['level'] as num?)?.toInt() ??
          DndRules.levelFromCharacterClass(characterClass),
      speed: (json['speed'] as num?)?.toInt() ?? 30,
      nivel20Link: json['nivel20_link'] as String?,
      spellSaveDc: (json['spell_save_dc'] as num?)?.toInt(),
      hitDieSides: (json['hit_die_sides'] as num?)?.toInt(),
      hitDiceMax: (json['hit_dice_max'] as num?)?.toInt(),
      hitDiceCurrent: (json['hit_dice_current'] as num?)?.toInt(),
      alignment: json['alignment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'race': race,
      'characterClass': characterClass,
      'hp_max': hpMax,
      'hp_current': currentHp,
      'ac': ac,
      'level': level,
      'speed': speed,
      'nivel20_link': nivel20Link,
      'spell_save_dc': spellSaveDc,
      'hit_die_sides': hitDieSides,
      'hit_dice_max': hitDiceMax,
      'hit_dice_current': hitDiceCurrent,
      'alignment': alignment,
    };
  }
}

/// Action Economy Tracker — estado de los recursos de acción del turno
/// actual. Los booleanos arrancan en false (disponible), se ponen a
/// true al gastarse y vuelven con resetTurn(). El movimiento no es
/// binario: es una cantidad que se va consumiendo a lo largo del
/// turno, con máximo siempre en BasicInfo.speed del personaje.
///
/// `reactionUsed` es aditivo respecto de la app vieja (que solo tenía
/// acción y adicional): la reacción también se recupera al inicio del
/// turno, así que el HUD la muestra y la resetea junto con las otras.
class TurnStatus {
  bool actionUsed;
  bool bonusActionUsed;
  bool reactionUsed;
  int movementRemaining;

  TurnStatus({
    this.actionUsed = false,
    this.bonusActionUsed = false,
    this.reactionUsed = false,
    this.movementRemaining = 9,
  });

  /// [maxSpeed] es BasicInfo.speed del personaje dueño — valor de
  /// arranque si la ficha todavía no trae "movementRemaining" guardado.
  factory TurnStatus.fromJson(Map<String, dynamic>? json, {required int maxSpeed}) {
    if (json == null) return TurnStatus(movementRemaining: maxSpeed);
    return TurnStatus(
      actionUsed: json['actionUsed'] ?? false,
      bonusActionUsed: json['bonusActionUsed'] ?? false,
      // Fichas viejas sin la clave: la reacción arranca disponible.
      reactionUsed: json['reactionUsed'] ?? false,
      movementRemaining: (json['movementRemaining'] as num?)?.toInt() ?? maxSpeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionUsed': actionUsed,
      'bonusActionUsed': bonusActionUsed,
      'reactionUsed': reactionUsed,
      'movementRemaining': movementRemaining,
    };
  }
}

/// Los 5 campos narrativos clásicos de ficha (tab Lore). Texto libre,
/// de sola lectura en el HUD.
class LoreInfo {
  String backstory;
  String personalityTraits;
  String ideals;
  String bonds;
  String flaws;

  LoreInfo({
    required this.backstory,
    required this.personalityTraits,
    required this.ideals,
    required this.bonds,
    required this.flaws,
  });

  factory LoreInfo.fromJson(Map<String, dynamic> json) {
    return LoreInfo(
      backstory: json['backstory'] ?? '',
      personalityTraits: json['personality_traits'] ?? '',
      ideals: json['ideals'] ?? '',
      bonds: json['bonds'] ?? '',
      flaws: json['flaws'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backstory': backstory,
      'personality_traits': personalityTraits,
      'ideals': ideals,
      'bonds': bonds,
      'flaws': flaws,
    };
  }
}

/// Objeto no mágico de inventario (raciones, cuerda, antorchas...).
/// Sin bonificadores de ataque ni cargas mágicas, a diferencia de
/// Weapon: solo nombre, descripción y cantidad.
class MundaneItem {
  String name;
  String description;
  int quantity;

  MundaneItem({
    required this.name,
    required this.description,
    required this.quantity,
  });

  factory MundaneItem.fromJson(Map<String, dynamic> json) {
    return MundaneItem(
      name: json['name'] ?? 'Objeto sin nombre',
      description: json['description'] ?? '',
      quantity: ((json['quantity'] as num?) ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'quantity': quantity,
    };
  }
}

class Inventory {
  List<Weapon> weapons;
  List<MundaneItem> mundaneItems;

  Inventory({required this.weapons, List<MundaneItem>? mundaneItems})
      : mundaneItems = mundaneItems ?? [];

  factory Inventory.fromJson(Map<String, dynamic> json) {
    final rawWeapons = (json['weapons'] as List<dynamic>?) ?? [];
    final rawMundaneItems = (json['mundane_items'] as List<dynamic>?) ?? [];
    return Inventory(
      weapons: rawWeapons
          .map((e) => Weapon.fromJson(e as Map<String, dynamic>))
          .toList(),
      mundaneItems: rawMundaneItems
          .map((e) => MundaneItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weapons': weapons.map((w) => w.toJson()).toList(),
      'mundane_items': mundaneItems.map((m) => m.toJson()).toList(),
    };
  }
}

/// Espacio de conjuro de un nivel concreto. "current" baja al lanzar
/// un conjuro escalado a ese nivel.
class SpellSlot {
  int level;
  int max;
  int current;

  SpellSlot({
    required this.level,
    required this.max,
    required this.current,
  });

  factory SpellSlot.fromJson(Map<String, dynamic> json) {
    final max = ((json['max'] as num?) ?? 0).toInt();
    return SpellSlot(
      level: ((json['level'] as num?) ?? 1).toInt(),
      max: max,
      // Sin "current" guardado (recién creado / a tope): arranca lleno,
      // igual que el HP.
      current: ((json['current'] as num?) ?? max).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'level': level, 'max': max, 'current': current};
  }
}

class SpellSlots {
  List<SpellSlot> slots;

  SpellSlots({required this.slots});

  factory SpellSlots.fromJson(dynamic raw) {
    if (raw == null) return SpellSlots(slots: []);
    return SpellSlots(
      slots: (raw as List<dynamic>)
          .map((e) => SpellSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Nivel máximo de ranura, o null si el personaje no es lanzador.
  int? get maxLevel {
    if (slots.isEmpty) return null;
    return slots.map((s) => s.level).reduce((a, b) => a > b ? a : b);
  }

  /// La ranura de un nivel concreto, o null si no tiene de ese nivel.
  SpellSlot? forLevel(int level) {
    for (final s in slots) {
      if (s.level == level) return s;
    }
    return null;
  }

  List<Map<String, dynamic>> toJson() => slots.map((s) => s.toJson()).toList();
}

/// Los tres tipos de moneda de la bolsa. Stacks independientes (sin
/// conversión automática) para no imponer reglas de casa que el
/// jugador no pidió.
enum CurrencyType { gold, silver, copper }

/// Bolsa de monedas del personaje. Cada denominación es un contador
/// independiente y nunca baja de cero (ver el store).
class Purse {
  int gold;
  int silver;
  int copper;

  /// Platino y electro: solo los edita el taller de fichas; el HUD de
  /// combate sigue mostrando oro, plata y cobre.
  int platinum;
  int electrum;

  Purse({
    this.gold = 0,
    this.silver = 0,
    this.copper = 0,
    this.platinum = 0,
    this.electrum = 0,
  });

  factory Purse.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Purse();
    return Purse(
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      silver: (json['silver'] as num?)?.toInt() ?? 0,
      copper: (json['copper'] as num?)?.toInt() ?? 0,
      platinum: (json['platinum'] as num?)?.toInt() ?? 0,
      electrum: (json['electrum'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gold': gold,
      'silver': silver,
      'copper': copper,
      'platinum': platinum,
      'electrum': electrum,
    };
  }

  /// Valor equivalente total en piezas de oro (1 po = 10 pp = 100 pc),
  /// solo como referencia visual — no colapsa los stacks reales.
  double get totalInGold =>
      platinum * 10 + gold + (electrum / 2) + (silver / 10) + (copper / 100);
}

/// Cualquier "pool" de puntos que un personaje gasta y recupera fuera
/// de las ranuras de conjuro (Ki, Hechicería, Furia por día,
/// Inspiración Bárdica...). Se identifica por nombre y no por id
/// estable porque el jugador puede crearlos libremente — dos
/// personajes pueden tener un recurso con el mismo nombre sin que eso
/// sea un conflicto (a diferencia del id de un arma).
class ResourcePoint {
  String name;
  int current;
  int max;

  /// Cuándo se recupera: 'short_rest' | 'long_rest' | 'manual'. Los
  /// descansos del HUD todavía no lo consumen; es dato de la ficha.
  String recovery;

  ResourcePoint({
    required this.name,
    required this.current,
    required this.max,
    this.recovery = 'manual',
  });

  factory ResourcePoint.fromJson(Map<String, dynamic> json) {
    final max = ((json['max'] as num?) ?? 0).toInt();
    return ResourcePoint(
      name: json['name'] ?? 'Recurso sin nombre',
      current: (json['current'] as num?)?.toInt() ?? max,
      max: max,
      recovery: json['recovery'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'current': current,
      'max': max,
      'recovery': recovery,
    };
  }
}

/// Mascotas / invocaciones / compañeros del personaje. `hasHp`
/// distingue entidades vulnerables (con barra de vida gestionable
/// desde el HUD) de entidades de apoyo invulnerables (familiares
/// narrativos): cuando es false, currentHp/maxHp se ignoran en la UI
/// aunque sigan viajando en el modelo.
class Companion {
  String name;
  String type;
  bool hasHp;
  int currentHp;
  int maxHp;
  int ac;

  Companion({
    required this.name,
    required this.type,
    this.hasHp = true,
    this.currentHp = 0,
    this.maxHp = 0,
    this.ac = 10,
  });

  factory Companion.fromJson(Map<String, dynamic> json) {
    final maxHp = (json['max_hp'] as num?)?.toInt() ?? 0;
    return Companion(
      name: json['name'] ?? 'Aliado sin nombre',
      type: json['type'] ?? '',
      hasHp: json['has_hp'] ?? true,
      currentHp: (json['current_hp'] as num?)?.toInt() ?? maxHp,
      maxHp: maxHp,
      ac: (json['ac'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'has_hp': hasHp,
      'current_hp': currentHp,
      'max_hp': maxHp,
      'ac': ac,
    };
  }
}

class CharacterModel {
  /// Versión del shape JSON de la ficha. v2 = rework (armas con
  /// "quantity" y habilidades con "magic_charges" serializados). Las
  /// migraciones futuras leen esto para saber qué arreglar.
  static const int schemaVersion = 2;

  /// Identificador ESTABLE y único del personaje, independiente de su
  /// nombre (que el jugador puede cambiar o repetir entre fichas).
  /// `final`: una vez asignado no se reescribe nunca — cualquier dato
  /// namespaceado por personaje depende de que no cambie bajo los pies.
  final String id;

  BasicInfo basicInfo;
  Inventory inventory;
  AbilitiesByAction abilitiesByAction;
  StatsBlock stats;
  SpellSlots spellSlots;

  /// Lista plana de competencias (Arcanos, Sigilo...). Ficha vieja sin
  /// el campo → lista vacía y la pestaña Stats no pinta la sección.
  List<Skill> skills;

  /// Bloque narrativo (trasfondo, rasgos, ideales, vínculos, defectos).
  LoreInfo loreInfo;

  /// Ruta local (galería del dispositivo) de la foto de perfil.
  String? avatarPath;

  /// Foto de la pestaña Lore: ruta independiente de avatarPath. Null
  /// mientras el jugador no la fije a mano; la UI de Lore cae en
  /// avatarPath como default SIN copiarlo, así cambiar la foto de
  /// perfil no congela la de Lore.
  String? loreAvatarPath;

  Purse purse;

  /// Códice / Diario. Tres campos de texto libre:
  ///  - aiTips: notas generadas por IA (solo lectura en el HUD).
  ///  - userTactics: notas del jugador sobre cómo jugar la ficha.
  ///  - adventureNotes: diario de aventura de formato libre.
  String aiTips;
  String userTactics;
  String adventureNotes;

  /// Pools genéricos de puntos (Ki, Hechicería, Furia...).
  List<ResourcePoint> resources;

  /// Estado de acción/adicional/movimiento del turno en curso.
  TurnStatus turnStatus;

  /// Nombres de condiciones activas (Apresado, Envenenado...). El
  /// detalle mecánico de cada una NO se guarda acá — vive en el
  /// catálogo estático DndRules.conditions para no duplicar datos de
  /// reglas en cada ficha serializada.
  List<String> activeConditions;

  List<Companion> companions;

  CharacterModel({
    String? id,
    required this.basicInfo,
    required this.inventory,
    required this.abilitiesByAction,
    required this.stats,
    required this.spellSlots,
    required this.skills,
    required this.loreInfo,
    this.avatarPath,
    this.loreAvatarPath,
    Purse? purse,
    this.aiTips = '',
    this.userTactics = '',
    this.adventureNotes = '',
    List<ResourcePoint>? resources,
    TurnStatus? turnStatus,
    List<String>? activeConditions,
    List<Companion>? companions,
  })  : id = id ?? _generateId(),
        purse = purse ?? Purse(),
        resources = resources ?? [],
        // Sin turnStatus explícito (ej. personaje recién creado), el
        // movimiento arranca a tope según la velocidad real de ESE
        // personaje — no un 9 fijo que solo casaba por casualidad con
        // la velocidad humana estándar.
        turnStatus =
            turnStatus ?? TurnStatus(movementRemaining: basicInfo.speed),
        activeConditions = activeConditions ?? [],
        companions = companions ?? [];

  /// Id de fallback para fichas importadas sin uno (las guardadas por
  /// la app vieja antes de que existiera el campo). No es un UUID de
  /// verdad para no sumar dependencias: timestamp + aleatorio, suficiente
  /// para no colisionar en un roster local. Importante: RosterRepository
  /// persiste inmediatamente después de cargar para que este id quede
  /// fijo desde el primer arranque y no cambie en cada reinicio.
  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(0x7FFFFFFF);
    return 'char_${timestamp}_$random';
  }

  /// Cambia la velocidad base manteniendo coherente el movimiento del
  /// turno en curso: si quedaba más movimiento que la nueva velocidad,
  /// se recorta (nunca se "regala" movimiento al subirla a mitad de
  /// turno).
  void setSpeed(int value) {
    basicInfo.speed = value;
    if (turnStatus.movementRemaining > value) {
      turnStatus.movementRemaining = value;
    }
  }

  /// Copia profunda e INDEPENDIENTE de la ficha. La usa el editor
  /// manual (Etapa 4): edita una copia y recién al confirmar la
  /// commitea al roster, así cerrar el editor a mitad de cambios no
  /// corrompe la ficha guardada.
  ///
  /// Va por roundtrip JSON a propósito: pasa por la MISMA
  /// deserialización que el guardado/carga, así la copia queda
  /// normalizada exactamente igual que la ficha que va a reemplazar
  /// (mismos fallbacks, mismo orden de claves).
  CharacterModel copy() => CharacterModel.fromJson(
        (jsonDecode(jsonEncode(toJson())) as Map).cast<String, dynamic>(),
      );

  /// Ficha en blanco para el alta manual (Etapa 4): lo mínimo jugable
  /// — PG 10, CA 10, velocidad humana, atributos 10/+0, todo lo demás
  /// vacío — con nombre placeholder. Pasa la validación sin ningún
  /// aviso (ver test): es una ficha "válida pero por llenar".
  factory CharacterModel.blank() => CharacterModel(
        basicInfo: BasicInfo(
          name: 'Aventurero sin nombre',
          race: '',
          characterClass: '',
          hpMax: 10,
          currentHp: 10,
          ac: 10,
        ),
        inventory: Inventory(weapons: [], mundaneItems: []),
        abilitiesByAction: AbilitiesByAction(
          action: [],
          bonusAction: [],
          reaction: [],
          passive: [],
        ),
        stats: StatsBlock(
          str: _blankScore('Fuerza'),
          dex: _blankScore('Destreza'),
          con: _blankScore('Constitución'),
          intelligence: _blankScore('Inteligencia'),
          wis: _blankScore('Sabiduría'),
          cha: _blankScore('Carisma'),
        ),
        spellSlots: SpellSlots(slots: []),
        skills: [],
        loreInfo: LoreInfo(
          backstory: '',
          personalityTraits: '',
          ideals: '',
          bonds: '',
          flaws: '',
        ),
      );

  static AbilityScore _blankScore(String name) =>
      AbilityScore(name: name, value: 10, mod: 0, description: '');

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    final rawSkills = (json['skills'] as List<dynamic>?) ?? [];
    final rawResources = (json['resources'] as List<dynamic>?) ?? [];
    final basicInfo = BasicInfo.fromJson(
      (json['basic_info'] as Map<String, dynamic>?) ?? {},
    );
    return CharacterModel(
      id: json['id'] as String?,
      basicInfo: basicInfo,
      inventory: Inventory.fromJson(
        (json['inventory'] as Map<String, dynamic>?) ?? {},
      ),
      abilitiesByAction: AbilitiesByAction.fromJson(
        (json['abilities_by_action'] as Map<String, dynamic>?) ?? {},
      ),
      stats: StatsBlock.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? {},
      ),
      spellSlots: SpellSlots.fromJson(json['spell_slots']),
      skills: rawSkills
          .map((e) => Skill.fromJson(e as Map<String, dynamic>))
          .toList(),
      loreInfo: LoreInfo.fromJson(
        (json['lore_info'] as Map<String, dynamic>?) ?? {},
      ),
      avatarPath: json['avatar_path'] as String?,
      loreAvatarPath: json['lore_avatar_path'] as String?,
      purse: Purse.fromJson(json['purse'] as Map<String, dynamic>?),
      aiTips: json['ai_tips'] ?? '',
      userTactics: json['user_tactics'] ?? '',
      adventureNotes: json['adventure_notes'] ?? '',
      resources: rawResources
          .map((e) => ResourcePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      turnStatus: TurnStatus.fromJson(
        json['turn_status'] as Map<String, dynamic>?,
        maxSpeed: basicInfo.speed,
      ),
      activeConditions:
          (json['active_conditions'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      companions: ((json['companions'] as List<dynamic>?) ?? const [])
          .map((e) => Companion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'id': id,
      'basic_info': basicInfo.toJson(),
      'inventory': inventory.toJson(),
      'abilities_by_action': abilitiesByAction.toJson(),
      'stats': stats.toJson(),
      'spell_slots': spellSlots.toJson(),
      'skills': skills.map((s) => s.toJson()).toList(),
      'lore_info': loreInfo.toJson(),
      'avatar_path': avatarPath,
      'lore_avatar_path': loreAvatarPath,
      'purse': purse.toJson(),
      'ai_tips': aiTips,
      'user_tactics': userTactics,
      'adventure_notes': adventureNotes,
      'resources': resources.map((r) => r.toJson()).toList(),
      'turn_status': turnStatus.toJson(),
      'active_conditions': activeConditions,
      'companions': companions.map((c) => c.toJson()).toList(),
    };
  }
}
