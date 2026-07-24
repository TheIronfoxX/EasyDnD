// lib/models/character_model.dart
import 'dart:math';

import 'weapon_model.dart';
import 'ability_model.dart';
import 'stats_model.dart';
import 'serialization_extensions.dart'; // toJson() de Weapon/Ability/AbilitiesByAction/StatsBlock/Skill

// currentHp es mutable: sube y baja cada dos por tres en combate.
// Si esto fuera "final" el HUD se rompería en el primer golpe recibido.
class BasicInfo {
  String name;
  String race;
  String characterClass;
  int hpMax;
  int currentHp;
  int ac;
  // Hotfix (CD de Salvación mal calculada): nivel de personaje. Vive en
  // "basic_info" como "level". Antes de este hotfix no existía en ningún
  // punto del modelo, así que el bonificador de competencia nunca se
  // sumaba a nada (ni a la CD de salvación, ni al modificador mostrado
  // junto a cada conjuro/rasgo en turn_tab.dart) — solo se usaba el
  // modificador puro de característica. Fallback a 1 para fichas
  // anteriores a este campo.
  int level;
  // Velocidad de movimiento base, en metros por turno (no en pies).
  // Opcional en el constructor con 9 por defecto (la velocidad humana
  // estándar) para no romper otros puntos donde ya se construye
  // BasicInfo sin conocer este campo (p.ej. mock_data.dart), igual que
  // se hizo con nivel20Link.
  int speed;
  // Integración Nivel20: enlace a la ficha del personaje en la plataforma
  // Nivel20 (nivel20.com). Null si el jugador todavía no lo ha vinculado.
  // Vive en "basic_info" como "nivel20_link" — opcional para no romper
  // el parseo de fichas anteriores a esta integración.
  String? nivel20Link;
  // CD de Salvación de conjuros, ya resuelta (8 + competencia + mod. de la
  // característica de lanzamiento). Vive en "basic_info" como
  // "spell_save_dc". A propósito NO se recalcula en la app a partir del
  // related_stat de cada Ability (como hacía antes turn_tab.dart): ese
  // cálculo asumía que todas las habilidades de tipo "save" comparten la
  // misma característica de lanzamiento, lo que rompía con multiclase o
  // rasgos homebrew. Este campo es el número que ya trae la ficha/JSON,
  // así que es la app la que confía en él en vez de reconstruirlo.
  // Null para personajes que no lanzan conjuros o fichas anteriores a este
  // campo — en ese caso turn_tab.dart no pinta ningún aviso de CD.
  int? spellSaveDc;

  // Descanso Corto (Reserva de Dados de Golpe): caras del dado de golpe de
  // la clase (6/8/10/12 en 5e). Vive en "basic_info" como
  // "hit_die_sides". Fallback a 8 (el más común entre las clases) si la
  // ficha no lo trae explícito y no se pudo inferir de "characterClass" —
  // ver _hitDieSidesFromClass más abajo.
  int hitDieSides;
  // Total de Dados de Golpe que tiene el personaje — en 5e, uno por nivel
  // de personaje. Vive en "basic_info" como "hit_dice_max". Fallback al
  // "level" ya resuelto si la ficha no lo trae.
  int hitDiceMax;
  // Dados de Golpe que le quedan sin gastar al personaje. Mutable: baja
  // al usar un Descanso Corto y sube (hasta la mitad de hitDiceMax) con
  // un Descanso Largo. Vive en "basic_info" como "hit_dice_current".
  // Fallback al máximo si la ficha no lo trae (arranca a tope, igual que
  // currentHp con hpMax).
  int hitDiceCurrent;

  BasicInfo({
    required this.name,
    required this.race,
    required this.characterClass,
    required this.hpMax,
    required this.currentHp,
    required this.ac,
    this.level = 1,
    this.speed = 9,
    this.nivel20Link,
    this.spellSaveDc,
    int? hitDieSides,
    int? hitDiceMax,
    int? hitDiceCurrent,
  })  : hitDieSides = hitDieSides ?? _hitDieSidesFromClass(characterClass),
        hitDiceMax = hitDiceMax ?? level,
        hitDiceCurrent = hitDiceCurrent ?? (hitDiceMax ?? level);

