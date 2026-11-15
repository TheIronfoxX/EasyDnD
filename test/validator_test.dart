import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/domain/character_validator.dart';

import 'fakes/test_fichas.dart';

void main() {
  group('errores bloqueantes (solo los cuatro)', () {
    test('texto que no es JSON', () {
      final result = CharacterValidator.parseAndValidate('hola, esto no es nada');
      expect(result.isOk, isFalse);
      expect(result.errors, hasLength(1));
      expect(result.character, isNull);
    });

    test('JSON que no es un objeto', () {
      final result = CharacterValidator.parseAndValidate('[1, 2, 3]');
      expect(result.isOk, isFalse);
    });

    test('sin basic_info', () {
      final result = CharacterValidator.validateMap({'name': 'X', 'hp_max': 10});
      expect(result.isOk, isFalse);
      expect(result.errors.single.field, 'basic_info');
    });

    test('sin nombre', () {
      final result = CharacterValidator.validateMap({
        'basic_info': {'hp_max': 10}
      });
      expect(result.isOk, isFalse);
      expect(result.errors.single.field, 'basic_info.name');
    });

    test('nombre vacío o en blanco', () {
      final result = CharacterValidator.validateMap({
        'basic_info': {'name': '   ', 'hp_max': 10}
      });
      expect(result.isOk, isFalse);
    });

    test('hp_max no numérico', () {
      final result = CharacterValidator.validateMap({
        'basic_info': {'name': 'X', 'hp_max': 'muchos'}
      });
      expect(result.isOk, isFalse);
      expect(result.errors.single.field, 'basic_info.hp_max');
    });
  });

  group('acepta lo válido', () {
    test('mínimo viable: nombre + hp_max', () {
      final result = CharacterValidator.validateMap({
        'basic_info': {'name': 'X', 'hp_max': 10}
      });
      expect(result.isOk, isTrue);
      expect(result.errors, isEmpty);
      expect(result.character!.basicInfo.name, 'X');
    });

    test('JSON envuelto en valla markdown y cortesía de IA', () {
      final raw = '¡Aquí tienes tu personaje!\n'
          '```json\n${jsonEncode(buildFichaJson())}\n```\n'
          '¡Espero que lo disfrutes!';
      final result = CharacterValidator.parseAndValidate(raw);
      expect(result.isOk, isTrue);
      expect(result.character!.basicInfo.name, 'Test');
    });

    test('una ficha real de la party pasa sin errores', () {
      final raw = File('fichas/Jiseol.json').readAsStringSync();
      final result = CharacterValidator.parseAndValidate(raw);
      expect(result.errors, isEmpty);
      expect(result.isOk, isTrue);
    });
  });

  group('warnings (no bloquean, avisan del fallback)', () {
    test('speed fuera de 5-120 pies avisa (¿metros?)', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)['speed'] = 3;
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field == 'basic_info.speed'), isTrue);
    });

    test('dado de daño irreconocible', () {
      final json = buildFichaJson();
      final weapon = (json['inventory'] as Map)['weapons'] as List;
      ((weapon.single as Map)['damage'] as Map)['base_dice'] = 'mucho daño';
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(
        result.warnings.any((w) => w.field.contains('base_dice')),
        isTrue,
        reason: 'El arma "Espada Larga" tiene un dado irreconocible',
      );
    });

    test('escalado prometido pero irresoluble', () {
      final json = buildFichaJson();
      final ability = ((json['abilities_by_action'] as Map)['action'] as List).single as Map;
      ability['is_scalable'] = true;
      ability['scaling_formula'] = 'sube con el nivel';
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field.contains('scaling_formula')), isTrue);
    });

    test('attack_type desconocido', () {
      final json = buildFichaJson();
      final ability = ((json['abilities_by_action'] as Map)['action'] as List).single as Map;
      ability['attack_type'] = 'quizas';
      final result = CharacterValidator.validateMap(json);
      expect(result.warnings.any((w) => w.field.contains('attack_type')), isTrue);
    });

    test('condición fuera del catálogo', () {
      final json = buildFichaJson();
      (json['active_conditions'] as List).add('Volando');
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field == 'active_conditions'), isTrue);
    });

    test('stats incompletos', () {
      final json = buildFichaJson();
      (json['stats'] as Map).remove('con');
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field == 'stats'), isTrue);
    });

    test('ranuras de conjuro sin CD de salvación', () {
      // La fixture trae spell_slots pero no spell_save_dc.
      final result = CharacterValidator.validateMap(buildFichaJson());
      expect(result.isOk, isTrue);
      expect(
        result.warnings.any((w) => w.field == 'basic_info.spell_save_dc'),
        isTrue,
      );
    });

    test('arma sin id', () {
      final json = buildFichaJson();
      ((json['inventory'] as Map)['weapons'] as List).single.remove('id');
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field.endsWith('.id')), isTrue);
    });

    test('hp_current fuera de rango', () {
      final result = CharacterValidator
          .validateMap(buildFichaJson(hpCurrent: 999, hpMax: 20));
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field == 'basic_info.hp_current'), isTrue);
    });

    test('nivel indeducible', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map).remove('level');
      (json['basic_info'] as Map)['characterClass'] = 'Guerrero'; // sin número
      final result = CharacterValidator.validateMap(json);
      expect(result.isOk, isTrue);
      expect(result.warnings.any((w) => w.field == 'basic_info.level'), isTrue);
    });

    test('ficha sin habilidades avisa', () {
      final result = CharacterValidator.validateMap({
        'basic_info': {'name': 'X', 'hp_max': 10},
      });
      expect(result.warnings.any((w) => w.field == 'abilities_by_action'), isTrue);
    });
  });
}
