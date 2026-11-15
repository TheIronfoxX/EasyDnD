// Tests del generador de prompts de importación (AiPrompt).
//
// Lo más valioso que cuidan: que TODAS las variantes lleven el cuerpo
// maestro completo (en la app vieja la copia resumida de
// generateAIPrompt fue perdiendo reglas silenciosamente) y que el
// ejemplo JSON embebido siga siendo una ficha válida — si alguien
// retoca el prompt y rompe el ejemplo, la IA aprendería el shape mal.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/domain/ai_prompt.dart';
import 'package:easydnd/domain/character_validator.dart';

void main() {
  group('AiPrompt', () {
    test('forEmptySheet: cuerpo maestro + marcador de pegado al final', () {
      final prompt = AiPrompt.forEmptySheet();

      expect(prompt, startsWith('Vas a convertir la ficha de un personaje'));
      expect(prompt, contains('REGLAS OBLIGATORIAS:'));
      expect(prompt, contains('FORMATO EXACTO A SEGUIR'));
      expect(prompt, contains('"Kaelen el Luminoso"')); // ejemplo completo
      expect(
        prompt.trim(),
        endsWith(
            '--- PEGA AQUÍ LOS DATOS DE TU PERSONAJE (texto de la ficha, '
            'copia de PDF, lo que tengas) ---'),
      );
    });

    test('todas las variantes incluyen el cuerpo maestro COMPLETO', () {
      final variants = [
        AiPrompt.forEmptySheet(),
        AiPrompt.forEmbeddedSource('Texto de la ficha'),
        AiPrompt.forNivel20Link('https://nivel20.com/games/g/characters/1-x'),
        AiPrompt.forCorrection('{"basic_info": {}}', ['un problema']),
      ];

      for (final prompt in variants) {
        // Reglas clave que la copia resumida vieja había perdido.
        expect(prompt, contains('"tactical_role"'));
        expect(prompt, contains('"scaling_formula"'));
        expect(prompt, contains('"spell_save_dc"'));
        expect(prompt, contains('"speed"'));
        // El ejemplo con todos los campos.
        expect(prompt, contains('"Kaelen el Luminoso"'));
        // Nada de marcadores sin reemplazar colgando.
        expect(prompt, isNot(contains('{{')));
      }
    });

    test('el prompt maestro clasifica poderes activos y pide los campos nuevos',
        () {
      final variants = [
        AiPrompt.forEmptySheet(),
        AiPrompt.forEmbeddedSource('x'),
        AiPrompt.forNivel20Link('https://nivel20.com/games/g/characters/1-x'),
      ];

      for (final prompt in variants) {
        // Los poderes activos no son pasivos, vengan de donde vengan.
        expect(prompt, contains('CLASIFICACIÓN DE PODERES ACTIVOS'));
        expect(prompt, contains('NUNCA va en "passive"'));
        // Origen con los cinco valores exactos.
        for (final type in ['"spell"', '"class"', '"racial"', '"feat"', '"item"']) {
          expect(prompt, contains(type));
        }
        // Recursos, curación y concentración.
        expect(prompt, contains('"resource_name"'));
        expect(prompt, contains('"resource_cost"'));
        expect(prompt, contains('"heal_dice"'));
        expect(prompt, contains('"concentration"'));
        // Y el ejemplo los enseña (la IA no puede usar campos que el
        // ejemplo no muestre).
        final example = prompt.substring(prompt.indexOf('"Kaelen el Luminoso"'));
        expect(example, contains('"resource_name": "Imposición de Manos"'));
        expect(example, contains('"concentration": true'));
        expect(example, contains('"type": "class"'));
      }
    });

    test('el ejemplo no deja campos de activas dentro de las pasivas', () {
      final prompt = AiPrompt.forEmbeddedSource('fuente');
      const header =
          'FORMATO EXACTO A SEGUIR (ejemplo mínimo con todos los campos):';
      final example = jsonDecode(
        prompt.substring(prompt.indexOf(header) + header.length).trim(),
      ) as Map<String, dynamic>;
      final abilities = example['abilities_by_action'] as Map<String, dynamic>;

      for (final passive in abilities['passive'] as List) {
        for (final field in [
          'resource_name',
          'resource_cost',
          'heal_dice',
          'concentration',
          'attack_type',
        ]) {
          expect((passive as Map).containsKey(field), isFalse, reason: field);
        }
      }
      // El recurso del ejemplo existe en "resources" con el MISMO nombre.
      final names = [
        for (final r in example['resources'] as List) (r as Map)['name'],
      ];
      for (final category in ['action', 'bonus_action', 'reaction']) {
        for (final a in abilities[category] as List) {
          final resource = (a as Map)['resource_name'] as String?;
          if (resource != null && resource.isNotEmpty) {
            expect(names, contains(resource));
          }
        }
      }
    });

    test('forNivel20Enrichment pide origen, recursos, curación y concentración',
        () {
      final prompt = AiPrompt.forNivel20Enrichment(
        name: 'Rook',
        characterClass: 'Bárbaro',
        level: 5,
        feats: 'Furia: ...',
      );

      expect(prompt, contains('"type": "class" | "racial" | "feat" | "item"'));
      expect(prompt, contains('"resource_name"'));
      expect(prompt, contains('"resource_cost"'));
      expect(prompt, contains('"heal_dice"'));
      expect(prompt, contains('"concentration": true'));
      expect(prompt, contains('NO son pasivos'));
      // Los campos de activas siguen prohibidos en pasivas.
      expect(prompt, contains('NUNCA en pasivas'));
    });

    test('forEmbeddedSource incrusta la fuente ARRIBA de las reglas', () {
      final prompt = AiPrompt.forEmbeddedSource('  FICHA-FUENTE  ');

      expect(prompt, startsWith('Actúa como experto en D&D 5e.'));
      expect(prompt, contains('FICHA-FUENTE')); // trim + embebido
      expect(prompt, contains('no hace falta que visites ningún enlace'));
      expect(
        prompt.indexOf('FICHA-FUENTE'),
        lessThan(prompt.indexOf('REGLAS OBLIGATORIAS:')),
      );
    });

    test('forNivel20Link manda el enlace y pide visitarlo', () {
      const link = 'https://nivel20.com/games/abc/characters/42-slug';
      final prompt = AiPrompt.forNivel20Link(link);

      expect(prompt, contains('Visita el siguiente enlace'));
      expect(prompt, contains(link));
    });

    test('forCorrection: ficha actual + problemas + no pisar notas', () {
      final prompt = AiPrompt.forCorrection(
        '{"basic_info": {"name": "Kaelen"}}',
        [
          'basic_info.speed: Sin "speed"; se asume 30 pies.',
          'abilities_by_action.passive[X].scaling_formula: irresoluble',
        ],
      );

      expect(prompt, contains('{"basic_info": {"name": "Kaelen"}}'));
      expect(prompt,
          contains('- basic_info.speed: Sin "speed"; se asume 30 pies.'));
      expect(prompt,
          contains('- abilities_by_action.passive[X].scaling_formula: irresoluble'));
      // La orden explícita de no pisar los campos del jugador.
      expect(prompt, contains('"user_tactics"'));
    });

    test('el ejemplo embebido decodifica y valida como ficha real', () {
      final prompt = AiPrompt.forEmbeddedSource('fuente');
      const header =
          'FORMATO EXACTO A SEGUIR (ejemplo mínimo con todos los campos):';
      final example = prompt.substring(prompt.indexOf(header) + header.length).trim();

      final decoded = jsonDecode(example) as Map<String, dynamic>;
      final result = CharacterValidator.validateMap(
        decoded.cast<String, dynamic>(),
      );

      // El ejemplo le enseña el shape a la IA: si deja de ser una ficha
      // válida, el prompt entero está enseñando mal.
      expect(result.isOk, isTrue,
          reason: 'errores: ${result.errors} / avisos: ${result.warnings}');
    });
  });
}