  /// Bonificador de competencia estándar de D&D 5e según nivel de
  /// personaje (2 en niveles 1-4, 3 en 5-8, 4 en 9-12, 5 en 13-16, 6 en
  /// 17-20). Es lo que faltaba sumar a la CD de salvación y al
  /// modificador de conjuros/rasgos: antes de este hotfix solo se usaba
  /// el modificador puro de característica (ver _abilityToEntry en
  /// turn_tab.dart), por eso un clérigo Nv.11 con Sabiduría +5 mostraba
  /// CD 13 (8+5) en vez de CD 17 (8+5+4 de competencia).
  int get proficiencyBonus => 2 + ((level.clamp(1, 20) - 1) ~/ 4);

  /// Hotfix (Competencia Fantasma / "el bug del 14 en vez del 15"):
  /// muchas fichas (ej. Jiseol, "Artillero 6") no traen un campo "level"
  /// numérico propio — el nivel real solo existe como texto pegado al
  /// final de "characterClass". Antes de este hotfix, esas fichas caían
  /// directas al fallback `?? 1` de más abajo, así que un personaje de
  /// nivel 6 se calculaba con competencia de nivel 1 (+2 en vez de +3),
  /// y tanto la CD de salvación como el modificador de conjuros/rasgos en
  /// turn_tab.dart salían un punto por debajo de lo correcto.
  ///
  /// Este parser busca el último número que aparece en el string (ej.
  /// "Artillero 6" -> 6, "Druida 12" -> 12) en vez de asumir nivel 1 a
  /// ciegas. Si no encuentra ningún número, sí que asume 1 — igual que el
  /// comportamiento anterior — porque no hay ninguna pista mejor de la
  /// que tirar.
  static int _levelFromCharacterClass(String characterClass) {
    final match = RegExp(r'(\d+)\s*$').firstMatch(characterClass.trim());
    if (match == null) return 1;
    return int.tryParse(match.group(1)!) ?? 1;
  }

  /// Infiera el dado de golpe (caras) a partir del texto libre de
  /// "characterClass" cuando la ficha no trae "hit_die_sides" explícito
  /// — mismo espíritu que _levelFromCharacterClass: mejor una inferencia
  /// razonable que asumir un valor a ciegas. Busca el nombre de clase
  /// como substring (case-insensitive), así "Bárbaro 6" o "Artillero
  /// (Bárbaro)" siguen encontrando la clase aunque venga acompañada de
  /// más texto. Si no reconoce ninguna clase, cae a d8 — el dado más
  /// común entre las clases de 5e.
  static int _hitDieSidesFromClass(String characterClass) {
    final normalized = characterClass.toLowerCase();
    const d12Classes = ['bárbaro', 'barbaro'];
    const d10Classes = ['guerrero', 'paladín', 'paladin', 'explorador', 'ranger'];
    const d8Classes = [
      'clérigo', 'clerigo', 'druida', 'monje', 'pícaro', 'picaro',
      'bardo', 'brujo', 'artillero', 'artífice', 'artifice',
    ];
    const d6Classes = ['hechicero', 'mago', 'sorcerer', 'wizard'];

    for (final name in d12Classes) {
      if (normalized.contains(name)) return 12;
    }
    for (final name in d10Classes) {
      if (normalized.contains(name)) return 10;
    }
    for (final name in d6Classes) {
      if (normalized.contains(name)) return 6;
    }
    for (final name in d8Classes) {
      if (normalized.contains(name)) return 8;
    }
    return 8;
  }

