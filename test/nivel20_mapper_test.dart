import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/nivel20_mapper.dart';

/// Mapeador determinista Nivel20 -> EasyDnD, contra la ficha real de Kael
/// (recortada en test/fixtures/nivel20/).
void main() {
  late Map<String, dynamic> raw;
  late Map<String, dynamic> json;

  setUpAll(() {
    raw = jsonDecode(File('test/fixtures/nivel20/kael_nar_ardinys.trimmed.json')
        .readAsStringSync()) as Map<String, dynamic>;
    json = Nivel20Mapper.toJson(raw);
  });

  Map<String, dynamic> spell(String name) {
    final all = (json['abilities_by_action'] as Map)
        .values
        .expand((l) => l as List)
        .cast<Map<String, dynamic>>();
    return all.firstWhere((a) => a['name'] == name);
  }

  group('basic_info', () {
    test('identidad, nivel, PG, CA, velocidad y CD', () {
      final c = Nivel20Mapper.map(raw);
      expect(c.basicInfo.name, 'Kael`nar Ardinys');
      expect(c.basicInfo.race, 'Kitsune');
      expect(c.basicInfo.characterClass, 'Mago 15 (Escuela de evocación)');
      expect(c.basicInfo.level, 15);
      expect(c.basicInfo.hpMax, 125);
      expect(c.basicInfo.currentHp, 125);
      expect(c.basicInfo.ac, 13);
      expect(c.basicInfo.speed, 30);
      expect(c.basicInfo.spellSaveDc, 18);
      expect(c.basicInfo.hitDieSides, 6);
      expect(c.basicInfo.proficiencyBonus, 5);
    });

    test('acepta la raíz sin envoltorio printable_hash', () {
      final inner = raw['printable_hash'] as Map<String, dynamic>;
      expect(Nivel20Mapper.map(inner).basicInfo.name, 'Kael`nar Ardinys');
    });

    test('fallbacks: CA de originals, velocidad de info y default 30', () {
      final inner = Map<String, dynamic>.from(raw['printable_hash'] as Map)
        ..remove('armor')
        ..remove('speed');
      var c = Nivel20Mapper.map(inner);
      expect(c.basicInfo.ac, 12);
      expect(c.basicInfo.speed, 30); // info.speed

      (inner['info'] as Map).remove('speed');
      c = Nivel20Mapper.map(inner);
      expect(c.basicInfo.speed, 30); // default
    });

    test('sin nombre lanza FormatException', () {
      expect(() => Nivel20Mapper.toJson({'info': {}}), throwsFormatException);
    });
  });

  group('stats, habilidades y ranuras', () {
    test('atributos con las claves del modelo', () {
      final c = Nivel20Mapper.map(raw);
      expect(c.stats.intelligence.value, 21);
      expect(c.stats.intelligence.mod, 5);
      expect(c.stats.wis.value, 14);
      expect(c.stats.str.mod, -1);
    });

    test('habilidades con su modificador total', () {
      final skills = json['skills'] as List;
      final arcanos = skills.firstWhere((s) => s['name'] == 'Arcanos');
      expect(arcanos['modifier'], 10);
      expect(arcanos['related_stat'], 'int');
      final trato = skills.firstWhere((s) => s['name'] == 'Trato con Animales');
      expect(trato['related_stat'], 'wis');
    });

    test('ranuras como enteros, sin cantrips', () {
      final slots = json['spell_slots'] as List;
      expect(slots.map((s) => s['level']), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(slots.first, {'level': 1, 'max': 4, 'current': 4});
      expect(slots.every((s) => s['max'] is int), isTrue);
    });

    test('sin current_level_slots usa resources.spell_slots', () {
      final inner = jsonDecode(jsonEncode(raw['printable_hash']))
          as Map<String, dynamic>;
      ((inner['spell_books'] as List).first as Map).remove('current_level_slots');
      final slots = Nivel20Mapper.toJson(inner)['spell_slots'] as List;
      expect(slots, hasLength(8));
    });
  });

  group('armas', () {
    test('Bastón: bonificador, dado con bono plano y versátil', () {
      final w = (json['inventory']['weapons'] as List).single;
      expect(w['name'], 'Bastón');
      expect(w['attack_bonus'], 4);
      expect(w['damage'], {'base_dice': '1d6-1', 'base_type': 'contundente'});
      expect((w['conditional_damage'] as List).single['damage_dice'], '1d8-1');
      expect(w['properties'], ['Versátil']);
      expect(w['tactical_summary'], contains('+4'));
    });
  });

  group('conjuros y acciones', () {
    test('trucos: ataque y dado escalado desde actions[]', () {
      final rayo = spell('Rayo de fuego');
      expect(rayo['attack_type'], 'attack');
      expect(rayo['damage_dice'], '2d10'); // actions[], no el 1d10 del texto
      expect(rayo['base_level'], 0);
    });

    test('salvación, escalado y economía de acción', () {
      final manos = spell('Manos ardientes');
      expect(manos['attack_type'], 'save');
      expect(manos['damage_dice'], '3d6');
      expect(manos['is_scalable'], isTrue);
      expect(manos['scaling_formula'], '1d6');
      expect(manos['tactical_summary'], contains('(18)'));

      final abilities = json['abilities_by_action'] as Map;
      expect((abilities['bonus_action'] as List).map((a) => a['name']),
          contains('Retirada expeditiva'));
      expect((abilities['action'] as List).map((a) => a['name']),
          containsAll(['Rayo de fuego', 'Manos ardientes', 'Conjurar elemental']));
    });

    test('sin ataque ni salvación -> none y sin dado', () {
      final e = spell('Conjurar elemental');
      expect(e['attack_type'], 'none');
      expect(e['damage_dice'], '');
      expect(e['is_scalable'], isFalse);
    });

    test('rasgos y homebrew van a passive; carpetas de pruebas no', () {
      final names = ((json['abilities_by_action'] as Map)['passive'] as List)
          .map((a) => a['name'])
          .toList();
      expect(names, containsAll(['Esculpir conjuros', 'Forma cambiante', 'Supernova']));
      expect(names, isNot(contains('Arcanos')));
      expect(names, isNot(contains('Inteligencia')));
      expect(names, isNot(contains('Bastón')));
    });

    test('ids únicos', () {
      final ids = (json['abilities_by_action'] as Map)
          .values
          .expand((l) => l as List)
          .map((a) => a['id'])
          .toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('lore y validación', () {
    test('alineamiento e historia', () {
      final lore = json['lore_info'] as Map;
      expect(lore['backstory'], startsWith('Kael nació'));
      expect(lore['personality_traits'], 'Alineamiento: Caótico bueno');
    });

    test('equipo libre como objeto', () {
      final items = json['inventory']['mundane_items'] as List;
      expect(items.single['description'], 'Una aguja que nunca se dobla.');
    });

    test('el resultado pasa el validador sin errores', () {
      final result = CharacterValidator.validateMap(json);
      expect(result.errors, isEmpty);
      expect(result.isOk, isTrue);
    });
  });
}
