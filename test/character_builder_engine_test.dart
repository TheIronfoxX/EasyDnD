import 'dart:convert';
import 'dart:io';

import 'package:easydnd/data/class_catalog.dart';
import 'package:easydnd/data/equipment_catalog.dart';
import 'package:easydnd/data/spell_catalog.dart';
import 'package:easydnd/domain/character_builder_engine.dart';
import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<SrdClass> classes;
  late List<SrdWeapon> weapons;
  late List<SrdArmor> armors;
  late List<SrdSpell> spells;

  SrdClass cls(String id) => ClassCatalog.byIdOrName(classes, id)!;
  SrdWeapon weapon(String n) => EquipmentCatalog.weaponByIdOrName(weapons, n)!;
  SrdArmor armor(String n) => EquipmentCatalog.armorByIdOrName(armors, n)!;
  SrdSpell spell(String english) =>
      spells.firstWhere((s) => s.englishName == english);

  setUpAll(() {
    classes = ClassCatalog.parse(
      File('assets/srd/classes_5e.json').readAsStringSync(),
    );
    final eq = EquipmentCatalog.parse(
      File('assets/srd/equipment_5e.json').readAsStringSync(),
    );
    weapons = eq.$1;
    armors = eq.$2;
    spells =
        (jsonDecode(File('assets/srd/spells_5e.json').readAsStringSync())
                as List)
            .map((e) => SrdSpell.fromJson(e as Map<String, dynamic>))
            .toList();
  });

  CharacterCreationInput input(
    String classId, {
    int level = 1,
    Map<String, int> scores = const {},
    Set<String> skills = const {},
    List<SrdWeapon> weapons = const [],
    List<SrdArmor> armors = const [],
    List<SrdSpell> spells = const [],
    int? customHp,
  }) => CharacterCreationInput(
    name: 'Prueba',
    race: 'Humano',
    level: level,
    srdClass: cls(classId),
    baseScores: {
      'str': 10,
      'dex': 10,
      'con': 10,
      'int': 10,
      'wis': 10,
      'cha': 10,
      ...scores,
    },
    skillProficiencies: skills,
    weapons: weapons,
    armors: armors,
    spells: spells,
    customHpMax: customHp,
    startingGold: 15,
  );

  /// Pasa la ficha por el validador real: ni errores ni avisos.
  CharacterModel validated(CharacterCreationInput i) {
    final model = CharacterBuilderEngine.build(i);
    final result = CharacterValidator.validateMap(
      (jsonDecode(jsonEncode(model.toJson())) as Map).cast<String, dynamic>(),
    );
    expect(result.issues.map((x) => '${x.field}: ${x.message}'), isEmpty);
    expect(result.character, isNotNull);
    return result.character!;
  }

  group('reglas base', () {
    test('competencia, modificador y PG', () {
      expect(
        [
          1,
          4,
          5,
          8,
          9,
          13,
          17,
          20,
        ].map(CharacterBuilderEngine.proficiencyBonus),
        [2, 2, 3, 3, 4, 5, 6, 6],
      );
      expect([8, 9, 10, 11, 15, 7, 1].map(CharacterBuilderEngine.modifier), [
        -1,
        -1,
        0,
        0,
        2,
        -2,
        -5,
      ]);
      // Nivel 1 = dado + CON; luego media fija; nunca menos de 1.
      expect(
        CharacterBuilderEngine.hitPoints(hitDie: 10, level: 1, conMod: 2),
        12,
      );
      expect(
        CharacterBuilderEngine.hitPoints(hitDie: 10, level: 5, conMod: 2),
        12 + 4 * 8,
      );
      expect(
        CharacterBuilderEngine.hitPoints(hitDie: 6, level: 1, conMod: -5),
        1,
      );
      expect(
        CharacterBuilderEngine.hitPoints(hitDie: 6, level: 3, conMod: -5),
        3,
      );
      expect(
        CharacterBuilderEngine.hitPoints(
          hitDie: 8,
          level: 5,
          conMod: 0,
          customHpMax: 31,
        ),
        31,
      );
    });

    test('bonos raciales suman al total', () {
      final i = CharacterCreationInput(
        srdClass: cls('mago'),
        baseScores: const {'int': 15},
        racialBonuses: const {'int': 2},
      );
      final s = CharacterBuilderEngine.compute(i);
      expect((s.totals['int'], s.mods['int']), (17, 3));
    });

    test('tablas de ranuras SRD', () {
      expect(CharacterBuilderEngine.spellSlotsFor('full', 1), {1: 2});
      expect(CharacterBuilderEngine.spellSlotsFor('full', 5), {
        1: 4,
        2: 3,
        3: 2,
      });
      expect(CharacterBuilderEngine.spellSlotsFor('full', 20), {
        1: 4,
        2: 3,
        3: 3,
        4: 3,
        5: 3,
        6: 2,
        7: 2,
        8: 1,
        9: 1,
      });
      expect(CharacterBuilderEngine.spellSlotsFor('half', 1), isEmpty);
      expect(CharacterBuilderEngine.spellSlotsFor('half', 5), {1: 4, 2: 2});
      expect(CharacterBuilderEngine.spellSlotsFor('third', 3), {1: 2});
      expect(CharacterBuilderEngine.spellSlotsFor('third', 19), {
        1: 4,
        2: 3,
        3: 3,
        4: 1,
      });
      expect(CharacterBuilderEngine.spellSlotsFor('none', 10), isEmpty);
      expect(
        {
          for (final l in [1, 2, 3, 5, 7, 9, 11, 17])
            l: CharacterBuilderEngine.spellSlotsFor('pact', l),
        },
        {
          1: {1: 1},
          2: {1: 2},
          3: {2: 2},
          5: {3: 2},
          7: {4: 2},
          9: {5: 2},
          11: {5: 3},
          17: {5: 4},
        },
      );
    });

    test('fórmulas de recursos', () {
      int f(
        String s, {
        int level = 5,
        Map<String, int> mods = const {'cha': 3},
      }) => CharacterBuilderEngine.resolveFormula(s, level: level, mods: mods);
      expect(f('3'), 3);
      expect(f('level'), 5);
      expect(f('proficiency'), 3);
      expect(f('cha_mod'), 3);
      expect(f('5*level'), 25);
      expect(f('max(1,1+cha_mod)'), 4);
      expect(f('max(1,cha_mod)', mods: {'cha': -2}), 1);
      expect(f('rage_uses', level: 5), 3);
      expect(() => f('banana'), throwsFormatException);
    });
  });

  group('arquetipos', () {
    test('Mago nivel 1', () {
      final i = input(
        'mago',
        scores: {'int': 16, 'dex': 14, 'con': 13},
        skills: {'Arcanos', 'Historia'},
        weapons: [weapon('Bastón')],
        spells: [spell('Magic Missile'), spell('Fire Bolt'), spell('Shield')],
      );
      final stats = CharacterBuilderEngine.compute(i);
      expect(stats.proficiencyBonus, 2);
      expect(stats.spellSaveDc, 8 + 2 + 3);
      expect(stats.spellAttackBonus, 5);
      expect(stats.hpMax, 6 + 1);
      expect(stats.ac, 12);
      expect(stats.savingThrows['int'], 5); // competente
      expect(stats.savingThrows['str'], 0);
      expect(stats.skills['Arcanos'], 5);
      expect(stats.skills['Medicina'], 0);

      final c = validated(i);
      expect(c.basicInfo.spellSaveDc, 13);
      expect(c.basicInfo.hitDieSides, 6);
      expect(c.spellSlots.forLevel(1)!.max, 2);
      expect(c.spellSlots.maxLevel, 1);
      expect(c.resources.single.name, 'Recuperación arcana');
      expect(c.resources.single.max, 1);
      expect(c.purse.gold, 15);

      final staff = c.inventory.weapons.single;
      expect(staff.name, 'Bastón');
      expect(staff.damage.baseDice, '1d6'); // FUE 10: sin modificador
      expect(staff.damage.baseType, 'contundente');
      expect(staff.attackBonus, 0 + 2); // sencilla: el mago domina el Bastón
      expect(staff.conditionalDamage.single.trigger, contains('dos manos'));
      expect(staff.conditionalDamage.single.dice, '1d8');

      final spellNames = c.abilitiesByAction.all
          .where((a) => a.isSpell)
          .map((a) => a.name);
      expect(
        spellNames,
        containsAll(['Proyectil mágico', 'Saeta de fuego', 'Escudo']),
      );
      expect(
        c.abilitiesByAction.reaction.map((a) => a.name),
        contains('Escudo'),
      );
      expect(
        c.abilitiesByAction.all
            .firstWhere((a) => a.name == 'Saeta de fuego')
            .relatedStat,
        'int',
      );
    });

    test('Guerrero nivel 5: cota de mallas + escudo, espadón', () {
      final i = input(
        'guerrero',
        level: 5,
        scores: {'str': 16, 'dex': 12, 'con': 14},
        skills: {'Atletismo', 'Percepción'},
        weapons: [weapon('Espadón')],
        armors: [armor('Cota de mallas'), armor('Escudo')],
      );
      final stats = CharacterBuilderEngine.compute(i);
      expect(stats.ac, 18);
      expect(stats.hpMax, 12 + 4 * ((10 ~/ 2) + 1 + 2));
      expect(stats.proficiencyBonus, 3);
      expect(stats.savingThrows['str'], 3 + 3);
      expect(stats.savingThrows['con'], 2 + 3);

      final c = validated(i);
      expect(c.basicInfo.ac, 18);
      expect(c.basicInfo.hpMax, 44);
      expect(c.spellSlots.slots, isEmpty);
      expect(c.basicInfo.spellSaveDc, isNull);
      final sword = c.inventory.weapons.single;
      expect(sword.attackBonus, 3 + 3); // FUE +3, competencia +3
      expect(sword.damage.baseDice, '2d6+3');
      expect(sword.conditionalDamage, isEmpty);
      expect(c.inventory.mundaneItems.map((m) => m.name), [
        'Cota de mallas',
        'Escudo',
      ]);
      expect(
        c.resources.map((r) => r.name),
        containsAll(['Tomar aliento', 'Oleada de acción']),
      );
    });

    test('Pícaro nivel 3: estoque Sutil con Destreza, cuero tachonado', () {
      final i = input(
        'picaro',
        level: 3,
        scores: {'str': 10, 'dex': 16, 'con': 12},
        skills: {'Sigilo', 'Percepción', 'Engaño', 'Juego de manos'},
        weapons: [weapon('Estoque'), weapon('Daga')],
        armors: [armor('Cuero tachonado')],
      );
      final stats = CharacterBuilderEngine.compute(i);
      expect(stats.ac, 12 + 3);

      final c = validated(i);
      final rapier = c.inventory.weapons.firstWhere((w) => w.name == 'Estoque');
      expect(rapier.properties, contains('Sutil'));
      expect(rapier.attackBonus, 3 + 2); // DES, no FUE (+0)
      expect(rapier.damage.baseDice, '1d8+3');
      expect(c.skills.firstWhere((s) => s.name == 'Sigilo').modifier, 5);
      expect(c.inventory.mundaneItems.single.name, 'Cuero tachonado');
    });

    test('Sutil elige el mayor entre FUE y DES; a distancia usa DES', () {
      final strong = CharacterBuilderEngine.build(
        input(
          'picaro',
          scores: {'str': 16, 'dex': 12},
          weapons: [weapon('Daga'), weapon('Arco corto')],
        ),
      );
      final dagger = strong.inventory.weapons.firstWhere(
        (w) => w.name == 'Daga',
      );
      expect(dagger.attackBonus, 3 + 2);
      final bow = strong.inventory.weapons.firstWhere(
        (w) => w.name == 'Arco corto',
      );
      expect(bow.attackBonus, 1 + 2);
    });

    test('Brujo nivel 5: ranuras de pacto', () {
      final i = input(
        'brujo',
        level: 5,
        scores: {'cha': 16, 'con': 14},
        skills: {'Arcanos', 'Engaño'},
        spells: [spell('Eldritch Blast'), spell('Misty Step')],
      );
      final c = validated(i);
      expect(c.spellSlots.slots, hasLength(1));
      expect(
        (c.spellSlots.slots.single.level, c.spellSlots.slots.single.max),
        (3, 2),
      );
      expect(c.basicInfo.spellSaveDc, 8 + 3 + 3);
      expect(c.basicInfo.hpMax, 10 + 4 * (5 + 2));
    });

    test('Bárbaro y Monje sin armadura', () {
      final barb = input(
        'barbaro',
        scores: {'dex': 14, 'con': 16},
        skills: {'Atletismo', 'Percepción'},
      );
      expect(CharacterBuilderEngine.compute(barb).ac, 10 + 2 + 3);
      final barbShield = input(
        'barbaro',
        scores: {'dex': 14, 'con': 16},
        armors: [armor('Escudo')],
      );
      expect(CharacterBuilderEngine.compute(barbShield).ac, 10 + 2 + 3 + 2);
      final cb = validated(barb);
      expect(cb.resources.single.name, 'Furias');
      expect(cb.resources.single.max, 2);
      expect(validated(input('barbaro', level: 3)).resources.single.max, 3);
      expect(
        validated(input('barbaro', level: 3)).resources.single.name,
        'Furias',
      );

      final monk = input(
        'monje',
        scores: {'dex': 16, 'wis': 14},
        skills: {'Acrobacias', 'Sigilo'},
      );
      expect(CharacterBuilderEngine.compute(monk).ac, 10 + 3 + 2);
      final monkShield = input(
        'monje',
        scores: {'dex': 16, 'wis': 14},
        armors: [armor('Escudo')],
      );
      expect(CharacterBuilderEngine.compute(monkShield).ac, 10 + 3 + 2);
      final cm = validated(input('monje', level: 3, scores: {'dex': 16}));
      expect(cm.resources.single.max, 3);
      expect(
        cm.abilitiesByAction.reaction.map((a) => a.name),
        contains('Desviar proyectiles'),
      );
    });

    test('rasgos por nivel y exclusión mutua rol táctico / tipo de ataque', () {
      final lvl1 = validated(input('picaro'));
      final lvl2 = validated(input('picaro', level: 2));
      expect(lvl1.abilitiesByAction.bonusAction, isEmpty);
      expect(lvl2.abilitiesByAction.bonusAction.map((a) => a.name), [
        'Acción astuta',
      ]);
      final json = lvl2.toJson()['abilities_by_action'] as Map<String, dynamic>;
      for (final a in json['passive'] as List) {
        expect((a as Map).containsKey('attack_type'), isFalse);
        expect(a['tactical_role'], isNotNull);
      }
      for (final a in json['bonus_action'] as List) {
        expect((a as Map).containsKey('tactical_role'), isFalse);
        expect(a['attack_type'], 'none');
      }
    });

    test('Red sin daño: sin dados ni modificador', () {
      final c = validated(
        input('guerrero', scores: {'str': 16}, weapons: [weapon('Red')]),
      );
      final net = c.inventory.weapons.single;
      expect(net.damage.baseDice, '0d0');
      expect(net.conditionalDamage, isEmpty);
    });

    test('todas las clases producen fichas válidas en niveles 1, 5 y 20', () {
      for (final c in classes) {
        for (final level in [1, 5, 20]) {
          validated(
            input(
              c.id,
              level: level,
              scores: {'con': 14, 'dex': 14, 'wis': 12, 'cha': 12},
            ),
          );
        }
      }
    });

    test('es determinista', () {
      final i = input(
        'mago',
        spells: [spell('Magic Missile')],
        weapons: [weapon('Bastón')],
      );
      final a = CharacterBuilderEngine.build(i).toJson()..remove('id');
      final b = CharacterBuilderEngine.build(i).toJson()..remove('id');
      expect(jsonEncode(a), jsonEncode(b));
    });
  });
}