  factory BasicInfo.fromJson(Map<String, dynamic> json) {
    final hpMax = json['hp_max'] ?? 1;
    final characterClass = json['characterClass'] ?? '';
    return BasicInfo(
      name: json['name'] ?? 'Aventurero sin nombre',
      // Fase 9 — Identidad: si la ficha no trae raza/clase (personaje
      // pre-Fase-9), quedan vacías y el subtítulo del header simplemente
      // no se pinta (ver main_hud_screen.dart).
      race: json['race'] ?? '',
      characterClass: characterClass,
      hpMax: hpMax,
      // El JSON de origen no trae hp_current, así que arrancamos a full vida.
      currentHp: json['hp_current'] ?? hpMax,
      ac: json['ac'] ?? 10,
      // Fallback en dos pasos: si el JSON trae "level" explícito, se usa
      // tal cual (fichas nuevas / ya migradas). Si no, en vez de asumir
      // nivel 1 directamente, se intenta extraer el número de
      // "characterClass" (fichas como la de Jiseol, "Artillero 6"). Solo
      // si tampoco hay número ahí, se cae a nivel 1 de verdad.
      level: (json['level'] as num?)?.toInt() ??
          _levelFromCharacterClass(characterClass),
      // Fallback seguro: fichas anteriores a este campo no traen "speed"
      // — 9 metros (la velocidad humana estándar) en vez de romper el
      // parseo o dejar al personaje inmóvil con un 0.
      speed: (json['speed'] as num?)?.toInt() ?? 9,
      // Fallback seguro: fichas anteriores a esta integración no traen
      // "nivel20_link" — queda null en vez de romper el parseo.
      nivel20Link: json['nivel20_link'] as String?,
      // Fallback seguro: fichas anteriores a este campo, o de personajes
      // sin conjuros, no traen "spell_save_dc" — queda null en vez de
      // romper el parseo (turn_tab.dart simplemente no pinta el aviso).
      spellSaveDc: (json['spell_save_dc'] as num?)?.toInt(),
      // Fallback seguro: fichas anteriores al Descanso Corto no traen
      // estas claves — se infiere el dado según la clase (o d8) y el
      // máximo de dados según el nivel ya resuelto, arrancando a tope
      // (igual que currentHp con hpMax).
      hitDieSides: (json['hit_die_sides'] as num?)?.toInt(),
      hitDiceMax: (json['hit_dice_max'] as num?)?.toInt(),
      hitDiceCurrent: (json['hit_dice_current'] as num?)?.toInt(),
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
    };
  }
}

/// Action Economy Tracker — estado de los recursos de acción del turno
/// actual (acción, acción adicional, movimiento). Los dos booleanos
/// arrancan en `false` (recurso disponible); se ponen a `true` cuando el
/// jugador los gasta y vuelven a `false` con resetTurn() al terminar el
/// turno. Vive en la raíz del JSON como "turn_status".
///
/// Refactor "Reacción -> Movimiento": el antiguo `reactionUsed` (bool) se
/// sustituye por `movementRemaining` (int), porque el movimiento no es un
/// recurso binario gastado/disponible sino una cantidad que se va
/// consumiendo a lo largo del turno (ver turn_tab.dart, _MovementTile).
/// No lleva su propio "máximo": el máximo siempre es
/// BasicInfo.speed del personaje — guardarlo aparte solo lo
/// desincronizaría si el jugador sube de nivel o cambia de raza/velocidad.
class TurnStatus {
  bool actionUsed;
  bool bonusActionUsed;
  int movementRemaining;

  TurnStatus({
    this.actionUsed = false,
    this.bonusActionUsed = false,
    this.movementRemaining = 9,
  });

