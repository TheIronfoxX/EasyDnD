import 'package:easydnd/domain/models/character.dart';

/// Ficha JSON de prueba: mínima pero con TODAS las secciones que el
/// store y el repositorio tocan (arma con cargas y cantidad, habilidad
/// con cargas, ranuras, recursos, turno, condiciones, compañero), para
/// que los tests ejerciten los mismos caminos que una ficha real de la
/// party.
///
/// OJO con [weaponId]: por default todas las fichas comparten 'w1' a
/// propósito — es justo el caso que rompía el mapa global de
/// cantidades de la app vieja.
Map<String, dynamic> buildFichaJson({
  String id = 'char_test',
  String name = 'Test',
  String characterClass = 'Guerrero 5',
  int hpMax = 20,
  int hpCurrent = 20,
  int speed = 9,
  int conMod = 2,
  int hitDieSides = 10,
  int hitDiceMax = 5,
  int hitDiceCurrent = 5,
  String weaponId = 'w1',
  int weaponQuantity = 1,
  bool weaponIsUnique = false,
  int weaponChargesCurrent = 3,
  int abilityChargesCurrent = 1,
  int slotCurrent = 4,
}) {
  return {
    'id': id,
    'basic_info': {
      'name': name,
      'race': 'Humano',
      'characterClass': characterClass,
      'hp_max': hpMax,
      'hp_current': hpCurrent,
      'ac': 18,
      'level': 5,
      'speed': speed,
      'hit_die_sides': hitDieSides,
      'hit_dice_max': hitDiceMax,
      'hit_dice_current': hitDiceCurrent,
    },
    'inventory': {
      'weapons': [
        {
          'id': weaponId,
          'name': 'Espada Larga',
          'attack_bonus': 5,
          'damage': {
            'base_dice': '1d8+3',
            'base_type': 'cortante',
          },
          'conditional_damage': [],
          'properties': [],
          'homebrew_effect': '',
          'magic_charges': {
            'has_charges': true,
            'max': 3,
            'current': weaponChargesCurrent,
          },
          'success_description': '',
          'failure_description': '',
          'is_unique': weaponIsUnique,
          'quantity': weaponQuantity,
        },
      ],
      'mundane_items': [
        {'name': 'Cuerda', 'description': '10 metros', 'quantity': 1},
      ],
    },
    'abilities_by_action': {
      'action': [
        {
          'id': 'a1',
          'name': 'Golpe Devastador',
          'type': 'trait',
          'related_stat': 'str',
          'attack_type': 'attack',
          'success_description': '',
          'failure_description': '',
          'is_scalable': false,
          'base_level': 0,
          'damage_dice': '2d6',
          'magic_charges': {
            'has_charges': true,
            'max': 3,
            'current': abilityChargesCurrent,
          },
        },
      ],
      'bonus_action': [],
      'reaction': [],
      'passive': [],
    },
    'stats': {
      'str': {'name': 'Fuerza', 'value': 16, 'mod': 3, 'description': ''},
      'dex': {'name': 'Destreza', 'value': 12, 'mod': 1, 'description': ''},
      'con': {
        'name': 'Constitución',
        'value': 14,
        'mod': conMod,
        'description': '',
      },
      'int': {'name': 'Inteligencia', 'value': 10, 'mod': 0, 'description': ''},
      'wis': {'name': 'Sabiduría', 'value': 10, 'mod': 0, 'description': ''},
      'cha': {'name': 'Carisma', 'value': 10, 'mod': 0, 'description': ''},
    },
    'spell_slots': [
      {'level': 1, 'max': 4, 'current': slotCurrent},
    ],
    'skills': [],
    'lore_info': {
      'backstory': 'Historia',
      'personality_traits': '',
      'ideals': '',
      'bonds': '',
      'flaws': '',
    },
    'purse': {'gold': 10, 'silver': 5, 'copper': 2},
    'resources': [
      {'name': 'Furia', 'current': 2, 'max': 3},
    ],
    'turn_status': {
      'actionUsed': false,
      'bonusActionUsed': false,
      'movementRemaining': speed,
    },
    'active_conditions': [],
    'companions': [
      {
        'name': 'Lobo',
        'type': 'bestia',
        'has_hp': true,
        'current_hp': 5,
        'max_hp': 10,
        'ac': 12,
      },
    ],
  };
}

/// Atajo: la ficha de arriba ya parseada a modelo.
CharacterModel buildCharacter({
  String id = 'char_test',
  String name = 'Test',
  String characterClass = 'Guerrero 5',
  int hpMax = 20,
  int hpCurrent = 20,
  int speed = 9,
  int conMod = 2,
  int hitDieSides = 10,
  int hitDiceMax = 5,
  int hitDiceCurrent = 5,
  String weaponId = 'w1',
  int weaponQuantity = 1,
  bool weaponIsUnique = false,
  int weaponChargesCurrent = 3,
  int abilityChargesCurrent = 1,
  int slotCurrent = 4,
}) {
  return CharacterModel.fromJson(buildFichaJson(
    id: id,
    name: name,
    characterClass: characterClass,
    hpMax: hpMax,
    hpCurrent: hpCurrent,
    speed: speed,
    conMod: conMod,
    hitDieSides: hitDieSides,
    hitDiceMax: hitDiceMax,
    hitDiceCurrent: hitDiceCurrent,
    weaponId: weaponId,
    weaponQuantity: weaponQuantity,
    weaponIsUnique: weaponIsUnique,
    weaponChargesCurrent: weaponChargesCurrent,
    abilityChargesCurrent: abilityChargesCurrent,
    slotCurrent: slotCurrent,
  ));
}
