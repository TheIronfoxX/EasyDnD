import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/models/character.dart';

/// Blindaje de importación: las fichas reales de la party deben pasar el
/// validador sin errores, sobrevivir al roundtrip del modelo sin perder
/// campos clave y no descartar ni una habilidad/arma.
const _fichas = [
  'Jiseol',
  'dislexica',
  'doloria',
  'eggchan',
  'fecaliht',
  'kael',
];

int _len(Object? v) => v is List ? v.length : 0;

void main() {
  for (final nombre in _fichas) {
    group('ficha real: $nombre', () {
      late Map<String, dynamic> raw;
      late CharacterValidationResult result;

      setUpAll(() {
        final text = File('fichas/$nombre.json').readAsStringSync();
        raw = jsonDecode(text) as Map<String, dynamic>;
        result = CharacterValidator.parseAndValidate(text);
      });

      test('valida sin errores', () {
        expect(result.errors, isEmpty);
        expect(result.isOk, isTrue);
        expect(result.character, isNotNull);
      });

      test('conserva identidad y estadísticas clave', () {
        final c = result.character!;
        final bi = raw['basic_info'] as Map;
        expect(c.basicInfo.name, bi['name']);
        expect(c.basicInfo.hpMax, bi['hp_max']);
        expect(c.basicInfo.ac, bi['ac']);
      });

      test('no pierde armas ni habilidades por acción', () {
        final out =
            jsonDecode(jsonEncode(result.character!.toJson()))
                as Map<String, dynamic>;
        expect(
          _len((out['inventory'] as Map)['weapons']),
          _len((raw['inventory'] as Map)['weapons']),
        );
        final rawAbs = raw['abilities_by_action'] as Map;
        final outAbs = out['abilities_by_action'] as Map;
        for (final k in ['action', 'bonus_action', 'reaction', 'passive']) {
          expect(_len(outAbs[k]), _len(rawAbs[k]), reason: 'sección $k');
        }
      });

      test('roundtrip estable (toJson → fromJson → toJson)', () {
        final first = jsonDecode(jsonEncode(result.character!.toJson()));
        final second = jsonDecode(
          jsonEncode(
            CharacterModel.fromJson(first as Map<String, dynamic>).toJson(),
          ),
        );
        expect(second, first);
      });
    });
  }
}
