import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/core/json_sanitizer.dart';
import 'package:easydnd/domain/character_validator.dart';

import 'fakes/test_fichas.dart';

void main() {
  group('sanitizeJsonText', () {
    test('quita vallas y texto de cortesía', () {
      expect(
        sanitizeJsonText('Hola\n```json\n{"a": 1}\n```\nChao'),
        '{"a": 1}',
      );
    });
  });

  group('normalizeCharacterJson', () {
    test('strings numéricos -> enteros en basic_info', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)
        ..['hp_max'] = '44'
        ..['hp_current'] = ' 40 '
        ..['ac'] = '18'
        ..['speed'] = '30'
        ..['level'] = '5'
        ..['spell_save_dc'] = '+14'
        ..['spell_attack_bonus'] = '6.0';
      final basic = normalizeCharacterJson(json)['basic_info'] as Map;
      expect(basic['hp_max'], 44);
      expect(basic['hp_current'], 40);
      expect(basic['ac'], 18);
      expect(basic['speed'], 30);
      expect(basic['level'], 5);
      expect(basic['spell_save_dc'], 14);
      expect(basic['spell_attack_bonus'], 6);
    });

    test('atributos, ranuras, recursos y bonos de arma', () {
      final json = buildFichaJson();
      ((json['stats'] as Map)['str'] as Map)
        ..['value'] = '16'
        ..['mod'] = '3';
      json['spell_slots'] = [
        {'level': '1', 'max': '4', 'current': '2'},
      ];
      json['resources'] = [
        {'name': 'Ki', 'current': '3', 'max': '5'},
      ];
      final weapon =
          ((json['inventory'] as Map)['weapons'] as List).first as Map;
      weapon['attack_bonus'] = '7';

      final out = normalizeCharacterJson(json);
      expect(((out['stats'] as Map)['str'] as Map)['value'], 16);
      expect(((out['stats'] as Map)['str'] as Map)['mod'], 3);
      expect((out['spell_slots'] as List).first, {
        'level': 1,
        'max': 4,
        'current': 2,
      });
      expect((out['resources'] as List).first['max'], 5);
      expect(
        (((out['inventory'] as Map)['weapons'] as List).first
            as Map)['attack_bonus'],
        7,
      );
    });

    test('texto no numérico y decimales reales no se tocan', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)
        ..['hp_max'] = 'mucho'
        ..['ac'] = 17.5;
      final basic = normalizeCharacterJson(json)['basic_info'] as Map;
      expect(basic['hp_max'], 'mucho');
      expect(basic['ac'], 17.5);
    });

    test('null -> [] en arrays e inventario', () {
      final json = buildFichaJson()
        ..['resources'] = null
        ..['spell_slots'] = null
        ..['active_conditions'] = null
        ..['inventory'] = {'weapons': null, 'mundane_items': null}
        ..['abilities_by_action'] = {
          'action': null,
          'bonus_action': null,
          'reaction': null,
          'passive': null,
        };
      final out = normalizeCharacterJson(json);
      expect(out['resources'], isEmpty);
      expect(out['spell_slots'], isEmpty);
      expect(out['active_conditions'], isEmpty);
      expect((out['inventory'] as Map)['weapons'], isEmpty);
      expect((out['inventory'] as Map)['mundane_items'], isEmpty);
      for (final k in ['action', 'bonus_action', 'reaction', 'passive']) {
        expect((out['abilities_by_action'] as Map)[k], isEmpty, reason: k);
      }
    });

    test(
      'inventory y abilities_by_action null -> objetos con listas vacías',
      () {
        final out = normalizeCharacterJson(
          buildFichaJson()
            ..['inventory'] = null
            ..['abilities_by_action'] = null,
        );
        expect((out['inventory'] as Map)['weapons'], isEmpty);
        expect((out['abilities_by_action'] as Map)['passive'], isEmpty);
      },
    );

    test('defaults seguros para secciones no críticas ausentes', () {
      final out = normalizeCharacterJson({
        'basic_info': {'name': 'X', 'hp_max': 10},
      });
      expect(out['ai_tips'], '');
      expect(out['user_tactics'], '');
      expect(out['adventure_notes'], '');
      expect(out['purse'], {'gold': 0, 'silver': 0, 'copper': 0});
      expect(out['resources'], isEmpty);
      expect((out['lore_info'] as Map)['backstory'], '');
      // Lo crítico NO se inventa.
      expect((out['basic_info'] as Map).containsKey('speed'), isFalse);
      expect(out.containsKey('stats'), isFalse);
    });

    test('no muta la entrada', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)['hp_max'] = '44';
      normalizeCharacterJson(json);
      expect((json['basic_info'] as Map)['hp_max'], '44');
    });

    test('es idempotente', () {
      final once = normalizeCharacterJson(
        buildFichaJson()..['resources'] = null,
      );
      expect(normalizeCharacterJson(once), once);
    });
  });

  group('integración con el validador', () {
    test('una ficha con números entre comillas y nulls entra sin errores', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)
        ..['hp_max'] = '44'
        ..['ac'] = '15';
      json['resources'] = null;
      final result = CharacterValidator.parseAndValidate(jsonEncode(json));
      expect(result.errors, isEmpty);
      expect(result.character!.basicInfo.hpMax, 44);
      expect(result.character!.basicInfo.ac, 15);
    });

    test('hp_max no numérico sigue siendo error bloqueante', () {
      final json = buildFichaJson();
      (json['basic_info'] as Map)['hp_max'] = 'mucho';
      final result = CharacterValidator.parseAndValidate(jsonEncode(json));
      expect(result.isOk, isFalse);
    });
  });
}
