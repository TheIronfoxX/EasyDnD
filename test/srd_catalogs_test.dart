import 'dart:convert';
import 'dart:io';

import 'package:easydnd/data/class_catalog.dart';
import 'package:easydnd/data/equipment_catalog.dart';
import 'package:easydnd/data/spell_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<SrdClass> classes;
  late List<SrdWeapon> weapons;
  late List<SrdArmor> armors;
  late List<SrdSpell> spells;

  setUpAll(() {
    classes = ClassCatalog.parse(File('assets/srd/classes_5e.json').readAsStringSync());
    final eq = EquipmentCatalog.parse(File('assets/srd/equipment_5e.json').readAsStringSync());
    spells = (jsonDecode(File('assets/srd/spells_5e.json').readAsStringSync()) as List)
        .map((e) => SrdSpell.fromJson(e as Map<String, dynamic>))
        .toList();
    weapons = eq.$1;
    armors = eq.$2;
  });

  group('Clases', () {
    const abilities = {'str', 'dex', 'con', 'int', 'wis', 'cha'};

    test('carga las 12 clases con ids únicos', () {
      expect(classes, hasLength(12));
      expect(classes.map((c) => c.id).toSet(), hasLength(12));
      expect(classes.map((c) => c.name), containsAll([
        'Bárbaro', 'Bardo', 'Brujo', 'Clérigo', 'Druida', 'Explorador',
        'Guerrero', 'Hechicero', 'Mago', 'Monje', 'Paladín', 'Pícaro',
      ]));
    });

    test('datos básicos coherentes', () {
      for (final c in classes) {
        expect([6, 8, 10, 12], contains(c.hitDie), reason: c.id);
        expect(c.savingThrows, hasLength(2), reason: c.id);
        expect(abilities.containsAll([...c.primaryAbilities, ...c.savingThrows]), isTrue, reason: c.id);
        expect(c.skillOptions.length, greaterThanOrEqualTo(c.skillChoicesCount), reason: c.id);
        expect(c.coreFeatures, isNotEmpty, reason: c.id);
        for (final f in c.coreFeatures) {
          expect(f.level, inInclusiveRange(1, 3));
          expect(['action', 'bonus_action', 'reaction', 'passive'], contains(f.actionType));
          expect(f.tacticalRole != null, f.actionType == 'passive', reason: '${c.id}/${f.name}');
          if (f.resource != null) {
            expect(['short_rest', 'long_rest'], contains(f.resource!.recovery));
          }
        }
      }
    });

    test('lanzamiento de conjuros coherente con spell_list_tag', () {
      for (final c in classes) {
        if (c.spellcastingType == 'none') {
          expect(c.spellcastingAbility, isNull, reason: c.id);
          expect(c.spellListTag, isNull, reason: c.id);
        } else {
          expect(['int', 'wis', 'cha'], contains(c.spellcastingAbility), reason: c.id);
          expect(c.spellListTag, c.id, reason: c.id);
        }
      }
      expect(ClassCatalog.byIdOrName(classes, 'brujo')!.spellcastingType, 'pact');
    });

    test('spell_list_tag cruza con SpellCatalog.forClass', () {
      for (final c in classes.where((c) => c.spellListTag != null)) {
        final list = SpellCatalog.forClass(c.spellListTag!, spells);
        expect(list, isNotEmpty, reason: c.id);
      }
      // Toda etiqueta usada en los conjuros corresponde a una clase real.
      final ids = classes.map((c) => c.id).toSet();
      expect(spells.expand((s) => s.classes).toSet().difference(ids), isEmpty);
      expect(spells.every((s) => s.classes.isNotEmpty), isTrue);
    });

    test('forClass: listas del SRD y normalización', () {
      List<String> names(String id) => SpellCatalog.forClass(id, spells).map((s) => s.englishName).toList();
      expect(names('mago'), contains('Fireball'));
      expect(names('brujo'), contains('Eldritch Blast'));
      expect(names('brujo'), isNot(contains('Fireball')));
      expect(names('clerigo'), contains('Sacred Flame'));
      expect(names('Clérigo'), names('clerigo'));
      expect(names('guerrero'), isEmpty);
      expect(SrdSpell.fromJson(const {'name': 'X'}).classes, isEmpty);
    });

    test('competencias de armas SRD 5.1: Druida, Monje y Pícaro', () {
      List<String> w(String id) => ClassCatalog.byIdOrName(classes, id)!.weaponProficiencies;
      expect(w('druida'), unorderedEquals([
        'Garrote', 'Daga', 'Dardo', 'Jabalina', 'Maza', 'Bastón', 'Cimitarra', 'Hoz', 'Honda', 'Lanza',
      ]));
      expect(w('monje'), unorderedEquals(['Armas sencillas', 'Espada corta']));
      expect(w('picaro'), unorderedEquals([
        'Armas sencillas', 'Ballesta de mano', 'Espada larga', 'Estoque', 'Espada corta',
      ]));
      // Las armas nombradas existen en el catálogo de equipo.
      for (final id in ['druida', 'monje', 'picaro', 'bardo', 'hechicero', 'mago']) {
        for (final n in w(id).where((n) => !n.startsWith('Armas '))) {
          expect(EquipmentCatalog.weaponByIdOrName(weapons, n), isNotNull, reason: '$id/$n');
        }
      }
    });

    test('recursos clave presentes', () {
      String? res(String id, String feature) => ClassCatalog.byIdOrName(classes, id)!
          .coreFeatures.firstWhere((f) => f.name == feature).resource?.recovery;
      expect(res('barbaro', 'Furia'), 'long_rest');
      expect(res('monje', 'Ki'), 'short_rest');
      expect(res('paladin', 'Imposición de manos'), 'long_rest');
    });

    test('búsqueda normalizada sin tildes', () {
      expect(ClassCatalog.byIdOrName(classes, 'PICARO')!.name, 'Pícaro');
      expect(ClassCatalog.byIdOrName(classes, 'clérigo')!.id, 'clerigo');
      expect(ClassCatalog.byIdOrName(classes, 'nada'), isNull);
      expect(ClassCatalog.search(classes, query: 'barbaro'), hasLength(1));
      expect(ClassCatalog.search(classes, spellcastingType: 'half').map((c) => c.id),
          unorderedEquals(['explorador', 'paladin']));
    });
  });

  group('Equipo', () {
    test('armas íntegras y sin ids repetidos', () {
      expect(weapons.length, greaterThanOrEqualTo(30));
      expect(weapons.map((w) => w.id).toSet(), hasLength(weapons.length));
      for (final w in weapons) {
        expect(['sencilla', 'marcial'], contains(w.category), reason: w.id);
        expect(['melee', 'ranged'], contains(w.rangeType), reason: w.id);
        expect(w.rangeText, isNotEmpty, reason: w.id);
        // Versátil <=> tiene dado versátil.
        expect(w.hasProperty('Versátil'), w.versatileDice != null, reason: w.id);
      }
    });

    test('propiedades Sutil y Versátil', () {
      final sutiles = EquipmentCatalog.searchWeapons(weapons, property: 'Sutil').map((w) => w.name);
      expect(sutiles, containsAll(['Daga', 'Estoque', 'Cimitarra', 'Espada corta']));
      final espada = EquipmentCatalog.weaponByIdOrName(weapons, 'espada larga')!;
      expect(espada.damageDice, '1d8');
      expect(espada.versatileDice, '1d10');
      expect(EquipmentCatalog.weaponByIdOrName(weapons, 'Bastón')!.versatileDice, '1d8');
      expect(EquipmentCatalog.weaponByIdOrName(weapons, 'ESPADON')!.damageDice, '2d6');
    });

    test('casos borde: Red sin daño y Cerbatana de 1 de daño', () {
      final red = EquipmentCatalog.weaponByIdOrName(weapons, 'Red')!;
      expect(red.damageDice, isNull);
      expect(red.damageType, isNull);
      expect(red.rangeType, 'ranged');
      final cerbatana = EquipmentCatalog.weaponByIdOrName(weapons, 'Cerbatana')!;
      expect(cerbatana.damageDice, '1');
      expect(cerbatana.hasProperty('Recarga'), isTrue);
    });

    test('filtros por categoría y alcance', () {
      final arcos = EquipmentCatalog.searchWeapons(weapons, query: 'arco', rangeType: 'ranged');
      expect(arcos.map((w) => w.name), containsAll(['Arco corto', 'Arco largo']));
      expect(EquipmentCatalog.searchWeapons(weapons, category: 'sencilla', rangeType: 'ranged'),
          isNotEmpty);
    });

    test('armaduras íntegras', () {
      expect(armors, hasLength(13));
      expect(armors.map((a) => a.id).toSet(), hasLength(13));
      for (final a in armors.where((a) => a.category == 'media')) {
        expect(a.addDex && a.maxDexBonus == 2, isTrue, reason: a.id);
      }
      for (final a in armors.where((a) => a.category == 'pesada')) {
        expect(a.addDex, isFalse, reason: a.id);
      }
      final placas = EquipmentCatalog.armorByIdOrName(armors, 'placas')!;
      expect((placas.baseAc, placas.minStrength, placas.stealthDisadvantage), (18, 15, true));
      expect(EquipmentCatalog.armorByIdOrName(armors, 'Escudo')!.category, 'escudo');
      expect(EquipmentCatalog.searchArmors(armors, category: 'ligera'), hasLength(3));
      expect(EquipmentCatalog.searchArmors(armors, query: 'cuero'), hasLength(2));
    });
  });
}