  /// [maxSpeed] es BasicInfo.speed del personaje al que pertenece este
  /// TurnStatus — se usa como valor de arranque si la ficha todavía no
  /// trae "movementRemaining" guardado (fichas anteriores a este campo, o
  /// justo después de crear el personaje), en vez de un número fijo que
  /// podría no coincidir con la velocidad real del personaje.
  factory TurnStatus.fromJson(Map<String, dynamic>? json, {required int maxSpeed}) {
    // Fallback seguro: fichas anteriores a este módulo no traen
    // "turn_status" — arrancan con acción/adicional disponibles y el
    // movimiento a tope.
    if (json == null) return TurnStatus(movementRemaining: maxSpeed);
    return TurnStatus(
      actionUsed: json['actionUsed'] ?? false,
      bonusActionUsed: json['bonusActionUsed'] ?? false,
      // Fallback seguro: fichas guardadas con el antiguo "reactionUsed"
      // (o sin ningún dato de movimiento todavía) arrancan a velocidad
      // completa en vez de a 0 — un personaje recién migrado no debería
      // aparecer como si ya hubiera gastado todo su movimiento.
      movementRemaining: (json['movementRemaining'] as num?)?.toInt() ?? maxSpeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionUsed': actionUsed,
      'bonusActionUsed': bonusActionUsed,
      'movementRemaining': movementRemaining,
    };
  }
}

// Fase 10 — Pestaña de Lore: los 5 campos narrativos clásicos de ficha
// (trasfondo, rasgos de personalidad, ideales, vínculos y defectos). Son
// texto libre, de sola lectura en el HUD — no hay UI todavía para editarlos.
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

/// Mundane Items Inventory — objeto no mágico de inventario (raciones,
/// cuerda, antorchas, herramientas...). Sin bonificadores de ataque ni
/// cargas mágicas, a diferencia de Weapon: solo nombre, descripción y
/// una cantidad que sube o baja libremente.
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
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
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
    // Fallback seguro: inventarios anteriores a este módulo no traen
    // "mundane_items" — lista vacía en vez de romper el parseo.
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

  // Requiere que Weapon tenga su propio toJson() — ver
  // serialization_extensions.dart si weapon_model.dart no lo trae aún.
  Map<String, dynamic> toJson() {
    return {
      'weapons': weapons.map((w) => w.toJson()).toList(),
      'mundane_items': mundaneItems.map((m) => m.toJson()).toList(),
    };
  }
}

// Fase 6: espacios de conjuro. "current" es mutable y baja cada vez que se
// lanza un conjuro escalable a ese nivel — no puede ser "final" por la
// misma razón que currentHp o las cargas mágicas de un arma.
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
    final max = json['max'] ?? 0;
    return SpellSlot(
      level: json['level'] ?? 1,
      max: max,
      // Si el JSON no trae "current" (personaje recién creado / a tope),
      // arrancamos con la ranura llena, igual que hacemos con el HP.
      current: json['current'] ?? max,
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

  /// Nivel máximo de ranura que tiene el personaje, o null si no tiene
  /// ninguna ranura de conjuro (personaje no lanzador).
  int? get maxLevel {
    if (slots.isEmpty) return null;
    return slots.map((s) => s.level).reduce((a, b) => a > b ? a : b);
  }

  /// Busca la ranura de un nivel concreto. Null si el personaje no tiene
  /// ranuras de ese nivel.
  SpellSlot? forLevel(int level) {
    for (final s in slots) {
      if (s.level == level) return s;
    }
    return null;
  }

  List<Map<String, dynamic>> toJson() => slots.map((s) => s.toJson()).toList();
}

/// Paso 1 (Vertical Slice) — Gestión de Oro.
/// Los tres tipos de moneda que maneja la bolsa del personaje. Se
/// mantienen como stacks independientes (sin conversión automática entre
/// ellas) para no imponer reglas de casa que el jugador no pidió.
enum CurrencyType { gold, silver, copper }

/// Bolsa de monedas del personaje. Cada denominación es un contador
/// independiente y nunca baja de cero (ver CharacterProvider.spendCurrency).
class Purse {
  int gold;
  int silver;
  int copper;

  Purse({this.gold = 0, this.silver = 0, this.copper = 0});

