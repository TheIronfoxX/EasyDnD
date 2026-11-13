// Reglas de D&D 5e que la app necesita — un solo lugar.
//
// En el código viejo estas reglas vivían repartidas: la competencia y
// el parser de nivel adentro de BasicInfo, el dado de golpe en otro
// helper privado del mismo modelo, y el catálogo de condiciones en
// character_provider.dart. Acá viven juntas, son datos y funciones
// puras (sin Flutter, sin modelos de por medio) y se testean solas.

/// Labels en español de los seis atributos, indexados por la clave del
/// shape. Lo comparten el editor y las vistas de solo lectura del HUD
/// (ficha y competencias). Vive en core para que el HUD no dependa de
/// widgets del editor.
const Map<String, String> kStatLabels = {
  'str': 'Fuerza',
  'dex': 'Destreza',
  'con': 'Constitución',
  'int': 'Inteligencia',
  'wis': 'Sabiduría',
  'cha': 'Carisma',
};

/// Detalle mecánico estático de una condición (Apresado, Envenenado,
/// Derribado...). Es un dato de solo lectura, independiente de
/// cualquier personaje: la ficha solo guarda el *nombre* de la
/// condición activa; este objeto es el que le da significado.
class ConditionDetail {
  final String description;

  /// true si la condición impone desventaja en tiradas de ataque /
  /// pruebas de característica (Envenenado, Derribado, Asustado,
  /// Cegado). Lo consume el aviso de desventaja del HUD.
  final bool causesDisadvantage;

  const ConditionDetail({required this.description, this.causesDisadvantage = false});
}

class DndRules {
  DndRules._(); // clase estática: no se instancia.

  /// Bonificador de competencia estándar de 5e según nivel (2 en 1-4,
  /// 3 en 5-8, 4 en 9-12, 5 en 13-16, 6 en 17-20).
  static int proficiencyBonusFor(int level) =>
      2 + ((level.clamp(1, 20) - 1) ~/ 4);

  /// Extrae el nivel del texto libre de "characterClass" ("Artillero 6"
  /// → 6). Muchas fichas no traen un "level" numérico propio y el nivel
  /// real solo existe pegado al final de la clase. Si no hay ningún
  /// número, asume 1 — no hay mejor pista de la que tirar.
  static int levelFromCharacterClass(String characterClass) {
    final match = RegExp(r'(\d+)\s*$').firstMatch(characterClass.trim());
    if (match == null) return 1;
    return int.tryParse(match.group(1)!) ?? 1;
  }

  /// Infiere las caras del dado de golpe a partir del texto libre de
  /// "characterClass" cuando la ficha no trae "hit_die_sides" explícito
  /// ("Bárbaro 6" → d12). Busca el nombre de clase como substring
  /// (case-insensitive), así "Artillero (Bárbaro)" también lo encuentra.
  /// Si no reconoce ninguna clase, cae a d8 — el más común en 5e.
  static int hitDieSidesFromClass(String characterClass) {
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

  /// Catálogo de Estados Alterados / Condiciones disponibles. La clave
  /// es el nombre EXACTO que se guarda en
  /// `CharacterModel.activeConditions` — la UI de selección debe usar
  /// estas claves tal cual para que la descripción y el aviso de
  /// desventaja resuelvan. `const` a propósito: son datos de reglas,
  /// no estado editable.
  static const Map<String, ConditionDetail> conditions = {
    'Apresado': ConditionDetail(
      description: 'La velocidad del personaje se reduce a 0 y no puede '
          'beneficiarse de ningún bonificador a su velocidad.',
      causesDisadvantage: false,
    ),
    'Envenenado': ConditionDetail(
      description: 'El personaje sufre desventaja en tiradas de ataque y '
          'pruebas de característica.',
      causesDisadvantage: true,
    ),
    'Derribado': ConditionDetail(
      description: 'El personaje solo puede moverse a rastras, tiene '
          'desventaja en tiradas de ataque y los ataques cuerpo a cuerpo '
          'contra él tienen ventaja.',
      causesDisadvantage: true,
    ),
    'Asustado': ConditionDetail(
      description: 'El personaje tiene desventaja en tiradas de ataque y '
          'pruebas de característica mientras la fuente de su miedo esté '
          'a la vista, y no puede acercarse voluntariamente a ella.',
      causesDisadvantage: true,
    ),
    'Cegado': ConditionDetail(
      description: 'El personaje no puede ver y falla automáticamente '
          'cualquier prueba que requiera vista. Tiene desventaja en '
          'tiradas de ataque y los ataques contra él tienen ventaja.',
      causesDisadvantage: true,
    ),
    'Ensordecido': ConditionDetail(
      description: 'El personaje no puede oír y falla automáticamente '
          'cualquier prueba que requiera oído.',
      causesDisadvantage: false,
    ),
    'Paralizado': ConditionDetail(
      description: 'El personaje está incapacitado, no puede moverse ni '
          'hablar, y falla automáticamente las salvaciones de Fuerza y '
          'Destreza. Los ataques contra él tienen ventaja y cualquier '
          'impacto cuerpo a cuerpo a menos de 1,5 metros es crítico '
          'automático.',
      causesDisadvantage: false,
    ),
    'Inconsciente': ConditionDetail(
      description: 'El personaje está incapacitado, no puede moverse ni '
          'hablar y no es consciente de su entorno. Suelta lo que '
          'sostenga y cae derribado.',
      causesDisadvantage: false,
    ),
    'Aturdido': ConditionDetail(
      description: 'El personaje está incapacitado, no puede moverse y '
          'solo puede hablar de forma entrecortada. Falla '
          'automáticamente las salvaciones de Fuerza y Destreza, y los '
          'ataques contra él tienen ventaja.',
      causesDisadvantage: false,
    ),
    'Agarrado': ConditionDetail(
      description: 'La velocidad del personaje se convierte en 0 y no '
          'puede beneficiarse de ningún bonificador a su velocidad.',
      causesDisadvantage: false,
    ),
    'Invisible': ConditionDetail(
      description: 'El personaje es imposible de ver sin ayuda mágica o '
          'sentidos especiales. Tiene ventaja en tiradas de ataque y '
          'los ataques contra él tienen desventaja.',
      causesDisadvantage: false,
    ),
    'Incapacitado': ConditionDetail(
      description: 'El personaje no puede realizar acciones ni reacciones.',
      causesDisadvantage: false,
    ),
  };
}