  factory Purse.fromJson(Map<String, dynamic>? json) {
    // Fallback total: fichas anteriores al Paso 1 no traen "purse" en
    // absoluto, así que arrancan con la bolsa vacía en vez de romper el
    // parseo.
    if (json == null) return Purse();
    return Purse(
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      silver: (json['silver'] as num?)?.toInt() ?? 0,
      copper: (json['copper'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gold': gold,
      'silver': silver,
      'copper': copper,
    };
  }

  /// Valor equivalente total en piezas de oro (1 po = 10 pp = 100 pc),
  /// usado solo como referencia visual — no colapsa ni reescribe los
  /// stacks reales.
  double get totalInGold => gold + (silver / 10) + (copper / 100);
}

/// Paso 3 (Vertical Slice) — Sistema Genérico de Recursos.
///
/// Representa cualquier "pool" de puntos que un personaje gaste y
/// recupere fuera del sistema de ranuras de conjuro (Puntos de Ki,
/// Puntos de Hechicería, Furia por día, Inspiración Bárdica...). Se
/// identifica por "name" en vez de un id estable porque el jugador puede
/// crear/importar estos recursos libremente desde la ficha — dos
/// personajes distintos pueden tener un recurso con el mismo nombre sin
/// que eso sea un conflicto (a diferencia del id de un arma).
class ResourcePoint {
  String name;
  int current;
  int max;

  ResourcePoint({
    required this.name,
    required this.current,
    required this.max,
  });

  factory ResourcePoint.fromJson(Map<String, dynamic> json) {
    final max = (json['max'] as num?)?.toInt() ?? 0;
    return ResourcePoint(
      name: json['name'] ?? 'Recurso sin nombre',
      // Si el JSON no trae "current" (recurso recién creado / a tope),
      // arrancamos lleno, igual que con SpellSlot y currentHp.
      current: (json['current'] as num?)?.toInt() ?? max,
      max: max,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'current': current,
      'max': max,
    };
  }
}

/// Aliados Tácticos — Mascotas / Invocaciones / Compañeros del personaje
/// activo. `hasHp` distingue entre entidades vulnerables (con barra de
/// vida gestionable desde el HUD) y entidades de apoyo invulnerables
/// (familiares narrativos, invocaciones sin estadísticas de combate...):
/// cuando es `false`, `currentHp`/`maxHp` se ignoran en la UI aunque
/// sigan viajando en el modelo para no complicar la serialización.
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
      // Fallback seguro: aliados guardados antes de este módulo no traen
      // "has_hp" — se asumen con vida gestionable (comportamiento previo).
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
  // Roster multi-personaje / HUD por personaje: identificador ESTABLE
  // y único del personaje, independiente de su nombre (que el jugador
  // puede cambiar o repetir entre fichas). Se genera una sola vez al
  // crear el personaje (o, para fichas guardadas antes de este campo,
  // la primera vez que se cargan — ver CharacterProvider.init(), que
  // persiste el roster inmediatamente después de cargarlo para que el
  // id de fallback no cambie en cada reinicio de la app).
  //
  // `final`: una vez asignado, no debe reescribirse nunca — cualquier
  // dato namespaceado por personaje (como el layout del HUD) depende
  // de que este valor no cambie bajo los pies.
  final String id;

  BasicInfo basicInfo;
  Inventory inventory;
  AbilitiesByAction abilitiesByAction;
  StatsBlock stats;
  SpellSlots spellSlots;
  // Fase 8 — Matriz de Habilidades: lista plana de competencias (Arcanos,
  // Sigilo...), vive en la raíz del JSON como "skills". Si el personaje
  // no trae ese campo (ficha vieja, pre-Fase-8), simplemente queda vacía
  // y stats_tab.dart no pinta la sección de habilidades.
  List<Skill> skills;
  // Fase 10: bloque narrativo de la ficha (backstory, rasgos, ideales,
  // vínculos, defectos). Vive en la raíz del JSON como "lore_info".
  LoreInfo loreInfo;
  // Fase 12 — Roster multi-personaje: ruta local (galería del dispositivo)
  // de la foto de perfil. Null si el personaje aún no tiene avatar propio
  // (se pinta un icono por defecto en el header, ver main_hud_screen.dart).
  String? avatarPath;
  // Fase 10.1 — Foto de la pestaña de Lore: ruta local independiente de
  // "avatarPath". Null mientras el jugador no la edite explícitamente
  // desde LoreTab; en ese caso lore_tab.dart cae en avatarPath como
  // valor por defecto (misma foto que el header) SIN copiarlo aquí — así
  // si luego el jugador cambia la foto de perfil, la de Lore no se queda
  // "congelada" con la antigua a menos que el jugador la haya fijado a
  // mano alguna vez.
  String? loreAvatarPath;
  // Paso 1 — Gestión de Oro: bolsa de monedas del personaje. Vive en la
  // raíz del JSON como "purse". Parámetro opcional en el constructor
  // (con Purse() vacía por defecto) para no romper otros puntos de
  // construcción de CharacterModel que aún no conocen este campo.
  Purse purse;

  // Paso 2 — Códice / Diario. Tres campos de texto libre, todos viven en
  // la raíz del JSON. Por defecto vacíos ('') para que las fichas
  // anteriores a este paso no traigan estas claves y no rompan el parseo.
  //
  // - aiTips: notas generadas por IA. De solo lectura en el Códice — el
  //   provider expone un setter (setAiTips) por si en el futuro se
  //   regeneran desde una llamada a IA, pero la UI actual no las edita a
  //   mano.
  // - userTactics: notas libres del jugador sobre cómo jugar la ficha
  //   (combos, prioridades de turno, etc).
  // - adventureNotes: diario de aventura de formato libre. Se modela como
  //   un único String largo (no lista) para no forzar una estructura de
  //   entradas — el jugador decide cómo organizarlo dentro del propio
  //   texto.
  String aiTips;
  String userTactics;
  String adventureNotes;

  // Paso 3 — Sistema Genérico de Recursos. Lista de "pools" tipo Puntos
  // de Ki / Hechicería / Furia por día, etc. Vive en la raíz del JSON
  // como "resources". Opcional en el constructor (lista vacía por
  // defecto) para no romper otros puntos de construcción de
  // CharacterModel que aún no conocen este campo, igual que "purse".
  List<ResourcePoint> resources;

  // Action Economy Tracker — estado de acción/adicional/reacción del
  // turno en curso. Vive en la raíz del JSON como "turn_status".
  // Opcional en el constructor (TurnStatus() con los tres recursos
  // disponibles por defecto) para no romper otros puntos de construcción
  // de CharacterModel que aún no conocen este campo, igual que "purse".
  TurnStatus turnStatus;

  // Estados Alterados / Condiciones — lista de nombres de condiciones
  // activas sobre el personaje (Apresado, Envenenado, Derribado...). Vive
  // en la raíz del JSON como "active_conditions". El detalle mecánico de
  // cada condición (descripción, si impone desventaja...) NO se guarda
  // aquí — solo el nombre; el diccionario con los detalles vive en
  // CharacterProvider.conditionDetails para no duplicar datos estáticos
  // en cada ficha serializada. Opcional en el constructor (lista vacía
  // por defecto) para no romper otros puntos de construcción de
  // CharacterModel que aún no conocen este campo, igual que "purse".
  List<String> activeConditions;

  // Aliados Tácticos — Mascotas / Invocaciones / Compañeros del personaje.
  // Vive en la raíz del JSON como "companions". Opcional en el
  // constructor (lista vacía por defecto) para no romper otros puntos de
  // construcción de CharacterModel que aún no conocen este campo, igual
  // que "purse" y "resources".
  List<Companion> companions;

  CharacterModel({
    String? id,
    required BasicInfo basicInfo,
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
        basicInfo = basicInfo,
        purse = purse ?? Purse(),
        resources = resources ?? [],
        // Sin turnStatus explícito (ej. personaje nuevo desde el
        // formulario de alta), el movimiento arranca a tope según la
        // velocidad real de ESE personaje — no un 9 fijo que solo casaba
        // por casualidad con la velocidad humana estándar.
        turnStatus = turnStatus ?? TurnStatus(movementRemaining: basicInfo.speed),
        activeConditions = activeConditions ?? [],
        companions = companions ?? [];

  /// Genera un id de fallback para personajes creados o importados sin
  /// uno explícito (fichas anteriores a este campo, o construidas a
  /// mano en algún punto del código que aún no pasa `id`). No es un
  /// UUID de verdad para no añadir una dependencia nueva solo por
  /// esto — combina timestamp + aleatorio, suficiente para no colisionar
  /// entre los pocos personajes de un roster local.
  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(0x7FFFFFFF);
    return 'char_${timestamp}_$random';
  }

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    final rawSkills = (json['skills'] as List<dynamic>?) ?? [];
    final rawResources = (json['resources'] as List<dynamic>?) ?? [];
    final basicInfo = BasicInfo.fromJson(json['basic_info'] ?? {});
    return CharacterModel(
      // null si es una ficha guardada antes de este campo: el
      // constructor genera un id de fallback automáticamente (ver
      // _generateId más arriba).
      id: json['id'] as String?,
      basicInfo: basicInfo,
      inventory: Inventory.fromJson(json['inventory'] ?? {}),
      abilitiesByAction:
          AbilitiesByAction.fromJson(json['abilities_by_action'] ?? {}),
      stats: StatsBlock.fromJson(json['stats'] ?? {}),
      spellSlots: SpellSlots.fromJson(json['spell_slots']),
      skills: rawSkills
          .map((e) => Skill.fromJson(e as Map<String, dynamic>))
          .toList(),
      loreInfo: LoreInfo.fromJson(json['lore_info'] ?? {}),
      avatarPath: json['avatar_path'] as String?,
      // Fallback seguro: JSONs de personajes creados antes de este campo
      // no traen "lore_avatar_path" — queda null y LoreTab cae en
      // avatarPath como valor por defecto, ver lore_tab.dart.
      loreAvatarPath: json['lore_avatar_path'] as String?,
      // Fallback seguro: JSONs de personajes creados antes del Paso 1 no
      // traen "purse" — Purse.fromJson(null) devuelve una bolsa a 0/0/0.
      purse: Purse.fromJson(json['purse'] as Map<String, dynamic>?),
      // Fallback seguro: JSONs de personajes creados antes del Paso 2 no
      // traen estas claves — quedan como texto vacío en vez de romper el
      // parseo.
      aiTips: json['ai_tips'] ?? '',
      userTactics: json['user_tactics'] ?? '',
      adventureNotes: json['adventure_notes'] ?? '',
      // Fallback seguro: JSONs de personajes creados antes del Paso 3 no
      // traen "resources" — lista vacía en vez de romper el parseo.
      resources: rawResources
          .map((e) => ResourcePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Fallback seguro: JSONs de personajes creados antes de este módulo
      // no traen "turn_status" — TurnStatus.fromJson(null, ...) arranca
      // con acción/adicional disponibles y el movimiento a tope según la
      // velocidad real del personaje (basicInfo.speed).
      turnStatus: TurnStatus.fromJson(
        json['turn_status'] as Map<String, dynamic>?,
        maxSpeed: basicInfo.speed,
      ),
      // Fallback seguro: JSONs de personajes creados antes de este módulo
      // no traen "active_conditions" — lista vacía en vez de romper el
      // parseo.
      activeConditions: (json['active_conditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      // Fallback seguro: JSONs de personajes creados antes de este módulo
      // no traen "companions" — lista vacía en vez de romper el parseo.
      companions: ((json['companions'] as List<dynamic>?) ?? [])
          .map((e) => Companion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serialización completa para persistir el roster en SharedPreferences
  /// (Fase 12). Requiere que AbilitiesByAction, StatsBlock y Skill tengan
  /// su propio toJson() — ver serialization_extensions.dart si
  /// ability_model.dart / stats_model.dart todavía no lo traen.
  Map<String, dynamic> toJson() {
    return {
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